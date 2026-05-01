#!/usr/bin/env bash
# tests/m031-acceptance/test-budget-drift-warning.sh
# M031/P04/T03 — AD-19 QUICK_BUDGET_DRIFT informational warning acceptance
# test for scripts/diagnostics/efficiency-footer.sh.
#
# Constructs two 7-record fixture JSONL streams of payload_breakdown shape
# (profile + knowledge_section_tokens fields).
#
#   trip stream — 7 quick records each with knowledge_section_tokens=1000.
#   Default budget 800 -> threshold 880 -> median 1000 > 880 -> trigger fires.
#
#   safe stream — 7 quick records each with knowledge_section_tokens=700.
#   Threshold 880 -> median 700 < 880 -> trigger does NOT fire.
#
# Each fixture is piped through scripts/diagnostics/efficiency-footer.sh via
# the ORCH_EFFICIENCY_FOOTER_INPUT env override seam. The trip case must
# emit the QUICK_BUDGET_DRIFT literal substring on stdout/stderr; the safe
# case must NOT emit it.
#
# Envelope: emits PASS:/FAIL: per-check + final RESULT: AD-19 pass / RESULT:
# AD-19 fail (mirrors the M031 P01/P02/P03 acceptance-test envelope
# convention). Bash 3.2 compatible.

set -u

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FOOTER="$PROJECT_ROOT/scripts/diagnostics/efficiency-footer.sh"

if [ ! -f "$FOOTER" ]; then
  printf 'FAIL: efficiency-footer.sh not found at %s\n' "$FOOTER"
  printf 'RESULT: AD-19 fail\n'
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

trip_stream="$work/trip.jsonl"
safe_stream="$work/safe.jsonl"

# Trip fixture: 7 quick records with knowledge_section_tokens=1000 each.
i=1
while [ "$i" -le 7 ]; do
  printf '{"profile":"quick","knowledge_section_tokens":1000}\n' >>"$trip_stream"
  i=$((i + 1))
done

# Safe fixture: 7 quick records with knowledge_section_tokens=700 each.
i=1
while [ "$i" -le 7 ]; do
  printf '{"profile":"quick","knowledge_section_tokens":700}\n' >>"$safe_stream"
  i=$((i + 1))
done

pass=0
fail=0

# Run trip fixture; expect QUICK_BUDGET_DRIFT to appear.
trip_out=$(ORCH_EFFICIENCY_FOOTER_INPUT="$trip_stream" bash "$FOOTER" --project 2>&1 || true)
if printf '%s\n' "$trip_out" | grep -qF -- "QUICK_BUDGET_DRIFT"; then
  printf 'PASS: trip fixture emits QUICK_BUDGET_DRIFT (median=1000 > threshold=880)\n'
  pass=$((pass + 1))
else
  printf 'FAIL: trip fixture missing QUICK_BUDGET_DRIFT\n'
  fail=$((fail + 1))
fi

# Run safe fixture; expect QUICK_BUDGET_DRIFT to be absent.
safe_out=$(ORCH_EFFICIENCY_FOOTER_INPUT="$safe_stream" bash "$FOOTER" --project 2>&1 || true)
if printf '%s\n' "$safe_out" | grep -qF -- "QUICK_BUDGET_DRIFT"; then
  printf 'FAIL: safe fixture unexpectedly emits QUICK_BUDGET_DRIFT (median=700 < threshold=880)\n'
  fail=$((fail + 1))
else
  printf 'PASS: safe fixture suppresses QUICK_BUDGET_DRIFT (median=700 < threshold=880)\n'
  pass=$((pass + 1))
fi

printf 'AD-19 totals: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'RESULT: AD-19 pass\n'
  exit 0
fi
printf 'RESULT: AD-19 fail\n'
exit 1
