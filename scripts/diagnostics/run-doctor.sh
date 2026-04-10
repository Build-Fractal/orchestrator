#!/usr/bin/env bash
# scripts/diagnostics/run-doctor.sh — Run all diagnostic checks
# Usage: run-doctor.sh [--root <project-root>] [--format text|json]
#
# Main orchestrator for all diagnostic checks. Runs each check script
# and produces a combined report. Results are appended to doctor-history.jsonl.
#
# Bash 3.2 compatible.
set -euo pipefail

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

echo "=== Orchestrator Diagnostics ==="
echo "Project root: $PROJECT_ROOT"
echo "Date: $(date +%Y-%m-%d)"
echo ""

total_warnings=0
total_errors=0

# Run each check script, capture output and counts
run_check() {
    local name="$1"
    local script="$2"
    shift 2

    echo "--- $name ---"
    local output
    local exit_code=0
    output="$(bash "$script" "$@" 2>&1)" || exit_code=$?

    if [ -n "$output" ]; then
        echo "$output"
        # Count WARNING and ERROR lines
        local warns errs
        warns="$(echo "$output" | grep -c "^WARNING:" || true)"
        errs="$(echo "$output" | grep -c "^ERROR:" || true)"
        total_warnings=$((total_warnings + warns))
        total_errors=$((total_errors + errs))
    else
        echo "PASS: No issues found."
    fi
    echo ""
}

run_check "Orphaned Artifacts" "$SCRIPT_DIR/check-orphaned.sh"
run_check "Stale Knowledge" "$SCRIPT_DIR/check-stale.sh"
run_check "Scope Issues" "$SCRIPT_DIR/check-scope.sh"
run_check "Cost Spikes" "$SCRIPT_DIR/check-cost-spikes.sh"

# Summary
echo "=== Summary ==="
echo "Warnings: $total_warnings"
echo "Errors: $total_errors"
if [ "$total_warnings" -eq 0 ] && [ "$total_errors" -eq 0 ]; then
    echo "Status: HEALTHY"
else
    echo "Status: NEEDS_ATTENTION"
fi

# Append to doctor-history.jsonl
history_file="$PROJECT_ROOT/.specify/orchestrator/doctor-history.jsonl"
mkdir -p "$(dirname "$history_file")"
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "{\"timestamp\":\"$ts\",\"warnings\":$total_warnings,\"errors\":$total_errors,\"status\":\"$([ "$total_warnings" -eq 0 ] && [ "$total_errors" -eq 0 ] && echo 'healthy' || echo 'needs_attention')\"}" >> "$history_file"
echo ""
echo "Results appended to: $history_file"
