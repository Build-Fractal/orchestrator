#!/usr/bin/env bash
# scripts/diagnostics/check-decisions.sh — M034 P01 T04 (FR-4 doctor advisory).
#
# Advisory health check: flags when the count of active, unreviewed,
# warn-severity decision entries across the project reaches the SSOT
# threshold (DECISIONS_WARN_FINDING_THRESHOLD). A recurring unreviewed
# warn-severity backlog is a health signal, not a hard failure — so this
# check is wired advisory (1) in run-doctor.sh and always exits 0.
#
# Walks <root>/milestones/*/ (and phase subdirs) for *-DECISIONS.md packets
# and sums each packet's unreviewed warn-severity entries via
# read-decisions.sh unreviewed-warn-count.
#
# Emits exactly one DOCTOR: line:
#   sum >= threshold : DOCTOR: status=warn check=decisions unreviewed_warn=<N> threshold=<T> — ...
#   else             : DOCTOR: status=ok   check=decisions unreviewed_warn=<N> threshold=<T>
#   no packets found : DOCTOR: status=skip check=decisions — no decision packets found
#
# CON-4: the threshold + the "warn" severity value come from the SSOT
# (decisions-constants.sh); never hard-coded here.
#
# Bash 3.2 compatible. Read-only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../knowledge/lib/decisions-constants.sh
. "$SCRIPT_DIR/../knowledge/lib/decisions-constants.sh"

READER="$SCRIPT_DIR/../knowledge/read-decisions.sh"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --quiet) shift ;;            # accepted for run_check arg-shape parity
    *) shift ;;
  esac
done

# Real packets live under .orchestrator/milestones/. A test root may place the
# milestones/ tree directly; fall back to ROOT when there is no .orchestrator/.
scan="$ROOT/.orchestrator"
if [ ! -d "$scan" ]; then
  scan="$ROOT"
fi

THRESHOLD="$DECISIONS_WARN_FINDING_THRESHOLD"

# Collect every *-DECISIONS.md under milestones/ (and their phase subdirs).
matches="$(find "$scan/milestones" -type f -name '*-DECISIONS.md' 2>/dev/null || true)"

if [ -z "$matches" ]; then
  echo "PASS: no decision packets found."
  echo "DOCTOR: status=skip check=decisions — no decision packets found"
  exit 0
fi

sum=0
_old_ifs="$IFS"
IFS='
'
for f in $matches; do
  [ -n "$f" ] || continue
  n="$(bash "$READER" unreviewed-warn-count "$f" 2>/dev/null || true)"
  case "$n" in
    ''|*[!0-9]*) n=0 ;;
  esac
  sum=$((sum + n))
done
IFS="$_old_ifs"

if [ "$sum" -ge "$THRESHOLD" ]; then
  echo "Resolve unreviewed warn-severity decisions: walk the decision packets and adjudicate each warn entry via the P02 review gate."
  echo "DOCTOR: status=warn check=decisions unreviewed_warn=$sum threshold=$THRESHOLD — recurring unreviewed warn-severity decisions"
else
  echo "PASS: unreviewed warn-severity decisions below threshold ($sum < $THRESHOLD)."
  echo "DOCTOR: status=ok check=decisions unreviewed_warn=$sum threshold=$THRESHOLD"
fi
exit 0
