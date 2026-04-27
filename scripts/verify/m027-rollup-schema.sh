#!/usr/bin/env bash
# scripts/verify/m027-rollup-schema.sh — M027/P00 phase-suite orchestrator.
#
# FR-15 / SC-2 phase-suite entry point. Orchestrates the fourteen
# per-contract m027-p00-*.sh verifiers in a stable order (cheapest first,
# slowest last) and aggregates results.
#
#   - Exit 0 on all-green; prints `PASS: m027-rollup-schema.sh <N> gates` to stdout.
#   - Exit 1 on any failure; prints `FAIL: m027-rollup-schema.sh <N> failing
#     gates: <space-separated names>` to stderr, plus per-gate FAIL lines.
#   - The perf-bound gate's structured `RELAX-CANDIDATE` annotation (if any)
#     is preserved on stdout so plan-phase / consolidate can act on it.
#
# Internal carve-out (per task-plan AD-19 note + MEM004): the suite uses a
# `for gate in $GATES; do ...; done` loop with per-gate `$?` capture. The
# external Check shape remains a single-script invocation:
#   `bash scripts/verify/m027-rollup-schema.sh`
#
# Bash 3.2 compatible (parallel scalars only; no associative arrays).

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Stable gate order — cheapest first, perf-bound last. m027-p00 literal
# token below also satisfies the must-have "contains the literal string
# m027-p00" content check.
GATES="
m027-p00-bash32-compat.sh
m027-p00-zero-llm-token.sh
m027-p00-rollup-cli-contract.sh
m027-p00-input-schema.sh
m027-p00-corrupt-line.sh
m027-p00-pricing-warning.sh
m027-p00-source-filter.sh
m027-p00-aggregation-precedence.sh
m027-p00-goodhart-pairing.sh
m027-p00-pre-m019-additivity.sh
m027-p00-fs-race.sh
m027-p00-read-only.sh
m027-p00-live-m019-row.sh
m027-p00-perf-bound.sh
"

pass_count=0
fail_count=0
total_count=0
failed_gates=""
relax_candidate_lines=""

for gate in $GATES; do
  total_count=$((total_count + 1))
  gate_path="$PROJECT_ROOT/scripts/verify/$gate"

  if [ ! -f "$gate_path" ]; then
    echo "FAIL: $gate (missing)" >&2
    fail_count=$((fail_count + 1))
    failed_gates="$failed_gates $gate"
    continue
  fi

  if [ ! -x "$gate_path" ]; then
    echo "FAIL: $gate (not executable)" >&2
    fail_count=$((fail_count + 1))
    failed_gates="$failed_gates $gate"
    continue
  fi

  # Capture stdout so we can surface RELAX-CANDIDATE annotations from the
  # perf-bound gate. Stderr passes through to the operator.
  gate_stdout="$(bash "$gate_path" 2>&1)"
  rc=$?

  # Forward any RELAX-CANDIDATE annotation lines verbatim.
  relax_line="$(printf '%s\n' "$gate_stdout" | grep -E '^RELAX-CANDIDATE' || true)"
  if [ -n "$relax_line" ]; then
    relax_candidate_lines="$relax_candidate_lines
$relax_line"
  fi

  if [ "$rc" -eq 0 ]; then
    echo "PASS: $gate"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $gate (exit $rc)" >&2
    # Echo the gate's own output for diagnostic context.
    printf '%s\n' "$gate_stdout" >&2
    fail_count=$((fail_count + 1))
    failed_gates="$failed_gates $gate"
  fi
done

# Surface any RELAX-CANDIDATE annotations on stdout so downstream tooling
# can grep them without scraping per-gate output.
if [ -n "$relax_candidate_lines" ]; then
  printf '%s\n' "$relax_candidate_lines" | sed '/^$/d'
fi

echo "SUMMARY: m027-rollup-schema.sh pass=$pass_count fail=$fail_count total=$total_count"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m027-rollup-schema.sh $total_count gates"
  exit 0
else
  # Trim leading whitespace from accumulator.
  trimmed_failed="$(echo $failed_gates)"
  echo "FAIL: m027-rollup-schema.sh $fail_count failing gates: $trimmed_failed" >&2
  exit 1
fi
