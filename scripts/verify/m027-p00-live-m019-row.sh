#!/usr/bin/env bash
# scripts/verify/m027-p00-live-m019-row.sh — M027/P00 FR-1 / FR-4 / SC-1.
#
# Runs the rollup CLI against this repo's live M019 execution-log.jsonl
# at --granularity milestone --milestone M019. Asserts:
#   - exit 0
#   - stdout contains exactly one milestone-row line
#   - that row carries both a cost token (numeric or `(N missing)`) AND
#     a quality token (numeric PASS_RATE) — FR-4 Goodhart pairing.
#
# Graceful: if the live log is missing or empty, emits SKIP and exits 0
# (fresh clones still pass; fixture-based verifiers cover the same contract).
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-live-m019-row.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
LIVE_LOG="$PROJECT_ROOT/.orchestrator/milestones/M019/execution-log.jsonl"

if [ ! -r "$ROLLUP" ]; then
  printf 'FAIL: %s rollup-missing at=%s\n' "$NAME" "$ROLLUP" >&2
  exit 1
fi

if [ ! -f "$LIVE_LOG" ] || [ ! -s "$LIVE_LOG" ]; then
  printf 'SKIP: live M019 log not present at %s\n' "$LIVE_LOG"
  printf 'PASS: %s skip-fresh-clone\n' "$NAME"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

out="$tmp/out"
err="$tmp/err"
bash "$ROLLUP" --granularity milestone --milestone M019 >"$out" 2>"$err"
rc=$?

if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s rollup exited %d (expected 0)\n' "$NAME" "$rc" >&2
  cat "$err" >&2 || true
  exit 1
fi

# Count milestone-data rows. A milestone-data row starts with the literal
# token "milestone " followed by an Mxxx scope. The header line starts with
# GRANULARITY so it's filtered out by the prefix match.
row_count="$(grep -c '^milestone[[:space:]][[:space:]]*M019' "$out" || true)"
if [ "$row_count" -ne 1 ]; then
  printf 'FAIL: %s expected 1 milestone-row got %s\n' "$NAME" "$row_count" >&2
  cat "$out" >&2 || true
  exit 1
fi

row="$(grep '^milestone[[:space:]][[:space:]]*M019' "$out" | head -n 1)"

# Cost token — must look like a numeric or include "(N missing)".
has_cost=0
case "$row" in
  *missing*) has_cost=1 ;;
esac
if [ "$has_cost" -eq 0 ]; then
  if printf '%s' "$row" | awk '{ for (i=4;i<=NF;i++) if ($i ~ /^-?[0-9]+\.[0-9]+$/) { print "yes"; exit } }' | grep -q yes; then
    has_cost=1
  fi
fi

# Quality token — locate a PASS_RATE numeric (4-decimal) or "unknown".
has_quality=0
if printf '%s' "$row" | awk '{ for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9]{4}$/ || $i == "unknown") { print "yes"; exit } }' | grep -q yes; then
  has_quality=1
fi

if [ "$has_cost" -eq 0 ] || [ "$has_quality" -eq 0 ]; then
  printf 'FAIL: %s row missing cost(%d) or quality(%d) tokens\n' "$NAME" "$has_cost" "$has_quality" >&2
  printf 'row: %s\n' "$row" >&2
  exit 1
fi

printf 'PASS: %s live-row paired cost+quality\n' "$NAME"
exit 0
