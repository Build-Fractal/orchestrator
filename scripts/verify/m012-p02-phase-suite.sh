#!/usr/bin/env bash
# scripts/verify/m012-p02-phase-suite.sh — orchestrates all nine M012/P02 gates.
#
# Runs each gate script as a subprocess, aggregates results, emits one
# `GATE: <name> PASS|FAIL` line per gate to stdout, and prints a
# `SUMMARY: <passed>/<total> gates passed` line to stderr.
#
# Exit 0 iff all nine gates exit 0. SKIP: outputs from mkdocs-dependent gates
# map to PASS at the gate boundary (the gate itself exits 0 on SKIP).
#
# Bash 3.2 compatible. Uses parallel indexed variables (not Bash 4 arrays).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

TMP_LOG="/tmp/m012-p02-phase-suite-$$.log"
trap 'rm -f "$TMP_LOG"' EXIT INT TERM

gates_0="m012-p02-link-rewrite-config.sh"
gates_1="m012-p02-mem-stubs.sh"
gates_2="m012-p02-mem-anchors.sh"
gates_3="m012-p02-link-check-contract.sh"
gates_4="m012-p02-link-check-help.sh"
gates_5="m012-p02-readme-policy.sh"
gates_6="m012-p02-link-check-smoke.sh"
gates_7="m012-p02-bash32-compat.sh"
gates_8="m012-p02-d011-evaluation.sh"
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
  if bash "$gate_path" "$ROOT" > "$TMP_LOG" 2>&1; then
    printf 'GATE: %s PASS\n' "$g"
    PASSED=$((PASSED + 1))
  else
    printf 'GATE: %s FAIL\n' "$g"
    sed 's/^/  /' "$TMP_LOG" >&2
  fi
  i=$((i + 1))
done

printf 'SUMMARY: %d/%d gates passed\n' "$PASSED" "$TOTAL" >&2

if [ "$PASSED" -eq "$TOTAL" ]; then
  exit 0
fi
exit 1
