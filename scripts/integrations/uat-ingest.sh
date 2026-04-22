#!/usr/bin/env bash
# scripts/integrations/uat-ingest.sh -- Ingest UAT-bug fixture files into
# knowledge/spec/defect/SPEC-DEFECT-NNN.md entries.
#
# Usage:
#   uat-ingest.sh --source <dir> [--root <project-root>] [--dry-run]
#
# Inputs: one JSON file per UAT bug under <source>, each carrying:
#   issue_number, title, spec_chunk_id, body, created_at
#
# Output (stdout):
#   INGEST: SPEC-DEFECT-NNN status=<open|chunk-lookup-failed> issue=<N>
#   SKIP: SPEC-DEFECT-NNN issue=<N> (already ingested)
#   SUMMARY: created=<N> skipped=<N> errors=<N>
#
# Exit 0 on success (including chunk-lookup-failed entries -- those are
# created, not silently dropped -- FR-10). Exit 1 on malformed fixtures
# or write errors. Exit 2 on invalid CLI args.
#
# Bash 3.2 compatible; no jq hard dep; no gh subprocess calls.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_DIR=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE_DIR="$2"; shift 2 ;;
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "uat-ingest.sh: unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$SOURCE_DIR" ]; then
  echo "uat-ingest.sh: --source <dir> is required" >&2
  exit 2
fi
if [ ! -d "$SOURCE_DIR" ]; then
  echo "uat-ingest.sh: source directory does not exist: $SOURCE_DIR" >&2
  exit 1
fi

DEFECT_DIR="${PROJECT_ROOT}/knowledge/spec/defect"
INDEX="${PROJECT_ROOT}/KNOWLEDGE-INDEX.md"

# Build set of known chunk IDs from KNOWLEDGE-INDEX.md Spec Chunks section.
# Bash 3.2 -- use a newline-delimited string, not an assoc array.
known_chunks=""
if [ -f "$INDEX" ]; then
  known_chunks=$(awk '
    /^## Spec Chunks/ { in_sec=1; next }
    /^## / && in_sec { exit }
    in_sec && /^SPEC-[A-Z]+-[0-9]+ \|/ {
      n = index($0, " |")
      if (n > 0) print substr($0, 1, n-1)
    }
  ' "$INDEX")
fi

chunk_known() {
  # $1 = candidate id
  local id="$1"
  printf '%s\n' "$known_chunks" | grep -qxF "$id"
}

# Minimal JSON field reader -- handles flat single-level string/integer fields
# with double-quoted keys. Not a general JSON parser; acceptable for fixture
# files we author. Prefers python3 when available for robustness.
json_field_str() {
  # $1 = file path; $2 = field name; stdout = value (unquoted)
  local file="$1"
  local field="$2"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
v=d.get(sys.argv[2])
if v is None:
    sys.exit(0)
sys.stdout.write(str(v))
" "$file" "$field"
    return
  fi
  # Fallback: grep + sed
  grep -E "\"${field}\"[[:space:]]*:" "$file" | head -1 | \
    sed -E "s/.*\"${field}\"[[:space:]]*:[[:space:]]*//" | \
    sed -E 's/^"//' | sed -E 's/"[[:space:]]*,?[[:space:]]*$//' | \
    sed -E 's/,[[:space:]]*$//'
}

created=0
skipped=0
errors=0

mkdir -p "$DEFECT_DIR"

for f in "$SOURCE_DIR"/*.json; do
  [ -f "$f" ] || continue
  issue_number=$(json_field_str "$f" "issue_number")
  title=$(json_field_str "$f" "title")
  chunk=$(json_field_str "$f" "spec_chunk_id")
  body=$(json_field_str "$f" "body")
  created_at=$(json_field_str "$f" "created_at")

  if [ -z "$issue_number" ]; then
    echo "ERROR: $f missing issue_number" >&2
    errors=$((errors + 1))
    continue
  fi

  # Zero-pad issue_number to 3 digits for IDs 1-999; otherwise use as-is.
  if [ "$issue_number" -lt 1000 ] 2>/dev/null; then
    padded=$(printf '%03d' "$issue_number")
  else
    padded="$issue_number"
  fi
  defect_id="SPEC-DEFECT-${padded}"
  out="${DEFECT_DIR}/${defect_id}.md"

  # Idempotency: skip if already exists with matching issue_number.
  if [ -f "$out" ]; then
    existing=$(grep -E '^github_issue_number:' "$out" | head -1 | sed 's/^github_issue_number:[[:space:]]*//')
    if [ "$existing" = "$issue_number" ]; then
      echo "SKIP: ${defect_id} issue=${issue_number} (already ingested)"
      skipped=$((skipped + 1))
      continue
    fi
    # File exists with different issue -- collision; error.
    echo "ERROR: ${out} exists with different issue_number: ${existing} vs ${issue_number}" >&2
    errors=$((errors + 1))
    continue
  fi

  # Resolve status by chunk lookup.
  if [ -n "$chunk" ] && chunk_known "$chunk"; then
    status="open"
    chunk_field="$chunk"
  else
    status="chunk-lookup-failed"
    chunk_field=""
  fi

  ingested_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: would write ${out} status=${status}"
    continue
  fi

  {
    printf -- '---\n'
    printf 'id: %s\n' "$defect_id"
    printf 'scope_tags: "[project]"\n'
    printf 'category: spec/defect\n'
    printf 'status: %s\n' "$status"
    printf 'chunk: "%s"\n' "$chunk_field"
    printf 'phase: ""\n'
    printf 'tests: []\n'
    printf 'github_issue_number: %s\n' "$issue_number"
    printf 'created_at: "%s"\n' "$created_at"
    printf 'ingested_at: "%s"\n' "$ingested_at"
    printf -- '---\n\n'
    printf '# %s: %s\n\n' "$defect_id" "$title"
    printf '<!-- Original GitHub Issue body -->\n\n'
    printf '%s\n' "$body"
  } > "$out"

  echo "INGEST: ${defect_id} status=${status} issue=${issue_number}"
  created=$((created + 1))
done

printf 'SUMMARY: created=%d skipped=%d errors=%d\n' "$created" "$skipped" "$errors"

if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0
