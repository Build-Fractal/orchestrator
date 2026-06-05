#!/usr/bin/env bash
# m043-p02-provisioner-shape.sh — static checks on cloudflare-access-setup.sh:
# exists, Bash 3.2 (no declare -A / process substitution), single cf_api seam,
# create-order endpoint keys, FR-9 diagnostic branch, apex+wildcard. Tier 1.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
S="scripts/wiki/cloudflare-access-setup.sh"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

test -f "$S"
check "provisioner exists" $?
grep -q 'cf_api' "$S"
check "cf_api transport seam present" $?
grep -q 'M043_CF_FIXTURE_DIR' "$S"
check "fixture-replay mode wired" $?
grep -q 'emit_provision_diagnostic' "$S"
check "FR-9 diagnostic function present" $?
grep -q 'self_hosted_domains' "$S"
check "apex+wildcard self_hosted_domains constructed" $?
grep -q 'pages-project-create' "$S"
check "pages-project-create endpoint key present" $?
grep -q 'access-app-create' "$S"
check "access-app-create endpoint key present" $?
grep -q 'access-policy-create' "$S"
check "access-policy-create endpoint key present" $?
# CON-5 Bash 3.2 compliance
if grep -q 'declare -A' "$S"; then check "no declare -A (CON-5)" 1; else check "no declare -A (CON-5)" 0; fi
if grep -Eq '<\(|>\(' "$S"; then check "no process substitution (CON-5)" 1; else check "no process substitution (CON-5)" 0; fi

echo "SUMMARY: m043-p02-provisioner-shape.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
