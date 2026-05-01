#!/usr/bin/env bash
# tools/verify/p07-corpus-synthesizer-idempotent.sh — M030/P07/T01
#
# Asserts tests/m030-acceptance/shadow-corpus-fixtures.sh is idempotent:
# re-running the synthesizer produces byte-identical corpora (sha256
# equality across two invocations).
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Helper-function
# carve-out for the _sha256 portability shim (sha256sum vs. shasum -a 256).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNTH="$PROJECT_ROOT/tests/m030-acceptance/shadow-corpus-fixtures.sh"
ACCEPT_DIR="$PROJECT_ROOT/tests/m030-acceptance"

# Portability shim: macOS lacks sha256sum by default; fall back to
# `shasum -a 256` (BSD). Helper-function carve-out per AD-19.
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

pass=0
fail=0

# First synthesis pass.
bash "$SYNTH" >/dev/null
sha_before_50="$(_sha256 "$ACCEPT_DIR/corpus-50-per-class.jsonl")"
sha_before_zero="$(_sha256 "$ACCEPT_DIR/corpus-zero.jsonl")"
sha_before_2cls="$(_sha256 "$ACCEPT_DIR/corpus-2-class-only.jsonl")"
sha_before_block="$(_sha256 "$ACCEPT_DIR/corpus-block.jsonl")"

# Second synthesis pass.
bash "$SYNTH" >/dev/null
sha_after_50="$(_sha256 "$ACCEPT_DIR/corpus-50-per-class.jsonl")"
sha_after_zero="$(_sha256 "$ACCEPT_DIR/corpus-zero.jsonl")"
sha_after_2cls="$(_sha256 "$ACCEPT_DIR/corpus-2-class-only.jsonl")"
sha_after_block="$(_sha256 "$ACCEPT_DIR/corpus-block.jsonl")"

if [ "$sha_before_50" = "$sha_after_50" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: corpus-50-per-class.jsonl drifted (before=%s after=%s)\n' "$sha_before_50" "$sha_after_50"
fi

if [ "$sha_before_zero" = "$sha_after_zero" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: corpus-zero.jsonl drifted (before=%s after=%s)\n' "$sha_before_zero" "$sha_after_zero"
fi

if [ "$sha_before_2cls" = "$sha_after_2cls" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: corpus-2-class-only.jsonl drifted (before=%s after=%s)\n' "$sha_before_2cls" "$sha_after_2cls"
fi

if [ "$sha_before_block" = "$sha_after_block" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: corpus-block.jsonl drifted (before=%s after=%s)\n' "$sha_before_block" "$sha_after_block"
fi

printf 'SUMMARY: p07-corpus-synthesizer-idempotent.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
