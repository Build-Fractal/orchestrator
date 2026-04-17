#!/usr/bin/env bash
# scripts/verify/m021-p04-bash32-compat.sh -- Bash 3.2 compatibility scan for P04 files.
#
# Asserts all seven P04 shell files parse clean via bash -n and contain no
# forbidden Bash-4 constructs.
#
# Exit 0 on all-pass; 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

targets="
scripts/verify/replay-prompt-corpus.sh
scripts/verify/m021-p04-dogfood-attestation.sh
scripts/verify/m021-p04-corpus-shape.sh
scripts/verify/m021-p04-decisions-d012.sh
scripts/verify/m021-p04-antipatterns-crossrefs.sh
scripts/verify/m021-p04-bash32-compat.sh
scripts/verify/m021-p04-phase-suite.sh
"

# Forbidden constructs. Split across assignments to avoid the gate's own
# source matching its own needles during self-inspection.
FORBID_A='declare'' -A'
FORBID_B='map''file'
FORBID_C='read''array'
# Case-conversion parameter expansion forms -- assembled so this source does not self-match.
FORBID_D='${''var'',,}'
FORBID_E='${''var''^^}'
FORBID_F='${!''prefix''*}'
# Process substitution open-paren -- split to avoid self-match.
FORBID_G='<''('

for rel in $targets; do
  f="${REPO_ROOT}/${rel}"
  if [ ! -f "$f" ]; then
    fail "file present: $rel" "not found"
    continue
  fi

  if bash -n "$f" 2>/dev/null; then
    pass "parse: $rel"
  else
    fail "parse: $rel" "bash -n failed"
  fi

  _stripped="$(grep -v '^[[:space:]]*#' "$f")"
  for needle in "$FORBID_A" "$FORBID_B" "$FORBID_C" "$FORBID_D" "$FORBID_E" "$FORBID_F" "$FORBID_G"; do
    if printf '%s' "$_stripped" | grep -qF "$needle"; then
      fail "forbidden in $rel" "found [$needle]"
    fi
  done
  pass "forbidden-construct scan: $rel"
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m021-p04-bash32-compat.sh ($fail_count failures)"
exit 1
