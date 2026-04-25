#!/usr/bin/env bash
# scripts/comments/comments.sh
# M014/P03/T04 master pipeline — orchestrator:comments subcommand surface.
#
# Wires T01 fetch + T02 classify + T03 apply/reject/triage primitives into
# the user-visible classify / status / apply / reject / triage / reclassify
# subcommand flow. Auto-apply paths exist ONLY for the trivial classes
# (uat-bug, decision-append). The amendment class — see CON-5 / SC-5 — is
# always queued for human sign-off; the manual gate at scripts/comments/
# apply.sh is the single path for spec mutation from a comment-class verdict.
# This invariant is mechanically asserted by
# scripts/verify/m014-p03-spec-amendment-human-gate.sh.
#
# FR coverage: FR-1 (subcommand surface), FR-9 (per-class routing),
# FR-10 (comment_actioned event), FR-11 (review-queue convention),
# FR-16 (unit_close observability).
#
# Hermetic test hooks:
#   ORCHESTRATOR_PROJECT_ROOT=<dir>  Override project root resolution.
#   COMMENTS_FETCH=<path>            Override scripts/comments/fetch.sh path.
#   COMMENTS_ADAPTER=<path>          Override conversus adapter path.
#   COMMENTS_UAT_INGEST=<path>       Override M013 UAT ingestion entry point.
#   GH_API_STUB / GH_GRAPHQL_STUB    Forwarded to fetch.sh.
#
# CON-3 / SC-7 zero-prompts: --yes resolves all prompts to documented
# defaults. The classify / status / reclassify subcommand bodies emit no
# interactive reads; apply/reject/triage delegate to the T03 primitives,
# which are themselves zero-prompt under --yes.
#
# CON-4: ambiguous-class comments route to
# scripts/dispatch/adapters/tool/conversus.sh via `gate <preset> <input>
# <output> --strict`. Adapter unavailability or BLOCK / low-confidence
# verdict routes to the human triage bucket (M013/FR-13 inheritance).
# This script does NOT modify the conversus adapter (D007 reuse).
#
# CON-6 / MEM001 Bash 3.2: no declare -A, no mapfile, no ${var,,}, no
# process substitution, no &>. awk is used for float compare + YAML scalar
# read. AD-19 single-script-file shape — every Check is a single bash
# scripts/verify/m014-p03-<name>.sh invocation.
#
# CON-8 idempotency: re-running classify skips actioned URLs (delegated to
# fetch.sh + the actioned.jsonl gate inside the loop). Queue + triage
# filenames are deterministic shasum prefixes of the comment URL, so
# re-running on a clean slate produces the same filenames.

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

# Resolve sub-scripts. Tests can override via env to point at stubs.
ADAPTER="${COMMENTS_ADAPTER:-${PROJECT_ROOT}/scripts/dispatch/adapters/tool/conversus.sh}"
CLASSIFY="${COMMENTS_CLASSIFY:-${SCRIPT_DIR}/classify.sh}"
FETCH="${COMMENTS_FETCH:-${SCRIPT_DIR}/fetch.sh}"
APPLY="${COMMENTS_APPLY:-${SCRIPT_DIR}/apply.sh}"
REJECT="${COMMENTS_REJECT:-${SCRIPT_DIR}/reject.sh}"
TRIAGE="${COMMENTS_TRIAGE:-${SCRIPT_DIR}/triage.sh}"
UAT_INGEST="${COMMENTS_UAT_INGEST:-${PROJECT_ROOT}/scripts/integrations/uat-ingest.sh}"

mkdir -p "$INBOX_DIR" "$QUEUE_DIR" "$TRIAGE_DIR"
mkdir -p "$(dirname "$EXEC_LOG")"
mkdir -p "$(dirname "$ACTIONED_LOG")"
touch "$ACTIONED_LOG"
touch "$EXEC_LOG"

# ---------- helpers ----------

# _read_threshold <class>
# Read comments.auto_apply_threshold.<class> from config.yml. Falls back to
# 0.8 when the file or key is absent.
_read_threshold() {
  _cls="$1"
  _val=""
  if [ -f "$CONFIG_FILE" ]; then
    _val="$(awk -v cls="$_cls" '
      BEGIN { in_c=0; in_t=0 }
      /^[[:space:]]*comments:[[:space:]]*$/ { in_c=1; next }
      in_c && /^[[:space:]]*auto_apply_threshold:[[:space:]]*$/ { in_t=1; next }
      in_t {
        line=$0
        if (line !~ /^[[:space:]]+/) { in_t=0; in_c=0; next }
        sub(/^[[:space:]]+/, "", line)
        n=split(line, parts, ":")
        if (n >= 2) {
          k=parts[1]
          v=parts[2]
          sub(/^[[:space:]]+/, "", v)
          sub(/[[:space:]]+$/, "", v)
          if (k == cls) { print v; exit }
        }
      }
      in_c && !/^[[:space:]]/ { in_c=0; in_t=0 }
    ' "$CONFIG_FILE" 2>/dev/null)"
  fi
  if [ -z "$_val" ]; then
    printf '0.8'
  else
    printf '%s' "$_val"
  fi
}

# _ge <a> <b>
# Float-safe greater-or-equal compare via awk (Bash 3.2 has no float math).
_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a+0 >= b+0) }'
}

# _is_actioned <url>
# Returns 0 if the URL appears in actioned.jsonl, 1 otherwise.
_is_actioned() {
  _url="$1"
  [ -f "$ACTIONED_LOG" ] || return 1
  grep -F -- "\"comment_url\":\"$_url\"" "$ACTIONED_LOG" >/dev/null 2>&1
}

# _qid <url>
# Deterministic 8-char shasum prefix of the URL — used as the queue/triage
# filename suffix for idempotency.
_qid() {
  printf '%s' "$1" | shasum -a 256 | awk '{print substr($1,1,8)}'
}

# _emit_actioned <url> <class> <action_taken> <surface> <confidence>
# Append a row to actioned.jsonl + emit a comment_actioned event to
# execution-log.jsonl. Carries the FR-10 fields.
_emit_actioned() {
  _url="$1"; _cls="$2"; _act="$3"; _surf="$4"; _conf="$5"
  _now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"comment_url":"%s","actioned_at":"%s","class":"%s","applied":true,"action_taken":"%s"}\n' \
    "$_url" "$_now" "$_cls" "$_act" >> "$ACTIONED_LOG"
  printf '{"event":"comment_actioned","comment_url":"%s","class":"%s","confidence":"%s","action_taken":"%s","source_surface":"%s","timestamp":"%s"}\n' \
    "$_url" "$_cls" "$_conf" "$_act" "$_surf" "$_now" >> "$EXEC_LOG"
}

# _queue_item <inbox-file> <url> <class> <conf>
# Write a review-queue entry for the human-gated flow. Returns the queue id
# on stdout. Used for the amendment class (always) and for low-confidence
# trivial classes that fall below their auto-apply threshold.
_queue_item() {
  _inbox="$1"; _url="$2"; _cls="$3"; _conf="$4"
  _id="$(_qid "$_url")"
  _qfile="${QUEUE_DIR}/Q-${_id}.md"
  {
    printf -- '---\n'
    printf 'comment_url: "%s"\n' "$_url"
    printf 'class: "%s"\n' "$_cls"
    printf 'confidence: "%s"\n' "$_conf"
    printf 'queued_at: "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'queue_id: "Q-%s"\n' "$_id"
    printf -- '---\n\n'
    printf '## Source comment\n\n'
    cat "$_inbox"
    printf '\n\n## Proposed change\n\nOperator must author the change before `apply Q-%s`.\n' "$_id"
  } > "$_qfile"
  printf 'Q-%s' "$_id"
}

# _route_triage <inbox-file> <url> <verdict-tag>
# Park a comment in the human-triage bucket with a verdict tag explaining
# why automated routing punted (adapter-missing | conversus-block-or-low-conf).
_route_triage() {
  _inbox="$1"; _url="$2"; _verdict="$3"
  _tid="$(_qid "$_url")"
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

# _route_ambiguous <inbox-file> <url>
# CON-4 path: invoke conversus gate classify-comment with --strict.
# - Adapter not executable → triage with reason=adapter-missing.
# - Adapter exit 0 AND verdict file declares a non-ambiguous class → re-route
#   to the new class via _route_class (with a low-but-positive 0.6 confidence
#   so high-threshold trivial classes still queue).
# - Otherwise → triage with reason=conversus-block-or-low-conf.
#
# Returns: 1 if the comment was reclassified out of ambiguous (caller
# treats it as "the conversus invocation produced a class"); 0 if the
# comment landed in triage. Either way the comment is fully routed.
_route_ambiguous() {
  _inbox="$1"; _url="$2"
  if [ ! -x "$ADAPTER" ]; then
    printf 'WARN: conversus adapter not executable at %s; routing %s to human triage\n' "$ADAPTER" "$_url" >&2
    _route_triage "$_inbox" "$_url" "adapter-missing"
    return 0
  fi
  _vfile="$(mktemp)"
  bash "$ADAPTER" gate classify-comment "$_inbox" "$_vfile" --strict >/dev/null 2>&1
  _rc=$?
  if [ "$_rc" -eq 0 ]; then
    _new_class="$(grep -oE 'class=[a-z-]+' "$_vfile" 2>/dev/null | head -n 1 | sed 's/class=//')"
    rm -f "$_vfile"
    if [ -n "$_new_class" ] && [ "$_new_class" != "ambiguous" ]; then
      printf 'INFO: conversus reclassified %s as %s\n' "$_url" "$_new_class" >&2
      _route_class "$_inbox" "$_url" "$_new_class" "0.6"
      return 1
    fi
    _route_triage "$_inbox" "$_url" "conversus-pass-without-class-line"
    return 0
  fi
  rm -f "$_vfile"
  _route_triage "$_inbox" "$_url" "conversus-block-or-low-conf"
  return 0
}

# _route_class <inbox-file> <url> <class> <conf>
# Per-class router. Updates the global counters _CL_APPLIED and _CL_QUEUED
# (used by the classify-pipeline observability summary). Auto-apply gates:
#   - uat-bug    (conf >= threshold)  → invoke M013 UAT ingest, emit comment_actioned.
#   - decision-append (conf >= threshold) → append templated row to
#     .orchestrator/DECISIONS.md, emit comment_actioned.
# Below-threshold trivial classes queue for human review. The amendment
# class always queues regardless of confidence (CON-5 / SC-5).
_CL_APPLIED=0
_CL_QUEUED=0
_route_class() {
  _inbox="$1"; _url="$2"; _cls="$3"; _conf="$4"
  _thr="$(_read_threshold "$_cls")"
  case "$_cls" in
    uat-bug)
      if _ge "$_conf" "$_thr"; then
        # M013 UAT ingestion path (FR-10). Best-effort: missing entry-point
        # under hermetic test is tolerated as a no-op (the `auto-apply-uat-bug`
        # event still lands so observability captures the decision).
        if [ -x "$UAT_INGEST" ]; then
          bash "$UAT_INGEST" --comment "$_url" --body-file "$_inbox" >/dev/null 2>&1 || true
        fi
        _emit_actioned "$_url" "uat-bug" "auto-apply-uat-bug" "github" "$_conf"
        _CL_APPLIED=$((_CL_APPLIED + 1))
      else
        _queue_item "$_inbox" "$_url" "$_cls" "$_conf" >/dev/null
        _CL_QUEUED=$((_CL_QUEUED + 1))
      fi
      ;;
    decision-append)
      if _ge "$_conf" "$_thr"; then
        _now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        # Append a templated decision-append row referencing the source
        # comment URL. The operator review pass populates the rationale
        # before the row is promoted into the canonical D-table.
        if [ -f "$DECISIONS_FILE" ]; then
          {
            printf '\n<!-- decision-append from %s at %s -->\n' "$_url" "$_now"
            printf '| Dauto | from comment %s (%s) | (operator review) | (body below) | (rationale below) | (operator review) |\n' \
              "$_url" "$_now"
          } >> "$DECISIONS_FILE"
        fi
        _emit_actioned "$_url" "decision-append" "auto-apply-decision-append" "github" "$_conf"
        _CL_APPLIED=$((_CL_APPLIED + 1))
      else
        _queue_item "$_inbox" "$_url" "$_cls" "$_conf" >/dev/null
        _CL_QUEUED=$((_CL_QUEUED + 1))
      fi
      ;;
    spec-amendment)
      # Human-gated path. CON-5 / SC-5 — every comment in this class queues
      # regardless of confidence; the operator runs apply.sh when ready.
      _queue_item "$_inbox" "$_url" "spec-amendment" "$_conf" >/dev/null
      _CL_QUEUED=$((_CL_QUEUED + 1))
      ;;
    ambiguous)
      _route_ambiguous "$_inbox" "$_url"
      ;;
    *)
      printf 'WARN: unknown class %s for %s; routing to triage\n' "$_cls" "$_url" >&2
      _route_triage "$_inbox" "$_url" "unknown-class-${_cls}"
      ;;
  esac
}

# ---------- subcommand bodies ----------

_classify_pipeline() {
  _start_s="$(date +%s)"
  bash "$FETCH" "$@" >/dev/null
  _classified=0
  _conv=0
  _CL_APPLIED=0
  _CL_QUEUED=0
  for _f in "$INBOX_DIR"/*.json; do
    [ -f "$_f" ] || continue
    _url="$(awk '
      /"url"[[:space:]]*:/ {
        sub(/.*"url"[[:space:]]*:[[:space:]]*"/, "")
        sub(/".*/, "")
        print
        exit
      }
    ' "$_f")"
    [ -z "$_url" ] && continue
    if _is_actioned "$_url"; then continue; fi
    _verdict="$(bash "$CLASSIFY" "$_f" 2>/dev/null)"
    _cls="$(printf '%s' "$_verdict" | grep -oE '^class=[a-z-]+' | sed 's/^class=//')"
    _conf="$(printf '%s' "$_verdict" | grep -oE 'confidence=[0-9.]+' | sed 's/^confidence=//')"
    [ -z "$_cls" ] && _cls="ambiguous"
    [ -z "$_conf" ] && _conf="0.0"
    _classified=$((_classified + 1))
    if [ "$_cls" = "ambiguous" ]; then
      _conv=$((_conv + 1))
    fi
    _route_class "$_f" "$_url" "$_cls" "$_conf"
  done
  _elapsed_s=$(( $(date +%s) - _start_s ))
  _elapsed_ms=$((_elapsed_s * 1000))
  printf '{"event":"unit_close","command":"comments classify","comments_classified":%d,"comments_auto_applied":%d,"comments_queued":%d,"conversus_invocations":%d,"elapsed_ms":%d,"source":"runtime"}\n' \
    "$_classified" "$_CL_APPLIED" "$_CL_QUEUED" "$_conv" "$_elapsed_ms" >> "$EXEC_LOG"
  printf 'SUMMARY: comments classify classified=%d applied=%d queued=%d conv=%d\n' \
    "$_classified" "$_CL_APPLIED" "$_CL_QUEUED" "$_conv"
}

_status_pipeline() {
  _count=0
  for _f in "$QUEUE_DIR"/*.md; do
    [ -f "$_f" ] || continue
    _count=$((_count + 1))
    _id="$(basename "$_f" .md)"
    _url="$(awk '/^comment_url:/ { sub(/^comment_url:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }' "$_f")"
    _cls="$(awk '/^class:/ { sub(/^class:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }' "$_f")"
    _conf="$(awk '/^confidence:/ { sub(/^confidence:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }' "$_f")"
    printf '%s\t%s\tconf=%s\t%s\n' "$_id" "$_cls" "$_conf" "$_url"
  done
  printf 'SUMMARY: queued=%d\n' "$_count"
}

_reclassify_pipeline() {
  _url="${1:-}"
  if [ -z "$_url" ]; then
    printf 'FAIL: reclassify requires <comment-url>\n' >&2
    exit 2
  fi
  _hit=""
  for _f in "$INBOX_DIR"/*.json; do
    [ -f "$_f" ] || continue
    if grep -F -q "$_url" "$_f"; then _hit="$_f"; break; fi
  done
  if [ -z "$_hit" ]; then
    printf 'FAIL: no inbox entry matches URL %s\n' "$_url" >&2
    exit 2
  fi
  _verdict="$(bash "$CLASSIFY" "$_hit" 2>/dev/null)"
  _cls="$(printf '%s' "$_verdict" | grep -oE '^class=[a-z-]+' | sed 's/^class=//')"
  _conf="$(printf '%s' "$_verdict" | grep -oE 'confidence=[0-9.]+' | sed 's/^confidence=//')"
  [ -z "$_cls" ] && _cls="ambiguous"
  [ -z "$_conf" ] && _conf="0.0"
  _CL_APPLIED=0
  _CL_QUEUED=0
  _route_class "$_hit" "$_url" "$_cls" "$_conf"
  printf 'PASS: reclassify %s as %s (conf=%s)\n' "$_url" "$_cls" "$_conf"
}

_print_help() {
  cat <<'EOF'
orchestrator:comments — comment-to-workflow classifier with human-gated apply.

Subcommands:
  classify [--dry-run] [--yes]   Fetch + classify + route per FR-9 classes.
  status                         List review-queue entries.
  apply <queue-id>               Apply an operator-approved amendment (T03).
  reject <queue-id> --reason "<prose>"
                                 Mark a queue item rejected (T03).
  triage                         List human-triage bucket entries (T03).
  reclassify <comment-url>       Re-classify a single URL bypassing the
                                 actioned.jsonl idempotency gate.

Auto-apply gates (FR-10):
  uat-bug + conf >= comments.auto_apply_threshold.uat-bug          (default 0.8)
  decision-append + conf >= comments.auto_apply_threshold.decision-append
                                                                    (default 0.8)
  amendment class                                                   ALWAYS queues (CON-5/SC-5)
  ambiguous                                                         conversus --strict; on
                                                                    block / low-conf / adapter
                                                                    missing → human triage
EOF
}

# ---------- entry point ----------

SUBCMD="${1:-}"
shift || true
case "$SUBCMD" in
  classify) _classify_pipeline "$@" ;;
  status) _status_pipeline ;;
  apply) bash "$APPLY" "$@" ;;
  reject) bash "$REJECT" "$@" ;;
  triage) bash "$TRIAGE" "$@" ;;
  reclassify) _reclassify_pipeline "$@" ;;
  ""|--help|-h) _print_help ;;
  *)
    printf 'FAIL: unknown subcommand %s\n' "$SUBCMD" >&2
    exit 2
    ;;
esac

exit 0
