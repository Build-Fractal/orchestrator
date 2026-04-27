#!/usr/bin/env bash
# scripts/verify/m027-p03-anomaly-latency.sh -- M027/P03 Truth #7.
#
# Measures wall-clock latency of `check-anomalies.sh --milestone M013`
# (the largest existing milestone log -- ~26 KB / 110+ records).
#
# Two measurements (mirrors P01/P02/T04 outer-vs-inner split):
#
#   - "outer": full CLI invocation. Includes bash startup + the
#     metrics-rollup.sh fork + read-config.sh forks. Environment-sensitive
#     -- macOS dev boxes incur ~150 ms of bash+fork overhead the surface
#     author cannot optimize. Reported informationally above the hard
#     threshold via a structured `WARN: RELAX-CANDIDATE ...` line.
#
#   - "inner": same invocation. The check-anomalies.sh helper has no
#     fast-path env-vars to short-circuit the rollup fork, so the inner
#     measurement equals the outer measurement here. The hard pass/fail
#     threshold applies to this measurement (the surface author's
#     actual budget on macOS dev boxes).
#
# Threshold model: SOFT_WARN_MS = 100 (the #Q-5 measured baseline target);
# HARD_FAIL_MS = 250 (target + ~150 ms of CI/macOS slack). Inner is the
# gating measurement; outer is observational with a RELAX-CANDIDATE
# annotation when over the hard threshold.
#
# Takes the minimum of 3 warm-cache invocations for each measurement.
# Sub-second timing prefers `perl -MTime::HiRes` (standard on macOS).
# Falls back to whole-second `date` when perl is missing.
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out.

set -u

NAME="m027-p03-anomaly-latency.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh"

HARD_FAIL_MS=250
SOFT_WARN_MS=100

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -f "$HELPER" ]; then
  fail "scripts/diagnostics/check-anomalies.sh missing"
fi

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
  start=$(now_ms)
  bash "$HELPER" --milestone M013 >/dev/null 2>&1
  end=$(now_ms)
  echo $((end - start))
}

# Warm-up (don't count first run; primes the disk cache).
measure_one >/dev/null

m1=$(measure_one)
m2=$(measure_one)
m3=$(measure_one)
outer_min=$m1
[ "$m2" -lt "$outer_min" ] && outer_min=$m2
[ "$m3" -lt "$outer_min" ] && outer_min=$m3

# Inner == outer here (no fast-path env-vars to short-circuit the rollup
# fork). The split is preserved structurally so the suite's RELAX-CANDIDATE
# forwarding still operates on the outer-bound diagnostic shape if/when an
# inner fast-path is introduced.
inner_min=$outer_min

# Hard threshold applies to the inner measurement.
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
# fails the gate (mirrors P01/P02/T04 outer-vs-inner split).
if [ "$outer_min" -gt "$HARD_FAIL_MS" ]; then
  printf 'WARN: RELAX-CANDIDATE %s outer-wall-clock measured=%dms target=%dms (~150ms macOS bash startup + rollup-fork overhead)\n' \
    "$NAME" "$outer_min" "$HARD_FAIL_MS"
fi

printf 'PASS: %s inner=%dms outer=%dms target=%dms hard_fail=%dms\n' \
  "$NAME" "$inner_min" "$outer_min" "$SOFT_WARN_MS" "$HARD_FAIL_MS"
exit 0
