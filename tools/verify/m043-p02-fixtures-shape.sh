#!/usr/bin/env bash
# m043-p02-fixtures-shape.sh — assert the M043 Cloudflare recorded-API fixture
# tree is well-formed: four scenario dirs, required response files per scenario,
# valid JSON with an _http_status field, the clean-account app-create body
# carrying BOTH apex and wildcard self_hosted_domains, and the two error
# fixtures carrying distinguishable (status, code) discriminators. Tier 1.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
FX="tests/fixtures/m043-cloudflare"
fail=0

check() {
  if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi
}

# README present + documents the contract
test -f "$FX/README.md"
check "fixtures README present" $?
grep -q "fixture-replay" "$FX/README.md" 2>/dev/null
check "README documents the fixture-replay contract" $?

# Required response files per scenario
for f in \
  clean-account/pages-project-get.response.json \
  clean-account/pages-project-create.response.json \
  clean-account/access-apps-list.response.json \
  clean-account/access-app-create.response.json \
  clean-account/access-policies-list.response.json \
  clean-account/access-policy-create.response.json \
  all-present/pages-project-get.response.json \
  all-present/access-apps-list.response.json \
  all-present/access-policies-list.response.json \
  zero-trust-not-enabled/access-apps-list.response.json \
  missing-scope/access-apps-list.response.json
do
  test -f "$FX/$f"
  check "fixture present: $f" $?
done

# Every response file is valid JSON and carries _http_status
while IFS= read -r jf; do
  jq -e . "$jf" >/dev/null 2>&1
  check "valid JSON: ${jf#$FX/}" $?
  jq -e 'has("_http_status")' "$jf" >/dev/null 2>&1
  check "_http_status present: ${jf#$FX/}" $?
done < <(find "$FX" -name '*.response.json' | sort)

# clean-account app-create carries BOTH apex and wildcard self_hosted_domains
APP="$FX/clean-account/access-app-create.response.json"
if [ -f "$APP" ]; then
  jq -e '.result.self_hosted_domains | index("<name>.pages.dev")' "$APP" >/dev/null 2>&1
  check "clean-account app-create has apex self_hosted_domain" $?
  jq -e '.result.self_hosted_domains | index("*.<name>.pages.dev")' "$APP" >/dev/null 2>&1
  check "clean-account app-create has wildcard self_hosted_domain" $?
fi

# all-present access-apps-list returns a non-empty result with an existing app
AP="$FX/all-present/access-apps-list.response.json"
if [ -f "$AP" ]; then
  jq -e '.result | length > 0' "$AP" >/dev/null 2>&1
  check "all-present apps-list is non-empty (idempotency seed)" $?
fi

# Error fixtures: distinguishable on (status, code)
ZT="$FX/zero-trust-not-enabled/access-apps-list.response.json"
MS="$FX/missing-scope/access-apps-list.response.json"
if [ -f "$ZT" ] && [ -f "$MS" ]; then
  zt_code="$(jq -r '.errors[0].code' "$ZT" 2>/dev/null)"
  ms_code="$(jq -r '.errors[0].code' "$MS" 2>/dev/null)"
  zt_status="$(jq -r '._http_status' "$ZT" 2>/dev/null)"
  ms_status="$(jq -r '._http_status' "$MS" 2>/dev/null)"
  if [ "$ms_status" = "403" ]; then s_ok=0; else s_ok=1; fi
  check "missing-scope fixture is HTTP 403" $s_ok
  if [ "$zt_status" != "403" ]; then z_ok=0; else z_ok=1; fi
  check "zero-trust fixture is NOT HTTP 403 (distinct status axis)" $z_ok
  if [ -n "$zt_code" ] && [ -n "$ms_code" ] && [ "$zt_code" != "$ms_code" ]; then c_ok=0; else c_ok=1; fi
  check "error fixtures carry distinct errors[].code (distinct code axis)" $c_ok
fi

echo "SUMMARY: m043-p02-fixtures-shape.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
