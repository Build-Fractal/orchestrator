---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M012"
name: "wiki-giscus-remap.sh — idempotent Discussion-title remap + wiki/README.md mapping docs"
depends_on: ["T03"]
---

## Prerequisites

- T01 complete: `mapping: "pathname"` is fixed in `wiki/mkdocs.yml`. Each rendered page maps to a GitHub Discussion whose title equals the page's pathname (e.g., `/decisions/`, `/milestones/M011/M011-SUMMARY/`).
- T02 complete: env-var check script exists.
- T03 complete: smoke script exists; this task references it from `wiki/README.md` as the verification companion for a remap.
- `gh` CLI (GitHub CLI) is assumed available on a maintainer's machine for live remap; the dry-run path must work without `gh`.

## Description

Ship two artifacts:

1. **`scripts/diagnostics/wiki-giscus-remap.sh`** — a Bash 3.2, idempotent utility that takes `<old-path> <new-path>` pairs and renames the corresponding Giscus Discussion titles on the configured repo. Under `mapping: pathname`, Giscus keys each thread by the page's rendered URL path. When an orchestrator artifact is consolidated (e.g., `milestones/M011/phases/P03/` → `archive/M011/phases/P03/`), the page URL changes and Giscus creates a fresh thread at the new URL, orphaning the old discussion. This script relabels the old Discussion's title to the new pathname so Giscus' pathname-matcher picks it up on the next page load.

2. **`wiki/README.md` extension** — append two sections: "Giscus mapping" (documents the `pathname` strategy, its tradeoffs for rename/archive, and what the smoke script asserts) and "Remapping threads after consolidation" (documents the remap script's usage and links to both the smoke script and config-check script by basename so the link-check gate in P05 resolves them).

This is the AD-5 mapping tradeoffs surface required by SC-7 and US5.

Out-of-scope for this task: verify gates / phase-suite (T05 — immediately downstream), deploy pipeline wiring (P04), automated trigger of the remap on consolidate (future).

## Steps

1. **Create `scripts/diagnostics/wiki-giscus-remap.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/wiki-giscus-remap.sh — M012/P03 US5 remap utility.
   #
   # Under mapping: pathname, a Giscus thread is keyed by the page URL path.
   # When an artifact is consolidated (e.g. moved under archive/), the page
   # URL changes and Giscus creates a fresh empty thread at the new URL,
   # orphaning prior comments. This script relabels the old Discussion's
   # TITLE to the new pathname so Giscus' pathname-matcher reconnects the
   # thread at the new URL on next page load.
   #
   # Usage:
   #   wiki-giscus-remap.sh <old-path> <new-path> [<old2> <new2> ...]
   #   wiki-giscus-remap.sh --dry-run <pairs>
   #   wiki-giscus-remap.sh --repo <owner/repo> --category <cat> <pairs>
   #   wiki-giscus-remap.sh --help
   #
   # Flags:
   #   --dry-run       print planned operations; do NOT call gh api
   #   --repo OWNER/R  target repo (default $GISCUS_REPO)
   #   --category CAT  Discussion category name (default $GISCUS_CATEGORY)
   #   --help          print usage; exit 0
   #
   # Behavior:
   #   For each <old new> pair:
   #     1. Query existing Discussions whose title == <old>.
   #     2. If found: rename title to <new>. If already == <new> or no match
   #        whose title == <old>: emit NOOP: <old> -> <new> and continue.
   #     3. If match count > 1: emit FAIL: ambiguous (N matches) and exit 1
   #        without making changes.
   #
   # Idempotency: running the script twice in a row against the same pair
   # list produces identical observable state — the second run emits
   # NOOP lines for every pair.
   #
   # Bash 3.2 compatible. Requires gh (unless --dry-run). No jq hard-dep;
   # uses gh --jq for GraphQL response field extraction.

   set -u
   set -o pipefail

   DRY_RUN=0
   REPO="${GISCUS_REPO:-}"
   CATEGORY="${GISCUS_CATEGORY:-}"

   usage() {
     sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
   }

   pairs_old=""
   pairs_new=""

   # Two-phase arg parse: flags first, then <old new> positional pairs.
   while [ $# -gt 0 ]; do
     case "$1" in
       --dry-run)  DRY_RUN=1; shift ;;
       --repo)     REPO="$2"; shift 2 ;;
       --category) CATEGORY="$2"; shift 2 ;;
       --help|-h)  usage; exit 0 ;;
       --)         shift; break ;;
       -*)         printf 'ERROR: unknown flag: %s\n' "$1" >&2; exit 2 ;;
       *)          break ;;
     esac
   done

   if [ $# -eq 0 ] || [ $(( $# % 2 )) -ne 0 ]; then
     printf 'ERROR: positional args must be <old> <new> pairs; got %d args\n' "$#" >&2
     usage >&2
     exit 2
   fi

   if [ "$DRY_RUN" -eq 0 ]; then
     if [ -z "$REPO" ] || [ -z "$CATEGORY" ]; then
       printf 'ERROR: --repo and --category required (or set GISCUS_REPO + GISCUS_CATEGORY)\n' >&2
       exit 2
     fi
     if ! command -v gh >/dev/null 2>&1; then
       printf 'ERROR: gh CLI not on PATH (required for non-dry-run)\n' >&2
       exit 2
     fi
   fi

   # Loop pairs.
   status=0
   while [ $# -gt 0 ]; do
     OLD="$1"; NEW="$2"; shift 2
     if [ "$DRY_RUN" -eq 1 ]; then
       printf 'DRY-RUN: %s -> %s\n' "$OLD" "$NEW"
       continue
     fi

     # Query Discussions in the category whose title == OLD.
     # Output is a JSON list of {id,title} objects. GraphQL via `gh api graphql`.
     query='query($o:String!,$r:String!,$c:String!,$t:String!){repository(owner:$o,name:$r){discussions(first:50,categoryId:null){nodes{id title category{name}}}}}'
     owner="${REPO%%/*}"
     name="${REPO##*/}"
     # Pull all discussions, filter by title+category in the helper script.
     discussions_json="$(gh api graphql -f query="$query" -F o="$owner" -F r="$name" -F c="$CATEGORY" -F t="$OLD" --jq '.data.repository.discussions.nodes' 2>/dev/null || echo '[]')"

     match_count="$(printf '%s' "$discussions_json" \
       | grep -o "\"title\":\"$OLD\"" | wc -l | tr -d '[:space:]')"

     if [ "$match_count" -eq 0 ]; then
       printf 'NOOP: %s -> %s (no match)\n' "$OLD" "$NEW"
       continue
     fi
     if [ "$match_count" -gt 1 ]; then
       printf 'FAIL: %s -> %s (ambiguous: %d matches)\n' "$OLD" "$NEW" "$match_count" >&2
       status=1
       continue
     fi

     # Exactly one match. Extract its id.
     disc_id="$(printf '%s' "$discussions_json" \
       | sed 's/.*"id":"\([^"]*\)","title":"'"$OLD"'".*/\1/p' | head -n 1)"
     if [ -z "$disc_id" ]; then
       printf 'FAIL: %s -> %s (id extract failed)\n' "$OLD" "$NEW" >&2
       status=1
       continue
     fi

     # GraphQL updateDiscussion mutation to rename title.
     mutation='mutation($id:ID!,$title:String!){updateDiscussion(input:{discussionId:$id,title:$title}){discussion{id title}}}'
     if gh api graphql -f query="$mutation" -F id="$disc_id" -F title="$NEW" >/dev/null 2>&1; then
       printf 'OK: %s -> %s\n' "$OLD" "$NEW"
     else
       printf 'FAIL: %s -> %s (gh api mutation failed)\n' "$OLD" "$NEW" >&2
       status=1
     fi
   done

   exit "$status"
   ```

   - GraphQL fields are pathname strings, unambiguous under `pathname` mapping.
   - The script uses `gh api graphql --jq` which extracts fields without a jq binary dependency (`gh` bundles jq internally).
   - Pure-text parsing (`grep -o`, `sed`) for match count / id extraction keeps the script resilient to missing jq and Bash 3.2 compatible.

2. **Make it executable**: `chmod 755 scripts/diagnostics/wiki-giscus-remap.sh`.

3. **Extend `wiki/README.md`** — append two new sections at the end of the file (do not edit P01/P02 content above):

   ```markdown
   ## Giscus mapping

   Giscus uses `mapping: pathname` — each rendered page maps to a GitHub
   Discussion whose title equals the page's URL path. The strategy is
   configured in `wiki/mkdocs.yml` under `extra.giscus.mapping`.

   ### Tradeoffs

   - **Simple and deterministic.** A page at `/decisions/` has a
     Discussion titled `/decisions/`. No metadata injection, no per-page
     authoring cost.
   - **Breaks on rename.** If an artifact is moved (e.g., consolidated
     under `.orchestrator/archive/`), its rendered URL changes. Giscus
     sees a new pathname and creates a fresh empty thread, orphaning the
     prior comments. The fix is the remap script below.
   - **Survives content edits.** Editing an artifact's body does not
     change its URL — comments stay attached.
   - **Survives theme / partial changes.** The mapping is keyed at the
     page URL level; reshuffling the theme override does not orphan
     threads.

   The smoke script (`scripts/diagnostics/wiki-giscus-smoke.sh`) verifies
   that every rendered HTML page carries the Giscus loader. It does NOT
   verify thread continuity across renames — that's what the remap
   script handles.

   ## Remapping threads after consolidation

   When an artifact is consolidated (moved or renamed), its rendered URL
   changes. Run the remap script from the repo root to relabel the
   corresponding Discussion:

   ```
   bash scripts/diagnostics/wiki-giscus-remap.sh /old/path/ /new/path/
   ```

   Dry-run mode (no GitHub API calls — prints planned operations):

   ```
   bash scripts/diagnostics/wiki-giscus-remap.sh --dry-run /old/path/ /new/path/
   ```

   Env vars `GISCUS_REPO` and `GISCUS_CATEGORY` default the target; pass
   `--repo` and `--category` to override. `gh` must be on PATH for
   non-dry-run mode. The script is idempotent — rerunning after a
   successful remap prints `NOOP:` for every already-migrated pair.

   After a remap, rebuild the wiki and run the smoke script to confirm
   the page still renders the Giscus loader:

   ```
   (cd wiki && mkdocs build)
   bash scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site
   ```

   Pre-build env-var check (companion to this flow):

   ```
   bash scripts/diagnostics/wiki-giscus-config-check.sh
   ```
   ```

4. **Smoke-verify manually** (not wired as a Check):

   - `bash scripts/diagnostics/wiki-giscus-remap.sh --help` → exit 0, usage on stdout.
   - `bash scripts/diagnostics/wiki-giscus-remap.sh --dry-run /old/ /new/` → exit 0, `DRY-RUN: /old/ -> /new/` on stdout.
   - `bash scripts/diagnostics/wiki-giscus-remap.sh --dry-run /a/ /b/ /c/` → exit 2 (odd arg count).
   - `grep -n 'Giscus mapping' wiki/README.md` — one match.
   - `grep -n 'wiki-giscus-remap.sh' wiki/README.md` — at least one match.
   - `grep -n 'wiki-giscus-smoke.sh' wiki/README.md` — at least one match (either the P02 reference or the new section's reference).

## Must-Haves

- `scripts/diagnostics/wiki-giscus-remap.sh` exists, executable, ≥ 80 lines, contains the literal `pathname`.
- Script supports `--dry-run`, `--help`, `--repo`, `--category` flags.
- Script is idempotent: a second invocation after a successful remap emits `NOOP:` lines and exits 0.
- Script exits 2 on odd positional-arg count or unknown flag.
- Script requires `gh` on PATH only in non-dry-run mode.
- Script is Bash 3.2 compatible.
- `wiki/README.md` contains a "Giscus mapping" section documenting the pathname strategy + tradeoffs.
- `wiki/README.md` contains a section referencing `wiki-giscus-remap.sh` by basename.
- `wiki/README.md` contains a reference to `wiki-giscus-smoke.sh` by basename in the remap workflow (the P02 remap-script section may already reference it; reinforce under the new heading).

## Verification

- `bash scripts/verify/m012-p03-remap-contract.sh` — PASS (T05 gate; verifies flag handling, dry-run behavior, help, exit codes, idempotency surface).
- `bash scripts/verify/m012-p03-mapping-documented.sh` — PASS (T05 gate; verifies README contains "Giscus mapping" heading + `pathname` word + remap-script reference).
- `bash scripts/verify/m012-p03-bash32-compat.sh` — PASS.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P03` — artifact + key-link patterns pass.

## Inputs

### From Previous Tasks

- **T01**: `mapping: "pathname"` in `wiki/mkdocs.yml`. Determines that threads are keyed by URL path — the remap contract.
- **T02**: `scripts/diagnostics/wiki-giscus-config-check.sh` referenced by basename in the README.
- **T03**: `scripts/diagnostics/wiki-giscus-smoke.sh` referenced by basename in the README. The remap-workflow documentation instructs the operator to run the smoke script after a rebuild.

### From Disk (Pre-existing)

- `wiki/README.md` — carries P01/P02 content (install, preview, regenerate, scope, link resolution, link-checker usage, pre-deploy integration). This task appends two sections; it does not rewrite prior content.
- GitHub CLI (`gh`) external tool — contract: `gh api graphql -f query=<q> -F <var>=<val> --jq <jq-expr>` evaluates a GraphQL query against the configured repo using the user's `gh auth` state and returns JSON (or the `--jq`-filtered subset).

## Constraints

- **Bash 3.2** — MEM001. No associative arrays; positional-arg pair loop uses a simple `while [ $# -gt 0 ]; do OLD="$1"; NEW="$2"; shift 2` pattern.
- **Idempotent** — running the script twice in a row must leave the target state unchanged after the first successful run. Verified by T05's `m012-p03-remap-contract.sh` gate via a fake-fixture simulation path.
- **Dry-run decoupled from `gh`** — `--dry-run` must work without `gh` on PATH so developers can reason about planned changes on a machine without `gh` auth configured.
- **No silent writes** — every action emits one of `DRY-RUN:`, `OK:`, `NOOP:`, `FAIL:` per pair. No quiet success.
- **AD-3 SSOT** — the remap script targets Giscus' GitHub Discussions; it does **not** edit `wiki/docs/**`, `.orchestrator/**.md`, or `wiki/mkdocs.yml`. Comment state lives in GitHub; artifact state lives on disk.
- **Ambiguous-match safety** — if two Discussions carry the same title, the script fails-closed: exit 1 on that pair without attempting a rename, so human judgment is required.
- **README append-only** — do not rewrite P01/P02 content; append the new sections at the file's tail.

## Expected Output

- `scripts/diagnostics/wiki-giscus-remap.sh` exists, executable, ≥ 80 lines, Bash 3.2 compliant.
- `bash scripts/diagnostics/wiki-giscus-remap.sh --help` — exit 0, usage on stdout.
- `bash scripts/diagnostics/wiki-giscus-remap.sh --dry-run /a/ /b/` — exit 0, `DRY-RUN: /a/ -> /b/` on stdout.
- `bash scripts/diagnostics/wiki-giscus-remap.sh /a/` — exit 2 (odd arg count).
- `wiki/README.md` ends with a "Giscus mapping" section and a "Remapping threads after consolidation" section; both cite the remap script by basename and the smoke script by basename.
