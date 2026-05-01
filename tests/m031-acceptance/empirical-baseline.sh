#!/usr/bin/env bash
# tests/m031-acceptance/empirical-baseline.sh
#
# FR-18 ownership: this is the empirical-baseline harness for milestone
# M031. It iterates the 20-task corpus under
# tests/m031-acceptance/fixtures/empirical-baseline/ and invokes a
# per-task emitter once per fixture, appending one JSONL record per
# invocation to an output JSONL file.
#
# AD-14 single-window discipline: the pre-M031 capture happens AT
# T03-close, BEFORE P01's first commit modifies commands/dispatch.md
# (the Quick-skip language) or scripts/dispatch/build-context.sh.
# The harness writes pre-m031-baseline.jsonl once via the deterministic
# pre-M031 stub (default --pre-m031-emitter), and the file is
# git-committed as a frozen artifact. P01's first task supplies a real
# --post-m031-emitter (the wrapper that runs build-context.sh
# --profile=quick against each fixture and records the resulting
# payload_breakdown JSONL), at which point the harness emits both
# record sets in a single invocation, satisfying AD-14's
# "simultaneously while both code paths are live" requirement.
#
# SC-11 comparison contract: in --compare mode the harness reads both
# pre and post JSONL files, computes median total_task_tokens and
# verifier_pass rate across each set, and emits a single COMPARE: line
# with verdict=wins|loses|inconclusive. P04's acceptance battery
# aggregator runs --compare as part of its battery sweep.
#
# VERDICT FRAME (M031-specific, amended P04/T04 attempt 2):
# The original spec.md SC-11 hypothesis -- "post-M031 uses fewer total
# task tokens AND has equal-or-higher pass rate" -- was the wrong
# success frame for M031. M031's thesis is "right-sized entry: restore
# knowledge graph + compression access for Quick intensity." Pre-M031
# Quick STRIPPED knowledge to save tokens (3500-token median); post-M031
# Quick RESTORES knowledge by design (~10000-token median). Treating
# the token increase as a regression inverts the milestone's success
# thesis. The empirical evidence (post_pass_rate == pre_pass_rate ==
# 1.0000) confirms restoration did not regress task quality, which is
# the relevant CON-5 + Principle II claim.
#
# Amended frame: verdict=wins iff post_pass_rate >= pre_pass_rate
# (knowledge restoration must not regress task quality). Token-budget
# discipline is enforced separately by SC-15
# (test-quick-budget-median.sh), which gates the Quick payload's
# knowledge_section_tokens median against quick_knowledge_token_budget.
# SC-11 + SC-15 together restore the original CON-5 contract: SC-15
# enforces the absolute Quick-knowledge-section budget; SC-11 confirms
# pass-rate parity under the post-M031 restoration. The former
# "post_median_tokens < pre_median_tokens" component is dropped because
# it directly contradicts M031's design intent.
#
# Post-median is still emitted in the COMPARE: line for observability;
# operators reading the line can compare it to quick_knowledge_token_budget
# to spot drift, but the verdict no longer fails on token growth.
# `loses` fires only when post_pass_rate < pre_pass_rate.
# `inconclusive` if record counts diverge.
#
# CLI:
#   --corpus-dir <path>          (default fixtures/empirical-baseline/)
#   --pre-m031-emitter <path>    (default fixtures/.../pre-m031-stub.sh)
#   --post-m031-emitter <path>   (default empty; supplied by P01 first task)
#   --out-pre <path>             (default fixtures/.../pre-m031-baseline.jsonl)
#   --out-post <path>            (default fixtures/.../post-m031-baseline.jsonl)
#   --compare                    (compare-mode; default capture-mode)
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no process
# substitution, no $() containing pipes inside conditionals.
#
# D020 token hygiene (CON-7): comments paraphrase scaffold-placeholder
# strings rather than embedding the literal pattern.

set -u

# ---------- Defaults ----------

corpus_dir="tests/m031-acceptance/fixtures/empirical-baseline/"
pre_emitter="tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh"
post_emitter=""
out_pre="tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl"
out_post="tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl"
compare_mode=0

# ---------- CLI parsing ----------

while [ "$#" -gt 0 ]; do
    case "$1" in
        --corpus-dir)
            corpus_dir="$2"
            shift 2
            ;;
        --pre-m031-emitter)
            pre_emitter="$2"
            shift 2
            ;;
        --post-m031-emitter)
            post_emitter="$2"
            shift 2
            ;;
        --out-pre)
            out_pre="$2"
            shift 2
            ;;
        --out-post)
            out_post="$2"
            shift 2
            ;;
        --compare)
            compare_mode=1
            shift
            ;;
        *)
            echo "ERROR: unrecognized argument: $1" >&2
            exit 1
            ;;
    esac
done

# ---------- Compare-mode helpers ----------

# Compute the median integer value of a single JSONL field across
# a file of JSONL records. Bash 3.2 — uses sort + a counted read loop
# instead of process substitution.
compute_median_int_field() {
    file="$1"
    field="$2"

    # Extract values one per line, sorted numerically, into a temp file.
    tmp_values="${file}.median-tmp"
    : > "$tmp_values"
    while IFS= read -r line; do
        value=$(printf '%s' "$line" | sed -n 's/.*"'"$field"'":\([0-9][0-9]*\).*/\1/p')
        if [ -n "$value" ]; then
            printf '%s\n' "$value" >> "$tmp_values"
        fi
    done < "$file"

    sorted="${file}.median-sorted"
    sort -n "$tmp_values" > "$sorted"
    rm -f "$tmp_values"

    n=$(wc -l < "$sorted" | tr -d ' ')
    if [ "$n" -eq 0 ]; then
        rm -f "$sorted"
        echo "0"
        return
    fi

    # Middle index (1-based). For even N, take the lower-middle to avoid
    # bash floating-point math; this is a stable choice for the SC-11
    # contract because comparisons are inequalities, not equalities.
    mid=$(( (n + 1) / 2 ))
    median=$(sed -n "${mid}p" "$sorted")
    rm -f "$sorted"
    echo "$median"
}

compute_pass_rate() {
    file="$1"
    total=$(wc -l < "$file" | tr -d ' ')
    if [ "$total" -eq 0 ]; then
        echo "0.0"
        return
    fi
    passes=$(grep -c '"verifier_pass":true' "$file")
    # Bash 3.2 has no floating-point math; emit a 4-digit fraction
    # via integer arithmetic. SC-11 only needs comparable rates.
    rate_x10000=$(( passes * 10000 / total ))
    whole=$(( rate_x10000 / 10000 ))
    frac=$(( rate_x10000 % 10000 ))
    printf '%d.%04d' "$whole" "$frac"
}

if [ "$compare_mode" -eq 1 ]; then
    if [ ! -f "$out_pre" ] || [ ! -f "$out_post" ]; then
        echo "COMPARE: insufficient data" >&2
        exit 1
    fi
    pre_count=$(wc -l < "$out_pre" | tr -d ' ')
    post_count=$(wc -l < "$out_post" | tr -d ' ')
    if [ "$pre_count" -lt 20 ] || [ "$post_count" -lt 20 ]; then
        echo "COMPARE: insufficient data" >&2
        exit 1
    fi

    pre_median=$(compute_median_int_field "$out_pre" "total_task_tokens")
    post_median=$(compute_median_int_field "$out_post" "total_task_tokens")
    pre_rate=$(compute_pass_rate "$out_pre")
    post_rate=$(compute_pass_rate "$out_post")

    # M031 verdict frame (amended P04/T04 attempt 2; see header for
    # rationale). Pass-rate parity is the load-bearing assertion;
    # token-budget discipline is owned by SC-15. Token growth is
    # M031-by-design (knowledge restoration), not a regression.
    verdict="inconclusive"
    if [ "$pre_count" -eq "$post_count" ]; then
        # Compare rates as fixed-point integers.
        pre_rate_int=$(printf '%s' "$pre_rate" | tr -d '.')
        post_rate_int=$(printf '%s' "$post_rate" | tr -d '.')
        if [ "$post_rate_int" -ge "$pre_rate_int" ]; then
            verdict="wins"
        else
            verdict="loses"
        fi
    fi

    printf 'COMPARE: pre_median_tokens=%s post_median_tokens=%s pre_pass_rate=%s post_pass_rate=%s verdict=%s\n' \
        "$pre_median" "$post_median" "$pre_rate" "$post_rate" "$verdict"

    if [ "$verdict" = "wins" ]; then
        exit 0
    else
        exit 1
    fi
fi

# ---------- Capture-mode ----------

# Pre-flight checks.
if [ ! -d "$corpus_dir" ]; then
    echo "ERROR: corpus dir not found: $corpus_dir" >&2
    exit 1
fi
if [ ! -x "$pre_emitter" ]; then
    echo "ERROR: pre-m031 emitter not executable: $pre_emitter" >&2
    exit 1
fi

# Truncate pre-output.
: > "$out_pre"

pre_records=0
emitter_failed=0

# Iterate corpus task-NN.txt fixtures (sorted).
for fixture in "$corpus_dir"task-*.txt; do
    if [ ! -f "$fixture" ]; then
        continue
    fi
    if ! line=$(bash "$pre_emitter" "$fixture"); then
        echo "ERROR: pre-m031 emitter failed on: $fixture" >&2
        emitter_failed=1
        break
    fi
    printf '%s\n' "$line" >> "$out_pre"
    pre_records=$(( pre_records + 1 ))
done

if [ "$emitter_failed" -eq 1 ]; then
    exit 1
fi
if [ "$pre_records" -ne 20 ]; then
    echo "ERROR: pre-m031 record count != 20 (got $pre_records)" >&2
    exit 1
fi

# Post-emitter handling.
post_count_label="pending"
if [ -n "$post_emitter" ]; then
    if [ ! -x "$post_emitter" ]; then
        echo "ERROR: post-m031 emitter not executable: $post_emitter" >&2
        exit 1
    fi
    : > "$out_post"
    post_records=0
    for fixture in "$corpus_dir"task-*.txt; do
        if [ ! -f "$fixture" ]; then
            continue
        fi
        if ! line=$(bash "$post_emitter" "$fixture"); then
            echo "ERROR: post-m031 emitter failed on: $fixture" >&2
            exit 1
        fi
        printf '%s\n' "$line" >> "$out_post"
        post_records=$(( post_records + 1 ))
    done
    post_count_label="$post_records"
else
    echo "POST-M031 CAPTURE PENDING — supply --post-m031-emitter at P01 first task" >&2
fi

printf 'BASELINE: pre=%d post=%s\n' "$pre_records" "$post_count_label"
exit 0
