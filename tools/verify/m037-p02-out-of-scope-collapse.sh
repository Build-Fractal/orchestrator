#!/usr/bin/env bash
# tools/verify/m037-p02-out-of-scope-collapse.sh — M037 P02 T04 FR-22a verifier.
#
# Asserts:
#  1. scripts/diagnostics/wiki-link-check.sh contains the `--verbose` flag handler.
#  2. wiki-link-check.sh contains the `(collapsed)` literal marker (summary
#     line shape: `OUT-OF-SCOPE: <N> pages -> <url> [<reason>] (collapsed)`).
#  3. wiki-link-check.sh contains the `THRESHOLD` awk variable name (the
#     5-occurrence collapse threshold; CONSTRAINT: constant in awk script,
#     not exposed as a flag in P02).
#  4. scripts/wiki/wiki-deploy.sh contains a `--verbose` flag handler that
#     forwards to wiki-link-check.sh.
#  5. tests/m037-acceptance/p01-out-of-scope-collapse.sh exists and exits 0
#     (covers SC-16 acceptance: 178-page collapse, --verbose passthrough,
#     mixed-targets, zero-OOS silent-on-empty).
#
# AD-19 compliant: invokes the test scaffold via `bash <path>` only.
# Bash 3.2 compatible. Single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LINK_CHECK="$PROJECT_ROOT/scripts/diagnostics/wiki-link-check.sh"
DEPLOY="$PROJECT_ROOT/scripts/wiki/wiki-deploy.sh"
ACCEPTANCE="$PROJECT_ROOT/tests/m037-acceptance/p01-out-of-scope-collapse.sh"

pass=0
fail=0

ok() {
  printf 'PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

# 1. wiki-link-check.sh exists.
if [ -f "$LINK_CHECK" ]; then
  ok "scripts/diagnostics/wiki-link-check.sh exists"
else
  bad "scripts/diagnostics/wiki-link-check.sh missing"
  printf 'SUMMARY: m037-p02-out-of-scope-collapse pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# 2. --verbose flag handler.
if grep -q -- '--verbose' "$LINK_CHECK"; then
  ok "wiki-link-check.sh contains --verbose flag handler"
else
  bad "wiki-link-check.sh missing --verbose flag handler"
fi

# 3. (collapsed) literal marker — summary-line shape.
if grep -q '(collapsed)' "$LINK_CHECK"; then
  ok "wiki-link-check.sh contains (collapsed) summary marker"
else
  bad "wiki-link-check.sh missing (collapsed) marker"
fi

# 4. THRESHOLD awk variable name.
if grep -q 'THRESHOLD' "$LINK_CHECK"; then
  ok "wiki-link-check.sh contains THRESHOLD awk variable"
else
  bad "wiki-link-check.sh missing THRESHOLD variable"
fi

# 5. wiki-deploy.sh --verbose passthrough handler.
if [ -f "$DEPLOY" ]; then
  ok "scripts/wiki/wiki-deploy.sh exists"
else
  bad "scripts/wiki/wiki-deploy.sh missing"
fi

if grep -q -- '--verbose' "$DEPLOY"; then
  ok "wiki-deploy.sh contains --verbose flag passthrough"
else
  bad "wiki-deploy.sh missing --verbose flag passthrough"
fi

# 6. Acceptance test exists + passes.
if [ -f "$ACCEPTANCE" ]; then
  ok "tests/m037-acceptance/p01-out-of-scope-collapse.sh exists"
else
  bad "tests/m037-acceptance/p01-out-of-scope-collapse.sh missing"
  printf 'SUMMARY: m037-p02-out-of-scope-collapse pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

if bash "$ACCEPTANCE" >/dev/null 2>&1; then
  ok "p01-out-of-scope-collapse.sh exits 0 (SC-16 acceptance)"
else
  bad "p01-out-of-scope-collapse.sh exits non-zero — run directly for diagnostics"
fi

printf 'SUMMARY: m037-p02-out-of-scope-collapse pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
