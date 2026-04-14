#!/usr/bin/env bash
# scripts/diagnostics/check-graph-health.sh — Graph health diagnostic
# Usage: check-graph-health.sh [--root <project-root>]
#
# Checks knowledge.db graph health across five dimensions:
#   1. Graph statistics (entries, edges, scope_tags, avg degree)
#   2. Orphaned entries (no edges at all)
#   3. Connected components (iterative shell loop + recursive CTE)
#   4. Broken supersession chains (supersedes/superseded_by -> missing entry)
#   5. Dangling edges (edge references non-existent entry)
#
# Outputs human-readable block + DOCTOR:GRAPH_HEALTH machine-readable line.
# Exits 0 in all cases (diagnostics should not fail the runner).
#
# Bash 3.2 compatible (no associative arrays, no mapfile).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "check-graph-health.sh: unknown option: $1" >&2; exit 0 ;;
  esac
done

export PROJECT_ROOT

# --- Source graph-db.sh for get_db_path() and db_query() ---
# shellcheck source=../knowledge/lib/graph-db.sh
source "$SCRIPT_DIR/../knowledge/lib/graph-db.sh"

# --- Locate knowledge.db ---
db_path="$(get_db_path)"

if [ ! -f "$db_path" ]; then
  echo "GRAPH_HEALTH: knowledge.db not found"
  echo "DOCTOR:GRAPH_HEALTH status=skip"
  exit 0
fi

# --- 1. Graph Statistics ---
entry_count="$(db_query "$db_path" "SELECT COUNT(*) FROM entries;")" || entry_count=0
edge_count="$(db_query "$db_path" "SELECT COUNT(*) FROM edges;")" || edge_count=0
scope_tag_count="$(db_query "$db_path" "SELECT COUNT(DISTINCT tag) FROM scope_tags;")" || scope_tag_count=0

# Average degree: 2 * edges / entries (total degree, both endpoints)
if [ "$entry_count" -gt 0 ] 2>/dev/null; then
  avg_degree="$(db_query "$db_path" "SELECT ROUND(CAST(${edge_count} AS REAL) * 2 / ${entry_count}, 2);")" || avg_degree="0.0"
else
  avg_degree="0.0"
fi

# --- 2. Orphaned Entries (no edges at all) ---
orphan_ids="$(db_query "$db_path" "
  SELECT e.id FROM entries e
  LEFT JOIN edges e1 ON e.id = e1.source_id
  LEFT JOIN edges e2 ON e.id = e2.target_id
  WHERE e1.source_id IS NULL AND e2.target_id IS NULL;
")" || orphan_ids=""

orphan_count=0
orphan_list=""
if [ -n "$orphan_ids" ]; then
  orphan_count="$(printf '%s\n' "$orphan_ids" | wc -l | tr -d ' ')"
  # Build comma-separated list
  orphan_list="$(printf '%s\n' "$orphan_ids" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')"
fi

# --- 3. Connected Components (iterative shell loop) ---
component_count=0
largest_component=0

if [ "$entry_count" -gt 0 ] 2>/dev/null && [ "$entry_count" -ne 0 ]; then
  remaining_entries="$(db_query "$db_path" "SELECT id FROM entries;")" || remaining_entries=""

  while [ -n "$remaining_entries" ]; do
    seed="$(printf '%s\n' "$remaining_entries" | head -1)"
    safe_seed="$(printf '%s' "$seed" | sed "s/'/''/g")"

    component="$(db_query "$db_path" "
      WITH RECURSIVE reachable(id) AS (
        SELECT '${safe_seed}'
        UNION
        SELECT e.target_id FROM edges e JOIN reachable r ON e.source_id = r.id
        UNION
        SELECT e.source_id FROM edges e JOIN reachable r ON e.target_id = r.id
      )
      SELECT id FROM reachable;
    ")" || component="$seed"

    comp_size="$(printf '%s\n' "$component" | wc -l | tr -d ' ')"
    component_count=$((component_count + 1))
    if [ "$comp_size" -gt "$largest_component" ]; then
      largest_component="$comp_size"
    fi

    # Remove this component's entries from remaining
    new_remaining=""
    while IFS= read -r eid; do
      [ -z "$eid" ] && continue
      in_component=false
      while IFS= read -r cid; do
        [ -z "$cid" ] && continue
        if [ "$eid" = "$cid" ]; then
          in_component=true
          break
        fi
      done <<COMP_EOF
$component
COMP_EOF
      if [ "$in_component" = false ]; then
        new_remaining="${new_remaining}${eid}
"
      fi
    done <<REM_EOF
$remaining_entries
REM_EOF
    remaining_entries="$(printf '%s' "$new_remaining" | sed '/^$/d')"
  done
fi

# --- 4. Broken Supersession Chains ---
broken_supersedes="$(db_query "$db_path" "
  SELECT e.id, e.supersedes FROM entries e
  WHERE e.supersedes != ''
  AND NOT EXISTS (SELECT 1 FROM entries e2 WHERE e2.id = e.supersedes);
")" || broken_supersedes=""

broken_superseded_by="$(db_query "$db_path" "
  SELECT e.id, e.superseded_by FROM entries e
  WHERE e.superseded_by != ''
  AND NOT EXISTS (SELECT 1 FROM entries e2 WHERE e2.id = e.superseded_by);
")" || broken_superseded_by=""

broken_chain_count=0
if [ -n "$broken_supersedes" ]; then
  broken_chain_count="$(printf '%s\n' "$broken_supersedes" | wc -l | tr -d ' ')"
fi
if [ -n "$broken_superseded_by" ]; then
  extra="$(printf '%s\n' "$broken_superseded_by" | wc -l | tr -d ' ')"
  broken_chain_count=$((broken_chain_count + extra))
fi

# --- 5. Dangling Edges ---
dangling="$(db_query "$db_path" "
  SELECT e.source_id, e.target_id, e.edge_type FROM edges e
  WHERE NOT EXISTS (SELECT 1 FROM entries n WHERE n.id = e.source_id)
     OR NOT EXISTS (SELECT 1 FROM entries n WHERE n.id = e.target_id);
")" || dangling=""

dangling_count=0
if [ -n "$dangling" ]; then
  dangling_count="$(printf '%s\n' "$dangling" | wc -l | tr -d ' ')"
fi

# --- Determine Status ---
status="ok"
if [ "$broken_chain_count" -gt 0 ] || [ "$dangling_count" -gt 0 ]; then
  status="drift"
elif [ "$orphan_count" -gt 1 ] || [ "$component_count" -gt 1 ]; then
  status="warn"
fi

# --- Human-Readable Output ---
echo "GRAPH_HEALTH: knowledge.db"
echo "  Statistics: ${entry_count} entries, ${edge_count} edges, ${scope_tag_count} scope_tags, avg degree ${avg_degree}"

if [ "$orphan_count" -gt 0 ]; then
  echo "  Orphaned entries: ${orphan_count} (${orphan_list})"
else
  echo "  Orphaned entries: 0"
fi

echo "  Connected components: ${component_count} (largest: ${largest_component} entries)"
echo "  Broken supersession chains: ${broken_chain_count}"
echo "  Dangling edges: ${dangling_count}"

# Overall label
case "$status" in
  ok) echo "  Overall: HEALTHY" ;;
  warn) echo "  Overall: WARNINGS" ;;
  drift) echo "  Overall: INTEGRITY ISSUES" ;;
esac

# --- Machine-Readable DOCTOR Line ---
echo "DOCTOR:GRAPH_HEALTH status=${status} entries=${entry_count} edges=${edge_count} orphans=${orphan_count} components=${component_count} broken_chains=${broken_chain_count} dangling=${dangling_count}"

exit 0
