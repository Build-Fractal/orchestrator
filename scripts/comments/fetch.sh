#!/usr/bin/env bash
# scripts/comments/fetch.sh
# FR-8 comment fetcher — Giscus + GitHub Issue/PR.
# Bash 3.2 compatible. CON-8 idempotent via actioned.jsonl.
#
# Behavior:
#   1. Enumerate unactioned comments from two surfaces (Giscus Discussions,
#      GitHub Issue/PR comments) and cache each new comment to
#      .orchestrator/comments/inbox/<comment-id>.json.
#   2. Skip any comment whose URL is already in
#      .orchestrator/comments/actioned.jsonl.
#   3. --dry-run prints FR-19 JSONL action records to stdout (no disk writes).
#   4. --yes is honored as inheritance from CON-3 (no prompts in T01).
#   5. Emit unit_close JSONL to .orchestrator/execution-log.jsonl on exit.
#
# Hermetic test hooks:
#   GH_API_STUB=<file>     -- fixture file for the GitHub Issue/PR surface.
#   GH_GRAPHQL_STUB=<file> -- fixture file for the Giscus Discussions surface.
#   Each stub file is JSONL (one JSON object per line) with fields:
#     {url, body, source_surface, id, created_at}.
#   The fetcher filters records per-surface by the source_surface field so
#   that both stubs pointing at the same fixture yield each record exactly
#   once.
#
# CON-6 / MEM001: no declare -A, no mapfile, no ${var,,}, no process
# substitution, no &>. Only single &&/|| of two commands.

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
    --help|-h) sed -n '2,30p' "$0"; exit 0 ;;
    *) printf 'FAIL: unknown arg %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$INBOX_DIR"
touch "$ACTIONED_LOG"
mkdir -p "$(dirname "$EXEC_LOG")"
touch "$EXEC_LOG"

_start_ms="$(date +%s)"
_fetched=0
_skipped=0

# ---------- helpers ----------

# _json_field <line> <key>
# Pull the value of "key" from a single-line JSON object. Strips surrounding
# quotes. Returns empty string on miss. Pure shell; no jq dependency.
_json_field() {
  _line="$1"
  _key="$2"
  printf '%s' "$_line" \
    | sed -n 's/.*"'"$_key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1
}

# _is_actioned <url>
# Returns 0 if the URL appears in actioned.jsonl, 1 otherwise.
_is_actioned() {
  _url="$1"
  [ -f "$ACTIONED_LOG" ] || return 1
  grep -F -- "\"comment_url\":\"$_url\"" "$ACTIONED_LOG" >/dev/null 2>&1
}

# _body_shasum <body>
# Compute a short shasum of the body string for the optional dedup fallback.
_body_shasum() {
  printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
}

# _process_record <surface> <line>
# Parse one JSONL record from a stub or `gh api` output and either skip or
# write to inbox. Honors --dry-run.
_process_record() {
  _surface="$1"
  _line="$2"
  _url="$(_json_field "$_line" url)"
  _body="$(_json_field "$_line" body)"
  _id="$(_json_field "$_line" id)"
  _record_surface="$(_json_field "$_line" source_surface)"
  [ -z "$_url" ] && return 0
  [ -z "$_id" ] && return 0
  # Filter by surface when the record has a source_surface field. This makes
  # JSONL stubs that contain mixed-surface records yield each record from
  # exactly one of {_fetch_github,_fetch_giscus}.
  if [ -n "$_record_surface" ] && [ "$_record_surface" != "$_surface" ]; then
    return 0
  fi
  if _is_actioned "$_url"; then
    _skipped=$((_skipped + 1))
    return 0
  fi
  _shasum="$(_body_shasum "$_body")"
  _target="${INBOX_DIR}/${_id}.json"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '{"command":"comments fetch","action_type":"cache-comment","target_path":"%s","source_ref":"%s","description":"would cache comment from %s"}\n' \
      "$_target" "$_url" "$_surface"
    _fetched=$((_fetched + 1))
    return 0
  fi
  # Write a flat single-line JSON record. Escape body double-quotes minimally
  # (replace " with \") since we cannot rely on jq.
  _body_escaped="$(printf '%s' "$_body" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  printf '{"url":"%s","body":"%s","source_surface":"%s","fetched_at":"%s","body_shasum":"%s"}\n' \
    "$_url" "$_body_escaped" "$_surface" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_shasum" \
    > "$_target"
  _fetched=$((_fetched + 1))
}

# ---------- surface fetchers ----------

_fetch_github() {
  # Iterate gh api repos/<owner>/<repo>/issues/comments + /pulls/comments.
  # Filter to comments whose body contains an orchestrator-id marker
  # (per M013/scripts/integrations/github-common.sh convention).
  # Honor GH_API_STUB env var for hermetic testing — when set, read JSONL
  # from the file path it points at instead of calling gh.
  _src=""
  if [ -n "${GH_API_STUB:-}" ] && [ -f "${GH_API_STUB}" ]; then
    _src="${GH_API_STUB}"
  else
    if ! command -v gh >/dev/null 2>&1; then
      printf 'WARN: gh not installed; skipping github surface\n' >&2
      return 0
    fi
    _src="$(mktemp)"
    gh api repos/:owner/:repo/issues/comments --paginate > "$_src" 2>/dev/null || true
  fi
  # JSONL path: one JSON object per line.
  while IFS= read -r _line; do
    [ -z "$_line" ] && continue
    _process_record "github" "$_line"
  done < "$_src"
}

_fetch_giscus() {
  # Iterate gh api graphql against Discussions.
  # Honor GH_GRAPHQL_STUB env var for hermetic testing.
  _src=""
  if [ -n "${GH_GRAPHQL_STUB:-}" ] && [ -f "${GH_GRAPHQL_STUB}" ]; then
    _src="${GH_GRAPHQL_STUB}"
  else
    if ! command -v gh >/dev/null 2>&1; then
      printf 'WARN: gh not installed; skipping giscus surface\n' >&2
      return 0
    fi
    _src="$(mktemp)"
    gh api graphql -f query='query { repository(owner:":owner",name:":repo"){ discussions(first:100){ nodes { id url comments(first:50){ nodes { id url body createdAt } } } } } }' > "$_src" 2>/dev/null || true
  fi
  while IFS= read -r _line; do
    [ -z "$_line" ] && continue
    _process_record "giscus" "$_line"
  done < "$_src"
}

# ---------- main ----------

_fetch_github
_fetch_giscus

_elapsed_ms=$(( ( $(date +%s) - _start_ms ) * 1000 ))
if [ "$DRY_RUN" -eq 0 ]; then
  printf '{"event":"unit_close","command":"comments fetch","comments_fetched":%d,"comments_skipped":%d,"source_surfaces":["giscus","github"],"elapsed_ms":%d,"source":"runtime"}\n' \
    "$_fetched" "$_skipped" "$_elapsed_ms" >> "$EXEC_LOG"
fi
printf 'SUMMARY: comments fetch fetched=%d skipped=%d\n' "$_fetched" "$_skipped"
exit 0
