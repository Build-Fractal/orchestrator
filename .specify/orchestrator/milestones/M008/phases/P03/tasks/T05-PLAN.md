---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P03"
milestone: "M008"
name: "Integration test + Bash 3.2 compatibility check"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: `scripts/engine/intensity-gate.sh` exists and emits key=value output.
- T02 complete: `scripts/engine/intensity-override.sh` exists and rewrites metadata frontmatter.
- T03 complete: `scripts/knowledge/intensity-knowledge.sh` exists with `--dry-run` mode.

## Description

Two verification scripts:

1. `scripts/verify/m008-p03-bash32-compat.sh` — scans the three new scripts for prohibited Bash 4+ constructs. Matches the pattern established by `scripts/verify/m008-p01-bash32-compat.sh` and `scripts/verify/m008-p02-bash32-compat.sh`.

2. `scripts/verify/m008-p03-integration-e2e.sh` — end-to-end integration test:
   - Builds a fixture metadata file at each of Quick / Standard / Full.
   - Invokes `intensity-gate.sh` for every stage at every level; asserts outputs are non-empty and distinct across levels for each stage.
   - Invokes `intensity-override.sh` to transition Quick -> Full on a fixture metadata file; asserts the rewrite succeeded.
   - Invokes `intensity-knowledge.sh --dry-run` at each level; asserts the dry-run log matches the expected subset.

No dependency on the command docs from T04 — the integration test exercises the scripts only. This keeps the integration test's concerns separate from T04's doc-refactor concerns.

## Steps

### Step 1 — Create scripts/verify/m008-p03-bash32-compat.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies new P03 scripts avoid Bash 4+ constructs per MEM001 (NFR-200).
# Matches the pattern from m008-p01-bash32-compat.sh and
# m008-p02-bash32-compat.sh.
set -u

scripts="
scripts/engine/intensity-gate.sh
scripts/engine/intensity-override.sh
scripts/knowledge/intensity-knowledge.sh
"

fail=0
for s in $scripts; do
  if [[ ! -f "$s" ]]; then
    echo "FAIL: $s missing"
    fail=1
    continue
  fi

  # declare -A = associative arrays (bash 4+)
  if grep -nE '^[[:space:]]*(declare|typeset|local)[[:space:]]+-A[[:space:]]' "$s" >/dev/null; then
    echo "FAIL: $s uses 'declare -A' (bash 4+ associative arrays)"
    fail=1
  fi

  # readarray / mapfile (bash 4+)
  if grep -nE '^[[:space:]]*(readarray|mapfile)[[:space:]]' "$s" >/dev/null; then
    echo "FAIL: $s uses readarray/mapfile (bash 4+)"
    fail=1
  fi

  # |& (bash 4+ redirect)
  if grep -nE '\|&' "$s" >/dev/null; then
    echo "FAIL: $s uses '|&' redirect (bash 4+)"
    fail=1
  fi

  # Process substitution inside script (would break in /bin/sh; bash 3.2 ok but we avoid)
  # NB: this is a style choice aligned with AD-19 (harness heuristic).
  if grep -nE '<\(|>\(' "$s" >/dev/null; then
    echo "FAIL: $s uses process substitution '<(...)' or '>(...)'"
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  exit 1
fi

echo "PASS: all P03 scripts are Bash 3.2 compatible"
```

### Step 2 — Create scripts/verify/m008-p03-integration-e2e.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# End-to-end integration test for the P03 intensity-aware pipeline.
# Exercises intensity-gate.sh, intensity-override.sh, and
# intensity-knowledge.sh against fixture metadata files.
set -u

gate="scripts/engine/intensity-gate.sh"
override="scripts/engine/intensity-override.sh"
know="scripts/knowledge/intensity-knowledge.sh"

for f in "$gate" "$override" "$know"; do
  test -x "$f" || { echo "FAIL: $f missing or not executable"; exit 1; }
done

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

make_meta() {
  local path="$1"
  local level="$2"
  cat > "$path" <<EOF
---
schema_version: "1.0"
type: intensity-metadata
intensity: "$level"
scope: "moderate"
risk_level: "medium"
complexity: "moderate"
confidence: "high"
reasoning: "fixture"
overridden_by: ""
original_intensity: ""
capabilities_used:
  - "none"
evaluated_at: "2026-04-14T15:00:00Z"
---

## Fixture
EOF
}

# --- 1. Gate: all 7 stages x 3 levels produce distinct output ---

stages="discuss research plan-phase dispatch verify knowledge auto"

for s in $stages; do
  q="$(bash "$gate" --stage "$s" --intensity Quick 2>/dev/null)"
  std="$(bash "$gate" --stage "$s" --intensity Standard 2>/dev/null)"
  full="$(bash "$gate" --stage "$s" --intensity Full 2>/dev/null)"

  if [[ -z "$q" ]] || [[ -z "$std" ]] || [[ -z "$full" ]]; then
    echo "FAIL: stage=$s emitted empty output at some level"
    exit 1
  fi
  if [[ "$q" = "$std" ]]; then
    echo "FAIL: stage=$s produced identical output at Quick and Standard"
    exit 1
  fi
  if [[ "$std" = "$full" ]]; then
    echo "FAIL: stage=$s produced identical output at Standard and Full"
    exit 1
  fi
done

# --- 2. Gate via --intensity-metadata produces identical output to --intensity ---

make_meta "$tmp/quick.md" "Quick"
make_meta "$tmp/full.md" "Full"

direct="$(bash "$gate" --stage verify --intensity Quick 2>/dev/null)"
via_meta="$(bash "$gate" --stage verify --intensity-metadata "$tmp/quick.md" 2>/dev/null)"
if [[ "$direct" != "$via_meta" ]]; then
  echo "FAIL: --intensity-metadata does not agree with --intensity for verify Quick"
  exit 1
fi

# --- 3. Override: Quick -> Full rewrites metadata ---

meta_ov="$tmp/override-target.md"
make_meta "$meta_ov" "Quick"

bash "$override" --metadata-file "$meta_ov" --new-intensity Full >/dev/null 2>&1 \
  || { echo "FAIL: override Quick -> Full exited non-zero"; exit 1; }

grep -q '^intensity: "Full"' "$meta_ov" || { echo "FAIL: override did not rewrite intensity to Full"; exit 1; }
grep -q '^original_intensity: "Quick"' "$meta_ov" || { echo "FAIL: override did not preserve Quick as original_intensity"; exit 1; }
grep -q '^overridden_by: "developer"' "$meta_ov" || { echo "FAIL: override did not set overridden_by=developer"; exit 1; }

# After override, the gate reading that file should now return Full substeps
post="$(bash "$gate" --stage verify --intensity-metadata "$meta_ov" 2>/dev/null)"
echo "$post" | grep -q 'tier1,tier2,tier3,tier4' \
  || { echo "FAIL: gate on overridden file did not reflect Full intensity"; exit 1; }

# --- 4. Knowledge: dry-run at each level matches expected subset ---

make_meta "$tmp/k-quick.md" "Quick"
make_meta "$tmp/k-std.md" "Standard"
make_meta "$tmp/k-full.md" "Full"

q_log="$(bash "$know" --intensity-metadata "$tmp/k-quick.md" --dry-run 2>/dev/null)"
s_log="$(bash "$know" --intensity-metadata "$tmp/k-std.md" --dry-run 2>/dev/null)"
f_log="$(bash "$know" --intensity-metadata "$tmp/k-full.md" --dry-run 2>/dev/null)"

# Quick: one step (write-summary only)
q_count="$(echo "$q_log" | grep -c '^WOULD_RUN:')"
if [[ "$q_count" != "1" ]]; then echo "FAIL: Quick knowledge log expected 1 step, got $q_count"; exit 1; fi
echo "$q_log" | grep -q 'write-summary.sh' || { echo "FAIL: Quick missing write-summary.sh"; exit 1; }

# Standard: two steps
s_count="$(echo "$s_log" | grep -c '^WOULD_RUN:')"
if [[ "$s_count" != "2" ]]; then echo "FAIL: Standard knowledge log expected 2 steps, got $s_count"; exit 1; fi
echo "$s_log" | grep -q 'append-decision.sh' || { echo "FAIL: Standard missing append-decision.sh"; exit 1; }

# Full: four steps
f_count="$(echo "$f_log" | grep -c '^WOULD_RUN:')"
if [[ "$f_count" != "4" ]]; then echo "FAIL: Full knowledge log expected 4 steps, got $f_count"; exit 1; fi
echo "$f_log" | grep -q 'rebuild-index.sh' || { echo "FAIL: Full missing rebuild-index.sh"; exit 1; }

# --- 5. End-to-end sanity: override then knowledge dispatch expands set ---

make_meta "$tmp/e2e.md" "Quick"
pre_log="$(bash "$know" --intensity-metadata "$tmp/e2e.md" --dry-run 2>/dev/null)"
pre_count="$(echo "$pre_log" | grep -c '^WOULD_RUN:')"
if [[ "$pre_count" != "1" ]]; then echo "FAIL: pre-override Quick should plan 1 step, got $pre_count"; exit 1; fi

bash "$override" --metadata-file "$tmp/e2e.md" --new-intensity Full >/dev/null 2>&1 \
  || { echo "FAIL: mid-workflow override exited non-zero"; exit 1; }

post_log="$(bash "$know" --intensity-metadata "$tmp/e2e.md" --dry-run 2>/dev/null)"
post_count="$(echo "$post_log" | grep -c '^WOULD_RUN:')"
if [[ "$post_count" != "4" ]]; then echo "FAIL: post-override Full should plan 4 steps, got $post_count"; exit 1; fi

echo "PASS: P03 end-to-end integration — gate, override, knowledge all honor intensity"
```

### Step 3 — Make both verify scripts executable

```bash
chmod +x scripts/verify/m008-p03-bash32-compat.sh
chmod +x scripts/verify/m008-p03-integration-e2e.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: Bash 3.2 compat truth, end-to-end integration truth.
- **Artifacts**: `scripts/verify/m008-p03-bash32-compat.sh`, `scripts/verify/m008-p03-integration-e2e.sh`.

## Verification

```bash
bash scripts/verify/m008-p03-bash32-compat.sh
bash scripts/verify/m008-p03-integration-e2e.sh
```

Both print `PASS:` and exit 0.

### Files Touched By This Task

- `scripts/verify/m008-p03-bash32-compat.sh` (create)
- `scripts/verify/m008-p03-integration-e2e.sh` (create)

## Inputs

### From Previous Tasks

- `scripts/engine/intensity-gate.sh` (from T01)
  - Key API: `--stage <name> --intensity <level>` OR `--stage <name> --intensity-metadata <path>`. Emits `execute_substeps=<csv>` and `skip_substeps=<csv>`. Exit 0 success, non-zero on invalid.
  - Matrix: all 7 stages (discuss/research/plan-phase/dispatch/verify/knowledge/auto) distinct per Quick/Standard/Full.

- `scripts/engine/intensity-override.sh` (from T02)
  - Key API: `--metadata-file <path> --new-intensity <level>`. Rewrites frontmatter atomically. Exit 0 success, 2 invalid intensity, 3 no-op rejection.
  - Post-conditions: `intensity:` is the new value, `original_intensity:` holds the old value, `overridden_by:` is `"developer"`. Body unchanged.

- `scripts/knowledge/intensity-knowledge.sh` (from T03)
  - Key API: `--intensity-metadata <path>` or `--intensity <level>`, plus `--dry-run`. Dry-run emits `WOULD_RUN: <script> <args>` lines.
  - Expected step counts: Quick=1, Standard=2, Full=4.

### From Disk (Pre-existing)

- `scripts/verify/m008-p01-bash32-compat.sh` and `scripts/verify/m008-p02-bash32-compat.sh` — templates for the P03 bash32 compat check. Same pattern, new file list.

## Constraints

- Bash 3.2 compatible (verify script itself). No process substitution, no associative arrays.
- The integration test MUST NOT depend on any external state (`.specify/`, `git`, network). All inputs are built in a fresh `$(mktemp -d)` and cleaned up via `trap`.
- The integration test uses `--dry-run` on `intensity-knowledge.sh` rather than invoking the real knowledge pipeline. This isolates the P03 gate logic under test from M007 knowledge-pipeline side effects.
- Every step emits a clear `FAIL: <message>` diagnostic on failure with enough context (stage name, counts, fixture path) to diagnose.
- Final success line on stdout is exactly `PASS: ...` (for compatibility with `check-must-haves.sh`).

## Expected Output

After completing this task:

1. `scripts/verify/m008-p03-bash32-compat.sh` exists and passes against all three new P03 scripts.
2. `scripts/verify/m008-p03-integration-e2e.sh` exists and exercises the gate, override, and knowledge dispatch end-to-end.
3. Running `bash scripts/verify/m008-p03-bash32-compat.sh` prints `PASS:` and exits 0.
4. Running `bash scripts/verify/m008-p03-integration-e2e.sh` prints `PASS:` and exits 0.
5. With all P01/P02/P03 tasks complete, running `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P03` reports all truths PASS, all artifacts present, all key links valid.
6. `git status` shows 2 new files under `scripts/verify/`.
