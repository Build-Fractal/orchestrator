#!/usr/bin/env bash
# m043-p01-config-and-resolver.sh — FR-1 config schema + resolver behavior.
set -u

fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

CFG="templates/orchestrator-config-default.yml"
grep -q "deploy_target: github-pages" "$CFG"; check "config declares deploy_target: github-pages default" $?
grep -q "allowed_email_domains" "$CFG";        check "config documents allowed_email_domains" $?
grep -q "cloudflare-access" "$CFG";             check "config names the cloudflare-access value" $?

R="scripts/wiki/resolve-deploy-target.sh"
test -x "$R"; check "resolver is executable" $?

TMP="$(mktemp -d)"

# absent -> github-pages
mkdir -p "$TMP/absent/.orchestrator"
printf 'wiki:\n  landing_cards: []\n' > "$TMP/absent/.orchestrator/config.yml"
out="$(bash "$R" "$TMP/absent" 2>/dev/null)"
[ "$out" = "github-pages" ]; check "absent deploy_target -> github-pages (got '$out')" $?

# explicit github-pages
mkdir -p "$TMP/gh/.orchestrator"
printf 'wiki:\n  deploy_target: github-pages\n' > "$TMP/gh/.orchestrator/config.yml"
out="$(bash "$R" "$TMP/gh" 2>/dev/null)"
[ "$out" = "github-pages" ]; check "explicit github-pages -> github-pages (got '$out')" $?

# cloudflare-access
mkdir -p "$TMP/cf/.orchestrator"
printf 'wiki:\n  deploy_target: cloudflare-access\n' > "$TMP/cf/.orchestrator/config.yml"
out="$(bash "$R" "$TMP/cf" 2>/dev/null)"
[ "$out" = "cloudflare-access" ]; check "cloudflare-access -> cloudflare-access (got '$out')" $?

# unknown value -> exit 2
mkdir -p "$TMP/bad/.orchestrator"
printf 'wiki:\n  deploy_target: netlify\n' > "$TMP/bad/.orchestrator/config.yml"
bash "$R" "$TMP/bad" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ]; check "unknown value exits 2 (got rc=$rc)" $?

rm -rf "$TMP"

if [ "$fail" -eq 0 ]; then echo "SUMMARY: m043-p01-config-and-resolver.sh pass=ALL fail=0"; exit 0; fi
echo "SUMMARY: m043-p01-config-and-resolver.sh pass=SOME fail=1"; exit 1
