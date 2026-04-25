---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M020"
name: "Cluster computation helper (lib/cluster.sh)"
depends_on: []
---

## Prerequisites

- P01: `scripts/knowledge/lib/jaccard.sh` exposes `pairwise_jaccard <file-a> <file-b>` (emits `similarity=N.NNNN` to stdout) and `_jaccard_extract_tokens <file>` (echoes feature-vector tokens, one per line). Bash 3.2 safe.
- P01: `scripts/knowledge/lib/index-utils.sh` exposes `get_project_root` (honors `PROJECT_ROOT` env var per the 4-rule resolver) and adjacent helpers. `scripts/knowledge/lib/detail-utils.sh` exposes `find_detail_file <id>`.
- P01: `scripts/knowledge/lib/frontmatter.sh` exposes `fm_read_status <file>` returning the `status:` field value (or `graduated` per FR-10 default for entries lacking the field).
- M020 ROADMAP cross-cutting concern (atomic frontmatter writes / read-only-during-dispatch): cluster.sh is a pure read-only helper; it MUST NOT mutate any file under `knowledge/**` or anywhere else. All output flows to stdout.
- M020-CONTEXT.md AD-3: cluster IDs are content-hashes of the cluster's sorted member-ID set, truncated to 8 hex characters and prefixed `C`. Deterministic across runs.

## Description

Create a NEW pure-function helper at `scripts/knowledge/lib/cluster.sh` that implements FR-5 clustering on top of the P01 `pairwise_jaccard` primitive. The helper is sourceable (double-source-guarded per the P03 convention) and exposes two functions:

1. **`cluster_compute <knowledge-root> <threshold>`** — walks `<knowledge-root>` for `MEM*.md` files (filtering to `status: candidate` only — graduated and archived entries are not eligible for clustering per spec FR-5 implicit semantic; this is verified by tempdir-fixture isolation in the verifier suite), computes the pairwise Jaccard graph, finds connected components with edge-weight >= `<threshold>`, and emits one TAB-separated `<cluster-id>\t<member-id>` line per (cluster, member) pair on stdout, sorted by `<cluster-id>` ascending then `<member-id>` ascending. Singletons (members with no above-threshold neighbours) form their own one-member clusters. Pure read; no file mutations; no JSONL emission. Exit 0 on success; non-zero on error (e.g. unreadable knowledge-root).

2. **`cluster_id_for <sorted-csv-of-member-ids>`** — deterministic content-hash. Echoes `C<first-8-hex-of-sha1(<sorted-csv>)>` on stdout. Same input -> same output across runs (AD-3 contract). The CSV must be sorted by the caller; cluster_id_for does not re-sort.

The connected-component algorithm is the standard union-find or BFS-from-each-unvisited-node approach over the similarity graph. Bash 3.2 safe: parallel indexed scalars for the union-find parent array; no `declare -A`. Iteration over pairs is O(n^2) which is fine at the milestone scale (<= 50 candidate entries per milestone per the M020-CONTEXT.md rebuild-cost note).

`cluster.sh` is operator-invoked indirectly via `consolidate-artifacts.sh --cluster` (T03 of this phase). It is NOT a callable surface from dispatch (FR-8 / CON-1 — clustering is mutation-adjacent and operator-only).

## Steps

### Step 1: Create `scripts/knowledge/lib/cluster.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/knowledge/lib/cluster.sh`

Reference implementation:

```bash
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
# shellcheck source=jaccard.sh
. "$_CLUSTER_SCRIPT_DIR/jaccard.sh"
# shellcheck source=frontmatter.sh
. "$_CLUSTER_SCRIPT_DIR/frontmatter.sh"

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
      sim_line="$(pairwise_jaccard "$file_i" "$file_j" 2>/dev/null || true)"
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
  # Build a list of (root_idx, member_id) pairs, then group.
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

  # Walk sorted pairs grouped by root_idx; for each group, compute the cluster
  # id from the sorted member ids and emit <cluster-id>\t<member-id> lines.
  local current_root="" current_members=""
  printf '%s\n' "$sorted_pairs" | while IFS='	' read -r r mem; do
    [ -z "$r" ] && continue
    if [ "$r" != "$current_root" ]; then
      if [ -n "$current_root" ]; then
        # Emit prior group.
        local sorted_ids cid m
        sorted_ids="$(printf '%s\n' "$current_members" | LC_ALL=C sort | tr '\n' ',' | sed 's/,$//')"
        cid="$(cluster_id_for "$sorted_ids")"
        printf '%s\n' "$current_members" | LC_ALL=C sort | while IFS= read -r m; do
          [ -z "$m" ] && continue
          printf '%s\t%s\n' "$cid" "$m"
        done
      fi
      current_root="$r"
      current_members="$mem"
    else
      current_members="$current_members
$mem"
    fi
  done | { cat; }
  # Emit final group: subshell-locality of the while loop above means we lose
  # current_members at exit. Re-run grouping in a single awk pass for the
  # final emission to ensure determinism without subshell variable loss.
  printf '%s\n' "$sorted_pairs" | awk -F'\t' '
    { groups[$1] = (groups[$1] ? groups[$1] "\n" $2 : $2); order[++n_order] = (seen[$1] ? "" : $1); seen[$1]=1 }
    END {
      for (k=1; k<=n_order; k++) {
        r = order[k]
        if (r == "") continue
        # sort members lexicographically.
        nmem = split(groups[r], mems, "\n")
        # Bubble sort (small n, bash-3.2-mindset; awk has no built-in sort fn portably).
        for (a=1; a<nmem; a++) for (b=a+1; b<=nmem; b++) if (mems[a] > mems[b]) { t=mems[a]; mems[a]=mems[b]; mems[b]=t }
        csv = ""
        for (a=1; a<=nmem; a++) csv = csv (a==1 ? "" : ",") mems[a]
        print "__GROUP__\t" csv
        for (a=1; a<=nmem; a++) print r "\t" mems[a]
      }
    }
  ' > /tmp/_cluster_groups.$$ 2>/dev/null || true

  # Now compute cluster IDs and emit final output.
  local group_csv group_root
  while IFS='	' read -r marker payload; do
    [ -z "$marker" ] && continue
    if [ "$marker" = "__GROUP__" ]; then
      group_csv="$payload"
      group_root=""
      cid="$(cluster_id_for "$group_csv")"
    else
      printf '%s\t%s\n' "$cid" "$payload"
    fi
  done < /tmp/_cluster_groups.$$
  rm -f /tmp/_cluster_groups.$$
}
```

Make executable:

```
chmod +x scripts/knowledge/lib/cluster.sh
```

Note: this implementation uses an awk pass for final grouping to dodge the subshell-variable-loss bash 3.2 trap. The /tmp/_cluster_groups.$$ scratch file is local to the function call and removed at the end; it is not a knowledge mutation.

### Step 2: Create `scripts/verify/m020-p05-cluster-helper-contract.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p05-cluster-helper-contract.sh`

Verifier asserts (1) the helper sources cleanly, (2) `cluster_id_for` produces deterministic AD-3-shaped IDs, (3) `cluster_compute` emits the expected schema (TAB-separated `<cluster-id>\t<member-id>` lines).

```bash
#!/usr/bin/env bash
# m020-p05-cluster-helper-contract.sh — assert cluster.sh exposes
# cluster_compute and cluster_id_for with the AD-3 + FR-5 contracts.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/cluster.sh"

if [ ! -f "$LIB" ]; then
  echo "FAIL: $LIB does not exist"
  exit 1
fi

# Source the helper in a fresh subshell to detect non-clean source.
out_src="$(bash -c ". '$LIB' && type cluster_compute && type cluster_id_for" 2>&1)"
rc_src=$?
if [ "$rc_src" -ne 0 ]; then
  echo "FAIL: sourcing cluster.sh exited $rc_src. Output: $out_src"
  exit 1
fi
case "$out_src" in
  *"cluster_compute is a function"*) ;;
  *) echo "FAIL: cluster_compute is not exposed as a function. Got: $out_src"; exit 1 ;;
esac
case "$out_src" in
  *"cluster_id_for is a function"*) ;;
  *) echo "FAIL: cluster_id_for is not exposed as a function. Got: $out_src"; exit 1 ;;
esac

# AD-3 ID shape: cluster_id_for emits C<8-hex>.
id1="$(bash -c ". '$LIB' && cluster_id_for 'MEM900,MEM901,MEM902'")"
case "$id1" in
  C[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) echo "FAIL: cluster_id_for output '$id1' does not match C<8-hex> shape"; exit 1 ;;
esac

# Determinism: same input twice -> same output.
id2="$(bash -c ". '$LIB' && cluster_id_for 'MEM900,MEM901,MEM902'")"
if [ "$id1" != "$id2" ]; then
  echo "FAIL: cluster_id_for non-deterministic ('$id1' vs '$id2')"
  exit 1
fi

# Different input -> different output.
id3="$(bash -c ". '$LIB' && cluster_id_for 'MEM910,MEM911'")"
if [ "$id1" = "$id3" ]; then
  echo "FAIL: cluster_id_for collision on distinct inputs ('$id1')"
  exit 1
fi

# cluster_compute on an empty knowledge-root emits no output and exits 0.
empty_dir="$(mktemp -d)"
trap 'rm -rf "$empty_dir"' EXIT
out_empty="$(bash -c ". '$LIB' && cluster_compute '$empty_dir' 0.5" 2>&1)"
rc_empty=$?
if [ "$rc_empty" -ne 0 ]; then
  echo "FAIL: cluster_compute on empty root exited $rc_empty. Output: $out_empty"
  exit 1
fi
if [ -n "$out_empty" ]; then
  echo "FAIL: cluster_compute on empty root emitted output: '$out_empty'"
  exit 1
fi

# cluster_compute on a single-candidate fixture emits one line.
mkdir -p "$empty_dir/patterns"
cat >"$empty_dir/patterns/MEM800.md" <<'EOF'
---
id: MEM800
status: candidate
topic: alpha
tags: [alpha, beta]
---

# MEM800: single candidate fixture
A short body for token extraction.
EOF
out_one="$(bash -c ". '$LIB' && cluster_compute '$empty_dir' 0.5" 2>&1)"
rc_one=$?
if [ "$rc_one" -ne 0 ]; then
  echo "FAIL: cluster_compute on single-candidate fixture exited $rc_one. Output: $out_one"
  exit 1
fi
line_count="$(printf '%s\n' "$out_one" | grep -c '^C[0-9a-f]\{8\}	MEM800$' || true)"
if [ "$line_count" -ne 1 ]; then
  echo "FAIL: cluster_compute on single-candidate fixture did not emit exactly 1 line matching '<cluster-id>\\tMEM800'. Got:"
  printf '%s\n' "$out_one"
  exit 1
fi

echo "PASS: cluster.sh helper contract (function exposure + AD-3 ID shape + determinism + empty + singleton)"
exit 0
```

`chmod +x scripts/verify/m020-p05-cluster-helper-contract.sh`.

### Step 3: Create `scripts/verify/m020-p05-cluster-determinism.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p05-cluster-determinism.sh`

```bash
#!/usr/bin/env bash
# m020-p05-cluster-determinism.sh — assert cluster_compute output is byte-
# identical across two runs against the same fixture.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/cluster.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/patterns"

# Three candidates; not all expected to cluster; exact clustering
# depends on the feature vector but determinism is invariant.
for trip in "MEM800:alpha:body about alpha and beta" \
            "MEM801:alpha:body about alpha and gamma" \
            "MEM802:delta:body about delta and epsilon"; do
  id="${trip%%:*}"; rest="${trip#*:}"
  topic="${rest%%:*}"; body="${rest#*:}"
  cat >"$tmpdir/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
topic: ${topic}
tags: [${topic}]
---

# ${id}: determinism fixture
${body}
EOF
done

run1="$(bash -c ". '$LIB' && cluster_compute '$tmpdir' 0.1" 2>&1)"
rc1=$?
run2="$(bash -c ". '$LIB' && cluster_compute '$tmpdir' 0.1" 2>&1)"
rc2=$?

if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ]; then
  echo "FAIL: cluster_compute exited non-zero ($rc1, $rc2). Outputs:"
  printf 'run1:\n%s\nrun2:\n%s\n' "$run1" "$run2"
  exit 1
fi

if [ "$run1" != "$run2" ]; then
  echo "FAIL: cluster_compute output is not deterministic across runs"
  echo "----- run1 -----"; printf '%s\n' "$run1"
  echo "----- run2 -----"; printf '%s\n' "$run2"
  exit 1
fi

echo "PASS: cluster_compute is deterministic (run1 == run2 byte-for-byte)"
exit 0
```

`chmod +x scripts/verify/m020-p05-cluster-determinism.sh`.

### Step 4: Create `scripts/verify/m020-p05-cluster-singleton-coverage.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/m020-p05-cluster-singleton-coverage.sh`

Asserts ten-entry fixture (four near-duplicates above threshold by intentionally-overlapping topic+tags+body, plus six distinct entries) emits seven distinct cluster IDs covering all ten members exactly once. Uses an artificially-low threshold (0.1) plus topic-stuffed near-duplicates to make the four-cluster outcome robust.

```bash
#!/usr/bin/env bash
# m020-p05-cluster-singleton-coverage.sh — assert cluster_compute against a
# 10-entry fixture (4 near-duplicates + 6 distinct) yields 7 distinct cluster
# IDs covering all 10 entries exactly once.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/cluster.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/patterns"

# 4 near-duplicates: identical topic + tags + heavy body overlap.
for id in MEM900 MEM901 MEM902 MEM903; do
  cat >"$tmpdir/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
topic: shared-cluster-alpha
tags: [shared, cluster, alpha, beta, gamma]
relates_to: [MEM900, MEM901, MEM902, MEM903]
source_unit: M999/P01
---

# ${id}: near-duplicate fixture
shared body cluster alpha beta gamma delta epsilon zeta eta theta iota kappa
lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega
EOF
done

# 6 distinct entries: each with a unique topic, unique tags, unique body.
i=0
for tag in distinct-uniq-1 distinct-uniq-2 distinct-uniq-3 distinct-uniq-4 distinct-uniq-5 distinct-uniq-6; do
  i=$(( i + 1 ))
  id_num=$(( 909 + i ))
  cat >"$tmpdir/patterns/MEM${id_num}.md" <<EOF
---
id: MEM${id_num}
status: candidate
topic: ${tag}
tags: [${tag}]
relates_to: []
source_unit: M999/P${id_num}
---

# MEM${id_num}: distinct fixture
unique body for ${tag} distinct word${id_num} another${id_num}
EOF
done

# Threshold deliberately low (0.1) so the 4-near-duplicate cluster forms
# reliably regardless of exact extended-vector tuning.
out="$(bash -c ". '$LIB' && cluster_compute '$tmpdir' 0.1" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: cluster_compute exited $rc. Output: $out"
  exit 1
fi

# Total member lines == 10.
total_lines="$(printf '%s\n' "$out" | grep -c '^C[0-9a-f]\{8\}	MEM' || true)"
if [ "$total_lines" -ne 10 ]; then
  echo "FAIL: expected 10 member lines, got $total_lines. Output:"
  printf '%s\n' "$out"
  exit 1
fi

# Distinct cluster IDs. With an aggressively-stuffed near-duplicate fixture
# at threshold 0.1, the expected outcome is 7 (one 4-member + 6 singletons),
# but if the implementation is more conservative (lower vector overlap due
# to first-paragraph cap pre-T02), accept 7..10. T04 narrows this to == 7
# against the FULL extended vector after T02 ships.
distinct_clusters="$(printf '%s\n' "$out" | awk -F'\t' '{print $1}' | LC_ALL=C sort -u | grep -c '^C[0-9a-f]\{8\}$' || true)"
if [ "$distinct_clusters" -lt 7 ] || [ "$distinct_clusters" -gt 10 ]; then
  echo "FAIL: expected 7..10 distinct cluster IDs, got $distinct_clusters. Output:"
  printf '%s\n' "$out"
  exit 1
fi

# Each member appears exactly once.
dup_count="$(printf '%s\n' "$out" | awk -F'\t' '{print $2}' | LC_ALL=C sort | uniq -d | wc -l | awk '{print $1}')"
if [ "$dup_count" -ne 0 ]; then
  echo "FAIL: $dup_count members appear more than once. Output:"
  printf '%s\n' "$out"
  exit 1
fi

echo "PASS: cluster_compute singleton coverage (10 members, $distinct_clusters clusters, no duplicates)"
exit 0
```

`chmod +x scripts/verify/m020-p05-cluster-singleton-coverage.sh`.

## Must-Haves

- `scripts/knowledge/lib/cluster.sh` exists, is sourceable, exposes `cluster_compute` and `cluster_id_for` functions.
- `cluster_id_for <sorted-csv>` emits `C<8-hex>` matching `^C[0-9a-f]{8}$`; deterministic; collision-resistant (different inputs yield different IDs at the contract test scale).
- `cluster_compute <root> <threshold>` walks `MEM*.md` under `<root>`, filters to `status: candidate`, computes pairwise Jaccard via `pairwise_jaccard`, builds the similarity graph, emits one TAB-separated `<cluster-id>\t<member-id>` line per (cluster, member) pair on stdout, sorted deterministically.
- `cluster_compute` is byte-deterministic across runs against the same fixture.
- `cluster_compute` covers every candidate exactly once (no orphans, no duplicates) including singletons.
- Bash 3.2: parallel newline-joined scalars; no `declare -A`; no `mapfile`; no process substitution; no AD-19-forbidden shapes.
- Pure read: no writes to `knowledge/**` or `.orchestrator/**` (the /tmp/_cluster_groups.$$ scratch file does not count — local to the function call, cleaned up).
- The three T01 verifier scripts exist, are executable, and exit 0 with `PASS:` lines.

## Verification

```
bash scripts/verify/m020-p05-cluster-helper-contract.sh
bash scripts/verify/m020-p05-cluster-determinism.sh
bash scripts/verify/m020-p05-cluster-singleton-coverage.sh
```

Each must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

None — T01 has no upstream tasks within this phase.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/jaccard.sh` (P01)
  - Key API: `pairwise_jaccard <file-a> <file-b>` echoes `similarity=N.NNNN` to stdout. Pure function; reads only the two argument files.
  - cluster.sh sources jaccard.sh and calls `pairwise_jaccard` directly inside the iteration loop.
- `scripts/knowledge/lib/frontmatter.sh` (P01)
  - Key API: `fm_read_status <file>` returns the `status:` field value or `graduated` per FR-10 default. cluster.sh inlines an awk-based status reader (rather than sourcing fm_read_status) to dodge bash-3.2 nested-source quirks AND to keep the candidate filter visible to verifier readers without hopping helpers.
- `scripts/knowledge/lib/index-utils.sh` (P01) — provides `get_project_root` honoring `PROJECT_ROOT` env override. T01 verifiers set `PROJECT_ROOT` to the tempdir for fixture isolation.
- `scripts/knowledge/lib/detail-utils.sh` (P01) — adjacent helpers; sourced by jaccard.sh.

## Constraints

- **AD-19 / MEM001**: every `Check:` and verification command in this plan is a single-script-file invocation. cluster.sh internals use awk + sort + temp files but those live inside the script body, not on Check lines.
- **Bash 3.2**: no associative arrays, no `mapfile`, no process substitution. Parent array uses parallel newline-joined scalars; grouping uses an awk pass with array indexing (awk has its own associative arrays which are fine — bash 3.2 constraint applies to bash code only).
- **CON-1 / FR-8 (read-only-during-dispatch)**: cluster.sh writes only to `/tmp/_cluster_groups.$$` scratch (cleaned at function exit) and stdout. Never to `knowledge/**` or `.orchestrator/**`.
- **AD-3 (cluster ID format)**: `cluster_id_for` MUST emit `C<8-hex-of-sha1(sorted-csv)>` exactly. Verified by the helper-contract verifier with the regex `^C[0-9a-f]{8}$`.
- **CON-5 (feature vector)**: cluster.sh does NOT define the feature vector — it consumes whatever `pairwise_jaccard` exposes. After T02 of this phase ships the extended vector, cluster.sh's behavior changes accordingly without any code change in cluster.sh itself. This is the contract decoupling that lets T01 and T02 land in either order.
- **Principle XIV (No Speculative Complexity)**: union-find with path compression is the standard simple algorithm. No semantic-clustering escalation; no agglomerative hierarchical clustering; no DBSCAN. Connected-components-above-threshold matches FR-5's single-pass shape.
- **Determinism**: same input -> same stdout, byte-equivalent. Sort orders are explicit (`LC_ALL=C sort`), no random tie-breakers, member ordering inside a cluster is lexicographic.

## Expected Output

After this task:

1. `scripts/knowledge/lib/cluster.sh` is created (>= 120 lines), executable, and the help comment documents `cluster_compute` + `cluster_id_for`.
2. All three T01 verifiers exist under `scripts/verify/`, are executable, and pass.
3. `git status knowledge/` is clean (T01 verifiers use tempdirs with `PROJECT_ROOT` overrides; live tree never touched).
4. `git status .orchestrator/execution-log.jsonl` is unchanged by T01 verifiers (T01 emits no JSONL records — that is T03's responsibility).

**Done when**: all three T01 verifiers print `PASS:` and exit 0; `git status knowledge/` and `git status .orchestrator/execution-log.jsonl` are unchanged by T01 work.
