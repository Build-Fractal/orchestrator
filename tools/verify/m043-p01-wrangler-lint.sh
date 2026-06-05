#!/usr/bin/env bash
# m043-p01-wrangler-lint.sh — SC-2 (npx wrangler@4, no wrangler-action) +
# SC-10 (FR-3a health check precedes deploy) over a Cloudflare workflow file.
# Usage: m043-p01-wrangler-lint.sh [<workflow-or-template-path>]
#        defaults to templates/wiki-cloudflare-deploy.yml.tmpl
set -u

TARGET="${1:-templates/wiki-cloudflare-deploy.yml.tmpl}"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

test -f "$TARGET"
check "workflow file exists: $TARGET" $?
if [ ! -f "$TARGET" ]; then
  echo "SUMMARY: m043-p01-wrangler-lint.sh pass=0 fail=1"; exit 1
fi

grep -q "npx --yes wrangler@4" "$TARGET"
check "SC-2: deploys via npx --yes wrangler@4" $?

if grep -q "cloudflare/wrangler-action" "$TARGET"; then
  check "SC-2: contains no cloudflare/wrangler-action" 1
else
  check "SC-2: contains no cloudflare/wrangler-action" 0
fi

# SC-10: the FR-3a health-check step line precedes the wrangler deploy line.
hc_line="$(grep -n "Verify Cloudflare Access gate" "$TARGET" | head -n1 | cut -d: -f1)"
dep_line="$(grep -n "wrangler@4 pages deploy" "$TARGET" | head -n1 | cut -d: -f1)"
if [ -n "$hc_line" ] && [ -n "$dep_line" ] && [ "$hc_line" -lt "$dep_line" ]; then
  check "SC-10: FR-3a health check (line $hc_line) precedes deploy (line $dep_line)" 0
else
  check "SC-10: FR-3a health check precedes deploy (hc=$hc_line dep=$dep_line)" 1
fi

if [ "$fail" -eq 0 ]; then echo "SUMMARY: m043-p01-wrangler-lint.sh pass=ALL fail=0"; exit 0; fi
echo "SUMMARY: m043-p01-wrangler-lint.sh pass=SOME fail=1"; exit 1
