#!/usr/bin/env bash
# scripts/util/cleanup-stale-results.sh -- Remove per-step result files under a milestone tree.
#
# Usage: cleanup-stale-results.sh <milestone-id>
#   <milestone-id> -- format M[0-9]+ (e.g. M028).
#
# Removes every *.txt file under .orchestrator/milestones/<MID>/phases/<PID>/tasks/
# (per-step task-result scratch files) and prints a structured summary.
#
# Output:
#   REMOVED: <N>          (count of files removed)
#   RESIDUAL: <count>     (count of *.txt files still present under the milestone tree)
#   OK                    (success terminator)
#
# Refuses milestone IDs that do not match M[0-9]+ to bound blast radius.
# Refuses if the milestone tree does not exist.
#
# Exit:
#   0 -- success.
#   1 -- milestone tree missing.
#   2 -- usage / validation error (bad milestone ID).
#
# Replaces the Screenshot 2 / Finding D shape `/bin/rm -f .../*.txt && ls .../*.txt` (M028 FR-15).
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

if [ $# -ne 1 ]; then
  echo "usage: cleanup-stale-results.sh <milestone-id>" >&2
  exit 2
fi

mid="$1"

# Validate milestone ID format -- closed shape avoids path traversal and globbing.
case "$mid" in
  M[0-9]*) : ;;
  *)
    echo "cleanup-stale-results.sh: invalid milestone ID '$mid' (expected M[0-9]+)" >&2
    exit 2
    ;;
esac

# Resolve repo root.
script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../.." && pwd -P)"
TREE="${REPO_ROOT}/.orchestrator/milestones/${mid}"

if [ ! -d "$TREE" ]; then
  echo "cleanup-stale-results.sh: milestone tree not found: $TREE" >&2
  exit 1
fi

# Enumerate target files via find (no -exec into sh -c; AP-014 safe).
list_tmp="$(mktemp)"
find "$TREE" -type f -path '*/phases/*/tasks/*.txt' -print > "$list_tmp"

removed=0
while IFS= read -r f; do
  if [ -f "$f" ]; then
    rm -f -- "$f"
    removed=$((removed + 1))
  fi
done < "$list_tmp"
rm -f "$list_tmp"

# Residual count -- separate find pass after removal.
residual_tmp="$(mktemp)"
find "$TREE" -type f -path '*/phases/*/tasks/*.txt' -print > "$residual_tmp"
residual=$(wc -l < "$residual_tmp" | tr -d ' ')
rm -f "$residual_tmp"

printf 'REMOVED: %s\n' "$removed"
printf 'RESIDUAL: %s\n' "$residual"
echo "OK"
exit 0
