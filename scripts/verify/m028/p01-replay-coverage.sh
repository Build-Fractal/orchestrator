#!/usr/bin/env bash
# scripts/verify/m028/p01-replay-coverage.sh -- M028/P01/T01 replay-coverage verifier.
#
# Asserts:
#   1. The classifier-replay audit at
#      .orchestrator/milestones/M028/phases/P01/classifier-audit.md exists.
#   2. It contains at least 7 source-event sections (`## SE-` headings).
#      The M028 spec's Findings A through G yield 7 to 9 source events
#      (this verifier sets the floor at 7 per the T01 task plan).
#   3. It contains the literal substring `AP-009` somewhere in the body —
#      the anchor proving the M021 classifier output (`compound-chain-gt2`,
#      which AP-009 in `ANTIPATTERNS.md` documents) was actually captured.
#
# Exit 0 on PASS. Exit 1 on any FAIL with a one-line stderr diagnostic
# pointing at the offending check.
#
# AD-19 single-script-file shape: flat file, no nested helpers, no compound
# chains in the body. Bash 3.2 + POSIX-sh-safe.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
AUDIT="${REPO_ROOT}/.orchestrator/milestones/M028/phases/P01/classifier-audit.md"

if [ ! -f "$AUDIT" ]; then
  echo "FAIL: classifier-audit.md missing at ${AUDIT}" >&2
  exit 1
fi

if [ ! -r "$AUDIT" ]; then
  echo "FAIL: classifier-audit.md unreadable at ${AUDIT}" >&2
  exit 1
fi

# Count `## SE-` section headings. Use grep -c with a literal pattern;
# the heading shape `## SE-NN: <label>` is fixed per the T01 task plan.
SE_COUNT=$(grep -c '^## SE-' "$AUDIT")

if [ "${SE_COUNT:-0}" -lt 7 ]; then
  echo "FAIL: classifier-audit.md has ${SE_COUNT} source events, expected >= 7" >&2
  exit 1
fi

# Anchor check: the literal string AP-009 must appear (proves the M021
# classifier verdict for `compound-chain-gt2` was captured).
if ! grep -q 'AP-009' "$AUDIT"; then
  echo "FAIL: classifier-audit.md missing literal 'AP-009' anchor" >&2
  exit 1
fi

echo "PASS: classifier-audit.md has ${SE_COUNT} source events, AP-009 anchor present"
exit 0
