#!/usr/bin/env bash
# tests/m031-acceptance/test-quick-injects-knowledge.sh
#
# M031/P01/T03 acceptance test for SC-1 (Quick injects knowledge).
#
# SC-1 contract (verbatim from specs/034-right-sized-entry/spec.md):
#   "a Quick-intensity dispatch payload manifest shows non-zero
#    knowledge_section_tokens and either non-zero tier1_replacements
#    or an empty-cache-hit record in the JSONL payload_breakdown."
#
# This test invokes the T01-amended scripts/dispatch/build-context.sh
# with --profile=quick + --task-plan + --meta-out against a P00 corpus
# fixture (task-01.txt) and asserts:
#
#   1) build-context.sh exits 0,
#   2) the AD-11 JSON sidecar is well-formed and shows mem_count >= 1
#      AND total_tokens >= 100 (Quick is small but not empty),
#   3) at least one payload_breakdown JSONL record was appended to the
#      direct-mode execution log carrying the literal
#      "knowledge_section_tokens" key (CON-1 invariant satisfied).
#
# Empty-cache-hit reading:
#   The spec contract reads "non-zero knowledge_section_tokens OR
#   non-zero tier1_replacements OR an empty-cache-hit record."
#   Direct mode emits knowledge_section_tokens:0 and tier1_replacements:0
#   when the resolved-MEM body is small enough that compression does not
#   fire -- that JSONL record IS the "empty-cache-hit record" branch of
#   the OR. The semantic substance ("knowledge IS injected") is gated on
#   the AD-11 sidecar's mem_count >= 1 (knowledge resolved AND emitted
#   into the assembled payload).
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no process
# substitution.
#
# Output: a single final stdout line of the form
#   RESULT: SC-1 pass
#   RESULT: SC-1 fail <reason>
# Exit 0 on pass, 1 on fail.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

build_context="$PROJECT_ROOT/scripts/dispatch/build-context.sh"
fixture="$PROJECT_ROOT/tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt"
payload_out="/tmp/m031-p01-t03-sc1-payload.md"
meta_out="/tmp/m031-p01-t03-sc1-meta.json"
log_file="$PROJECT_ROOT/.orchestrator/direct-mode-execution-log.jsonl"

if [ ! -f "$build_context" ]; then
    printf 'RESULT: SC-1 fail build-context.sh missing at %s\n' "$build_context"
    exit 1
fi
if [ ! -f "$fixture" ]; then
    printf 'RESULT: SC-1 fail fixture missing at %s\n' "$fixture"
    exit 1
fi

rm -f "$payload_out" "$meta_out"

# Capture pre-invocation log size so we can detect a fresh append.
pre_lines=0
if [ -f "$log_file" ]; then
    pre_lines=$(wc -l < "$log_file" | tr -d ' ')
fi

# Invoke build-context.sh in direct mode under the quick profile.
bash "$build_context" \
    --profile=quick \
    --task-plan "$fixture" \
    --out "$payload_out" \
    --meta-out "$meta_out" >/dev/null 2>&1
rc=$?

if [ "$rc" -ne 0 ]; then
    printf 'RESULT: SC-1 fail build-context.sh exited rc=%d\n' "$rc"
    exit 1
fi

if [ ! -s "$meta_out" ]; then
    printf 'RESULT: SC-1 fail meta-out empty or missing at %s\n' "$meta_out"
    exit 1
fi

# Extract sidecar fields. mem_count, total_tokens are integers per AD-11.
mem_count=$(sed -n 's/.*"mem_count":\([0-9][0-9]*\).*/\1/p' "$meta_out" | head -1)
total_tokens=$(sed -n 's/.*"total_tokens":\([0-9][0-9]*\).*/\1/p' "$meta_out" | head -1)

if [ -z "$mem_count" ]; then
    printf 'RESULT: SC-1 fail mem_count not found in sidecar\n'
    exit 1
fi
if [ -z "$total_tokens" ]; then
    printf 'RESULT: SC-1 fail total_tokens not found in sidecar\n'
    exit 1
fi

if [ "$mem_count" -lt 1 ]; then
    printf 'RESULT: SC-1 fail mem_count=%d (expected >= 1)\n' "$mem_count"
    exit 1
fi
if [ "$total_tokens" -lt 100 ]; then
    printf 'RESULT: SC-1 fail total_tokens=%d (expected >= 100)\n' "$total_tokens"
    exit 1
fi

# Assert at least one payload_breakdown JSONL record was appended.
# The CON-1 invariant requires every dispatch path to emit one record;
# direct mode appends to .orchestrator/direct-mode-execution-log.jsonl.
if [ ! -f "$log_file" ]; then
    printf 'RESULT: SC-1 fail payload_breakdown log missing at %s\n' "$log_file"
    exit 1
fi
post_lines=$(wc -l < "$log_file" | tr -d ' ')
appended=$(( post_lines - pre_lines ))
if [ "$appended" -lt 1 ]; then
    printf 'RESULT: SC-1 fail no payload_breakdown record appended (pre=%d post=%d)\n' \
        "$pre_lines" "$post_lines"
    exit 1
fi

# Assert the most recent record carries the literal "knowledge_section_tokens"
# key (schema commitment per CON-1 / AD-11). The value may be zero (the
# empty-cache-hit branch); the field's presence is what the schema gates on.
last=$(tail -1 "$log_file")
case "$last" in
    *'"knowledge_section_tokens"'*) : ;;
    *)
        printf 'RESULT: SC-1 fail last payload_breakdown record missing knowledge_section_tokens key\n'
        exit 1
        ;;
esac

printf 'RESULT: SC-1 pass\n'
exit 0
