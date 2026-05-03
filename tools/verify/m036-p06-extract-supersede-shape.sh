#!/usr/bin/env bash
# tools/verify/m036-p06-extract-supersede-shape.sh -- M036 P06 T01.
# Token-presence verifier on scripts/knowledge/extract-reference.sh
# asserting the supersede branch tokens are present. AD-19 single-
# script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/scripts/knowledge/extract-reference.sh"
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
  echo "SUMMARY: m036-p06-extract-supersede-shape.sh pass=0 fail=1"
  exit 1
fi
chk "sources-helper-lib"            "lib/extract-supersede.sh"
chk "calls-find-chain-tip"          "supersede_find_chain_tip"
chk "calls-next-version"            "supersede_next_version"
chk "calls-amend-prior-chunk"       "supersede_amend_prior_chunk"
chk "emits-SUPERSEDED-prefix"       "SUPERSEDED:"
chk "stamps-supersedes-frontmatter" "supersedes:"
chk "stamps-version-on-supersede"   "printf 'version: %s\\n'"
chk "writes-versioned-successor"    'REF-${category}-${cite_id}-v'
chk "preserves-skipped-fast-path"   "SKIPPED: \$cite_id reason=unchanged"
chk "M036-P06-attribution-comment"  "M036/P06"
echo "SUMMARY: m036-p06-extract-supersede-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
