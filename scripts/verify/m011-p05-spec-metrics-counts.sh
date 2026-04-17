#!/usr/bin/env bash
# scripts/verify/m011-p05-spec-metrics-counts.sh
# Verify spec-metrics.sh counts non-superseded tips by category.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/knowledge/spec/story"
mkdir -p "$FIXTURE/knowledge/spec/requirement"
mkdir -p "$FIXTURE/knowledge/spec/acceptance"
mkdir -p "$FIXTURE/knowledge/spec/constraint"
mkdir -p "$FIXTURE/knowledge/spec/nfr"
mkdir -p "$FIXTURE/knowledge/spec/non-goal"

make_chunk() {
  # make_chunk <path> <category> <superseded_by>
  local path="$1" cat="$2" sby="$3"
  {
    printf -- '---\n'
    printf 'schema_version: "1.0"\n'
    printf 'id: "%s"\n' "$(basename "$path" .md)"
    printf 'category: "%s"\n' "$cat"
    printf 'superseded_by: "%s"\n' "$sby"
    printf 'relates_to: []\n'
    printf 'scope_tags: "[project]"\n'
    printf -- '---\n\n'
    printf 'body stub\n'
  } > "$path"
}

make_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-001.md"       spec/story      ""
make_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-002.md"       spec/story      ""
make_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-003.md"       spec/story      ""
make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-001.md" spec/requirement ""
make_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-002.md" spec/requirement ""
make_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-001.md"  spec/acceptance ""
make_chunk "$FIXTURE/knowledge/spec/constraint/SPEC-CON-001.md" spec/constraint ""
make_chunk "$FIXTURE/knowledge/spec/non-goal/SPEC-NG-001.md"    spec/non-goal   ""

OUT="$(bash "$REPO/scripts/state/spec-metrics.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"

check() {
  local key="$1" expect="$2"
  local got
  got="$(printf '%s\n' "$OUT" | awk -F= -v k="$key" '$1==k {print $2; exit}')"
  if [ "$got" != "$expect" ]; then
    printf 'FAIL: %s expected=%s got=%s\n' "$key" "$expect" "$got"
    exit 1
  fi
}

check spec_chunks_present true
check story_count 3
check requirement_count 2
check acceptance_count 1
check constraint_count 1
check nfr_count 0
check non_goal_count 1

echo "PASS: spec-metrics counts match fixture"
