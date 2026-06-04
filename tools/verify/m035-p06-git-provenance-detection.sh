#!/usr/bin/env bash
# tools/verify/m035-p06-git-provenance-detection.sh
#
# Regression guard for the 2026-06 update-channel fix (run-update.sh
# resolve_update_source step 2a-bis):
#
# install-meta.txt has no explicit channel field; the `runtime=` field it
# DOES record is always the runtime type (claude-code), never the install
# channel. Before the fix, a git/source-repo install matched no channel case
# and fell through to step 2b (npm global presence) — which silently captured
# every git-origin project as `npm` once @build-fractal/orchestrator was
# published to the npm registry, flipping dogfood projects off their local
# tree onto the registry build. The fix detects git from the provenance
# signal that IS recorded: a populated `commit_sha=` (set only when the
# install's source_root is a git working tree).
#
# Asserts:
#   1. git-provenance install-meta (commit_sha set) + no `update_source` in
#      config resolves to the GIT channel — even on a machine where the npm
#      global package is present (the exact condition that triggered the bug).
#   2. git detection is not persisted into config (re-detected each run).
#
# Uses run-update.sh --dry-run so nothing is installed. Bash 3.2 safe.
set -uo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
RUN_UPDATE="$REPO/scripts/lifecycle/run-update.sh"

pass=0
fail=0

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t m035p06prov)"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT
PROJ="$TMP/proj"
mkdir -p "$PROJ/.orchestrator"

# Git-provenance install-meta: commit_sha populated == installed from a git
# working tree. source_root points at this repo (a real git tree).
{
  printf 'source_root=%s\n' "$REPO"
  printf 'runtime=claude-code\n'
  printf 'installed_at=2026-06-03T12:00:00Z\n'
  printf 'commit_sha=e5707470aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n'
  printf 'version=0.9.5\n'
} > "$PROJ/.orchestrator/install-meta.txt"

# Config WITHOUT update_source — forces AD-5 detection (Path 2).
{
  printf 'schema_version: "1.0"\n'
  printf 'type: orchestrator-config\n'
} > "$PROJ/.orchestrator/config.yml"

OUT="$TMP/dryrun.log"
bash "$RUN_UPDATE" --dry-run --project-dir "$PROJ" --source-repo "$REPO" >"$OUT" 2>&1

# Channel discriminator: the git arm's dry-run emits a would_invoke= for
# install-claude-code.sh; the npm arm emits `would_invoke=npm update -g`.
if grep -q 'install-claude-code.sh' "$OUT" && ! grep -q 'npm update -g' "$OUT"; then
  echo "PASS: git-provenance install-meta resolves to the git channel (not npm)"
  pass=$((pass + 1))
else
  echo "FAIL: git-provenance did not resolve to git (npm-presence captured it)"
  sed 's/^/    /' "$OUT"
  fail=$((fail + 1))
fi

# git detection must not be persisted (avoids noising fresh consumer configs;
# it is re-detected from install-meta on every run).
if ! grep -qE '^update_source:' "$PROJ/.orchestrator/config.yml"; then
  echo "PASS: git detection not persisted into config.yml"
  pass=$((pass + 1))
else
  echo "FAIL: git detection was persisted into config.yml (should re-detect each run)"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
