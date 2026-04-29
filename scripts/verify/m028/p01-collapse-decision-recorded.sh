#!/usr/bin/env bash
# scripts/verify/m028/p01-collapse-decision-recorded.sh
# M028/P01/T03 -- Collapse-decision evidence shape verifier.
#
# Asserts the shape (not the values) of
# .orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md:
#
#   1. File exists and is readable.
#   2. Frontmatter contains a `collapse_decision:` field whose value is
#      exactly `full-5-phase` or `collapse-to-2-PRs` (no other values).
#   3. Body contains a `## Per-Screenshot Causal Trace` heading.
#   4. Body contains a `## Collapse Decision` heading.
#   5. Body contains a `## Corpus Staging List` heading (substring match
#      tolerates the parenthetical "(consumed by P03)" suffix).
#   6. Within the Per-Screenshot Causal Trace section every line that
#      contains the literal token `**Resolved-by-Finding-A-alone**:` ends
#      (on the same line) with either `YES` or `NO`.
#
# Exit 0 on PASS with a single-line PASS message. Exit 1 on FAIL with a
# one-line stderr diagnostic naming the failing check.
#
# AD-19 single-script-file shape: flat file, no nested helpers, no compound
# chains > 2 connectors in the body. bash 3.2 + POSIX-sh-safe.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOC="${REPO_ROOT}/.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md"

# --- Check 1: file present & readable -----------------------------------

if [ ! -f "$DOC" ]; then
  echo "FAIL: P01-VERIFICATION.md missing at ${DOC}" >&2
  exit 1
fi

if [ ! -r "$DOC" ]; then
  echo "FAIL: P01-VERIFICATION.md unreadable at ${DOC}" >&2
  exit 1
fi

# --- Check 2: collapse_decision frontmatter field -----------------------
#
# We extract the first frontmatter line matching `^collapse_decision:` and
# strip the value. The rule per the task plan: value is exactly
# `full-5-phase` or `collapse-to-2-PRs`, optionally double-quoted.

DECISION_LINE=$(grep -m 1 '^collapse_decision:' "$DOC" || true)

if [ -z "$DECISION_LINE" ]; then
  echo "FAIL: frontmatter field 'collapse_decision:' missing" >&2
  exit 1
fi

# Strip leading `collapse_decision:` and surrounding whitespace + quotes.
DECISION_VALUE=$(printf '%s\n' "$DECISION_LINE" | sed -e 's/^collapse_decision:[[:space:]]*//' -e 's/^"//' -e 's/"$//' -e 's/[[:space:]]*$//')

if [ "$DECISION_VALUE" != "full-5-phase" ] && [ "$DECISION_VALUE" != "collapse-to-2-PRs" ]; then
  echo "FAIL: collapse_decision value '${DECISION_VALUE}' not in {full-5-phase, collapse-to-2-PRs}" >&2
  exit 1
fi

# --- Check 3: Per-Screenshot Causal Trace heading -----------------------

if ! grep -q '^## Per-Screenshot Causal Trace' "$DOC"; then
  echo "FAIL: missing '## Per-Screenshot Causal Trace' section heading" >&2
  exit 1
fi

# --- Check 4: Collapse Decision heading ---------------------------------

if ! grep -q '^## Collapse Decision' "$DOC"; then
  echo "FAIL: missing '## Collapse Decision' section heading" >&2
  exit 1
fi

# --- Check 5: Corpus Staging List heading -------------------------------

if ! grep -q '^## Corpus Staging List' "$DOC"; then
  echo "FAIL: missing '## Corpus Staging List' section heading" >&2
  exit 1
fi

# --- Check 6: every Resolved-by-Finding-A-alone line ends with YES or NO

# Collect all lines containing the literal token. `grep` returns non-zero
# (exit 1) when no matches; that itself is a failure here -- the document
# must contain at least one such line because the Per-Screenshot Causal
# Trace section authors one per source event.

RESOLVED_LINES=$(grep -n '\*\*Resolved-by-Finding-A-alone\*\*:' "$DOC" || true)

if [ -z "$RESOLVED_LINES" ]; then
  echo "FAIL: no '**Resolved-by-Finding-A-alone**:' lines found" >&2
  exit 1
fi

# For each line, check that the trailing token (after the colon) is YES
# or NO. Allow optional parenthetical commentary -- the rule per the task
# plan is "followed (on the same line) by either YES or NO". We treat any
# line containing the token AND containing either YES or NO after the
# token as conformant.

BAD_LINE=""

while IFS= read -r LINE; do
  TAIL=$(printf '%s\n' "$LINE" | sed -e 's/^.*\*\*Resolved-by-Finding-A-alone\*\*://')
  case "$TAIL" in
    *YES*) : ;;
    *NO*)  : ;;
    *)
      BAD_LINE="$LINE"
      break
      ;;
  esac
done <<EOF
$RESOLVED_LINES
EOF

if [ -n "$BAD_LINE" ]; then
  echo "FAIL: Resolved-by-Finding-A-alone line lacks YES/NO token: ${BAD_LINE}" >&2
  exit 1
fi

# --- All checks passed --------------------------------------------------

echo "PASS: P01-VERIFICATION.md collapse-decision shape-valid"
exit 0
