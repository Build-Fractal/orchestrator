---
schema_version: "1.0"
task: "T03"
phase: "P03"
milestone: "M014"
name: "Command surface + review queue + apply/reject/triage (FR-1, FR-11, US-5, CON-5)"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped — fetch.sh writes inbox JSON, actioned.jsonl is the idempotency log.
- [M011](../../../../milestones/M011/index.md) has shipped — `scripts/knowledge/rebuild-index.sh` exists; chunk-source-line metadata is preserved by the M011 ingest path. T03 invokes rebuild-index.sh after spec-amendment apply.
- Spec line 116-128 (US-5) defines the apply contract: atomic git-commit, chunk-source-preserving edit, pre-commit hooks honored, stale-diff detection.
- Spec line 64 (AS-4) and line 245 (SC-5) define the human-gate invariant: spec-amendment is NEVER auto-applied regardless of confidence; the `apply <queue-id>` invocation is the only path.

## Description

T03 ships:

1. `commands/comments.md` — user-facing command surface documenting all six subcommands (`classify`, `status`, `apply`, `reject`, `triage`, `reclassify`). The doc cites D023 for the regex/heuristic v1 baseline pin and the retune trigger; documents the FR-19 dry-run JSONL manifest shape; documents the spec-amendment human-gate invariant.

2. `scripts/comments/apply.sh <queue-id>` — applies an operator-approved spec-amendment queue item:
   - Reads `.orchestrator/comments/review-queue/<queue-id>.md` (frontmatter has `comment_url`, `class`, `proposed_action`, `target_spec_path`, `target_chunk_id`, `proposed_diff`).
   - Verifies the proposed diff still applies cleanly against the target spec (stale-diff detection per US-5 AS-2).
   - Applies the diff atomically via `patch` or temp-file-then-rename.
   - Invokes `scripts/knowledge/rebuild-index.sh` to re-version affected chunks.
   - Marks the comment actioned in `actioned.jsonl` with `applied: true`.
   - Refuses when an in-flight conversus deliberation exists at `specs/<NNN>-<slug>/conversus/` (US-5 AS-4).
   - Refuses on stale diff with three-way diff surfaced to operator (US-5 AS-2).

3. `scripts/comments/reject.sh <queue-id> --reason <prose>` — marks a queue item actioned with `applied: false` and the rejection reason recorded.

4. `scripts/comments/triage.sh` — lists comments routed to the human-triage bucket (those whose conversus-adapter triage returned low confidence per spec AS-5/AS-8). Each entry shows source URL, conversus verdict, and remediation hint.

5. The review-queue convention `.orchestrator/comments/review-queue/<queue-id>.md` — markdown file with frontmatter (`comment_url`, `class`, `confidence`, `proposed_action`, `queued_at`, `queue_id`, `target_spec_path` (optional), `target_chunk_id` (optional)) and body rendering the proposed diff (for spec-amendment) or proposed append (for below-threshold decision-append).

6. Verifiers:
   - `scripts/verify/m014-p03-commands-md.sh` — asserts commands/comments.md shape and content.
   - `scripts/verify/m014-p03-apply.sh` — exercises apply.sh end-to-end against a hermetic scratch repo.
   - `scripts/verify/m014-p03-reject-triage.sh` — exercises reject.sh + triage.sh.
   - `scripts/verify/m014-p03-spec-amendment-human-gate.sh` — SC-5 invariant assertion (no auto-apply path exists for spec-amendment class).

## Steps

1. **Create `commands/comments.md`**:

   ```markdown
   # orchestrator:comments

   Comment→workflow classifier and human-gated spec-amendment apply path.
   Consumes [M012](../../../../milestones/M012/index.md) wiki Giscus + [M013](../../../../milestones/M013/index.md) GitHub Issue/PR comments per FR-8/FR-9
   (M014 spec). Spec-amendment-class comments are NEVER auto-applied
   (CON-5/SC-5 — Constitution III + XIV); the `apply <queue-id>` subcommand
   is the single path for spec mutation from comments.

   ## Subcommands

   ### classify

   `orchestrator:comments classify [--dry-run] [--yes]`

   Fetches unactioned comments from Giscus + GitHub surfaces, classifies each
   into one of `{uat-bug, decision-append, spec-amendment, ambiguous}` per the
   regex/heuristic v1 baseline (D023 pin), routes:

   - **uat-bug** above threshold → auto-apply via M013/FR-10 UAT ingestion path.
   - **decision-append** above threshold → append templated block to [`.orchestrator/DECISIONS.md`](../../../../decisions.md).
   - **spec-amendment** any confidence → queue for human sign-off at `.orchestrator/comments/review-queue/<queue-id>.md`.
   - **ambiguous** → invoke `scripts/dispatch/adapters/tool/conversus.sh gate classify-comment` (M011/P07 adapter, `--strict`); on low-confidence verdict, route to human triage bucket.

   `--dry-run` prints FR-19 JSONL action records to stdout without disk mutation.
   `--yes` resolves all interactive prompts to documented defaults (CON-3 zero-prompt baseline).

   ### status

   `orchestrator:comments status`

   Lists every queued review-queue item with `queue_id`, `class`, `confidence`,
   `comment_url`, and the approve/reject hint. Read-only.

   ### apply

   `orchestrator:comments apply <queue-id>`

   Applies an operator-approved spec-amendment queue item atomically:
   reads the queued diff, verifies it still applies (rejects on stale diff
   per US-5 AS-2), edits the target spec, runs `scripts/knowledge/rebuild-index.sh`,
   commits the change with a message citing the queue-id and source comment URL,
   and marks the comment actioned with `applied: true`.

   Refuses when an in-flight conversus deliberation exists at the target spec's
   `conversus/` directory (US-5 AS-4 — no interleaving authorship + amendment).

   ### reject

   `orchestrator:comments reject <queue-id> --reason "<prose>"`

   Marks a queue item actioned with `applied: false`, records the rejection reason,
   and (if `comments.reply_on_apply: true` in config) replies to the source comment
   thread with the rejection reason.

   ### triage

   `orchestrator:comments triage`

   Lists comments routed to the human-triage bucket (ambiguous comments whose
   conversus verdict was low-confidence per spec AS-5/AS-8). Each entry shows
   source URL, conversus verdict, and remediation hint.

   ### reclassify

   `orchestrator:comments reclassify <comment-url>`

   Re-runs classification on a specific URL skipping the `actioned.jsonl`
   idempotency check. Useful when the regex/heuristic ruleset has been retuned
   (per the D023 retune trigger) and historical comments need reprocessing.

   ## D023 retune trigger

   The regex/heuristic v1 baseline is provisional. When EITHER of these conditions
   holds, open a follow-up D-row that re-pins FR-9 shape:

   1. `actioned.jsonl` shows ≥30 fetched comments across the four classes.
   2. Classifier confidence calibration on observed comments diverges from
      regex/heuristic predictions in ≥20% of samples.

   See `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md`
   and [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D023 for the full retune contract.

   ## FR-19 dry-run manifest

   Every M014 command's `--dry-run` emits JSONL action records to stdout:

   ```
   {"command":"comments classify","action_type":"<action>","target_path":"<path>","source_ref":"<url>","description":"<text>"}
   ```

   `action_type` values include `cache-comment`, `classify-comment`, `auto-apply-uat-bug`,
   `auto-apply-decision-append`, `queue-spec-amendment`, `route-ambiguous-to-conversus`,
   `apply-amendment`, `reject-queue-item`.

   ## Reference files

   - `scripts/comments/comments.sh` — master pipeline implementation (M014/P03/T04).
   - `scripts/comments/{fetch,classify,apply,reject,triage}.sh` — sub-action scripts.
   - `references/spec-management.md#comment-classification--workflow-routing` — full algorithmic reference.
   - [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D023 — regex/heuristic v1 pin + retune trigger.
   ```

2. **Create `scripts/comments/apply.sh`** (~140 lines, Bash 3.2):

   ```bash
   #!/usr/bin/env bash
   # scripts/comments/apply.sh
   # FR-1 + US-5 — apply an operator-approved spec-amendment queue item.
   # CON-5: spec-amendment class is human-gated; this is the ONLY path
   # for spec mutation from comments.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="${ORCHESTRATOR_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
   ORCH_ROOT="${PROJECT_ROOT}/.orchestrator"
   QUEUE_DIR="${ORCH_ROOT}/comments/review-queue"
   ACTIONED_LOG="${ORCH_ROOT}/comments/actioned.jsonl"
   EXEC_LOG="${ORCH_ROOT}/execution-log.jsonl"

   _queue_id="${1:-}"
   if [ -z "$_queue_id" ]; then
     printf 'FAIL: apply.sh: queue-id required as $1\n' >&2
     exit 2
   fi

   _queue_file="${QUEUE_DIR}/${_queue_id}.md"
   if [ ! -f "$_queue_file" ]; then
     printf 'FAIL: apply.sh: queue-id %s not found at %s\n' "$_queue_id" "$_queue_file" >&2
     exit 2
   fi

   # Extract frontmatter fields via awk.
   _comment_url="$(awk '/^comment_url:/ { sub(/^comment_url:[[:space:]]*/, ""); print; exit }' "$_queue_file")"
   _target_spec="$(awk '/^target_spec_path:/ { sub(/^target_spec_path:[[:space:]]*/, ""); print; exit }' "$_queue_file")"
   _class="$(awk '/^class:/ { sub(/^class:[[:space:]]*/, ""); print; exit }' "$_queue_file")"

   # Guard: only spec-amendment class is applied via this path. Other classes
   # have their own auto-apply pipeline; manual apply is reserved for spec-amendment.
   if [ "$_class" != "spec-amendment" ]; then
     printf 'FAIL: apply.sh: queue item class=%s; expected spec-amendment (other classes auto-apply via classify pipeline)\n' "$_class" >&2
     exit 2
   fi

   # Guard: in-flight conversus deliberation refuses apply (US-5 AS-4).
   _spec_dir="$(dirname "${PROJECT_ROOT}/${_target_spec}")"
   if [ -d "${_spec_dir}/conversus" ] && [ ! -f "${_spec_dir}/conversus/summary/final.md" ]; then
     printf 'FAIL: apply.sh: deliberation in progress at %s/conversus/; complete or abort before applying amendments\n' "$_spec_dir" >&2
     exit 2
   fi

   # Extract proposed-diff body (between ```diff and ``` fences).
   _diff_file="$(mktemp)"
   awk '/^```diff[[:space:]]*$/ { in_diff=1; next } /^```[[:space:]]*$/ && in_diff { in_diff=0; exit } in_diff { print }' "$_queue_file" > "$_diff_file"

   if [ ! -s "$_diff_file" ]; then
     printf 'FAIL: apply.sh: queue item has no proposed-diff body\n' >&2
     rm -f "$_diff_file"
     exit 2
   fi

   # Stale-diff detection — dry-apply via patch --dry-run.
   if ! patch --dry-run -p1 -d "$PROJECT_ROOT" < "$_diff_file" >/dev/null 2>&1; then
     printf 'FAIL: apply.sh: stale-diff — proposed diff no longer applies cleanly. Operator must re-classify or refresh manually.\n' >&2
     rm -f "$_diff_file"
     exit 2
   fi

   # Apply for real.
   patch -p1 -d "$PROJECT_ROOT" < "$_diff_file" >/dev/null 2>&1
   _rc=$?
   if [ "$_rc" -ne 0 ]; then
     printf 'FAIL: apply.sh: patch exited %d after dry-run succeeded — manual investigation required\n' "$_rc" >&2
     rm -f "$_diff_file"
     exit 1
   fi
   rm -f "$_diff_file"

   # Invoke rebuild-index (best-effort; warn on failure).
   if [ -x "${PROJECT_ROOT}/scripts/knowledge/rebuild-index.sh" ]; then
     bash "${PROJECT_ROOT}/scripts/knowledge/rebuild-index.sh" >/dev/null 2>&1 || printf 'WARN: rebuild-index returned non-zero; index may be stale\n' >&2
   fi

   # Append to actioned.jsonl.
   _now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   printf '{"comment_url":"%s","actioned_at":"%s","class":"%s","applied":true,"queue_id":"%s"}\n' \
     "$_comment_url" "$_now" "$_class" "$_queue_id" >> "$ACTIONED_LOG"

   # Emit comment_actioned event.
   printf '{"event":"comment_actioned","comment_url":"%s","class":"%s","action_taken":"apply-amendment","source_surface":"queue","queue_id":"%s"}\n' \
     "$_comment_url" "$_class" "$_queue_id" >> "$EXEC_LOG"

   printf 'PASS: apply.sh: queue-id %s applied (class=%s)\n' "$_queue_id" "$_class"
   exit 0
   ```

3. **Create `scripts/comments/reject.sh`** (~50 lines):

   ```bash
   #!/usr/bin/env bash
   # scripts/comments/reject.sh
   # FR-1 — mark a queue item rejected.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="${ORCHESTRATOR_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
   ORCH_ROOT="${PROJECT_ROOT}/.orchestrator"
   QUEUE_DIR="${ORCH_ROOT}/comments/review-queue"
   ACTIONED_LOG="${ORCH_ROOT}/comments/actioned.jsonl"

   _queue_id="${1:-}"
   _reason=""
   shift || true
   while [ $# -gt 0 ]; do
     case "$1" in
       --reason) shift; _reason="${1:-}" ;;
       *) printf 'FAIL: unknown arg %s\n' "$1" >&2; exit 2 ;;
     esac
     shift
   done

   if [ -z "$_queue_id" ] || [ -z "$_reason" ]; then
     printf 'FAIL: reject.sh: queue-id ($1) and --reason required\n' >&2
     exit 2
   fi

   _queue_file="${QUEUE_DIR}/${_queue_id}.md"
   [ -f "$_queue_file" ] || { printf 'FAIL: reject.sh: queue-id %s not found\n' "$_queue_id" >&2; exit 2; }

   _comment_url="$(awk '/^comment_url:/ { sub(/^comment_url:[[:space:]]*/, ""); print; exit }' "$_queue_file")"
   _class="$(awk '/^class:/ { sub(/^class:[[:space:]]*/, ""); print; exit }' "$_queue_file")"
   _now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

   # Escape reason for JSONL (basic — strip quotes).
   _reason_escaped="$(printf '%s' "$_reason" | tr '"' "'")"

   printf '{"comment_url":"%s","actioned_at":"%s","class":"%s","applied":false,"queue_id":"%s","reason":"%s"}\n' \
     "$_comment_url" "$_now" "$_class" "$_queue_id" "$_reason_escaped" >> "$ACTIONED_LOG"

   printf 'PASS: reject.sh: queue-id %s rejected (reason=%s)\n' "$_queue_id" "$_reason_escaped"
   exit 0
   ```

4. **Create `scripts/comments/triage.sh`** (~50 lines):

   ```bash
   #!/usr/bin/env bash
   # scripts/comments/triage.sh
   # FR-1 — list comments routed to the human-triage bucket.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="${ORCHESTRATOR_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
   ORCH_ROOT="${PROJECT_ROOT}/.orchestrator"
   TRIAGE_DIR="${ORCH_ROOT}/comments/triage"

   if [ ! -d "$TRIAGE_DIR" ]; then
     printf 'INFO: no triage entries (directory %s does not exist)\n' "$TRIAGE_DIR"
     printf 'SUMMARY: triage entries=0\n'
     exit 0
   fi

   _count=0
   for f in "$TRIAGE_DIR"/*.md; do
     [ -f "$f" ] || continue
     _count=$((_count+1))
     _id="$(basename "$f" .md)"
     _url="$(awk '/^comment_url:/ { sub(/^comment_url:[[:space:]]*/, ""); print; exit }' "$f")"
     _verdict="$(awk '/^conversus_verdict:/ { sub(/^conversus_verdict:[[:space:]]*/, ""); print; exit }' "$f")"
     printf '%s\t%s\tconversus_verdict=%s\n' "$_id" "$_url" "${_verdict:-unknown}"
   done

   printf 'SUMMARY: triage entries=%d\n' "$_count"
   exit 0
   ```

5. **Create `tests/fixtures/m014-p03/queued-amendment.md`** (a minimal review-queue fixture used by the apply verifier):

   ```markdown
   ---
   comment_url: "https://example/issues/3#issuecomment-3"
   class: "spec-amendment"
   confidence: "0.85"
   proposed_action: "amend-spec"
   queued_at: "2026-04-24T00:00:00Z"
   queue_id: "Q001"
   target_spec_path: "specs/m014-p03-test/spec.md"
   target_chunk_id: "FR-1"
   ---

   ## Proposed amendment

   FR-1 should also cover the additional clause requested in the source comment.

   ```diff
   --- a/specs/m014-p03-test/spec.md
   +++ b/specs/m014-p03-test/spec.md
   @@ -1,3 +1,4 @@
    # FR-1: Test spec
    Original line.
   +Additional line proposed by amendment.
   ```
   ```

6. **Create `scripts/verify/m014-p03-commands-md.sh`** (~50 lines): assert commands/comments.md exists, contains all six subcommands, references D023, references FR-19 dry-run shape, references spec-amendment human-gate.

7. **Create `scripts/verify/m014-p03-apply.sh`** (~80 lines): hermetic scratch repo with a minimal target spec + queued amendment fixture; exercises apply.sh, asserts the spec is mutated, actioned.jsonl gets `applied: true` row, comment_actioned event lands; second case asserts stale-diff refuses; third asserts in-flight-conversus refuses.

8. **Create `scripts/verify/m014-p03-reject-triage.sh`** (~50 lines): exercises reject.sh + triage.sh.

9. **Create `scripts/verify/m014-p03-spec-amendment-human-gate.sh`** (~40 lines): asserts no auto-apply path exists for spec-amendment class; greps `scripts/comments/comments.sh` (T04 ships) — but since T04 hasn't shipped yet at T03 verifier-write time, this gate is structured to skip-with-PASS if comments.sh doesn't exist, else assert the invariant. T04 expansion of comments.sh re-runs this verifier. Alternatively: assert the invariant against any present `scripts/comments/*.sh` — currently apply.sh (which IS the manual gate, so it's the legitimate path) and reject.sh — and assert no auto-* path exists. Uses pattern: grep for `class=spec-amendment.*auto` or similar; expects zero matches.

   Implementation:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m014-p03-spec-amendment-human-gate.sh
   # SC-5 invariant — spec-amendment is NEVER auto-applied.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   # Assert: scripts/comments/apply.sh refuses non-spec-amendment classes
   # AND requires explicit invocation (no caller is "auto-").
   if grep -q 'class=spec-amendment' "${REPO_ROOT}/scripts/comments/apply.sh" || grep -q '"$_class" != "spec-amendment"' "${REPO_ROOT}/scripts/comments/apply.sh"; then
     _pass "apply.sh gates on class=spec-amendment"
   else
     _fail "apply.sh missing class=spec-amendment guard"
   fi

   # Assert: no script under scripts/comments/ contains a pattern that
   # auto-applies spec-amendment without going through apply.sh.
   forbidden_patterns="auto[_-]?apply.*spec[_-]?amendment\|spec[_-]?amendment.*auto[_-]?apply"
   for f in "${REPO_ROOT}"/scripts/comments/*.sh; do
     [ -f "$f" ] || continue
     # Skip apply.sh itself (it's the manual path).
     case "$(basename "$f")" in
       apply.sh) continue ;;
     esac
     if grep -qiE "$forbidden_patterns" "$f"; then
       _fail "$f contains auto-apply-spec-amendment pattern"
     fi
   done
   _pass "no auto-apply-spec-amendment pattern in scripts/comments/"

   # Assert: SC-5 documented in commands/comments.md.
   if grep -qE "human-gate|never auto-applied|CON-5|SC-5" "${REPO_ROOT}/commands/comments.md"; then
     _pass "commands/comments.md documents human-gate invariant"
   else
     _fail "commands/comments.md missing human-gate documentation"
   fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

10. **Make scripts executable**:

    ```bash
    chmod +x scripts/comments/apply.sh scripts/comments/reject.sh scripts/comments/triage.sh
    ```

11. **Run all four T03 verifiers**:

    ```bash
    bash scripts/verify/m014-p03-commands-md.sh
    bash scripts/verify/m014-p03-apply.sh
    bash scripts/verify/m014-p03-reject-triage.sh
    bash scripts/verify/m014-p03-spec-amendment-human-gate.sh
    ```

    All four must exit 0 with `PASS:` final line.

## Must-Haves

Addresses phase must-haves:
- "Truth: commands/comments.md documents subcommand surface + D023 retune"
- "Truth: apply.sh applies queue item atomically; refuses stale + in-flight conversus"
- "Truth: reject.sh + triage.sh"
- "Truth: spec-amendment never auto-applied (SC-5/CON-5)"

## Verification

```
bash scripts/verify/m014-p03-commands-md.sh
bash scripts/verify/m014-p03-apply.sh
bash scripts/verify/m014-p03-reject-triage.sh
bash scripts/verify/m014-p03-spec-amendment-human-gate.sh
```

All four exit 0.

## Inputs

### From Previous Tasks

- `scripts/comments/fetch.sh` (T01) — actioned.jsonl shape `{comment_url, actioned_at, class, applied, queue_id?, reason?}`. T03 appends rows.

### From Disk (Pre-existing)

- `scripts/knowledge/rebuild-index.sh` (M011) — invoked by apply.sh post-edit.
- `patch` — POSIX util; used for stale-diff detection + apply.

## Constraints

- **CON-5 / SC-5**: spec-amendment is human-gated. Apply path is manual via `apply <queue-id>`. No script under `scripts/comments/` auto-applies spec-amendment regardless of confidence.
- **CON-8**: idempotent — re-applying the same queue item lands a stale-diff refusal on second run (the diff doesn't apply once the spec is already mutated).
- **CON-6 / MEM001 Bash 3.2**: no `${var,,}`, no `mapfile`, no `declare -A`.
- **AD-19**: every Check is `bash scripts/verify/m014-p03-<name>.sh`; verifiers use no inline compounds beyond `&&`/`||` of two commands.
- **D007 reuse**: T03 does not modify `scripts/dispatch/adapters/tool/conversus.sh`.

## Expected Output

- `commands/comments.md` created (~120-180 lines).
- `scripts/comments/apply.sh` created (~120-160 lines).
- `scripts/comments/reject.sh` created (~50-70 lines).
- `scripts/comments/triage.sh` created (~50-70 lines).
- `tests/fixtures/m014-p03/queued-amendment.md` created (~25-40 lines).
- Four verifiers under `scripts/verify/m014-p03-*.sh` (~60-100 lines each).
- All four verifiers exit 0 with `PASS:` final lines.
