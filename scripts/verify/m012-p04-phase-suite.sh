#!/usr/bin/env bash
# scripts/verify/m012-p04-phase-suite.sh — orchestrates all eleven M012/P04 gates.
#
# Runs each gate script as a subprocess, aggregates results, emits one
# `GATE: <name> PASS|FAIL` line per gate to stdout, and prints a
# `SUMMARY: <passed>/<total> gates passed` line to stderr.
# Exit 0 iff all eleven gates exit 0.
#
# Gate 11 (`m012-p04-summary-walkthrough.sh`) is accept-on-absent: it
# emits `SKIP:` and exits 0 when `P04-SUMMARY.md` is not yet written
# (phase-close artifact). The orchestrator treats any exit-0 gate as
# PASS regardless of its stdout terminator.
#
# Bash 3.2 compatible. Parallel indexed variables (mirrors the P02/P03
# phase-suite pattern). First positional arg (optional) overrides the
# project root.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

TMP_LOG="/tmp/m012-p04-phase-suite-$$.log"
# shellcheck disable=SC2064
trap "rm -f '$TMP_LOG'" EXIT INT TERM

gates_0="m012-p04-index-finalized.sh"
gates_1="m012-p04-index-ssot.sh"
gates_2="m012-p04-readme-first-deploy.sh"
gates_3="m012-p04-deploy-wrapper-contract.sh"
gates_4="m012-p04-deploy-wrapper-help.sh"
gates_5="m012-p04-deploy-wrapper-dry-run.sh"
gates_6="m012-p04-deploy-wrapper-loud-fail.sh"
gates_7="m012-p04-deploy-record.sh"
gates_8="m012-p04-bash32-compat.sh"
gates_9="m012-p04-wiki-removable.sh"
gates_10="m012-p04-summary-walkthrough.sh"
TOTAL=11

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
