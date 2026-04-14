#!/usr/bin/env bash
# Verifies new P03 scripts avoid Bash 4+ constructs per MEM001 (NFR-200).
# Matches the pattern from m008-p01-bash32-compat.sh and
# m008-p02-bash32-compat.sh.
set -u

scripts="
scripts/engine/intensity-gate.sh
scripts/engine/intensity-override.sh
scripts/knowledge/intensity-knowledge.sh
"

fail=0
for s in $scripts; do
  if [[ ! -f "$s" ]]; then
    echo "FAIL: $s missing"
    fail=1
    continue
  fi

  # declare -A = associative arrays (bash 4+)
  if grep -nE '^[[:space:]]*(declare|typeset|local)[[:space:]]+-A[[:space:]]' "$s" >/dev/null; then
    echo "FAIL: $s uses 'declare -A' (bash 4+ associative arrays)"
    fail=1
  fi

  # readarray / mapfile (bash 4+)
  if grep -nE '^[[:space:]]*(readarray|mapfile)[[:space:]]' "$s" >/dev/null; then
    echo "FAIL: $s uses readarray/mapfile (bash 4+)"
    fail=1
  fi

  # |& (bash 4+ redirect)
  if grep -nE '\|&' "$s" >/dev/null; then
    echo "FAIL: $s uses '|&' redirect (bash 4+)"
    fail=1
  fi

  # Process substitution inside script (would break in /bin/sh; bash 3.2 ok but we avoid)
  # NB: this is a style choice aligned with AD-19 (harness heuristic).
  if grep -nE '<\(|>\(' "$s" >/dev/null; then
    echo "FAIL: $s uses process substitution '<(...)' or '>(...)'"
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  exit 1
fi

echo "PASS: all P03 scripts are Bash 3.2 compatible"
