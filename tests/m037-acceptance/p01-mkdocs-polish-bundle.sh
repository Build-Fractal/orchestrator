#!/usr/bin/env bash
# tests/m037-acceptance/p01-mkdocs-polish-bundle.sh — M037 P01 SC-4 acceptance.
#
# Exercises FR-9: stages a fresh fixture project under a temp dir, configures
# a synthetic git remote (no network), pre-stages this repo's wiki/mkdocs.yml
# at <fixture>/wiki/mkdocs.yml, invokes wiki-init.sh --project-dir <fixture>,
# and asserts the rendered fixture mkdocs.yml carries all eight polish-bundle
# additions PLUS top-level edit_uri: derived from the fixture's git remote
# default branch via scripts/wiki/resolve-default-branch.sh (CON-4 helper).
#
# Synthetic-remote setup: `git init` + `git remote add origin <fake-url>`
# leaves `git symbolic-ref refs/remotes/origin/HEAD` empty (set-head requires
# network to query). To make the helper resolve to a real branch name without
# touching the network, we install the symbolic-ref manually:
#   git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
# This gives the resolver something to read; the polish-bundle assertion
# validates the resulting "edit/main/wiki/docs/" derivation.
#
# Phase artifact contract: this file is >= 20 lines and contains the literal
# string "navigation.prune" (M037 P01 plan must-have).
# Bash 3.2 + POSIX sh compatible.
#
# Spec references: FR-9, US-4 AS-1..AS-5, SC-4, CON-4.
# Pipeline under test: scripts/lifecycle/wiki-init.sh + scripts/wiki/resolve-default-branch.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

WIKI_INIT="$PROJECT_ROOT/scripts/lifecycle/wiki-init.sh"
RESOLVER="$PROJECT_ROOT/scripts/wiki/resolve-default-branch.sh"
SOURCE_MKDOCS="$PROJECT_ROOT/wiki/mkdocs.yml"

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

if [ ! -f "$WIKI_INIT" ]; then
  bad "wiki-init.sh missing at $WIKI_INIT"
  printf 'SC-4: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -f "$RESOLVER" ]; then
  bad "resolve-default-branch.sh missing at $RESOLVER"
  printf 'SC-4: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -f "$SOURCE_MKDOCS" ]; then
  bad "source wiki/mkdocs.yml missing at $SOURCE_MKDOCS (post-T05 polish bundle expected)"
  printf 'SC-4: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

TMPDIR_LOCAL="$(mktemp -d -t m037-p01-t05-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

FIXTURE="$TMPDIR_LOCAL/fixture-project"
mkdir -p "$FIXTURE/wiki"

# Copy this repo's polish-bundle-bearing mkdocs.yml as the fixture's pre-staged
# template so the wiki-init.sh PRE_STAGE_NO_OP branch fires (avoids invoking
# read-project-assets / install-asset-mode against a non-bundle fixture).
cp "$SOURCE_MKDOCS" "$FIXTURE/wiki/mkdocs.yml"

# Synthesize a git remote without touching the network.
git -C "$FIXTURE" init --quiet
git -C "$FIXTURE" remote add origin "https://github.com/example-org/example-repo.git"
# Manually install refs/remotes/origin/HEAD so the resolver helper reads
# "main" without `git remote set-head` (which requires network access).
mkdir -p "$FIXTURE/.git/refs/remotes/origin"
git -C "$FIXTURE" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

# Sanity-check: resolver returns "main" against the fixture.
RESOLVED_BRANCH="$(bash "$RESOLVER" "$FIXTURE" 2>/dev/null || true)"
if [ "$RESOLVED_BRANCH" = "main" ]; then
  ok "resolver returns 'main' against fixture remote"
else
  bad "resolver returned '$RESOLVED_BRANCH' against fixture remote (expected 'main')"
fi

# Invoke wiki-init.sh against the fixture. The fixture is detached from the
# orchestrator repo (--project-dir != REPO_ROOT) so SELF_APPLICATION=0; but
# wiki/mkdocs.yml pre-existing triggers PRE_STAGE_NO_OP=1 so the bundle
# staging step is skipped — the substitute-templating block below is what
# we're exercising.
INIT_LOG="$TMPDIR_LOCAL/wiki-init.log"
if bash "$WIKI_INIT" --project-dir "$FIXTURE" >"$INIT_LOG" 2>&1; then
  ok "wiki-init.sh exited 0"
else
  rc=$?
  bad "wiki-init.sh exited $rc (log: $INIT_LOG)"
  cat "$INIT_LOG" >&2 || true
  printf 'SC-4: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

RENDERED="$FIXTURE/wiki/mkdocs.yml"
if [ ! -f "$RENDERED" ]; then
  bad "rendered fixture mkdocs.yml missing at $RENDERED"
  printf 'SC-4: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Assert the eight polish-bundle additions plus top-level edit_uri:.
assert_contains() {
  _label="$1"
  _pattern="$2"
  if grep -qE "$_pattern" "$RENDERED"; then
    ok "$_label"
  else
    bad "$_label (pattern: $_pattern)"
  fi
}

assert_contains "fixture has - navigation.tabs"           '^[[:space:]]*-[[:space:]]+navigation\.tabs[[:space:]]*$'
assert_contains "fixture has - navigation.tabs.sticky"    '^[[:space:]]*-[[:space:]]+navigation\.tabs\.sticky[[:space:]]*$'
assert_contains "fixture has - navigation.prune"          '^[[:space:]]*-[[:space:]]+navigation\.prune[[:space:]]*$'
assert_contains "fixture has - content.action.edit"       '^[[:space:]]*-[[:space:]]+content\.action\.edit[[:space:]]*$'
assert_contains "fixture has - content.action.view"       '^[[:space:]]*-[[:space:]]+content\.action\.view[[:space:]]*$'
assert_contains "fixture has toc_depth: 2"                '^[[:space:]]+toc_depth:[[:space:]]+2[[:space:]]*$'
assert_contains "fixture has - pymdownx.details"          '^[[:space:]]*-[[:space:]]+pymdownx\.details[[:space:]]*$'
assert_contains "fixture has - pymdownx.tasklist:"        '^[[:space:]]*-[[:space:]]+pymdownx\.tasklist:[[:space:]]*$'
assert_contains "fixture has custom_checkbox: true"       '^[[:space:]]+custom_checkbox:[[:space:]]+true[[:space:]]*$'

# Top-level edit_uri: must derive from the fixture's git remote default branch
# (set above to refs/remotes/origin/main → "edit/main/wiki/docs/").
EXPECTED_EDIT_URI='edit_uri: "edit/main/wiki/docs/"'
if grep -qxF "$EXPECTED_EDIT_URI" "$RENDERED"; then
  ok "fixture edit_uri: derives 'edit/main/wiki/docs/' from origin HEAD"
else
  ACTUAL_EDIT_URI="$(grep -E '^edit_uri:' "$RENDERED" | head -n 1 || true)"
  bad "fixture edit_uri: missing/wrong (got '$ACTUAL_EDIT_URI', expected '$EXPECTED_EDIT_URI')"
fi

# repo_url: must have been substituted to the fixture's origin URL (proves the
# pre-existing four-field substitution still works after the fifth-field
# addition — byte-identical regression coverage).
if grep -qxF 'repo_url: "https://github.com/example-org/example-repo"' "$RENDERED"; then
  ok "fixture repo_url: substituted from fixture origin remote"
else
  bad "fixture repo_url: not substituted (regression on existing four-field path)"
fi

printf 'SUMMARY: p01-mkdocs-polish-bundle pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: p01-mkdocs-polish-bundle\n'
  exit 0
fi
exit 1
