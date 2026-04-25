#!/usr/bin/env bash
# m020-p05-feature-vector-extension.sh -- assert lib/jaccard.sh has been
# extended with relates_to + source_unit + 200-token body cap, and the
# regenerated validation report exists at the P05 path with the new
# vector signature documented.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/jaccard.sh"
REPORT="$ROOT/.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md"

if [ ! -f "$LIB" ]; then
  echo "FAIL: $LIB does not exist"
  exit 1
fi
if [ ! -f "$REPORT" ]; then
  echo "FAIL: $REPORT does not exist (P05 validation report missing)"
  exit 1
fi

# Feature vector extension: lib/jaccard.sh must mention relates_to and source_unit.
if ! grep -q 'relates_to' "$LIB"; then
  echo "FAIL: lib/jaccard.sh does not reference relates_to (vector extension missing)"
  exit 1
fi
if ! grep -q 'source_unit' "$LIB"; then
  echo "FAIL: lib/jaccard.sh does not reference source_unit (vector extension missing)"
  exit 1
fi

# Token cap moved to 200 (was 50). Look for `head -200` literal.
if ! grep -q 'head -200' "$LIB"; then
  echo "FAIL: lib/jaccard.sh does not contain 'head -200' (token cap not raised to 200)"
  exit 1
fi

# Body extraction must not terminate at first blank line -- i.e. the printed
# block under NR>=s must not contain `if (/^\$/) { ...; exit; ... }`. We
# settle for asserting the new body-extraction shape by checking the absence
# of the `printed=1` v1 sentinel (which is unique to first-paragraph mode).
if grep -q 'printed=1' "$LIB"; then
  echo "FAIL: lib/jaccard.sh still uses first-paragraph extraction (v1) -- printed=1 sentinel found"
  exit 1
fi

# P05 report content: must mention relates_to and source_unit and CON-5 v2.
if ! grep -q 'relates_to' "$REPORT"; then
  echo "FAIL: P05 jaccard-validation-report does not document relates_to in the extended vector"
  exit 1
fi
if ! grep -q 'source_unit' "$REPORT"; then
  echo "FAIL: P05 jaccard-validation-report does not document source_unit in the extended vector"
  exit 1
fi
if ! grep -q 'M020/P05' "$REPORT"; then
  echo "FAIL: P05 jaccard-validation-report does not name M020/P05 in its header"
  exit 1
fi

echo "PASS: feature-vector extension (relates_to + source_unit + body cap 200) + P05 report present"
exit 0
