#!/usr/bin/env bash
# tools/verify/m041-p03-phase-suite.sh -- M041 P03 phase-close gate suite.
#
# Aggregates all m041-p03-* verifiers (excluding itself) and emits
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
  local name="$1"
  bash "tools/verify/$name" 2>/dev/null
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    pass=$((pass + 1))
    printf 'OK: %s\n' "$name"
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n' "$name"
  fi
}

# Discover and run all m041-p03-* verifiers except this script
self="$(basename "${BASH_SOURCE[0]}")"
for gate in "$SCRIPT_DIR"/m041-p03-*.sh; do
  name="$(basename "$gate")"
  [ "$name" = "$self" ] && continue
  run_gate "$name"
done

# ---------- Aggregate summary ----------
printf 'SUITE: pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
