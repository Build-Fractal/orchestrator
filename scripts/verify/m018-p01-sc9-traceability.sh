#!/usr/bin/env bash
# scripts/verify/m018-p01-sc9-traceability.sh — phase-truth verifier:
# "grammar defends against the SC-9 calibrated 34.7% floor by naming the
# per-tier modeling assumptions from P00's probe, in-document".
#
# Asserts the literal SC-9 floor (34.7) plus each per-tier 80% CI low_pct
# from the P00 probe (filter 12.55, tier1 6.24, tier2 25.33, tier3 12.10)
# all appear verbatim in references/compression-grammar.md.
#
# AD-19 single-script-file shape, bash 3.2, MEM001 PASS/FAIL, exit 0/1.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GRAMMAR="$REPO_ROOT/references/compression-grammar.md"

if [ ! -f "$GRAMMAR" ]; then
  printf 'FAIL: grammar file missing: %s\n' "$GRAMMAR" >&2
  exit 1
fi

LITERALS_FILE=$(mktemp)
trap 'rm -f "$LITERALS_FILE"' EXIT INT TERM

# label<TAB>literal — tabs are AD-19 safe inside a printf format string.
{
  printf '%s\t%s\n' 'SC-9 floor' '34.7'
  printf '%s\t%s\n' 'filter low_pct' '12.55'
  printf '%s\t%s\n' 'tier1 low_pct' '6.24'
  printf '%s\t%s\n' 'tier2 low_pct' '25.33'
  printf '%s\t%s\n' 'tier3 low_pct' '12.10'
} > "$LITERALS_FILE"

MISS_COUNT=0

while IFS=$'\t' read -r label literal; do
  if grep -qF "$literal" "$GRAMMAR"; then
    printf 'PASS: %s literal %s present\n' "$label" "$literal"
  else
    printf 'FAIL: %s literal %s missing from %s\n' "$label" "$literal" "$GRAMMAR" >&2
    MISS_COUNT=$((MISS_COUNT + 1))
  fi
done < "$LITERALS_FILE"

if [ "$MISS_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
