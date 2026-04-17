#!/usr/bin/env bash
# scripts/knowledge/spec-story-graph.sh — Emit story-to-story depends_on edges.
#
# Usage: spec-story-graph.sh <orch_root>
#   <orch_root> — path to the .orchestrator/ tree (used to locate the
#                 sibling knowledge/ directory).
#
# Output (stdout): one line per non-superseded `spec/story` chunk:
#   <SPEC-STORY-ID>|<comma-sep list of SPEC-STORY-IDs this story depends on>
# The right-hand side is empty ("") for stories with no story-to-story edges.
#
# "Depends on" means: there is a `relates_to` edge from this story to
# another story chunk. The directionality is taken as-is — relates_to
# is treated as a dependency edge for the roadmap's purposes.
#
# Exit 0 on success (including empty output when no stories exist).
# Exit 1 on missing argument.
#
# Bash 3.2 compatible (MEM001). Delegates edge traversal to
# scripts/knowledge/traverse-graph.sh rather than reimplementing SQL.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "spec-story-graph.sh: requires <orch_root>" >&2
  exit 1
fi

ORCH_ROOT="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Resolve the knowledge project root: orch_root's parent if it holds a
# knowledge/spec tree, else the repo root. This becomes PROJECT_ROOT for
# the delegated traverse-graph.sh subprocess so it finds the matching
# knowledge.db regardless of the caller's working directory.
KNOWLEDGE_PROJECT_ROOT=""
KNOWLEDGE_SPEC=""
if [ -d "${ORCH_ROOT}/../knowledge/spec" ]; then
  KNOWLEDGE_PROJECT_ROOT="$(cd "${ORCH_ROOT}/.." && pwd)"
  KNOWLEDGE_SPEC="${KNOWLEDGE_PROJECT_ROOT}/knowledge/spec"
elif [ -d "${REPO_ROOT}/knowledge/spec" ]; then
  KNOWLEDGE_PROJECT_ROOT="$REPO_ROOT"
  KNOWLEDGE_SPEC="${REPO_ROOT}/knowledge/spec"
fi

if [ -z "$KNOWLEDGE_SPEC" ]; then
  exit 0
fi

STORY_DIR="${KNOWLEDGE_SPEC}/story"
if [ ! -d "$STORY_DIR" ]; then
  exit 0
fi

TRAVERSE="${REPO_ROOT}/scripts/knowledge/traverse-graph.sh"

# Read superseded_by frontmatter field from a spec chunk file.
# Returns the unquoted value (may be empty).
read_superseded_by() {
  # read_superseded_by <file>
  local file="$1"
  awk '
    /^---$/ { c++; if (c==2) exit; next }
    c==1 && /^superseded_by:/ {
      sub(/^superseded_by:[[:space:]]*/, "")
      gsub(/"/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print; exit
    }
  ' "$file" 2>/dev/null
}

# Read the relates_to frontmatter field from a spec chunk file and
# emit one ID per line on stdout. Handles inline YAML array form
# `[A, B, C]` (the form ingest-spec.sh writes for spec chunks).
read_relates_to_ids() {
  # read_relates_to_ids <file>
  local file="$1"
  awk '
    /^---$/ { c++; if (c==2) exit; next }
    c==1 && /^relates_to:/ {
      sub(/^relates_to:[[:space:]]*/, "")
      gsub(/[\[\]"]/, "")
      n = split($0, parts, ",")
      for (i = 1; i <= n; i++) {
        t = parts[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
        if (t != "") print t
      }
      exit
    }
  ' "$file" 2>/dev/null
}

emit_story_deps() {
  # emit_story_deps <story-file>
  local file="$1"
  local id sby
  id="$(basename "$file" .md)"

  # Skip superseded tips
  sby="$(read_superseded_by "$file")"
  if [ -n "$sby" ]; then
    return 0
  fi

  # Enumerate 1-hop relates_to neighbors via traverse-graph.sh; filter
  # to story-category neighbors whose edges are explicitly declared
  # OUTBOUND from this story (traverse-graph is bidirectional on
  # relates_to; the roadmap only wants `this depends on that` edges,
  # which means the current story's frontmatter names the neighbor).
  local neighbors_file outbound_file
  neighbors_file="$(mktemp)"
  outbound_file="$(mktemp)"
  PROJECT_ROOT="$KNOWLEDGE_PROJECT_ROOT" bash "$TRAVERSE" --id "$id" --hops 1 > "$neighbors_file" 2>/dev/null || true
  read_relates_to_ids "$file" > "$outbound_file"

  local deps=""
  local n
  local nsby
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    [ "$n" = "$id" ] && continue
    # Keep only neighbors that exist under knowledge/spec/story/
    [ -f "${STORY_DIR}/${n}.md" ] || continue
    # Require the edge to be declared on THIS story (directional).
    if ! grep -Fxq "$n" "$outbound_file"; then
      continue
    fi
    # Skip neighbor if it is itself superseded
    nsby="$(read_superseded_by "${STORY_DIR}/${n}.md")"
    if [ -n "$nsby" ]; then
      continue
    fi
    if [ -z "$deps" ]; then
      deps="$n"
    else
      deps="${deps},${n}"
    fi
  done < "$neighbors_file"
  rm -f "$neighbors_file" "$outbound_file"

  printf '%s|%s\n' "$id" "$deps"
}

# Iterate story chunks in sorted order for deterministic output
for f in "$STORY_DIR"/SPEC-US-*.md; do
  [ -e "$f" ] || continue
  emit_story_deps "$f"
done
