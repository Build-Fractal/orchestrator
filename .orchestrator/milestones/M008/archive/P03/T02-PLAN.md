---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M008"
name: "Create scripts/engine/intensity-override.sh -- mid-workflow override"
depends_on: []
---

## Prerequisites

- `templates/intensity-metadata.md` (from P01) — the schema this script rewrites. Known frontmatter fields: `intensity`, `scope`, `risk_level`, `complexity`, `confidence`, `reasoning`, `overridden_by`, `original_intensity`, `capabilities_used`, `evaluated_at`.
- A metadata instance file conforming to that schema (created by an earlier pipeline stage — typically via `intensity-recommend.sh` output funnelled into the template).
- Bash 3.2+.

## Description

Create `scripts/engine/intensity-override.sh` — a surgical mid-workflow intensity override. Given a metadata file and a new intensity level, rewrite the metadata's YAML frontmatter so:

1. `intensity:` becomes the new value.
2. `original_intensity:` is set to the previous value of `intensity:` (preserving history).
3. `overridden_by:` is set to `"developer"`.

The script MUST NOT touch any file other than the metadata file it was told to rewrite. Completed stage outputs (phase summaries, task summaries, verification reports, knowledge entries) are off-limits: FR-004's "preserving completed stages" guarantee depends on this script being scope-limited.

Reject no-op overrides (new == current) and reject invalid intensity values.

Implementation approach: rewrite the file via a tmp + mv swap (atomic replace). Use `sed`/`awk` on the YAML frontmatter lines only. Do not touch the body.

## Steps

### Step 1 — Create scripts/engine/intensity-override.sh

Write verbatim to `scripts/engine/intensity-override.sh`:

```bash
#!/usr/bin/env bash
# scripts/engine/intensity-override.sh -- Mid-workflow intensity override.
#
# Rewrites the `intensity:` field in an intensity-metadata.md file's
# YAML frontmatter, preserving the previous value as original_intensity
# and flagging overridden_by=developer. Does not touch any other file.
#
# FR-004: override remaining stages while preserving completed stages.
#         This script enforces the "other files untouched" half of that
#         contract. Command docs enforce the "future stages read the
#         new value" half via intensity-gate.sh.
#
# Usage:
#   intensity-override.sh --metadata-file <path> --new-intensity <Quick|Standard|Full>
#
# Exit: 0 success, 1 usage/IO error, 2 invalid intensity, 3 no-op rejection.
# Bash 3.2 compatible.

set -u

METADATA_FILE=""
NEW_INTENSITY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --metadata-file)
      METADATA_FILE="${2:-}"; shift 2 ;;
    --new-intensity)
      NEW_INTENSITY="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

if [[ -z "$METADATA_FILE" ]]; then
  echo "ERROR: --metadata-file is required" >&2
  exit 1
fi
if [[ ! -f "$METADATA_FILE" ]]; then
  echo "ERROR: metadata file not found: $METADATA_FILE" >&2
  exit 1
fi
if [[ -z "$NEW_INTENSITY" ]]; then
  echo "ERROR: --new-intensity is required" >&2
  exit 1
fi

case "$NEW_INTENSITY" in
  Quick|Standard|Full) ;;
  *)
    echo "ERROR: invalid intensity '$NEW_INTENSITY' (expected Quick|Standard|Full)" >&2
    exit 2 ;;
esac

# Read current intensity from the file's YAML frontmatter.
current="$(grep -E '^intensity:' "$METADATA_FILE" | head -n 1 | sed -E 's/^intensity:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"

if [[ -z "$current" ]]; then
  echo "ERROR: cannot find intensity: field in $METADATA_FILE" >&2
  exit 1
fi

if [[ "$current" = "$NEW_INTENSITY" ]]; then
  echo "ERROR: already at intensity=$NEW_INTENSITY (no-op rejected)" >&2
  exit 3
fi

# Rewrite via tmp + mv (atomic).
tmp_file="$(mktemp)"
# shellcheck disable=SC2064
trap "rm -f '$tmp_file'" EXIT

# AWK pass: modify three frontmatter fields in place. We consider only
# the first YAML frontmatter block (between the first pair of '---'
# lines). Outside that block, lines are copied verbatim.
awk -v new_intensity="$NEW_INTENSITY" -v old_intensity="$current" '
  BEGIN { in_fm = 0; fm_done = 0; seen_ov = 0; seen_orig = 0; }
  {
    if (fm_done == 0 && $0 == "---") {
      if (in_fm == 0) { in_fm = 1; print; next; }
      else {
        # Closing the frontmatter block — inject override/original fields
        # if the original file did not already contain them.
        if (seen_orig == 0) {
          print "original_intensity: \"" old_intensity "\"";
        }
        if (seen_ov == 0) {
          print "overridden_by: \"developer\"";
        }
        print;
        in_fm = 0;
        fm_done = 1;
        next;
      }
    }
    if (in_fm == 1) {
      if ($0 ~ /^intensity:/) {
        print "intensity: \"" new_intensity "\"";
        next;
      }
      if ($0 ~ /^original_intensity:/) {
        # Only set original_intensity if it is currently empty. If it
        # already holds a non-empty prior value we keep the original
        # chain (so that override-then-override traces to the first
        # recommendation, not to the intermediate).
        val = $0;
        sub(/^original_intensity:[[:space:]]*/, "", val);
        gsub(/"/, "", val);
        gsub(/[[:space:]]+$/, "", val);
        if (val == "") {
          print "original_intensity: \"" old_intensity "\"";
        } else {
          print $0;
        }
        seen_orig = 1;
        next;
      }
      if ($0 ~ /^overridden_by:/) {
        print "overridden_by: \"developer\"";
        seen_ov = 1;
        next;
      }
    }
    print;
  }
' "$METADATA_FILE" > "$tmp_file"

# Sanity check: tmp file should not be empty and should still have a frontmatter.
if [[ ! -s "$tmp_file" ]]; then
  echo "ERROR: rewrite produced empty file" >&2
  exit 1
fi
if ! grep -q '^intensity:' "$tmp_file"; then
  echo "ERROR: rewrite lost intensity: field" >&2
  exit 1
fi

mv "$tmp_file" "$METADATA_FILE"
trap - EXIT

echo "OVERRIDE: ${current} -> ${NEW_INTENSITY} in ${METADATA_FILE}"
exit 0
```

### Step 2 — Make executable

```bash
chmod +x scripts/engine/intensity-override.sh
```

### Step 3 — Create scripts/verify/m008-p03-override-rewrites-metadata.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-override.sh rewrites the metadata frontmatter:
# intensity becomes the new value, original_intensity records the old
# value, overridden_by=developer. Body is untouched.
set -u

f="scripts/engine/intensity-override.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
meta="$tmp/intensity.md"
cat > "$meta" <<'EOF'
---
schema_version: "1.0"
type: intensity-metadata
intensity: "Quick"
scope: "trivial"
risk_level: "low"
complexity: "simple"
confidence: "high"
reasoning: "trivial task, low risk"
overridden_by: ""
original_intensity: ""
capabilities_used:
  - "none"
evaluated_at: "2026-04-14T15:00:00Z"
---

## Intensity Metadata

Body content stays untouched by override.
EOF

body_before="$(sed -n '/^---$/,/^---$/!p' "$meta")"

bash "$f" --metadata-file "$meta" --new-intensity Full >/dev/null 2>&1 \
  || { echo "FAIL: override Quick -> Full returned non-zero"; exit 1; }

grep -q '^intensity: "Full"' "$meta" || { echo "FAIL: intensity: not rewritten to Full"; exit 1; }
grep -q '^original_intensity: "Quick"' "$meta" || { echo "FAIL: original_intensity: not set to Quick"; exit 1; }
grep -q '^overridden_by: "developer"' "$meta" || { echo "FAIL: overridden_by: not set to developer"; exit 1; }

body_after="$(sed -n '/^---$/,/^---$/!p' "$meta")"
if [[ "$body_before" != "$body_after" ]]; then
  echo "FAIL: body content changed by override"
  exit 1
fi

echo "PASS: intensity-override.sh rewrites frontmatter correctly and leaves body unchanged"
```

### Step 4 — Create scripts/verify/m008-p03-override-rejects-invalid.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-override.sh rejects invalid intensities and no-op
# (same-level) overrides with non-zero exit.
set -u

f="scripts/engine/intensity-override.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
meta="$tmp/intensity.md"
cat > "$meta" <<'EOF'
---
schema_version: "1.0"
type: intensity-metadata
intensity: "Standard"
---
EOF

# Invalid intensity
err="$(bash "$f" --metadata-file "$meta" --new-intensity Medium 2>&1 >/dev/null)"
rc=$?
if [[ $rc -eq 0 ]]; then echo "FAIL: invalid intensity did not exit non-zero"; exit 1; fi
echo "$err" | grep -q 'invalid intensity' || { echo "FAIL: invalid intensity diagnostic missing"; exit 1; }

# No-op (same level)
err2="$(bash "$f" --metadata-file "$meta" --new-intensity Standard 2>&1 >/dev/null)"
rc2=$?
if [[ $rc2 -eq 0 ]]; then echo "FAIL: same-level override did not exit non-zero"; exit 1; fi
echo "$err2" | grep -q 'no-op' || { echo "FAIL: same-level override diagnostic missing"; exit 1; }

# Missing file
err3="$(bash "$f" --metadata-file "$tmp/does-not-exist" --new-intensity Full 2>&1 >/dev/null)"
rc3=$?
if [[ $rc3 -eq 0 ]]; then echo "FAIL: missing file did not exit non-zero"; exit 1; fi

echo "PASS: intensity-override.sh rejects invalid intensities, no-ops, and missing files"
```

### Step 5 — Create scripts/verify/m008-p03-override-scope-limited.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-override.sh does not modify any file other than
# the metadata file it was given. Uses a sandbox directory with several
# sentinel files and checks their mtimes after the override runs.
set -u

f="scripts/engine/intensity-override.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

meta="$tmp/intensity.md"
cat > "$meta" <<'EOF'
---
schema_version: "1.0"
type: intensity-metadata
intensity: "Quick"
---
EOF

# Sentinel files that represent completed stage outputs.
sentinel_a="$tmp/P01-SUMMARY.md"
sentinel_b="$tmp/T01-SUMMARY.md"
sentinel_c="$tmp/KNOWLEDGE.md"
echo "phase summary" > "$sentinel_a"
echo "task summary" > "$sentinel_b"
echo "knowledge" > "$sentinel_c"

hash_before_a="$(cksum "$sentinel_a" | cut -d' ' -f1-2)"
hash_before_b="$(cksum "$sentinel_b" | cut -d' ' -f1-2)"
hash_before_c="$(cksum "$sentinel_c" | cut -d' ' -f1-2)"

bash "$f" --metadata-file "$meta" --new-intensity Standard >/dev/null 2>&1 \
  || { echo "FAIL: override returned non-zero"; exit 1; }

hash_after_a="$(cksum "$sentinel_a" | cut -d' ' -f1-2)"
hash_after_b="$(cksum "$sentinel_b" | cut -d' ' -f1-2)"
hash_after_c="$(cksum "$sentinel_c" | cut -d' ' -f1-2)"

if [[ "$hash_before_a" != "$hash_after_a" ]]; then echo "FAIL: override modified P01-SUMMARY.md"; exit 1; fi
if [[ "$hash_before_b" != "$hash_after_b" ]]; then echo "FAIL: override modified T01-SUMMARY.md"; exit 1; fi
if [[ "$hash_before_c" != "$hash_after_c" ]]; then echo "FAIL: override modified KNOWLEDGE.md"; exit 1; fi

# Metadata file ITSELF must have been rewritten
grep -q '^intensity: "Standard"' "$meta" || { echo "FAIL: metadata file not rewritten"; exit 1; }

echo "PASS: intensity-override.sh modifies only the metadata file"
```

### Step 6 — Make verify scripts executable

```bash
chmod +x scripts/verify/m008-p03-override-rewrites-metadata.sh
chmod +x scripts/verify/m008-p03-override-rejects-invalid.sh
chmod +x scripts/verify/m008-p03-override-scope-limited.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: override rewrites metadata, override rejects invalid, override scope-limited.
- **Artifacts**: `scripts/engine/intensity-override.sh`, `scripts/verify/m008-p03-override-rewrites-metadata.sh`, `scripts/verify/m008-p03-override-rejects-invalid.sh`, `scripts/verify/m008-p03-override-scope-limited.sh`.

## Verification

```bash
bash scripts/verify/m008-p03-override-rewrites-metadata.sh
bash scripts/verify/m008-p03-override-rejects-invalid.sh
bash scripts/verify/m008-p03-override-scope-limited.sh
```

All three should print `PASS:` and exit 0.

### Files Touched By This Task

- `scripts/engine/intensity-override.sh` (create)
- `scripts/verify/m008-p03-override-rewrites-metadata.sh` (create)
- `scripts/verify/m008-p03-override-rejects-invalid.sh` (create)
- `scripts/verify/m008-p03-override-scope-limited.sh` (create)

## Inputs

### From Previous Tasks

- None. T02 is independent within P03.

### From Disk (Pre-existing)

- `templates/intensity-metadata.md` (from P01) — the schema this script mutates. Only frontmatter fields are touched; body is preserved verbatim.

## Constraints

- Bash 3.2 compatible — `awk` is POSIX-safe, no bash 4 features. No associative arrays, no `readarray`, no `|&`, no process substitution.
- MUST NOT modify any file other than the file passed via `--metadata-file`. Violating this breaks FR-004's completed-stage preservation guarantee. Verified by `m008-p03-override-scope-limited.sh`.
- Atomic rewrite: write to tmp file, then `mv` into place. Never truncate-in-place (a crash mid-write would corrupt the metadata).
- MUST preserve the YAML frontmatter body region boundary — the closing `---` line and all content below must survive.
- `original_intensity` chain: if `original_intensity` is already populated from a previous override, preserve it (so repeat overrides trace back to the first recommendation, not to the intermediate).
- ISO 8601 UTC timestamps only if the script writes timestamps; this script does NOT add any timestamp field itself.

## Expected Output

After completing this task:

1. `scripts/engine/intensity-override.sh` exists (~130 lines), executable.
2. Given a metadata file with `intensity: "Quick"`, running the script with `--new-intensity Full` produces a file with `intensity: "Full"`, `original_intensity: "Quick"`, `overridden_by: "developer"`, body unchanged.
3. Running with `--new-intensity Medium` exits 2 with "invalid intensity" on stderr.
4. Running with `--new-intensity` equal to the current value exits 3 with "no-op" on stderr.
5. No file other than the metadata file is modified.
6. All three verify scripts print `PASS:` and exit 0.
7. `git status` shows 4 new files.
