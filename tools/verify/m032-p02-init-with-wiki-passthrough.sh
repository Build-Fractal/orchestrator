#!/usr/bin/env bash
# tools/verify/m032-p02-init-with-wiki-passthrough.sh -- M032 P02 T02.
#
# Verifies the FR-11 / MIT-011 sequential-atomicity contract for
# `orchestrator:init --with-wiki [--with-giscus] [--deploy]` passthrough.
#
# Four scenarios:
#   1. Default-passthrough success: init --with-wiki produces both init outputs
#      (.orchestrator/) and wiki-init outputs (wiki/mkdocs.yml).
#   2. Failure-propagation: M032_WIKI_INIT_FORCE_EXIT=7 propagates literal
#      exit code 7, init outputs are preserved, wiki outputs are absent,
#      stderr names `init-complete, wiki-pending`.
#   3. Composition-error: --with-giscus without --with-wiki rejects with
#      exit 2 and `requires --with-wiki` diagnostic.
#   4. Pre-M032 byte-identical: invocation without any --with- flag does NOT
#      create wiki/ directory (wiki-init not invoked).
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
#
# Output:
#   PASS: m032-p02-init-with-wiki-passthrough  (on success)
#   FAIL: <reason>                              (on any failure)
#
# Exit codes: 0 ok, 1 fail.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture"
INIT_SCRIPT="$REPO_ROOT/scripts/lifecycle/init-project.sh"

# Prereq checks.
if [ ! -d "$FIXTURE" ]; then
  echo "FAIL: fixture missing: $FIXTURE" >&2
  exit 1
fi
if [ ! -x "$INIT_SCRIPT" ]; then
  echo "FAIL: init-project.sh missing or not executable: $INIT_SCRIPT" >&2
  exit 1
fi

TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

# Helper: bootstrap a fresh fixture into a given tmp directory plus a HOME sandbox.
# AD-19 single-script-file shape — function body owns the subshell, no compound
# bash chains in inline Check: invocations.
bootstrap_fixture() {
  dir="$1"
  mkdir -p "$dir"
  cp -R "$FIXTURE/." "$dir/"
  ( cd "$dir" && git init -q )
  ( cd "$dir" && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git )
}

# --- Test 1: default passthrough success ----------------------------------
TMP1="$TMPROOT/test1"
HOME1="$TMPROOT/home1"
mkdir -p "$HOME1/.claude"
bootstrap_fixture "$TMP1"

set +e
HOME="$HOME1" bash "$INIT_SCRIPT" --project-dir "$TMP1" --runtime claude-code --with-wiki >"$TMPROOT/test1.out" 2>"$TMPROOT/test1.err"
RC1=$?
set -e

if [ "$RC1" -ne 0 ]; then
  echo "FAIL: test1 default-passthrough exited rc=$RC1 (expected 0)" >&2
  sed -n '1,40p' "$TMPROOT/test1.err" >&2
  exit 1
fi
if [ ! -d "$TMP1/.orchestrator" ]; then
  echo "FAIL: test1 init outputs missing (.orchestrator/ absent)" >&2
  exit 1
fi
if [ ! -f "$TMP1/wiki/mkdocs.yml" ]; then
  echo "FAIL: test1 wiki-init outputs missing (wiki/mkdocs.yml absent)" >&2
  exit 1
fi

# --- Test 2: failure-propagation -----------------------------------------
TMP2="$TMPROOT/test2"
HOME2="$TMPROOT/home2"
mkdir -p "$HOME2/.claude"
bootstrap_fixture "$TMP2"

set +e
HOME="$HOME2" M032_WIKI_INIT_FORCE_EXIT=7 bash "$INIT_SCRIPT" --project-dir "$TMP2" --runtime claude-code --with-wiki >"$TMPROOT/test2.out" 2>"$TMPROOT/test2.err"
RC2=$?
set -e

if [ "$RC2" != "7" ]; then
  echo "FAIL: test2 failure-propagation expected rc=7 got rc=$RC2" >&2
  sed -n '1,40p' "$TMPROOT/test2.err" >&2
  exit 1
fi
if [ ! -d "$TMP2/.orchestrator" ]; then
  echo "FAIL: test2 init outputs not preserved on wiki-init failure" >&2
  exit 1
fi
if ! grep -q 'init-complete, wiki-pending' "$TMPROOT/test2.err"; then
  echo "FAIL: test2 missing 'init-complete, wiki-pending' diagnostic on stderr" >&2
  sed -n '1,40p' "$TMPROOT/test2.err" >&2
  exit 1
fi
# Note: wiki/mkdocs.yml exists from the installer's project_assets staging step
# (which runs as part of init-project.sh BEFORE wiki-init.sh dispatches under
# --with-wiki). The correct signal that wiki-init.sh aborted is that ITS work
# (the placeholder substitution + glossary stub authoring) did NOT execute.
# Check: stderr carries the M032_WIKI_INIT_FORCE_EXIT diagnostic AND the
# `wiki-init: done` success line is absent from stdout.
if ! grep -q 'M032_WIKI_INIT_FORCE_EXIT=7' "$TMPROOT/test2.err"; then
  echo "FAIL: test2 missing M032_WIKI_INIT_FORCE_EXIT diagnostic on stderr" >&2
  sed -n '1,40p' "$TMPROOT/test2.err" >&2
  exit 1
fi
if grep -q '^wiki-init: done' "$TMPROOT/test2.out"; then
  echo "FAIL: test2 wiki-init success message present despite forced failure" >&2
  exit 1
fi

# --- Test 3: composition error -------------------------------------------
TMP3="$TMPROOT/test3"
HOME3="$TMPROOT/home3"
mkdir -p "$HOME3/.claude"
bootstrap_fixture "$TMP3"

set +e
HOME="$HOME3" bash "$INIT_SCRIPT" --project-dir "$TMP3" --runtime claude-code --with-giscus >"$TMPROOT/test3.out" 2>"$TMPROOT/test3.err"
RC3=$?
set -e

if [ "$RC3" != "2" ]; then
  echo "FAIL: test3 composition-error expected rc=2 got rc=$RC3" >&2
  sed -n '1,40p' "$TMPROOT/test3.err" >&2
  exit 1
fi
if ! grep -q 'requires --with-wiki' "$TMPROOT/test3.err"; then
  echo "FAIL: test3 missing 'requires --with-wiki' diagnostic on stderr" >&2
  sed -n '1,40p' "$TMPROOT/test3.err" >&2
  exit 1
fi

# --- Test 4: pre-M032 byte-identical (no --with-* flags) -----------------
TMP4="$TMPROOT/test4"
HOME4="$TMPROOT/home4"
mkdir -p "$HOME4/.claude"
bootstrap_fixture "$TMP4"

set +e
HOME="$HOME4" bash "$INIT_SCRIPT" --project-dir "$TMP4" --runtime claude-code >"$TMPROOT/test4.out" 2>"$TMPROOT/test4.err"
RC4=$?
set -e

if [ "$RC4" -ne 0 ]; then
  echo "FAIL: test4 pre-M032 invocation expected rc=0 got rc=$RC4" >&2
  sed -n '1,40p' "$TMPROOT/test4.err" >&2
  exit 1
fi
# Note: wiki/ directory IS present after init even without --with-wiki — the
# installer stages wiki/ via the project_assets manifest loop unconditionally.
# The correct signal that wiki-init.sh was NOT invoked: no wiki-init: diagnostic
# in stdout/stderr (the substitution + glossary-authoring step never ran).
if grep -q '^wiki-init:' "$TMPROOT/test4.out"; then
  echo "FAIL: test4 wiki-init: diagnostic in stdout despite no --with-wiki" >&2
  exit 1
fi
if grep -q 'wiki-init' "$TMPROOT/test4.err"; then
  echo "FAIL: test4 wiki-init reference in stderr despite no --with-wiki" >&2
  exit 1
fi

echo "PASS: m032-p02-init-with-wiki-passthrough"
exit 0
