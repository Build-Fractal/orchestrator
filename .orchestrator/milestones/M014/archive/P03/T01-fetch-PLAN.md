---
schema_version: "1.0"
task: "T01"
phase: "P03"
milestone: "M014"
name: "Comment fetcher + idempotency log (FR-8, CON-8)"
depends_on: []
---

## Prerequisites

- M013 has shipped — `scripts/integrations/github-common.sh` exists with `gh` invocation helpers and orchestrator-id-marker conventions. T01 reads from this file's contract; it does not modify it.
- M012 has shipped — `scripts/wiki/wiki-giscus-remap.sh` provides Discussion → spec-chunk pathname-keyed thread mapping. T01 consumes via shellout.
- `gh` CLI is operator-installed and authenticated when this script runs against the live repo. Verifier exercises hermetic stub path (PATH-prefixed `gh` shim under scratch) — never invokes the real `gh` binary.
- `.orchestrator/comments/` directory does not yet exist; T01 creates it on first run.

## Description

T01 ships `scripts/comments/fetch.sh` — the comment fetcher (FR-8). Behavior:

1. Enumerate unactioned comments from two surfaces:
   - **Giscus Discussions** on the wiki: `gh api graphql` query against the M012-shipped Discussions category, filtered to comment-bearing threads keyed to spec-chunk pathnames.
   - **GitHub Issue/PR comments**: `gh api repos/<owner>/<repo>/issues/comments` (and `/pulls/comments`) for orchestrator-id-marker-bearing Issue/PR threads.
2. For each fetched comment, compute the idempotency key as `URL || shasum(body)` (URL is the canonical part; body shasum is a fallback when URL fragments collide).
3. Skip any comment whose URL is already present in `.orchestrator/comments/actioned.jsonl` (one JSONL row per actioned comment with `comment_url`, `actioned_at`, `class`, `applied`).
4. Cache each new comment to `.orchestrator/comments/inbox/<comment-id>.json` with fields `{url, body, source_surface, fetched_at, body_shasum, anchor_chunk_id (optional)}`.
5. Support `--dry-run`: print FR-19 JSONL action records to stdout (one per comment that would be cached) without disk writes.
6. Support `--yes`: auto-resolve any interactive prompt to the conservative default (none planned in T01; the flag is honored as inheritance from CON-3).
7. Emit a `unit_close` JSONL record at exit with `{command: "comments fetch", comments_fetched: N, comments_skipped: M, source_surfaces: ["giscus","github"], elapsed_ms, source: "runtime"}`.

The fetcher does NOT classify, queue, or apply — it is a pure cache primer.

## Steps

1. **Create `scripts/comments/fetch.sh`** with this skeleton (Bash 3.2, AD-19-compliant, no inline compounds beyond `&&`/`||` of two commands):

   ```bash
   #!/usr/bin/env bash
   # scripts/comments/fetch.sh
   # FR-8 comment fetcher — Giscus + GitHub Issue/PR.
   # Bash 3.2 compatible. CON-8 idempotent via actioned.jsonl.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="${ORCHESTRATOR_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
   ORCH_ROOT="${PROJECT_ROOT}/.orchestrator"
   INBOX_DIR="${ORCH_ROOT}/comments/inbox"
   ACTIONED_LOG="${ORCH_ROOT}/comments/actioned.jsonl"
   EXEC_LOG="${ORCH_ROOT}/execution-log.jsonl"

   DRY_RUN=0
   YES=0
   while [ $# -gt 0 ]; do
     case "$1" in
       --dry-run) DRY_RUN=1 ;;
       --yes) YES=1 ;;
       --help|-h) sed -n '2,15p' "$0"; exit 0 ;;
       *) printf 'FAIL: unknown arg %s\n' "$1" >&2; exit 2 ;;
     esac
     shift
   done

   mkdir -p "$INBOX_DIR"
   touch "$ACTIONED_LOG"

   _start_ms="$(date +%s)"
   _fetched=0
   _skipped=0

   # ... see Step 2 for surface-specific fetchers ...

   _elapsed_ms=$(( ( $(date +%s) - _start_ms ) * 1000 ))
   if [ "$DRY_RUN" -eq 0 ]; then
     printf '{"event":"unit_close","command":"comments fetch","comments_fetched":%d,"comments_skipped":%d,"source_surfaces":["giscus","github"],"elapsed_ms":%d,"source":"runtime"}\n' \
       "$_fetched" "$_skipped" "$_elapsed_ms" >> "$EXEC_LOG"
   fi
   printf 'SUMMARY: comments fetch fetched=%d skipped=%d\n' "$_fetched" "$_skipped"
   ```

2. **Implement the surface-specific fetchers** as helper functions:

   ```bash
   _fetch_github() {
     # Iterate gh api repos/<owner>/<repo>/issues/comments + /pulls/comments.
     # Filter to comments whose body contains an orchestrator-id marker
     # (per M013/scripts/integrations/github-common.sh convention).
     # Honor GH_API_STUB env var for hermetic testing — when set, read from
     # the file path it points at instead of calling gh.
     local _src
     if [ -n "${GH_API_STUB:-}" ] && [ -f "${GH_API_STUB}" ]; then
       _src="${GH_API_STUB}"
     else
       command -v gh >/dev/null 2>&1 || { printf 'WARN: gh not installed; skipping github surface\n' >&2; return 0; }
       _src="$(mktemp)"
       gh api repos/:owner/:repo/issues/comments --paginate > "$_src" 2>/dev/null || true
     fi
     # ... parse JSON, write to inbox, increment counters ...
   }

   _fetch_giscus() {
     # Iterate gh api graphql against Discussions.
     # Honor GH_GRAPHQL_STUB env var for hermetic testing.
     local _src
     if [ -n "${GH_GRAPHQL_STUB:-}" ] && [ -f "${GH_GRAPHQL_STUB}" ]; then
       _src="${GH_GRAPHQL_STUB}"
     else
       command -v gh >/dev/null 2>&1 || { printf 'WARN: gh not installed; skipping giscus surface\n' >&2; return 0; }
       _src="$(mktemp)"
       gh api graphql -f query='query { repository(owner:":owner",name:":repo"){ discussions(first:100){ nodes { id url comments(first:50){ nodes { id url body createdAt } } } } } }' > "$_src" 2>/dev/null || true
     fi
     # ... parse JSON, write to inbox, increment counters ...
   }
   ```

   For JSON parsing under Bash 3.2 with no jq dependency hard-required, use `awk`-based extraction of the load-bearing fields (`url`, `body`, `id`). If `jq` is on PATH, prefer `jq` (operator-installed convenience). Fall back to awk for the hermetic verifier path.

   The full function bodies parse one comment per JSON object, compute the body shasum, check `actioned.jsonl` for the URL, and either skip (incrementing `_skipped`) or write `<inbox>/<comment-id>.json` with the full record (incrementing `_fetched`). On `--dry-run`, the same iteration runs but prints FR-19 JSONL records to stdout instead of writing to inbox:
   `{"command":"comments fetch","action_type":"cache-comment","target_path":"<inbox-path>","source_ref":"<url>","description":"would cache comment from <surface>"}`

3. **Implement the actioned.jsonl skip check** as a helper:

   ```bash
   _is_actioned() {
     # _is_actioned <url>
     # Returns 0 if the URL appears in actioned.jsonl, 1 otherwise.
     local _url="$1"
     [ -f "$ACTIONED_LOG" ] || return 1
     grep -F -- "\"comment_url\":\"$_url\"" "$ACTIONED_LOG" >/dev/null 2>&1
   }
   ```

   Use `grep -F` (literal) for performance and correctness on URLs containing regex metacharacters.

4. **Make the script executable**:

   ```bash
   chmod +x scripts/comments/fetch.sh
   ```

5. **Create test fixtures** under `tests/fixtures/m014-p03/`:

   - `sample-inbox.jsonl` — 4 fake comments (one per FR-9 class). Used by T02 + downstream tasks; T01 also uses it as the GH_API_STUB target for one of the verifier cases. Format: one JSON object per line with `url`, `body`, `source_surface`, `id`, `created_at` fields. Example seed lines:
     ```
     {"url":"https://github.com/Build-Fractal/spec-kit-orchestrator/issues/1#issuecomment-1","body":"acceptance criterion 2 fails on macOS 13","source_surface":"github","id":"c1","created_at":"2026-04-24T00:00:00Z"}
     {"url":"https://github.com/Build-Fractal/spec-kit-orchestrator/issues/2#issuecomment-2","body":"decision: we should pin Bash 3.2 across all scripts","source_surface":"github","id":"c2","created_at":"2026-04-24T00:01:00Z"}
     {"url":"https://github.com/Build-Fractal/spec-kit-orchestrator/discussions/3#discussioncomment-3","body":"FR-5 should also cover token-density measurement","source_surface":"giscus","id":"c3","created_at":"2026-04-24T00:02:00Z"}
     {"url":"https://github.com/Build-Fractal/spec-kit-orchestrator/discussions/4#discussioncomment-4","body":"hmm not sure about this approach","source_surface":"giscus","id":"c4","created_at":"2026-04-24T00:03:00Z"}
     ```

6. **Create `scripts/verify/m014-p03-fetch.sh`** as the T01 verifier (single-script-file shape, Bash 3.2):

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m014-p03-fetch.sh
   # Verifies M014/P03/T01: comment fetcher + idempotency.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   FETCHER="${REPO_ROOT}/scripts/comments/fetch.sh"
   FIXTURE="${REPO_ROOT}/tests/fixtures/m014-p03/sample-inbox.jsonl"

   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   SCRATCH="$(mktemp -d)"
   trap 'rm -rf "$SCRATCH"' EXIT
   mkdir -p "$SCRATCH/.orchestrator/comments"
   touch "$SCRATCH/.orchestrator/execution-log.jsonl"

   # Case A: Hermetic fetch via stub — fixture fed as GH_API_STUB; expect 4 inbox files.
   ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
   GH_API_STUB="$FIXTURE" \
   GH_GRAPHQL_STUB="$FIXTURE" \
     bash "$FETCHER" --yes > "$SCRATCH/run-a.out" 2>&1
   rc_a=$?
   if [ "$rc_a" = "0" ]; then _pass "Case A: fetch exits 0 with stub"; else _fail "Case A: rc=$rc_a"; fi
   if grep -q "fetched=4" "$SCRATCH/run-a.out"; then _pass "Case A: SUMMARY reports fetched=4"; else _fail "Case A: SUMMARY missing fetched=4 (out: $(cat $SCRATCH/run-a.out))"; fi
   inbox_count=$(ls -1 "$SCRATCH/.orchestrator/comments/inbox/" 2>/dev/null | wc -l | tr -d ' ')
   if [ "$inbox_count" = "4" ]; then _pass "Case A: 4 inbox files written"; else _fail "Case A: inbox count=$inbox_count, expected 4"; fi
   if grep -q '"event":"unit_close"' "$SCRATCH/.orchestrator/execution-log.jsonl"; then _pass "Case A: unit_close emitted"; else _fail "Case A: unit_close missing"; fi

   # Case B: Idempotency — seed actioned.jsonl with one URL, re-fetch, expect skipped=1 fetched=3.
   echo '{"comment_url":"https://github.com/Build-Fractal/spec-kit-orchestrator/issues/1#issuecomment-1","actioned_at":"2026-04-24T00:00:00Z","class":"uat-bug","applied":true}' > "$SCRATCH/.orchestrator/comments/actioned.jsonl"
   rm -rf "$SCRATCH/.orchestrator/comments/inbox"
   ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
   GH_API_STUB="$FIXTURE" \
   GH_GRAPHQL_STUB="$FIXTURE" \
     bash "$FETCHER" --yes > "$SCRATCH/run-b.out" 2>&1
   if grep -q "fetched=3 skipped=1" "$SCRATCH/run-b.out"; then _pass "Case B: idempotency skip on actioned URL"; else _fail "Case B: expected fetched=3 skipped=1 (out: $(cat $SCRATCH/run-b.out))"; fi

   # Case C: --dry-run emits FR-19 JSONL to stdout, no inbox writes.
   rm -rf "$SCRATCH/.orchestrator/comments/inbox"
   rm -f "$SCRATCH/.orchestrator/comments/actioned.jsonl"
   touch "$SCRATCH/.orchestrator/comments/actioned.jsonl"
   ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
   GH_API_STUB="$FIXTURE" \
   GH_GRAPHQL_STUB="$FIXTURE" \
     bash "$FETCHER" --yes --dry-run > "$SCRATCH/run-c.out" 2>&1
   if grep -q '"action_type":"cache-comment"' "$SCRATCH/run-c.out"; then _pass "Case C: dry-run emits FR-19 manifest"; else _fail "Case C: missing dry-run JSONL"; fi
   inbox_dry=$(ls -1 "$SCRATCH/.orchestrator/comments/inbox/" 2>/dev/null | wc -l | tr -d ' ')
   if [ "$inbox_dry" = "0" ]; then _pass "Case C: dry-run no inbox writes"; else _fail "Case C: dry-run wrote $inbox_dry files"; fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

7. **Run the verifier**:

   ```bash
   bash scripts/verify/m014-p03-fetch.sh
   ```

   Expected:
   ```
   ----
   SUMMARY: m014-p03-fetch.sh pass=8 fail=0
   PASS: m014-p03-fetch.sh
   ```

## Must-Haves

Addresses phase must-haves:
- "Truth: fetch.sh enumerates unactioned comments + writes inbox + skips actioned URLs + dry-run FR-19 manifest"
- Artifacts: `scripts/comments/fetch.sh`, `scripts/verify/m014-p03-fetch.sh`, `tests/fixtures/m014-p03/sample-inbox.jsonl`

## Verification

```
bash scripts/verify/m014-p03-fetch.sh
```

Must exit 0 with `PASS: m014-p03-fetch.sh`.

## Inputs

### From Previous Tasks

None — T01 is independent within P03.

### From Disk (Pre-existing)

- `scripts/integrations/github-common.sh` (M013/P04) — orchestrator-id marker convention reference. T01 does not modify it.
- `scripts/wiki/wiki-giscus-remap.sh` (M012) — Giscus Discussion → spec-chunk thread mapping. T01 reads behavior contract; does not modify.
- `.orchestrator/execution-log.jsonl` — append target for unit_close emission.

## Constraints

- **CON-6 / MEM001**: Bash 3.2; no `declare -A`, no `mapfile`, no `${var,,}`, no process substitution, no `&>`. Verifier asserts via `m014-p03-bash32-and-lint.sh` (T05 omnibus).
- **CON-3 / SC-7**: `--yes` resolves all interactive prompts to documented defaults; verifier seeds `--yes` on every invocation.
- **CON-8**: idempotent — re-running fetch never duplicates inbox files; URL+shasum is the dedup key against `actioned.jsonl`.
- **D007 reuse**: T01 does NOT modify `scripts/dispatch/adapters/tool/conversus.sh`. Conversus integration belongs to T02 (ambiguous-routing).
- **AD-19**: every `Check:` in this plan is `bash scripts/verify/m014-p03-<name>.sh`. The verifier itself uses no inline compounds beyond two-command `&&`/`||`.

## Expected Output

- `scripts/comments/fetch.sh` created (~120-160 lines).
- `tests/fixtures/m014-p03/sample-inbox.jsonl` created (~4-6 lines).
- `scripts/verify/m014-p03-fetch.sh` created (~80-100 lines).
- `bash scripts/verify/m014-p03-fetch.sh` exits 0, prints `SUMMARY: ... pass=8 fail=0` and `PASS: m014-p03-fetch.sh`.
