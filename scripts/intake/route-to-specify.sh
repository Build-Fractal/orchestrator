#!/usr/bin/env bash
# scripts/intake/route-to-specify.sh
# M024/P03/T03 — Route an approved proposal to orchestrator:specify (M024 → M014 handshake).
#
# Input:
#   --proposal <path>   Approved proposal whose recommended_command=orchestrator:specify.
#
# Output (stdout):
#   invoke=orchestrator:specify --input-from <proposal_path>
#
# Exit 0 on success; 1 on probe failure or wrong recommended_command; 2 on usage error.

set -u

usage() {
  echo "usage: route-to-specify.sh --proposal <path>" >&2
  exit 2
}

PROPOSAL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --proposal) PROPOSAL="$2"; shift 2 ;;
    -h|--help)  usage ;;
    *)          usage ;;
  esac
done

[ -n "$PROPOSAL" ] || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# M014/extended shipping probe (#DQ-2 option b — invoke-time fail-fast).
if [ ! -f "$ROOT/scripts/specify/specify.sh" ]; then
  echo "STUB: M014/extended not shipped — author commands/specify.md three-pass contract per D019 before invoking this route." >&2
  exit 1
fi
if ! grep -q 'Pass.1' "$ROOT/commands/specify.md" 2>/dev/null; then
  echo "STUB: M014/extended not shipped — commands/specify.md missing three-pass contract." >&2
  exit 1
fi

# Read recommended_command from frontmatter.
rec_cmd=$(sed -n 's/^recommended_command: "\(.*\)"$/\1/p' "$PROPOSAL" | head -1)
if [ "$rec_cmd" != "orchestrator:specify" ]; then
  echo "ERR: route-to-specify invoked on proposal with recommended_command='$rec_cmd' (expected orchestrator:specify)" >&2
  exit 1
fi

echo "invoke=orchestrator:specify --input-from $PROPOSAL"
exit 0
