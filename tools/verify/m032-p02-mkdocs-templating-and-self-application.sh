#!/usr/bin/env bash
# tools/verify/m032-p02-mkdocs-templating-and-self-application.sh
#
# M032/P02/T01 verifier (Truth 3): asserts the FR-6 self-application
# loop has been closed within this task.
#
# Asserts:
#   1. wiki/mkdocs.yml at the orchestrator-repo root carries RESOLVED
#      orchestrator-identity values (site_name contains
#      "spec-kit-orchestrator", site_url is the lowercase build-fractal
#      GitHub Pages URL, repo_url points at Build-Fractal/spec-kit-orchestrator).
#   2. wiki/mkdocs.yml does NOT contain literal {{site_name}} /
#      {{site_description}} / {{site_url}} / {{repo_url}} placeholders
#      (placeholders cleared by the FR-6 self-application loop).
#   3. packaging/bundle/manifest.yml carries the additive `wiki/` entry
#      under project_assets:; the four pre-existing P01 entries
#      (commands/, scripts/, references/, templates/) are byte-preserved.
#   4. bash scripts/wiki/wiki-serve.sh succeeds (proxied via
#      tools/verify/lib/m032-p02-wiki-serve-probe.sh which runs
#      `wiki-serve.sh --probe` -> mkdocs build --strict).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
# The wiki-serve.sh start+probe+kill (or --probe) is extracted to a
# helper script per the AD-19 envelope constraint.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MKDOCS="$PROJECT_ROOT/wiki/mkdocs.yml"
MANIFEST="$PROJECT_ROOT/packaging/bundle/manifest.yml"
PROBE_HELPER="$PROJECT_ROOT/tools/verify/lib/m032-p02-wiki-serve-probe.sh"

pass=0
fail=0

check_pass() {
  pass=$((pass + 1))
  echo "PASS: $1"
}

check_fail() {
  fail=$((fail + 1))
  echo "FAIL: $1"
}

# Check 1: wiki/mkdocs.yml exists.
if [ -f "$MKDOCS" ]; then
  check_pass "$MKDOCS exists"
else
  check_fail "$MKDOCS missing"
  echo "SUMMARY: m032-p02-mkdocs-templating-and-self-application.sh pass=$pass fail=$fail"
  exit 1
fi

# Check 2: site_name resolved to orchestrator identity.
if grep -q 'site_name: "spec-kit-orchestrator' "$MKDOCS"; then
  check_pass "wiki/mkdocs.yml site_name resolved (contains 'spec-kit-orchestrator')"
else
  check_fail "wiki/mkdocs.yml site_name NOT resolved (expected 'spec-kit-orchestrator')"
fi

# Check 3: site_url resolved to lowercase build-fractal GitHub Pages URL.
if grep -q 'site_url: "https://build-fractal.github.io/spec-kit-orchestrator/"' "$MKDOCS"; then
  check_pass "wiki/mkdocs.yml site_url resolved (build-fractal.github.io/spec-kit-orchestrator/)"
else
  check_fail "wiki/mkdocs.yml site_url NOT resolved correctly"
fi

# Check 4: repo_url resolved to Build-Fractal/spec-kit-orchestrator.
if grep -q 'repo_url: "https://github.com/Build-Fractal/spec-kit-orchestrator"' "$MKDOCS"; then
  check_pass "wiki/mkdocs.yml repo_url resolved (Build-Fractal/spec-kit-orchestrator)"
else
  check_fail "wiki/mkdocs.yml repo_url NOT resolved correctly"
fi

# Check 5: site_description resolved (not the empty placeholder).
if grep -q '^site_description: "Browseable projection of .orchestrator/ artifacts for the dogfood team."' "$MKDOCS"; then
  check_pass "wiki/mkdocs.yml site_description resolved to orchestrator-identity value"
else
  check_fail "wiki/mkdocs.yml site_description NOT resolved correctly"
fi

# Check 6: NO literal {{...}} placeholders remain.
if grep -qE '\{\{(site_name|site_description|site_url|repo_url)\}\}' "$MKDOCS"; then
  check_fail "wiki/mkdocs.yml still contains {{site_*}} / {{repo_url}} placeholders (FR-6 self-application loop NOT closed)"
else
  check_pass "wiki/mkdocs.yml has no literal {{site_*}} / {{repo_url}} placeholders"
fi

# Check 7: packaging/bundle/manifest.yml exists.
if [ -f "$MANIFEST" ]; then
  check_pass "$MANIFEST exists"
else
  check_fail "$MANIFEST missing"
fi

# Check 8: manifest.yml carries the wiki/ project_assets entry.
if grep -q '^  - source: wiki/$' "$MANIFEST"; then
  check_pass "manifest.yml has 'source: wiki/' project_assets entry"
else
  check_fail "manifest.yml missing 'source: wiki/' project_assets entry"
fi

if grep -q '^    target: wiki/$' "$MANIFEST"; then
  check_pass "manifest.yml has 'target: wiki/' for wiki entry"
else
  check_fail "manifest.yml missing 'target: wiki/' for wiki entry"
fi

# Check 9: P01 entries (commands/, scripts/, references/, templates/) byte-preserved.
for src in 'commands/' 'scripts/' 'references/' 'templates/'; do
  if grep -q "^  - source: $src\$" "$MANIFEST"; then
    check_pass "manifest.yml preserves P01 'source: $src' entry"
  else
    check_fail "manifest.yml lost P01 'source: $src' entry"
  fi
done

# Check 10: wiki-serve.sh probe.
if [ -x "$PROBE_HELPER" ]; then
  check_pass "wiki-serve probe helper exists at $PROBE_HELPER"
else
  check_fail "wiki-serve probe helper missing at $PROBE_HELPER"
fi

set +e
bash "$PROBE_HELPER" >/dev/null 2>&1
probe_rc=$?
set -e

if [ "$probe_rc" -eq 0 ]; then
  check_pass "wiki-serve.sh probe (mkdocs build --strict) succeeded"
else
  check_fail "wiki-serve.sh probe failed (rc=$probe_rc)"
fi

echo "SUMMARY: m032-p02-mkdocs-templating-and-self-application.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
