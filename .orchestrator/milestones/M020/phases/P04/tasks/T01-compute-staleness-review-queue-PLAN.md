---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M020"
name: "compute-staleness.sh extension — --review-queue mode (FR-4 cluster grouping + staleness flag)"
depends_on: []
---

## Prerequisites

- P01: `scripts/knowledge/lib/frontmatter.sh` exposes `fm_read_status <file>` (echoes the entry's `status:` value or `graduated` for pre-M020 fallback per FR-10) and `fm_field <file> <key>` (read-only field reader for first-frontmatter scalar values like `topic:`, `created_at:`, `last_verified:`).
- P01: `knowledge/conventions/MEM031.md` documents the closed enum `{candidate, graduated, archived}` and the FR-10 pre-M020 default-graduated semantics.
- P03: `scripts/knowledge/graduate.sh` writes `decision_history:` blocks; T01 does NOT consume those blocks (T01 reads the simpler `created_at:` / `last_verified:` scalar fields for age computation).
- P05: `scripts/knowledge/lib/cluster.sh` exposes `cluster_compute <knowledge-root> <similarity-threshold>` (walks the root, filters to `status: candidate`, emits TAB-separated `<cluster-id>\t<member-id>` lines on stdout sorted by cluster-id then member-id) and `cluster_id_for <sorted-csv>` (deterministic AD-3 `C<8-hex>` derivation). T01 consumes `cluster_compute` directly via subprocess invocation OR by sourcing the helper — sourcing is permitted because cluster.sh is sourceable (double-source-guard + no file-scope `set -e` issues; see P05/T01 SUMMARY).
- P05: `scripts/knowledge/lib/jaccard.sh` provides the pairwise similarity primitive consumed by `cluster_compute`. T01 does not call jaccard.sh directly.
- The legacy `scripts/knowledge/compute-staleness.sh` invocation shape (no flag, walks the index, prints the staleness report) is the on-main shape T01 must preserve byte-equivalent under CON-4.

## Description

Extend `scripts/knowledge/compute-staleness.sh` in place with a new `--review-queue` mode that emits one structured line per candidate cluster on stdout, gated at the top of the existing argument parser. The mode short-circuits before the legacy index walk so the legacy invocation pays no cost and exhibits no behavior delta.

**New mode contract** (single-line stdout per cluster, sorted by cluster_id ascending; trailing newline; `EMPTY` sentinel on empty queue):

```
cluster_id=<C8hex> topic=<topic-or-empty> count=<N> oldest_age=<days> stale=<true|false>
```

Where:

- `<C8hex>` = `C` + 8 hex chars per AD-3 (the cluster_id emitted by `cluster_compute`).
- `<topic-or-empty>` = the canonical (lexicographically-first) member's `topic:` frontmatter value, with whitespace collapsed to single spaces and any embedded space replaced with `_` (so the line can be parsed by `awk` on whitespace without ambiguity); empty string when the field is absent.
- `<N>` = integer count of cluster members.
- `<days>` = integer days since the canonical member's `created_at:` (with `last_verified:` fallback when `created_at:` is missing); both fields are `YYYY-MM-DD` per MEM013 + observed live-tree shape.
- `<true|false>` = `<days>` >= resolved staleness threshold.

**Resolved staleness threshold**:

1. Default: `14` (per OQ-1 in `M020-CONTEXT.md`).
2. Override: read `.orchestrator/preferences.yml::staleness_threshold` integer scalar if the file exists and the value parses as a positive integer; otherwise fall back to `14` and emit a single-line stderr diagnostic of the shape `WARN: malformed staleness_threshold='<raw>' — using default=14`. Preferences-file absent is silently the default (no diagnostic).
3. Out of scope for T01: the FR-6 multi-key precedence (project > user > default) lands in P06. T01 reads only `.orchestrator/preferences.yml` (project-level); user-level `~/.orchestrator/preferences.yml` is ignored. P06 will rewire compute-staleness.sh to consume `lib/preferences.sh` once that helper ships.

**Resolved similarity threshold for cluster_compute**:

1. Default: `0.7` (AD-5 default validated against the live tree in P01).
2. Override: read `.orchestrator/preferences.yml::similarity_threshold` decimal-scalar if present and parseable as a positive decimal in (0.0, 1.0); otherwise fall back to `0.7` (silent — no stderr diagnostic for the similarity threshold; this matches the P05 silent-fallback convention).

**Knowledge-root resolution**:

1. `--knowledge-root <path>` flag (preferred; required for fixture-based verification): used verbatim.
2. Default (no flag): `<repo-root>/knowledge` where `<repo-root>` is the script's `cd ../..` from `$(dirname "$0")`.

**EMPTY-queue contract**: when the candidate filter yields zero entries (regardless of whether `cluster_compute` itself runs), emit exactly the literal `EMPTY` on stdout (no trailing fields), exit 0.

Out of scope (deferred to T02 / T03 / T04):

- Status.sh integration (T02).
- Per-truth contract verifiers (T03).
- End-to-end SC-3 integration test (T04).
- The FR-6 multi-source preferences cascade (P06).

## Steps

### Step 1: Extend `scripts/knowledge/compute-staleness.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/knowledge/compute-staleness.sh`

The existing script (143 lines) has a `--archive-below` / `--min-hits` / `--dry-run` argument loop. Add `--review-queue` and `--knowledge-root <path>` flags, and short-circuit the new mode at the top of the script before the legacy index walk.

**Key insertion points** (relative to the existing file):

1. Below the existing `source "$SCRIPT_DIR/lib/staleness.sh"` line, add:

   ```bash
   # P04: review-queue mode helpers
   # shellcheck source=lib/frontmatter.sh
   source "$SCRIPT_DIR/lib/frontmatter.sh"
   # shellcheck source=lib/cluster.sh
   source "$SCRIPT_DIR/lib/cluster.sh"
   ```

2. In the argument-parser `case` block, add two new branches before the `*)` catch-all:

   ```bash
       --review-queue)
         review_queue_mode=true
         shift
         ;;
       --knowledge-root)
         knowledge_root="$2"
         shift 2
         ;;
   ```

3. Above the argument-parser, declare the two new variables alongside the existing defaults:

   ```bash
   review_queue_mode=false
   knowledge_root=""
   ```

4. After the argument loop and before the legacy `index_path="$(get_index_path)"` block, add the review-queue short-circuit:

   ```bash
   if [ "$review_queue_mode" = "true" ]; then
     _p04_review_queue_emit
     exit 0
   fi
   ```

5. Define `_p04_review_queue_emit` (and its three internal helpers) above the argument loop. The full helper body:

```bash
# --- P04 review-queue helpers (FR-4) ---

# Resolve project knowledge root (used when --knowledge-root not supplied).
_p04_default_knowledge_root() {
  local repo_root
  repo_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
  printf '%s\n' "$repo_root/knowledge"
}

# Read .orchestrator/preferences.yml::<key> as a single scalar; echoes empty
# string when the file or key is absent. Reads ONLY the project-level
# preferences file ($PWD/.orchestrator/preferences.yml). User-level cascade
# is deferred to P06.
_p04_read_pref_scalar() {
  local key="$1"
  local prefs_file=".orchestrator/preferences.yml"
  if [ ! -f "$prefs_file" ]; then
    printf '%s\n' ""
    return 0
  fi
  awk -v k="$key" '
    {
      pat = "^" k ":[[:space:]]"
      if ($0 ~ pat) {
        sub(pat, "")
        sub(/[[:space:]]+$/, "")
        sub(/^"/, ""); sub(/"$/, "")
        sub(/^'\''/, ""); sub(/'\''$/, "")
        print
        exit
      }
    }
  ' "$prefs_file" 2>/dev/null || true
}

# Resolve staleness threshold (positive integer, default 14 per OQ-1).
# Malformed scalar -> stderr WARN + default.
_p04_resolve_staleness_threshold() {
  local raw
  raw="$(_p04_read_pref_scalar staleness_threshold)"
  if [ -z "$raw" ]; then
    printf '%s\n' "14"
    return 0
  fi
  case "$raw" in
    ''|*[!0-9]*)
      printf 'WARN: malformed staleness_threshold=%s — using default=14\n' "'$raw'" >&2
      printf '%s\n' "14"
      return 0
      ;;
  esac
  if [ "$raw" -le 0 ]; then
    printf 'WARN: malformed staleness_threshold=%s — using default=14\n' "'$raw'" >&2
    printf '%s\n' "14"
    return 0
  fi
  printf '%s\n' "$raw"
}

# Resolve similarity threshold (positive decimal in (0,1), default 0.7).
# Malformed scalar -> silent default (P05 convention).
_p04_resolve_similarity_threshold() {
  local raw
  raw="$(_p04_read_pref_scalar similarity_threshold)"
  if [ -z "$raw" ]; then
    printf '%s\n' "0.7"
    return 0
  fi
  # Accept N.N or 0.N or .N forms. Reject anything else.
  case "$raw" in
    [0-9].[0-9]*|[0-9]|.[0-9]*) printf '%s\n' "$raw" ;;
    *) printf '%s\n' "0.7" ;;
  esac
}

# Read first non-empty value across the listed keys for a given file.
_p04_first_field() {
  local file="$1"
  shift
  local key val
  for key in "$@"; do
    val="$(fm_field "$file" "$key" 2>/dev/null || true)"
    if [ -n "$val" ]; then
      printf '%s\n' "$val"
      return 0
    fi
  done
  printf '%s\n' ""
}

# Emit the review-queue lines (one per cluster) on stdout, or EMPTY on empty.
_p04_review_queue_emit() {
  local k_root="$knowledge_root"
  if [ -z "$k_root" ]; then
    k_root="$(_p04_default_knowledge_root)"
  fi
  if [ ! -d "$k_root" ]; then
    printf 'WARN: knowledge root not found: %s\n' "$k_root" >&2
    printf '%s\n' "EMPTY"
    return 0
  fi

  local sim_threshold stale_threshold
  sim_threshold="$(_p04_resolve_similarity_threshold)"
  stale_threshold="$(_p04_resolve_staleness_threshold)"

  # cluster_compute emits TAB-separated <cluster-id>\t<member-file-basename>
  # OR <cluster-id>\t<member-id>; per P05/T01 SUMMARY the second token is the
  # member-id (e.g. MEM900) extracted from the entry's frontmatter id: field.
  # Capture into a tempfile so we can iterate without subshell scope issues.
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  local cluster_lines="$tmpdir/clusters.tsv"
  cluster_compute "$k_root" "$sim_threshold" >"$cluster_lines" 2>/dev/null || true

  if [ ! -s "$cluster_lines" ]; then
    printf '%s\n' "EMPTY"
    return 0
  fi

  # Build a member-id -> file-path map for the candidate-filtered tree.
  # We re-walk the tree once to materialise the lookup (cluster_compute
  # already filtered to status: candidate; we only need to map id -> file).
  local id_path_map="$tmpdir/id_paths.tsv"
  : >"$id_path_map"
  local f mid
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    local s
    s="$(fm_read_status "$f" 2>/dev/null || printf '%s\n' "graduated")"
    [ "$s" = "candidate" ] || continue
    mid="$(fm_field "$f" id 2>/dev/null || true)"
    if [ -z "$mid" ]; then
      mid="$(basename "$f" .md)"
    fi
    printf '%s\t%s\n' "$mid" "$f" >>"$id_path_map"
  done < <(find "$k_root" -type f -name 'MEM*.md' 2>/dev/null | sort)

  # Today reference date.
  local today
  today="$(date -u +%Y-%m-%d)"

  # Group cluster_lines by cluster-id, sort by cluster-id, emit one line each.
  local current_cid="" canonical_id="" canonical_file="" count=0
  local _flush_pending=0

  _flush_one() {
    local cid="$1" can_file="$2" cnt="$3"
    if [ -z "$cid" ] || [ -z "$can_file" ] || [ "$cnt" -eq 0 ]; then
      return 0
    fi
    local topic age stale created
    topic="$(fm_field "$can_file" topic 2>/dev/null || true)"
    if [ -z "$topic" ]; then
      topic=""
    else
      # Collapse whitespace to single underscore so awk-on-whitespace parses ok.
      topic="$(printf '%s' "$topic" | tr -s '[:space:]' '_' )"
    fi
    created="$(_p04_first_field "$can_file" created_at last_verified)"
    if [ -z "$created" ]; then
      age=0
    else
      age="$(days_since "$created" "$today" 2>/dev/null || printf '%s\n' "0")"
    fi
    if [ "$age" -ge "$stale_threshold" ]; then
      stale="true"
    else
      stale="false"
    fi
    printf 'cluster_id=%s topic=%s count=%s oldest_age=%s stale=%s\n' \
      "$cid" "$topic" "$cnt" "$age" "$stale"
  }

  # cluster_compute output is already sorted by cluster-id; iterate streaming.
  local cid mid_local file_path
  while IFS=$'\t' read -r cid mid_local; do
    [ -n "$cid" ] || continue
    if [ "$cid" != "$current_cid" ]; then
      # Flush the previous cluster.
      _flush_one "$current_cid" "$canonical_file" "$count"
      # Reset.
      current_cid="$cid"
      canonical_id="$mid_local"
      file_path="$(awk -F '\t' -v id="$mid_local" '$1==id{print $2; exit}' "$id_path_map")"
      canonical_file="$file_path"
      count=1
    else
      count=$(( count + 1 ))
      # Lexicographically-smallest member-id is canonical; cluster_compute
      # already sorts members within a cluster ascending by member-id, so
      # the first member encountered is canonical.
    fi
  done <"$cluster_lines"

  # Flush the last cluster.
  _flush_one "$current_cid" "$canonical_file" "$count"
}
```

> **Implementation note — process substitution**: the inline `done < <(find ...)` is permitted *inside* the script body. AD-19's shape-guard inspects directly-invoked Bash tool-call shapes (the truth Check command line), not script internals. P03/T04 SUMMARY explicitly carries this lesson forward.

> **Implementation note — `cluster_compute` output shape**: per `scripts/knowledge/lib/cluster.sh` lines 7-12 the helper emits `<cluster-id>\t<member-id>` lines sorted by cluster-id ascending then member-id ascending. T01 trusts this contract; the canonical (lexicographically-first) member is the first member encountered for each cluster.

> **Bash 3.2 / portability**: every helper uses `local`, plain indexed scalars, and `awk`/`printf`/`sed`. No associative arrays, no `mapfile`, no `<<<` here-strings inside `$()`. The `_flush_one` inner function is a plain function (not a closure or process substitution).

### Step 2: chmod + smoke

```
chmod +x scripts/knowledge/compute-staleness.sh
```

The legacy invocation `bash scripts/knowledge/compute-staleness.sh` (no flags) MUST continue to emit the staleness-report header line `STALENESS REPORT (as of <YYYY-MM-DD>)` byte-equivalent (CON-4). Quick smoke (advisory; the gate is the verifier in T03):

```
bash scripts/knowledge/compute-staleness.sh | head -1
```

Expected stdout first line: `STALENESS REPORT (as of <YYYY-MM-DD>)`.

The new invocation against the live tree:

```
bash scripts/knowledge/compute-staleness.sh --review-queue
```

Expected exit 0. Stdout: zero or more `cluster_id=<C8hex> ...` lines OR the literal `EMPTY` (the live tree has no candidates as of P03 close — observed `EMPTY`).

## Must-Haves

- `scripts/knowledge/compute-staleness.sh` accepts `--review-queue` and `--knowledge-root <path>` flags without breaking the legacy `--archive-below` / `--min-hits` / `--dry-run` / no-flag invocation shapes.
- `--review-queue` walks `<knowledge-root>/**/MEM*.md`, filters to `status: candidate`, groups via `cluster_compute`, and emits one structured line per cluster on stdout in the documented shape (`cluster_id=...`).
- Empty candidate set emits exactly `EMPTY` on stdout, exit 0.
- Staleness threshold resolves: default 14 → preferences `staleness_threshold:` if integer-positive → malformed warns to stderr + default 14. Preferences-file absent is silent default.
- Similarity threshold resolves: default 0.7 → preferences `similarity_threshold:` if N.N parseable → malformed silent default 0.7.
- Topic field is whitespace-collapsed (spaces → underscores) so the output line is awk-on-whitespace parseable.
- Age computation uses `created_at:` then falls back to `last_verified:` then defaults to age 0.
- Bash 3.2, AD-19, MEM001 conventions throughout (no `declare -A`, no `mapfile`, no `<<<`-into-`$()`, no inline compound bash on Check command lines — all heavy logic lives inside script bodies, single-script-file invocation shape on every Check).
- Read-only against `knowledge/**` and against `.orchestrator/execution-log.jsonl`. T01 writes ONLY to its own tempdir (which is cleaned by trap-EXIT-rm-rf) and to stdout/stderr.

## Verification

```
bash scripts/verify/m020-p04-compute-staleness-review-queue.sh
```

Must print a `PASS:` line and exit 0. (This verifier is shipped by T03 and asserts the cluster_id-line stdout shape, the EMPTY-on-empty contract, and the legacy-shape preservation.) T01 does not author this verifier itself; T01's local verification is the script behavior under the SC-3-style fixture exercised by T04 (also shipped later). T01-local advisory smoke:

```
bash scripts/knowledge/compute-staleness.sh --review-queue
```

(Exit 0; stdout `EMPTY` against the live tree.)

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/frontmatter.sh` (M020/P01)
  - Key API: `fm_read_status <file>` echoes the frontmatter `status:` value with FR-10 pre-M020 default of `graduated`; `fm_field <file> <key>` echoes the first scalar value for the given key (single-line values; trims surrounding quotes/whitespace). Both are pure read; never mutate.
  - Behavior contract: pre-M020 entries (no `status:` field) -> `fm_read_status` echoes `graduated` (so they are EXCLUDED from the candidate filter). Cluster.sh likewise excludes them.

- `scripts/knowledge/lib/cluster.sh` (M020/P05)
  - Key API: `cluster_compute <knowledge-root> <similarity-threshold>` emits TAB-separated `<cluster-id>\t<member-id>` lines on stdout, sorted by `<cluster-id>` ascending then `<member-id>` ascending. Singletons are emitted as one-member clusters. Pure read — no `knowledge/**` or `.orchestrator/**` mutations.
  - Schema dependency: filters to `status: candidate` per MEM031; pre-M020 entries default-graduated and are EXCLUDED.
  - Sourcing safety: cluster.sh has a `_CLUSTER_HELPER_SOURCED` double-source guard and is sourceable from another helper.

- `scripts/knowledge/lib/staleness.sh` (M001 / M020 baseline)
  - Key API: `days_since <YYYY-MM-DD> [<reference-YYYY-MM-DD>]` echoes integer days between the two dates; portable across macOS BSD `date -j -f` and GNU `date -d`. Already sourced by the legacy `compute-staleness.sh`.

### From Disk (Pre-existing)

- `scripts/knowledge/compute-staleness.sh` — the existing 143-line script T01 modifies in place. Preserve every existing line of the legacy index walk, the `STALENESS REPORT (as of ...)` header, the percent-sign printf format, and the per-entry `printf "%-8s ...` table. The additive changes are the two new variables (`review_queue_mode`, `knowledge_root`), the two new `case` branches, the helper-function block, and the short-circuit `if`.
- `.orchestrator/preferences.yml` (operator-owned, may not exist) — the project-level preferences file. T01 reads only the `staleness_threshold:` and `similarity_threshold:` scalar keys; absence of the file is silent default.
- `knowledge/conventions/MEM031.md` — schema authority for the closed enum; T01 does not modify this file.

## Constraints

- **AD-19 / MEM001**: every Truth Check in the phase plan is a single-script-file invocation. The helper functions inside compute-staleness.sh use process-substitution and pipe constructions; that is permitted (P03/T04 carry-forward) because the harness shape-guard inspects only directly-invoked Bash tool-call shapes, not script internals.
- **Bash 3.2**: no associative arrays, no `mapfile`, no `<<<` here-strings inside command-substitution-with-pipes. Awk handles all multi-key extraction.
- **CON-1 / FR-8 (read-only-during-dispatch)**: T01 reads `knowledge/**` and `.orchestrator/preferences.yml`; never writes to either. Tempdir writes are scoped to `mktemp -d` + `trap RETURN rm -rf`.
- **CON-4 (Surgical Precision)**: legacy compute-staleness.sh invocations (no flag, `--archive-below`, `--min-hits`, `--dry-run`) MUST continue to emit byte-identical output. The only adds are: two variable defaults, two `case` branches, one short-circuit `if`, and one helper block. No existing line is rewritten.
- **Principle XIV (No Speculative Complexity)**: T01 ships only the FR-4 review-queue contract. No FR-6 user-level preferences cascade. No JSONL emission. No cluster-conflict detection (P05's job). No graduate.sh integration. No new schema fields.
- **Principle VII (Knowledge Compounds)**: T01 reads the P03 / P05 / P01 helpers verbatim. Zero copy-paste of clustering or frontmatter logic.
- **No jq hard dependency**: T01's helpers emit plain `key=value` stdout; jq is not invoked.

## Expected Output

After this task:

1. `scripts/knowledge/compute-staleness.sh` accepts `--review-queue` and `--knowledge-root <path>` and short-circuits the new mode at the top of the script.
2. `bash scripts/knowledge/compute-staleness.sh` (no flag) emits the legacy `STALENESS REPORT (as of <date>)` table byte-equivalent to pre-P04 main.
3. `bash scripts/knowledge/compute-staleness.sh --review-queue` exits 0; stdout is either `EMPTY` (no candidates) or one `cluster_id=...` line per cluster sorted by cluster_id ascending.
4. `bash scripts/knowledge/compute-staleness.sh --review-queue --knowledge-root <fixture>` walks the fixture, not the repo's live `knowledge/`.
5. No file under `knowledge/**` is touched by T01.
6. `git status knowledge/` is unchanged by running T01 against the live tree.

**Done when**: the legacy invocation continues to print the staleness report; `--review-queue` against an empty fixture prints `EMPTY`; `--review-queue` against a fixture with at least one candidate prints a `cluster_id=` line; both invocations exit 0.
