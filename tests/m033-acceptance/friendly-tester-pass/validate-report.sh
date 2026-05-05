#!/usr/bin/env bash
# tests/m033-acceptance/friendly-tester-pass/validate-report.sh
#
# M033 SC-15 mechanical gate. Reads a filled friendly-tester report and
# exits 0 iff:
#   - friction_blockers: 0   (in frontmatter)
#   - eligible_testers >= 1  (counted from `not_familiar_with_orchestrator: yes`
#                             attestation lines in frontmatter list)
#
# This script does NOT enforce the M033_SKIP_FRIENDLY_TESTER_PASS=1
# escalation override. That is validate-milestone.sh's responsibility,
# fired at milestone close. This script is purely the per-report shape
# verifier.
#
# Bash 3.2 compatible. Parsing uses awk/grep/sed only -- no jq, no python.
# References: M033 spec FR-19 / US-8 AS-5 / SC-15. MEM001 (bash 3.2).

set -e -u -o pipefail

REPORT="${1:-}"

if [ -z "$REPORT" ]; then
  echo "usage: validate-report.sh <report.md>" >&2
  exit 2
fi

if [ ! -f "$REPORT" ]; then
  echo "friendly-tester pass not run — milestone close blocked" >&2
  echo "  expected report at: $REPORT" >&2
  exit 1
fi

# Extract frontmatter scalars via awk (no jq).
# `exit` after first match guards against duplicate keys in the body.
blockers=$(awk '/^friction_blockers: /{print $2; exit}' "$REPORT" | tr -d ' "')
eligible=$(awk '/^eligible_testers: /{print $2; exit}' "$REPORT" | tr -d ' "')
warnings=$(awk '/^friction_warnings: /{print $2; exit}' "$REPORT" | tr -d ' "')

# Defensive defaults if a field is missing entirely.
blockers="${blockers:-0}"
eligible="${eligible:-0}"
warnings="${warnings:-0}"

# Count eligible attestations: lines matching not_familiar_with_orchestrator: yes
# (with or without surrounding quotes), but ONLY inside the YAML frontmatter
# block (between the first two `---` lines). This avoids double-counting
# matches inside body comments or markdown prose.
eligible_attest=$(awk '
  BEGIN { in_fm=0; seen=0; n=0 }
  /^---[[:space:]]*$/ {
    if (seen==0) { in_fm=1; seen=1; next }
    else if (in_fm==1) { in_fm=0; exit }
  }
  in_fm==1 && /not_familiar_with_orchestrator: "?yes"?/ { n++ }
  END { print n+0 }
' "$REPORT")

# The mechanical eligible count is derived from attestations, not the
# scalar field. The scalar `eligible_testers:` is captured for human
# readability but the validator trusts the attestation list. This
# guards against a maintainer typo'ing the scalar past zero without
# any attestation lines actually being present.
actual_eligible="$eligible_attest"

fail=0

if [ "$blockers" -gt 0 ]; then
  echo "FAIL: friction_blockers=$blockers (must be 0 for SC-15)" >&2
  # Echo blocker descriptions from body. Each "### Friction (Blockers)"
  # subsection collects "- " bullets until the next "###" or "## " header.
  awk '/^### Friction \(Blockers\)/{flag=1; next} /^###|^## /{flag=0} flag && /^- /{print "  blocker: " $0}' "$REPORT" >&2
  fail=1
fi

if [ "$actual_eligible" -lt 1 ]; then
  echo "FAIL: no eligible testers -- recruit >=1 outsider per SC-15" >&2
  echo "  count of not_familiar_with_orchestrator: yes lines = $actual_eligible" >&2
  fail=1
fi

if [ "$fail" -eq 1 ]; then
  exit 1
fi

echo "PASS: friction_blockers=0 eligible_testers=$actual_eligible warnings=$warnings"
exit 0
