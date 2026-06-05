#!/usr/bin/env bash
# m043-p01-wiki-init-branch.sh — FR-2/FR-4 branching + CON-4 byte-stability.
set -u

WI="scripts/lifecycle/wiki-init.sh"
GOLDEN="tests/fixtures/m043-p01/pages-workflow.golden.yml"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

test -f "$WI"; check "wiki-init.sh present" $?

grep -q "emit_cloudflare_workflow()" "$WI"; check "FR-2: emit_cloudflare_workflow defined" $?
grep -q "emit_cloudflare_workflow" "$WI";   check "FR-2: emit branch calls emit_cloudflare_workflow" $?
grep -q "resolve-deploy-target.sh" "$WI";   check "resolves deploy_target via resolver" $?
grep -q "wiki-cloudflare.yml" "$WI";        check "FR-2: emits wiki-cloudflare.yml" $?
grep -q "cloudflare-access-setup.sh" "$WI"; check "FR-4: --deploy references cloudflare-access-setup.sh" $?

# github-pages four-step sequence preserved (markers from the existing block).
grep -q "has_discussions=true" "$WI";       check "CON-4: github-pages step 1 (has_discussions) preserved" $?
grep -q "/repos/\$OWNER/\$REPO/pages" "$WI"; check "CON-4: github-pages step 4 (PUT pages) preserved" $?

# CON-4 / SC-1: the pages.yml heredoc body is byte-identical to the golden.
test -f "$GOLDEN"; check "byte-stability golden present" $?
TMP="$(mktemp -d)"
awk '/<<.PAGES_WORKFLOW_EOF.$/{f=1;next} /^PAGES_WORKFLOW_EOF$/{f=0} f' "$WI" > "$TMP/current.yml"
if [ -f "$GOLDEN" ] && diff -q "$TMP/current.yml" "$GOLDEN" >/dev/null 2>&1; then
  check "CON-4/SC-1: pages.yml heredoc byte-identical to golden" 0
else
  check "CON-4/SC-1: pages.yml heredoc byte-identical to golden" 1
fi
rm -rf "$TMP"

if [ "$fail" -eq 0 ]; then echo "SUMMARY: m043-p01-wiki-init-branch.sh pass=ALL fail=0"; exit 0; fi
echo "SUMMARY: m043-p01-wiki-init-branch.sh pass=SOME fail=1"; exit 1
