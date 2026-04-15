---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M008"
name: "Create scripts/engine/intensity-gate.sh -- the stage-level matrix gate"
depends_on: []
---

## Prerequisites

- `templates/intensity-metadata.md` exists (from P01) with YAML frontmatter field `intensity:` that takes values `Quick`, `Standard`, or `Full`.
- `scripts/engine/intensity-recommend.sh` exists (from P01) and emits `intensity=<level>` as its first stdout line.
- Bash 3.2+ available (macOS default). No Bash 4 features.

## Description

Create `scripts/engine/intensity-gate.sh` — the central stage x intensity matrix consumed by every pipeline command. The gate encodes a single authoritative policy: given a pipeline stage name (discuss, research, plan-phase, dispatch, verify, knowledge, auto) and an intensity level (Quick, Standard, Full), which substeps should execute and which should skip.

Command documents do NOT encode the matrix themselves; they call the gate at entry and parse its output. This guarantees the matrix stays in exactly one place (MEM014 "Scripts -> Commands" interface contract).

Output shape — two key=value lines on stdout:

```
execute_substeps=<csv>
skip_substeps=<csv>
```

Substeps are stage-scoped identifiers; their meaning is defined in the command docs (T04). Values include keywords like `all`, `none`, `tier1`, `tier1+tier2`, and stage-specific tokens.

## Steps

### Step 1 — Create scripts/engine/intensity-gate.sh

Write verbatim to `scripts/engine/intensity-gate.sh`:

```bash
#!/usr/bin/env bash
# scripts/engine/intensity-gate.sh — Stage-level intensity gate.
#
# Given a pipeline stage and an intensity level, emit the set of
# substeps to execute and the set to skip. The matrix is hardcoded
# here to guarantee a single source of truth across all command docs
# (discuss, research, plan-phase, dispatch, verify, knowledge, auto).
#
# Usage:
#   intensity-gate.sh --stage <name> --intensity <Quick|Standard|Full>
#   intensity-gate.sh --stage <name> --intensity-metadata <path-to-md>
#
# Output (stdout, key=value):
#   execute_substeps=<csv>
#   skip_substeps=<csv>
#
# Exit: 0 success, 1 invalid arguments, 2 unknown stage/intensity.
# Bash 3.2 compatible (NFR-200, MEM001).

set -u

STAGE=""
INTENSITY=""
METADATA_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage)
      STAGE="${2:-}"; shift 2 ;;
    --intensity)
      INTENSITY="${2:-}"; shift 2 ;;
    --intensity-metadata)
      METADATA_FILE="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

if [[ -z "$STAGE" ]]; then
  echo "ERROR: --stage is required" >&2
  exit 1
fi

# Resolve intensity from metadata file if --intensity not given
if [[ -z "$INTENSITY" ]] && [[ -n "$METADATA_FILE" ]]; then
  if [[ ! -f "$METADATA_FILE" ]]; then
    echo "ERROR: metadata file not found: $METADATA_FILE" >&2
    exit 1
  fi
  INTENSITY="$(grep -E '^intensity:' "$METADATA_FILE" | head -n 1 | sed -E 's/^intensity:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
fi

if [[ -z "$INTENSITY" ]]; then
  echo "ERROR: --intensity or --intensity-metadata required" >&2
  exit 1
fi

case "$INTENSITY" in
  Quick|Standard|Full) ;;
  *)
    echo "ERROR: unknown intensity '$INTENSITY' (expected Quick|Standard|Full)" >&2
    exit 2 ;;
esac

# --- Hardcoded stage x intensity matrix ---
# Substep vocabulary (stage-scoped; meaning documented in command docs):
#   discuss:    all | none | optional | required
#   research:   all | none | on-demand | pre-planning
#   plan-phase: single-task | basic-decomp | full-decomp, boundary-map
#   dispatch:   sequential | standard-payload | full-context, knowledge-inject
#   verify:     tier1 | tier2 | tier3 | tier4
#   knowledge:  summary | decision | graph-entry | rebuild-index
#   auto:       dispatch | no-pause | standard-pause | strict-pause | human-review

execute=""
skip=""

case "$STAGE" in
  discuss)
    case "$INTENSITY" in
      Quick)    execute="none";     skip="all" ;;
      Standard) execute="optional"; skip="none" ;;
      Full)     execute="required"; skip="none" ;;
    esac
    ;;
  research)
    case "$INTENSITY" in
      Quick)    execute="none";         skip="all" ;;
      Standard) execute="on-demand";    skip="pre-planning" ;;
      Full)     execute="pre-planning"; skip="none" ;;
    esac
    ;;
  plan-phase)
    case "$INTENSITY" in
      Quick)    execute="single-task";                  skip="boundary-map,full-decomp" ;;
      Standard) execute="basic-decomp,boundary-map";    skip="full-decomp" ;;
      Full)     execute="full-decomp,boundary-map";     skip="none" ;;
    esac
    ;;
  dispatch)
    case "$INTENSITY" in
      Quick)    execute="sequential";                        skip="standard-payload,full-context,knowledge-inject" ;;
      Standard) execute="standard-payload";                  skip="full-context,knowledge-inject" ;;
      Full)     execute="full-context,knowledge-inject";     skip="none" ;;
    esac
    ;;
  verify)
    case "$INTENSITY" in
      Quick)    execute="tier1";                   skip="tier2,tier3,tier4" ;;
      Standard) execute="tier1,tier2";             skip="tier3,tier4" ;;
      Full)     execute="tier1,tier2,tier3,tier4"; skip="none" ;;
    esac
    ;;
  knowledge)
    case "$INTENSITY" in
      Quick)    execute="summary";                                skip="decision,graph-entry,rebuild-index" ;;
      Standard) execute="summary,decision";                       skip="graph-entry,rebuild-index" ;;
      Full)     execute="summary,decision,graph-entry,rebuild-index"; skip="none" ;;
    esac
    ;;
  auto)
    case "$INTENSITY" in
      Quick)    execute="dispatch,no-pause";                    skip="standard-pause,strict-pause,human-review" ;;
      Standard) execute="dispatch,standard-pause";              skip="strict-pause,human-review" ;;
      Full)     execute="dispatch,strict-pause,human-review";   skip="no-pause" ;;
    esac
    ;;
  *)
    echo "ERROR: unknown stage '$STAGE' (expected discuss|research|plan-phase|dispatch|verify|knowledge|auto)" >&2
    exit 2
    ;;
esac

echo "execute_substeps=$execute"
echo "skip_substeps=$skip"
```

### Step 2 — Make executable

```bash
chmod +x scripts/engine/intensity-gate.sh
```

### Step 3 — Create scripts/verify/m008-p03-gate-arguments.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-gate.sh accepts --stage plus either --intensity or
# --intensity-metadata, and emits execute_substeps= / skip_substeps= lines.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

grep -q '\-\-stage' "$f" || { echo "FAIL: $f missing --stage"; exit 1; }
grep -q '\-\-intensity' "$f" || { echo "FAIL: $f missing --intensity"; exit 1; }
grep -q '\-\-intensity-metadata' "$f" || { echo "FAIL: $f missing --intensity-metadata"; exit 1; }
grep -q 'execute_substeps=' "$f" || { echo "FAIL: $f does not emit execute_substeps="; exit 1; }
grep -q 'skip_substeps=' "$f" || { echo "FAIL: $f does not emit skip_substeps="; exit 1; }

# Direct invocation emits both lines
out="$(bash "$f" --stage verify --intensity Standard 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=' || { echo "FAIL: direct invocation did not emit execute_substeps="; exit 1; }
echo "$out" | grep -q '^skip_substeps=' || { echo "FAIL: direct invocation did not emit skip_substeps="; exit 1; }

# Metadata-file invocation also works
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '%s\n' '---' 'intensity: "Full"' '---' > "$tmp/meta.md"
out2="$(bash "$f" --stage verify --intensity-metadata "$tmp/meta.md" 2>/dev/null)"
echo "$out2" | grep -q '^execute_substeps=' || { echo "FAIL: metadata-file invocation did not emit execute_substeps="; exit 1; }

echo "PASS: intensity-gate.sh accepts documented arguments and emits key=value output"
```

### Step 4 — Create scripts/verify/m008-p03-gate-matrix.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies the hardcoded stage x intensity matrix returns expected values
# for the critical corner cases.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# discuss Quick -> skip all
out="$(bash "$f" --stage discuss --intensity Quick 2>/dev/null)"
echo "$out" | grep -q '^skip_substeps=all' || { echo "FAIL: discuss Quick should skip=all"; exit 1; }

# discuss Full -> execute required
out="$(bash "$f" --stage discuss --intensity Full 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=required' || { echo "FAIL: discuss Full should execute=required"; exit 1; }

# verify Quick -> tier1 only
out="$(bash "$f" --stage verify --intensity Quick 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=tier1$' || { echo "FAIL: verify Quick should execute=tier1"; exit 1; }

# verify Full -> all four tiers
out="$(bash "$f" --stage verify --intensity Full 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=tier1,tier2,tier3,tier4' || { echo "FAIL: verify Full should execute all four tiers"; exit 1; }

# knowledge Quick -> summary only
out="$(bash "$f" --stage knowledge --intensity Quick 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=summary$' || { echo "FAIL: knowledge Quick should execute=summary"; exit 1; }

# knowledge Full -> full pipeline
out="$(bash "$f" --stage knowledge --intensity Full 2>/dev/null)"
echo "$out" | grep -q 'rebuild-index' || { echo "FAIL: knowledge Full should include rebuild-index"; exit 1; }

# auto Full -> human-review present
out="$(bash "$f" --stage auto --intensity Full 2>/dev/null)"
echo "$out" | grep -q 'human-review' || { echo "FAIL: auto Full should include human-review"; exit 1; }

echo "PASS: intensity matrix yields expected values for all documented corner cases"
```

### Step 5 — Create scripts/verify/m008-p03-gate-stage-coverage.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies all seven pipeline stages are handled at all three intensity
# levels with a non-empty, distinct output.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

stages="discuss research plan-phase dispatch verify knowledge auto"
levels="Quick Standard Full"

for s in $stages; do
  for l in $levels; do
    out="$(bash "$f" --stage "$s" --intensity "$l" 2>/dev/null)"
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "FAIL: stage=$s intensity=$l exited $rc"
      exit 1
    fi
    echo "$out" | grep -q '^execute_substeps=' || { echo "FAIL: stage=$s intensity=$l missing execute_substeps"; exit 1; }
    echo "$out" | grep -q '^skip_substeps=' || { echo "FAIL: stage=$s intensity=$l missing skip_substeps"; exit 1; }
  done
done

# Distinctness smoke: discuss Quick vs discuss Full must differ
q="$(bash "$f" --stage discuss --intensity Quick 2>/dev/null)"
full="$(bash "$f" --stage discuss --intensity Full 2>/dev/null)"
if [[ "$q" = "$full" ]]; then
  echo "FAIL: discuss Quick and discuss Full produce identical output (matrix not distinct)"
  exit 1
fi

echo "PASS: all 7 stages x 3 levels produce non-empty, distinct key=value output"
```

### Step 6 — Create scripts/verify/m008-p03-gate-rejects-unknown.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-gate.sh rejects unknown stages and intensities
# with non-zero exit and a stderr message.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Unknown stage
err="$(bash "$f" --stage bogus-stage --intensity Quick 2>&1 >/dev/null)"
rc=$?
if [[ $rc -eq 0 ]]; then echo "FAIL: unknown stage did not exit non-zero"; exit 1; fi
echo "$err" | grep -q 'unknown stage' || { echo "FAIL: unknown stage did not emit diagnostic on stderr"; exit 1; }

# Unknown intensity
err2="$(bash "$f" --stage verify --intensity Medium 2>&1 >/dev/null)"
rc2=$?
if [[ $rc2 -eq 0 ]]; then echo "FAIL: unknown intensity did not exit non-zero"; exit 1; fi
echo "$err2" | grep -q 'unknown intensity' || { echo "FAIL: unknown intensity did not emit diagnostic on stderr"; exit 1; }

# Missing --stage
err3="$(bash "$f" --intensity Quick 2>&1 >/dev/null)"
rc3=$?
if [[ $rc3 -eq 0 ]]; then echo "FAIL: missing --stage did not exit non-zero"; exit 1; fi

echo "PASS: intensity-gate.sh rejects unknown/missing inputs with non-zero exit and stderr"
```

### Step 7 — Make all verify scripts executable

```bash
chmod +x scripts/verify/m008-p03-gate-arguments.sh
chmod +x scripts/verify/m008-p03-gate-matrix.sh
chmod +x scripts/verify/m008-p03-gate-stage-coverage.sh
chmod +x scripts/verify/m008-p03-gate-rejects-unknown.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: gate arguments, gate matrix, gate stage coverage, gate rejects-unknown.
- **Artifacts**: `scripts/engine/intensity-gate.sh`, `scripts/verify/m008-p03-gate-arguments.sh`, `scripts/verify/m008-p03-gate-matrix.sh`, `scripts/verify/m008-p03-gate-stage-coverage.sh`, `scripts/verify/m008-p03-gate-rejects-unknown.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p03-gate-arguments.sh
bash scripts/verify/m008-p03-gate-matrix.sh
bash scripts/verify/m008-p03-gate-stage-coverage.sh
bash scripts/verify/m008-p03-gate-rejects-unknown.sh
```

All four should print `PASS:` and exit 0.

### Files Touched By This Task

- `scripts/engine/intensity-gate.sh` (create)
- `scripts/verify/m008-p03-gate-arguments.sh` (create)
- `scripts/verify/m008-p03-gate-matrix.sh` (create)
- `scripts/verify/m008-p03-gate-stage-coverage.sh` (create)
- `scripts/verify/m008-p03-gate-rejects-unknown.sh` (create)

## Inputs

### From Previous Tasks

- None. T01 is independent within P03.

### From Disk (Pre-existing)

- `templates/intensity-metadata.md` (from P01)
  - Schema: YAML frontmatter with field `intensity: "Quick|Standard|Full"`. The gate reads this field when `--intensity-metadata` is supplied.
- `scripts/engine/intensity-recommend.sh` (from P01) — not called by the gate but establishes the precedent that intensity values are literal strings `Quick`, `Standard`, `Full`.

## Constraints

- Bash 3.2 compatible — no associative arrays, no `readarray`, no `|&`, no process substitution, no brace expansion with quoted regex classes (per AD-19 and MEM001).
- Zero runtime dependencies beyond `bash`, `grep`, `sed`, `cut`, `echo`, `head`.
- Stage vocabulary is exactly: `discuss research plan-phase dispatch verify knowledge auto`. No more, no fewer. Any other stage must exit 2 with an "unknown stage" diagnostic.
- Intensity vocabulary is exactly: `Quick Standard Full`. Any other value must exit 2 with an "unknown intensity" diagnostic.
- Output format MUST be exactly two lines — `execute_substeps=<csv>` and `skip_substeps=<csv>` — with CSV tokens documented in the matrix above. No extra lines on stdout. Errors go to stderr.
- MUST NOT read or write any file other than the metadata file named by `--intensity-metadata` (and that file is read-only).
- Matrix values must match the P03 phase plan comment block verbatim. When editing, grep the phase plan first — if the matrix changed there, update it here and vice versa.

## Expected Output

After completing this task:

1. `scripts/engine/intensity-gate.sh` exists (~140 lines), executable.
2. `bash scripts/engine/intensity-gate.sh --stage verify --intensity Full` prints:
   ```
   execute_substeps=tier1,tier2,tier3,tier4
   skip_substeps=none
   ```
3. `bash scripts/engine/intensity-gate.sh --stage discuss --intensity Quick` prints:
   ```
   execute_substeps=none
   skip_substeps=all
   ```
4. `bash scripts/engine/intensity-gate.sh --stage bogus --intensity Quick` exits 2 with "unknown stage" on stderr.
5. All four verify scripts print `PASS:` and exit 0.
6. `git status` shows 5 new files under `scripts/engine/` and `scripts/verify/`.
