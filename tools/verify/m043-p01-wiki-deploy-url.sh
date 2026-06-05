#!/usr/bin/env bash
# m043-p01-wiki-deploy-url.sh — FR-5 target-aware URL + CON-4 github-pages
# output byte-stability (string-presence proxy).
set -u

WD="scripts/wiki/wiki-deploy.sh"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

test -f "$WD"; check "wiki-deploy.sh present" $?

grep -q "resolve-deploy-target.sh" "$WD"; check "FR-5: resolves deploy_target" $?
grep -q "actions/workflows/wiki-cloudflare.yml" "$WD"; check "FR-5: prints wiki-cloudflare.yml URL for cloudflare-access" $?
grep -q "identical across targets" "$WD"; check "FR-5: states gates identical across targets" $?

# CON-4: the github-pages output lines are preserved verbatim.
grep -q "OK: pre-deploy gates PASS. Push to main to trigger workflow deploy:" "$WD"; check "CON-4: github-pages OK line preserved" $?
grep -q "actions/workflows/pages.yml" "$WD"; check "CON-4: github-pages pages.yml URL preserved" $?

if [ "$fail" -eq 0 ]; then echo "SUMMARY: m043-p01-wiki-deploy-url.sh pass=ALL fail=0"; exit 0; fi
echo "SUMMARY: m043-p01-wiki-deploy-url.sh pass=SOME fail=1"; exit 1
