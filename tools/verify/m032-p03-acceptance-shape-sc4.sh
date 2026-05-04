#!/usr/bin/env bash
# tools/verify/m032-p03-acceptance-shape-sc4.sh — M032/P03/T01 SC-4 shape.
#
# Asserts that tests/m032-acceptance/p02-wiki-init-with-giscus.sh exists,
# is executable, and contains the load-bearing tokens that prove it
# exercises all six SC-4 branches: FR-7 placeholder presence, FR-8
# happy-path, post-step verifier, failure injection, re-run idempotency,
# overwrite branch.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible (MEM001).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACC="$REPO_ROOT/tests/m032-acceptance/p02-wiki-init-with-giscus.sh"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -x "$ACC" ]; then
  say_fail "$ACC absent or non-executable"
  printf 'SUMMARY: m032-p03-acceptance-shape-sc4 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

for tok in 'SC-4' 'FR-7' 'FR-8' 'M032_GISCUS_IDS_FROM_GH_STUB=1' 'M032_GISCUS_IDS_FROM_GH_STUB=fail' \
           'fixture-owner/fixture-repo' 'R_kgDOFixture' 'wiki-giscus-config-check.sh' \
           'integration-giscus-config-failed' '{{giscus_repo}}' 'fixture-owner-2'; do
  if grep -qF "$tok" "$ACC"; then
    say_pass "SC-4 contains: $tok"
  else
    say_fail "SC-4 missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-acceptance-shape-sc4 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
