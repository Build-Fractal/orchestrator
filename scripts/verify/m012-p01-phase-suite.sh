#!/usr/bin/env bash
# scripts/verify/m012-p01-phase-suite.sh — orchestrates the M012/P01 gates.
#
# Runs each gate script as a subprocess and aggregates results.
# Emits one `GATE: <name> PASS|FAIL` line per gate to stdout.
# Prints `SUMMARY: <passed>/<total> gates passed` at end (stderr).
# Exit 0 iff all gates exit 0.
#
# m012-p01-index-placeholder.sh was retired at M012 close: T01 (P04)
# finalized wiki/docs/index.md as a 65-line home page, inverting the
# gate's original assertion ("contains 'placeholder' and <= 30 lines").
# Its intent ("P01 ships a placeholder stub") was satisfied at P01
# close; the long-term home-page surface is now covered by
# scripts/verify/m012-p04-index-finalized.sh and m012-p04-index-ssot.sh.
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
gates_7="m012-p01-bash32-compat.sh"
TOTAL=8

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
