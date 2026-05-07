#!/usr/bin/env bash
# tests/test-wiki-init-staged-invocation.sh
#
# Verify wiki-init.sh works when invoked from a project that has the
# orchestrator runtime staged in (the operator-facing happy path documented
# in the M032 wiki-deploy quickstart). Repros and gates the regression
# surfaced by the M037 P01 wiki-deploy first-deploy session against
# pbj-central-mono-repo:
#   - scripts/lifecycle/wiki-init.sh:36 computes REPO_ROOT as ../.. of $0,
#     which resolves to the staged-into project, not the orchestrator
#     source repo.
#   - packaging/ is intentionally NOT staged into projects (see
#     packaging/bundle/manifest.yml's project_assets list), so the staged
#     wiki-init.sh would fail at the manifest read with `FAIL: manifest
#     not found` before its self-application detection could run.
# The fix: install-meta.txt sidecar with source_root=<abs> + REPO_ROOT
# fallback gated on manifest absence. This test fails before the patch
# and passes after.
#
# Uses install-cursor.sh because it requires no runtime binary to probe
# (adapter only checks for .cursor/) and shares the Stage 4.5 +
# install-meta.txt write with claude-code/codex.
#
# Bash 3.2 compatible. MIT-001 SKIP_REASON when python3 unavailable.

set -u

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

if ! command -v python3 >/dev/null 2>&1 || ! command -v pip3 >/dev/null 2>&1; then
  echo "SKIP_REASON: python3/pip3 unavailable on this host (wiki-init FR-12 toolchain probe)"
  exit 77
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$REPO_ROOT/packaging/install/install-cursor.sh"

if [ ! -f "$INSTALLER" ]; then
  fail "installer missing at $INSTALLER"
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
fi

TMP="$(mktemp -d -t wiki-init-staged.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

PROJECT="$TMP/proj"
mkdir -p "$PROJECT/.cursor"
mkdir -p "$PROJECT/.orchestrator/milestones"

# Stage the orchestrator runtime into PROJECT.
if ! bash "$INSTALLER" --project-dir "$PROJECT" >"$TMP/install.log" 2>&1; then
  fail "installer failed against $PROJECT (rc=$?)"
  sed -n '1,40p' "$TMP/install.log" >&2 || true
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
fi

# 1. install-meta.txt sidecar present with source_root=$REPO_ROOT.
META_FILE="$PROJECT/.orchestrator/install-meta.txt"
if [ -f "$META_FILE" ] && grep -qF "source_root=$REPO_ROOT" "$META_FILE"; then
  pass "install-meta.txt records source_root=$REPO_ROOT"
else
  fail "install-meta.txt missing or source_root entry absent"
  [ -f "$META_FILE" ] && sed -n '1,10p' "$META_FILE" >&2 || echo "($META_FILE absent)" >&2
fi

# 2. Staged wiki-init.sh is on disk.
STAGED="$PROJECT/scripts/lifecycle/wiki-init.sh"
if [ ! -f "$STAGED" ]; then
  fail "staged wiki-init.sh missing at $STAGED (installer did not stage scripts/lifecycle/)"
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
fi

# 3. PROJECT has no packaging/ (paranoia — proves the failure mode is real).
if [ ! -d "$PROJECT/packaging" ]; then
  pass "PROJECT lacks packaging/ (operator-facing condition reproduced)"
else
  fail "PROJECT unexpectedly has packaging/ — fixture invalid"
fi

# 4. Configure git remote so wiki-init's FR-5 origin parser succeeds.
( cd "$PROJECT" && git init -q && git remote add origin git@github.com:Test-Org/test-repo.git ) >/dev/null 2>&1

# 5. Invoke STAGED wiki-init from PROJECT — the operator-facing happy path.
#    Default scope (no --with-giscus, no --deploy). The patch must let
#    REPO_ROOT fall back to the install-meta.txt-recorded source_root so
#    that read-project-assets.sh finds packaging/bundle/manifest.yml.
set +e
WIKI_LOG="$TMP/wiki-init.log"
bash "$STAGED" --project-dir "$PROJECT" >"$WIKI_LOG" 2>&1
WIKI_RC=$?
set -e

if grep -qF 'FAIL: manifest not found' "$WIKI_LOG"; then
  fail "staged invocation hit 'manifest not found' (rc=$WIKI_RC)"
  sed -n '1,40p' "$WIKI_LOG" >&2 || true
elif grep -qF 'FAIL: wiki-init: read-project-assets.sh exited' "$WIKI_LOG"; then
  fail "staged invocation tripped read-project-assets failure (rc=$WIKI_RC)"
  sed -n '1,40p' "$WIKI_LOG" >&2 || true
else
  pass "staged invocation did not fail at manifest resolution (rc=$WIKI_RC)"
fi

if [ "$WIKI_RC" -eq 0 ]; then
  pass "staged wiki-init exited 0 against PROJECT"
else
  fail "staged wiki-init exited $WIKI_RC; expected 0"
  sed -n '1,40p' "$WIKI_LOG" >&2 || true
fi

# 6. mkdocs.yml staged at PROJECT/wiki/mkdocs.yml with the project's
#    site identity (proves the source_root fallback resolved to the
#    canonical bundle wiki tree, not a stub).
MKDOCS="$PROJECT/wiki/mkdocs.yml"
if [ -f "$MKDOCS" ] && grep -qF 'site_name: "test-repo"' "$MKDOCS"; then
  pass "wiki/mkdocs.yml staged + site-identity templated against project's git remote"
else
  fail "wiki/mkdocs.yml missing or site_name not templated"
  [ -f "$MKDOCS" ] && sed -n '1,10p' "$MKDOCS" >&2 || echo "($MKDOCS absent)" >&2
fi

# 7. WIKI_INIT_SOURCE_ROOT env override path: even with install-meta.txt
#    removed, an explicit env var lets the staged invocation succeed.
rm -f "$META_FILE"
rm -rf "$PROJECT/wiki"  # force a fresh staging pass
set +e
WIKI_LOG2="$TMP/wiki-init-env.log"
WIKI_INIT_SOURCE_ROOT="$REPO_ROOT" bash "$STAGED" --project-dir "$PROJECT" >"$WIKI_LOG2" 2>&1
WIKI_RC2=$?
set -e
if [ "$WIKI_RC2" -eq 0 ] && [ -f "$MKDOCS" ]; then
  pass "WIKI_INIT_SOURCE_ROOT env override resolves manifest when install-meta.txt absent"
else
  fail "WIKI_INIT_SOURCE_ROOT override path failed (rc=$WIKI_RC2)"
  sed -n '1,40p' "$WIKI_LOG2" >&2 || true
fi

echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
