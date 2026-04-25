#!/usr/bin/env bash
# scripts/comments/reject.sh
# FR-1 — mark a queue item rejected.
#
# Usage: reject.sh <queue-id> --reason "<prose>"
#
# Behavior:
#   1. Reads .orchestrator/comments/review-queue/<queue-id>.md.
#   2. Appends actioned.jsonl row {applied:false, queue_id, reason}.
#   3. Does not mutate any spec file.
#
# Hermetic test hook:
#   ORCHESTRATOR_PROJECT_ROOT — overrides project root resolution.
#
# CON-6 / MEM001: Bash 3.2. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${ORCHESTRATOR_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
ORCH_ROOT="${PROJECT_ROOT}/.orchestrator"
QUEUE_DIR="${ORCH_ROOT}/comments/review-queue"
ACTIONED_LOG="${ORCH_ROOT}/comments/actioned.jsonl"

_queue_id="${1:-}"
shift || true

_reason=""
while [ $# -gt 0 ]; do
  case "$1" in
    --reason)
      shift
      _reason="${1:-}"
      ;;
    *)
      printf 'FAIL: reject.sh: unknown arg %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift || true
done

if [ -z "$_queue_id" ]; then
  printf 'FAIL: reject.sh: queue-id required as $1\n' >&2
  exit 2
fi
if [ -z "$_reason" ]; then
  printf 'FAIL: reject.sh: --reason "<prose>" required\n' >&2
  exit 2
fi

_queue_file="${QUEUE_DIR}/${_queue_id}.md"
if [ ! -f "$_queue_file" ]; then
  printf 'FAIL: reject.sh: queue-id %s not found at %s\n' "$_queue_id" "$_queue_file" >&2
  exit 2
fi

_comment_url="$(awk '/^comment_url:/ { sub(/^comment_url:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }' "$_queue_file")"
_class="$(awk '/^class:/ { sub(/^class:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }' "$_queue_file")"
_now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Escape reason for JSONL — strip embedded double-quotes (basic safety).
_reason_escaped="$(printf '%s' "$_reason" | tr '"' "'")"

mkdir -p "$(dirname "$ACTIONED_LOG")"
touch "$ACTIONED_LOG"

printf '{"comment_url":"%s","actioned_at":"%s","class":"%s","applied":false,"queue_id":"%s","reason":"%s","action_taken":"reject-queue-item"}\n' \
  "$_comment_url" "$_now" "$_class" "$_queue_id" "$_reason_escaped" >> "$ACTIONED_LOG"

printf 'PASS: reject.sh: queue-id %s rejected (reason=%s)\n' "$_queue_id" "$_reason_escaped"
exit 0
