#!/usr/bin/env bash
# scripts/verify/m012-p04-deploy-wrapper-contract.sh — M012/P04 T03 gate.
#
# Static assertions on scripts/wiki/wiki-deploy.sh:
#   - file exists
#   - executable bit set
#   - contains `set -u`
#   - declares a `usage()` function
#   - references each of the four chained diagnostic basenames:
#       wiki-giscus-config-check.sh
#       wiki-link-check.sh
#       wiki-giscus-smoke.sh
#       mkdocs gh-deploy
#   - at least 120 lines (size floor per P04-PLAN artifact spec)
#
# Bash 3.2 compatible. Single-script-file shape.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

WRAPPER="$ROOT/scripts/wiki/wiki-deploy.sh"
if [ ! -f "$WRAPPER" ]; then
  printf 'FAIL: %s not found\n' "$WRAPPER" >&2
  exit 1
fi
if [ ! -x "$WRAPPER" ]; then
  printf 'FAIL: %s not executable\n' "$WRAPPER" >&2
  exit 1
fi

# `set -u` — must appear at non-comment column, roughly at script top.
if ! grep -qE '^set -u' "$WRAPPER"; then
  printf 'FAIL: %s missing `set -u`\n' "$WRAPPER" >&2
  exit 1
fi

# `usage()` function declaration.
if ! grep -qE '^usage\(\)' "$WRAPPER"; then
  printf 'FAIL: %s missing usage() function\n' "$WRAPPER" >&2
  exit 1
fi

# Four chained basenames + the deploy command.
for needle in \
  'wiki-giscus-config-check.sh' \
  'wiki-link-check.sh' \
  'wiki-giscus-smoke.sh' \
  'mkdocs gh-deploy'
do
  if ! grep -qF "$needle" "$WRAPPER"; then
    printf 'FAIL: %s missing required reference %s\n' "$WRAPPER" "$needle" >&2
    exit 1
  fi
done

# Four supported flags (documented in contract).
# Use `grep -e --` so BSD grep doesn't interpret the `--flag` literals
# as grep options.
for flag in '--dry-run' '--help' '--root' '--skip-smoke'; do
  if ! grep -qF -e "$flag" -- "$WRAPPER"; then
    printf 'FAIL: %s missing flag %s\n' "$WRAPPER" "$flag" >&2
    exit 1
  fi
done

lines=$(wc -l < "$WRAPPER" | tr -d '[:space:]')
[ -z "$lines" ] && lines=0
if [ "$lines" -lt 120 ]; then
  printf 'FAIL: %s %s lines (< 120)\n' "$WRAPPER" "$lines" >&2
  exit 1
fi

printf 'PASS: wiki-deploy.sh contract honored (%s lines; 4 gates, 4 flags, usage(), set -u)\n' "$lines"
exit 0
