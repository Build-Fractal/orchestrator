#!/usr/bin/env bash
# tools/verify/m041-p02-phase-suite.sh -- M041 P02 phase-close gate suite.
#
# Aggregates all m041-p02-* verifiers (excluding itself) and emits
# a SUITE summary line. Exits 1 if any sub-gate fails.
#
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

pass=0
fail=0

run_gate() {
  name="$1"
  bash "tools/verify/$name" 2>/dev/null
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass=$(( pass + 1 ))
    printf 'OK: %s\n' "$name"
  else
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$name"
  fi
}

# ---------- Gate 1: search-issues-mock ----------
run_gate "m041-p02-search-issues-mock.sh"

# ---------- Gate 2: file-issue-mock ----------
run_gate "m041-p02-file-issue-mock.sh"

# ---------- Gate 3: gh-degradation ----------
run_gate "m041-p02-gh-degradation.sh"

# ---------- Gate 4: mock-substitution ----------
run_gate "m041-p02-mock-substitution.sh"

# ---------- Gate 5: file-issue-comment ----------
run_gate "m041-p02-file-issue-comment.sh"

# ---------- Aggregate summary ----------
printf 'SUITE: pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
