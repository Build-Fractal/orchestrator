#!/usr/bin/env bash
# tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh
# Task-grain shape verifier for M035/P03/T03.
# Asserts:
#   - byte-equivalence test contains the homebrew arm + cross-channel
#     equality assertion (static-shape needles)
#   - SKIP: pending P03 stub is gone (anti-pattern)
#   - end-to-end: HOMEBREW_HASH=<64-hex> emitted, cross-channel
#     equality PASS line fires (skipped when npm absent on PATH)
set -u

pass=0
fail=0
TEST="tests/m035-acceptance/cross-channel-byte-equivalence.sh"

if [ ! -x "$TEST" ]; then
  echo "FAIL: $TEST not executable"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi
pass=$((pass + 1))

# Static-shape checks.
for needle in 'HOMEBREW_HASH=' \
  'EXCLUSION_LIST_HOMEBREW' \
  'cross-channel byte-equivalence' \
  '_exclusion-list-by-channel.sh'; do
  if grep -qF "$needle" "$TEST"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $TEST missing pattern: $needle"
    fail=$((fail + 1))
  fi
done

# Anti-pattern: the SKIP: pending P03 stub MUST be gone.
if grep -qF 'SKIP: pending P03' "$TEST"; then
  echo "FAIL: $TEST still contains 'SKIP: pending P03' stub"
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# End-to-end: run the test. Requires npm on PATH.
if ! command -v npm >/dev/null 2>&1; then
  echo "SKIP: npm not on PATH — end-to-end byte-equivalence skipped"
  echo "BATTERY: pass=$pass fail=$fail skip=1"
  [ "$fail" -eq 0 ]
  exit $?
fi

PROBE_LOG="/tmp/m035-p03-byte-equivalence-probe.log"
if bash "$TEST" >"$PROBE_LOG" 2>&1; then
  pass=$((pass + 1))
else
  echo "FAIL: $TEST exited non-zero (see $PROBE_LOG)"
  fail=$((fail + 1))
fi

if grep -qE '^HOMEBREW_HASH=[0-9a-f]{64}$' "$PROBE_LOG"; then
  pass=$((pass + 1))
else
  echo "FAIL: HOMEBREW_HASH not emitted as 64-hex-char digest"
  fail=$((fail + 1))
fi

if grep -qF 'PASS: cross-channel byte-equivalence' "$PROBE_LOG"; then
  pass=$((pass + 1))
else
  echo "FAIL: cross-channel equality assertion did not PASS"
  # Don't delete the log on failure — operator needs to inspect.
  echo "  see $PROBE_LOG"
  fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
  rm -f "$PROBE_LOG"
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
