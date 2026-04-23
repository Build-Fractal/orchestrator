---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P02"
milestone: "M014"
name: "P02 phase verification suite — nine gates + suite orchestrator + lint-and-bash32 gate"
depends_on: ["T01", "T02", "T03", "T04", "T05"]
---

## Prerequisites

- T01 shipped `scripts/verify/m014-p02-write-site-manifest.sh`.
- T02 shipped `scripts/verify/m014-p02-init-dual-write.sh` and `scripts/verify/m014-p02-reinit-dual-write.sh`.
- T03 shipped `scripts/verify/m014-p02-consolidate-dual-write.sh`.
- T04 shipped `scripts/verify/m014-p02-check-docs-drift.sh`, `scripts/verify/m014-p02-run-doctor-drift-section.sh`, `scripts/verify/m014-p02-doctor-md.sh`.
- T05 shipped `scripts/verify/m014-p02-migration-idempotent.sh`.
- `scripts/verify/anti-pattern-lint.sh` exists from M016. `scripts/verify/m014-p01-bash32-compat.sh` precedent exists from M014/P01/T07.
- P01 precedent: `scripts/verify/m014-p01-phase-suite.sh` chains all P01 gates and exits 0 on green, non-zero with per-gate breakdown on failure.

## Description

Ship the P02 phase-suite orchestrator plus the omnibus `lint-and-bash32` gate. Together these bring P02's gate count to nine:

1. `m014-p02-write-site-manifest.sh` (T01)
2. `m014-p02-init-dual-write.sh` (T02)
3. `m014-p02-reinit-dual-write.sh` (T02)
4. `m014-p02-consolidate-dual-write.sh` (T03)
5. `m014-p02-check-docs-drift.sh` (T04)
6. `m014-p02-run-doctor-drift-section.sh` (T04)
7. `m014-p02-doctor-md.sh` (T04)
8. `m014-p02-migration-idempotent.sh` (T05)
9. `m014-p02-lint-and-bash32.sh` (T06 — this task)

The lint-and-bash32 gate runs `anti-pattern-lint.sh` across every P02-modified script plus a Bash 3.2 compatibility scan (same forbidden-token set as P01: `declare -A`, `mapfile`, `${var,,}`, `${var^^}`, `<(...)`, `&>`).

The phase-suite orchestrator chains all nine gates, reports `PASS:` / `FAIL:` per gate, exits 0 on green, exits 1 with a per-gate breakdown otherwise.

## Steps

### Step 1: Create `scripts/verify/m014-p02-lint-and-bash32.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: every P02-modified/created shell script passes anti-pattern-lint
# and is Bash 3.2 compatible (no forbidden tokens).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LINT="${PROJECT_ROOT}/scripts/verify/anti-pattern-lint.sh"

if [ ! -x "$LINT" ]; then
  echo "FAIL: anti-pattern-lint.sh missing or not executable" >&2; exit 1
fi

# P02-touched files.
FILES="scripts/lifecycle/init-project.sh
scripts/lifecycle/reinit-handler.sh
scripts/knowledge/consolidate-artifacts.sh
scripts/diagnostics/check-docs.sh
scripts/diagnostics/run-doctor.sh
scripts/migrate/m014-p02-migrate-recent-changes.sh
scripts/verify/m014-p02-write-site-manifest.sh
scripts/verify/m014-p02-init-dual-write.sh
scripts/verify/m014-p02-reinit-dual-write.sh
scripts/verify/m014-p02-consolidate-dual-write.sh
scripts/verify/m014-p02-check-docs-drift.sh
scripts/verify/m014-p02-run-doctor-drift-section.sh
scripts/verify/m014-p02-doctor-md.sh
scripts/verify/m014-p02-migration-idempotent.sh
scripts/verify/m014-p02-lint-and-bash32.sh
scripts/verify/m014-p02-phase-suite.sh"

failed=0

# --- Anti-pattern lint pass ---
for f in $FILES; do
  path="$PROJECT_ROOT/$f"
  if [ ! -f "$path" ]; then
    echo "FAIL: missing file: $f" >&2
    failed=$((failed + 1))
    continue
  fi
  if ! bash "$LINT" --fixture "$path" >/dev/null 2>&1; then
    echo "FAIL: anti-pattern-lint rejected: $f" >&2
    failed=$((failed + 1))
  fi
done

# --- Bash 3.2 compat scan ---
# Forbidden tokens: declare -A, mapfile, ${var,,}, ${var^^}, <(...), &>.
# We scan each file; the scanner itself self-excludes (diagnostic strings match).
SELF="$(basename "${BASH_SOURCE[0]}")"

for f in $FILES; do
  # Skip self (diagnostic strings contain the forbidden tokens as literals).
  bname="$(basename "$f")"
  if [ "$bname" = "$SELF" ]; then continue; fi

  # Also skip anti-pattern-lint.sh itself and the m014-p01 bash32 gate which have
  # similar self-exemption needs (both scan for tokens and would match themselves).
  if [ "$bname" = "anti-pattern-lint.sh" ]; then continue; fi

  path="$PROJECT_ROOT/$f"
  if [ ! -f "$path" ]; then continue; fi

  # declare -A
  if grep -nE '^[[:space:]]*declare[[:space:]]+-A' "$path" >/dev/null 2>&1; then
    echo "FAIL: declare -A found in $f" >&2
    failed=$((failed + 1))
  fi
  # mapfile
  if grep -nE '^[[:space:]]*mapfile([[:space:]]|$)' "$path" >/dev/null 2>&1; then
    echo "FAIL: mapfile found in $f" >&2
    failed=$((failed + 1))
  fi
  # ${var,,} / ${var^^}
  if grep -nE '\$\{[A-Za-z_][A-Za-z0-9_]*,,' "$path" >/dev/null 2>&1; then
    echo "FAIL: \${var,,} found in $f" >&2
    failed=$((failed + 1))
  fi
  if grep -nE '\$\{[A-Za-z_][A-Za-z0-9_]*\^\^' "$path" >/dev/null 2>&1; then
    echo "FAIL: \${var^^} found in $f" >&2
    failed=$((failed + 1))
  fi
  # Process substitution <(...)
  if grep -nE '<\([^)]' "$path" >/dev/null 2>&1; then
    echo "FAIL: process substitution <(...) found in $f" >&2
    failed=$((failed + 1))
  fi
  # &>
  if grep -nE '&>' "$path" >/dev/null 2>&1; then
    echo "FAIL: &> redirect found in $f" >&2
    failed=$((failed + 1))
  fi
done

if [ "$failed" -gt 0 ]; then
  echo "FAIL: $failed lint/bash32 violations" >&2
  exit 1
fi

echo "PASS: anti-pattern-lint + bash32-compat green across all P02 files"
exit 0
```

Make executable.

### Step 2: Create `scripts/verify/m014-p02-phase-suite.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# M014/P02 phase verification suite — chains all nine P02 gates.
# Exit 0 on green; exit 1 with per-gate breakdown on failure.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GATES="m014-p02-write-site-manifest.sh
m014-p02-init-dual-write.sh
m014-p02-reinit-dual-write.sh
m014-p02-consolidate-dual-write.sh
m014-p02-check-docs-drift.sh
m014-p02-run-doctor-drift-section.sh
m014-p02-doctor-md.sh
m014-p02-migration-idempotent.sh
m014-p02-lint-and-bash32.sh"

passed=0
failed=0
total=0
failed_list=""

for g in $GATES; do
  total=$((total + 1))
  path="$SCRIPT_DIR/$g"
  if [ ! -x "$path" ]; then
    echo "FAIL: gate missing or not executable: $g" >&2
    failed=$((failed + 1))
    failed_list="${failed_list}  - $g (missing)
"
    continue
  fi

  if bash "$path" >/dev/null 2>&1; then
    passed=$((passed + 1))
    echo "PASS: $g"
  else
    failed=$((failed + 1))
    echo "FAIL: $g" >&2
    failed_list="${failed_list}  - $g
"
  fi
done

echo ""
echo "M014/P02 phase suite: $passed / $total gates passed"

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "Failed gates:"
  printf '%s' "$failed_list"
  exit 1
fi

exit 0
```

Make executable.

## Must-Haves

- `scripts/verify/m014-p02-lint-and-bash32.sh` exists, is executable, scans all 16 P02-touched files for anti-pattern and Bash 3.2 compat violations, reports per-violation lines to stderr, exits 0 only when every scanned file is clean
- `scripts/verify/m014-p02-phase-suite.sh` exists, is executable, chains all nine gates in declared order, emits one `PASS:` / `FAIL:` line per gate, reports the summary line `M014/P02 phase suite: <P> / 9 gates passed`, exits 0 on green and 1 otherwise with a failed-gate breakdown
- Running the phase suite after T01-T05 ship produces `PASS: m014-p02-*` for all nine gates and exits 0
- The lint-and-bash32 gate self-exempts (its diagnostic strings contain the forbidden tokens as literals)
- Both new gate scripts pass `anti-pattern-lint.sh`

## Verification

```
bash scripts/verify/m014-p02-lint-and-bash32.sh
```

Expected: `PASS: anti-pattern-lint + bash32-compat green across all P02 files`, exit 0.

```
bash scripts/verify/m014-p02-phase-suite.sh
```

Expected (on green):

```
PASS: m014-p02-write-site-manifest.sh
PASS: m014-p02-init-dual-write.sh
PASS: m014-p02-reinit-dual-write.sh
PASS: m014-p02-consolidate-dual-write.sh
PASS: m014-p02-check-docs-drift.sh
PASS: m014-p02-run-doctor-drift-section.sh
PASS: m014-p02-doctor-md.sh
PASS: m014-p02-migration-idempotent.sh
PASS: m014-p02-lint-and-bash32.sh

M014/P02 phase suite: 9 / 9 gates passed
```

Exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/verify/m014-p02-phase-suite.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

- `scripts/verify/m014-p02-write-site-manifest.sh` (T01)
- `scripts/verify/m014-p02-init-dual-write.sh` (T02)
- `scripts/verify/m014-p02-reinit-dual-write.sh` (T02)
- `scripts/verify/m014-p02-consolidate-dual-write.sh` (T03)
- `scripts/verify/m014-p02-check-docs-drift.sh` (T04)
- `scripts/verify/m014-p02-run-doctor-drift-section.sh` (T04)
- `scripts/verify/m014-p02-doctor-md.sh` (T04)
- `scripts/verify/m014-p02-migration-idempotent.sh` (T05)

All invoked by the phase suite as `bash $SCRIPT_DIR/<gate-name>.sh >/dev/null 2>&1`; exit 0 on green.

### From Disk (Pre-existing)

- `scripts/verify/anti-pattern-lint.sh` — invoked by the lint-and-bash32 gate as `bash "$LINT" --fixture <file>`.
- `scripts/verify/m014-p01-phase-suite.sh` — P01 precedent for the suite orchestrator shape (chained gate invocation, per-gate PASS/FAIL line, summary, exit code).

## Constraints

- Bash 3.2 compatible. Uses `for` over whitespace-split strings (not arrays), plain `if`, `grep`, `echo` — no process substitution, no `$( ... | ... )` with inner pipe.
- The lint-and-bash32 gate self-exempts its own file because its diagnostic strings contain the forbidden tokens literally (precedent: M016/P03 `lint-self-excludes.sh`, M014/P01/T07 `m014-p01-bash32-compat.sh`).
- The phase suite MUST invoke each gate in a fresh subshell (plain `bash <path>`) so gate-local state (traps, scratch dirs) doesn't leak between gates.
- Passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files created:

1. `scripts/verify/m014-p02-lint-and-bash32.sh` (~95 lines, executable)
2. `scripts/verify/m014-p02-phase-suite.sh` (~50 lines, executable)

Both scripts pass anti-pattern-lint; phase suite exits 0 with all nine gates green.
