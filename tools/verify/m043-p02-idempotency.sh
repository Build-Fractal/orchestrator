#!/usr/bin/env bash
# m043-p02-idempotency.sh — SC-4 (FR-7): against the all-present fixture the
# provisioner issues zero create requests and exits 0. Behavioral.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
S="scripts/wiki/cloudflare-access-setup.sh"
FX="tests/fixtures/m043-cloudflare/all-present"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

CAP="$(mktemp -d 2>/dev/null || echo /tmp/m043cap2.$$)"
mkdir -p "$CAP"

M043_CF_FIXTURE_DIR="$FX" M043_CF_CAPTURE_DIR="$CAP" \
  bash "$S" --project-name '<name>' --domains 'example.com' >"$CAP/out.log" 2>&1
rc=$?
[ "$rc" -eq 0 ]
check "provisioner exits 0 on all-present account (rc=$rc)" $?

if grep -q -- '-create' "$CAP/requests.log" 2>/dev/null; then has_create=1; else has_create=0; fi
[ "$has_create" -eq 0 ]
check "zero create requests issued (idempotent re-run)" $?

rm -rf "$CAP"
echo "SUMMARY: m043-p02-idempotency.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
