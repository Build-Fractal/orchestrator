#!/usr/bin/env bash
# tools/verify/m032-p03-with-feature-pattern-doc.sh — FR-13 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO_ROOT/references/installation.md"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -f "$DOC" ] || { say_fail "$DOC absent"; printf 'SUMMARY: m032-p03-with-feature-pattern-doc pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in '--with-<feature>' 'Progressive Opt-In' 'default-off' \
           'independently composable' 'Constitution I' 'FR-13' \
           '--with-wiki' '--with-giscus' '--deploy' 'reversibility' \
           'M032 prior art'; do
  if grep -qiF -- "$tok" "$DOC"; then
    say_pass "installation.md contains: $tok"
  else
    say_fail "installation.md missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-with-feature-pattern-doc pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
