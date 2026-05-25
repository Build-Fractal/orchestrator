#!/usr/bin/env bash
# tools/verify/m041-p01-phase-suite.sh -- M041 P01 phase-close gate suite.
#
# Aggregates all m041-p01-* verifiers (excluding itself) and emits
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

# ---------- Gate 1: triage-report-sections ----------
run_gate "m041-p01-triage-report-sections.sh"

# ---------- Gate 2: suggest-fix-unconditional ----------
run_gate "m041-p01-suggest-fix-unconditional.sh"

# ---------- Gate 3: suggest-fix-heuristic ----------
run_gate "m041-p01-suggest-fix-heuristic.sh"

# ---------- Gate 4: pipe-input ----------
run_gate "m041-p01-pipe-input.sh"

# ---------- Gate 5: command-shape ----------
run_gate "m041-p01-command-shape.sh"

# ---------- Gate 6: report-frontmatter ----------
run_gate "m041-p01-report-frontmatter.sh"

# ---------- Aggregate summary ----------
printf 'SUITE: pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
