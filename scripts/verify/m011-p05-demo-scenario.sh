#!/usr/bin/env bash
# scripts/verify/m011-p05-demo-scenario.sh
# End-to-end P05 demo scenario: a fixture with 3 stories, 8 requirements,
# 5 acceptances, 2 constraints, 1 non-goal, one story->story relates_to
# edge. Assert spec-metrics.sh counts match and spec-story-graph.sh
# emits the expected depends_on edges.
#
# Fixture writes the full spec-chunk frontmatter (matching ingest-spec.sh
# output) plus a leading `# <id>: ...` heading so rebuild-index.sh
# populates knowledge.db + edges under set -euo pipefail. A minimal
# frontmatter does NOT work — rebuild's description-extraction grep
# returns nonzero when no heading matches and pipefail aborts the run.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/knowledge/spec/story"
mkdir -p "$FIXTURE/knowledge/spec/requirement"
mkdir -p "$FIXTURE/knowledge/spec/acceptance"
mkdir -p "$FIXTURE/knowledge/spec/constraint"
mkdir -p "$FIXTURE/knowledge/spec/non-goal"

write_chunk() {
  # write_chunk <path> <category> <relates> <superseded_by>
  local path="$1" cat="$2" rel="$3" sby="$4"
  local id
  id="$(basename "$path" .md)"
  {
    printf -- '---\n'
    printf 'id: %s\n' "$id"
    printf 'scope_tags: "[project]"\n'
    printf 'category: %s\n' "$cat"
    printf 'confidence: 0.80\n'
    printf 'created_at: 2026-04-16\n'
    printf 'last_verified: 2026-04-16\n'
    printf 'hit_count: 0\n'
    printf 'source_unit: "M999/P05"\n'
    printf 'source_type: spec-ingest\n'
    printf 'supersedes: ""\n'
    printf 'superseded_by: "%s"\n' "$sby"
    printf 'relates_to: %s\n' "$rel"
    printf 'content_hash: "sha256:%s"\n' "$(printf '%s' "$id" | tr 'A-Z-' 'a-z0')"
    printf -- '---\n\n'
    printf '# %s: fixture entry\n\nBody stub.\n' "$id"
  } > "$path"
}

# 3 stories; US-003 relates_to US-001
write_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-001.md" spec/story "[]"            ""
write_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-002.md" spec/story "[]"            ""
write_chunk "$FIXTURE/knowledge/spec/story/SPEC-US-003.md" spec/story "[SPEC-US-001]" ""

# 8 requirements (non-superseded tips)
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-001.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-002.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-003.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-004.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-005.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-006.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-007.md" spec/requirement "[]" ""
write_chunk "$FIXTURE/knowledge/spec/requirement/SPEC-FR-008.md" spec/requirement "[]" ""

# 5 acceptances
write_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-001.md" spec/acceptance "[]" ""
write_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-002.md" spec/acceptance "[]" ""
write_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-003.md" spec/acceptance "[]" ""
write_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-004.md" spec/acceptance "[]" ""
write_chunk "$FIXTURE/knowledge/spec/acceptance/SPEC-AC-005.md" spec/acceptance "[]" ""

# 2 constraints
write_chunk "$FIXTURE/knowledge/spec/constraint/SPEC-CON-001.md" spec/constraint "[]" ""
write_chunk "$FIXTURE/knowledge/spec/constraint/SPEC-CON-002.md" spec/constraint "[]" ""

# 1 non-goal
write_chunk "$FIXTURE/knowledge/spec/non-goal/SPEC-NG-001.md" spec/non-goal "[]" ""

# Rebuild the knowledge index (populates knowledge.db + KNOWLEDGE-INDEX.md).
# Fail loudly if rebuild fails — the fixture is meant to be index-valid.
if ! PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/knowledge/rebuild-index.sh" > "$FIXTURE/rebuild.log" 2>&1; then
  echo "FAIL: rebuild-index.sh failed"
  cat "$FIXTURE/rebuild.log"
  exit 1
fi

# --- Assertion block A: spec-metrics.sh counts ---
OUT_METRICS="$(bash "$REPO/scripts/state/spec-metrics.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"

check_metric() {
  local key="$1" expect="$2"
  local got
  got="$(printf '%s\n' "$OUT_METRICS" | awk -F= -v k="$key" '$1==k {print $2; exit}')"
  if [ "$got" != "$expect" ]; then
    printf 'FAIL[metrics]: %s expected=%s got=%s\n' "$key" "$expect" "$got"
    printf 'Full metrics output:\n%s\n' "$OUT_METRICS"
    exit 1
  fi
}

check_metric spec_chunks_present true
check_metric story_count 3
check_metric requirement_count 8
check_metric acceptance_count 5
check_metric constraint_count 2
check_metric nfr_count 0
check_metric non_goal_count 1

# --- Assertion block B: spec-story-graph.sh edges ---
OUT_GRAPH="$(bash "$REPO/scripts/knowledge/spec-story-graph.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"

check_graph_line() {
  local expect="$1"
  if ! printf '%s\n' "$OUT_GRAPH" | grep -Fxq "$expect"; then
    printf 'FAIL[graph]: missing line: %s\n' "$expect"
    printf 'Actual output:\n%s\n' "$OUT_GRAPH"
    exit 1
  fi
}

check_graph_line "SPEC-US-001|"
check_graph_line "SPEC-US-002|"
check_graph_line "SPEC-US-003|SPEC-US-001"

echo "PASS: P05 demo scenario — metrics and story-graph match expectations"
