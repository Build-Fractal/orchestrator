#!/usr/bin/env bash
# scripts/state/spec-metrics.sh — Count ingested spec chunks by category.
#
# Usage: spec-metrics.sh <orch_root>
#   <orch_root> — path to the .orchestrator/ tree (or any path whose
#                 project root contains knowledge/spec/).
#
# Output (stdout, key=value lines):
#   spec_chunks_present=true|false
#   story_count=N
#   requirement_count=N
#   acceptance_count=N
#   constraint_count=N
#   nfr_count=N
#   non_goal_count=N
#
# Counts are non-superseded tips only — chunks whose frontmatter
# `superseded_by:` field is non-empty are excluded.
#
# Exit 0 on success (including the "no chunks present" case).
# Exit 1 on missing argument.
#
# Bash 3.2 compatible (MEM001).

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "spec-metrics.sh: requires <orch_root>" >&2
  exit 1
fi

ORCH_ROOT="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Resolve the knowledge root. Precedence:
# 1. <orch_root>/../knowledge/spec (repo layout where .orchestrator/ is a sibling of knowledge/)
# 2. <project-root>/knowledge/spec (resolved via SCRIPT_DIR parent)
KNOWLEDGE_SPEC=""
if [ -d "${ORCH_ROOT}/../knowledge/spec" ]; then
  KNOWLEDGE_SPEC="$(cd "${ORCH_ROOT}/../knowledge/spec" && pwd)"
elif [ -d "${PROJECT_ROOT}/knowledge/spec" ]; then
  KNOWLEDGE_SPEC="${PROJECT_ROOT}/knowledge/spec"
fi

count_category() {
  # count_category <cat-dir-name> — count *.md files whose frontmatter
  # `superseded_by:` is empty or missing.
  local cat_dir="$1"
  local dir="${KNOWLEDGE_SPEC}/${cat_dir}"
  local n=0
  if [ -z "$KNOWLEDGE_SPEC" ] || [ ! -d "$dir" ]; then
    echo 0
    return 0
  fi
  local f sby
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    # Extract superseded_by value from frontmatter (first match wins)
    sby="$(awk '
      /^---$/ { c++; if (c==2) exit; next }
      c==1 && /^superseded_by:/ {
        sub(/^superseded_by:[[:space:]]*/, "")
        gsub(/"/, "")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        print
        exit
      }
    ' "$f" 2>/dev/null)"
    if [ -z "$sby" ]; then
      n=$((n + 1))
    fi
  done
  echo "$n"
}

STORY="$(count_category story)"
REQUIREMENT="$(count_category requirement)"
ACCEPTANCE="$(count_category acceptance)"
CONSTRAINT="$(count_category constraint)"
NFR="$(count_category nfr)"
NONGOAL="$(count_category non-goal)"

TOTAL=$((STORY + REQUIREMENT + ACCEPTANCE + CONSTRAINT + NFR + NONGOAL))
if [ "$TOTAL" -gt 0 ]; then
  echo "spec_chunks_present=true"
else
  echo "spec_chunks_present=false"
fi

echo "story_count=${STORY}"
echo "requirement_count=${REQUIREMENT}"
echo "acceptance_count=${ACCEPTANCE}"
echo "constraint_count=${CONSTRAINT}"
echo "nfr_count=${NFR}"
echo "non_goal_count=${NONGOAL}"
