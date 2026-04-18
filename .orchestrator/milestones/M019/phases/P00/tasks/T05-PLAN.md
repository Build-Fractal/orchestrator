---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P00"
milestone: "M019"
name: "Phase verify-suite: author m019-p00-no-regression.sh (wraps tests/test-s01..s07 + anti-pattern-lint + m021 P04), m019-p00-bash32-compat.sh (scans all P00-touched .sh files), and m019-p00-phase-suite.sh (orchestrates the four P00 gates). Establishes P00's `completed_at` epoch for P01's no-pre-p00-emission gate (SC-12)."
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

All four upstream tasks have completed:

- T01 → `scripts/dispatch/build-context.sh` emits L1/L2/L4 markers; `scripts/verify/m019-p00-payload-shape.sh` exists + executable.
- T02 → `templates/dispatch-prompt.md` has positive-form expressive guidance; `scripts/engine/intensity-gate.sh` has L3 contract comment; `templates/.p00-negative-guidance-retained.txt` exists.
- T03 → `scripts/lifecycle/write-permissions.sh` MODE=overwrite is sentinel-scoped; `scripts/lifecycle/apply-sentinel-overwrite.sh` exists; `.claude/settings.json` retrofitted with sentinels; `scripts/verify/m019-p00-evaluate-preflight-additivity.sh` exists + executable.
- T04 → `.orchestrator/config/pricing.yml` exists.

Repository pre-existing state:

- `tests/test-s01.sh` through `tests/test-s07.sh` — seven test suites (ship the repo's 334+ assertions per CLAUDE.md). Each exits 0 on all-pass.
- `scripts/verify/anti-pattern-lint.sh` — M016/M021 anti-pattern linter. Scans for 10 Class-A patterns. Exits 0 on clean.
- `scripts/verify/run-suite.sh` — suite runner. Invocation: `bash scripts/verify/run-suite.sh <milestone> <phase>`. Discovers `m###-p##-*.sh` gates and reports PASS: N / FAIL: M.

## Description

Author three verify scripts:

1. **`scripts/verify/m019-p00-no-regression.sh`** — load-bearing SC-13 regression gate. Invokes every pre-existing test suite, the anti-pattern linter, and the M021 P04 suite. Exits 0 only when all green.
2. **`scripts/verify/m019-p00-bash32-compat.sh`** — Constitution VIII compliance gate. Scans every `.sh` file authored or modified in P00 for forbidden Bash-4 constructs; runs `bash -n` on each for syntax validity.
3. **`scripts/verify/m019-p00-phase-suite.sh`** — orchestrator gate. Invokes the four P00 gates in order and reports PASS: 4 / FAIL: 0.

T05 also runs the phase-suite once to confirm P00 is green and to establish the `completed_at` epoch (the phase-suite's successful exit timestamp becomes P01's no-pre-p00-emission reference).

## Steps

### Step 1: Author `scripts/verify/m019-p00-no-regression.sh`

**File:** `scripts/verify/m019-p00-no-regression.sh` (new, executable)

Complete script:

```bash
#!/usr/bin/env bash
# scripts/verify/m019-p00-no-regression.sh — SC-13 regression guard.
#
# Invokes every pre-existing test suite + anti-pattern linter + M021 P04
# suite against the P00-adapted codebase. Exits 0 only when all green.
# This gate proves adaptation did not change what the orchestrator does,
# only how its dispatches are phrased.
#
# Exit 0 on all-pass, 1 on any failure. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# --- Gate 1..7: test-s01..test-s07 suites ---
for n in 01 02 03 04 05 06 07; do
  suite="$REPO_ROOT/tests/test-s${n}.sh"
  # Some test-s*.sh files have variant names (e.g., test-s04-core-commands.sh).
  # Glob-resolve the canonical name.
  if [ ! -f "$suite" ]; then
    candidate="$(ls "$REPO_ROOT"/tests/test-s${n}-*.sh 2>/dev/null | head -1)"
    [ -n "$candidate" ] && suite="$candidate"
  fi
  if [ ! -f "$suite" ]; then
    fail "suite s${n} file exists" "no tests/test-s${n}*.sh found"
    continue
  fi
  log="$(mktemp -t m019-p00-s${n}.XXXXXX)"
  if bash "$suite" >"$log" 2>&1; then
    pass "test-s${n} suite green"
  else
    fail "test-s${n} suite" "non-zero exit; log at $log"
    tail -20 "$log" >&2
  fi
done

# --- Gate 8: anti-pattern linter ---
if bash "$REPO_ROOT/scripts/verify/anti-pattern-lint.sh" >/dev/null 2>&1; then
  pass "anti-pattern-lint green"
else
  fail "anti-pattern-lint" "non-zero exit"
fi

# --- Gate 9: M021 P04 suite ---
if bash "$REPO_ROOT/scripts/verify/run-suite.sh" m021 P04 >/dev/null 2>&1; then
  pass "m021 P04 suite green"
else
  fail "m021 P04 suite" "non-zero exit from run-suite.sh m021 P04"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m019-p00-no-regression.sh"
  exit 0
else
  echo "FAIL: m019-p00-no-regression.sh ($fail_count failures)"
  exit 1
fi
```

Make executable.

### Step 2: Author `scripts/verify/m019-p00-bash32-compat.sh`

**File:** `scripts/verify/m019-p00-bash32-compat.sh` (new, executable)

The gate enumerates every `.sh` file P00 authored or modified and asserts (a) `bash -n` parses clean, (b) no forbidden constructs appear.

Complete script:

```bash
#!/usr/bin/env bash
# scripts/verify/m019-p00-bash32-compat.sh — Constitution VIII compliance gate.
#
# Scans every .sh file authored or modified by P00 for Bash-4-only
# constructs and confirms bash -n parses each file.
#
# Exit 0 on clean, 1 on any violation. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# P00 touched/created .sh files
FILES="
scripts/dispatch/build-context.sh
scripts/engine/intensity-gate.sh
scripts/lifecycle/write-permissions.sh
scripts/lifecycle/generate-permissions.sh
scripts/lifecycle/apply-sentinel-overwrite.sh
scripts/verify/m019-p00-payload-shape.sh
scripts/verify/m019-p00-evaluate-preflight-additivity.sh
scripts/verify/m019-p00-no-regression.sh
scripts/verify/m019-p00-bash32-compat.sh
scripts/verify/m019-p00-phase-suite.sh
"

for rel in $FILES; do
  f="$REPO_ROOT/$rel"
  if [ ! -f "$f" ]; then
    fail "file exists" "$rel"
    continue
  fi
  # (a) bash -n parse
  if bash -n "$f" 2>/dev/null; then
    pass "$rel parses clean"
  else
    fail "$rel parses clean" "bash -n failed"
  fi
  # (b) forbidden constructs
  if grep -q 'declare -A' "$f"; then
    fail "$rel no declare -A" "found"
  fi
  if grep -qE '\bmapfile\b' "$f"; then
    fail "$rel no mapfile" "found"
  fi
  if grep -qE '\breadarray\b' "$f"; then
    fail "$rel no readarray" "found"
  fi
  if grep -qE '\$\{[A-Za-z_][A-Za-z0-9_]*,,\}' "$f"; then
    fail "$rel no \${var,,}" "found"
  fi
  if grep -qE '\$\{[A-Za-z_][A-Za-z0-9_]*\^\^\}' "$f"; then
    fail "$rel no \${var^^}" "found"
  fi
  if grep -qE '\$\{\![A-Za-z_][A-Za-z0-9_]*\*\}' "$f"; then
    fail "$rel no \${!prefix*}" "found"
  fi
  # Process substitution: match '<(' or '>(' that is NOT part of a comment
  if grep -vE '^[[:space:]]*#' "$f" | grep -qE '<\(|>\('; then
    fail "$rel no process substitution" "found <( or >("
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m019-p00-bash32-compat.sh"
  exit 0
else
  echo "FAIL: m019-p00-bash32-compat.sh ($fail_count failures)"
  exit 1
fi
```

Make executable.

### Step 3: Author `scripts/verify/m019-p00-phase-suite.sh`

**File:** `scripts/verify/m019-p00-phase-suite.sh` (new, executable)

Complete script:

```bash
#!/usr/bin/env bash
# scripts/verify/m019-p00-phase-suite.sh — P00 phase integration gate.
#
# Orchestrates the four P00 verify gates:
#   1. m019-p00-payload-shape.sh      — L1..L5 + pricing.yml presence
#   2. m019-p00-evaluate-preflight-additivity.sh — AD-7 byte-identical preservation
#   3. m019-p00-no-regression.sh      — SC-13 regression guard
#   4. m019-p00-bash32-compat.sh      — Constitution VIII compliance
#
# Reports PASS: 4 / FAIL: 0 on green. Exit 0 on all-pass, 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GATES="
scripts/verify/m019-p00-payload-shape.sh
scripts/verify/m019-p00-evaluate-preflight-additivity.sh
scripts/verify/m019-p00-no-regression.sh
scripts/verify/m019-p00-bash32-compat.sh
"

pass_count=0
fail_count=0
for rel in $GATES; do
  f="$REPO_ROOT/$rel"
  if [ ! -x "$f" ]; then
    echo "FAIL: $rel (not executable)"
    fail_count=$((fail_count + 1))
    continue
  fi
  if bash "$f" >/dev/null 2>&1; then
    echo "PASS: $rel"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $rel"
    fail_count=$((fail_count + 1))
  fi
done

total=$((pass_count + fail_count))
echo "PASS: $pass_count / FAIL: $fail_count (of $total P00 gates)"
if [ "$fail_count" -eq 0 ] && [ "$pass_count" -eq 4 ]; then
  echo "PASS: m019-p00-phase-suite.sh"
  exit 0
else
  echo "FAIL: m019-p00-phase-suite.sh"
  exit 1
fi
```

Make executable.

### Step 4: Run the phase-suite to confirm P00 is green

Run:

```
bash scripts/verify/m019-p00-phase-suite.sh
```

Expected terminal output (on success):

```
PASS: scripts/verify/m019-p00-payload-shape.sh
PASS: scripts/verify/m019-p00-evaluate-preflight-additivity.sh
PASS: scripts/verify/m019-p00-no-regression.sh
PASS: scripts/verify/m019-p00-bash32-compat.sh
PASS: 4 / FAIL: 0 (of 4 P00 gates)
PASS: m019-p00-phase-suite.sh
```

Exit 0.

If any gate fails, do not attempt to paper over the failure in the phase-suite script — the failure must surface so the upstream task can be corrected. T05's deliverable is the three new gate scripts + confirmed green phase-suite run; not patching over regressions.

## Must-Haves

- `scripts/verify/m019-p00-no-regression.sh` exists + executable + exits 0 when test-s01..s07 + anti-pattern-lint + m021 P04 all green.
- `scripts/verify/m019-p00-bash32-compat.sh` exists + executable + exits 0 when every P00-touched `.sh` file parses clean and contains no forbidden constructs.
- `scripts/verify/m019-p00-phase-suite.sh` exists + executable + reports `PASS: 4 / FAIL: 0` and exits 0.
- All three scripts themselves pass the bash32-compat gate (the gate scans itself).

## Verification

Single command:

```
bash scripts/verify/m019-p00-phase-suite.sh
```

Expected: exit 0, final line `PASS: m019-p00-phase-suite.sh`. P01's no-pre-p00-emission gate uses this gate's success timestamp as the ordering epoch (SC-12).

Also run each gate individually to confirm standalone invocation works:

```
bash scripts/verify/m019-p00-no-regression.sh
bash scripts/verify/m019-p00-bash32-compat.sh
```

Each exits 0 with `PASS:` final line.

## Inputs

### From Previous Tasks

- `scripts/dispatch/build-context.sh` (from T01) — modified file scanned by bash32-compat gate.
- `templates/dispatch-prompt.md` (from T01/T02) — no direct gate input; enforced via payload-shape gate which no-regression runs transitively only through test-s suites' shape assertions.
- `scripts/engine/intensity-gate.sh` (from T02) — modified file scanned by bash32-compat gate.
- `scripts/lifecycle/write-permissions.sh` + `scripts/lifecycle/generate-permissions.sh` + `scripts/lifecycle/apply-sentinel-overwrite.sh` (from T03) — modified/created files scanned by bash32-compat gate.
- `scripts/verify/m019-p00-payload-shape.sh` (from T01) — invoked by phase-suite gate.
- `scripts/verify/m019-p00-evaluate-preflight-additivity.sh` (from T03) — invoked by phase-suite gate.
- `.orchestrator/config/pricing.yml` (from T04) — consumed transitively via payload-shape gate Gate 6.

### From Disk (Pre-existing)

- `tests/test-s01.sh` through `tests/test-s07.sh` — invoked by no-regression gate.
- `scripts/verify/anti-pattern-lint.sh` — invoked by no-regression gate.
- `scripts/verify/run-suite.sh` — invoked by no-regression gate (for M021 P04).

## Constraints

- **Bash 3.2 compat** across all three gate scripts (the bash32-compat gate scans itself).
- **Single-script-file invocation** at every `Check:` call site (AD-19). All four P00 gates are single-script invocations.
- **No test suite modification.** T05 wraps but does not modify `tests/test-s*.sh` — they must pass as-is against adapted templates per SC-13.
- **Phase-suite reports PASS: 4 / FAIL: 0 literal string** — P00-PLAN.md Artifacts check requires this literal text.
- **Hermetic.** Gates must run without network access and without modifying the repo (no writes outside `$TMPDIR`).
- **No parallelization inside the phase suite.** Gates run serially because their stdout order must be deterministic for downstream consumers.
- **Phase-suite success == P00 `completed_at` epoch.** P01's `scripts/verify/m019-p01-no-pre-p00-emission.sh` reads `P00-SUMMARY.md`'s `completed_at` frontmatter to enforce SC-12. T05's deliverable makes that epoch definable — the SUMMARY itself is written by the phase-close workflow, not T05.

## Expected Output

After T05:

- Three new gate scripts exist + executable under `scripts/verify/`.
- `bash scripts/verify/m019-p00-phase-suite.sh` exits 0, reports `PASS: 4 / FAIL: 0` and `PASS: m019-p00-phase-suite.sh` as the last two output lines.
- The phase's standard close workflow can now be invoked to write `P00-SUMMARY.md` and advance M019 state to `P01 planning`.
- P01's no-pre-p00-emission gate has its epoch reference in place.
