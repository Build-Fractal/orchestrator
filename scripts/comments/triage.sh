#!/usr/bin/env bash
# scripts/comments/triage.sh
# FR-1 — list comments routed to the human-triage bucket.
#
# Each triage entry lives at .orchestrator/comments/triage/<id>.md with
# frontmatter fields:
#   comment_url, conversus_verdict (optional), reason (optional)
#
# Output: tab-separated rows {id, comment_url, conversus_verdict}
# followed by a SUMMARY: line with the entry count.
#
# Hermetic test hook:
#   ORCHESTRATOR_PROJECT_ROOT — overrides project root resolution.
#
# CON-6 / MEM001: Bash 3.2. AD-19 single-script-file shape.

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
  if [ ! -f "$f" ]; then
    continue
  fi
  _count=$((_count + 1))
  _id="$(basename "$f" .md)"
  _url="$(awk '/^comment_url:/ { sub(/^comment_url:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }' "$f")"
  _verdict="$(awk '/^conversus_verdict:/ { sub(/^conversus_verdict:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }' "$f")"
  if [ -z "$_verdict" ]; then
    _verdict="unknown"
  fi
  printf '%s\t%s\tconversus_verdict=%s\n' "$_id" "$_url" "$_verdict"
done

printf 'SUMMARY: triage entries=%d\n' "$_count"
exit 0
