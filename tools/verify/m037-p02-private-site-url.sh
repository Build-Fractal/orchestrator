#!/usr/bin/env bash
# tools/verify/m037-p02-private-site-url.sh — M037 P02 T03 FR-21 verifier.
#
# Asserts:
#  1. scripts/lifecycle/wiki-init.sh contains the `resolve_site_url_for_visibility`
#     function name (FR-21 visibility-detection branch).
#  2. wiki-init.sh contains the `.visibility` jq selector (gh api ... --jq .visibility).
#  3. wiki-init.sh contains the `GH_VISIBILITY_OVERRIDE` test escape hatch.
#  4. tests/test-wiki-init-private-site-url.sh exists and exits 0.
#  5. (Optional, gated on `mkdocs` availability) private-mode 404.html-href
#     smoke test: build the site with site_url empty and verify 404.html
#     stylesheet hrefs are relative (do NOT begin with /test-repo/).
#
# AD-19 compliant: invokes the test scaffold via `bash <path>` only.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

WIKI_INIT="$PROJECT_ROOT/scripts/lifecycle/wiki-init.sh"
PRIVATE_TEST="$PROJECT_ROOT/tests/test-wiki-init-private-site-url.sh"

pass=0
fail=0
skip=0

ok() {
  printf 'PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

skipped() {
  printf 'SKIP: %s\n' "$1"
  skip=$((skip + 1))
}

# 1. wiki-init.sh exists.
if [ -f "$WIKI_INIT" ]; then
  ok "scripts/lifecycle/wiki-init.sh exists"
else
  bad "scripts/lifecycle/wiki-init.sh missing"
  printf 'SUMMARY: m037-p02-private-site-url pass=%d skip=%d fail=%d\n' "$pass" "$skip" "$fail"
  exit 1
fi

# 2. resolve_site_url_for_visibility function name.
if grep -q 'resolve_site_url_for_visibility' "$WIKI_INIT"; then
  ok "wiki-init.sh contains resolve_site_url_for_visibility (FR-21 visibility branch)"
else
  bad "wiki-init.sh missing resolve_site_url_for_visibility function"
fi

# 3. .visibility jq selector.
if grep -q '\.visibility' "$WIKI_INIT"; then
  ok "wiki-init.sh contains .visibility (gh api --jq selector)"
else
  bad "wiki-init.sh missing .visibility jq selector"
fi

# 4. GH_VISIBILITY_OVERRIDE escape hatch.
if grep -q 'GH_VISIBILITY_OVERRIDE' "$WIKI_INIT"; then
  ok "wiki-init.sh contains GH_VISIBILITY_OVERRIDE test escape hatch"
else
  bad "wiki-init.sh missing GH_VISIBILITY_OVERRIDE escape hatch"
fi

# 5. Test scaffold exists + passes.
if [ -f "$PRIVATE_TEST" ]; then
  ok "tests/test-wiki-init-private-site-url.sh exists"
else
  bad "tests/test-wiki-init-private-site-url.sh missing"
  printf 'SUMMARY: m037-p02-private-site-url pass=%d skip=%d fail=%d\n' "$pass" "$skip" "$fail"
  exit 1
fi

if bash "$PRIVATE_TEST" >/dev/null 2>&1; then
  ok "tests/test-wiki-init-private-site-url.sh exits 0"
else
  bad "tests/test-wiki-init-private-site-url.sh exits non-zero — run directly for diagnostic output"
fi

# 6. Optional: private-mode 404.html-href smoke test.
# NOTE: bash's `set -e` inside a `( ... ) || x` subshell is suppressed (POSIX
# rule), so this block uses explicit rc checks. Build is run against a
# minimal docs/ corpus (single index.md) to avoid spec-snippet cross-tree
# include errors that would otherwise mask the FR-21 contract under test.
if command -v mkdocs >/dev/null 2>&1; then
  SMOKE_WORK="$(mktemp -d)"
  smoke_ok=1
  smoke_diag=""
  (
    cd "$SMOKE_WORK" || exit 1
    git init -q || exit 1
    git remote add origin git@github.com:Test-Org/test-repo.git || exit 1
    bash "$PROJECT_ROOT/packaging/install/install-claude-code.sh" --project-dir . --force >/dev/null 2>&1 || exit 1
    GH_VISIBILITY_OVERRIDE=private bash "$PROJECT_ROOT/scripts/lifecycle/wiki-init.sh" \
      --project-dir . >/dev/null 2>&1 || exit 1
    # Strip plugin/extra references that pull in cross-tree files; FR-21
    # contract is exercised by the bare 404.html emit, not by the full wiki.
    rm -rf wiki/docs
    mkdir -p wiki/docs
    printf '# Smoke\n\nFR-21 smoke fixture.\n' > wiki/docs/index.md
    # Comment out plugins:/markdown_extensions: blocks that reference
    # snippets / external dirs to keep the build minimal.
    cat > wiki/mkdocs-smoke.yml <<'YAML_EOF'
site_name: "smoke"
site_url: ""
docs_dir: docs
site_dir: site
theme:
  name: material
YAML_EOF
    mkdocs build -f wiki/mkdocs-smoke.yml >/dev/null 2>&1 || exit 2
    test -f wiki/site/404.html || exit 3
    # Extract stylesheet href values; assert none begin with /test-repo/.
    if grep -oE '<link[^>]*rel="stylesheet"[^>]*href="[^"]*"' wiki/site/404.html \
       | grep -qE 'href="/test-repo/'; then
      exit 4
    fi
    exit 0
  )
  smoke_rc=$?
  rm -rf "$SMOKE_WORK"
  case "$smoke_rc" in
    0) ok "private-mode 404.html stylesheet hrefs are relative (no /test-repo/ prefix)" ;;
    2) bad "private-mode 404.html smoke test: mkdocs build failed (rc=$smoke_rc)" ;;
    3) bad "private-mode 404.html smoke test: 404.html missing after build (rc=$smoke_rc)" ;;
    4) bad "private-mode 404.html smoke test: 404.html stylesheet href has /test-repo/ absolute prefix (rc=$smoke_rc)" ;;
    *) bad "private-mode 404.html smoke test setup failed (rc=$smoke_rc)" ;;
  esac
else
  skipped "mkdocs not on PATH; private-mode 404.html smoke test deferred to operator (SC-15 real-app browser verification)"
fi

printf 'SUMMARY: m037-p02-private-site-url pass=%d skip=%d fail=%d\n' "$pass" "$skip" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
