#!/usr/bin/env bash
# m043-p02-create-order.sh — SC-3 (FR-6/FR-8): against the clean-account fixture
# the provisioner creates resources in Pages-project -> Access-app -> policy
# order, and the captured Access-app create body carries BOTH apex and wildcard
# self_hosted_domains. Behavioral — runs the provisioner in fixture-replay mode.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
S="scripts/wiki/cloudflare-access-setup.sh"
FX="tests/fixtures/m043-cloudflare/clean-account"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

CAP="$(mktemp -d 2>/dev/null || echo /tmp/m043cap.$$)"
mkdir -p "$CAP"

M043_CF_FIXTURE_DIR="$FX" M043_CF_CAPTURE_DIR="$CAP" \
  bash "$S" --project-name '<name>' --domains 'example.com' >"$CAP/out.log" 2>&1
rc=$?
[ "$rc" -eq 0 ]
check "provisioner exits 0 on clean account (rc=$rc)" $?

ORDER="$(grep -E 'pages-project-create|access-app-create|access-policy-create' "$CAP/requests.log" 2>/dev/null | awk '{print $2}' | tr '\n' ',')"
[ "$ORDER" = "pages-project-create,access-app-create,access-policy-create," ]
check "create order is pages-project -> access-app -> policy (got: $ORDER)" $?

APPREQ="$CAP/access-app-create.request.json"
test -f "$APPREQ"
check "app-create request body captured" $?
if [ -f "$APPREQ" ]; then
  jq -e '.self_hosted_domains | index("<name>.pages.dev")' "$APPREQ" >/dev/null 2>&1
  check "app-create body has apex self_hosted_domain" $?
  jq -e '.self_hosted_domains | index("*.<name>.pages.dev")' "$APPREQ" >/dev/null 2>&1
  check "app-create body has wildcard self_hosted_domain" $?
fi

rm -rf "$CAP"
echo "SUMMARY: m043-p02-create-order.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
