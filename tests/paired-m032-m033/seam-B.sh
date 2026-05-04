#!/usr/bin/env bash
# tests/paired-m032-m033/seam-B.sh — paired-launch shared invariant per #Q-B Seam-B.
#
# --with-wiki failure-propagation contract per FR-11 / MIT-011. Both M032
# (init-project.sh + wiki-init.sh authors) and M033 (downstream caller via
# orchestrator:start grilling-shell) treat this as a shared contract:
#
#   * compound exit code is wiki-init.sh's literal exit code (NOT 0, NOT 1)
#   * init outputs are PRESERVED on disk on wiki-init failure
#   * 'init-complete, wiki-pending' diagnostic appears on stderr
#   * wiki-init outputs are absent (failure aborted before staging)
#   * caller can re-run wiki-init independently after the failure
#     (M033/P01..P04 stub-mode compatibility per M033-MIT-001)
#
# Failure injected via M032_WIKI_INIT_FORCE_EXIT=7 env-var (test-only escape
# wired into wiki-init.sh by T01).
#
# Bash 3.2 compatible (MEM001).

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"
cd "$PROJECT_ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stage a fresh fixture from the P01 shared fixture (read-only baseline)
cp -R tests/fixtures/m032-fresh-project-fixture/. "$TMP/"
( cd "$TMP" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git ) >/dev/null 2>&1

# (a) Inject failure into wiki-init.sh via env-var; init-project.sh runs init then wiki-init.
set +e
M032_WIKI_INIT_FORCE_EXIT=7 bash scripts/lifecycle/init-project.sh --with-wiki --project-dir "$TMP" >"$TMP/out" 2>"$TMP/err"
RC=$?
set -e

# Compound exit code is wiki-init.sh's literal exit code (7), NOT 0, NOT 1.
[ "$RC" = "7" ] || { echo "FAIL: Seam-B compound exit expected 7 got $RC"; sed -n '1,40p' "$TMP/err"; exit 1; }

# (b) init outputs preserved on wiki-init failure
[ -d "$TMP/.orchestrator" ] || { echo "FAIL: Seam-B init outputs not preserved on wiki-init failure"; exit 1; }

# (c) init-complete, wiki-pending diagnostic on stderr
grep -q 'init-complete, wiki-pending' "$TMP/err" || { echo "FAIL: Seam-B missing init-complete, wiki-pending diagnostic"; sed -n '1,40p' "$TMP/err"; exit 1; }

# (d) wiki-init templating did not fire against the fixture identity. The install
# step (install-claude-code.sh) may have already staged wiki/ via the project_assets:
# manifest loop BEFORE wiki-init was invoked, so wiki/mkdocs.yml may be on disk --
# but with the orchestrator-local source's contents (either {{...}} placeholders
# verbatim, or pre-resolved orchestrator identity values from FR-6 dogfooding).
# The load-bearing assertion: wiki-init's templating step did NOT fire, so the
# fixture's identity ('m032-fresh-project-fixture') is NOT baked into the staged
# mkdocs.yml.
if [ -f "$TMP/wiki/mkdocs.yml" ]; then
  if grep -q 'site_name: "m032-fresh-project-fixture"' "$TMP/wiki/mkdocs.yml"; then
    echo "FAIL: Seam-B fixture identity baked into mkdocs.yml despite forced wiki-init failure"
    exit 1
  fi
fi

# (e) M033/P01..P04 stub-mode compatibility per M033-MIT-001: caller can re-run
#     wiki-init independently after the failure.
unset M032_WIKI_INIT_FORCE_EXIT
bash scripts/lifecycle/wiki-init.sh --project-dir "$TMP" >/dev/null 2>"$TMP/err2" || {
  echo "FAIL: Seam-B independent wiki-init re-run failed"
  sed -n '1,40p' "$TMP/err2"
  exit 1
}
[ -f "$TMP/wiki/mkdocs.yml" ] || { echo "FAIL: Seam-B independent wiki-init did not stage mkdocs.yml"; exit 1; }

echo "PASS: Seam-B --with-wiki failure-propagation (FR-11 / MIT-011)"
exit 0
