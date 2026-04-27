#!/usr/bin/env bash
# scripts/verify/m027-p01-intensity-text-back-compat.sh — M027/P01
# Truth #8 (FR-7, SC-3).
#
# Asserts byte-stability of the first 8 key=value lines of
# `intensity-recommend.sh` text output. Pre-T02 callers parse those 8
# lines via fixed grep patterns; T02's cost-annotation block is
# appended after. The verifier passes deterministic inline
# `--analyze-output` and `--profile-output` so neither
# `intensity-analyze.sh` nor `detect-capabilities.sh` is forked
# (removes environmental variance), uses `--no-cost-annotation` to
# suppress the trailing T02 block, and diffs against the shipped
# fixture.
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out.

set -u

NAME="m027-p01-intensity-text-back-compat.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
IR="$PROJECT_ROOT/scripts/engine/intensity-recommend.sh"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m027-p01/intensity-recommend-baseline-text.txt"

ANALYZE='scope=moderate
risk_level=medium
complexity=moderate
risk_signals=none
recommended_intensity=Standard'

PROFILE='cap_score=1'

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

[ -f "$IR" ] || fail "intensity-recommend.sh missing"
[ -f "$FIXTURE" ] || fail "fixture missing: $FIXTURE"

# Capture live output; --no-cost-annotation suppresses the T02 trailing
# block. --description "test" so the embedded cost-estimate library
# does not emit its empty-description WARN to stderr.
live_out="$(bash "$IR" \
  --analyze-output "$ANALYZE" \
  --profile-output "$PROFILE" \
  --description "test" \
  --no-cost-annotation 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s intensity-recommend.sh exit %d\n%s\n' "$NAME" "$rc" "$live_out" >&2
  exit 1
fi

# Take only the first 8 lines after stripping any leading WARN: lines
# (pre-T02 callers also tolerated leading stderr; we want to compare
# the structured key=value block).
first8="$(printf '%s\n' "$live_out" | grep -v '^WARN:' | head -n 8)"
expected="$(awk 'NR <= 8' "$FIXTURE")"

if [ "$first8" != "$expected" ]; then
  printf 'FAIL: %s byte-stability drift in first 8 lines\n' "$NAME" >&2
  printf '--- expected ---\n%s\n--- got ---\n%s\n' "$expected" "$first8" >&2
  exit 1
fi

printf 'PASS: %s 8-line byte-stable text output verified\n' "$NAME"
exit 0
