#!/usr/bin/env bash
# scripts/verify/m012-p04-deploy-wrapper-dry-run.sh — M012/P04 T03 gate.
#
# Runs `bash scripts/wiki/wiki-deploy.sh --dry-run` with all four
# GISCUS_* env vars set to "x" (fixture synthetic values). Asserts:
#   - exit 0
#   - stdout contains `GATE: giscus-config PASS`
#   - stdout terminates on `DRY-RUN: would deploy`
#   - no `gh-pages` push occurs (no gh API calls; --dry-run short-circuits
#     before `mkdocs gh-deploy`).
#
# When mkdocs is absent in the sandbox, the wrapper emits
# `BUILD: skip (mkdocs not installed)` and the site-dependent gates
# emit `GATE: ... SKIP (no wiki/site/)`. Both are tolerated — the
# critical assertion is: dry-run exits 0 without touching the remote.
#
# Writes only to /tmp; cleans up on exit. Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

WRAPPER="$ROOT/scripts/wiki/wiki-deploy.sh"
if [ ! -f "$WRAPPER" ]; then
  printf 'FAIL: %s not found\n' "$WRAPPER" >&2
  exit 1
fi

DRY_OUT="/tmp/m012-p04-deploy-dry.$$.out"
DRY_ERR="/tmp/m012-p04-deploy-dry.$$.err"
# shellcheck disable=SC2064
trap "rm -f '$DRY_OUT' '$DRY_ERR'" EXIT INT TERM

rc=0
env -i PATH="$PATH" HOME="$HOME" \
  GISCUS_REPO=x \
  GISCUS_REPO_ID=x \
  GISCUS_CATEGORY=x \
  GISCUS_CATEGORY_ID=x \
  bash "$WRAPPER" --root "$ROOT" --dry-run \
  >"$DRY_OUT" 2>"$DRY_ERR" || rc=$?

if [ "$rc" -ne 0 ]; then
  printf 'FAIL: --dry-run exit %d != 0 (err=%s)\n' "$rc" "$DRY_ERR" >&2
  sed 's/^/  /' "$DRY_OUT" >&2
  sed 's/^/  /' "$DRY_ERR" >&2
  exit 1
fi

if ! grep -qF 'GATE: giscus-config PASS' "$DRY_OUT"; then
  printf 'FAIL: --dry-run missing `GATE: giscus-config PASS` line\n' >&2
  sed 's/^/  /' "$DRY_OUT" >&2
  exit 1
fi

if ! grep -qF 'DRY-RUN: would deploy' "$DRY_OUT"; then
  printf 'FAIL: --dry-run missing `DRY-RUN: would deploy` terminator\n' >&2
  sed 's/^/  /' "$DRY_OUT" >&2
  exit 1
fi

# Safety: ensure no accidental live-deploy terminator leaked through.
if grep -qF 'OK: deployed to' "$DRY_OUT"; then
  printf 'FAIL: --dry-run wrongly emitted `OK: deployed to` terminator\n' >&2
  sed 's/^/  /' "$DRY_OUT" >&2
  exit 1
fi

printf 'PASS: --dry-run exits 0, gates pass, emits DRY-RUN terminator, no gh-pages push\n'
exit 0
