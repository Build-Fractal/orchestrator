#!/usr/bin/env bash
# tools/verify/m032-p04-acceptance-shape-sc11.sh — SC-11 acceptance
# script shape verifier. Asserts the SC-11 acceptance script exists,
# is executable, and carries the load-bearing token surface for the
# three orthogonal invariants per the M032 spec MIT-002 + MIT-008
# amendments:
#   - Constitution VIII (no dead-infrastructure / unreferenced-asset)
#   - MIT-002 (FR-6 self-application via wiki-serve --probe)
#   - MIT-008 (wiki-deploy-mutation audit record presence)
#
# Bash 3.2 compatible. Single-script-file shape (AD-19).
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACC="$REPO_ROOT/tests/m032-acceptance/sc11-doctor-no-warnings.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -f "$ACC" ]; then
  say_fail "$ACC absent"
  printf 'SUMMARY: m032-p04-acceptance-shape-sc11 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -x "$ACC" ]; then
  say_fail "$ACC not executable"
  printf 'SUMMARY: m032-p04-acceptance-shape-sc11 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
say_pass "SC-11 acceptance script exists and is executable"

# Load-bearing token surface — three invariant groups + envelope tags.
for tok in 'SC-11' \
           'MIT-002' \
           'MIT-008' \
           'run-doctor.sh' \
           'wiki-serve.sh' \
           '--probe' \
           'wiki-deploy-mutation' \
           'dead-infrastructure' \
           'unreferenced-asset' \
           'M032_GISCUS_IDS_FROM_GH_STUB' \
           'M032_DEPLOY_GH_API_STUB' \
           'trap'; do
  if grep -qF -- "$tok" "$ACC"; then
    say_pass "SC-11 contains: $tok"
  else
    say_fail "SC-11 missing: $tok"
  fi
done

# Pass/fail accounting + structured RESULT line.
if grep -qE '^[[:space:]]*say_pass\b' "$ACC"; then
  say_pass "SC-11 uses say_pass accounting"
else
  say_fail "SC-11 missing say_pass accounting"
fi
if grep -qE '^[[:space:]]*say_fail\b' "$ACC"; then
  say_pass "SC-11 uses say_fail accounting"
else
  say_fail "SC-11 missing say_fail accounting"
fi
if grep -qF 'RESULT: SC-11' "$ACC"; then
  say_pass "SC-11 emits RESULT line"
else
  say_fail "SC-11 missing RESULT: SC-11 emission"
fi

printf 'SUMMARY: m032-p04-acceptance-shape-sc11 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
