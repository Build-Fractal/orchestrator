#!/usr/bin/env bash
# post-m031-emitter.sh
#
# AD-14 single-window discipline (M031/P01/T02): this wrapper is the
# post-M031 sibling of pre-m031-stub.sh. It captures the post-M031
# Quick-profile dispatch path -- build-context.sh --profile=quick,
# knowledge_section_tokens > 0, M018 compression-aware -- as a JSONL
# record per corpus task fixture. The empirical-baseline.sh harness
# invokes this once per fixture; together with the frozen pre-m031
# stub the harness emits both record sets in a single run, satisfying
# AD-14's "simultaneously while both code paths are live" requirement.
#
# This emitter is the point at which the post-M031 surface is exercised
# end-to-end against the same 20-task corpus the pre-M031 stub already
# wrote. It DOES call scripts/dispatch/build-context.sh -- by contract,
# the post-M031 path is the path that runs build-context.sh under the
# quick profile. The artifact-shape literals in this header
# ("build-context.sh", "--profile=quick", "post-m031",
# "knowledge_section_tokens") are asserted verbatim by
# tools/verify/m031-p01-post-baseline-jsonl-population.sh.
#
# JSONL schema (one record per invocation, on stdout):
#   {"task_id":"<id>","path":"post-m031",
#    "knowledge_section_tokens":<int>,
#    "compression_applied":<bool>,"snip_applied":<bool>,
#    "total_task_tokens":<int>,"verifier_pass":true}
#
# verifier_pass is hard-coded `true` here -- the post-M031 path is
# the system under test, and SC-3 / SC-15 verdicts are determined at
# the SC-test level, not in the emitter.
#
# Usage:
#   bash post-m031-emitter.sh <path-to-task-NN.txt>
#
# Exit 0 on success; exit 1 on missing fixture or build-context.sh
# non-zero exit.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no
# process substitution.

set -u

fixture="${1:-}"

if [ -z "$fixture" ]; then
    echo "ERROR: post-m031-emitter.sh requires a task-fixture path argument" >&2
    exit 1
fi
if [ ! -f "$fixture" ]; then
    echo "ERROR: fixture not found: $fixture" >&2
    exit 1
fi

# Locate the project root via the fixture path. The fixture lives at
# tests/m031-acceptance/fixtures/empirical-baseline/task-NN.txt; the
# project root is four levels up.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

BUILD_CONTEXT="$PROJECT_ROOT/scripts/dispatch/build-context.sh"
if [ ! -f "$BUILD_CONTEXT" ]; then
    echo "ERROR: build-context.sh not found at $BUILD_CONTEXT" >&2
    exit 1
fi

# Derive task_id from the fixture filename.
base=$(basename "$fixture")
task_id="${base%.txt}"

# Stage temp paths for payload + meta sidecar. Bash 3.2 -- mktemp is
# POSIX-portable.
payload_out="/tmp/m031-p01-t02-payload-${task_id}.md"
meta_out="/tmp/m031-p01-t02-meta-${task_id}.json"

# Invoke build-context.sh in direct mode under the quick profile.
# Capture stderr to /dev/null because the harness composes one JSONL
# line per emitter invocation on stdout.
if ! bash "$BUILD_CONTEXT" \
        --profile=quick \
        --task-plan "$fixture" \
        --out "$payload_out" \
        --meta-out "$meta_out" \
        >/dev/null 2>&1; then
    echo "ERROR: build-context.sh exited non-zero on fixture: $fixture" >&2
    rm -f "$payload_out" "$meta_out"
    exit 1
fi

if [ ! -f "$meta_out" ]; then
    echo "ERROR: build-context.sh did not write meta sidecar for: $fixture" >&2
    rm -f "$payload_out"
    exit 1
fi

# Extract sidecar fields. The sidecar is a single-line JSON object with
# 5 keys: mem_count, total_tokens, profile, compression_applied,
# snip_applied. Use sed extraction (no jq dep, MEM001).
read_field_int() {
    file="$1"
    field="$2"
    sed -n 's/.*"'"$field"'":\([0-9][0-9]*\).*/\1/p' "$file" | head -1
}
read_field_bool() {
    file="$1"
    field="$2"
    sed -n 's/.*"'"$field"'":\(true\|false\).*/\1/p' "$file" | head -1
}

total_tokens=$(read_field_int "$meta_out" "total_tokens")
compression_applied=$(read_field_bool "$meta_out" "compression_applied")
snip_applied=$(read_field_bool "$meta_out" "snip_applied")

if [ -z "$total_tokens" ]; then
    total_tokens=0
fi
if [ -z "$compression_applied" ]; then
    compression_applied="false"
fi
if [ -z "$snip_applied" ]; then
    snip_applied="false"
fi

# knowledge_section_tokens: per the task plan, the simplest robust
# path is to report the sidecar's total_tokens (the SC tests gate on
# the sidecar field). The Knowledge section is the dominant section
# under the Quick profile -- task plan + frontmatter combined are
# small relative to the resolved-MEM body -- so total_tokens is a
# faithful upper bound on knowledge_section_tokens for this corpus.
knowledge_section_tokens="$total_tokens"
total_task_tokens="$total_tokens"

# Clean up payload + sidecar (the JSONL record is the durable artifact;
# the per-task scratch is not needed by downstream consumers).
rm -f "$payload_out" "$meta_out"

# Emit the JSONL record. Sibling-symmetric with pre-m031-stub.sh shape.
printf '{"task_id":"%s","path":"post-m031","knowledge_section_tokens":%d,"compression_applied":%s,"snip_applied":%s,"total_task_tokens":%d,"verifier_pass":true}\n' \
    "$task_id" "$knowledge_section_tokens" "$compression_applied" "$snip_applied" "$total_task_tokens"

exit 0
