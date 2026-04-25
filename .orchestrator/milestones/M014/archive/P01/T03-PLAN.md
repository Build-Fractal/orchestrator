---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M014"
name: "scripts/util/dual-write-runtime-md.sh FR-12 helper + config.yml dual_write_agents key + tests/test-dual-write-outside-invariant.sh SC-6a invariant"
depends_on: []
---

## Prerequisites

No upstream task dependencies (parallelizable with T01). Pre-existing disk state:

- `scripts/util/` exists with several utility scripts (`json-field.sh`, `read-range.sh`, etc.).
- `.orchestrator/config.yml` exists with existing keys (`intensity:`, `integration:`, `dispatch:`, `knowledge:`).
- `CLAUDE.md` exists at repo root with a `## Recent Changes` section — P01 will insert a marker-bounded region inside the existing file without overwriting any bytes outside the new markers.
- `AGENTS.md` does NOT yet exist — the first dual-write invocation will create it.
- `scripts/verify/anti-pattern-lint.sh` is the lint compliance verifier.
- M012/P04's `scripts/wiki/wiki-giscus-remap.sh` is a precedent for marker-bounded atomic splice (read-only reference; do not modify).

## Description

Ship the FR-12 dual-write helper — the full helper surface (per P01 boundary map, P02 adds invocation sites only). The helper writes content between literal marker lines `# >>> orchestrator:<region-name> >>>` and `# <<< orchestrator:<region-name> <<<` in two target files (`CLAUDE.md` and `AGENTS.md` by default), preserving bytes outside markers byte-identically (SC-6a). When markers are absent, they are inserted above the file's first heading or at EOF if no heading. When `.orchestrator/config.yml` has `dual_write_agents: false`, the helper writes only `CLAUDE.md` and skips `AGENTS.md` cleanly.

Also ship:

- The `dual_write_agents: true` top-level key in `.orchestrator/config.yml` (additive — existing keys untouched).
- `tests/test-dual-write-outside-invariant.sh` — the SC-6a invariant test that verifies bytes outside the markers are byte-identical pre- and post-write.

## Steps

### Step 1: Create `scripts/util/dual-write-runtime-md.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# scripts/util/dual-write-runtime-md.sh — FR-12 marker-bounded dual-write helper.
# Writes a content fragment between
#   # >>> orchestrator:<region-name> >>>
#   # <<< orchestrator:<region-name> <<<
# in one or more target files. Preserves bytes outside markers byte-identically.
#
# Usage: dual-write-runtime-md.sh --marker <region-name> --content <path-to-fragment>
#                                 [--file CLAUDE.md] [--file AGENTS.md]
#                                 [--root <project-root>] [--dry-run]
#
# Behavior:
#   - If a target file is missing, it is created containing only the marker
#     region with the given content.
#   - If markers are absent in an existing target, they are inserted above
#     the first heading (^#) or at EOF if no heading.
#   - If AGENTS.md is in the target list and .orchestrator/config.yml has
#     `dual_write_agents: false` at top level, AGENTS.md is skipped with a
#     `SKIPPED: AGENTS.md (dual_write_agents=false)` line on stderr.
#   - --dry-run emits one JSONL record per would-be write
#       {"command":"dual-write-runtime-md","action_type":"dual-write-region",
#        "target_path":"...","source_ref":"...","description":"..."}
#     to stdout and makes no disk writes.
#
# Exit: 0 on success; 1 on any error.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MARKER=""
CONTENT=""
DRY_RUN=0
TARGETS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --marker)
      if [ $# -lt 2 ]; then echo "--marker requires a value" >&2; exit 1; fi
      MARKER="$2"; shift 2
      ;;
    --content)
      if [ $# -lt 2 ]; then echo "--content requires a path" >&2; exit 1; fi
      CONTENT="$2"; shift 2
      ;;
    --file)
      if [ $# -lt 2 ]; then echo "--file requires a filename" >&2; exit 1; fi
      TARGETS="${TARGETS}${TARGETS:+ }$2"; shift 2
      ;;
    --root)
      if [ $# -lt 2 ]; then echo "--root requires a path" >&2; exit 1; fi
      PROJECT_ROOT="$2"; shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h)
      sed -n '1,/^$/p' "$0" | sed -e 's/^# //' -e 's/^#$//'
      exit 0
      ;;
    *)
      echo "dual-write-runtime-md.sh: unknown flag: $1" >&2; exit 1
      ;;
  esac
done

if [ -z "$MARKER" ]; then echo "missing --marker" >&2; exit 1; fi
if [ -z "$CONTENT" ] || [ ! -f "$CONTENT" ]; then
  echo "missing or unreadable --content: $CONTENT" >&2; exit 1
fi
if [ -z "$TARGETS" ]; then TARGETS="CLAUDE.md AGENTS.md"; fi

# --- Read dual_write_agents toggle from config ---
CONFIG="${PROJECT_ROOT}/.orchestrator/config.yml"
DUAL_WRITE_AGENTS=1
if [ -f "$CONFIG" ]; then
  if grep -qE '^dual_write_agents:[[:space:]]*false' "$CONFIG"; then
    DUAL_WRITE_AGENTS=0
  fi
fi

emit_dry_run_record() {
  local target="$1"
  printf '{"command":"dual-write-runtime-md","action_type":"dual-write-region","target_path":"%s","source_ref":"%s","description":"write marker-bounded region %s"}\n' \
    "$target" "$CONTENT" "$MARKER"
}

write_region() {
  local target="$1"
  local begin="# >>> orchestrator:${MARKER} >>>"
  local end="# <<< orchestrator:${MARKER} <<<"
  local tmp
  tmp="$(mktemp)"

  if [ ! -f "$target" ]; then
    # Create fresh file with just the marker region.
    {
      printf '%s\n' "$begin"
      cat "$CONTENT"
      printf '%s\n' "$end"
    } > "$tmp"
    mv "$tmp" "$target"
    return 0
  fi

  # Existing file: replace between markers, or insert above first heading/EOF.
  if grep -qF "$begin" "$target" && grep -qF "$end" "$target"; then
    # Replace in place. Use awk to copy-then-substitute the region.
    awk -v begin="$begin" -v end="$end" -v content_file="$CONTENT" '
      BEGIN { in_region=0 }
      $0 == begin {
        print $0
        while ((getline line < content_file) > 0) print line
        close(content_file)
        in_region=1
        next
      }
      $0 == end {
        print $0
        in_region=0
        next
      }
      in_region==0 { print }
    ' "$target" > "$tmp"
    mv "$tmp" "$target"
    return 0
  fi

  # Markers absent: insert above first heading, or at EOF if none.
  local first_heading_line
  first_heading_line="$(grep -nE '^#' "$target" | head -1 | awk -F: '{print $1}')"

  if [ -n "$first_heading_line" ]; then
    awk -v before="$first_heading_line" -v begin="$begin" -v end="$end" -v content_file="$CONTENT" '
      NR == before {
        print begin
        while ((getline line < content_file) > 0) print line
        close(content_file)
        print end
        print ""
      }
      { print }
    ' "$target" > "$tmp"
    mv "$tmp" "$target"
  else
    {
      cat "$target"
      printf '%s\n' "$begin"
      cat "$CONTENT"
      printf '%s\n' "$end"
    } > "$tmp"
    mv "$tmp" "$target"
  fi
}

# --- Main: iterate targets ---
for t in $TARGETS; do
  abs_target="${PROJECT_ROOT}/${t}"

  # Apply dual_write_agents=false gate for AGENTS.md only.
  if [ "$t" = "AGENTS.md" ] && [ "$DUAL_WRITE_AGENTS" -eq 0 ]; then
    echo "SKIPPED: AGENTS.md (dual_write_agents=false)" >&2
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    emit_dry_run_record "$abs_target"
    continue
  fi

  write_region "$abs_target"
  echo "WROTE: $abs_target (region=${MARKER})"
done

exit 0
```

Make executable: `chmod +x scripts/util/dual-write-runtime-md.sh`.

**Design note**: the iteration uses `for t in $TARGETS` (word-splitting on space-separated list) rather than an array. This is Bash 3.2 safe. The `TARGETS` string is built via append; when the user passes no `--file` flags, it defaults to `CLAUDE.md AGENTS.md`.

### Step 2: Add `dual_write_agents: true` to `.orchestrator/config.yml`

Append the key to the existing file — do not reorder or rewrite existing keys. Expected final file:

```yaml
schema_version: "1.0"
type: orchestrator-config
# state_root: ".orchestrator"  # Example; omit to use rule-3 (existing .orchestrator/) resolution
intensity:
  default: standard
  auto_detect: true
integration:
  speckit: auto  # auto|disabled|enabled
dispatch:
  default_backend: local-agent
knowledge:
  graph_backend: sqlite
dual_write_agents: true  # M014/P01 FR-12 — when false, skip AGENTS.md dual-write
```

(T05 will add the `specify:` section below this key.)

### Step 3: Create `tests/test-dual-write-outside-invariant.sh`

The SC-6a invariant test. Verbatim body:

```bash
#!/usr/bin/env bash
# tests/test-dual-write-outside-invariant.sh — SC-6a outside-markers shasum invariant.
# Seeds a temp CLAUDE.md-like file with known outside-markers bytes, invokes
# dual-write-runtime-md.sh several times with distinct content fragments, and
# asserts shasum of outside-markers bytes is byte-identical across writes.
# Also verifies AGENTS.md is created when absent and its outside region is
# preserved on subsequent writes.
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HELPER="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"

if [ ! -x "$HELPER" ]; then
  echo "FAIL: scripts/util/dual-write-runtime-md.sh missing or not executable" >&2
  exit 1
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Set up scratch project root with config.yml (dual_write_agents: true).
mkdir -p "$SCRATCH/.orchestrator"
cat > "$SCRATCH/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
dual_write_agents: true
EOF

# Seed CLAUDE.md with outside-markers content.
cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# CLAUDE.md

Outside content paragraph 1.

## Existing Section

Outside content paragraph 2.
EOF

# Helper: extract outside-markers bytes from a file.
outside_bytes() {
  local f="$1"
  awk '
    /^# >>> orchestrator:/ { in_region=1; next }
    /^# <<< orchestrator:/ { in_region=0; next }
    in_region != 1 { print }
  ' "$f"
}

# Compute reference shasum before any writes.
REF_CLAUDE_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"

# Fragment 1.
FRAG1="$(mktemp)"
echo "- fragment one: spec-001 scaffolded" > "$FRAG1"

bash "$HELPER" --marker recent-changes --content "$FRAG1" --root "$SCRATCH" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: first write exited non-zero ($RC)" >&2; exit 1
fi

POST1_CLAUDE_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
if [ "$REF_CLAUDE_SHA" != "$POST1_CLAUDE_SHA" ]; then
  echo "FAIL: outside-markers bytes diverged in CLAUDE.md after first write" >&2
  echo "  ref=$REF_CLAUDE_SHA post=$POST1_CLAUDE_SHA" >&2
  exit 1
fi

# AGENTS.md should now exist.
if [ ! -f "$SCRATCH/AGENTS.md" ]; then
  echo "FAIL: AGENTS.md not created on first write" >&2; exit 1
fi
REF_AGENTS_SHA="$(outside_bytes "$SCRATCH/AGENTS.md" | shasum -a 256 | awk '{print $1}')"

# Fragment 2 — replace the region.
FRAG2="$(mktemp)"
echo "- fragment two: spec-001 amended + spec-002 scaffolded" > "$FRAG2"
bash "$HELPER" --marker recent-changes --content "$FRAG2" --root "$SCRATCH" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: second write exited non-zero ($RC)" >&2; exit 1
fi

POST2_CLAUDE_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
POST2_AGENTS_SHA="$(outside_bytes "$SCRATCH/AGENTS.md" | shasum -a 256 | awk '{print $1}')"

if [ "$REF_CLAUDE_SHA" != "$POST2_CLAUDE_SHA" ]; then
  echo "FAIL: outside-markers bytes diverged in CLAUDE.md after second write" >&2
  exit 1
fi
if [ "$REF_AGENTS_SHA" != "$POST2_AGENTS_SHA" ]; then
  echo "FAIL: outside-markers bytes diverged in AGENTS.md after second write" >&2
  exit 1
fi

# Verify region contents actually changed.
if ! grep -qF "fragment two" "$SCRATCH/CLAUDE.md"; then
  echo "FAIL: CLAUDE.md region content was not replaced" >&2; exit 1
fi
if ! grep -qF "fragment two" "$SCRATCH/AGENTS.md"; then
  echo "FAIL: AGENTS.md region content was not replaced" >&2; exit 1
fi

# Test dual_write_agents=false gate.
cat > "$SCRATCH/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
dual_write_agents: false
EOF

FRAG3="$(mktemp)"
echo "- fragment three: should NOT appear in AGENTS.md" > "$FRAG3"

# Capture the pre-state of AGENTS.md.
PRE_GATE_AGENTS_BYTES="$(cat "$SCRATCH/AGENTS.md" | shasum -a 256 | awk '{print $1}')"

bash "$HELPER" --marker recent-changes --content "$FRAG3" --root "$SCRATCH" >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: third write (gated) exited non-zero ($RC)" >&2; exit 1
fi

POST_GATE_AGENTS_BYTES="$(cat "$SCRATCH/AGENTS.md" | shasum -a 256 | awk '{print $1}')"
if [ "$PRE_GATE_AGENTS_BYTES" != "$POST_GATE_AGENTS_BYTES" ]; then
  echo "FAIL: AGENTS.md was modified despite dual_write_agents=false" >&2; exit 1
fi

if ! grep -qF "fragment three" "$SCRATCH/CLAUDE.md"; then
  echo "FAIL: CLAUDE.md was not updated on gated write" >&2; exit 1
fi

# Test --dry-run.
DRY_OUT="$(bash "$HELPER" --marker recent-changes --content "$FRAG3" --root "$SCRATCH" --dry-run 2>/dev/null)"
if ! echo "$DRY_OUT" | grep -qE '^\{.*"action_type":"dual-write-region"'; then
  echo "FAIL: --dry-run did not emit JSONL manifest record" >&2; exit 1
fi

echo "PASS: tests/test-dual-write-outside-invariant.sh"
exit 0
```

Make executable: `chmod +x tests/test-dual-write-outside-invariant.sh`.

### Step 4: Create gate verifiers

#### `scripts/verify/m014-p01-dual-write-helper.sh`

```bash
#!/usr/bin/env bash
# Gate: verify dual-write helper shape (flag surface + exit codes + config gating).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HELPER="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"

if [ ! -x "$HELPER" ]; then
  echo "FAIL: helper missing or not executable" >&2; exit 1
fi

# Required flags present in help output (sed-extracted header block).
grep -q -- '--marker' "$HELPER" || { echo "FAIL: --marker flag missing" >&2; exit 1; }
grep -q -- '--content' "$HELPER" || { echo "FAIL: --content flag missing" >&2; exit 1; }
grep -q -- '--file' "$HELPER" || { echo "FAIL: --file flag missing" >&2; exit 1; }
grep -q -- '--dry-run' "$HELPER" || { echo "FAIL: --dry-run flag missing" >&2; exit 1; }

# Marker convention literal strings appear in source.
grep -q 'orchestrator:' "$HELPER" || { echo "FAIL: orchestrator: marker convention absent" >&2; exit 1; }
grep -q 'dual_write_agents' "$HELPER" || { echo "FAIL: dual_write_agents config key not referenced" >&2; exit 1; }

# Missing required flags errors non-zero.
bash "$HELPER" >/dev/null 2>&1
if [ $? -eq 0 ]; then echo "FAIL: no-args invocation exited 0" >&2; exit 1; fi

echo "PASS: dual-write helper shape verified"
exit 0
```

#### `scripts/verify/m014-p01-dual-write-outside-invariant.sh`

```bash
#!/usr/bin/env bash
# Gate: run the outside-markers invariant fixture test.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST="${PROJECT_ROOT}/tests/test-dual-write-outside-invariant.sh"

if [ ! -x "$TEST" ]; then
  echo "FAIL: tests/test-dual-write-outside-invariant.sh missing or not executable" >&2
  exit 1
fi

bash "$TEST"
exit $?
```

#### `scripts/verify/m014-p01-config-keys.sh`

```bash
#!/usr/bin/env bash
# Gate: verify .orchestrator/config.yml carries the new dual_write_agents key.
# (T05 extends this later with specify: section checks.)
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG="${PROJECT_ROOT}/.orchestrator/config.yml"

if [ ! -f "$CONFIG" ]; then
  echo "FAIL: .orchestrator/config.yml missing" >&2; exit 1
fi

grep -qE '^dual_write_agents:[[:space:]]*true' "$CONFIG" || {
  echo "FAIL: dual_write_agents: true not present at top level" >&2; exit 1;
}

# T05 will expand this gate to check specify: section. P01 skeleton check:
# Once T05 runs, this assertion becomes required.
if grep -q '^specify:' "$CONFIG"; then
  # T05 landed; run the expanded checks.
  grep -q 'complexity_thresholds:' "$CONFIG" || {
    echo "FAIL: specify.complexity_thresholds missing" >&2; exit 1;
  }
  grep -q 'scaffolder_description_min_words:' "$CONFIG" || {
    echo "FAIL: specify.scaffolder_description_min_words missing" >&2; exit 1;
  }
fi

echo "PASS: config keys verified"
exit 0
```

Make all three executable.

## Must-Haves

- `scripts/util/dual-write-runtime-md.sh` exists, is executable, and implements the FR-12 contract (marker-bounded write with outside-byte preservation, AGENTS.md create-if-absent, `dual_write_agents: false` gate, `--dry-run` FR-19 manifest emission)
- `.orchestrator/config.yml` carries `dual_write_agents: true` at top level; all pre-existing keys are byte-preserved
- `tests/test-dual-write-outside-invariant.sh` exists, is executable, exits 0 with `PASS: ...`
- `scripts/verify/m014-p01-dual-write-helper.sh` exists, is executable, exits 0
- `scripts/verify/m014-p01-dual-write-outside-invariant.sh` exists, is executable, exits 0
- `scripts/verify/m014-p01-config-keys.sh` exists, is executable, exits 0
- All four new shell scripts are Bash 3.2 compatible and pass `scripts/verify/anti-pattern-lint.sh`

## Verification

```
bash scripts/verify/m014-p01-dual-write-helper.sh
```

Expected: `PASS: dual-write helper shape verified`, exit 0.

```
bash scripts/verify/m014-p01-dual-write-outside-invariant.sh
```

Expected: `PASS: tests/test-dual-write-outside-invariant.sh`, exit 0.

```
bash scripts/verify/m014-p01-config-keys.sh
```

Expected: `PASS: config keys verified`, exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/util/dual-write-runtime-md.sh
```

Expected: exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture tests/test-dual-write-outside-invariant.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

None — T03 is independent of T01.

### From Disk (Pre-existing)

- `.orchestrator/config.yml` — existing config; new key appended additively.
- `scripts/verify/anti-pattern-lint.sh` — lint compliance verifier.
- `scripts/wiki/wiki-giscus-remap.sh` — M012/P04 marker-bounded atomic splice precedent (read-only reference).

## Constraints

- Bash 3.2 compatible. No associative arrays, no `mapfile`, no `${var,,}`, no `<(...)`, no `&>`.
- Outside-markers bytes are preserved byte-identically (SC-6a). The atomic write pattern is temp-file-then-rename per M012/P04 precedent.
- `dual_write_agents: false` gate is a runtime-level skip; the helper is still invoked from every call site, but AGENTS.md write is a no-op.
- `--dry-run` emits FR-19-shaped JSONL records (`{command, action_type, target_path, source_ref, description}`). Makes zero disk writes.
- `CLAUDE.md`'s existing content outside the new marker region is byte-preserved when the helper inserts markers.
- Passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files committed:

1. `scripts/util/dual-write-runtime-md.sh` — FR-12 helper (~170 lines, executable)
2. `.orchestrator/config.yml` — additive edit adding `dual_write_agents: true`
3. `tests/test-dual-write-outside-invariant.sh` — SC-6a fixture test (~130 lines, executable)
4. `scripts/verify/m014-p01-dual-write-helper.sh` — shape gate (~30 lines, executable)
5. `scripts/verify/m014-p01-dual-write-outside-invariant.sh` — invariant gate (~15 lines, executable)
6. `scripts/verify/m014-p01-config-keys.sh` — config-keys gate (~30 lines, executable)

All three gate verifiers exit 0.
