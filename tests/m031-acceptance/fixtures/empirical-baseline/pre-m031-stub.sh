#!/usr/bin/env bash
# pre-m031-stub.sh
#
# AD-14 single-window discipline: this stub freezes the pre-M031
# dispatch-path semantics for a given task fixture. It is the only
# capture window for the pre-M031 baseline — once P01 modifies
# commands/dispatch.md:21 (the Quick-skip language) and
# scripts/dispatch/build-context.sh, the live skip branch is gone
# and there is no second capture opportunity. T03 invokes this stub
# once across all 20 corpus fixtures to materialize
# pre-m031-baseline.jsonl.
#
# This stub MUST NOT call scripts/dispatch/build-context.sh — the
# pre-M031 path is defined as the path that skips it (Quick intensity,
# load-bearing leak per AD-14). The p00-pre-stub-shape.sh verifier
# enforces this with an inverted grep on this script's body.
#
# Cost-model constants (documented for future auditors):
#   PER_FILE_REDISCOVERY_TOKENS = 1500   # rough proxy: each touched
#       file pays a rediscovery cost when knowledge-graph + compression
#       are skipped (the pre-M031 Quick leak this milestone closes).
#   PLAN_DELIVERY_OVERHEAD_TOKENS = 500  # fixed per-task overhead.
#       Synthetic empty fixture (task-06) returns this floor only.
# These values approximate observed pre-M031 Quick costs without
# requiring a live capture, which is unavailable post-P01.
#
# JSONL schema (one record per invocation, on stdout):
#   {"task_id":"<id>","path":"pre-m031","knowledge_section_tokens":0,
#    "compression_applied":false,"snip_applied":false,
#    "total_task_tokens":<int>,"verifier_pass":true}
#
# verifier_pass is hard-coded `true` for the stub — the pre-M031
# path's pass rate is the baseline against which the post-M031 path
# is measured for "equal-or-higher" per CON-5 / AD-4. P01's first
# task captures the actual post-M031 pass rate; T03's harness
# compares them.
#
# Usage:
#   bash pre-m031-stub.sh <path-to-task-NN.txt>
#
# Exit 0 on success; exit 1 with stderr diagnostic on missing or
# malformed fixture.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no
# process substitution.

set -u

PER_FILE_REDISCOVERY_TOKENS=1500
PLAN_DELIVERY_OVERHEAD_TOKENS=500

fixture="${1:-}"

if [ -z "$fixture" ]; then
    echo "ERROR: pre-m031-stub.sh requires a task-fixture path argument" >&2
    exit 1
fi
if [ ! -f "$fixture" ]; then
    echo "ERROR: fixture not found: $fixture" >&2
    exit 1
fi

# task_id is the basename without the .txt suffix.
base=$(basename "$fixture")
task_id="${base%.txt}"

# Extract touched_files line; everything after the first colon, trimmed.
touched_line=$(grep -E '^touched_files:' "$fixture" | head -n 1)
if [ -z "$touched_line" ]; then
    echo "ERROR: fixture missing 'touched_files:' line: $fixture" >&2
    exit 1
fi
# Strip the leading "touched_files:" and one optional space.
touched_value="${touched_line#touched_files:}"
# Trim leading whitespace.
while [ -n "$touched_value" ] && [ "${touched_value# }" != "$touched_value" ]; do
    touched_value="${touched_value# }"
done

# Count touched files: 0 if empty, else (commas + 1).
file_count=0
if [ -n "$touched_value" ]; then
    # Replace every char other than comma with nothing, count chars.
    commas_only=$(echo "$touched_value" | tr -cd ',')
    file_count=$(( ${#commas_only} + 1 ))
fi

total_task_tokens=$(( file_count * PER_FILE_REDISCOVERY_TOKENS + PLAN_DELIVERY_OVERHEAD_TOKENS ))

# Emit one JSONL line. Fields are deterministic so T03 can grep + diff.
printf '{"task_id":"%s","path":"pre-m031","knowledge_section_tokens":0,"compression_applied":false,"snip_applied":false,"total_task_tokens":%d,"verifier_pass":true}\n' \
    "$task_id" "$total_task_tokens"

exit 0
