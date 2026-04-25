---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M020"
name: "status.sh Review-Queue section (FR-4 rendering)"
depends_on: ["T01"]
---

## Prerequisites

- T01: `scripts/knowledge/compute-staleness.sh --review-queue [--knowledge-root <path>]` accepts the `--review-queue` flag and emits structured stdout — either the literal `EMPTY` (no candidates) or one `cluster_id=<C8hex> topic=<topic-or-empty> count=<N> oldest_age=<days> stale=<true|false>` line per cluster, sorted by cluster_id ascending. Exit code 0 in both cases.
- The on-main `scripts/orchestrator/status.sh` (100 lines) emits `MILESTONE: <ID>`, `STATE: <state>`, and per-phase `PHASE: <P##> <state>` lines for every milestone under the resolved root. T02 must preserve these lines byte-equivalent (CON-4) and append the Review-Queue section after the last `PHASE:` line of the last milestone enumerated.
- `scripts/state/resolve-root.sh` resolves the orchestrator state root via the documented 4-rule precedence (env → config → `.orchestrator/` → default).

## Description

Extend `scripts/orchestrator/status.sh` in place to emit a `Review Queue:` section after the existing milestone/phase enumeration. The section is rendered from T01's `compute-staleness.sh --review-queue` output and conforms to the FR-4 contract:

**Empty queue rendering** (T01 emitted `EMPTY`):

```
Review Queue: empty
```

(Exactly one line, no per-cluster lines.)

**Non-empty queue rendering** (T01 emitted one or more `cluster_id=...` lines):

```
Review Queue: <N> clusters, <M> entries awaiting review
  cluster=<C8hex> topic=<topic> count=<N> oldest_age=<days>d
  cluster=<C8hex> topic=<topic> count=<N> oldest_age=<days>d (stale)
  ...
```

Where:

- `<N>` = number of distinct cluster_ids in T01's output (counted line-by-line).
- `<M>` = sum of `count=` values across T01's lines.
- Per-cluster summary lines are two-space-indented (`  ` literal at start of line).
- `<topic>` = the value of T01's `topic=` field for that cluster. Render as-is (T01 already collapsed whitespace to underscores, so the rendered topic is single-token; downstream callers can replace `_` with space for human display, but T02 emits the underscore form so the line stays awk-on-whitespace parseable).
- `<days>d` = the value of T01's `oldest_age=` field with a literal `d` suffix.
- ` (stale)` (parenthesised, lowercase, single-space-separated) is appended at end-of-line iff T01's `stale=` field for that cluster was `true`. Non-stale clusters do NOT carry the marker.

**Failure-tolerant rendering**: if T01 exits non-zero, hangs (timeout-bounded; see "Timeout" below), or emits stdout that does not match either the `EMPTY` sentinel or one-or-more well-formed `cluster_id=...` lines, status.sh emits exactly:

```
Review Queue: unavailable
```

…and continues (does not exit non-zero on the parent `status.sh` invocation; a single-line stderr diagnostic naming the cause is emitted).

**Timeout**: T02 invokes T01 via subprocess with a 5-second wall-clock budget (defensive — clustering against a large knowledge tree should complete in <1s but the timeout is the unattended-loop guard). If `command -v timeout` is available, wrap the invocation; otherwise invoke directly (Bash 3.2 / macOS lacks `timeout` by default — degrade gracefully).

**Read-only invariant** (FR-8 / CON-1): status.sh must not write to `knowledge/**`, must not append to `.orchestrator/execution-log.jsonl`, and must not modify `.orchestrator/preferences.yml`.

**Surface preservation** (CON-4): the existing `MILESTONE:`, `STATE:`, `PHASE:` lines remain byte-equivalent. The Review-Queue section is strictly appended.

Out of scope (deferred):

- Per-cluster member-id enumeration (one-line summary per cluster is the FR-4 contract; the operator drills down via `query.sh --topic <X>` or by reading `knowledge/`).
- T03 contract verifiers.
- T04 SC-3 integration test.

## Steps

### Step 1: Edit `scripts/orchestrator/status.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/orchestrator/status.sh`

The on-main script ends after the milestone-loop (line 99). Append the Review-Queue rendering function and its invocation after the loop. The full diff:

1. Above the milestone-loop (alongside the existing root-resolution / milestone enumeration), add the helper function `_p04_render_review_queue` (or a similar name, scoped with a P04 prefix to avoid collisions). Function body:

```bash
# --- P04: Review-Queue section (FR-4) ---
# Renders the Review Queue: section by invoking
# scripts/knowledge/compute-staleness.sh --review-queue and parsing its
# structured stdout. Failure-tolerant: any error path emits the
# `Review Queue: unavailable` fallback and a one-line stderr diagnostic.
_p04_render_review_queue() {
  local repo_root="$REPO_ROOT"
  local helper="$repo_root/scripts/knowledge/compute-staleness.sh"
  if [ ! -x "$helper" ] && [ ! -f "$helper" ]; then
    echo "Review Queue: unavailable"
    echo "P04 review-queue: helper not found at $helper" >&2
    return 0
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  local out_file="$tmpdir/review-queue.out"
  local err_file="$tmpdir/review-queue.err"

  # Wall-clock-bounded invocation. macOS may lack `timeout`; if so, run direct.
  local rc=0
  if command -v timeout >/dev/null 2>&1; then
    timeout 5 bash "$helper" --review-queue >"$out_file" 2>"$err_file" || rc=$?
  else
    bash "$helper" --review-queue >"$out_file" 2>"$err_file" || rc=$?
  fi

  if [ "$rc" -ne 0 ]; then
    echo "Review Queue: unavailable"
    echo "P04 review-queue: helper exited rc=$rc; stderr: $(head -1 "$err_file" 2>/dev/null || true)" >&2
    return 0
  fi

  # Empty-queue path.
  if [ "$(head -1 "$out_file" 2>/dev/null || true)" = "EMPTY" ]; then
    echo "Review Queue: empty"
    return 0
  fi

  # Parse cluster lines: count clusters, sum counts. Reject empty output.
  local n_clusters=0 n_entries=0 line
  if [ ! -s "$out_file" ]; then
    echo "Review Queue: unavailable"
    echo "P04 review-queue: helper emitted empty output" >&2
    return 0
  fi

  # First pass: validate every line is well-formed and tally totals.
  local cnt
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      cluster_id=*\ topic=*\ count=*\ oldest_age=*\ stale=*) ;;
      *)
        echo "Review Queue: unavailable"
        echo "P04 review-queue: malformed helper line: $line" >&2
        return 0
        ;;
    esac
    cnt="$(printf '%s\n' "$line" | awk '{
      for (i=1;i<=NF;i++) {
        if ($i ~ /^count=/) { sub(/^count=/, "", $i); print $i; exit }
      }
    }')"
    case "$cnt" in
      ''|*[!0-9]*)
        echo "Review Queue: unavailable"
        echo "P04 review-queue: non-integer count on line: $line" >&2
        return 0
        ;;
    esac
    n_clusters=$(( n_clusters + 1 ))
    n_entries=$(( n_entries + cnt ))
  done <"$out_file"

  # Second pass: render header + per-cluster lines.
  printf 'Review Queue: %d clusters, %d entries awaiting review\n' \
    "$n_clusters" "$n_entries"
  local cid topic count age stale stale_marker
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    cid="$(printf '%s\n' "$line"   | awk '{for(i=1;i<=NF;i++)if($i~/^cluster_id=/){sub(/^cluster_id=/,"",$i);print $i;exit}}')"
    topic="$(printf '%s\n' "$line" | awk '{for(i=1;i<=NF;i++)if($i~/^topic=/){sub(/^topic=/,"",$i);print $i;exit}}')"
    count="$(printf '%s\n' "$line" | awk '{for(i=1;i<=NF;i++)if($i~/^count=/){sub(/^count=/,"",$i);print $i;exit}}')"
    age="$(printf '%s\n' "$line"   | awk '{for(i=1;i<=NF;i++)if($i~/^oldest_age=/){sub(/^oldest_age=/,"",$i);print $i;exit}}')"
    stale="$(printf '%s\n' "$line" | awk '{for(i=1;i<=NF;i++)if($i~/^stale=/){sub(/^stale=/,"",$i);print $i;exit}}')"
    stale_marker=""
    if [ "$stale" = "true" ]; then
      stale_marker=" (stale)"
    fi
    printf '  cluster=%s topic=%s count=%s oldest_age=%sd%s\n' \
      "$cid" "$topic" "$count" "$age" "$stale_marker"
  done <"$out_file"
}
```

2. After the milestone-loop's closing `done`, invoke the renderer once:

```bash
# --- P04: Review-Queue section (FR-4) ---
_p04_render_review_queue
```

(Single invocation. The Review-Queue section is global per `status.sh` invocation, not per-milestone — the queue lives at `<repo>/knowledge/`, not under a specific milestone.)

3. Confirm `REPO_ROOT` is in scope at the call-site. The on-main script defines `REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"` at line 28; the helper function references it directly. (Not exported — that is fine; Bash function scope sees the parent shell's variables.)

> **Implementation note — `mktemp` on macOS**: BSD `mktemp -d` requires no template by default; both BSD and GNU support `mktemp -d`. Plain `mktemp -d` is portable.

> **Implementation note — `trap RETURN`**: this is bash-builtin (NOT POSIX) and is what we want here so each function call has its own cleanup. Bash 3.2 supports `trap '...' RETURN`.

> **Implementation note — process substitution / heredocs**: NOT used in the directly-invoked Check command. The renderer reads from a tempfile (`<"$out_file"`) which is plain input redirection, AD-19 safe inside script bodies (and harmless even at Check shape since it's inside the script).

### Step 2: Smoke-test against the live tree

```
bash scripts/orchestrator/status.sh
```

Expected stdout tail:

```
...
PHASE: P05 complete
Review Queue: empty
```

(The live tree currently has no candidates; T01's `--review-queue` returns `EMPTY`, and T02 renders `Review Queue: empty`.)

## Must-Haves

- `scripts/orchestrator/status.sh` invokes `bash scripts/knowledge/compute-staleness.sh --review-queue` after the existing milestone enumeration.
- Empty queue (T01 stdout = `EMPTY`) renders the single line `Review Queue: empty`.
- Non-empty queue (T01 stdout = one-or-more `cluster_id=...` lines) renders a header line `Review Queue: <N> clusters, <M> entries awaiting review` followed by one indented `  cluster=<C8hex> topic=<topic> count=<N> oldest_age=<days>d` line per cluster, with ` (stale)` appended on stale lines.
- Failure-tolerant: T01 helper missing, non-zero exit, malformed output, or non-integer count → `Review Queue: unavailable` + one-line stderr diagnostic; status.sh exits 0 regardless.
- Pre-P04 `MILESTONE:` / `STATE:` / `PHASE:` lines remain byte-equivalent to on-main output for any given root.
- Read-only: status.sh writes nothing to `knowledge/**` and appends nothing to `.orchestrator/execution-log.jsonl`. Tempdirs are cleaned via `trap RETURN rm -rf`.
- Bash 3.2, AD-19, MEM001 conventions throughout.

## Verification

```
bash scripts/verify/m020-p04-status-review-queue-section.sh
bash scripts/verify/m020-p04-status-stale-marker.sh
bash scripts/verify/m020-p04-status-review-queue-readonly.sh
bash scripts/verify/m020-p04-status-prefix-preserved.sh
```

All four must print `PASS:` and exit 0. (These verifiers are shipped by T03; T02 does not author them. T02's local advisory smoke is the live-tree invocation in Step 2.)

## Inputs

### From Previous Tasks

- `scripts/knowledge/compute-staleness.sh` (M020/P04/T01)
  - Key API: `--review-queue [--knowledge-root <path>]` mode emits to stdout either the literal `EMPTY` (no candidates) or one line per cluster of the form `cluster_id=<C8hex> topic=<topic-or-empty> count=<N> oldest_age=<days> stale=<true|false>`. Exit 0 in both cases. Stderr may contain a `WARN:` line if `staleness_threshold:` is malformed; T02 ignores stderr for parsing purposes.
  - Behavioral contract: lines are sorted by `<cluster-id>` ascending. The `topic=` field is whitespace-collapsed (spaces → underscores) so the line is awk-on-whitespace parseable.

### From Disk (Pre-existing)

- `scripts/orchestrator/status.sh` (the 100-line on-main script T02 modifies in place). Preserve the four output line-shapes byte-equivalent: `MILESTONE: <ID>`, `STATE: <state>`, `PHASE: <P##> <state>`, and the per-help comment block. The additive changes are the `_p04_render_review_queue` helper function and one invocation line after the milestone-loop.
- `scripts/state/resolve-root.sh` (the existing root resolver). T02 does not modify this; it inherits `resolved_root` and `REPO_ROOT` from the surrounding script body.

## Constraints

- **AD-19 / MEM001**: every Truth Check in the phase plan is a single-script-file invocation. T02's helper function uses pipes and `awk` inside the script body — that is permitted (P03/T04 carry-forward). No Check command line uses inline compound bash.
- **Bash 3.2**: no associative arrays, no `mapfile`, no `<<<` here-strings inside `$()`. The renderer uses plain `while IFS= read` over a tempfile; the awk-extraction is one-liners with simple `for (i=1;i<=NF;i++)` loops (BSD-awk and gawk compatible).
- **CON-1 / FR-8 (read-only-during-dispatch)**: status.sh writes nothing to `knowledge/**` or `.orchestrator/execution-log.jsonl`. Tempdir is cleaned via `trap RETURN rm -rf`.
- **CON-4 (Surgical Precision)**: existing `MILESTONE:`, `STATE:`, `PHASE:` lines preserved byte-equivalent. The Review-Queue section is strictly appended.
- **Principle XIV (No Speculative Complexity)**: T02 ships only the FR-4 rendering contract. No per-cluster member-enumeration. No JSONL emission. No drill-down menu.
- **No jq hard dependency**: T02 parses with awk + case-glob.
- **Failure tolerance**: T02 must NEVER propagate a T01 failure into the parent `status.sh` exit code — the existing `MILESTONE:` / `PHASE:` enumeration is the load-bearing contract for status.sh and must continue to ship even when the review-queue renderer can't.

## Expected Output

After this task:

1. `bash scripts/orchestrator/status.sh` (against any milestone-bearing root) emits the existing `MILESTONE:` / `STATE:` / `PHASE:` lines unchanged, followed by either `Review Queue: empty`, `Review Queue: <N> clusters, <M> entries awaiting review` + indented per-cluster lines, or `Review Queue: unavailable`.
2. The pre-P04 prefix lines are byte-equivalent to on-main output for the same root.
3. No file under `knowledge/**` or `.orchestrator/execution-log.jsonl` is touched by T02 invocations.
4. Helper failures (missing helper, non-zero exit, malformed output) emit `Review Queue: unavailable` plus a one-line stderr diagnostic; the parent `status.sh` exits 0.

**Done when**: a live-tree invocation of `bash scripts/orchestrator/status.sh` emits `Review Queue: empty` after the last `PHASE:` line, and the legacy `MILESTONE:` / `STATE:` / `PHASE:` lines remain byte-equivalent.
