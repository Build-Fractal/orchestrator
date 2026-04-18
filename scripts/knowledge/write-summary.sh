#!/usr/bin/env bash
# scripts/knowledge/write-summary.sh — Produce structured task/phase/milestone summaries
# Usage: write-summary.sh <type> <output-file> --<field>=<value> [--<field>=<value> ...]
#   type: task | phase | milestone
#   output-file: path to write the summary markdown to (use "-" for stdout)
#
# Required fields for task: id, parent, milestone, provides, requires, affects,
#   key_files, key_decisions, patterns_established, drill_down_paths,
#   duration, verification_result, body
# Optional fields: completed_at (defaults to current UTC; accepts "now" sentinel or ISO-8601)
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
    --provides="state derivation" --requires="from:P01/T01 what:config.yml" \
    --affects=P02 --key_files=scripts/foo.sh --key_decisions=D001 \
    --patterns_established="file presence" --drill_down_paths=plans/T01.md \
    --duration=25m --verification_result=pass \
    --body="Summary body text here"

  --completed_at is optional. Omit it to default to now, or pass --completed_at=now.
  Explicit ISO-8601 values (e.g., --completed_at=2026-03-19T14:30:00Z) are also accepted.
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
TASK_FIELDS="id parent milestone provides requires affects key_files key_decisions patterns_established drill_down_paths duration verification_result body"
PHASE_FIELDS="id parent milestone provides requires affects key_files key_decisions patterns_established drill_down_paths duration verification_result observability_surfaces body"
MILESTONE_FIELDS="id parent milestone provides requires affects key_files key_decisions patterns_established drill_down_paths duration verification_result observability_surfaces body"

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

# Handle completed_at: optional, defaults to now
f_completed_raw=$(lookup_field "completed_at") || true
if [ -z "$f_completed_raw" ] || [ "$f_completed_raw" = "now" ]; then
  f_completed=$(date -u +%Y-%m-%dT%H:%M:%SZ)
else
  f_completed="$f_completed_raw"
fi

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

# ============================================================================
# M019/P01/T04: unit_close emitter with Goodhart pairing
# ----------------------------------------------------------------------------
# Appends exactly one `unit_close` JSONL record to the milestone's
# execution-log.jsonl after each successful summary write. Every record
# carries BOTH a cost block AND a quality block (C2 Goodhart guard).
# Cost block is summed from already-emitted payload_breakdown +
# dispatch_usage records keyed by unitId prefix. Quality block is derived
# per AD-3 from existing attempt/outcome/verification_result fields — no
# new event surface.
#
# Never abort: all log-write failures degrade silently via `|| true`.
# Summary file write output is unchanged. MEM004 carve-out applies:
# awk/$()/pipes permitted (emitter is dispatch-internal, not agent-facing).
# Bash 3.2 compatible.
# ============================================================================
_ws_parse_duration_seconds() {
  # Parse "25m" / "2h" / "90s" / bare integer into seconds. Empty -> 0.
  local raw="${1:-}"
  [ -n "$raw" ] || { printf '0\n'; return 0; }
  local tail="${raw: -1}"
  local head="${raw%?}"
  case "$tail" in
    m) printf '%d\n' $(( head * 60 )) ;;
    h) printf '%d\n' $(( head * 3600 )) ;;
    s) printf '%d\n' "$head" ;;
    *)
      # Bare integer (or unknown suffix). Only emit a valid int.
      case "$raw" in
        ''|*[!0-9]*) printf '0\n' ;;
        *)           printf '%d\n' "$raw" ;;
      esac
      ;;
  esac
}

_ws_emit_unit_close() {
  # args: granularity milestone phase task duration_s outcome completed_at
  local granularity="$1"
  local milestone_arg="$2"
  local phase_arg="$3"
  local task_arg="$4"
  local duration_s="$5"
  local outcome="$6"
  local completed_at_arg="$7"

  # Resolve orchestrator root and milestone log path.
  local orch_root log_dir log_file
  orch_root="${ORCHESTRATOR_ROOT:-.orchestrator}"
  log_dir="$orch_root/milestones/$milestone_arg"
  # Fixture mode: if orch_root itself IS a milestone dir (contains phases/),
  # log directly there (T02/T03 fixture carve-out pattern).
  if [ ! -d "$log_dir" ] && [ -d "$orch_root/phases" ]; then
    log_dir="$orch_root"
  fi
  log_file="$log_dir/execution-log.jsonl"

  # Compute unitId + prefix for child-aggregation lookups.
  local unit_id prefix_self prefix_children
  case "$granularity" in
    task)
      unit_id="$milestone_arg/$phase_arg/$task_arg"
      # task rollup looks at its own records only — full-id match.
      prefix_self="\"unitId\":\"$unit_id\""
      prefix_children=""
      ;;
    phase)
      unit_id="$milestone_arg/$phase_arg"
      prefix_self="\"unitId\":\"$unit_id\""
      prefix_children="\"unitId\":\"$unit_id/"
      ;;
    milestone)
      unit_id="$milestone_arg"
      prefix_self="\"unitId\":\"$unit_id\""
      prefix_children="\"unitId\":\"$unit_id/"
      ;;
    *)
      return 0
      ;;
  esac

  # --- Cost block: sum estimated_cost_usd across all matching records.
  # Match: own-unitId OR any child-unitId (phase/milestone) — effectively a
  # prefix match on the unitId field. For task, only own records.
  # Track any-null: if any contributing record has null cost, summed field is null.
  # pricing_version wins = most recent (last-seen in log order).
  local cost_summary cost_total pricing_version
  if [ ! -r "$log_file" ]; then
    cost_total="null"
    pricing_version=""
  else
    cost_summary="$(
      awk -v p_self="$prefix_self" -v p_kids="$prefix_children" '
        {
          hit = 0
          if (index($0, p_self)) hit = 1
          else if (p_kids != "" && index($0, p_kids)) hit = 1
          if (!hit) next
          if (match($0, /"estimated_cost_usd":null/)) {
            any_null = 1
          } else if (match($0, /"estimated_cost_usd":[0-9.]+/)) {
            v = substr($0, RSTART + 24, RLENGTH - 24)
            sum += v + 0
            n++
          }
          if (match($0, /"pricing_version":"[^"]*"/)) {
            pv = substr($0, RSTART + 19, RLENGTH - 20)
          }
        }
        END {
          if (any_null || n == 0) printf "null|%s\n", pv
          else                    printf "%.8f|%s\n", sum, pv
        }
      ' "$log_file" 2>/dev/null
    )"
    cost_total="${cost_summary%%|*}"
    pricing_version="${cost_summary#*|}"
  fi
  [ -n "$cost_total" ] || cost_total="null"

  # --- Quality block (AD-3 — derive from existing fields).
  # retry_count: records matching self-unitId with attempt >= 2.
  # deviation_count: retry_count + records with outcome in {fail,error}.
  # verification_pass_rate:
  #   task: 1.0 if outcome==pass else 0.0
  #   phase/milestone: count(child unit_close records with outcome=pass) /
  #                    count(child unit_close records total); 1.0 when zero.
  local retry_count deviation_count pass_rate
  retry_count=0
  deviation_count=0

  if [ -r "$log_file" ]; then
    retry_count="$(
      awk -v p="$prefix_self" '
        index($0, p) && match($0, /"attempt":[2-9]/) { c++ }
        END { printf "%d\n", c+0 }
      ' "$log_file" 2>/dev/null
    )"
    [ -n "$retry_count" ] || retry_count=0

    local fail_err_count
    fail_err_count="$(
      awk -v p="$prefix_self" '
        index($0, p) && (match($0, /"outcome":"fail"/) || match($0, /"outcome":"error"/)) { c++ }
        END { printf "%d\n", c+0 }
      ' "$log_file" 2>/dev/null
    )"
    [ -n "$fail_err_count" ] || fail_err_count=0
    deviation_count=$(( retry_count + fail_err_count ))
  fi

  case "$granularity" in
    task)
      case "$outcome" in
        pass) pass_rate="1.0" ;;
        *)    pass_rate="0.0" ;;
      esac
      ;;
    phase|milestone)
      # Phase counts child tasks; milestone counts child phases.
      local child_gran
      if [ "$granularity" = "phase" ]; then
        child_gran="\"granularity\":\"task\""
      else
        child_gran="\"granularity\":\"phase\""
      fi
      if [ -r "$log_file" ] && [ -n "$prefix_children" ]; then
        pass_rate="$(
          awk -v p="$prefix_children" -v g="$child_gran" '
            index($0, p) && index($0, "\"record_type\":\"unit_close\"") && index($0, g) {
              total++
              if (index($0, "\"outcome\":\"pass\"")) pass++
            }
            END {
              if (total > 0) printf "%.2f\n", pass / total
              else           printf "1.0\n"
            }
          ' "$log_file" 2>/dev/null
        )"
      else
        pass_rate="1.0"
      fi
      [ -n "$pass_rate" ] || pass_rate="1.0"
      ;;
  esac

  # --- Emit.
  local ts src cost_field
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ "$granularity" = "task" ]; then
    src="estimate"
  else
    src="aggregate"
  fi
  if [ "$cost_total" = "null" ]; then
    cost_field="null"
  else
    cost_field="$cost_total"
  fi

  mkdir -p "$log_dir" 2>/dev/null || return 0

  printf '{"record_type":"unit_close","granularity":"%s","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","duration_s":%d,"outcome":"%s","completed_at":"%s","estimated_cost_usd":%s,"pricing_version":"%s","verification_pass_rate":%s,"deviation_count":%d,"retry_count":%d,"source":"%s","timestamp":"%s"}\n' \
    "$granularity" "$unit_id" \
    "$milestone_arg" "$phase_arg" "$task_arg" \
    "$duration_s" "$outcome" "$completed_at_arg" \
    "$cost_field" "$pricing_version" \
    "$pass_rate" "$deviation_count" "$retry_count" \
    "$src" "$ts" \
    >> "$log_file" 2>/dev/null || true

  return 0
}

# Call the emitter. Task id is empty for phase/milestone; phase id is
# empty for milestone. Duration parsed to seconds; outcome mapped from
# verification_result (pass|fail|pending).
_ws_uc_task=""
_ws_uc_phase=""
case "$SUMMARY_TYPE" in
  task)
    _ws_uc_task="$f_id"
    _ws_uc_phase="$f_parent"
    ;;
  phase)
    _ws_uc_phase="$f_id"
    ;;
  milestone)
    : ;;
esac
_ws_uc_duration_s="$(_ws_parse_duration_seconds "$f_duration")"
_ws_emit_unit_close \
  "$SUMMARY_TYPE" \
  "$f_milestone" \
  "$_ws_uc_phase" \
  "$_ws_uc_task" \
  "$_ws_uc_duration_s" \
  "$f_verif" \
  "$f_completed" \
  || true

echo "SUMMARY: $SUMMARY_TYPE $f_id written"
