#!/usr/bin/env bash
# tools/verify/m037-p02-workflow-pages-publishing.sh — M037 P02 T02 FR-19/FR-20 verifier.
#
# Asserts:
#  1. scripts/lifecycle/wiki-init.sh contains the FR-19 workflow YAML emit
#     markers: actions/deploy-pages, build_type=workflow,
#     cache-dependency-path: wiki/requirements.txt, cancel-in-progress: false.
#  2. scripts/wiki/wiki-deploy.sh has NO `mkdocs gh-deploy --force` invocation
#     outside comments (legacy live-deploy primitive demoted).
#  3. scripts/wiki/wiki-deploy.sh contains the literal `git push origin main`
#     and the workflow URL pattern `actions/workflows/pages.yml`.
#  4. wiki/README.md contains the `git push origin main` push instruction
#     (deploy-flow section), references `build_type` or `GitHub Actions`
#     (manual-recovery block), and does NOT carry the SHAPE
#     `bash scripts/wiki/wiki-deploy.sh` followed within 5 lines by
#     `mkdocs gh-deploy` (no live-deploy adjacency).
#  5. tests/test-wiki-init-workflow-mode.sh exists and exits 0.
#
# AD-19 compliant: invokes the test scaffold via `bash <path>` only.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

WIKI_INIT="$PROJECT_ROOT/scripts/lifecycle/wiki-init.sh"
WIKI_DEPLOY="$PROJECT_ROOT/scripts/wiki/wiki-deploy.sh"
WIKI_README="$PROJECT_ROOT/wiki/README.md"
WORKFLOW_TEST="$PROJECT_ROOT/tests/test-wiki-init-workflow-mode.sh"

pass=0
fail=0

ok() {
  printf 'PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

# 1. wiki-init.sh FR-19 workflow YAML emit markers.
if [ -f "$WIKI_INIT" ]; then
  ok "scripts/lifecycle/wiki-init.sh exists"
else
  bad "scripts/lifecycle/wiki-init.sh missing"
  printf 'SUMMARY: m037-p02-workflow-pages-publishing pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

if grep -q 'actions/deploy-pages' "$WIKI_INIT"; then
  ok "wiki-init.sh contains actions/deploy-pages (workflow YAML emit)"
else
  bad "wiki-init.sh missing actions/deploy-pages marker"
fi

if grep -q 'build_type=workflow' "$WIKI_INIT"; then
  ok "wiki-init.sh contains build_type=workflow (gh api PUT invocation)"
else
  bad "wiki-init.sh missing build_type=workflow marker"
fi

if grep -q 'cache-dependency-path: wiki/requirements.txt' "$WIKI_INIT"; then
  ok "wiki-init.sh contains cache-dependency-path: wiki/requirements.txt"
else
  bad "wiki-init.sh missing cache-dependency-path: wiki/requirements.txt marker"
fi

if grep -q 'cancel-in-progress: false' "$WIKI_INIT"; then
  ok "wiki-init.sh contains cancel-in-progress: false (concurrency block)"
else
  bad "wiki-init.sh missing cancel-in-progress: false marker"
fi

# 2. wiki-deploy.sh — no `mkdocs gh-deploy --force` outside comments.
if [ -f "$WIKI_DEPLOY" ]; then
  ok "scripts/wiki/wiki-deploy.sh exists"
else
  bad "scripts/wiki/wiki-deploy.sh missing"
  printf 'SUMMARY: m037-p02-workflow-pages-publishing pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

if grep -v '^[[:space:]]*#' "$WIKI_DEPLOY" | grep -q 'mkdocs gh-deploy --force'; then
  bad "wiki-deploy.sh still has unguarded 'mkdocs gh-deploy --force' outside comments (legacy live-deploy primitive must be removed)"
else
  ok "wiki-deploy.sh has no 'mkdocs gh-deploy --force' outside comments"
fi

# 3. wiki-deploy.sh contains the new push instruction + workflow URL pattern.
if grep -q 'git push origin main' "$WIKI_DEPLOY"; then
  ok "wiki-deploy.sh contains 'git push origin main' instruction"
else
  bad "wiki-deploy.sh missing 'git push origin main' instruction"
fi

if grep -q 'actions/workflows/pages.yml' "$WIKI_DEPLOY"; then
  ok "wiki-deploy.sh contains workflow URL pattern 'actions/workflows/pages.yml'"
else
  bad "wiki-deploy.sh missing workflow URL pattern 'actions/workflows/pages.yml'"
fi

# 4. wiki/README.md updates.
if [ -f "$WIKI_README" ]; then
  ok "wiki/README.md exists"
else
  bad "wiki/README.md missing"
  printf 'SUMMARY: m037-p02-workflow-pages-publishing pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

if grep -q 'git push origin main' "$WIKI_README"; then
  ok "wiki/README.md contains 'git push origin main' (deploy-flow section)"
else
  bad "wiki/README.md missing 'git push origin main'"
fi

if grep -q -E 'build_type|GitHub Actions' "$WIKI_README"; then
  ok "wiki/README.md references 'build_type' or 'GitHub Actions' (manual-recovery)"
else
  bad "wiki/README.md missing 'build_type' / 'GitHub Actions' (manual-recovery)"
fi

# Adjacency check: `bash scripts/wiki/wiki-deploy.sh` followed within 5 lines
# by `mkdocs gh-deploy` would indicate the legacy live-deploy primitive is
# still documented as the active path. Use awk to scan a sliding 5-line window.
if awk '
  /bash scripts\/wiki\/wiki-deploy\.sh/ { mark = NR }
  mark && NR <= mark + 5 && /mkdocs gh-deploy/ { print; found = 1 }
  END { exit (found ? 0 : 1) }
' "$WIKI_README" >/dev/null 2>&1; then
  bad "wiki/README.md has 'bash scripts/wiki/wiki-deploy.sh' followed within 5 lines by 'mkdocs gh-deploy' (live-deploy adjacency must not appear)"
else
  ok "wiki/README.md has no 'wiki-deploy.sh -> mkdocs gh-deploy' adjacency"
fi

# 5. Workflow test scaffold present + passing.
if [ -f "$WORKFLOW_TEST" ]; then
  ok "tests/test-wiki-init-workflow-mode.sh exists"
else
  bad "tests/test-wiki-init-workflow-mode.sh missing"
  printf 'SUMMARY: m037-p02-workflow-pages-publishing pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

if bash "$WORKFLOW_TEST" >/dev/null 2>&1; then
  ok "tests/test-wiki-init-workflow-mode.sh exits 0"
else
  bad "tests/test-wiki-init-workflow-mode.sh exits non-zero — run directly for diagnostic output"
fi

printf 'SUMMARY: m037-p02-workflow-pages-publishing pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
