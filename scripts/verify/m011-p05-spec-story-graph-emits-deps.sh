#!/usr/bin/env bash
# scripts/verify/m011-p05-spec-story-graph-emits-deps.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.orchestrator"
for sub in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$FIXTURE/knowledge/spec/$sub"
done

write_story() {
  # write_story <id> <relates-yaml> <superseded_by>
  local id="$1" rel="$2" sby="$3"
  {
    printf -- '---\n'
    printf 'id: %s\n' "$id"
    printf 'scope_tags: "[milestone:M999]"\n'
    printf 'category: spec/story\n'
    printf 'confidence: 0.80\n'
    printf 'created_at: 2026-04-16\n'
    printf 'last_verified: 2026-04-16\n'
    printf 'hit_count: 0\n'
    printf 'source_unit: "M999/P01"\n'
    printf 'source_type: spec-ingest\n'
    printf 'supersedes: ""\n'
    printf 'superseded_by: "%s"\n' "$sby"
    printf 'relates_to: %s\n' "$rel"
    printf 'content_hash: "sha256:abc"\n'
    printf -- '---\n\n# %s: story\n\nbody\n' "$id"
  } > "$FIXTURE/knowledge/spec/story/${id}.md"
}

write_story SPEC-US-001 "[]"            ""
write_story SPEC-US-002 "[]"            ""
write_story SPEC-US-003 "[SPEC-US-001]" ""

# Rebuild the knowledge DB so traverse-graph.sh can find edges
PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/knowledge/rebuild-index.sh" > "$FIXTURE/rebuild.log" 2>&1 || {
  echo "FAIL: rebuild-index.sh failed"
  cat "$FIXTURE/rebuild.log"
  exit 1
}

OUT="$(PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/knowledge/spec-story-graph.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"

# Expected lines (order may vary)
check_line() {
  local expect="$1"
  if ! printf '%s\n' "$OUT" | grep -Fxq "$expect"; then
    printf 'FAIL: missing expected line: %s\n' "$expect"
    printf 'Actual output:\n%s\n' "$OUT"
    exit 1
  fi
}

check_line "SPEC-US-001|"
check_line "SPEC-US-002|"
check_line "SPEC-US-003|SPEC-US-001"

echo "PASS: spec-story-graph emits expected depends_on edges"
