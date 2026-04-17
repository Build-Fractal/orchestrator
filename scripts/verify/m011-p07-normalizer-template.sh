#!/usr/bin/env bash
# scripts/verify/m011-p07-normalizer-template.sh
# Asserts templates/spec-normalizer-prompt.md shape, placeholders,
# section layout instructions, and non-introduction directive.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$REPO/templates/spec-normalizer-prompt.md"

fail=0

if [ ! -f "$TEMPLATE" ]; then
  printf 'FAIL[exists]: %s not found\n' "$TEMPLATE"
  exit 1
fi

FRONTMATTER="
schema_version:
type: normalizer-prompt
"
for tok in $FRONTMATTER; do
  if ! grep -Fq -- "$tok" "$TEMPLATE"; then
    printf 'FAIL[frontmatter]: template missing token: %s\n' "$tok"
    fail=1
  fi
done

PLACEHOLDERS="
{{source_markdown}}
{{slug}}
"
for tok in $PLACEHOLDERS; do
  if ! grep -Fq -- "$tok" "$TEMPLATE"; then
    printf 'FAIL[placeholder]: template missing placeholder: %s\n' "$tok"
    fail=1
  fi
done

LAYOUT="
## Functional Requirements
## User Scenarios
"
# Use line-by-line to handle multi-word tokens
if ! grep -Fq -- '## Functional Requirements' "$TEMPLATE"; then
  printf 'FAIL[layout]: template missing "## Functional Requirements"\n'
  fail=1
fi
if ! grep -Fq -- '## User Scenarios' "$TEMPLATE"; then
  printf 'FAIL[layout]: template missing "## User Scenarios"\n'
  fail=1
fi

# Non-introduction directive: accept any of several phrasings
if grep -Eiq -- 'do not introduce' "$TEMPLATE"; then
  :
elif grep -Eiq -- 'must not add' "$TEMPLATE"; then
  :
elif grep -Eiq -- 'no new requirements' "$TEMPLATE"; then
  :
else
  printf 'FAIL[directive]: template missing non-introduction directive\n'
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: spec-normalizer-prompt.md template has required frontmatter, placeholders, layout, and directive"
