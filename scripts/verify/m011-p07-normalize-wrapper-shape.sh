#!/usr/bin/env bash
# scripts/verify/m011-p07-normalize-wrapper-shape.sh
# Asserts structural properties of scripts/knowledge/normalize-spec.sh
# without running it end-to-end.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO/scripts/knowledge/normalize-spec.sh"

fail=0

if [ ! -f "$SCRIPT" ]; then
  printf 'FAIL[exists]: %s not found\n' "$SCRIPT"
  exit 1
fi

if [ ! -x "$SCRIPT" ]; then
  printf 'FAIL[executable]: %s is not executable\n' "$SCRIPT"
  fail=1
fi

REQUIRED="
--spec-path
--slug
--force
dispatch-interface.sh
NORMALIZED:
SKIPPED:
NORMALIZER_STUB
"

for tok in $REQUIRED; do
  if ! grep -Fq -- "$tok" "$SCRIPT"; then
    printf 'FAIL[token]: normalize-spec.sh missing required token: %s\n' "$tok"
    fail=1
  fi
done

# No hardcoded LLM HTTP calls
if grep -Eq '(curl|wget)[[:space:]]' "$SCRIPT"; then
  printf 'FAIL[no-http]: normalize-spec.sh contains hardcoded curl/wget call\n'
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: normalize-spec.sh has required wrapper shape and no hardcoded HTTP calls"
