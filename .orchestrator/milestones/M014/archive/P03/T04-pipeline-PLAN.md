---
schema_version: "1.0"
task: "T04"
phase: "P03"
milestone: "M014"
name: "Master pipeline + auto-apply for trivial classes + observability (FR-10, FR-16, CON-4)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped: `scripts/comments/fetch.sh` writes inbox JSON files.
- T02 has shipped: `scripts/comments/classify.sh <inbox-file>` emits `class=<class> confidence=<score> reason=<rule>` on stdout.
- T03 has shipped: `scripts/comments/{apply,reject,triage}.sh`, `commands/comments.md`, review-queue convention.
- M011/P07 conversus adapter (`scripts/dispatch/adapters/tool/conversus.sh`) is shipped and supports `gate <preset> <input> <output> --strict`.
- M013/FR-10's UAT ingestion path is shipped — exact entry point at `scripts/integrations/<TBD>` (T04 reads M013/P04-SUMMARY.md to confirm). For hermetic testing, T04's verifier stubs the UAT-ingestion call.

## Description

T04 ships `scripts/comments/comments.sh` — the master pipeline that wires
T01–T03 primitives into the user-visible `orchestrator:comments` subcommand
flow. Behavior:

1. `comments.sh classify [--dry-run] [--yes]`:
   - Invokes `fetch.sh` to populate inbox.
   - Iterates each new inbox file, calls `classify.sh <file>` for the per-comment verdict.
   - Routes per class:
     - **uat-bug** + confidence ≥ `comments.auto_apply_threshold.uat-bug` (default 0.8) → invoke M013/FR-10 UAT ingestion path; emit `comment_actioned` event with `action_taken: auto-apply-uat-bug`.
     - **decision-append** + confidence ≥ `comments.auto_apply_threshold.decision-append` (default 0.8) → append a templated block to `.orchestrator/DECISIONS.md` citing the comment URL; emit `comment_actioned` with `action_taken: auto-apply-decision-append`.
     - **spec-amendment** at any confidence → write `.orchestrator/comments/review-queue/<queue-id>.md` with frontmatter + body; NEVER auto-apply.
     - **ambiguous** → invoke `scripts/dispatch/adapters/tool/conversus.sh gate classify-comment <inbox-file> <verdict-output> --strict`; on adapter PASS verdict that re-classifies, route to that class's flow; on BLOCK / low-confidence / adapter unavailable under `--strict`, route to human triage bucket at `.orchestrator/comments/triage/<queue-id>.md`.

2. `comments.sh status`: read review-queue + print per-entry list (delegates to a small inline reader, not an external script — `status` is read-only).

3. `comments.sh reclassify <comment-url>`: re-run classify on a specific URL, skipping the actioned.jsonl idempotency check.

4. `comments.sh apply <queue-id>` / `reject <queue-id> --reason ...` / `triage`: shell out to T03's per-action scripts.

5. Emit `unit_close` JSONL at the end of every invocation with `{command: "comments classify", comments_classified: N, comments_auto_applied: M, comments_queued: K, conversus_invocations: J, adapter_verdicts: [...], elapsed_ms, source: "runtime"}`.

## Steps

1. **Read M013/P04-SUMMARY.md** to identify the exact UAT-ingestion entry point. (As of plan time it lives at `scripts/integrations/uat-ingest.sh` per M013 conventions; T04 verifier will confirm by greping the file's existence and falling back to a no-op stub if absent.)

2. **Create `scripts/comments/comments.sh`** with this structure (Bash 3.2; full body ~200-280 lines):

   ```bash
   #!/usr/bin/env bash
   # scripts/comments/comments.sh
   # M014/P03 master pipeline — orchestrator:comments subcommand surface.
   # FR-1, FR-9, FR-10, FR-11, FR-16. Bash 3.2.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="${ORCHESTRATOR_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
   ORCH_ROOT="${PROJECT_ROOT}/.orchestrator"
   INBOX_DIR="${ORCH_ROOT}/comments/inbox"
   QUEUE_DIR="${ORCH_ROOT}/comments/review-queue"
   TRIAGE_DIR="${ORCH_ROOT}/comments/triage"
   ACTIONED_LOG="${ORCH_ROOT}/comments/actioned.jsonl"
   DECISIONS_FILE="${ORCH_ROOT}/DECISIONS.md"
   EXEC_LOG="${ORCH_ROOT}/execution-log.jsonl"
   CONFIG_FILE="${ORCH_ROOT}/config.yml"
   ADAPTER="${PROJECT_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"
   CLASSIFY="${PROJECT_ROOT}/scripts/comments/classify.sh"
   FETCH="${PROJECT_ROOT}/scripts/comments/fetch.sh"
   APPLY="${PROJECT_ROOT}/scripts/comments/apply.sh"
   REJECT="${PROJECT_ROOT}/scripts/comments/reject.sh"
   TRIAGE="${PROJECT_ROOT}/scripts/comments/triage.sh"

   mkdir -p "$INBOX_DIR" "$QUEUE_DIR" "$TRIAGE_DIR"
   touch "$ACTIONED_LOG"

   # Read auto-apply thresholds from config.yml; fall back to 0.8 default.
   _read_threshold() {
     # _read_threshold <class>
     local _cls="$1"
     local _val
     _val="$(awk -v cls="$_cls" '
       /^[[:space:]]*comments:/ { in_c=1; next }
       in_c && /^[[:space:]]*auto_apply_threshold:/ { in_t=1; next }
       in_t && /^[[:space:]]*[a-zA-Z_-]+:[[:space:]]*[0-9]/ {
         line=$0
         sub(/^[[:space:]]*/, "", line)
         sub(/:.*/, "", $1)
         k=$1
         sub(/.*:[[:space:]]*/, "", line)
         sub(/[[:space:]]*$/, "", line)
         if (k == cls) { print line; exit }
       }
       in_t && !/^[[:space:]]/ { exit }
     ' "$CONFIG_FILE" 2>/dev/null)"
     if [ -z "$_val" ]; then echo "0.8"; else echo "$_val"; fi
   }

   # Compare two decimal scores (Bash 3.2 — use awk for float compare).
   _ge() {
     awk -v a="$1" -v b="$2" 'BEGIN { exit !(a+0 >= b+0) }'
   }

   _is_actioned() {
     local _url="$1"
     [ -f "$ACTIONED_LOG" ] || return 1
     grep -F -- "\"comment_url\":\"$_url\"" "$ACTIONED_LOG" >/dev/null 2>&1
   }

   _emit_actioned() {
     # _emit_actioned <url> <class> <action_taken> <surface>
     local _url="$1" _cls="$2" _act="$3" _surf="$4"
     local _now
     _now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
     printf '{"comment_url":"%s","actioned_at":"%s","class":"%s","applied":true,"action_taken":"%s"}\n' \
       "$_url" "$_now" "$_cls" "$_act" >> "$ACTIONED_LOG"
     printf '{"event":"comment_actioned","comment_url":"%s","class":"%s","confidence":"<set-by-caller>","action_taken":"%s","source_surface":"%s"}\n' \
       "$_url" "$_cls" "$_act" "$_surf" >> "$EXEC_LOG"
   }

   _queue_amendment() {
     # _queue_amendment <inbox-file> <url> <conf>
     local _inbox="$1" _url="$2" _conf="$3"
     local _qid
     _qid="$(printf '%s' "$_url" | shasum -a 256 | awk '{print substr($1,1,8)}')"
     local _qfile="${QUEUE_DIR}/Q-${_qid}.md"
     {
       printf -- '---\n'
       printf 'comment_url: "%s"\n' "$_url"
       printf 'class: "spec-amendment"\n'
       printf 'confidence: "%s"\n' "$_conf"
       printf 'proposed_action: "amend-spec"\n'
       printf 'queued_at: "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
       printf 'queue_id: "Q-%s"\n' "$_qid"
       printf -- '---\n\n'
       printf '## Source comment\n\n'
       cat "$_inbox"
       printf '\n\n## Proposed amendment\n\nOperator must author diff before `apply Q-%s`.\n' "$_qid"
     } > "$_qfile"
     printf 'Q-%s' "$_qid"
   }

   _route_ambiguous() {
     # _route_ambiguous <inbox-file> <url>
     local _inbox="$1" _url="$2"
     if [ ! -x "$ADAPTER" ]; then
       printf 'WARN: conversus adapter not executable; routing %s to human triage\n' "$_url" >&2
       _route_triage "$_inbox" "$_url" "adapter-missing"
       return 0
     fi
     local _verdict_file
     _verdict_file="$(mktemp)"
     bash "$ADAPTER" gate classify-comment "$_inbox" "$_verdict_file" --strict >/dev/null 2>&1
     local _rc=$?
     if [ "$_rc" -eq 0 ]; then
       # Extract reclassified class from verdict file (preset declares
       # verdict shape: class=<...>).
       local _new_class
       _new_class="$(grep -oE 'class=[a-z-]+' "$_verdict_file" | head -n 1 | sed 's/class=//')"
       rm -f "$_verdict_file"
       if [ -n "$_new_class" ] && [ "$_new_class" != "ambiguous" ]; then
         printf 'INFO: conversus reclassified ambiguous comment as %s\n' "$_new_class" >&2
         _route_class "$_inbox" "$_url" "$_new_class" "0.6"
         return 0
       fi
     fi
     rm -f "$_verdict_file"
     _route_triage "$_inbox" "$_url" "conversus-low-confidence-or-block"
   }

   _route_triage() {
     local _inbox="$1" _url="$2" _verdict="$3"
     local _tid
     _tid="$(printf '%s' "$_url" | shasum -a 256 | awk '{print substr($1,1,8)}')"
     {
       printf -- '---\n'
       printf 'comment_url: "%s"\n' "$_url"
       printf 'class: "ambiguous"\n'
       printf 'conversus_verdict: "%s"\n' "$_verdict"
       printf 'queued_at: "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
       printf -- '---\n\n## Source comment\n\n'
       cat "$_inbox"
     } > "${TRIAGE_DIR}/T-${_tid}.md"
   }

   _route_class() {
     # _route_class <inbox> <url> <class> <conf>
     local _inbox="$1" _url="$2" _cls="$3" _conf="$4"
     local _thr
     _thr="$(_read_threshold "$_cls")"
     case "$_cls" in
       uat-bug)
         if _ge "$_conf" "$_thr"; then
           # Auto-apply via M013/FR-10 UAT ingestion path (shellout; tolerant
           # to missing entry-point in hermetic test).
           if [ -x "${PROJECT_ROOT}/scripts/integrations/uat-ingest.sh" ]; then
             bash "${PROJECT_ROOT}/scripts/integrations/uat-ingest.sh" --comment "$_url" --body-file "$_inbox" >/dev/null 2>&1 || true
           fi
           _emit_actioned "$_url" "uat-bug" "auto-apply-uat-bug" "github"
         else
           _queue_amendment "$_inbox" "$_url" "$_conf" >/dev/null
         fi
         ;;
       decision-append)
         if _ge "$_conf" "$_thr"; then
           local _now
           _now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
           # Append a templated block to .orchestrator/DECISIONS.md.
           {
             printf '\n<!-- decision-append from %s at %s -->\n' "$_url" "$_now"
             printf '| Dauto | from comment %s (%s) | (operator review) | (body below) | (rationale below) | (operator review) |\n' "$_url" "$_now"
           } >> "$DECISIONS_FILE"
           _emit_actioned "$_url" "decision-append" "auto-apply-decision-append" "github"
         else
           _queue_amendment "$_inbox" "$_url" "$_conf" >/dev/null
         fi
         ;;
       spec-amendment)
         _queue_amendment "$_inbox" "$_url" "$_conf" >/dev/null
         ;;
       ambiguous)
         _route_ambiguous "$_inbox" "$_url"
         ;;
     esac
   }

   _classify_pipeline() {
     local _start_ms="$(date +%s)"
     # Run fetch first.
     bash "$FETCH" "$@" >/dev/null
     local _classified=0 _applied=0 _queued=0 _conv=0
     for f in "$INBOX_DIR"/*.json; do
       [ -f "$f" ] || continue
       local _url _verdict _cls _conf
       _url="$(awk '/"url":/ { sub(/.*"url":[[:space:]]*"/, ""); sub(/",.*/, ""); print; exit }' "$f")"
       if _is_actioned "$_url"; then continue; fi
       _verdict="$(bash "$CLASSIFY" "$f" 2>/dev/null)"
       _cls="$(printf '%s' "$_verdict" | grep -oE '^class=[a-z-]+' | sed 's/^class=//')"
       _conf="$(printf '%s' "$_verdict" | grep -oE 'confidence=[0-9.]+' | sed 's/^confidence=//')"
       _classified=$((_classified+1))
       if [ "$_cls" = "ambiguous" ]; then _conv=$((_conv+1)); fi
       _route_class "$f" "$_url" "$_cls" "$_conf"
     done
     local _elapsed_ms=$(( ( $(date +%s) - _start_ms ) * 1000 ))
     printf '{"event":"unit_close","command":"comments classify","comments_classified":%d,"comments_auto_applied":%d,"comments_queued":%d,"conversus_invocations":%d,"elapsed_ms":%d,"source":"runtime"}\n' \
       "$_classified" "$_applied" "$_queued" "$_conv" "$_elapsed_ms" >> "$EXEC_LOG"
     printf 'SUMMARY: comments classify classified=%d conv=%d\n' "$_classified" "$_conv"
   }

   _status_pipeline() {
     local _count=0
     for f in "$QUEUE_DIR"/*.md; do
       [ -f "$f" ] || continue
       _count=$((_count+1))
       local _id _url _cls
       _id="$(basename "$f" .md)"
       _url="$(awk '/^comment_url:/ { sub(/^comment_url:[[:space:]]*/, ""); print; exit }' "$f")"
       _cls="$(awk '/^class:/ { sub(/^class:[[:space:]]*/, ""); print; exit }' "$f")"
       printf '%s\t%s\t%s\n' "$_id" "$_cls" "$_url"
     done
     printf 'SUMMARY: queued=%d\n' "$_count"
   }

   _reclassify_pipeline() {
     # _reclassify_pipeline <comment-url>
     local _url="$1"
     [ -n "$_url" ] || { printf 'FAIL: reclassify requires <comment-url>\n' >&2; exit 2; }
     # Find the inbox file by URL match.
     local _hit=""
     for f in "$INBOX_DIR"/*.json; do
       [ -f "$f" ] || continue
       if grep -F -q "$_url" "$f"; then _hit="$f"; break; fi
     done
     if [ -z "$_hit" ]; then printf 'FAIL: no inbox entry matches URL %s\n' "$_url" >&2; exit 2; fi
     local _verdict _cls _conf
     _verdict="$(bash "$CLASSIFY" "$_hit" 2>/dev/null)"
     _cls="$(printf '%s' "$_verdict" | grep -oE '^class=[a-z-]+' | sed 's/^class=//')"
     _conf="$(printf '%s' "$_verdict" | grep -oE 'confidence=[0-9.]+' | sed 's/^confidence=//')"
     _route_class "$_hit" "$_url" "$_cls" "$_conf"
     printf 'PASS: reclassify %s as %s (conf=%s)\n' "$_url" "$_cls" "$_conf"
   }

   SUBCMD="${1:-}"
   shift || true
   case "$SUBCMD" in
     classify) _classify_pipeline "$@" ;;
     status) _status_pipeline ;;
     apply) bash "$APPLY" "$@" ;;
     reject) bash "$REJECT" "$@" ;;
     triage) bash "$TRIAGE" "$@" ;;
     reclassify) _reclassify_pipeline "$@" ;;
     ""|--help|-h) sed -n '2,15p' "$0"; exit 0 ;;
     *) printf 'FAIL: unknown subcommand %s\n' "$SUBCMD" >&2; exit 2 ;;
   esac
   ```

3. **Make `comments.sh` executable**:

   ```bash
   chmod +x scripts/comments/comments.sh
   ```

4. **Create `scripts/verify/m014-p03-pipeline.sh`** (~120 lines): hermetic scratch project; seed 4-comment fixture; run `comments.sh classify --yes`; assert classified=4, queued/auto-applied counters match expectations, JSONL events emitted, queue + triage files exist.

5. **Create `scripts/verify/m014-p03-auto-apply.sh`** (~80 lines): assert auto-apply thresholds:
   - High-confidence uat-bug → comment_actioned `auto-apply-uat-bug` event lands.
   - High-confidence decision-append → DECISIONS.md gets a new templated row + actioned event.
   - Low-confidence uat-bug → goes to queue, not auto-applied.
   - High-confidence spec-amendment → ALWAYS queued (CON-5/SC-5 invariant retest).

6. **Create `scripts/verify/m014-p03-observability.sh`** (~60 lines): exercise pipeline; assert `unit_close` records contain the FR-16 fields (`comments_classified`, `comments_auto_applied`, `comments_queued`, `conversus_invocations`, `elapsed_ms`, `source: "runtime"`); assert at least one `comment_actioned` record contains the FR-10 fields (`comment_url`, `class`, `action_taken`, `source_surface`).

7. **Run all three T04 verifiers**:

   ```bash
   bash scripts/verify/m014-p03-pipeline.sh
   bash scripts/verify/m014-p03-auto-apply.sh
   bash scripts/verify/m014-p03-observability.sh
   ```

   All three must exit 0.

## Must-Haves

Addresses phase must-haves:
- "Truth: comments.sh master pipeline routes per-class correctly"
- "Truth: auto-apply path emits comment_actioned JSONL with FR-10/FR-16 fields"
- "Truth: ambiguous routes through conversus adapter (--strict); on adapter unavailability or block, routes to human triage"
- "Truth: observability emission (FR-16) carries unit_close + comment_actioned with required fields"

## Verification

```
bash scripts/verify/m014-p03-pipeline.sh
bash scripts/verify/m014-p03-auto-apply.sh
bash scripts/verify/m014-p03-observability.sh
```

All exit 0.

## Inputs

### From Previous Tasks

- `scripts/comments/fetch.sh` (T01) — produces inbox JSON.
- `scripts/comments/classify.sh` (T02) — emits class+confidence+reason on stdout.
- `scripts/comments/{apply,reject,triage}.sh` (T03) — sub-action surfaces.
- `commands/comments.md` (T03) — user-facing surface this script implements.
- `templates/conversus-presets/classify-comment.yml` (T02) — invoked by ambiguous-routing.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/tool/conversus.sh` (M011/P07) — invoked via `gate classify-comment`. Not modified.
- `scripts/integrations/uat-ingest.sh` (M013/P04, IF SHIPPED) — invoked best-effort under uat-bug auto-apply. Tolerant to absence (no-op stub fallback).
- `.orchestrator/DECISIONS.md` — appended to under decision-append auto-apply.
- `.orchestrator/execution-log.jsonl` — appended to under FR-16 emission.

## Constraints

- **CON-4**: invokes `scripts/dispatch/adapters/tool/conversus.sh` via `gate <preset>` interface only; does not duplicate deliberation logic; uses `--strict`; on adapter unavailability routes to human triage with `WARN:` diagnostic (M013/FR-13 inheritance).
- **CON-5 / SC-5**: spec-amendment ALWAYS queues regardless of confidence; auto-apply paths exist only for `uat-bug` and `decision-append`. Verifier asserts.
- **CON-3 / SC-7**: `--yes` resolves all prompts; verifier asserts no approval-prompt strings on the primary path under `--yes`.
- **CON-6 / MEM001 Bash 3.2**: no `${var,,}`; awk is used for float comparison + YAML scalar reads; `mapfile` and `declare -A` are not used.
- **AD-19**: every Check is `bash scripts/verify/m014-p03-<name>.sh`; no inline compounds beyond `&&`/`||` of two commands.
- **D007 reuse**: T04 does not modify the conversus adapter.
- **CON-8 idempotency**: re-running `classify` skips actioned URLs; re-running on a clean slate produces deterministic queue + triage filenames keyed by URL shasum.

## Expected Output

- `scripts/comments/comments.sh` created (~250-310 lines).
- Three verifiers under `scripts/verify/m014-p03-{pipeline,auto-apply,observability}.sh` (~80-130 lines each).
- All three verifiers exit 0 with `PASS:` final lines.
