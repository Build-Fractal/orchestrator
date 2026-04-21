#!/usr/bin/env bash
# scripts/verify/m012-p04-readme-first-deploy.sh — M012/P04 T02 gate.
#
# Asserts wiki/README.md carries the operator's first-deploy guide:
#   - `## First-deploy checklist` section heading
#   - `## Running the deploy wrapper` section heading
#   - every GISCUS_* env-var name (by literal string)
#   - `gh-pages` branch name
#   - `mkdocs gh-deploy` command
#   - `Discussions` feature name
#   - `discussions category` onboarding step
#   - `wiki-deploy.sh` wrapper reference
#
# Maps to US3 / SC-4 / SC-9. Bash 3.2 compatible.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

README="$ROOT/wiki/README.md"
if [ ! -f "$README" ]; then
  printf 'FAIL: %s not found\n' "$README" >&2
  exit 1
fi

# Required section headings (exact line-anchored match).
for hdr in '^## First-deploy checklist$' '^## Running the deploy wrapper$'; do
  count=$(grep -c -E "$hdr" "$README" | tr -d '[:space:]')
  if [ "$count" != "1" ]; then
    printf 'FAIL: %s expected one /%s/ heading, got %s\n' "$README" "$hdr" "$count" >&2
    exit 1
  fi
done

# Required literal strings (substrings).
for needle in \
  'GISCUS_REPO' \
  'GISCUS_REPO_ID' \
  'GISCUS_CATEGORY' \
  'GISCUS_CATEGORY_ID' \
  'gh-pages' \
  'mkdocs gh-deploy' \
  'Discussions' \
  'discussions category' \
  'wiki-deploy.sh'
do
  if ! grep -qF "$needle" "$README"; then
    printf 'FAIL: %s missing required string %s\n' "$README" "$needle" >&2
    exit 1
  fi
done

lines=$(wc -l < "$README" | tr -d '[:space:]')
[ -z "$lines" ] && lines=0

printf 'PASS: README first-deploy checklist + deploy-wrapper sections present (%s lines)\n' "$lines"
exit 0
