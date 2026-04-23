#!/usr/bin/env bash
# scripts/diagnostics/run-doctor.sh — Run all diagnostic checks with scored health report
# Usage: run-doctor.sh [--root <project-root>] [--format text|json]
#
# Main orchestrator for all diagnostic checks. Runs each check script,
# produces a scored health report, and appends results to doctor-history.jsonl.
#
# Bash 3.2 compatible (no associative arrays, no mapfile).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
FORMAT="text"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    *) echo "run-doctor.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

export PROJECT_ROOT

# --- Scoring state ---
checks_passed=0
checks_total=0
advisory_warnings=0

# --- Runner function ---
run_check() {
  local name="$1"
  local script="$2"
  local args="$3"
  local advisory="$4"

  echo "--- $name ---"

  # Run the check script — avoid eval; use word-splitting on $args deliberately
  local output=""
  local exit_code=0
  # shellcheck disable=SC2086
  output="$(bash "$script" $args 2>&1)" || exit_code=$?

  # check-permissions.sh exits 2 when target missing — treat as valid non-crash
  if [ "$exit_code" -gt 0 ] && [ "$exit_code" -ne 2 ] || [ "$exit_code" -eq 0 ] || [ "$exit_code" -eq 2 ]; then
    : # All valid exit codes (0, 2, or any non-zero) — continue parsing
  fi

  # Display output
  if [ -n "$output" ]; then
    echo "$output"
  fi

  # Determine pass/fail
  local passed=1
  local doctor_line=""
  doctor_line="$(echo "$output" | grep '^DOCTOR:' | head -1)" || true

  if [ -n "$doctor_line" ]; then
    # New-style check: parse status= from DOCTOR: line
    local status=""
    status="$(echo "$doctor_line" | sed -n 's/.*status=\([a-z_]*\).*/\1/p')" || true
    case "$status" in
      ok|skip) passed=1 ;;
      warn|drift|missing) passed=0 ;;
      *) passed=0 ;;  # Unknown status treated as failure
    esac
  else
    # Legacy check: exit code 0 = passed, non-zero = failed
    if [ "$exit_code" -ne 0 ]; then
      passed=0
    fi
  fi

  # Apply advisory logic
  if [ "$advisory" -eq 1 ]; then
    if [ "$passed" -eq 0 ]; then
      advisory_warnings=$((advisory_warnings + 1))
    fi
    # Advisory checks don't count toward pass/fail total
  else
    checks_total=$((checks_total + 1))
    if [ "$passed" -eq 1 ]; then
      checks_passed=$((checks_passed + 1))
    fi
  fi

  echo ""
}

# --- Run all checks ---
echo "=== Orchestrator Diagnostics ==="
echo "Project root: $PROJECT_ROOT"
echo "Date: $(date +%Y-%m-%d)"
echo ""

run_check "Orphaned Artifacts" "$SCRIPT_DIR/check-orphaned.sh" "" "0"
run_check "Stale Knowledge" "$SCRIPT_DIR/check-stale.sh" "" "0"
run_check "Scope Issues" "$SCRIPT_DIR/check-scope.sh" "" "0"
run_check "Cost Spikes" "$SCRIPT_DIR/check-cost-spikes.sh" "" "0"
run_check "Instruction Conformance" "$SCRIPT_DIR/check-instructions.sh" "--root $PROJECT_ROOT" "0"
run_check "Provider Conformance" "$SCRIPT_DIR/check-providers.sh" "--root $PROJECT_ROOT" "0"
run_check "Permission Drift" "$SCRIPT_DIR/check-permissions.sh" "--project-root $PROJECT_ROOT --quiet" "0"
run_check "Constitution Coverage" "$SCRIPT_DIR/check-constitution.sh" "--root $PROJECT_ROOT" "0"
run_check "Event Emission" "$SCRIPT_DIR/check-events.sh" "--root $PROJECT_ROOT" "0"
run_check "Content Hashes" "$SCRIPT_DIR/check-hashes.sh" "--root $PROJECT_ROOT" "0"
run_check "Run ID Coverage" "$SCRIPT_DIR/check-run-ids.sh" "--root $PROJECT_ROOT" "0"
run_check "Recipe Conformance" "$SCRIPT_DIR/check-recipe.sh" "--root $PROJECT_ROOT" "0"
run_check "Task Plan Shape" "$SCRIPT_DIR/check-plans.sh" "--root $PROJECT_ROOT" "1"
run_check "Documentation Completeness" "$SCRIPT_DIR/check-docs.sh" "--root $PROJECT_ROOT" "0"
run_check "Runtime Instruction Drift" "$SCRIPT_DIR/check-docs.sh" "--check drift --root $PROJECT_ROOT" "1"

# Graph health checks (requires knowledge.db from M007)
if [ -f "$PROJECT_ROOT/knowledge.db" ]; then
  run_check "Graph Health" "$SCRIPT_DIR/check-graph-health.sh" "--root $PROJECT_ROOT" "0"
else
  echo "--- Graph Health ---"
  echo "SKIP: knowledge.db not found (run rebuild-index.sh to create)"
  echo ""
fi

# --- Summary ---
if [ "$checks_passed" -eq "$checks_total" ]; then
  status_label="HEALTHY"
  status_value="healthy"
else
  status_label="NEEDS_ATTENTION"
  status_value="needs_attention"
fi

echo "=== Health Report ==="
echo "Checks passed: $checks_passed / $checks_total"
echo "Advisory warnings: $advisory_warnings"
echo "Status: $status_label"

# --- History append ---
history_file="$PROJECT_ROOT/.orchestrator/doctor-history.jsonl"
mkdir -p "$(dirname "$history_file")"
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "{\"timestamp\":\"$ts\",\"checks_passed\":$checks_passed,\"checks_total\":$checks_total,\"advisory_warnings\":$advisory_warnings,\"status\":\"$status_value\"}" >> "$history_file"

echo ""
echo "Results appended to: $history_file"
