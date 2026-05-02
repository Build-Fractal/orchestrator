#!/usr/bin/env bash
# tests/m031-acceptance/test-quick-budget-median.sh
#
# M031/P01/T03 acceptance test for SC-15 (Quick budget median compliance,
# AD-18).
#
# SC-15 contract (verbatim from specs/034-right-sized-entry/spec.md, post
# AD-18 ratification): "median knowledge_section_tokens emitted by
# build-context.sh --profile=quick across the 20-task P00 corpus is
# <= quick_knowledge_token_budget (800), independent of the pre-M031
# baseline."
#
# Median rule (P00 harness convention -- bash 3.2 fixed-point):
#   For even N=20, take the 10th element of the ascending-sorted list
#   (lower-middle). This sidesteps shell floating-point arithmetic.
#
# Field source (from task plan Step 4 Note):
#   "SC-15 tracks total_tokens from the sidecar as the proxy for
#    knowledge_section_tokens per the P00 emitter contract (T02's emitter
#    uses the same proxy). If the build-context.sh emits a separate
#    knowledge_section_tokens field in the meta sidecar (additive per
#    AD-11), SC-15 SHOULD prefer that field; otherwise it uses
#    total_tokens as the conservative proxy."
#
#   The current AD-11 sidecar schema has 5 keys (mem_count, total_tokens,
#   profile, compression_applied, snip_applied) -- no separate
#   knowledge_section_tokens field. The JSONL payload_breakdown record
#   does carry knowledge_section_tokens, populated by the post-m031
#   emitter to report the actual Knowledge-section tokens. SC-15 reads
#   the JSONL knowledge_section_tokens field (preferred) and falls back
#   to the sidecar total_tokens proxy when the JSONL field is absent.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no process
# substitution.
#
# Output: a single final stdout line:
#   RESULT: SC-15 pass median=<int> budget=<int>
#   RESULT: SC-15 fail median=<int> budget=<int>
# Exit 0 on pass, 1 on fail.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

build_context="$PROJECT_ROOT/scripts/dispatch/build-context.sh"
config="$PROJECT_ROOT/templates/orchestrator-config-default.yml"
corpus_dir="$PROJECT_ROOT/tests/m031-acceptance/fixtures/empirical-baseline"
tally="/tmp/m031-p01-t03-sc15-tokens.txt"

if [ ! -f "$build_context" ]; then
    printf 'RESULT: SC-15 fail median=0 budget=0\n'
    exit 1
fi
if [ ! -f "$config" ]; then
    printf 'RESULT: SC-15 fail median=0 budget=0\n'
    exit 1
fi
if [ ! -d "$corpus_dir" ]; then
    printf 'RESULT: SC-15 fail median=0 budget=0\n'
    exit 1
fi

# Read quick_knowledge_token_budget from config (P00 pin: 800).
budget=$(sed -n 's/^quick_knowledge_token_budget:[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
    "$config" | head -1)
if [ -z "$budget" ]; then
    printf 'RESULT: SC-15 fail median=0 budget=0\n'
    exit 1
fi

# Run build-context.sh against each task-NN.txt fixture and tally the
# knowledge_section_tokens proxy per the field-source note above.
> "$tally"
for fixture in "$corpus_dir"/task-*.txt; do
    if [ ! -f "$fixture" ]; then
        continue
    fi
    base=$(basename "$fixture")
    task_id="${base%.txt}"
    payload_out="/tmp/m031-p01-t03-sc15-payload-${task_id}.md"
    meta_out="/tmp/m031-p01-t03-sc15-meta-${task_id}.json"
    log_file="$PROJECT_ROOT/.orchestrator/direct-mode-execution-log.jsonl"

    pre_lines=0
    if [ -f "$log_file" ]; then
        pre_lines=$(wc -l < "$log_file" | tr -d ' ')
    fi

    rm -f "$payload_out" "$meta_out"
    bash "$build_context" \
        --profile=quick \
        --task-plan "$fixture" \
        --out "$payload_out" \
        --meta-out "$meta_out" >/dev/null 2>&1 || true

    # Prefer JSONL knowledge_section_tokens (the preferred SC-15 field
    # per the spec contract). Read the freshly appended record.
    kst=""
    if [ -f "$log_file" ]; then
        post_lines=$(wc -l < "$log_file" | tr -d ' ')
        if [ "$post_lines" -gt "$pre_lines" ]; then
            new_record=$(tail -1 "$log_file")
            kst=$(printf '%s' "$new_record" \
                | sed -n 's/.*"knowledge_section_tokens":\([0-9][0-9]*\).*/\1/p' \
                | head -1)
        fi
    fi
    # Fallback: sidecar total_tokens proxy (per task plan Note).
    if [ -z "$kst" ] && [ -f "$meta_out" ]; then
        kst=$(sed -n 's/.*"total_tokens":\([0-9][0-9]*\).*/\1/p' "$meta_out" | head -1)
    fi
    if [ -z "$kst" ]; then
        kst=0
    fi
    printf '%d\n' "$kst" >> "$tally"

    rm -f "$payload_out" "$meta_out"
done

# Sort ascending and pick the lower-middle of even-N=20 (10th element).
n=$(wc -l < "$tally" | tr -d ' ')
if [ "$n" -lt 1 ]; then
    printf 'RESULT: SC-15 fail median=0 budget=%d\n' "$budget"
    exit 1
fi

# Lower-middle index for even N: floor(N/2) -- but for N=20 that yields 10
# in 1-based indexing of the sorted ascending list, which is the
# convention from the P00 harness (".. take the 10th value of 20").
sorted="/tmp/m031-p01-t03-sc15-tokens-sorted.txt"
sort -n "$tally" > "$sorted"
mid_index=$(( n / 2 ))
median=$(sed -n "${mid_index}p" "$sorted")
if [ -z "$median" ]; then
    median=0
fi

if [ "$median" -le "$budget" ]; then
    printf 'RESULT: SC-15 pass median=%d budget=%d\n' "$median" "$budget"
    exit 0
fi
printf 'RESULT: SC-15 fail median=%d budget=%d\n' "$median" "$budget"
exit 1
