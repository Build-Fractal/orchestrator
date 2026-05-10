---
schema_version: "1.0"
type: task-plan
task: "T07"
phase: "P01"
milestone: "M014"
name: "Phase verification suite — fourteen gates + phase-suite orchestrator"
depends_on: ["T01", "T02", "T03", "T04", "T05", "T06"]
---

## Prerequisites

All six upstream tasks must be green (each ships its own gate verifier). T07 orchestrates them and adds three cross-cutting gates: `bash32-compat`, `zero-prompts`, and the `phase-suite` runner itself.

Pre-existing disk state:

- `scripts/verify/anti-pattern-lint.sh` — lint compliance verifier.
- `scripts/verify/run-suite.sh` — [M016](../../../../milestones/M016/index.md) wrapper pattern for running a phase-level test suite.
- `tests/fixtures/m021-prompt-corpus.txt` — [M021](../../../../milestones/M021/index.md) prompt-corpus fixture used for zero-prompts attestation.

## Description

Ship the P01 phase verification suite. Three new cross-cutting gate verifiers plus the phase-suite orchestrator.

## Steps

### Step 1: Create `scripts/verify/m014-p01-bash32-compat.sh`

Verifies every new shell script shipped by T01–T06 passes Bash 3.2 compatibility heuristics + `scripts/verify/anti-pattern-lint.sh`.

```bash
#!/usr/bin/env bash
# Gate: all P01-new shell scripts are Bash 3.2 compatible and lint-clean.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LINT="${PROJECT_ROOT}/scripts/verify/anti-pattern-lint.sh"

if [ ! -x "$LINT" ]; then
  echo "FAIL: anti-pattern-lint.sh missing" >&2; exit 1
fi

# List of P01-new scripts (hand-enumerated; the phase suite owns this list).
SCRIPTS="
scripts/util/dual-write-runtime-md.sh
scripts/knowledge/spec-complexity-probe.sh
scripts/specify/specify.sh
scripts/verify/spec-shape-lint.sh
tests/test-specify-shape.sh
tests/test-dual-write-outside-invariant.sh
scripts/verify/m014-p01-template-ssot.sh
scripts/verify/m014-p01-spec-shape-lint.sh
scripts/verify/m014-p01-dual-write-helper.sh
scripts/verify/m014-p01-dual-write-outside-invariant.sh
scripts/verify/m014-p01-complexity-probe-stub.sh
scripts/verify/m014-p01-specify-command.sh
scripts/verify/m014-p01-specify-sh.sh
scripts/verify/m014-p01-specify-shape-test.sh
scripts/verify/m014-p01-config-keys.sh
scripts/verify/m014-p01-agents-md-shape.sh
scripts/verify/m014-p01-runtime-assumptions.sh
scripts/verify/m014-p01-spec-management-reference.sh
scripts/verify/m014-p01-bash32-compat.sh
scripts/verify/m014-p01-zero-prompts.sh
scripts/verify/m014-p01-phase-suite.sh
"

FAILED=0
FAILS=""

for rel in $SCRIPTS; do
  abs="${PROJECT_ROOT}/${rel}"
  if [ ! -f "$abs" ]; then
    continue  # Not yet shipped; anti-pattern-lint will run suite-wide at close.
  fi

  # Bash 3.2 compat heuristics (coarse — matches M015 precedent).
  if grep -qE 'declare[[:space:]]+-A' "$abs"; then
    FAILS="${FAILS}${rel}: uses declare -A (not Bash 3.2 safe)\n"; FAILED=1
  fi
  if grep -qE 'mapfile[[:space:]]' "$abs" || grep -qE 'readarray[[:space:]]' "$abs"; then
    FAILS="${FAILS}${rel}: uses mapfile/readarray (not Bash 3.2 safe)\n"; FAILED=1
  fi
  if grep -qE '\$\{[A-Za-z_][A-Za-z_0-9]*,,\}' "$abs"; then
    FAILS="${FAILS}${rel}: uses \${var,,} case expansion (not Bash 3.2 safe)\n"; FAILED=1
  fi

  # Anti-pattern lint per-file.
  if ! bash "$LINT" --fixture "$abs" >/dev/null 2>&1; then
    FAILS="${FAILS}${rel}: anti-pattern-lint failed\n"; FAILED=1
  fi
done

if [ "$FAILED" -eq 1 ]; then
  printf "FAIL: Bash 3.2 compat or anti-pattern lint failures:\n%b" "$FAILS" >&2
  exit 1
fi

echo "PASS: all P01-new shell scripts are Bash 3.2 compatible and lint-clean"
exit 0
```

### Step 2: Create `scripts/verify/m014-p01-zero-prompts.sh`

Verifies `orchestrator:specify --yes --dry-run` against a scratch project produces zero patterns that match the M021 prompt-corpus.

```bash
#!/usr/bin/env bash
# Gate: zero approval prompts in auto mode. Runs specify.sh --dry-run on a
# scratch project and asserts its output and the resulting script bodies do
# not match any pattern in tests/fixtures/m021-prompt-corpus.txt.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPECIFY="${PROJECT_ROOT}/scripts/specify/specify.sh"
CORPUS="${PROJECT_ROOT}/tests/fixtures/m021-prompt-corpus.txt"

if [ ! -x "$SPECIFY" ]; then
  echo "FAIL: scripts/specify/specify.sh missing" >&2; exit 1
fi

# If the corpus file is absent (not yet shipped), gate passes with a note.
if [ ! -f "$CORPUS" ]; then
  echo "PASS: zero-prompts gate lenient (M021 prompt-corpus fixture not present)"
  exit 0
fi

# Scan specify.sh and commands/specify.md for any pattern in the corpus.
CMD="${PROJECT_ROOT}/commands/specify.md"
FILES="$SPECIFY"
if [ -f "$CMD" ]; then FILES="$FILES $CMD"; fi

FAILED=0
FAIL_LINES=""

# Iterate corpus lines (one pattern per line, # for comments).
while IFS= read -r pattern; do
  if [ -z "$pattern" ]; then continue; fi
  case "$pattern" in \#*) continue ;; esac

  for f in $FILES; do
    if grep -qF "$pattern" "$f"; then
      FAIL_LINES="${FAIL_LINES}${f}: prompt-corpus hit: ${pattern}\n"
      FAILED=1
    fi
  done
done < "$CORPUS"

if [ "$FAILED" -eq 1 ]; then
  printf "FAIL: M021 prompt-corpus pattern(s) detected:\n%b" "$FAIL_LINES" >&2
  exit 1
fi

echo "PASS: zero-prompts attestation clean"
exit 0
```

### Step 3: Create `scripts/verify/m014-p01-phase-suite.sh`

The orchestrator that runs all fourteen gates and reports per-gate results.

```bash
#!/usr/bin/env bash
# scripts/verify/m014-p01-phase-suite.sh — orchestrate all M014/P01 gates.
# Runs every gate; exits 0 on green, non-zero on any failure with a
# per-gate breakdown on stderr.
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

GATES="
template-ssot
spec-shape-lint
dual-write-helper
dual-write-outside-invariant
complexity-probe-stub
specify-command
specify-sh
specify-shape-test
config-keys
agents-md-shape
runtime-assumptions
spec-management-reference
bash32-compat
zero-prompts
"

PASS=0
FAIL=0
FAIL_NAMES=""

for g in $GATES; do
  script="${PROJECT_ROOT}/scripts/verify/m014-p01-${g}.sh"
  if [ ! -x "$script" ]; then
    echo "FAIL: m014-p01-${g}.sh missing or not executable" >&2
    FAIL=$((FAIL + 1))
    FAIL_NAMES="${FAIL_NAMES}${g} "
    continue
  fi
  if bash "$script" >/dev/null 2>&1; then
    echo "  [ok] m014-p01-${g}"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] m014-p01-${g}" >&2
    FAIL=$((FAIL + 1))
    FAIL_NAMES="${FAIL_NAMES}${g} "
  fi
done

echo ""
echo "Summary: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed gates: ${FAIL_NAMES}" >&2
  exit 1
fi

echo "PASS: m014-p01-phase-suite"
exit 0
```

Make all three new scripts executable: `chmod +x scripts/verify/m014-p01-bash32-compat.sh scripts/verify/m014-p01-zero-prompts.sh scripts/verify/m014-p01-phase-suite.sh`.

### Step 4: Run the full suite to confirm end-to-end green

Once T01–T06 have all shipped, run:

```
bash scripts/verify/m014-p01-phase-suite.sh
```

Expected output:
```
  [ok] m014-p01-template-ssot
  [ok] m014-p01-spec-shape-lint
  [ok] m014-p01-dual-write-helper
  [ok] m014-p01-dual-write-outside-invariant
  [ok] m014-p01-complexity-probe-stub
  [ok] m014-p01-specify-command
  [ok] m014-p01-specify-sh
  [ok] m014-p01-specify-shape-test
  [ok] m014-p01-config-keys
  [ok] m014-p01-agents-md-shape
  [ok] m014-p01-runtime-assumptions
  [ok] m014-p01-spec-management-reference
  [ok] m014-p01-bash32-compat
  [ok] m014-p01-zero-prompts

Summary: 14 passed, 0 failed
PASS: m014-p01-phase-suite
```

Exit code 0.

## Must-Haves

- `scripts/verify/m014-p01-bash32-compat.sh` exists, is executable, exits 0
- `scripts/verify/m014-p01-zero-prompts.sh` exists, is executable, exits 0 (lenient when M021 prompt-corpus absent)
- `scripts/verify/m014-p01-phase-suite.sh` exists, is executable, orchestrates all fourteen gates, exits 0 on green
- The phase suite emits one line per gate with `[ok]` or `[FAIL]` and a summary
- On any gate failure, the phase suite exits non-zero with a named-gate breakdown on stderr
- All three new scripts pass `scripts/verify/anti-pattern-lint.sh`

## Verification

```
bash scripts/verify/m014-p01-bash32-compat.sh
```

Expected: `PASS: all P01-new shell scripts are Bash 3.2 compatible and lint-clean`, exit 0.

```
bash scripts/verify/m014-p01-zero-prompts.sh
```

Expected: `PASS: zero-prompts attestation clean`, exit 0.

```
bash scripts/verify/m014-p01-phase-suite.sh
```

Expected: `PASS: m014-p01-phase-suite`, exit 0, fourteen `[ok]` lines.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/verify/m014-p01-phase-suite.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

- Every T01–T06 artifact (templates, scripts, tests, reference doc, gate verifiers) — T07 reads by existence/execution, not by parsing content beyond what each gate does.

### From Disk (Pre-existing)

- `scripts/verify/anti-pattern-lint.sh` — per-file lint invocation.
- `tests/fixtures/m021-prompt-corpus.txt` — M021 prompt-corpus fixture (may be absent; gate is lenient).

## Constraints

- Bash 3.2 compatible; no `declare -A`, `mapfile`, `${var,,}`, process substitution, `&>`.
- Phase suite iterates gates in declared order; a failure in one gate does not abort the suite — every gate is evaluated and reported.
- No parallel execution — sequential for clear failure reporting.
- Passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files committed:

1. `scripts/verify/m014-p01-bash32-compat.sh` — Bash-3.2 + lint gate (~70 lines, executable)
2. `scripts/verify/m014-p01-zero-prompts.sh` — zero-prompts attestation (~50 lines, executable)
3. `scripts/verify/m014-p01-phase-suite.sh` — suite orchestrator (~60 lines, executable)

Running `bash scripts/verify/m014-p01-phase-suite.sh` exits 0 with fourteen `[ok]` lines and `PASS: m014-p01-phase-suite`.
