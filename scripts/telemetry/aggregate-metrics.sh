#!/usr/bin/env bash
# scripts/telemetry/aggregate-metrics.sh — Compute aggregate execution metrics
# Reads execution-log.jsonl and produces summary metrics from both dispatch
# result entries and telemetry entries.
#
# Usage: aggregate-metrics.sh <execution-log> [--milestone=M###] [--format=text|json]
#
# Options:
#   --milestone=<M###>    Filter to a specific milestone
#   --format=<text|json>  Output format (default: text)
#
# Structured output depends on --format flag.
# Exits 0 on success, 1 on invalid arguments, 2 if log file not found.
#
# Bash 3.2 / BSD awk compatible — no GNU extensions, no jq dependency.

set -euo pipefail

# --- Helper: extract JSON string value ---
# Usage: json_str_val <line> <field>
json_str_val() {
  printf '%s' "$1" | sed -n 's/.*"'"$2"'":"\([^"]*\)".*/\1/p'
}

# --- Helper: extract JSON numeric value ---
# Usage: json_num_val <line> <field>
json_num_val() {
  printf '%s' "$1" | sed -n 's/.*"'"$2"'":\([0-9.]*[0-9]\).*/\1/p'
}

# --- Argument parsing ---
if [ $# -lt 1 ]; then
  echo "Usage: aggregate-metrics.sh <execution-log> [--milestone=M###] [--format=text|json]" >&2
  exit 1
fi

EXECUTION_LOG="$1"
shift

MILESTONE_FILTER=""
FORMAT="text"

while [ $# -gt 0 ]; do
  case "$1" in
    --milestone=*) MILESTONE_FILTER="${1#--milestone=}" ;;
    --format=*) FORMAT="${1#--format=}" ;;
    *) echo "aggregate-metrics.sh: unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ ! -f "$EXECUTION_LOG" ]; then
  echo "aggregate-metrics.sh: log file not found: $EXECUTION_LOG" >&2
  exit 2
fi

# --- Accumulate metrics line by line (Bash 3.2 compatible) ---
total_dispatches=0
success_count=0
total_duration=0
duration_count=0
inline_cost_sum=0
telemetry_cost_sum=0
cache_hit_sum=0
cache_hit_count=0

# We'll build parallel arrays using indexed temp files for model + milestone tracking
MODEL_TMPDIR="$(mktemp -d)"
MILESTONE_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$MODEL_TMPDIR" "$MILESTONE_TMPDIR"' EXIT

while IFS= read -r line; do
  # Skip empty lines
  [ -z "$line" ] && continue

  entry_type="$(json_str_val "$line" "type")"

  # --- Determine milestone for this line ---
  line_milestone="$(json_str_val "$line" "milestone")"
  if [ -z "$line_milestone" ]; then
    unit_id="$(json_str_val "$line" "unitId")"
    line_milestone="$(printf '%s' "$unit_id" | cut -d/ -f1)"
  fi

  # Apply milestone filter if set
  if [ -n "$MILESTONE_FILTER" ]; then
    if [ "$line_milestone" != "$MILESTONE_FILTER" ]; then
      continue
    fi
  fi

  if [ "$entry_type" = "telemetry" ]; then
    # --- Process telemetry entry ---
    cost_val="$(json_num_val "$line" "cost_estimated")"
    if [ -n "$cost_val" ]; then
      telemetry_cost_sum=$(awk "BEGIN { printf \"%.6f\", $telemetry_cost_sum + $cost_val }")
    fi

    cache_val="$(json_num_val "$line" "cache_hit_rate")"
    if [ -n "$cache_val" ]; then
      cache_hit_sum=$(awk "BEGIN { printf \"%.6f\", $cache_hit_sum + $cache_val }")
      cache_hit_count=$((cache_hit_count + 1))
    fi

    # Model tracking
    model_name="$(json_str_val "$line" "model_used")"
    if [ -n "$model_name" ]; then
      # Sanitize model name for filename (replace non-alphanumeric with _)
      safe_model="$(printf '%s' "$model_name" | sed 's/[^a-zA-Z0-9._-]/_/g')"
      model_file="${MODEL_TMPDIR}/${safe_model}"
      if [ -f "$model_file" ]; then
        # Read existing count and cost
        old_count=$(sed -n '1p' "$model_file")
        old_cost=$(sed -n '2p' "$model_file")
        old_name=$(sed -n '3p' "$model_file")
      else
        old_count=0
        old_cost="0"
        old_name="$model_name"
      fi
      new_count=$((old_count + 1))
      if [ -n "$cost_val" ]; then
        new_cost=$(awk "BEGIN { printf \"%.3f\", $old_cost + $cost_val }")
      else
        new_cost="$old_cost"
      fi
      printf '%d\n%s\n%s\n' "$new_count" "$new_cost" "$old_name" > "$model_file"
    fi

    # Milestone telemetry cost tracking
    if [ -n "$line_milestone" ] && [ -n "$cost_val" ]; then
      safe_ms="$(printf '%s' "$line_milestone" | sed 's/[^a-zA-Z0-9._-]/_/g')"
      ms_tfile="${MILESTONE_TMPDIR}/${safe_ms}_tcost"
      if [ -f "$ms_tfile" ]; then
        old_tcost=$(cat "$ms_tfile")
      else
        old_tcost="0"
      fi
      new_tcost=$(awk "BEGIN { printf \"%.6f\", $old_tcost + $cost_val }")
      printf '%s' "$new_tcost" > "$ms_tfile"
    fi

  else
    # --- Process dispatch entry ---
    total_dispatches=$((total_dispatches + 1))

    outcome="$(json_str_val "$line" "outcome")"
    if [ "$outcome" = "success" ]; then
      success_count=$((success_count + 1))
    fi

    dur_val="$(json_num_val "$line" "duration_s")"
    if [ -n "$dur_val" ]; then
      total_duration=$(awk "BEGIN { printf \"%.6f\", $total_duration + $dur_val }")
      duration_count=$((duration_count + 1))
    fi

    # Inline cost from dispatch entries
    icost_val="$(json_num_val "$line" "cost_estimated")"
    if [ -n "$icost_val" ]; then
      inline_cost_sum=$(awk "BEGIN { printf \"%.6f\", $inline_cost_sum + $icost_val }")
    fi

    # Per-milestone dispatch tracking
    if [ -n "$line_milestone" ]; then
      safe_ms="$(printf '%s' "$line_milestone" | sed 's/[^a-zA-Z0-9._-]/_/g')"
      ms_dfile="${MILESTONE_TMPDIR}/${safe_ms}_dispatch"
      ms_sfile="${MILESTONE_TMPDIR}/${safe_ms}_success"
      ms_icfile="${MILESTONE_TMPDIR}/${safe_ms}_icost"
      ms_nfile="${MILESTONE_TMPDIR}/${safe_ms}_name"

      # Store original milestone name
      printf '%s' "$line_milestone" > "$ms_nfile"

      # Dispatch count
      if [ -f "$ms_dfile" ]; then
        old_d=$(cat "$ms_dfile")
      else
        old_d=0
      fi
      printf '%d' "$((old_d + 1))" > "$ms_dfile"

      # Success count
      if [ "$outcome" = "success" ]; then
        if [ -f "$ms_sfile" ]; then
          old_s=$(cat "$ms_sfile")
        else
          old_s=0
        fi
        printf '%d' "$((old_s + 1))" > "$ms_sfile"
      fi

      # Inline cost
      if [ -n "$icost_val" ]; then
        if [ -f "$ms_icfile" ]; then
          old_ic=$(cat "$ms_icfile")
        else
          old_ic="0"
        fi
        new_ic=$(awk "BEGIN { printf \"%.6f\", $old_ic + $icost_val }")
        printf '%s' "$new_ic" > "$ms_icfile"
      fi
    fi
  fi
done < "$EXECUTION_LOG"

# --- Compute derived metrics ---
total_cost=$(awk "BEGIN { printf \"%.3f\", $telemetry_cost_sum + $inline_cost_sum }")

if [ "$total_dispatches" -gt 0 ]; then
  avg_cost=$(awk "BEGIN { printf \"%.3f\", $total_cost / $total_dispatches }")
  success_pct=$(awk "BEGIN { printf \"%.1f\", ($success_count / $total_dispatches) * 100 }")
else
  avg_cost="0.000"
  success_pct="N/A"
fi

if [ "$duration_count" -gt 0 ]; then
  avg_duration=$(awk "BEGIN { printf \"%.0f\", $total_duration / $duration_count }")
else
  avg_duration="0"
fi

if [ "$cache_hit_count" -gt 0 ]; then
  avg_cache_hit=$(awk "BEGIN { printf \"%.1f\", ($cache_hit_sum / $cache_hit_count) * 100 }")
else
  avg_cache_hit="N/A"
fi

# --- Collect model stats from temp files ---
model_lines=""
for mfile in "$MODEL_TMPDIR"/*; do
  [ -f "$mfile" ] || continue
  m_count=$(sed -n '1p' "$mfile")
  m_cost=$(sed -n '2p' "$mfile")
  m_name=$(sed -n '3p' "$mfile")
  if [ -n "$model_lines" ]; then
    model_lines="${model_lines}
"
  fi
  model_lines="${model_lines}${m_name}	${m_count}	${m_cost}"
done

# --- Collect milestone stats ---
# Find unique milestones from dispatch files
milestone_lines=""
for dfile in "$MILESTONE_TMPDIR"/*_dispatch; do
  [ -f "$dfile" ] || continue
  safe_ms="$(basename "$dfile" _dispatch)"
  ms_name="$(cat "${MILESTONE_TMPDIR}/${safe_ms}_name" 2>/dev/null || echo "$safe_ms")"
  ms_disp=$(cat "$dfile")
  ms_succ=$(cat "${MILESTONE_TMPDIR}/${safe_ms}_success" 2>/dev/null || echo 0)
  ms_icost=$(cat "${MILESTONE_TMPDIR}/${safe_ms}_icost" 2>/dev/null || echo "0")
  ms_tcost=$(cat "${MILESTONE_TMPDIR}/${safe_ms}_tcost" 2>/dev/null || echo "0")
  ms_total_cost=$(awk "BEGIN { printf \"%.2f\", $ms_icost + $ms_tcost }")
  ms_success_pct=$(awk "BEGIN { printf \"%.1f\", ($ms_succ / $ms_disp) * 100 }")

  if [ -n "$milestone_lines" ]; then
    milestone_lines="${milestone_lines}
"
  fi
  milestone_lines="${milestone_lines}${ms_name}	${ms_disp}	${ms_success_pct}	${ms_total_cost}"
done

# Sort milestone lines
if [ -n "$milestone_lines" ]; then
  milestone_lines=$(printf '%s\n' "$milestone_lines" | sort)
fi

# --- Output ---
if [ "$FORMAT" = "json" ]; then
  json="{"
  json="${json}\"total_dispatches\":${total_dispatches}"
  json="${json},\"success_count\":${success_count}"
  if [ "$total_dispatches" -gt 0 ]; then
    json="${json},\"success_rate\":$(awk "BEGIN { printf \"%.3f\", $success_count / $total_dispatches }")"
  fi
  json="${json},\"total_cost\":${total_cost}"
  json="${json},\"avg_cost_per_task\":${avg_cost}"
  json="${json},\"avg_duration_s\":${avg_duration}"
  if [ "$avg_cache_hit" != "N/A" ]; then
    json="${json},\"cache_hit_rate\":$(awk "BEGIN { printf \"%.3f\", $cache_hit_sum / $cache_hit_count }")"
  fi

  # Models
  json="${json},\"by_model\":{"
  model_json=""
  if [ -n "$model_lines" ]; then
    first_model=1
    while IFS='	' read -r model count cost; do
      if [ $first_model -eq 0 ]; then
        model_json="${model_json},"
      fi
      model_json="${model_json}\"${model}\":{\"count\":${count},\"cost\":${cost}}"
      first_model=0
    done <<EOF
$model_lines
EOF
  fi
  json="${json}${model_json}}"

  # Milestones
  json="${json},\"by_milestone\":{"
  ms_json=""
  if [ -n "$milestone_lines" ]; then
    first_ms=1
    while IFS='	' read -r ms disp spct tcost; do
      if [ $first_ms -eq 0 ]; then
        ms_json="${ms_json},"
      fi
      ms_json="${ms_json}\"${ms}\":{\"dispatches\":${disp},\"success_rate\":${spct},\"cost\":${tcost}}"
      first_ms=0
    done <<EOF
$milestone_lines
EOF
  fi
  json="${json}${ms_json}}"

  json="${json}}"
  echo "$json"

else
  # Text format
  echo "=== Execution Telemetry ==="
  printf 'Dispatches:     %d\n' "$total_dispatches"
  if [ "$total_dispatches" -gt 0 ]; then
    printf 'Success rate:   %s%% (%d/%d)\n' "$success_pct" "$success_count" "$total_dispatches"
  else
    printf 'Success rate:   N/A\n'
  fi
  printf 'Total cost:     $%s\n' "$total_cost"
  printf 'Avg cost/task:  $%s\n' "$avg_cost"
  printf 'Avg duration:   %ss\n' "$avg_duration"
  if [ "$avg_cache_hit" != "N/A" ]; then
    printf 'Cache hit rate: %s%%\n' "$avg_cache_hit"
  else
    printf 'Cache hit rate: N/A\n'
  fi

  if [ -n "$model_lines" ]; then
    echo ""
    echo "--- By Model ---"
    printf '%s\n' "$model_lines" | sort | while IFS='	' read -r model count cost; do
      printf '%-25s %d tasks, $%s\n' "${model}:" "$count" "$cost"
    done
  fi

  if [ -n "$milestone_lines" ] && [ -z "$MILESTONE_FILTER" ]; then
    echo ""
    echo "--- By Milestone ---"
    printf '%s\n' "$milestone_lines" | while IFS='	' read -r ms disp spct tcost; do
      printf '%s: %d tasks, $%s, %s%% success\n' "$ms" "$disp" "$tcost" "$spct"
    done
  fi
fi
