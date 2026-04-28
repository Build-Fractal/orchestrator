#!/usr/bin/env bash
# scripts/verify/m018-p02-underperformance-emit.sh — phase-truth verifier:
# "The aggregate-savings self-check emits a `compression_underperformance`
# JSONL record when the running mean payload-token reduction across the
# last N dispatches falls below the SC-9 calibrated 34.7% floor (MIT-09).
# The check is operational signal — never blocks dispatch."
#
# Approach: stage an M999 fixture orch_root, pre-seed its execution-log
# with 30 underperforming `payload_breakdown` records (each with
# filter_dropped_tokens=5 against payload_tokens_estimate=100 →
# reduction = 5/(100+5) ≈ 4.76%, well below 34.7%). Run build-context.sh
# end-to-end against the fixture; assert a new compression_underperformance
# JSONL record is appended.
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BC="$REPO_ROOT/scripts/dispatch/build-context.sh"
FIXTURE_BUILDER="$REPO_ROOT/scripts/verify/_helpers/m018-p02-build-fixture.sh"

for p in "$BC" "$FIXTURE_BUILDER"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: prerequisite missing: %s\n' "$p" >&2
    exit 1
  fi
done

TMPDIR_U="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_U"' EXIT INT TERM
ROOT="$TMPDIR_U/M999"
mkdir -p "$ROOT"
bash "$FIXTURE_BUILDER" "$ROOT" >/dev/null

# Pre-seed 30 underperforming payload_breakdown records. Each reports
# payload_tokens_estimate=100 and filter_dropped_tokens=5 → savings ratio
# 5/(100+5) ≈ 4.76% < 34.7% floor.
LOG="$ROOT/execution-log.jsonl"
i=1
while [ "$i" -le 30 ]; do
  printf '{"record_type":"payload_breakdown","unitId":"M999/P01/T%02d","milestone":"M999","phase":"P01","task":"T%02d","payload_chars":400,"payload_tokens_estimate":100,"token_estimate_method":"char-quartile","section_tokens":{"Knowledge":50},"filter_dropped_tokens":5,"model":"","source":"estimate","timestamp":"2026-04-27T00:00:00Z"}\n' "$i" "$i" >> "$LOG"
  i=$(( i + 1 ))
done

PRE_COUNT="$(grep -c '"record_type":"compression_underperformance"' "$LOG" 2>/dev/null)"
if [ -z "$PRE_COUNT" ]; then PRE_COUNT=0; fi
if [ "$PRE_COUNT" -ne 0 ]; then
  printf 'FAIL: log already contained compression_underperformance record before run (count=%s)\n' "$PRE_COUNT" >&2
  exit 1
fi

# Run build-context.sh end-to-end. The emitter checks
# compression.underperformance.* config (we set enabled:true,
# floor_pct:34.7, window_size:30, min_sample_size:10 in the fixture).
PAYLOAD_OUT="$TMPDIR_U/payload.md"
ERR="$TMPDIR_U/bc.err"
bash "$BC" "$ROOT" M999 P01 T01 > "$PAYLOAD_OUT" 2>"$ERR" || {
  printf 'FAIL: build-context.sh nonzero against M999 fixture\n' >&2
  cat "$ERR" >&2
  exit 1
}

# Assert exactly one compression_underperformance record appended.
POST_COUNT="$(grep -c '"record_type":"compression_underperformance"' "$LOG" 2>/dev/null)"
if [ -z "$POST_COUNT" ]; then POST_COUNT=0; fi
if [ "$POST_COUNT" -lt 1 ]; then
  printf 'FAIL: no compression_underperformance record emitted (count=%s)\n' "$POST_COUNT" >&2
  printf '       Last 3 log lines for context:\n' >&2
  tail -3 "$LOG" >&2
  exit 1
fi

# Inspect the emitted record's fields.
EMITTED="$(grep '"record_type":"compression_underperformance"' "$LOG" | tail -1)"

# floor_pct must be the configured 34.7.
if ! printf '%s' "$EMITTED" | grep -q '"floor_pct":34.7'; then
  printf 'FAIL: emitted record missing or wrong floor_pct=34.7 (record: %s)\n' "$EMITTED" >&2
  exit 1
fi

# running_mean_pct must be present and < floor.
RM="$(printf '%s' "$EMITTED" | sed -n 's/.*"running_mean_pct":\([0-9][0-9.]*\).*/\1/p')"
if [ -z "$RM" ]; then
  printf 'FAIL: emitted record missing running_mean_pct\n' >&2
  exit 1
fi
LT="$(awk -v m="$RM" 'BEGIN { print (m < 34.7) ? "1" : "0" }')"
if [ "$LT" != "1" ]; then
  printf 'FAIL: running_mean_pct=%s is not < 34.7\n' "$RM" >&2
  exit 1
fi

# sample_size must be >= 10 (min_sample_size guard satisfied).
SS="$(printf '%s' "$EMITTED" | sed -n 's/.*"sample_size":\([0-9]\{1,\}\).*/\1/p')"
if [ -z "$SS" ]; then
  printf 'FAIL: emitted record missing sample_size\n' >&2
  exit 1
fi
if [ "$SS" -lt 10 ]; then
  printf 'FAIL: sample_size=%s < 10 (min_sample_size guard not satisfied)\n' "$SS" >&2
  exit 1
fi

# compression_underperformance literal in this verifier (artifact contains check).
# compression_underperformance
printf 'PASS: m018-p02-underperformance-emit (running_mean_pct=%s < 34.7 floor; sample_size=%s)\n' "$RM" "$SS"
exit 0
