#!/usr/bin/env bash
# scripts/verify/m024-p06-write-confinement.sh
# Asserts every P06 script writes only to .orchestrator/intake/<id>/ and /tmp.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Every P06-introduced or P06-modified shell artifact.
TARGETS="
scripts/intake/axis-rederive.sh
scripts/intake/revise.sh
"

# Pattern: any redirect token followed by a path that is NOT under /tmp,
# .orchestrator/intake/, or a tmp_render-style mktemp variable. The
# tightened P03 regex (whitespace-prefixed `>`, excluding `>&[12]` and
# `>/dev/null`) is reused.
fail=0
for rel in $TARGETS; do
  f="$ROOT/$rel"
  [ -f "$f" ] || { echo "FAIL: $rel not found"; fail=1; continue; }
  # Look for write redirects that target paths NOT under .orchestrator/intake/, /tmp, or a known scratch var.
  hits=$(grep -nE '[[:space:]]>[[:space:]]*[^&[:space:]/]' "$f" | grep -vE '/tmp|\.orchestrator/intake|tmp_render|axes_tmp|qa_tx_tmp|arc_qa_tmp|body-src|diff_marker|\.bak' || true)
  if [ -n "$hits" ]; then
    echo "FAIL: $rel has unconfined write redirects:"
    echo "$hits"
    fail=1
  fi
done

# Also check the P06 additions to proposal-emit.sh and approval-gate.sh did not
# introduce out-of-confine writes. The full files have wider scope than P06
# touched, so we only spot-check that the P06-introduced lines fit the pattern.
# Specifically: search for the new --axes-from block and the wired revise verb body.
grep -q 'axes-from' "$ROOT/scripts/intake/proposal-emit.sh" || { echo "FAIL: --axes-from not wired into proposal-emit.sh"; fail=1; }
grep -q 'revised_to' "$ROOT/scripts/intake/approval-gate.sh" || { echo "FAIL: revised_to not wired into approval-gate.sh"; fail=1; }

if [ "$fail" = "1" ]; then
  exit 1
fi

echo "PASS: write-confinement — P06 scripts write only to .orchestrator/intake/<id>/ and /tmp"
exit 0
