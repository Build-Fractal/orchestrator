#!/usr/bin/env bash
# m020-p01-migration-incremental.sh -- assert P01 did NOT bulk-migrate the
# live knowledge tree. Per FR-10 + NG-3, pre-M020 entries gain a `status:`
# field only on next touch; the M020/P01 phase MUST NOT walk the tree and
# write `status:` to every entry.
#
# Mechanism: count live `knowledge/*/MEM*.md` entries that already bear a
# `^status:` frontmatter field. The migration is incremental when this
# count stays small relative to the total. We allow up to 5% of entries
# to legitimately bear `status:` -- a generous upper bound that admits
# the operator-invoked graduate.sh demo flips that may have run during
# the phase, while still failing loudly if a bulk migration has occurred.
#
# Bash 3.2 safe. AD-19 single-script-invocation shape.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KNOW="$ROOT/knowledge"

if [ ! -d "$KNOW" ]; then
  echo "FAIL: knowledge directory missing at $KNOW"
  exit 1
fi

# Total entry count (archive excluded -- archived entries can carry status: archived
# legitimately and would skew the count).
total="$(find "$KNOW" -type f -name 'MEM*.md' -not -path '*/archive/*' | wc -l | tr -d ' ')"

if [ "$total" = "0" ]; then
  echo "FAIL: no MEM*.md entries found under $KNOW (cannot evaluate migration contract)"
  exit 1
fi

# Count entries with a `^status:` line. grep -l listfiles; only consider
# the same archive-excluded set as the total.
with_status=0
for f in "$KNOW"/*/MEM*.md; do
  case "$f" in
    *"/archive/"*) continue ;;
  esac
  [ -f "$f" ] || continue
  if grep -q '^status:' "$f"; then
    with_status=$((with_status+1))
  fi
done

# Threshold: 5% of total, rounded up via +1, with a hard floor of 2 to
# tolerate a small-tree case where 5% rounds below 1 useful unit.
limit="$(awk -v t="$total" 'BEGIN{ x=int((t*5)/100)+1; if (x<2) x=2; printf "%d\n", x }')"

if [ "$with_status" -gt "$limit" ]; then
  echo "FAIL: $with_status of $total live entries bear status: (limit $limit). M020/P01 overstepped FR-10 (incremental on-touch migration only)."
  exit 1
fi

# Cross-check: scan the milestone execution log for any record that
# reports more than 1 unit_close per task touching `knowledge/`. The log
# does not track per-file mutations, so this is a soft consistency check
# that we have a recognizable P01 task series, not a runaway loop.
log="$ROOT/.orchestrator/milestones/M020/execution-log.jsonl"
if [ -f "$log" ]; then
  task_close_count="$(grep -c '"record_type":"unit_close"' "$log" || true)"
  # P01 has 5 tasks; 4 closes (T01..T04) before T05 starts is normal,
  # 5 after T05's own close is normal. >7 would be alarming.
  if [ "$task_close_count" -gt 7 ]; then
    echo "FAIL: milestone log reports $task_close_count task closes (expected <=7 for P01); investigate runaway loop"
    exit 1
  fi
fi

echo "PASS: migration is incremental -- $with_status of $total entries bear status: (within $limit limit)"
exit 0
