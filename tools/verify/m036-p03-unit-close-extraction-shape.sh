#!/usr/bin/env bash
# tools/verify/m036-p03-unit-close-extraction-shape.sh -- M036 P03 T02.
# Drives extract_tier_2_emit_unit_close in a mktemp -d workspace and
# asserts the resulting JSONL line carries the required M030 unit_close
# fields. Bash 3.2 / POSIX-sh per CON-2. Single-script-file shape.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/lib/extract-tier-2-llm.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-unitclose.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
fail=0
if [ ! -f "$LIB" ]; then
  echo "FAIL: helper lib missing $LIB"
  echo "SUMMARY: m036-p03-unit-close-extraction-shape.sh fail=1"
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"
ORCHESTRATOR_ROOT="$WORK" extract_tier_2_emit_unit_close "verifier-cite-01" "claude-haiku-4-5" 100 200 0.005 0.95
LOG="$WORK/.orchestrator/execution-log.jsonl"
if [ ! -f "$LOG" ]; then
  echo "FAIL: log not created at $LOG"
  fail=$((fail + 1))
else
  echo "PASS: log created at $LOG"
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$LOG"; then
    echo "PASS: '$pat' in unit_close JSONL"
  else
    echo "FAIL: '$pat' missing in unit_close JSONL"
    fail=$((fail + 1))
  fi
}
checkpat '"event":"unit_close"'
checkpat '"task_type":"extraction"'
checkpat '"model":"claude-haiku-4-5"'
checkpat '"cite_id":"verifier-cite-01"'
checkpat '"cost_usd":0.005'
checkpat '"tokens_in":100'
checkpat '"tokens_out":200'
echo "SUMMARY: m036-p03-unit-close-extraction-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
