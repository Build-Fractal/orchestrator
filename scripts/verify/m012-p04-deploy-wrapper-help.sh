#!/usr/bin/env bash
# scripts/verify/m012-p04-deploy-wrapper-help.sh — M012/P04 T03 gate.
#
# Runs `bash scripts/wiki/wiki-deploy.sh --help`, asserts exit 0, and
# greps stdout for every documented flag + every chained gate basename
# + the `mkdocs gh-deploy` command. The goal: an operator who runs only
# --help must be able to reconstruct the deploy pipeline contract
# without reading the source.
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

HELP_OUT="/tmp/m012-p04-deploy-help.$$.out"
# shellcheck disable=SC2064
trap "rm -f '$HELP_OUT'" EXIT INT TERM

rc=0
bash "$WRAPPER" --help >"$HELP_OUT" 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: --help exit %d != 0\n' "$rc" >&2
  sed 's/^/  /' "$HELP_OUT" >&2
  exit 1
fi

# Required tokens in --help stdout.
for kw in \
  '--dry-run' \
  '--help' \
  '--root' \
  '--skip-smoke' \
  'wiki-giscus-config-check.sh' \
  'wiki-link-check.sh' \
  'wiki-giscus-smoke.sh' \
  'mkdocs gh-deploy'
do
  if ! grep -qF -- "$kw" "$HELP_OUT"; then
    printf 'FAIL: --help missing token %s\n' "$kw" >&2
    sed 's/^/  /' "$HELP_OUT" >&2
    exit 1
  fi
done

printf 'PASS: --help enumerates 4 flags, 4 chained gates, and mkdocs gh-deploy\n'
exit 0
