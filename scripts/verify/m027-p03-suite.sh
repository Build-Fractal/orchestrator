#!/usr/bin/env bash
# scripts/verify/m027-p03-suite.sh -- M027/P03 phase-suite orchestrator.
#
# Runs all 11 per-contract m027-p03-*.sh verifiers in stable order
# (cheapest static checks first; latency / live-invocation last) and
# aggregates results.
#
#   - Exit 0 on all-green; prints `PASS: m027-p03-suite.sh <N> gates`
#     to stdout.
#   - Exit 1 on any failure; prints `FAIL: m027-p03-suite.sh <N> failing
#     gates: <space-separated names>` to stderr, plus per-gate FAIL lines.
#   - Surfaces RELAX-CANDIDATE annotations (e.g. from latency gate) on
#     stdout so downstream tooling can grep without scraping per-gate
#     output. Mirrors the shape of m027-p02-suite.sh / m027-p01-suite.sh /
#     m027-rollup-schema.sh.
#
# Internal carve-out (per task-plan AD-19 note + MEM004): the suite uses
# a `for gate in $GATES; do ...; done` loop with per-gate `$?` capture.
# The external Check shape remains a single-script invocation:
#   `bash scripts/verify/m027-p03-suite.sh`
#
# Bash 3.2 compatible (parallel scalars only; no associative arrays).

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Stable gate order -- cheapest static / regex-only checks first; live
# invocations and the environment-sensitive latency gate last. The
# m027-p03 literal token below also satisfies the must-have content
# check.
GATES="
m027-p03-bash32-compat.sh
m027-p03-zero-llm-token.sh
m027-p03-doctor-md-shape.sh
m027-p03-anomaly-shape.sh
m027-p03-config-drift-shape.sh
m027-p03-run-doctor-integration.sh
m027-p03-suppression-matrix.sh
m027-p03-anomaly-goodhart-pairing.sh
m027-p03-doctor-byte-identity.sh
m027-p03-read-only.sh
m027-p03-anomaly-latency.sh
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

  # Capture combined stdout+stderr so we can surface RELAX-CANDIDATE
  # annotations from the latency gate.
  gate_stdout="$(bash "$gate_path" 2>&1)"
  rc=$?

  # Forward any RELAX-CANDIDATE annotation lines verbatim.
  relax_line="$(printf '%s\n' "$gate_stdout" | grep -E '^RELAX-CANDIDATE|^WARN: RELAX-CANDIDATE' || true)"
  if [ -n "$relax_line" ]; then
    relax_candidate_lines="$relax_candidate_lines
$relax_line"
  fi

  if [ "$rc" -eq 0 ]; then
    echo "PASS: $gate"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $gate (exit $rc)" >&2
    printf '%s\n' "$gate_stdout" >&2
    fail_count=$((fail_count + 1))
    failed_gates="$failed_gates $gate"
  fi
done

# Surface RELAX-CANDIDATE annotations on stdout.
if [ -n "$relax_candidate_lines" ]; then
  printf '%s\n' "$relax_candidate_lines" | sed '/^$/d'
fi

echo "SUMMARY: m027-p03-suite.sh pass=$pass_count fail=$fail_count total=$total_count"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m027-p03-suite.sh $total_count gates"
  exit 0
else
  trimmed_failed="$(echo $failed_gates)"
  echo "FAIL: m027-p03-suite.sh $fail_count failing gates: $trimmed_failed" >&2
  exit 1
fi
