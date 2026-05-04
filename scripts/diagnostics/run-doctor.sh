#!/usr/bin/env bash
# scripts/diagnostics/run-doctor.sh — Run all diagnostic checks with scored health report
# Usage: run-doctor.sh [--root <project-root>] [--format text|json]
#                      [--config-check] [--routing-table <path>] [--no-anomaly]
#
# Main orchestrator for all diagnostic checks. Runs each check script,
# produces a scored health report, and appends results to doctor-history.jsonl.
#
# Bash 3.2 compatible (no associative arrays, no mapfile).
#
# Key links (M031/P04):
#   - templates/orchestrator-config-default.yml (the doctor compares the
#     active config against the template default to detect pre-M031
#     projects -- see m031_compound_change_check below; absence of
#     quick_knowledge_token_budget triggers the AD-9 compound-change
#     message naming the auto_proceed flip + unconditional Quick
#     injection + recovery path).
#
# M033/P03/T04 #Q-11: skip _<sentinel>/ paths from milestone iteration.
# This dispatcher does NOT enumerate `.orchestrator/milestones/*/` itself —
# milestone enumeration is delegated to the sub-checks (`check-plans.sh`,
# `check-constitution.sh`). The `_*`-prefix skip clause is applied at the
# delegate enumeration sites. See `references/imported-context-sentinel.md`.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
FORMAT="text"
CONFIG_CHECK=0
NO_ANOMALY=0
ROUTING_TABLE_FLAG=""

# M031/P04/T02: AD-9 compound-change comms — resolve the active config path.
# Test-only env override `ORCH_DOCTOR_CONFIG_PATH` lets the SC test point
# doctor at fixture configs under a tmp scratch root; production callers do
# NOT set the env var and the doctor falls back to the canonical resolution
# (.orchestrator/config.yml under PROJECT_ROOT). The override is read at the
# top of the resolution chain so it beats every fallback.
if [ -n "${ORCH_DOCTOR_CONFIG_PATH:-}" ]; then
  DOCTOR_CONFIG_PATH="$ORCH_DOCTOR_CONFIG_PATH"
else
  DOCTOR_CONFIG_PATH="$PROJECT_ROOT/.orchestrator/config.yml"
fi

# M031/P04/T02: AD-9 compound-change comms. Emits a one-time message
# when the active config lacks quick_knowledge_token_budget (i.e. the
# config predates M031). Detection by knob-absence is the simplest
# invariant — no version field, no migration timestamp.
m031_compound_change_check() {
  # $1 config_path
  local cfg="$1"
  if [ ! -f "$cfg" ]; then
    return 0
  fi
  if grep -q -F -- "quick_knowledge_token_budget" "$cfg"; then
    return 0
  fi
  printf '\n'
  printf 'M031 (right-sized entry) is active. Two behavioral changes since the\n'
  printf 'last init of this project'\''s .orchestrator/config.yml:\n'
  printf '\n'
  printf '  1. auto_proceed default flipped from false to true. Dispatch loops\n'
  printf '     now auto-proceed past green gates without operator confirmation.\n'
  printf '  2. Quick-profile dispatches now inject knowledge + compression\n'
  printf '     unconditionally (the pre-M031 skip-context-for-Quick shortcut is\n'
  printf '     gone). Total task tokens drop because agents no longer rediscover\n'
  printf '     context the knowledge graph already holds.\n'
  printf '\n'
  printf 'If you prefer the pre-M031 auto_proceed behavior, add this line to\n'
  printf '.orchestrator/config.yml:\n'
  printf '\n'
  printf '    auto_proceed: false\n'
  printf '\n'
  printf 'To tune the knowledge ceiling, adjust quick_knowledge_token_budget\n'
  printf 'in your config (default 800 tokens).\n'
  printf '\n'
  printf 'This message will not appear again once your .orchestrator/config.yml\n'
  printf 'carries quick_knowledge_token_budget explicitly.\n'
  printf '\n'
  return 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --config-check) CONFIG_CHECK=1; shift ;;
    --routing-table) ROUTING_TABLE_FLAG="$2"; shift 2 ;;
    --no-anomaly) NO_ANOMALY=1; shift ;;
    *) echo "run-doctor.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

export PROJECT_ROOT

# --- M030/P01/T04: --config-check routing-table validation (FR-17 + SC-9) ---
#
# When --config-check is set, validate templates/model-routing.yml shape
# via tools/verify/p01-routing-table-shape.sh. On a malformed table,
# propagate the verifier's <file>:<lineno> diagnostic to stdout and
# exit 1 immediately. On a well-formed table, continue with the rest
# of the doctor pipeline. Resolution priority for the table path:
#   --routing-table <path>  (CLI flag)
#   $ROUTING_TABLE_PATH     (env var)
#   templates/model-routing.yml (default, resolved under PROJECT_ROOT)
if [ "$CONFIG_CHECK" -eq 1 ]; then
  if [ -n "$ROUTING_TABLE_FLAG" ]; then
    ROUTING_TABLE="$ROUTING_TABLE_FLAG"
  elif [ -n "${ROUTING_TABLE_PATH:-}" ]; then
    ROUTING_TABLE="$ROUTING_TABLE_PATH"
  else
    ROUTING_TABLE="$PROJECT_ROOT/templates/model-routing.yml"
  fi

  echo "--- Routing Table Shape (templates/model-routing.yml) ---"
  bash "$PROJECT_ROOT/tools/verify/p01-routing-table-shape.sh" "$ROUTING_TABLE"
  routing_rc=$?
  echo ""

  if [ "$routing_rc" -ne 0 ]; then
    # Verifier already emitted FAIL: <file>:<lineno> — <msg> to stdout.
    echo "=== Health Report ==="
    echo "Status: NEEDS_ATTENTION"
    echo "Routing table validation failed (--config-check)."
    exit 1
  fi
fi

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

# M031/P04/T02: AD-9 compound-change comms (one-time message for pre-M031
# configs lacking quick_knowledge_token_budget). Always returns 0 — purely
# observational, does not affect health-check scoring or exit codes.
m031_compound_change_check "$DOCTOR_CONFIG_PATH"

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

# M027/P03/T03 — Anomaly Detection (advisory; FR-8: never blocks autonomous mode).
if [ "$NO_ANOMALY" -eq 1 ]; then
  run_check "Anomaly Detection" "$SCRIPT_DIR/check-anomalies.sh" "--no-anomaly" "1"
else
  run_check "Anomaly Detection" "$SCRIPT_DIR/check-anomalies.sh" "" "1"
fi

# M027/P03/T03 — Config Drift (advisory; opt-in via --config-check; FR-16).
if [ "$CONFIG_CHECK" -eq 1 ]; then
  run_check "Config Drift" "$SCRIPT_DIR/check-config-drift.sh" "" "1"
fi

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
