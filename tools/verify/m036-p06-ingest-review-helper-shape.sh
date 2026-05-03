#!/usr/bin/env bash
# tools/verify/m036-p06-ingest-review-helper-shape.sh -- M036 P06 T02.
# Token-presence verifier on scripts/knowledge/lib/ingest-review-advisory.sh
# asserting the two pure-lib functions defined plus the typed-edge
# traverser invocation pattern. AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/scripts/knowledge/lib/ingest-review-advisory.sh"
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
  echo "SUMMARY: m036-p06-ingest-review-helper-shape.sh pass=0 fail=1"
  exit 1
fi
chk "superseded-emitter-defined"    "review_emit_for_superseded_chunks()"
chk "removed-emitter-defined"       "review_emit_for_removed_chunks()"
chk "invokes-traverse-graph"        "traverse-graph.sh"
chk "uses-edge-types-cites"         "--edge-types cites"
chk "uses-reverse-direction"        "--reverse"
chk "MEM004-attribution"            "MEM004"
chk "no-top-level-exec-marker"      "Pure-lib MEM004 helper"
echo "SUMMARY: m036-p06-ingest-review-helper-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
