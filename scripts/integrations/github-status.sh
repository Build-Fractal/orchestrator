#!/usr/bin/env bash
# scripts/integrations/github-status.sh — Read-only sidecar config reporter.
#
# Usage:
#   github-status.sh [--root <project-root>] [--init-pending] [--verify-cache]
#
# Output (stdout):
#   STATUS: absent|pending-operator-complete|configured
#   REPO_SLUG: <value>              (configured only)
#   SYNC_MODE: <value>              (configured only)
#   SUB_ISSUE_MODE: <value>         (configured only)
#   LAST_SYNC: <iso-8601|never>     (configured only)
#   CACHE_ITEMS: <integer>          (configured only)
#   PENDING_FIELDS: <csv>           (pending-operator-complete only)
#
# Exit: 0 on successful report, 1 on malformed JSON / schema mismatch,
#       2 on invalid CLI argument.
#
# Bash 3.2 compatible. No gh subprocess calls (P01 scope).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT_PENDING=0
VERIFY_CACHE=0

# ORCHESTRATOR_ROOT env override (4-rule resolver alignment): when set,
# use it verbatim as the .orchestrator root rather than PROJECT_ROOT/.orchestrator.
ORCH_ROOT_OVERRIDE="${ORCHESTRATOR_ROOT:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --init-pending) INIT_PENDING=1; shift ;;
    --verify-cache) VERIFY_CACHE=1; shift ;;
    -h|--help)
      echo "usage: github-status.sh [--root <dir>] [--init-pending] [--verify-cache]"
      exit 0
      ;;
    *) echo "github-status.sh: unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [ -n "$ORCH_ROOT_OVERRIDE" ]; then
  SIDECAR="${ORCH_ROOT_OVERRIDE}/integrations/github.json"
else
  SIDECAR="${PROJECT_ROOT}/.orchestrator/integrations/github.json"
fi

# --init-pending: bootstrap pending sentinel via T01 helper.
if [ "$INIT_PENDING" -eq 1 ] && [ ! -f "$SIDECAR" ]; then
  bash "${PROJECT_ROOT}/scripts/integrations/sidecar-init-pending.sh" --root "$PROJECT_ROOT" >/dev/null
fi

# --verify-cache: absent or pending sidecar -> pending-sentinel no-op (FR-11 reversibility).
# This branch runs BEFORE the generic absent-branch so --verify-cache on an
# absent sidecar returns the dedicated pending-sentinel message (T06 FR-18).
if [ "$VERIFY_CACHE" -eq 1 ]; then
  if [ ! -f "$SIDECAR" ] || grep -q '"pending"' "$SIDECAR"; then
    echo "STATUS: pending-operator-complete"
    echo "MESSAGE: --verify-cache requires a configured sidecar"
    exit 0
  fi
fi

# Absent branch.
if [ ! -f "$SIDECAR" ]; then
  echo "STATUS: absent"
  exit 0
fi

# Helper: extract a top-level JSON string or integer field by grep.
# Bash 3.2, no jq hard dep. For the fields we need (schema_version,
# repo_slug, project_v2_id, sync_mode, items) grep/sed is sufficient
# since the file is line-oriented JSON written by our own helper.
extract_field() {
  # $1 = field name; $2 = default
  local f="$1"
  local default="$2"
  local line
  line=$(grep -E "^[[:space:]]*\"${f}\"[[:space:]]*:" "$SIDECAR" | head -1)
  if [ -z "$line" ]; then
    printf '%s' "$default"
    return
  fi
  # Strip everything up to the colon, then trim trailing comma/whitespace
  # and surrounding double-quotes.
  printf '%s' "$line" \
    | sed -E 's/^[^:]*:[[:space:]]*//' \
    | sed -E 's/[,[:space:]]+$//' \
    | sed -E 's/^"//' \
    | sed -E 's/"$//'
}

repo_slug=$(extract_field repo_slug "")
project_v2_id=$(extract_field project_v2_id "")
sync_mode=$(extract_field sync_mode "")
sub_issue_mode=$(extract_field sub_issue_mode "")
last_sync=$(extract_field last_sync "never")

# Schema check: required top-level fields per FR-6.
missing=""
for f in schema_version repo_slug project_v2_id sync_mode sub_issue_mode recommended_cron custom_field_mappings items; do
  if ! grep -qE "^[[:space:]]*\"${f}\"[[:space:]]*:" "$SIDECAR"; then
    missing="${missing}${missing:+,}${f}"
  fi
done
if [ -n "$missing" ]; then
  echo "STATUS: schema-mismatch" >&2
  echo "MISSING_FIELDS: ${missing}" >&2
  exit 1
fi

# Pending-sentinel detection.
pending_fields=""
for f in repo_slug project_v2_id sync_mode sub_issue_mode; do
  v=$(extract_field "$f" "")
  if [ "$v" = "pending" ]; then
    pending_fields="${pending_fields}${pending_fields:+,}${f}"
  fi
done

if [ -n "$pending_fields" ]; then
  echo "STATUS: pending-operator-complete"
  echo "PENDING_FIELDS: ${pending_fields}"
  exit 0
fi

# --verify-cache configured branch: walk cached items, probe remote via
# gh_marker_search_remote, emit DIVERGENCE: lines per class. Never writes.
# Exit 0 on zero divergences, exit 5 on >=1 (T06 FR-18).
if [ "$VERIFY_CACHE" -eq 1 ]; then
  # Source common helpers for gh_marker_search_remote.
  if [ -f "${PROJECT_ROOT}/scripts/integrations/github-common.sh" ]; then
    # shellcheck disable=SC1091
    . "${PROJECT_ROOT}/scripts/integrations/github-common.sh"
  fi

  divergences=0
  # Parse cached items line-by-line (shape: '    "M###-P##[-T##]": {' open,
  # nested fields, closing '}' terminator). Same pattern as github-sync.sh
  # parse_cached_items. Bash 3.2: single-pass while-read with state vars.
  in_items=0
  oid=""
  issue=""
  synced=""
  while IFS= read -r line; do
    case "$line" in
      *\"items\"*:*) in_items=1 ;;
    esac
    if [ "$in_items" -eq 0 ]; then
      continue
    fi
    case "$line" in
      *\"M[0-9]*\"*:*\{*)
        oid=$(printf '%s\n' "$line" | sed -E 's/.*"(M[A-Z0-9-]+)".*/\1/')
        issue=""
        synced=""
        ;;
      *issue_number*)
        issue=$(printf '%s\n' "$line" | sed -E 's/.*"issue_number"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/')
        ;;
      *status_field_synced*)
        synced=$(printf '%s\n' "$line" | sed -E 's/.*"status_field_synced"[[:space:]]*:[[:space:]]*(true|false).*/\1/')
        ;;
      *\}*)
        if [ -n "$oid" ]; then
          hit=""
          hit_rc=0
          if command -v gh_marker_search_remote >/dev/null 2>&1; then
            hit=$(gh_marker_search_remote "$repo_slug" "$oid" 2>/dev/null)
            hit_rc=$?
          else
            hit_rc=1
          fi
          # Helper contract: exit 0 + number on stdout on unique hit;
          # exit 1 on zero matches; exit 2 on duplicate. For verify-cache
          # any non-zero rc (or empty stdout) is a missing-remote divergence.
          if [ "$hit_rc" -ne 0 ] || [ -z "$hit" ]; then
            echo "DIVERGENCE: missing-remote oid=${oid} cached-issue-number=${issue}"
            divergences=$((divergences + 1))
          fi
          oid=""
          issue=""
          synced=""
        fi
        ;;
    esac
  done < "$SIDECAR"

  # Missing-cache and status-mismatch divergence classes are documented in
  # references/github-integration.md; repo-wide marker-grep scope is
  # operator-owned (commentary-only here) to keep this probe fixture-driven.

  if [ "$divergences" -gt 0 ]; then
    echo "SUMMARY: --verify-cache divergences=${divergences}"
    exit 5
  fi
  echo "SUMMARY: --verify-cache divergences=0"
  exit 0
fi

# Configured branch.
# Count items: look for lines matching '    "M###-...": {' under items.
cache_items=$(grep -cE '^[[:space:]]{4,}"M[0-9]+-P[0-9]+' "$SIDECAR")
# grep -c always prints a number; ensure non-empty.
if [ -z "$cache_items" ]; then
  cache_items=0
fi

echo "STATUS: configured"
echo "REPO_SLUG: ${repo_slug}"
echo "SYNC_MODE: ${sync_mode}"
echo "SUB_ISSUE_MODE: ${sub_issue_mode}"
echo "LAST_SYNC: ${last_sync}"
echo "CACHE_ITEMS: ${cache_items}"
exit 0
