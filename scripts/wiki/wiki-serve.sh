#!/usr/bin/env bash
# scripts/wiki/wiki-serve.sh — M012/P01 wiki preview launcher.
#
# Default mode: regenerate stubs + nav, then exec
#   `mkdocs serve -f wiki/mkdocs.yml` from the repo root. Binds a local port;
#   use Ctrl-C to exit.
#
# --probe mode: run `mkdocs build -f wiki/mkdocs.yml --strict` into a
#   throwaway site-dir, then remove the output. Used by verification to
#   validate the config without binding a port or blocking the caller.
#   Skips stub/nav regen — verification owns its own freshness contract.
#
# --skip-regen: skip the pre-serve stub + nav regen step. Useful for
#   fast-iteration when you know the canonical tree has not changed.
#
# --help: print usage.
#
# Exit 0 on success, non-zero on mkdocs error (propagated).
# Bash 3.2 compatible. Single-script-file shape (no inline compounds).

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
CONFIG="$PROJECT_ROOT/wiki/mkdocs.yml"

usage() {
  printf 'Usage: %s [--probe] [--skip-regen] [--help]\n' "$0"
  printf '\n'
  printf '  (default)     Regenerate stubs + nav, then run "mkdocs serve" -- binds a local port.\n'
  printf '  --probe       Run "mkdocs build --strict" to a throwaway site-dir.\n'
  printf '  --skip-regen  Skip pre-serve stub + nav regeneration.\n'
  printf '  --help        Print this message.\n'
}

MODE="serve"
SKIP_REGEN=0
for arg in "$@"; do
  case "$arg" in
    --help|-h) usage; exit 0 ;;
    --probe) MODE="probe" ;;
    --skip-regen) SKIP_REGEN=1 ;;
    *)
      printf 'FAIL: unknown argument: %s\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ ! -f "$CONFIG" ]; then
  printf 'FAIL: wiki/mkdocs.yml not found at %s\n' "$CONFIG" >&2
  exit 1
fi

if ! command -v mkdocs >/dev/null 2>&1; then
  printf 'FAIL: "mkdocs" not on PATH -- run "pip install -r wiki/requirements.txt".\n' >&2
  exit 2
fi

if [ "$MODE" = "probe" ]; then
  TMP_SITE="/tmp/m012-p01-probe-site-$$"
  set +e
  mkdocs build -f "$CONFIG" --strict --site-dir "$TMP_SITE"
  rc=$?
  set -e
  rm -rf "$TMP_SITE" 2>/dev/null || true
  exit "$rc"
fi

# Pre-serve regen — keeps wiki/docs/ in sync with .orchestrator/ canonical tree.
# Stale stubs (e.g., for renamed task files) cause mkdocs build errors that
# obscure real wiki feedback. The generators are idempotent and clean stale
# files first, so this is safe to run on every serve.
if [ "$SKIP_REGEN" -eq 0 ]; then
  printf 'REGEN: stubs + nav (use --skip-regen to skip)\n' >&2
  bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh" --root "$PROJECT_ROOT" >/dev/null
  bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-nav.sh" --root "$PROJECT_ROOT" >/dev/null
fi

exec mkdocs serve -f "$CONFIG"
