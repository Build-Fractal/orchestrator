#!/usr/bin/env bash
# scripts/intake/paragraph-classify.sh
# M024/P03/T01 — Paragraph-branch axis classifier (resolves #Q-1 paragraph tier mapping).
#
# Input:
#   --input <string>   The paragraph-shaped input.
#
# Output (stdout, four lines):
#   scope_tier=<A|B|C>
#   decomposition=<single-task|single-phase|milestone-with-phases|multi-milestone>
#   recommended_command=<orchestrator:dispatch|orchestrator:specify>
#   rationale_paragraph=<one-line evidence string>
#
# Exit 0 on success, 2 on usage error.

set -u

usage() {
  echo "usage: paragraph-classify.sh --input <string>" >&2
  exit 2
}

INPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

[ -n "$INPUT" ] || usage

# Word count.
words=$(echo "$INPUT" | tr -s '[:space:]' '\n' | grep -c .)

# Structural FR-bullet count.
fr_bullets=$(echo "$INPUT" | grep -cE '^-[[:space:]]+FR-' || true)

# Tier C lexical triggers (case-insensitive, word-boundary).
tier_c_markers=0
if echo "$INPUT" | grep -qiE '\bmilestone\b|\bphases\b|\broadmap\b|\bmulti-phase\b|\bcross-phase\b'; then
  tier_c_markers=1
fi

# Decision table.
if [ "$tier_c_markers" -eq 1 ] || [ "$fr_bullets" -ge 3 ]; then
  echo "scope_tier=C"
  echo "decomposition=milestone-with-phases"
  echo "recommended_command=orchestrator:specify"
  echo "rationale_paragraph=paragraph $words words, $fr_bullets FR-bullets, $tier_c_markers milestone-markers — Tier C milestone-with-phases"
  exit 0
fi

if [ "$words" -ge 31 ] && [ "$words" -le 80 ]; then
  echo "scope_tier=B"
  echo "decomposition=single-phase"
  echo "recommended_command=orchestrator:specify"
  echo "rationale_paragraph=paragraph $words words, $fr_bullets FR-bullets, 0 milestone-markers — Tier B single-phase"
  exit 0
fi

# Tier A default.
echo "scope_tier=A"
echo "decomposition=single-task"
echo "recommended_command=orchestrator:dispatch"
echo "rationale_paragraph=paragraph $words words, $fr_bullets FR-bullets, 0 milestone-markers — Tier A single-task"
exit 0
