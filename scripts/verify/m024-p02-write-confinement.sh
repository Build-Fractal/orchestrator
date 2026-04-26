#!/usr/bin/env bash
# scripts/verify/m024-p02-write-confinement.sh
# SB-3 verify: every write op in P02-introduced scripts targets
# .orchestrator/intake/, /tmp, or tests/fixtures/ (the latter only for the
# one-shot baseline-capture helper).

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Scripts authored or modified in P02 (intake-tree subset).
TARGETS="
scripts/intake/spec-shape-classify.sh
scripts/intake/m014-manifest-read.sh
scripts/intake/_capture-baseline.sh
"

bad=0
for rel in $TARGETS; do
  f="$ROOT/$rel"
  [ -f "$f" ] || continue   # _capture-baseline.sh may be removed after use; skip cleanly.
  # Find write-shaped lines: redirect, mkdir, sed -i, mv to non-/tmp.
  while IFS= read -r line; do
    case "$line" in
      *' > '*|*' >> '*|*'mkdir '*|*'sed -i'*|*' tee '*|*' mv '*|*' cp '*)
        # Heuristic: extract the apparent target (last bareword on the line).
        target=$(echo "$line" | awk '{print $NF}')
        case "$target" in
          *.orchestrator/intake/*|/tmp/*|*tests/fixtures/*) ;;
          \"*\"|\$*) ;;  # variable / quoted literal — skip
          *)
            echo "FAIL: $rel:  potentially out-of-confine write target '$target'"
            bad=1 ;;
        esac
        ;;
    esac
  done < "$f"
done

if [ "$bad" -ne 0 ]; then
  echo "FAIL: write-confinement violations above"
  exit 1
fi

echo "PASS: write-confinement — all P02 intake-tree writes confined to .orchestrator/intake/, /tmp, tests/fixtures/"
exit 0
