---
schema_version: "1.0"
type: task-plan
task: "T07"
phase: "P01"
milestone: "M013"
name: "Phase verification suite — nine gates + phase-suite orchestrator"
depends_on: ["T01", "T02", "T03", "T04", "T05", "T06"]
---

## Prerequisites

- All T01–T06 gate scripts created and passing individually:
  - `scripts/verify/m013-p01-sidecar-schema.sh` (T01)
  - `scripts/verify/m013-p01-github-status.sh` (T02)
  - `scripts/verify/m013-p01-github-status-command.sh` (T02)
  - `scripts/verify/m013-p01-uat-template.sh` (T03)
  - `scripts/verify/m013-p01-rebuild-index-additive.sh` (T04)
  - `scripts/verify/m013-p01-defect-schema.sh` (T05)
  - `scripts/verify/m013-p01-uat-ingest.sh` (T05)
  - `scripts/verify/m013-p01-reference-skeleton.sh` (T06)
- Existing infra: `scripts/verify/run-suite.sh` (from M016/P02) is the repo's canonical suite runner; it discovers gate scripts by filename pattern `m<milestone>-p<phase>-*.sh`. The phase-suite orchestrator this task ships is a **local** orchestrator — it runs the nine gates in a fixed order and emits a consolidated summary.
- Existing infra: `scripts/verify/anti-pattern-lint.sh` (M016/M021 invariant) — the bash32-compat gate piggybacks on this.

## Description

Close the phase by shipping two final gates plus the phase-suite orchestrator:

1. **`scripts/verify/m013-p01-bash32-compat.sh`** — verifies every `.sh` file created or modified by P01 passes the repo's `anti-pattern-lint.sh` and has no Bash-4-only constructs (`declare -A`, `mapfile`, `${var^^}`, `<(...)`, `&>`). Reuses the M021 pattern established in `scripts/verify/m021-p01-bash32-compat.sh`.

2. **`scripts/verify/m013-p01-phase-suite.sh`** — orchestrator gate. Invokes all nine P01 gate scripts in dependency-respecting order, captures each gate's exit code, prints a consolidated summary, and exits 0 only when every gate passes. This is the canonical "P01 is done" mechanical check.

## Steps

### Step 1: Create `scripts/verify/m013-p01-bash32-compat.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p01-bash32-compat.sh — Verify every P01 shell script
# is Bash 3.2 compatible and anti-pattern-lint clean.
#
# Exits 0 when all scripts pass, 1 otherwise.
# Bash 3.2 compatible.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0
assert_ok() { if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $2"; fail_count=$((fail_count + 1)); fi; }

# List of files touched or created by P01.
P01_FILES="
scripts/integrations/sidecar-init-pending.sh
scripts/integrations/github-status.sh
scripts/integrations/uat-ingest.sh
scripts/knowledge/rebuild-index.sh
scripts/verify/m013-p01-sidecar-schema.sh
scripts/verify/m013-p01-github-status.sh
scripts/verify/m013-p01-github-status-command.sh
scripts/verify/m013-p01-uat-template.sh
scripts/verify/m013-p01-rebuild-index-additive.sh
scripts/verify/m013-p01-defect-schema.sh
scripts/verify/m013-p01-uat-ingest.sh
scripts/verify/m013-p01-reference-skeleton.sh
scripts/verify/m013-p01-bash32-compat.sh
scripts/verify/m013-p01-phase-suite.sh
"

# Bash-4-only constructs to catch. Each pattern is a grep -E regex.
# declare -A / mapfile / ${var^^} / ${var,,} / <(...) / >(...) / &> redirection.
BAD_PATTERNS="
declare[[:space:]]+-A
\\bmapfile\\b
\\$\\{[A-Za-z_][A-Za-z0-9_]*\\^\\^
\\$\\{[A-Za-z_][A-Za-z0-9_]*,,
<\\(
>\\(
&>
"

IFS='
'
for f in $P01_FILES; do
  IFS=' '
  [ -n "$f" ] || continue
  path="${REPO_ROOT}/${f}"
  if [ ! -f "$path" ]; then
    # Some P01 files may not exist until this task's implementation; verify gate
    # is designed to run after all upstream tasks complete. Missing is a FAIL.
    echo "FAIL: ${f} missing"
    fail_count=$((fail_count + 1))
    IFS='
'
    continue
  fi
  IFS='
'
  for p in $BAD_PATTERNS; do
    IFS=' '
    [ -n "$p" ] || continue
    if grep -En "$p" "$path" >/dev/null 2>&1; then
      echo "FAIL: ${f} contains bash4-only pattern: ${p}"
      fail_count=$((fail_count + 1))
    fi
    IFS='
'
  done
  IFS='
'
done
IFS=' '

# Run anti-pattern-lint across P01 files.
LINT="${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh"
if [ -x "$LINT" ] || [ -f "$LINT" ]; then
  IFS='
'
  for f in $P01_FILES; do
    IFS=' '
    [ -n "$f" ] || continue
    path="${REPO_ROOT}/${f}"
    [ -f "$path" ] || continue
    bash "$LINT" --target "$f" >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "FAIL: ${f} fails anti-pattern-lint.sh"
      fail_count=$((fail_count + 1))
    fi
    IFS='
'
  done
  IFS=' '
else
  echo "SKIP: anti-pattern-lint.sh not present (unexpected; M016/M021 invariant)"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m013-p01-bash32-compat.sh ($fail_count failures)"
exit 1
```

### Step 2: Create `scripts/verify/m013-p01-phase-suite.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p01-phase-suite.sh — Orchestrate all P01 gate scripts.
#
# Exits 0 when every gate passes; non-zero with a per-gate breakdown otherwise.
# Bash 3.2 compatible.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VDIR="${REPO_ROOT}/scripts/verify"

# Ordered gate list. Order reflects dependency graph:
# T01 → T02 → T03 → T04 → T05 → T06 → T07.
GATES="
m013-p01-sidecar-schema.sh
m013-p01-github-status.sh
m013-p01-github-status-command.sh
m013-p01-uat-template.sh
m013-p01-rebuild-index-additive.sh
m013-p01-defect-schema.sh
m013-p01-uat-ingest.sh
m013-p01-reference-skeleton.sh
m013-p01-bash32-compat.sh
"

passed=0
failed=0
failures=""

IFS='
'
for g in $GATES; do
  IFS=' '
  [ -n "$g" ] || continue
  path="${VDIR}/${g}"
  if [ ! -f "$path" ]; then
    echo "FAIL: gate missing: ${g}"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  ${g}: missing"
    IFS='
'
    continue
  fi

  bash "$path" > "/tmp/m013-p01-${g}.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "GATE-PASS: ${g}"
    passed=$((passed + 1))
  else
    echo "GATE-FAIL: ${g} (rc=${rc})"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  ${g}: rc=${rc} (see /tmp/m013-p01-${g}.out)"
  fi
  IFS='
'
done
IFS=' '

echo ""
echo "SUMMARY: passed=${passed} failed=${failed}"

if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p01-phase-suite.sh"
  exit 0
fi
echo "FAIL: m013-p01-phase-suite.sh"
printf '%s\n' "$failures"
exit 1
```

### Step 3: Smoke-run the suite

After creating both scripts, run `bash scripts/verify/m013-p01-phase-suite.sh`. Expected output: nine `GATE-PASS:` lines, `SUMMARY: passed=9 failed=0`, `PASS: m013-p01-phase-suite.sh`, exit 0.

If any individual gate fails during the smoke run, return to that task (T01–T06) to fix — do NOT patch the orchestrator to mask a failure.

## Must-Haves

- `scripts/verify/m013-p01-bash32-compat.sh` exists and checks every P01 `.sh` file for Bash-4-only constructs + runs `anti-pattern-lint.sh` against each.
- `scripts/verify/m013-p01-phase-suite.sh` exists and runs all nine P01 gates in dependency order, exits 0 iff all pass.
- Smoke run reports `SUMMARY: passed=9 failed=0` and exits 0.

## Verification

- `bash scripts/verify/m013-p01-bash32-compat.sh`
- `bash scripts/verify/m013-p01-phase-suite.sh`

## Inputs

### From Previous Tasks

- All P01 gate scripts (T01–T06). See Prerequisites.

### From Disk (Pre-existing)

- `scripts/verify/anti-pattern-lint.sh` — M016/M021 invariant. Consumed by the bash32-compat gate.
- `scripts/verify/run-suite.sh` — repo-wide suite runner (M016). The phase-suite orchestrator this task ships is a **local** orchestrator scoped to P01; it does not replace `run-suite.sh`. Both can coexist — `run-suite.sh m013 P01` and `m013-p01-phase-suite.sh` should produce the same PASS/FAIL verdict (structural equivalence invariant, not mechanically verified here).
- Reference precedents: `scripts/verify/m021-p01-bash32-compat.sh`, `scripts/verify/m019-p01-phase-suite.sh` — same-shape gates in prior milestones.

## Constraints

- Bash 3.2 compatible (no associative arrays, no `mapfile`, no process substitution). The suite orchestrator itself must be Bash-3.2 clean — the bash32-compat gate will self-check this.
- Single-script-file shape (AD-19) for both `Check:` commands. The gate scripts above are exactly that — `bash scripts/verify/m013-p01-<name>.sh` — no compound chains.
- **Fail loud, not silent**: when any gate fails, the orchestrator reports the failing gate name, the exit code, and the path to the captured output file. No silent-success paths.
- **Dependency order matters**: the suite invokes gates in T01→T07 order. If T01 fails (schema contract missing), T02 (`github-status.sh`) will also fail — the suite surfaces both failures so the operator sees the root cause in the first `GATE-FAIL:` line.
- **Do not modify upstream gates**: if a gate needs to change, edit the original task's verify script. This task only ships the bash32-compat gate and the orchestrator.
- **No network calls**: P01 is entirely offline. No gate script invokes `gh`, `curl`, or any other network tool.

## Expected Output

- `scripts/verify/m013-p01-bash32-compat.sh` created.
- `scripts/verify/m013-p01-phase-suite.sh` created.
- `bash scripts/verify/m013-p01-bash32-compat.sh` → `PASS: m013-p01-bash32-compat.sh`, exit 0.
- `bash scripts/verify/m013-p01-phase-suite.sh` → nine `GATE-PASS:` lines, `SUMMARY: passed=9 failed=0`, `PASS: m013-p01-phase-suite.sh`, exit 0.
