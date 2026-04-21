#!/usr/bin/env bash
# scripts/wiki/wiki-serve.sh — M012/P01 wiki preview launcher.
#
# Default mode: exec `mkdocs serve -f wiki/mkdocs.yml` from the repo root.
#   Binds a local port; use Ctrl-C to exit.
#
# --probe mode: run `mkdocs build -f wiki/mkdocs.yml --strict` into a
#   throwaway site-dir, then remove the output. Used by verification to
#   validate the config without binding a port or blocking the caller.
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
  printf 'Usage: %s [--probe] [--help]\n' "$0"
  printf '\n'
  printf '  (default)   Run "mkdocs serve -f wiki/mkdocs.yml" -- binds a local port.\n'
  printf '  --probe     Run "mkdocs build --strict" to a throwaway site-dir.\n'
  printf '  --help      Print this message.\n'
}

MODE="serve"
if [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi
if [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi
if [ "${1:-}" = "--probe" ]; then
  MODE="probe"
fi

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

exec mkdocs serve -f "$CONFIG"
