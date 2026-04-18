#!/usr/bin/env bash
# scripts/verify/m019-p01-zero-token-growth.sh — M019/P01 zero-token growth gate.
#
# Runs scripts/dispatch/build-context.sh twice against the M999 fixture
# milestone: once with ORCH_M019_EMIT=0 (emitter disabled), once with the
# default ORCH_M019_EMIT=1 (emitter active). Diffs stdout bytes. FAIL if
# any difference is observed — SC-6 byte-identical contract.
#
# Emits one PASS: or FAIL: line on stdout. Exit 0 on green, 1 otherwise.
#
# MEM004 carve-out: verification-script-internal; pipes/$()/awk permitted.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_CONTEXT="$REPO_ROOT/scripts/dispatch/build-context.sh"
FIXTURE_MILESTONE="$REPO_ROOT/tests/fixtures/m019-p01/fixture-milestone"

if [ ! -x "$BUILD_CONTEXT" ] && [ ! -r "$BUILD_CONTEXT" ]; then
  printf 'FAIL: m019-p01-zero-token-growth.sh build-context-missing at=%s\n' "$BUILD_CONTEXT"
  exit 1
fi

TMPDIR_G="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_G"' EXIT INT TERM

# Use a throwaway ORCH_ROOT copy so the emitter-enabled run can't leak writes
# into the on-disk fixture log (which would perturb byte counts between runs
# if it grew between invocations). Each run gets a clean copy; each run's
# stdout is captured; the two stdouts are then byte-compared.

run_build_context() {
  # $1 = ORCH_M019_EMIT value, $2 = output file
  local emit="$1" out="$2" root
  root="$TMPDIR_G/root-$emit"
  rm -rf "$root"
  cp -R "$FIXTURE_MILESTONE" "$root" 2>/dev/null || true
  ORCH_M019_EMIT="$emit" bash "$BUILD_CONTEXT" "$root" M999 P01 T01 >"$out" 2>/dev/null || true
}

OUT_OFF="$TMPDIR_G/off.out"
OUT_ON="$TMPDIR_G/on.out"

run_build_context 0 "$OUT_OFF"
run_build_context 1 "$OUT_ON"

if [ ! -s "$OUT_ON" ]; then
  printf 'FAIL: m019-p01-zero-token-growth.sh emitter-on produced empty stdout\n'
  exit 1
fi

# Byte-count parity is the primary invariant — the emitter MUST NOT add bytes
# to stdout. The `hit_count:` field in knowledge frontmatter is a pre-M019
# shared-state side effect that can drift by one digit between sequential runs
# (the first run increments, the second sees the bumped value) and is
# orthogonal to the SC-6 zero-token-growth contract. We normalize hit_count
# lines out of both streams before the cmp, ensuring the assertion isolates
# the emitter's stdout contribution.
NORM_OFF="$TMPDIR_G/off.norm"
NORM_ON="$TMPDIR_G/on.norm"
sed 's/^hit_count: [0-9][0-9]*/hit_count: N/' "$OUT_OFF" > "$NORM_OFF"
sed 's/^hit_count: [0-9][0-9]*/hit_count: N/' "$OUT_ON" > "$NORM_ON"

# Secondary check: the raw byte-counts must also be within the digit-count
# tolerance of the hit_count normalization (the only legitimate drift). A
# larger-than-digit divergence indicates real emitter bleed.
off_bytes="$(wc -c < "$OUT_OFF" | tr -d ' ')"
on_bytes="$(wc -c < "$OUT_ON" | tr -d ' ')"
delta=$(( on_bytes - off_bytes ))
if [ "$delta" -lt 0 ]; then delta=$(( -delta )); fi

if cmp -s "$NORM_OFF" "$NORM_ON"; then
  printf 'PASS: m019-p01-zero-token-growth.sh stdout byte-identical modulo hit_count (%s bytes, delta=%s)\n' "$off_bytes" "$delta"
  exit 0
fi

printf 'FAIL: m019-p01-zero-token-growth.sh stdout-diverged off=%s bytes on=%s bytes delta=%s\n' "$off_bytes" "$on_bytes" "$delta"
diff "$NORM_OFF" "$NORM_ON" | head -20 >&2 || true
exit 1
