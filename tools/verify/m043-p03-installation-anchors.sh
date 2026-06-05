#!/usr/bin/env bash
# m043-p03-installation-anchors.sh — SC-7 (FR-11). references/installation.md
# documents the GitHub-Pages footgun + the symmetric Cloudflare entitlement-lapse
# failure mode, token scopes, Zero Trust prereq, custom-domain + CON-7 + giscus
# caveats. Grep-asserted anchors.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
DOC="references/installation.md"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }
anchor() { if grep -qiF -- "$2" "$DOC"; then echo "PASS: $1"; else echo "FAIL: $1 (missing: $2)"; fail=1; fi; }

[ -f "$DOC" ]; check "installation.md exists" $?

anchor "Wiki Deploy Targets section"        "## Wiki Deploy Targets"
anchor "Enterprise-only private-Pages pitfall" "Enterprise-only private-Pages pitfall"
anchor "build-green / deploy-422 mode"       "build-green / deploy-422"
anchor "Cloudflare Pages + Access recipe"    "Recipe: Cloudflare Pages + Access"
anchor "token scope: Pages Edit"             "Cloudflare Pages › Edit"
anchor "token scope: Access Apps and Policies Edit" "Access: Apps and Policies › Edit"
anchor "token scope: Account Settings Read"  "Account Settings › Read"
anchor "no extra Read scope"                 "No additional"
anchor "Zero Trust prerequisite"             "Zero Trust prerequisite"
anchor "symmetric Cloudflare entitlement lapse (THREAT-7)" "Cloudflare entitlement lapse"
anchor "50-user free-tier limit"             "50-user"
anchor "FR-3a health-check failure as signal" "FR-3a pre-deploy health-check"
anchor "custom-domain / self_hosted_domains note (THREAT-11)" "self_hosted_domains"
anchor "CON-7 domain-list reprovision caveat" "allowed_email_domains"
anchor "giscus read-but-not-comment caveat"  "read-but-not-comment"

echo "SUMMARY: m043-p03-installation-anchors.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
