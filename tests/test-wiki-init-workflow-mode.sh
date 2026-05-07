#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
git init -q
git remote add origin git@github.com:Test-Org/test-repo.git
bash "$ROOT/packaging/install/install-claude-code.sh" --project-dir . --force >/dev/null
bash scripts/lifecycle/wiki-init.sh --project-dir . >/dev/null

test -f .github/workflows/pages.yml || { echo "FAIL: pages.yml not scaffolded"; exit 1; }
grep -q "actions/deploy-pages" .github/workflows/pages.yml || \
  { echo "FAIL: workflow does not use actions/deploy-pages"; exit 1; }
grep -q "actions/upload-pages-artifact" .github/workflows/pages.yml || \
  { echo "FAIL: workflow does not use upload-pages-artifact"; exit 1; }

if grep -q "mkdocs gh-deploy" scripts/wiki/wiki-deploy.sh; then
  grep -q "DRY_RUN\|--dry-run\|local-only" scripts/wiki/wiki-deploy.sh || \
    { echo "FAIL: wiki-deploy.sh still has unguarded mkdocs gh-deploy"; exit 1; }
fi

echo "PASS: wiki-init scaffolds workflow-based publishing"
