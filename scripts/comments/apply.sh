#!/usr/bin/env bash
# scripts/comments/apply.sh
# FR-1 + US-5 — apply an operator-approved spec-amendment queue item.
# CON-5 / SC-5: spec-amendment class is human-gated; this is the ONLY path
# for spec mutation from comments. The classifier and pipeline never auto-
# apply spec-amendment regardless of confidence — every spec-amendment-class
# verdict queues for human sign-off, and this script is the single
# operator-driven exit point.
#
# Behavior:
#   1. Reads .orchestrator/comments/review-queue/<queue-id>.md.
#   2. Validates class==spec-amendment (other classes have their own auto-
#      apply paths in T04 pipeline).
#   3. Refuses if in-flight conversus deliberation exists at the target spec
#      directory (US-5 AS-4 — no interleaving authorship + amendment).
#   4. Extracts proposed diff from ```diff fenced block in queue file body.
#   5. Refuses on stale diff (US-5 AS-2) via patch --dry-run probe.
#   6. Applies the diff with patch -p1.
#   7. Invokes scripts/knowledge/rebuild-index.sh (best-effort).
#   8. Appends actioned.jsonl row {applied:true, queue_id}.
#   9. Emits comment_actioned event to execution-log.jsonl.
#
# Hermetic test hook:
#   ORCHESTRATOR_PROJECT_ROOT — overrides project root resolution. Used by
#   scripts/verify/m014-p03-apply.sh to point apply.sh at a scratch repo.
#
# CON-6 / MEM001: Bash 3.2 — no declare -A, no mapfile, no ${var,,}, no
# process substitution, no &>. AD-19 single-script-file shape.
#
# References:
#   - M014 spec line 116-128 (US-5) — apply contract.
#   - M014 spec line 64 (AS-4) and line 245 (SC-5) — human-gate invariant.
#   - .orchestrator/DECISIONS.md D023 — regex/heuristic v1 baseline.

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

# Extract frontmatter fields via awk. Frontmatter is ---fenced YAML at the
# top of the queue file; we read each named key once.
_comment_url="$(awk '/^comment_url:/ { sub(/^comment_url:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }' "$_queue_file")"
_target_spec="$(awk '/^target_spec_path:/ { sub(/^target_spec_path:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }' "$_queue_file")"
_class="$(awk '/^class:/ { sub(/^class:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }' "$_queue_file")"

# Guard 1: only spec-amendment class is applied via this path.
# Other classes have their own auto-apply pipeline (T04); manual apply is
# reserved for spec-amendment per CON-5/SC-5.
if [ "$_class" != "spec-amendment" ]; then
  printf 'FAIL: apply.sh: queue item class=%s; expected spec-amendment (other classes auto-apply via classify pipeline)\n' "$_class" >&2
  exit 2
fi

# Guard 2: in-flight conversus deliberation refuses apply (US-5 AS-4).
# A deliberation is "in flight" if the conversus/ directory exists but no
# summary/final.md has been written yet.
if [ -n "$_target_spec" ]; then
  _spec_dir="$(dirname "${PROJECT_ROOT}/${_target_spec}")"
  if [ -d "${_spec_dir}/conversus" ]; then
    if [ ! -f "${_spec_dir}/conversus/summary/final.md" ]; then
      printf 'FAIL: apply.sh: deliberation in progress at %s/conversus/; complete or abort before applying amendments\n' "$_spec_dir" >&2
      exit 2
    fi
  fi
fi

# Extract proposed-diff body from a ```diff ... ``` fenced block in the
# queue file body. Only the FIRST diff block is honored.
_diff_file="$(mktemp)"
awk '
  /^```diff[[:space:]]*$/ { in_diff=1; next }
  /^```[[:space:]]*$/ && in_diff==1 { in_diff=0; exit }
  in_diff==1 { print }
' "$_queue_file" > "$_diff_file"

if [ ! -s "$_diff_file" ]; then
  printf 'FAIL: apply.sh: queue item has no proposed-diff body (expected ```diff ... ``` fenced block)\n' >&2
  rm -f "$_diff_file"
  exit 2
fi

# Stale-diff detection — dry-apply via patch --dry-run with -N (forward-only).
# -N makes patch return non-zero when the diff is already applied or reversed,
# which is the operative "stale-diff" signal for US-5 AS-2.
if ! patch -N --dry-run -p1 -d "$PROJECT_ROOT" < "$_diff_file" >/dev/null 2>&1; then
  printf 'FAIL: apply.sh: stale-diff — proposed diff no longer applies cleanly (already applied, reversed, or context drifted). Operator must re-classify or refresh manually.\n' >&2
  rm -f "$_diff_file"
  exit 2
fi

# Apply for real (also -N to refuse reverse-apply on race).
patch -N -p1 -d "$PROJECT_ROOT" < "$_diff_file" >/dev/null 2>&1
_rc=$?
if [ "$_rc" -ne 0 ]; then
  printf 'FAIL: apply.sh: patch exited %d after dry-run succeeded -- manual investigation required\n' "$_rc" >&2
  rm -f "$_diff_file"
  exit 1
fi
rm -f "$_diff_file"

# Invoke rebuild-index (best-effort; warn on failure).
if [ -x "${PROJECT_ROOT}/scripts/knowledge/rebuild-index.sh" ]; then
  bash "${PROJECT_ROOT}/scripts/knowledge/rebuild-index.sh" >/dev/null 2>&1 || printf 'WARN: rebuild-index returned non-zero; index may be stale\n' >&2
fi

# Ensure log dirs exist.
mkdir -p "$(dirname "$ACTIONED_LOG")"
mkdir -p "$(dirname "$EXEC_LOG")"
touch "$ACTIONED_LOG"
touch "$EXEC_LOG"

# Append to actioned.jsonl per T01 contract:
#   {comment_url, actioned_at, class, applied, queue_id?, reason?, action_taken?}
_now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"comment_url":"%s","actioned_at":"%s","class":"%s","applied":true,"queue_id":"%s","action_taken":"apply-amendment"}\n' \
  "$_comment_url" "$_now" "$_class" "$_queue_id" >> "$ACTIONED_LOG"

# Emit comment_actioned event.
printf '{"event":"comment_actioned","comment_url":"%s","class":"%s","action_taken":"apply-amendment","source_surface":"queue","queue_id":"%s","timestamp":"%s"}\n' \
  "$_comment_url" "$_class" "$_queue_id" "$_now" >> "$EXEC_LOG"

printf 'PASS: apply.sh: queue-id %s applied (class=%s)\n' "$_queue_id" "$_class"
exit 0
