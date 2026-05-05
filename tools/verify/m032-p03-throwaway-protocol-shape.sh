#!/usr/bin/env bash
# tools/verify/m032-p03-throwaway-protocol-shape.sh — AD-7 / CON-5 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO_ROOT/tests/m032-acceptance/throwaway-fixture-protocol.md"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -f "$DOC" ] || { say_fail "$DOC absent"; printf 'SUMMARY: m032-p03-throwaway-protocol-shape pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in 'AD-7' 'CON-5' '<ts>-m032-fixture' 'gh repo create' 'gh repo delete' \
           '--private' '--add-readme' '--yes' 'trap cleanup EXIT INT TERM' \
           'No-orphan-state' 'SKIP_REASON' 'exit 77' 'M013' 'M014'; do
  if grep -qF -- "$tok" "$DOC"; then
    say_pass "throwaway-fixture-protocol.md contains: $tok"
  else
    say_fail "throwaway-fixture-protocol.md missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-throwaway-protocol-shape pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
