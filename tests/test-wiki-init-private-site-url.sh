#!/usr/bin/env bash
# tests/test-wiki-init-private-site-url.sh — M037 P02 T03 FR-21 test scaffold.
#
# Verifies wiki-init.sh's repo-visibility branch for site_url::
#   - private repo (GH_VISIBILITY_OVERRIDE=private) -> empty site_url:
#   - public  repo (GH_VISIBILITY_OVERRIDE=public)  -> https://<owner>.github.io/<repo>/
#
# Mock gh visibility via GH_VISIBILITY_OVERRIDE env var (escape hatch added
# by FR-21 implementation). Both private and public branches exercised.
# Verbatim port from .orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md
# Gap 2 (lines 419-449) with a between-cases re-install added so Case 2 has a
# clean wiki/mkdocs.yml to mutate.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT; cd "$WORK"
git init -q
git remote add origin git@github.com:Test-Org/test-repo.git
bash "$ROOT/packaging/install/install-claude-code.sh" --project-dir . --force >/dev/null

# Case 1: private
GH_VISIBILITY_OVERRIDE=private bash "$ROOT/scripts/lifecycle/wiki-init.sh" \
  --project-dir . >/dev/null
SITE_URL_LINE="$(grep '^site_url:' wiki/mkdocs.yml || echo MISSING)"
case "$SITE_URL_LINE" in
  *'""'*|MISSING) ;;
  *) echo "FAIL: private repo got non-empty site_url: $SITE_URL_LINE"; exit 1 ;;
esac

# Case 2: public
rm -rf wiki .github
bash "$ROOT/packaging/install/install-claude-code.sh" --project-dir . --force >/dev/null
GH_VISIBILITY_OVERRIDE=public bash "$ROOT/scripts/lifecycle/wiki-init.sh" \
  --project-dir . >/dev/null
grep -q '^site_url: "https://test-org.github.io/test-repo/"' wiki/mkdocs.yml || \
  { echo "FAIL: public repo got wrong site_url"; grep '^site_url:' wiki/mkdocs.yml; exit 1; }

echo "PASS: site_url branches on repo visibility"
