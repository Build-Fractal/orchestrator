---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P03"
milestone: "M013"
name: "Phase verification suite — bash32-compat + phase-suite orchestrator"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01-T04 complete. The following gate scripts exist and individually exit 0:
  - `scripts/verify/m013-p03-re-init-fixture.sh` (T01)
  - `scripts/verify/m013-p03-github-common-readopt.sh` (T01)
  - `scripts/verify/m013-p03-re-init-adoption.sh` (T02)
  - `scripts/verify/m013-p03-re-init-auto-mode.sh` (T02)
  - `scripts/verify/m013-p03-graphql-call-shape-selftest.sh` (T03)
  - `scripts/verify/m013-p03-reference-extensions.sh` (T04)
- The P02 phase-suite orchestrator at `scripts/verify/m013-p02-phase-suite.sh` is the shape precedent: list of gates, `IFS`-based newline iteration, per-gate capture file under `/tmp`, PASS/FAIL counter + final SUMMARY line `SUMMARY: m013-p02-phase-suite.sh pass=N fail=M`.
- The P02 bash32-compat gate at `scripts/verify/m013-p02-bash32-compat.sh` (created by P02/T07) is the shape precedent: enumerate every M013-touched shell file, scan for forbidden tokens (`declare -A`, `mapfile`, `readarray`, `<(`, `>(`, `&>`, `|&`, `${var^^}`, `${var,,}`), emit PASS/FAIL per file. Includes a comment-discipline pattern for synonyms so the gate's own file doesn't trip its own scanner.
- `scripts/verify/anti-pattern-lint.sh` (M016/M021) is a repo-wide prompt-corpus lint. The bash32-compat gate invokes it on the M013/P03 files.
- Integer-minutes duration in T05-SUMMARY.md.

## Description

Three deliverables:

1. **`scripts/verify/m013-p03-bash32-compat.sh`** — mirror P02/T07's shape. Enumerate every `.sh` file touched or created by P03 (T01's `github-common.sh` extension, T02's `github-init.sh` extension, the new `graphql-call-shape.sh` lint from T03, and every `m013-p03-*.sh` gate). For each: (a) `bash -n` parse check, (b) grep for forbidden Bash 3.2 patterns with self-exclusion, (c) invoke `scripts/verify/anti-pattern-lint.sh` on the file.

2. **`scripts/verify/m013-p03-phase-suite.sh`** — orchestrator invoking the seven P03 gates in dependency order. Capture per-gate stdout/stderr to `/tmp/m013-p03-<gate>.out`. Emit consolidated `SUMMARY:` line + per-gate PASS/FAIL.

3. **Assertion backfills** (if needed) — after T01-T04 lands, re-run each P03 gate and confirm exit 0. If any gate has ambiguity or flakiness not apparent during its authoring task, T05 backfills tighter assertions or relaxes over-strict checks.

## Steps

### Step 1: Create `scripts/verify/m013-p03-bash32-compat.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p03-bash32-compat.sh — Bash 3.2 compatibility gate for P03 files.
#
# For each P03-touched or P03-created shell file:
#   1. bash -n parse check
#   2. grep for forbidden tokens (declare -A, mapfile, readarray, process
#      substitution, combined-redirect shorthand, case-conversion expansion)
#   3. scripts/verify/anti-pattern-lint.sh per-file invocation
#
# Self-exclusion: this gate's own file contains the forbidden-token comments
# (assoc-arrays, array-from-stdin, case-conversion expansion, combined-redirect
# shorthand). The scanner excludes its own filename via a case-branch.
#
# Invariant: MEM001, Constitution IX, Constitution XV, SC-6.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Files to scan. Mix of modified P02 files (github-common.sh, github-init.sh)
# and P03-new files. The modified P02 files are included because T01/T02
# touched them additively — the gate re-verifies post-touch cleanliness.
P03_FILES="
scripts/integrations/github-common.sh
scripts/integrations/github-init.sh
scripts/verify/graphql-call-shape.sh
scripts/verify/m013-p03-re-init-fixture.sh
scripts/verify/m013-p03-github-common-readopt.sh
scripts/verify/m013-p03-re-init-adoption.sh
scripts/verify/m013-p03-re-init-auto-mode.sh
scripts/verify/m013-p03-graphql-call-shape-selftest.sh
scripts/verify/m013-p03-reference-extensions.sh
scripts/verify/m013-p03-bash32-compat.sh
scripts/verify/m013-p03-phase-suite.sh
"

IFS='
'
for f in $P03_FILES; do
  IFS=' '
  [ -n "$f" ] || continue
  path="${REPO_ROOT}/${f}"
  if [ ! -f "$path" ]; then
    fail "${f} missing"
    IFS='
'
    continue
  fi

  # bash -n parse check.
  if bash -n "$path" 2>/dev/null; then
    pass "bash -n: ${f}"
  else
    fail "bash -n: ${f}"
  fi

  # Forbidden-token scan. Self-exclusion: skip this very file.
  case "$f" in
    scripts/verify/m013-p03-bash32-compat.sh)
      pass "forbidden-token scan: ${f} (self-excluded)"
      ;;
    *)
      # assoc-arrays synonym; array-from-stdin synonym; process substitution;
      # case-conversion expansion; combined-redirect shorthand.
      if grep -nE '\bdeclare[[:space:]]+-A\b|\b(mapfile|readarray)\b|<\(|>\(|&>|\|&|\$\{[A-Za-z_][A-Za-z_0-9]*\^\^?\}|\$\{[A-Za-z_][A-Za-z_0-9]*,,?\}' "$path" >/dev/null 2>&1; then
        fail "forbidden-token scan: ${f} (see grep output above)"
      else
        pass "forbidden-token scan: ${f}"
      fi
      ;;
  esac

  # anti-pattern-lint per-file.
  if bash "${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh" "$path" >/dev/null 2>&1; then
    pass "anti-pattern-lint: ${f}"
  else
    fail "anti-pattern-lint: ${f}"
  fi

  IFS='
'
done
IFS=' '

echo "SUMMARY: m013-p03-bash32-compat.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m013-p03-bash32-compat.sh" >&2
exit 1
```

### Step 2: Create `scripts/verify/m013-p03-phase-suite.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p03-phase-suite.sh — Orchestrate all M013/P03 gate scripts.
#
# Invokes every phase-P03 gate script in dependency-respecting order
# (T01 fixture → T01 helper → T02 adoption → T02 auto-mode → T03 lint →
#  T04 reference → T05 bash32-compat), captures each gate's exit code +
# stdout/stderr to a per-gate capture file under /tmp, and emits a
# consolidated summary with PASS/FAIL counts.
#
# Exits 0 only when every gate passes. Failing gates are reported with
# gate name, exit code, and capture-file path.
#
# Also re-runs the P02 phase suite as a regression guard — P02 byte-identity
# is load-bearing for P03's additive extension claim.
#
# Bash 3.2 compatible.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VDIR="${REPO_ROOT}/scripts/verify"

GATES="
m013-p03-re-init-fixture.sh
m013-p03-github-common-readopt.sh
m013-p03-re-init-adoption.sh
m013-p03-re-init-auto-mode.sh
m013-p03-graphql-call-shape-selftest.sh
m013-p03-reference-extensions.sh
m013-p03-bash32-compat.sh
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
  capture="/tmp/m013-p03-${g}.out"

  if [ ! -f "$path" ]; then
    echo "FAIL: ${g} (missing)"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  ${g}: missing at ${path}"
    IFS='
'
    continue
  fi

  bash "$path" > "$capture" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PASS: ${g}"
    passed=$((passed + 1))
  else
    echo "FAIL: ${g} (rc=${rc}, see ${capture})"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  ${g}: rc=${rc} (see ${capture})"
  fi
  IFS='
'
done
IFS=' '

# P02 regression guard.
p02_suite="${VDIR}/m013-p02-phase-suite.sh"
p02_capture="/tmp/m013-p03-p02-regression.out"
if [ -f "$p02_suite" ]; then
  bash "$p02_suite" > "$p02_capture" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PASS: m013-p02-phase-suite.sh (regression guard)"
    passed=$((passed + 1))
  else
    echo "FAIL: m013-p02-phase-suite.sh (regression guard, rc=${rc}, see ${p02_capture})"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  m013-p02-phase-suite.sh: REGRESSION rc=${rc}"
  fi
fi

echo "SUMMARY: m013-p03-phase-suite.sh pass=${passed} fail=${failed}"

if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-phase-suite.sh"
  exit 0
fi

echo "FAIL: m013-p03-phase-suite.sh" >&2
printf '%s\n' "$failures" >&2
exit 1
```

### Step 3: Chmod both to executable

```bash
chmod +x scripts/verify/m013-p03-bash32-compat.sh
chmod +x scripts/verify/m013-p03-phase-suite.sh
```

### Step 4: Run the full phase suite and observe all-green

Invoke `bash scripts/verify/m013-p03-phase-suite.sh`. Expected output: 7 PASS lines for the P03 gates + 1 PASS for the P02 regression guard + the self-named SUMMARY + final PASS.

If any gate fails during the suite run (not during its individual authoring task), diagnose via the per-gate capture file at `/tmp/m013-p03-<gate>.out`. Common failure modes:

- **Byte-identity regression**: P02 fixture gate fails because T02's additive change somehow altered the P02 fixture output — re-inspect the `manifest_footer` optional-4th-arg branch.
- **Section-content hash mismatch**: P02 reference-extensions gate fails — T04's edits touched a P01/P02 section. Inspect which section's hash changed and revert the edit.
- **Anti-pattern-lint**: M021 prompt-corpus triggered by a new `Check:` wording — adjust the task-plan wording or the gate script to avoid the trigger pattern.

## Must-Haves

From P03-PLAN:

- `scripts/verify/m013-p03-bash32-compat.sh` exists (≥30 lines, contains `declare -A` as a scan pattern), passes on every P03 file.
- `scripts/verify/m013-p03-phase-suite.sh` exists (≥50 lines, contains `m013-p03`), orchestrates all P03 gates + the P02 regression guard.
- The SUMMARY line uses the self-named form `SUMMARY: m013-p03-phase-suite.sh pass=N fail=M` (P02's shape).
- The full suite exits 0 after T05 lands.

## Verification

```bash
bash scripts/verify/m013-p03-bash32-compat.sh
bash scripts/verify/m013-p03-phase-suite.sh
```

Both exit 0. The phase-suite run is the P03 done-check.

## Inputs

### From Previous Tasks

- All seven P03 gates from T01-T04 (see Prerequisites list).
- `scripts/integrations/github-common.sh` (from P03/T01 addition)
- `scripts/integrations/github-init.sh` (from P03/T02 re-init branch)
- `scripts/verify/graphql-call-shape.sh` (from P03/T03)
- `references/github-integration.md` (from P03/T04 extensions)

### From Disk (Pre-existing)

- `scripts/verify/m013-p02-phase-suite.sh` (from M013/P02/T07)
  - Shape precedent + regression guard. T05's phase-suite invokes this as the final regression check.
- `scripts/verify/m013-p02-bash32-compat.sh` (from M013/P02/T07)
  - Shape precedent. T05's bash32-compat gate mirrors the structure with the `P03_FILES` list.
- `scripts/verify/anti-pattern-lint.sh` (M016/M021 invariant)
  - Invoked per-file by the bash32-compat gate.

## Constraints

- **Self-exclusion on bash32-compat**: the gate's own file contains the forbidden-token strings (for scanning). Self-exclusion via `case "$f" in ... self-excluded;;` branch is mandatory (mirror of P02/T07's pattern with comment-discipline synonyms: assoc-arrays, array-from-stdin, case-conversion expansion, combined-redirect shorthand).
- **P02 regression guard is load-bearing**: the phase suite MUST invoke the P02 phase suite and require it exit 0. This is the enforcement surface for the "P02 byte-identity preserved" claim.
- **AD-19 `Check:` shape**: all verification commands are single-script-file invocations.
- **SUMMARY line shape**: `SUMMARY: m013-p03-phase-suite.sh pass=N fail=M` — self-named form (P02's convention, not P01's).
- **Bash 3.2**: no `declare -A`, no `mapfile`, no process substitution, no combined-redirect shorthand. Parallel indexed arrays only.
- **Knowledge-Layer Boundary (D014)**: no knowledge/spec/ writes.
- **Integer-minutes duration** in T05-SUMMARY.md.

## Expected Output

```
PASS: m013-p03-re-init-fixture.sh
PASS: m013-p03-github-common-readopt.sh
PASS: m013-p03-re-init-adoption.sh
PASS: m013-p03-re-init-auto-mode.sh
PASS: m013-p03-graphql-call-shape-selftest.sh
PASS: m013-p03-reference-extensions.sh
PASS: m013-p03-bash32-compat.sh
PASS: m013-p02-phase-suite.sh (regression guard)
SUMMARY: m013-p03-phase-suite.sh pass=8 fail=0
PASS: m013-p03-phase-suite.sh
```

Estimated duration: 35 integer minutes.
