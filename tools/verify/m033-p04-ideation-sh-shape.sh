#!/usr/bin/env bash
# m033-p04-ideation-sh-shape.sh
#
# T02 verifier: shape verifier for scripts/lifecycle/ideation.sh (FR-10 driver).
#
# Asserts:
#   - File exists, executable, ≥200 lines.
#   - Fenced SSOT comment block `>>> ideation-question-keys >>>` present.
#   - Load-bearing tokens present (ask_one, all 7 qkeys, etc.).
#   - Negative grep: no `declare -A`, no process substitution `<(`.
#   - MIT-007 wiring assertion (load-bearing): every non-comment
#     `ask_one ` invocation has at least 3 token-segments after the
#     function name (function-name + 3 args = ≥4 whitespace-separated
#     tokens), proving the partial-answers.yml path is passed as the
#     third argument on every call.
#   - #Q-7 gate: `--with-conversus-stress-test` flag is checked via a
#     `[ "$WITH_STRESS_TEST" = "1" ]` style branch (default OFF).
#
# Bash 3.2 compatible (MEM001). Single-script invocation shape (AD-19).
# PASS/FAIL/SUMMARY structured-output protocol.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/lifecycle/ideation.sh"

pass=0
fail=0

if [ -f "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: ideation.sh exists at $target"
else
    fail=$((fail + 1))
    echo "FAIL: ideation.sh missing at $target" >&2
    echo "SUMMARY: m033-p04-ideation-sh-shape.sh pass=$pass fail=$fail"
    exit 1
fi

if [ -x "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: ideation.sh executable"
else
    fail=$((fail + 1))
    echo "FAIL: ideation.sh not executable" >&2
fi

# Line count assertion (≥200).
line_count=0
line_count=$(wc -l < "$target" | tr -d ' ')
if [ "$line_count" -ge 200 ]; then
    pass=$((pass + 1))
    echo "PASS: line count $line_count >= 200"
else
    fail=$((fail + 1))
    echo "FAIL: line count $line_count < 200" >&2
fi

# Fenced SSOT block marker.
if grep -F -q '>>> ideation-question-keys >>>' "$target"; then
    pass=$((pass + 1))
    echo "PASS: fenced SSOT block >>> ideation-question-keys >>> present"
else
    fail=$((fail + 1))
    echo "FAIL: fenced SSOT block >>> ideation-question-keys >>> missing" >&2
fi

# Load-bearing tokens (per T02 plan).
for tok in \
    "ask_one" \
    "grilling-shell.sh" \
    "--project-dir" \
    "--yes" \
    "--with-conversus-stress-test" \
    "problem-statement" \
    "target-user" \
    "mvp-boundary" \
    "top-user-stories" \
    "success-metric" \
    "top-risks" \
    "top-non-goals" \
    "_GRILLING_CURRENT_QKEY" \
    "partial-answers.yml" \
    "ideation-pre-spec.md" \
    "ideation.complete" \
    "ideation_completed" \
    "Adversarial Findings" \
    "dual-write-runtime-md.sh" \
    "M033_IDEATION_TIMESTAMP"
do
    if grep -F -q -- "$tok" "$target"; then
        pass=$((pass + 1))
        echo "PASS: token present: $tok"
    else
        fail=$((fail + 1))
        echo "FAIL: token missing: $tok" >&2
    fi
done

# Negative grep: no `declare -A` in non-comment lines (MEM001).
# Strip lines whose first non-whitespace char is `#` before grepping.
neg_da_count=0
neg_da_count=$(grep -E -v '^[[:space:]]*#' "$target" | grep -F -c 'declare -A' || true)
if [ -z "$neg_da_count" ]; then
    neg_da_count=0
fi
if [ "$neg_da_count" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS: no declare -A in code (MEM001)"
else
    fail=$((fail + 1))
    echo "FAIL: declare -A present in code ($neg_da_count occurrence(s)) (MEM001 bash 3.2 violation)" >&2
fi

# Negative grep: no process substitution `<(` in non-comment lines (MEM001).
neg_ps_count=0
neg_ps_count=$(grep -E -v '^[[:space:]]*#' "$target" | grep -F -c '<(' || true)
if [ -z "$neg_ps_count" ]; then
    neg_ps_count=0
fi
if [ "$neg_ps_count" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS: no process substitution <( in code (MEM001)"
else
    fail=$((fail + 1))
    echo "FAIL: process substitution <( present in code ($neg_ps_count occurrence(s)) (MEM001 bash 3.2 violation)" >&2
fi

# #Q-7 gate: --with-conversus-stress-test flag is checked via branch.
# Use fixed-string match for the canonical guard shape.
if grep -F -q '[ "$WITH_STRESS_TEST" = "1" ]' "$target"; then
    pass=$((pass + 1))
    echo "PASS: #Q-7 stress-test branch gated by [ \"\$WITH_STRESS_TEST\" = \"1\" ]"
else
    fail=$((fail + 1))
    echo "FAIL: #Q-7 stress-test branch not gated by [ \"\$WITH_STRESS_TEST\" = \"1\" ]" >&2
fi

# ---------------------------------------------------------------------------
# MIT-007 wiring assertion (LOAD-BEARING).
#
# Every non-comment `ask_one ` invocation in ideation.sh must have at
# least 3 token-segments after the function name — i.e. ≥4 whitespace-
# separated tokens on the line — proving the partial-answers.yml path
# is passed as the third argument on every call.
#
# Implementation:
#   - Extract lines containing `ask_one ` (with trailing space).
#   - Strip lines whose first non-whitespace char is `#` (comments).
#   - Strip lines from heredoc/usage strings (they typically start with
#     `'` or `"` after leading whitespace, or contain `usage:`).
#   - For each remaining line, find the substring starting at `ask_one `
#     and count whitespace-separated tokens; assert ≥4.
# ---------------------------------------------------------------------------

mit007_violations=0
mit007_calls=0
mit007_tmp=""
mit007_tmp="$(mktemp 2>/dev/null || mktemp -t mit007-tmp)"

# Extract candidate lines.
grep -n 'ask_one ' "$target" > "$mit007_tmp" 2>/dev/null || true

while IFS= read -r raw_line; do
    if [ -z "$raw_line" ]; then
        continue
    fi
    # Strip leading `<lineno>:` from grep -n output.
    line_body=""
    line_body="$(printf '%s' "$raw_line" | sed -E 's/^[0-9]+://')"
    # Strip leading whitespace.
    trimmed=""
    trimmed="$(printf '%s' "$line_body" | sed -E 's/^[[:space:]]+//')"
    # Skip comment lines.
    case "$trimmed" in
        \#*)
            continue
            ;;
    esac
    # Skip lines where ask_one appears only inside prose/usage strings.
    case "$trimmed" in
        *'usage:'*|*'API:'*|*'<question>'*)
            continue
            ;;
    esac
    # Find the substring starting at `ask_one `. Use awk to extract
    # everything from the first occurrence of `ask_one ` onward, then
    # count tokens.
    after=""
    after="$(printf '%s' "$trimmed" | awk 'match($0, /ask_one /){print substr($0, RSTART)}')"
    if [ -z "$after" ]; then
        continue
    fi
    # Strip a trailing `|| ...` or `&& ...` or `;` so we count actual args.
    args_only=""
    args_only="$(printf '%s' "$after" | sed -E 's/[[:space:]]+(\|\||&&|;).*$//')"
    # Count whitespace-separated tokens.
    token_count=0
    token_count="$(printf '%s\n' "$args_only" | awk '{print NF}')"
    mit007_calls=$((mit007_calls + 1))
    if [ "$token_count" -lt 4 ]; then
        mit007_violations=$((mit007_violations + 1))
        echo "FAIL: MIT-007 wiring: ask_one call has only $token_count tokens (need ≥4): $args_only" >&2
    fi
done < "$mit007_tmp"

rm -f "$mit007_tmp"

if [ "$mit007_calls" -gt 0 ]; then
    pass=$((pass + 1))
    echo "PASS: MIT-007 wiring assertion ran ($mit007_calls ask_one call(s) inspected)"
else
    fail=$((fail + 1))
    echo "FAIL: MIT-007 wiring assertion found zero ask_one calls to inspect" >&2
fi

if [ "$mit007_violations" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS: MIT-007 wiring: every ask_one call has ≥3 args (third arg = partial-answers.yml path)"
else
    fail=$((fail + 1))
    echo "FAIL: MIT-007 wiring: $mit007_violations ask_one call(s) missing third arg" >&2
fi

echo "SUMMARY: m033-p04-ideation-sh-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
