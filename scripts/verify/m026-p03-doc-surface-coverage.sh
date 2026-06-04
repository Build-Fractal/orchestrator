#!/usr/bin/env bash
# scripts/verify/m026-p03-doc-surface-coverage.sh
# Verifies M026/P03/T02: six doc surfaces grep-match conversus-oss + CONVERSUS_EDITION (FR-12).
# Verifies the M011-era four-step resolver block in commands/conversus-gate.md is rewritten,
# and the analogous block in docs/ingesting-arbitrary-specs.md is rewritten.
# AD-19 single-script-file shape; no compound bash, no subshells, no $(...|pipe).
# Bash 3.2 compatible.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pass=0
fail=0

_pass() {
  pass=$((pass + 1))
  echo "PASS: $1"
}

_fail() {
  fail=$((fail + 1))
  echo "FAIL: $1"
}

SURFACES="commands/conversus-gate.md commands/ingest.md commands/specify.md docs/ingesting-arbitrary-specs.md references/github-integration.md references/spec-management.md"

for surface in $SURFACES; do
  full="${REPO_ROOT}/${surface}"
  if [ ! -f "$full" ]; then
    _fail "${surface}: file missing"
    continue
  fi
  if grep -q 'conversus-oss' "$full"; then
    _pass "${surface}: contains 'conversus-oss'"
  else
    _fail "${surface}: missing 'conversus-oss'"
  fi
  if grep -q 'CONVERSUS_EDITION' "$full"; then
    _pass "${surface}: contains 'CONVERSUS_EDITION'"
  else
    _fail "${surface}: missing 'CONVERSUS_EDITION'"
  fi
done

# The M011-era 4-step resolver block in commands/conversus-gate.md ended at "user-local convention".
# Confirm the rewrite by asserting the new "user-local OSS default" or "user-local paid escape hatch"
# phrasing is present. Case-insensitive: the phrase legitimately appears capitalized as a table-cell
# label ("User-local OSS default") in docs/ingesting-arbitrary-specs.md — the assertion's intent is
# "rewrite happened", not "exact case", so a capitalized cell label is still a pass.
gate_doc="${REPO_ROOT}/commands/conversus-gate.md"
if grep -qiE 'user-local OSS default|user-local paid escape hatch' "$gate_doc"; then
  _pass "commands/conversus-gate.md: M011-era resolver block rewritten"
else
  _fail "commands/conversus-gate.md: original 'user-local convention' resolver block not rewritten"
fi

# Same check for docs/ingesting-arbitrary-specs.md.
ingest_doc="${REPO_ROOT}/docs/ingesting-arbitrary-specs.md"
if grep -qiE 'user-local OSS default|user-local paid escape hatch' "$ingest_doc"; then
  _pass "docs/ingesting-arbitrary-specs.md: resolver block rewritten"
else
  _fail "docs/ingesting-arbitrary-specs.md: resolver block not rewritten"
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "PASS: $(basename "$0")"
exit 0
