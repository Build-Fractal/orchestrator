#!/usr/bin/env bash
# m043-p02-diagnostics.sh — SC-5 (FR-9): the zero-trust-not-enabled fixture yields
# a non-zero exit + the dashboard-enablement instruction; the missing-scope
# fixture yields a non-zero exit + the scope-specific diagnostic. The two
# diagnostics are distinct (FR-9 distinguishable). Behavioral.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
S="scripts/wiki/cloudflare-access-setup.sh"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

TMP="$(mktemp -d 2>/dev/null || echo /tmp/m043diag.$$)"
mkdir -p "$TMP"

# --- zero-trust-not-enabled ---
M043_CF_FIXTURE_DIR="tests/fixtures/m043-cloudflare/zero-trust-not-enabled" \
  bash "$S" --project-name '<name>' --domains 'example.com' >"$TMP/zt.log" 2>&1
zt_rc=$?
[ "$zt_rc" -ne 0 ]
check "zero-trust fixture exits non-zero (rc=$zt_rc)" $?
grep -qi 'zero trust' "$TMP/zt.log"
check "zero-trust diagnostic names Zero Trust" $?
grep -qi 'dashboard' "$TMP/zt.log"
check "zero-trust diagnostic names the dashboard-enablement step" $?

# --- missing-scope ---
M043_CF_FIXTURE_DIR="tests/fixtures/m043-cloudflare/missing-scope" \
  bash "$S" --project-name '<name>' --domains 'example.com' >"$TMP/ms.log" 2>&1
ms_rc=$?
[ "$ms_rc" -ne 0 ]
check "missing-scope fixture exits non-zero (rc=$ms_rc)" $?
grep -qi 'Apps and Policies' "$TMP/ms.log"
check "missing-scope diagnostic names the Access: Apps and Policies scope" $?
grep -qi 'permission' "$TMP/ms.log"
check "missing-scope diagnostic names the missing permission" $?

# --- distinguishability: zero-trust log must NOT carry the scope text, and
#     missing-scope log must NOT carry the zero-trust text ---
if grep -qi 'Apps and Policies' "$TMP/zt.log"; then d1=1; else d1=0; fi
[ "$d1" -eq 0 ]
check "zero-trust diagnostic is distinct from the scope diagnostic" $?
if grep -qi 'zero trust' "$TMP/ms.log"; then d2=1; else d2=0; fi
[ "$d2" -eq 0 ]
check "missing-scope diagnostic is distinct from the zero-trust diagnostic" $?

rm -rf "$TMP"
echo "SUMMARY: m043-p02-diagnostics.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
