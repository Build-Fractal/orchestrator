#!/usr/bin/env bash
# tools/verify/m036-p06-ingest-review-shape.sh -- M036 P06 T02.
# Token-presence verifier on scripts/knowledge/ingest-reference.sh
# asserting the REVIEW: emission pass is wired. AD-19 single-script-
# file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/scripts/knowledge/ingest-reference.sh"
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
  echo "SUMMARY: m036-p06-ingest-review-shape.sh pass=0 fail=1"
  exit 1
fi
chk "sources-helper-lib"            "lib/ingest-review-advisory.sh"
chk "calls-superseded-emitter"      "review_emit_for_superseded_chunks"
chk "calls-removed-emitter"         "review_emit_for_removed_chunks"
chk "parses-detect-removals-flag"   "--detect-removals"
chk "parses-prior-manifest-flag"    "--prior-manifest"
chk "M036-P06-attribution-comment"  "M036/P06"
echo "SUMMARY: m036-p06-ingest-review-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
