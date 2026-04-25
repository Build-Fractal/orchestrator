#!/usr/bin/env bash
# scripts/knowledge/lib/cluster.sh — FR-5 clustering helper consumed by
# scripts/knowledge/consolidate-artifacts.sh (P05 --cluster extension).
#
# Provides:
#   cluster_compute <knowledge-root> <threshold>
#       Walks <knowledge-root>/**/MEM*.md filtering to status: candidate,
#       computes pairwise Jaccard via pairwise_jaccard, builds an undirected
#       similarity graph with edges where similarity >= threshold, emits one
#       TAB-separated <cluster-id>\t<member-id> line per (cluster, member)
#       pair on stdout, sorted by cluster-id asc then member-id asc.
#       Singletons form their own one-member clusters.
#
#   cluster_id_for <sorted-csv-of-member-ids>
#       Deterministic AD-3 cluster ID. Echoes C<8-hex> on stdout.
#       Same input -> same output across runs.
#
# Pure helpers — neither writes to knowledge/** nor to .orchestrator/**.
# All output flows to stdout.
#
# Schema dependency: consumes the closed-enum status: vocabulary defined in
# knowledge/conventions/MEM031.md (candidate|graduated|archived). Pre-M020
# entries without a status: field default to graduated per FR-10 and are
# therefore EXCLUDED from clustering (graduated entries are not eligible).
#
# References lib/jaccard.sh for pairwise_jaccard primitive (AD-19 single-
# script-invocation safe — pairwise_jaccard is sourced as a function, not
# spawned).
#
# Bash 3.2 compatible. AD-19 single-script-invocation shape. MEM001 prefixed-
# output conventions.

# --- Double-source guard ---
[ -n "${_CLUSTER_HELPER_SOURCED:-}" ] && return 0
_CLUSTER_HELPER_SOURCED=1

_CLUSTER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CLUSTER_JACCARD_BIN="$_CLUSTER_SCRIPT_DIR/jaccard.sh"

# Note: jaccard.sh uses `$0`-based SCRIPT_DIR resolution + `set -euo pipefail`
# at file scope, which makes sourcing it from another helper unsafe (a missing
# subcommand triggers `exit 1` in the host shell). Invoke it as a subprocess
# instead — `bash <jaccard.sh> pairwise_jaccard <a> <b>` — which is the
# AD-19 single-script-invocation shape the bottom of jaccard.sh dispatches on.

# --- AD-3 cluster ID: C<first-8-hex-of-sha1(sorted-csv)> ---
cluster_id_for() {
  local sorted_csv="$1"
  local hash
  if command -v shasum >/dev/null 2>&1; then
    hash="$(printf '%s' "$sorted_csv" | shasum -a 1 | awk '{print substr($1,1,8)}')"
  elif command -v sha1sum >/dev/null 2>&1; then
    hash="$(printf '%s' "$sorted_csv" | sha1sum | awk '{print substr($1,1,8)}')"
  else
    echo "FAIL: cluster_id_for requires shasum or sha1sum" >&2
    return 1
  fi
  printf 'C%s\n' "$hash"
}

# --- cluster_compute: walk tree, compute pairwise graph, emit clusters ---
# Args: <knowledge-root> <threshold>
# Threshold is a decimal in [0.0, 1.0]; awk handles the floating-point compare.
# Output: one TAB-separated <cluster-id>\t<member-id> line per (cluster, member)
# pair, sorted by cluster-id asc, then member-id asc.
cluster_compute() {
  local root="$1"
  local threshold="$2"

  if [ -z "$root" ] || [ ! -d "$root" ]; then
    echo "FAIL: cluster_compute requires an existing knowledge-root directory (got '$root')" >&2
    return 1
  fi
  if [ -z "$threshold" ]; then
    echo "FAIL: cluster_compute requires a threshold argument" >&2
    return 1
  fi

  # --- Step A: collect candidate entry ids + file paths ---
  # Bash 3.2: parallel newline-joined scalars, not associative arrays.
  local ids=""
  local files=""
  local n=0

  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    # Filter to status: candidate. fm_read_status falls back to graduated for
    # missing field per FR-10; we only want explicit candidates.
    local raw_status
    raw_status="$(awk '
      /^---$/ { n++; if (n==2) exit; next }
      n==1 && /^status:/ {
        sub(/^status:[[:space:]]*/, "")
        sub(/[[:space:]]+$/, "")
        sub(/^"/, ""); sub(/"$/, "")
        print
        exit
      }
    ' "$f" 2>/dev/null || true)"
    [ "$raw_status" = "candidate" ] || continue

    # Derive entry id from the basename minus extension.
    local id
    id="$(basename "$f" .md)"

    if [ "$n" -eq 0 ]; then
      ids="$id"
      files="$f"
    else
      ids="$ids
$id"
      files="$files
$f"
    fi
    n=$(( n + 1 ))
  done <<EOF
$(find "$root" -type f -name 'MEM*.md' | LC_ALL=C sort)
EOF

  if [ "$n" -eq 0 ]; then
    # No candidates -> empty cluster set. Exit 0; emit nothing.
    return 0
  fi

  # --- Step B: union-find over the similarity graph ---
  # parent[i] = i initially. Bash 3.2: parallel indexed scalars.
  local i j
  local parent_arr=""
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "$i" -eq 0 ]; then
      parent_arr="$i"
    else
      parent_arr="$parent_arr
$i"
    fi
    i=$(( i + 1 ))
  done

  # Helper: read parent[k]
  _cluster_parent_get() {
    local k="$1"
    printf '%s\n' "$parent_arr" | awk -v n="$(( k + 1 ))" 'NR==n{print; exit}'
  }
  # Helper: write parent[k] = v (rebuilds parent_arr)
  _cluster_parent_set() {
    local k="$1" v="$2"
    parent_arr="$(printf '%s\n' "$parent_arr" | awk -v n="$(( k + 1 ))" -v v="$v" 'NR==n{print v; next}{print}')"
  }
  # Find with path compression.
  _cluster_find() {
    local k="$1" p
    p="$(_cluster_parent_get "$k")"
    while [ "$p" != "$k" ]; do
      k="$p"
      p="$(_cluster_parent_get "$k")"
    done
    printf '%s\n' "$k"
  }
  # Union.
  _cluster_union() {
    local a="$1" b="$2" ra rb
    ra="$(_cluster_find "$a")"
    rb="$(_cluster_find "$b")"
    [ "$ra" = "$rb" ] && return 0
    if [ "$ra" -lt "$rb" ]; then
      _cluster_parent_set "$rb" "$ra"
    else
      _cluster_parent_set "$ra" "$rb"
    fi
  }

  # --- Step C: pairwise iteration; union when similarity >= threshold ---
  i=0
  while [ "$i" -lt "$n" ]; do
    j=$(( i + 1 ))
    local file_i
    file_i="$(printf '%s\n' "$files" | awk -v n="$(( i + 1 ))" 'NR==n{print; exit}')"
    while [ "$j" -lt "$n" ]; do
      local file_j
      file_j="$(printf '%s\n' "$files" | awk -v n="$(( j + 1 ))" 'NR==n{print; exit}')"
      local sim_line sim
      sim_line="$(bash "$_CLUSTER_JACCARD_BIN" pairwise_jaccard "$file_i" "$file_j" 2>/dev/null || true)"
      sim="$(printf '%s\n' "$sim_line" | sed -n 's/^similarity=//p' | head -1)"
      [ -z "$sim" ] && { j=$(( j + 1 )); continue; }
      # awk-based >= comparison; emits "1" if true, "0" otherwise.
      local ge
      ge="$(awk -v s="$sim" -v t="$threshold" 'BEGIN{ if (s+0 >= t+0) print 1; else print 0 }')"
      if [ "$ge" = "1" ]; then
        _cluster_union "$i" "$j"
      fi
      j=$(( j + 1 ))
    done
    i=$(( i + 1 ))
  done

  # --- Step D: gather clusters by root, emit deterministic output ---
  # Build a list of (root_idx, member_id) pairs.
  local pairs=""
  i=0
  while [ "$i" -lt "$n" ]; do
    local r mem_id
    r="$(_cluster_find "$i")"
    mem_id="$(printf '%s\n' "$ids" | awk -v n="$(( i + 1 ))" 'NR==n{print; exit}')"
    if [ -z "$pairs" ]; then
      pairs="$r	$mem_id"
    else
      pairs="$pairs
$r	$mem_id"
    fi
    i=$(( i + 1 ))
  done

  # Sort pairs by root, then by member-id.
  local sorted_pairs
  sorted_pairs="$(printf '%s\n' "$pairs" | LC_ALL=C sort -k1,1n -k2,2)"

  # Group members by root via awk and emit __GROUP__ markers + member rows
  # to a scratch file. Subshell-locality of bash while loops would lose
  # current_members at exit; awk has no such issue.
  local scratch
  scratch="/tmp/_cluster_groups.$$"
  printf '%s\n' "$sorted_pairs" | awk -F'\t' '
    NF < 2 { next }
    { groups[$1] = (groups[$1] ? groups[$1] "\n" $2 : $2)
      if (!seen[$1]) { order[++n_order] = $1; seen[$1] = 1 } }
    END {
      for (k = 1; k <= n_order; k++) {
        r = order[k]
        nmem = split(groups[r], mems, "\n")
        # Lexicographic sort (small n).
        for (a = 1; a < nmem; a++) {
          for (b = a + 1; b <= nmem; b++) {
            if (mems[a] > mems[b]) { t = mems[a]; mems[a] = mems[b]; mems[b] = t }
          }
        }
        csv = ""
        for (a = 1; a <= nmem; a++) csv = csv (a == 1 ? "" : ",") mems[a]
        print "__GROUP__\t" csv
        for (a = 1; a <= nmem; a++) print r "\t" mems[a]
      }
    }
  ' > "$scratch" 2>/dev/null

  # Walk scratch: __GROUP__ rows declare the next cluster id; member rows
  # consume the active cid. Emit final <cluster-id>\t<member-id> output.
  local cid="" marker payload
  while IFS='	' read -r marker payload; do
    [ -z "$marker" ] && continue
    if [ "$marker" = "__GROUP__" ]; then
      cid="$(cluster_id_for "$payload")"
    else
      [ -z "$cid" ] && continue
      printf '%s\t%s\n' "$cid" "$payload"
    fi
  done < "$scratch" | LC_ALL=C sort -k1,1 -k2,2
  rm -f "$scratch"
}
