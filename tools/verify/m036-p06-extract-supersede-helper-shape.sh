#!/usr/bin/env bash
# tools/verify/m036-p06-extract-supersede-helper-shape.sh -- M036 P06 T01.
# Token-presence verifier on scripts/knowledge/lib/extract-supersede.sh.
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/scripts/knowledge/lib/extract-supersede.sh"
pass=0
fail=0
chk() {
  local label="$1" pat="$2"
  if grep -qF -e "$pat" "$F"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (missing: $pat)"
    fail=$((fail + 1))
  fi
}
if [ ! -f "$F" ]; then
  echo "FAIL: $F not found"
  echo "SUMMARY: m036-p06-extract-supersede-helper-shape.sh pass=0 fail=1"
  exit 1
fi
chk "find-chain-tip-defined"       "supersede_find_chain_tip()"
chk "next-version-defined"         "supersede_next_version()"
chk "amend-prior-chunk-defined"    "supersede_amend_prior_chunk()"
chk "MEM004-attribution-comment"   "MEM004"
chk "set-eu-strict"                "set -eu"
chk "no-top-level-exec-marker"     "Pure-lib MEM004 helper"
echo "SUMMARY: m036-p06-extract-supersede-helper-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
