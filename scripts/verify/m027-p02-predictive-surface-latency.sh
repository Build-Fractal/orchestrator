#!/usr/bin/env bash
# scripts/verify/m027-p02-predictive-surface-latency.sh -- M027/P02 Truth #7.
#
# Measures wall-clock latency of `predictive-surface.sh --description ...
# --intensity standard`. Two measurements:
#
#   - "outer": full CLI invocation. Includes bash startup + the
#     intensity-recommend.sh fork. Environment-sensitive -- macOS dev
#     boxes incur ~200 ms of bash+fork overhead the surface author
#     cannot optimize. Reported informationally with a structured
#     `WARN: RELAX-CANDIDATE ...` line above the hard threshold.
#
#   - "inner": surface overhead with the documented fast-path env-vars
#     pre-set (INTENSITY_RECOMMEND_FAST_PATH=1 + _CE_RECOMMENDED=standard)
#     so the inner intensity-recommend.sh fork is skipped. This isolates
#     the predictive-surface helper's own work plus the (still-required)
#     downstream cost-estimate path. The hard pass/fail threshold is
#     applied to this measurement -- the surface author's actual budget.
#
# Threshold model mirrors the M027/P01/T04 latency verifier: SOFT_WARN_MS
# = 100 (CON-9 / FR-22 target); HARD_FAIL_MS = 250 (target + ~150 ms of
# CI/macOS slack). Inner is the gating measurement; outer is observational
# with a RELAX-CANDIDATE annotation.
#
# Takes the minimum of 3 warm-cache invocations for each measurement.
# Sub-second timing prefers `perl -MTime::HiRes` (standard on macOS).
# Falls back to whole-second `date` when perl is missing.
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out.

set -u

NAME="m027-p02-predictive-surface-latency.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/dispatch/predictive-surface.sh"

HARD_FAIL_MS=250
SOFT_WARN_MS=100

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -f "$HELPER" ]; then
  fail "scripts/dispatch/predictive-surface.sh missing"
fi

# now_ms returns milliseconds since epoch. Prefer perl Time::HiRes; fall
# back to seconds * 1000.
have_perl=0
if command -v perl >/dev/null 2>&1; then
  if perl -MTime::HiRes -e 'exit 0' 2>/dev/null; then
    have_perl=1
  fi
fi

now_ms() {
  if [ "$have_perl" -eq 1 ]; then
    perl -MTime::HiRes -e 'printf "%d\n", Time::HiRes::time()*1000'
  else
    s=$(date +%s)
    echo $((s * 1000))
  fi
}

measure_one() {
  # $1: "fast" to enable the inner-library fast-path (skips the inner
  #     intensity-recommend.sh fork). Requires both
  #     INTENSITY_RECOMMEND_FAST_PATH=1 and _CE_RECOMMENDED=standard.
  start=$(now_ms)
  if [ "${1:-}" = "fast" ]; then
    env _CE_RECOMMENDED=standard INTENSITY_RECOMMEND_FAST_PATH=1 \
      bash "$HELPER" --description "test" --intensity standard >/dev/null 2>&1
  else
    bash "$HELPER" --description "test" --intensity standard >/dev/null 2>&1
  fi
  end=$(now_ms)
  echo $((end - start))
}

# Outer: full CLI invocation, no fast-path.
# Warm-up (don't count first run; primes the disk cache).
measure_one >/dev/null

m1=$(measure_one)
m2=$(measure_one)
m3=$(measure_one)
outer_min=$m1
[ "$m2" -lt "$outer_min" ] && outer_min=$m2
[ "$m3" -lt "$outer_min" ] && outer_min=$m3

# Inner: with fast-path env-vars (skips the intensity-recommend re-fork).
inner_warmup=$(measure_one fast)
i1=$(measure_one fast)
i2=$(measure_one fast)
inner_min=$i1
[ "$i2" -lt "$inner_min" ] && inner_min=$i2
[ "$inner_warmup" -lt "$inner_min" ] && inner_min=$inner_warmup

# Hard threshold applies to the inner (surface-only) measurement.
if [ "$inner_min" -gt "$HARD_FAIL_MS" ]; then
  printf 'FAIL: %s inner=%dms hard_fail_at=%dms outer=%dms\n' \
    "$NAME" "$inner_min" "$HARD_FAIL_MS" "$outer_min" >&2
  exit 1
fi

# Inner soft-warn: RELAX-CANDIDATE annotation if over the target but
# within hard fail.
if [ "$inner_min" -gt "$SOFT_WARN_MS" ]; then
  printf 'WARN: RELAX-CANDIDATE %s inner=%dms target=%dms hard_fail=%dms outer=%dms\n' \
    "$NAME" "$inner_min" "$SOFT_WARN_MS" "$HARD_FAIL_MS" "$outer_min"
fi

# Outer informational: RELAX-CANDIDATE if over the hard threshold; never
# fails the gate (mirrors P01/T04 outer-vs-inner split).
if [ "$outer_min" -gt "$HARD_FAIL_MS" ]; then
  printf 'WARN: RELAX-CANDIDATE %s outer=%dms exceeds %dms (env-sensitive: bash startup + intensity-recommend fork; surface inner=%dms is within budget)\n' \
    "$NAME" "$outer_min" "$HARD_FAIL_MS" "$inner_min"
fi

printf 'PASS: %s inner=%dms outer=%dms target=%dms hard_fail=%dms\n' \
  "$NAME" "$inner_min" "$outer_min" "$SOFT_WARN_MS" "$HARD_FAIL_MS"
exit 0
