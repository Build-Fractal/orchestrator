#!/usr/bin/env bash
# tools/verify/m031-p01-post-baseline-jsonl-population.sh
#
# M031/P01/T02 verifier (project-owned, slug-bearing under tools/verify/).
#
# Asserts the post-M031 baseline JSONL was captured during the AD-14
# single-execution window and is shaped per the post-m031 schema:
#   1) the file exists at the expected fixtures path,
#   2) it carries exactly 20 records (one per corpus task),
#   3) every record carries the literal "path":"post-m031" tag,
#   4) every record carries a "knowledge_section_tokens":<int> field, and
#      at least 19 of 20 records report a non-zero value (one degenerate
#      fallback is allowed per the spec's "empty touched-file set falls
#      back to milestone scope" edge case for task-06).
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A.

set -u

JSONL="tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl"

pass=0
fail=0

ok() {
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$1"
}
ng() {
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$1"
}

# --- 1) File exists ---
if [ -f "$JSONL" ]; then
    ok "post-m031-baseline.jsonl exists at $JSONL"
else
    ng "post-m031-baseline.jsonl missing at $JSONL"
    printf 'SUMMARY: m031-p01-post-baseline-jsonl-population.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# --- 2) Exactly 20 lines ---
line_count=$(wc -l < "$JSONL" | tr -d ' ')
if [ "$line_count" -eq 20 ]; then
    ok "post-m031-baseline.jsonl has exactly 20 records"
else
    ng "post-m031-baseline.jsonl line count is $line_count (expected 20)"
fi

# --- 3) Every line contains "path":"post-m031" ---
post_tag_count=$(grep -c '"path":"post-m031"' "$JSONL")
if [ "$post_tag_count" -eq 20 ]; then
    ok "every record carries \"path\":\"post-m031\""
else
    ng "only $post_tag_count of 20 records carry \"path\":\"post-m031\""
fi

# --- 4) Every line has "knowledge_section_tokens":<int> field ---
field_count=$(grep -cE '"knowledge_section_tokens":[0-9]+' "$JSONL")
if [ "$field_count" -eq 20 ]; then
    ok "every record carries a knowledge_section_tokens integer field"
else
    ng "only $field_count of 20 records carry knowledge_section_tokens integer field"
fi

# --- 5) >= 19 of 20 records have non-zero knowledge_section_tokens ---
# Pattern requires one or more digits but rejects an isolated 0. The
# (?!) negative lookahead is not POSIX, so we count zero-valued records
# explicitly and subtract.
nonzero_count=0
zero_count=0
while IFS= read -r line; do
    value=$(printf '%s' "$line" | sed -n 's/.*"knowledge_section_tokens":\([0-9][0-9]*\).*/\1/p')
    if [ -z "$value" ]; then
        continue
    fi
    if [ "$value" -eq 0 ]; then
        zero_count=$(( zero_count + 1 ))
    else
        nonzero_count=$(( nonzero_count + 1 ))
    fi
done < "$JSONL"

if [ "$nonzero_count" -ge 19 ]; then
    ok "at least 19 of 20 records have non-zero knowledge_section_tokens (got $nonzero_count nonzero, $zero_count zero)"
else
    ng "only $nonzero_count of 20 records have non-zero knowledge_section_tokens (zeros: $zero_count)"
fi

printf 'SUMMARY: m031-p01-post-baseline-jsonl-population.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi
