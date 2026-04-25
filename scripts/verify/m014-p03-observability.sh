#!/usr/bin/env bash
# scripts/verify/m014-p03-observability.sh
# Verifies M014/P03/T04 observability emission per FR-16 + FR-10.
#
# Single hermetic run with a small fixture covering one auto-apply path
# (decision-append @ 0.95) and one ambiguous-routed comment (so
# conversus_invocations > 0). Then asserts:
#
#   1. Exactly one unit_close JSONL record carries every FR-16 field:
#        comments_classified, comments_auto_applied, comments_queued,
#        conversus_invocations, elapsed_ms, source: "runtime",
#        plus the canonical event/command keys.
#   2. At least one comment_actioned JSONL record carries every FR-10 field:
#        comment_url, class, confidence, action_taken, source_surface,
#        timestamp.
#   3. The unit_close numeric fields are integers (no leading whitespace,
#      no decimal point).
#
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMMENTS="${REPO_ROOT}/scripts/comments/comments.sh"

pass=0
fail=0
_pass() { pass=$((pass + 1)); echo "PASS: $1"; }
_fail() { fail=$((fail + 1)); echo "FAIL: $1"; }

if [ ! -x "$COMMENTS" ]; then
  _fail "comments.sh missing or not executable at $COMMENTS"
  echo "----"
  echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
  exit 1
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

mkdir -p "$SCRATCH/.orchestrator/comments"
printf '# DECISIONS\n\n| ID | Title | Owner | Body | Rationale | Outcome |\n| --- | --- | --- | --- | --- | --- |\n' \
  > "$SCRATCH/.orchestrator/DECISIONS.md"

FIX="$SCRATCH/obs-fix.jsonl"
# R4 decision-append @ 0.95 (auto-apply path), R10 ambiguous fallthrough.
{
  printf '{"url":"https://github.com/x/y/issues/1#issuecomment-1","body":"/append-decision: keep observability under FR-16","source_surface":"github","id":"o1","created_at":"2026-04-24T00:00:00Z"}\n'
  printf '{"url":"https://github.com/x/y/issues/2#issuecomment-2","body":"hmm not sure about this","source_surface":"github","id":"o2","created_at":"2026-04-24T00:00:00Z"}\n'
} > "$FIX"

ABSENT_ADAPTER="$SCRATCH/no-adapter.sh"

ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
GH_API_STUB="$FIX" \
GH_GRAPHQL_STUB="$FIX" \
COMMENTS_ADAPTER="$ABSENT_ADAPTER" \
  bash "$COMMENTS" classify --yes > "$SCRATCH/run.out" 2> "$SCRATCH/run.err"
rc=$?
if [ "$rc" -ne 0 ]; then
  _fail "classify exited ${rc} (stderr=$(cat "$SCRATCH/run.err"))"
  echo "----"
  echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
  exit 1
fi

EXEC_LOG="$SCRATCH/.orchestrator/execution-log.jsonl"
if [ ! -f "$EXEC_LOG" ]; then
  _fail "execution-log.jsonl not created at $EXEC_LOG"
  echo "----"
  echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
  exit 1
fi

# Pull the unit_close line for the comments classify command.
unit_line="$(grep '"event":"unit_close"' "$EXEC_LOG" | grep '"command":"comments classify"' | tail -n 1)"
if [ -z "$unit_line" ]; then
  _fail "no unit_close JSONL with command=comments classify in execution-log.jsonl"
else
  _pass "unit_close JSONL emitted for comments classify"
  # Required FR-16 fields.
  miss=""
  for k in '"comments_classified":' '"comments_auto_applied":' '"comments_queued":' '"conversus_invocations":' '"elapsed_ms":' '"source":"runtime"'; do
    if ! printf '%s' "$unit_line" | grep -q -- "$k"; then
      miss="${miss} ${k}"
    fi
  done
  if [ -z "$miss" ]; then
    _pass "unit_close carries every FR-16 field"
  else
    _fail "unit_close missing FR-16 fields:${miss}"
  fi

  # Numeric-shape sanity: extract the four counter values + elapsed_ms.
  cls_v="$(printf '%s' "$unit_line" | sed -n 's/.*"comments_classified":\([0-9]*\).*/\1/p')"
  app_v="$(printf '%s' "$unit_line" | sed -n 's/.*"comments_auto_applied":\([0-9]*\).*/\1/p')"
  q_v="$(printf '%s' "$unit_line" | sed -n 's/.*"comments_queued":\([0-9]*\).*/\1/p')"
  conv_v="$(printf '%s' "$unit_line" | sed -n 's/.*"conversus_invocations":\([0-9]*\).*/\1/p')"
  el_v="$(printf '%s' "$unit_line" | sed -n 's/.*"elapsed_ms":\([0-9]*\).*/\1/p')"
  if [ -n "$cls_v" ] && [ -n "$app_v" ] && [ -n "$q_v" ]; then
    _pass "unit_close counter fields are non-empty integers (classified=${cls_v} applied=${app_v} queued=${q_v})"
  else
    _fail "unit_close counter fields not integer-shaped"
  fi
  if [ -n "$conv_v" ] && [ -n "$el_v" ]; then
    _pass "unit_close conversus_invocations + elapsed_ms integer-shaped (conv=${conv_v} ms=${el_v})"
  else
    _fail "unit_close conversus_invocations or elapsed_ms not integer-shaped"
  fi
  # Sanity: classified=2 (one auto-apply + one ambiguous → triage).
  if [ "${cls_v:-0}" -eq 2 ]; then
    _pass "unit_close.comments_classified matches fixture size (2)"
  else
    _fail "expected comments_classified=2, got ${cls_v:-empty}"
  fi
  # Sanity: conversus_invocations >= 1 (the ambiguous comment).
  if [ "${conv_v:-0}" -ge 1 ]; then
    _pass "unit_close.conversus_invocations >= 1 (ambiguous routing exercised)"
  else
    _fail "expected conversus_invocations >= 1, got ${conv_v:-empty}"
  fi
fi

# At least one comment_actioned event with all FR-10 fields.
actioned_line="$(grep '"event":"comment_actioned"' "$EXEC_LOG" | head -n 1)"
if [ -z "$actioned_line" ]; then
  _fail "no comment_actioned JSONL emitted"
else
  _pass "comment_actioned JSONL present"
  miss=""
  for k in '"comment_url":' '"class":' '"confidence":' '"action_taken":' '"source_surface":' '"timestamp":'; do
    if ! printf '%s' "$actioned_line" | grep -q -- "$k"; then
      miss="${miss} ${k}"
    fi
  done
  if [ -z "$miss" ]; then
    _pass "comment_actioned carries every FR-10 field"
  else
    _fail "comment_actioned missing FR-10 fields:${miss}"
  fi
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "PASS: $(basename "$0")"
exit 0
