#!/usr/bin/env bash
# scripts/knowledge/write-summary.sh — Produce structured task/phase/milestone summaries
# Usage: write-summary.sh <type> <output-file> --<field>=<value> [--<field>=<value> ...]
#   type: task | phase | milestone
#   output-file: path to write the summary markdown to (use "-" for stdout)
#
# Required fields for task: id, parent, milestone, provides, requires, affects,
#   key_files, key_decisions, patterns_established, drill_down_paths,
#   duration, verification_result, completed_at, body
# Phase/milestone add: observability_surfaces
#
# Auto-set fields: schema_version (1.0), type (from arg)
#
# Exits non-zero with descriptive error naming the missing field on failure.
# Outputs "SUMMARY: <type> <id> written" on success.
# Reports field count to stderr.
#
# Bash 3.2 compatible (no declare -A per K001).

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: write-summary.sh <type> <output-file> --<field>=<value> ...

Types: task, phase, milestone

Example:
  write-summary.sh task /tmp/T01-SUMMARY.md \
    --id=T01 --parent=P01 --milestone=M001 \
    --provides="state derivation" --requires="from:P01/T01 what:extension.yml" \
    --affects=P02 --key_files=scripts/foo.sh --key_decisions=D001 \
    --patterns_established="file presence" --drill_down_paths=plans/T01.md \
    --duration=25m --verification_result=pass \
    --completed_at=2026-03-19T14:30:00Z --body="Summary body text here"
EOF
  exit 1
}

if [ $# -lt 3 ]; then
  echo "ERROR: write-summary.sh requires at least 3 arguments: <type> <output-file> --field=value ..." >&2
  usage
fi

SUMMARY_TYPE="$1"
OUTPUT_FILE="$2"
shift 2

# Validate type
case "$SUMMARY_TYPE" in
  task|phase|milestone) ;;
  *)
    echo "ERROR: Invalid summary type '$SUMMARY_TYPE'. Must be task, phase, or milestone." >&2
    exit 1
    ;;
esac

# Parse --field=value arguments into parallel arrays (bash 3.2 compatible)
FIELD_NAMES=""
FIELD_VALUES=""
# Use indexed arrays for bash 3.2 compatibility
field_name_list=""
field_value_list=""
idx=0

# We'll store field names and values in indexed arrays
declare_field_name() { eval "field_n_$1=\"\$2\""; }
declare_field_value() { eval "field_v_$1=\"\$2\""; }
get_field_name() { eval "echo \"\$field_n_$1\""; }
get_field_value() { eval "echo \"\$field_v_$1\""; }

for arg in "$@"; do
  case "$arg" in
    --*=*)
      name="${arg%%=*}"
      name="${name#--}"
      value="${arg#*=}"
      declare_field_name "$idx" "$name"
      declare_field_value "$idx" "$value"
      idx=$((idx + 1))
      ;;
    *)
      echo "ERROR: Unrecognized argument '$arg'. Use --field=value format." >&2
      exit 1
      ;;
  esac
done

FIELD_COUNT=$idx

# Lookup a field value by name; returns empty string if not found
lookup_field() {
  local target="$1"
  local i=0
  while [ $i -lt $FIELD_COUNT ]; do
    local n
    n=$(get_field_name "$i")
    if [ "$n" = "$target" ]; then
      get_field_value "$i"
      return 0
    fi
    i=$((i + 1))
  done
  echo ""
  return 1
}

# Define required fields per type
TASK_FIELDS="id parent milestone provides requires affects key_files key_decisions patterns_established drill_down_paths duration verification_result completed_at body"
PHASE_FIELDS="id parent milestone provides requires affects key_files key_decisions patterns_established drill_down_paths duration verification_result completed_at observability_surfaces body"
MILESTONE_FIELDS="id parent milestone provides requires affects key_files key_decisions patterns_established drill_down_paths duration verification_result completed_at observability_surfaces body"

case "$SUMMARY_TYPE" in
  task) REQUIRED_FIELDS="$TASK_FIELDS" ;;
  phase) REQUIRED_FIELDS="$PHASE_FIELDS" ;;
  milestone) REQUIRED_FIELDS="$MILESTONE_FIELDS" ;;
esac

# Validate all required fields are present
for field in $REQUIRED_FIELDS; do
  value=""
  value=$(lookup_field "$field") || true
  if [ -z "$value" ]; then
    echo "ERROR: Missing required field '$field' for $SUMMARY_TYPE summary." >&2
    exit 1
  fi
done

# Extract field values
f_id=$(lookup_field "id") || true
f_parent=$(lookup_field "parent") || true
f_milestone=$(lookup_field "milestone") || true
f_provides=$(lookup_field "provides") || true
f_requires=$(lookup_field "requires") || true
f_affects=$(lookup_field "affects") || true
f_key_files=$(lookup_field "key_files") || true
f_key_decisions=$(lookup_field "key_decisions") || true
f_patterns=$(lookup_field "patterns_established") || true
f_drilldown=$(lookup_field "drill_down_paths") || true
f_duration=$(lookup_field "duration") || true
f_verif=$(lookup_field "verification_result") || true
f_completed=$(lookup_field "completed_at") || true
f_body=$(lookup_field "body") || true

# Build the output
build_output() {
  echo "---"
  echo "schema_version: \"1.0\""
  echo "type: ${SUMMARY_TYPE}-summary"
  echo "id: \"$f_id\""
  echo "parent: \"$f_parent\""
  echo "milestone: \"$f_milestone\""
  echo "provides:"
  echo "  - \"$f_provides\""
  echo "requires:"
  echo "  - \"$f_requires\""
  echo "affects:"
  echo "  - \"$f_affects\""
  echo "key_files:"
  echo "  - \"$f_key_files\""
  echo "key_decisions:"
  echo "  - \"$f_key_decisions\""
  echo "patterns_established:"
  echo "  - \"$f_patterns\""
  echo "drill_down_paths:"
  echo "  - \"$f_drilldown\""
  echo "duration: \"$f_duration\""
  echo "verification_result: \"$f_verif\""
  echo "completed_at: \"$f_completed\""

  # Phase and milestone get observability_surfaces
  if [ "$SUMMARY_TYPE" = "phase" ] || [ "$SUMMARY_TYPE" = "milestone" ]; then
    f_obs=$(lookup_field "observability_surfaces") || true
    echo "observability_surfaces:"
    echo "  - \"$f_obs\""
  fi

  echo "---"
  echo ""
  echo "$f_body"
}

# Count frontmatter fields (excluding body)
case "$SUMMARY_TYPE" in
  task) frontmatter_count=15 ;;
  phase|milestone) frontmatter_count=16 ;;
esac
echo "FIELD_COUNT: $frontmatter_count fields in $SUMMARY_TYPE summary frontmatter" >&2

# Write output
if [ "$OUTPUT_FILE" = "-" ]; then
  build_output
else
  # Ensure output directory exists
  output_dir=$(dirname "$OUTPUT_FILE")
  mkdir -p "$output_dir"
  build_output > "$OUTPUT_FILE"
fi

echo "SUMMARY: $SUMMARY_TYPE $f_id written"
