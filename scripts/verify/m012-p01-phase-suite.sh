#!/usr/bin/env bash
# scripts/verify/m012-p01-phase-suite.sh — orchestrates all nine M012/P01 gates.
#
# Runs each gate script as a subprocess and aggregates results.
# Emits one `GATE: <name> PASS|FAIL` line per gate to stdout.
# Prints `SUMMARY: <passed>/<total> gates passed` at end (stderr).
# Exit 0 iff all nine gates exit 0.
#
# Bash 3.2 compatible. Single-script-file shape (no compound bash).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

TMP_LOG="/tmp/m012-p01-phase-suite-$$.log"
trap 'rm -f "$TMP_LOG"' EXIT INT TERM

gates_0="m012-p01-wiki-self-contained.sh"
gates_1="m012-p01-requirements-pinned.sh"
gates_2="m012-p01-include-plugin.sh"
gates_3="m012-p01-ssot.sh"
gates_4="m012-p01-exclusion-policy.sh"
gates_5="m012-p01-nav-structure.sh"
gates_6="m012-p01-serve-smoke.sh"
gates_7="m012-p01-index-placeholder.sh"
gates_8="m012-p01-bash32-compat.sh"
TOTAL=9

PASSED=0
i=0
while [ "$i" -lt "$TOTAL" ]; do
  eval "g=\$gates_${i}"
  gate_path="$ROOT/scripts/verify/$g"
  if [ ! -f "$gate_path" ]; then
    printf 'GATE: %s FAIL (script missing)\n' "$g"
    i=$((i + 1))
    continue
  fi
  if bash "$gate_path" > "$TMP_LOG" 2>&1; then
    printf 'GATE: %s PASS\n' "$g"
    PASSED=$((PASSED + 1))
  else
    printf 'GATE: %s FAIL\n' "$g"
    # Echo the gate's output to stderr for debuggability.
    sed 's/^/  /' "$TMP_LOG" >&2
  fi
  i=$((i + 1))
done

printf 'SUMMARY: %d/%d gates passed\n' "$PASSED" "$TOTAL" >&2

if [ "$PASSED" -eq "$TOTAL" ]; then
  exit 0
fi
exit 1
