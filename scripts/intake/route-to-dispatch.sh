#!/usr/bin/env bash
# scripts/intake/route-to-dispatch.sh
# M024/P03/T03 — Route an approved (or auto-proceeded) proposal to orchestrator:dispatch.
#
# Input:
#   --proposal <path>   Proposal whose recommended_command=orchestrator:dispatch.
#
# Output (stdout):
#   invoke=orchestrator:dispatch --proposal <proposal_path>
#   auto_proceed=1   (only when proposal frontmatter has auto_proceeded: true)
#
# Side effect (only when auto_proceeded=true):
#   Mutates proposal frontmatter to set proceeded_at: <ISO8601>.
#
# Exit 0 on success; 1 on wrong recommended_command; 2 on usage error.

set -u

usage() {
  echo "usage: route-to-dispatch.sh --proposal <path>" >&2
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

rec_cmd=$(sed -n 's/^recommended_command: "\(.*\)"$/\1/p' "$PROPOSAL" | head -1)
if [ "$rec_cmd" != "orchestrator:dispatch" ]; then
  echo "ERR: route-to-dispatch invoked on proposal with recommended_command='$rec_cmd' (expected orchestrator:dispatch)" >&2
  exit 1
fi

auto_proceeded=$(sed -n 's/^auto_proceeded: \(.*\)$/\1/p' "$PROPOSAL" | head -1)

if [ "$auto_proceeded" = "true" ]; then
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  esc=$(printf '%s' "proceeded_at: \"$ts\"" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/^proceeded_at: .*\$/${esc}/" "$PROPOSAL"
  rm -f "${PROPOSAL}.bak"
  echo "auto_proceed=1"
fi

echo "invoke=orchestrator:dispatch --proposal $PROPOSAL"
exit 0
