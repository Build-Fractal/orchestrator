#!/usr/bin/env bash
# scripts/knowledge/traverse-graph.sh — Traverse knowledge entry relationship graph
# Given an entry ID, returns related entry IDs using a recursive CTE against knowledge.db.
#
# Usage: traverse-graph.sh --id MEM042 [--max-depth 1] [--hops 1] [--max-entries 5] [--ranked]
#        traverse-graph.sh --id MEM042 --provenance
#
# Output (default): one related entry ID per line to stdout
# Output (--ranked): id|confidence|depth|ranked_score per line
# Output (--provenance): supersession chain from origin to current with labels
# Warnings go to stderr. Exit 0 always (no related entries is valid).
#
# Requires: knowledge.db (built by rebuild-index.sh), graph-db.sh library.
# Bash 3.2 compatible (no associative arrays, no mapfile).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/graph-db.sh
source "$SCRIPT_DIR/lib/graph-db.sh"

# --- Defaults ---
entry_id=""
max_depth=1
max_entries=5
ranked=false
provenance=false
edge_types=""   # M036/P05/T02: empty = sentinel for legacy relates_to-only path (CON-5)
reverse=false   # M036/P05/T02: BFS direction for typed-edge mode

# --- Argument parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --id)
      entry_id="$2"
      shift 2
      ;;
    --max-depth|--hops)
      max_depth="$2"
      shift 2
      ;;
    --max-entries)
      max_entries="$2"
      shift 2
      ;;
    --ranked)
      ranked=true
      shift
      ;;
    --provenance)
      provenance=true
      shift
      ;;
    --edge-types)
      edge_types="$2"
      shift 2
      ;;
    --reverse)
      reverse=true
      shift
      ;;
    *)
      echo "traverse-graph.sh: unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

if [ -z "$entry_id" ]; then
  echo "traverse-graph.sh: --id is required" >&2
  echo "Usage: traverse-graph.sh --id MEM042 [--max-depth 1] [--hops 1] [--max-entries 5] [--ranked]" >&2
  exit 1
fi

# --- Resolve database path ---
db_path="$(get_db_path)"

if [ ! -f "$db_path" ]; then
  echo "WARNING: knowledge.db not found at $db_path — run rebuild-index.sh first" >&2
  exit 0
fi

# --- Escape single quotes in entry_id for SQL safety ---
safe_id="$(printf '%s' "$entry_id" | sed "s/'/''/g")"

# --- Provenance mode ---
# Follows supersession chain in both directions via recursive CTEs on the
# supersedes/superseded_by columns of the entries table.
if [ "$provenance" = true ]; then
  sql="
WITH RECURSIVE
backward(id, depth) AS (
  SELECT supersedes, 1 FROM entries WHERE id = '${safe_id}' AND supersedes != ''
  UNION ALL
  SELECT e.supersedes, b.depth + 1
    FROM entries e JOIN backward b ON e.id = b.id
    WHERE e.supersedes != ''
),
forward(id, depth) AS (
  SELECT id, 1 FROM entries WHERE supersedes = '${safe_id}' AND supersedes != ''
  UNION ALL
  SELECT e.id, f.depth + 1
    FROM entries e JOIN forward f ON e.supersedes = f.id
    WHERE e.supersedes != ''
)
SELECT e.id || '|' || printf('%.2f', e.confidence) || '|' || e.created_at || '|' || e.description || '|backward|' || b.depth
FROM entries e JOIN backward b ON e.id = b.id
UNION ALL
SELECT id || '|' || printf('%.2f', confidence) || '|' || created_at || '|' || description || '|self|0'
FROM entries WHERE id = '${safe_id}'
UNION ALL
SELECT e.id || '|' || printf('%.2f', e.confidence) || '|' || e.created_at || '|' || e.description || '|forward|' || f.depth
FROM entries e JOIN forward f ON e.id = f.id;
"

  chain_results="$(db_query "$db_path" "$sql")" || true

  if [ -z "$chain_results" ]; then
    echo "PROVENANCE: ${entry_id} (not found)"
    exit 0
  fi

  # Check if only self was returned — verify the entry actually exists
  self_only=true
  has_self=false
  while IFS= read -r line; do
    direction="$(echo "$line" | awk -F'|' '{print $5}')"
    if [ "$direction" = "self" ]; then
      has_self=true
    else
      self_only=false
    fi
  done <<EOF_CHECK
$chain_results
EOF_CHECK

  if [ "$has_self" = false ]; then
    echo "PROVENANCE: ${entry_id} (not found)"
    exit 0
  fi

  # Sort: backward entries (reverse order — deepest first = origin)
  chain_count=0

  # Collect backward entries (reverse order — deepest first = origin)
  backward_lines=""
  while IFS= read -r line; do
    direction="$(echo "$line" | awk -F'|' '{print $5}')"
    if [ "$direction" = "backward" ]; then
      backward_lines="${line}
${backward_lines}"
      chain_count=$((chain_count + 1))
    fi
  done <<EOF_CHAIN
$chain_results
EOF_CHAIN

  # Self
  self_line=""
  while IFS= read -r line; do
    direction="$(echo "$line" | awk -F'|' '{print $5}')"
    if [ "$direction" = "self" ]; then
      self_line="$line"
      chain_count=$((chain_count + 1))
    fi
  done <<EOF_CHAIN2
$chain_results
EOF_CHAIN2

  # Forward entries (in order)
  forward_lines=""
  while IFS= read -r line; do
    direction="$(echo "$line" | awk -F'|' '{print $5}')"
    if [ "$direction" = "forward" ]; then
      forward_lines="${forward_lines}${line}
"
      chain_count=$((chain_count + 1))
    fi
  done <<EOF_CHAIN3
$chain_results
EOF_CHAIN3

  echo "PROVENANCE: ${entry_id} (chain length: ${chain_count})"

  idx=0
  # Print backward (origin first)
  if [ -n "$backward_lines" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      id_f="$(echo "$line" | awk -F'|' '{print $1}')"
      conf_f="$(echo "$line" | awk -F'|' '{print $2}')"
      date_f="$(echo "$line" | awk -F'|' '{print $3}')"
      desc_f="$(echo "$line" | awk -F'|' '{print $4}')"
      if [ "$idx" -eq 0 ]; then
        label="origin"
      else
        label="superseded"
      fi
      echo "  [${idx}] ${id_f} | ${conf_f} | ${date_f} | ${desc_f} (${label})"
      idx=$((idx + 1))
    done <<EOF_BW
$backward_lines
EOF_BW
  fi

  # Print self
  if [ -n "$self_line" ]; then
    id_f="$(echo "$self_line" | awk -F'|' '{print $1}')"
    conf_f="$(echo "$self_line" | awk -F'|' '{print $2}')"
    date_f="$(echo "$self_line" | awk -F'|' '{print $3}')"
    desc_f="$(echo "$self_line" | awk -F'|' '{print $4}')"
    if [ "$chain_count" -eq 1 ]; then
      label="sole entry"
    elif [ -z "$backward_lines" ] && [ -n "$forward_lines" ]; then
      label="origin"
    elif [ -n "$forward_lines" ]; then
      label="superseded"
    else
      label="current"
    fi
    echo "  [${idx}] ${id_f} | ${conf_f} | ${date_f} | ${desc_f} (${label})"
    idx=$((idx + 1))
  fi

  # Print forward (newest last)
  if [ -n "$forward_lines" ]; then
    # Count forward entries to know which is last
    fwd_count=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      fwd_count=$((fwd_count + 1))
    done <<EOF_FC
$forward_lines
EOF_FC

    fwd_idx=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      id_f="$(echo "$line" | awk -F'|' '{print $1}')"
      conf_f="$(echo "$line" | awk -F'|' '{print $2}')"
      date_f="$(echo "$line" | awk -F'|' '{print $3}')"
      desc_f="$(echo "$line" | awk -F'|' '{print $4}')"
      fwd_idx=$((fwd_idx + 1))
      if [ "$fwd_idx" -eq "$fwd_count" ]; then
        label="current"
      else
        label="superseded"
      fi
      echo "  [${idx}] ${id_f} | ${conf_f} | ${date_f} | ${desc_f} (${label})"
      idx=$((idx + 1))
    done <<EOF_FW
$forward_lines
EOF_FW
  fi

  exit 0
fi

# --- Typed-edge mode (M036/P05/T02) ---
# When --edge-types <comma-list> is passed, walk the specified edge types instead
# of the default relates_to-only path. Output is suffixed with '|<edge_type>' so
# consumers can grep the label. CON-5: this branch is GUARDED so the default-mode
# (no --edge-types) code path below remains byte-identical to the pre-T02 traverser.
# Directionality follows references/reference-edge-types.md (P00 SSOT):
#   relates_to       — bidirectional (existing semantics).
#   supersedes       — directional (newer -> older).
#   cites            — directional (citer -> cited).
#   derived_from     — directional (downstream -> upstream).
#   applies_to_field — directional (chunk -> field-name string).
# Default direction is forward (source_id = entry); --reverse swaps to walk
# targets-first (needed for "BFS from cms-rule chunk in reverse, training chunk
# reachable via derived_from").
#
# applies_to_field special case: target_id is a field name, not a chunk ID, so no
# entries row exists for it. We use LEFT JOIN entries and emit the raw target_id
# when the join misses (see comment at the LEFT JOIN site below).

if [ -n "$edge_types" ]; then
  # Parse comma-list into a SQL IN clause. Use IFS=',' loop (matches scope-filter.sh
  # --depends pattern at lines 119-128). No bashism: build a single string with
  # quoted, escaped tokens so the SQL is bash-3.2 / POSIX-sh safe.
  types_clause=""
  old_ifs="$IFS"
  IFS=','
  for raw_type in $edge_types; do
    # Trim whitespace
    t="$(printf '%s' "$raw_type" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    if [ -z "$t" ]; then
      continue
    fi
    # Escape single quotes (matches the safe_id pattern at line 74)
    t_safe="$(printf '%s' "$t" | sed "s/'/''/g")"
    if [ -z "$types_clause" ]; then
      types_clause="'${t_safe}'"
    else
      types_clause="${types_clause}, '${t_safe}'"
    fi
  done
  IFS="$old_ifs"

  if [ -z "$types_clause" ]; then
    echo "traverse-graph.sh: --edge-types value is empty after parsing" >&2
    exit 1
  fi

  # Build the typed-edge CTE. Forward direction by default; --reverse swaps
  # source_id/target_id roles in the WHERE clauses. Most new edge types are
  # directional, so this CTE is single-branch (unlike the bidirectional legacy
  # CTE below).
  if [ "$reverse" = true ]; then
    base_sel="SELECT source_id, edge_type, 1 FROM edges WHERE target_id = '${safe_id}' AND edge_type IN (${types_clause})"
    rec_sel="SELECT e2.source_id, e2.edge_type, r.depth + 1 FROM edges e2 JOIN reachable r ON e2.target_id = r.id WHERE r.depth < ${max_depth} AND e2.edge_type IN (${types_clause}) AND e2.source_id != '${safe_id}'"
  else
    base_sel="SELECT target_id, edge_type, 1 FROM edges WHERE source_id = '${safe_id}' AND edge_type IN (${types_clause})"
    rec_sel="SELECT e2.target_id, e2.edge_type, r.depth + 1 FROM edges e2 JOIN reachable r ON e2.source_id = r.id WHERE r.depth < ${max_depth} AND e2.edge_type IN (${types_clause}) AND e2.target_id != '${safe_id}'"
  fi

  if [ "$ranked" = true ]; then
    # When --ranked AND --edge-types both present, append the edge-type suffix to
    # the existing ranked shape (per task plan step 2).
    typed_select_cols="e.id || '|' || e.confidence || '|' || MIN(r.depth) || '|' || printf('%.6f', e.confidence * (1.0 / MIN(r.depth))) || '|' || r.edge_type"
    typed_group_by="GROUP BY e.id, r.edge_type"
    typed_order_by="ORDER BY e.confidence * (1.0 / MIN(r.depth)) DESC"
  else
    typed_select_cols="e.id || '|' || r.edge_type"
    typed_group_by="GROUP BY e.id, r.edge_type"
    typed_order_by=""
  fi

  # LEFT JOIN entries: applies_to_field edges target a field-name string (e.g.
  # "staff_count"), not a chunk ID. An INNER JOIN would silently drop those rows
  # because no entries row exists for the field name. The COALESCE below emits
  # the raw target_id when the join misses, so applies_to_field edges surface
  # in the output as "<field-name>|applies_to_field". See
  # references/reference-edge-types.md (M036/P00/T02) directionality table.
  sql="
WITH RECURSIVE reachable(id, edge_type, depth) AS (
  ${base_sel}
  UNION ALL
  ${rec_sel}
)
SELECT COALESCE(e.id, r.id) || '|' || r.edge_type
FROM reachable r
LEFT JOIN entries e ON e.id = r.id
WHERE COALESCE(e.id, r.id) != '${safe_id}'
${typed_group_by}
${typed_order_by}
LIMIT ${max_entries};
"

  # Override the simple line shape when --ranked is set. Re-build SQL with the
  # ranked select cols (the COALESCE shape above only handles the unranked case
  # because the ranked shape needs e.confidence which is NULL for missed joins).
  if [ "$ranked" = true ]; then
    sql="
WITH RECURSIVE reachable(id, edge_type, depth) AS (
  ${base_sel}
  UNION ALL
  ${rec_sel}
)
SELECT ${typed_select_cols}
FROM entries e JOIN reachable r ON e.id = r.id
WHERE e.id != '${safe_id}'
${typed_group_by}
${typed_order_by}
LIMIT ${max_entries};
"
  fi

  results="$(db_query "$db_path" "$sql")" || true

  if [ -n "$results" ]; then
    result_count="$(printf '%s\n' "$results" | wc -l | tr -d ' ')"
    printf '%s\n' "$results"
    if [ "$result_count" -ge "$max_entries" ]; then
      echo "WARNING: max-entries limit ($max_entries) reached, results may be truncated" >&2
    fi
  fi

  exit 0
fi

# --- Build and execute recursive CTE query ---
# Queries both edge directions since relates_to is semantically bidirectional.
# Uses MIN(depth) to pick the shortest path when an entry is reachable via
# multiple routes. Ranks by effective_confidence * (1.0 / min_depth).

if [ "$ranked" = true ]; then
  select_cols="e.id || '|' || e.confidence || '|' || MIN(r.depth) || '|' || printf('%.6f', e.confidence * (1.0 / MIN(r.depth)))"
else
  select_cols="e.id"
fi

sql="
WITH RECURSIVE reachable(id, depth) AS (
  SELECT target_id, 1 FROM edges
    WHERE source_id = '${safe_id}' AND edge_type = 'relates_to'
  UNION
  SELECT source_id, 1 FROM edges
    WHERE target_id = '${safe_id}' AND edge_type = 'relates_to'
  UNION ALL
  SELECT e2.target_id, r.depth + 1
    FROM edges e2 JOIN reachable r ON e2.source_id = r.id
    WHERE r.depth < ${max_depth} AND e2.edge_type = 'relates_to'
      AND e2.target_id != '${safe_id}'
  UNION ALL
  SELECT e2.source_id, r.depth + 1
    FROM edges e2 JOIN reachable r ON e2.target_id = r.id
    WHERE r.depth < ${max_depth} AND e2.edge_type = 'relates_to'
      AND e2.source_id != '${safe_id}'
)
SELECT ${select_cols}
FROM entries e
JOIN reachable r ON e.id = r.id
WHERE e.id != '${safe_id}'
GROUP BY e.id
ORDER BY e.confidence * (1.0 / MIN(r.depth)) DESC
LIMIT ${max_entries};
"

results="$(db_query "$db_path" "$sql")" || true

if [ -n "$results" ]; then
  result_count="$(printf '%s\n' "$results" | wc -l | tr -d ' ')"
  printf '%s\n' "$results"
  if [ "$result_count" -ge "$max_entries" ]; then
    echo "WARNING: max-entries limit ($max_entries) reached, results may be truncated" >&2
  fi
fi

exit 0
