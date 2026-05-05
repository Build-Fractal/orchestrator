#!/usr/bin/env bash
# tools/verify/m032-p04-acceptance-shape-sc9.sh
# M032/P04/T02 — SC-9 acceptance-script shape verifier.
#
# Asserts that tests/m032-acceptance/p0X-code-decorator.sh:
#   - exists and is executable
#   - exercises FR-20 / US-8 surface
#   - contains the three AS group labels (AS-1 / AS-2 / AS-3)
#   - implements trap-EXIT cleanup of /tmp/m032-p04-sc9-fixture-$$/
#
# Single-script-file shape per AD-19. Bash 3.2 compatible (MEM001).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACC="$REPO_ROOT/tests/m032-acceptance/p0X-code-decorator.sh"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -f "$ACC" ]; then
  say_fail "$ACC absent"
  printf 'SUMMARY: m032-p04-acceptance-shape-sc9.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
say_pass "SC-9 acceptance script exists at $ACC"

if [ ! -x "$ACC" ]; then
  say_fail "SC-9 acceptance script is not executable"
else
  say_pass "SC-9 acceptance script is executable"
fi

# Decision-id token surface for SC-9 / FR-20 / US-8.
for tok in 'SC-9' 'FR-20' 'US-8' 'Finding G'; do
  if grep -qF -- "$tok" "$ACC"; then
    say_pass "SC-9 references decision id: $tok"
  else
    say_fail "SC-9 missing decision id: $tok"
  fi
done

# Three AS group labels.
for tok in 'AS-1' 'AS-2' 'AS-3'; do
  if grep -qF -- "$tok" "$ACC"; then
    say_pass "SC-9 references acceptance scenario: $tok"
  else
    say_fail "SC-9 missing acceptance scenario: $tok"
  fi
done

# Trap-EXIT cleanup pattern of throwaway fixture.
if grep -qF -- "trap 'rm -rf \"\$FIXTURE\"' EXIT INT TERM" "$ACC"; then
  say_pass "SC-9 implements trap-EXIT cleanup of throwaway fixture"
else
  say_fail "SC-9 missing trap-EXIT cleanup pattern"
fi

# Fixture path convention: /tmp/m032-p04-sc9-fixture-$$/.
if grep -qF -- '/tmp/m032-p04-sc9-fixture-$$' "$ACC"; then
  say_pass "SC-9 uses canonical /tmp/m032-p04-sc9-fixture-\$\$ fixture path"
else
  say_fail "SC-9 missing /tmp/m032-p04-sc9-fixture-\$\$ fixture path"
fi

# Decorator interface invocation tokens.
for tok in '--in' '--glossary' '--out' 'wiki-decorate-codes.sh'; do
  if grep -qF -- "$tok" "$ACC"; then
    say_pass "SC-9 invokes decorator with: $tok"
  else
    say_fail "SC-9 missing decorator invocation token: $tok"
  fi
done

# Three-AS shape: AS-1 known/unknown; AS-2 first/subsequent; AS-3 missing-glossary.
for tok in 'XYZ-999' 'M032' 'AP-009' 'DR-STACK-001' 'missing.md'; do
  if grep -qF -- "$tok" "$ACC"; then
    say_pass "SC-9 fixture contains: $tok"
  else
    say_fail "SC-9 fixture missing: $tok"
  fi
done

# RESULT envelope shape.
if grep -qF -- 'RESULT: SC-9 pass=' "$ACC"; then
  say_pass "SC-9 emits canonical RESULT envelope"
else
  say_fail "SC-9 missing RESULT envelope"
fi

printf 'SUMMARY: m032-p04-acceptance-shape-sc9.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
