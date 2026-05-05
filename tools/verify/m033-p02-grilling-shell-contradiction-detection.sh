#!/usr/bin/env bash
# m033-p02-grilling-shell-contradiction-detection.sh
#
# Verifier for M033/P02/T04: asserts that the MIT-007 contradiction-detection
# wiring in scripts/lifecycle/grilling-shell.sh is live (not the T03 stub),
# the # >>> contradiction-pairs >>> SSOT block is populated with at least 3
# pairs in the documented <key>:<a>:<b> format, and a sandboxed functional
# smoke test surfaces a `contradiction:` line on stdout when invoked against a
# contradicting accumulator.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m033-p02-grilling-shell-contradiction-detection.sh
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

module="$PROJECT_ROOT/scripts/lifecycle/grilling-shell.sh"

pass=0
fail=0

check_pass() {
    pass=$((pass + 1))
    echo "PASS: $1"
}

check_fail() {
    fail=$((fail + 1))
    echo "FAIL: $1"
}

# Check 1: module exists.
if [ ! -f "$module" ]; then
    echo "FAIL: scripts/lifecycle/grilling-shell.sh missing at $module"
    echo "SUMMARY: m033-p02-grilling-shell-contradiction-detection.sh pass=0 fail=1"
    exit 1
fi
check_pass "scripts/lifecycle/grilling-shell.sh exists"

# Check 2: contradiction-pairs SSOT block populated with at least 3 pairs.
# Extract lines between `# >>> contradiction-pairs >>>` and `# <<< contradiction-pairs <<<`,
# then count lines matching the <key>:<a>:<b> shape. Strip leading whitespace
# and quotes so the variable assignment lines are also counted.
pair_block=$(awk '/^# >>> contradiction-pairs >>>/{f=1; next} /^# <<< contradiction-pairs <<</{f=0} f' "$module")
pair_count=$(printf '%s\n' "$pair_block" | grep -E '^[[:space:]]*"?[a-z][a-z0-9-]*:[a-z][a-z0-9-]*:[a-z][a-z0-9-]*"?$' | wc -l | tr -d ' ')

if [ "${pair_count:-0}" -ge 3 ]; then
    check_pass "contradiction-pairs SSOT block populated with $pair_count pairs (>=3)"
else
    check_fail "contradiction-pairs SSOT block has $pair_count pairs (need >=3)"
fi

# Check 3: literal token MIT-007 present.
if grep -qF 'MIT-007' "$module"; then
    check_pass "module references MIT-007"
else
    check_fail "module missing MIT-007 reference"
fi

# Check 4: literal token contradiction: present.
if grep -qF 'contradiction:' "$module"; then
    check_pass "module contains load-bearing token contradiction:"
else
    check_fail "module missing load-bearing token contradiction:"
fi

# Check 5: function name _grilling_check_contradiction defined.
if grep -qF '_grilling_check_contradiction' "$module"; then
    check_pass "module defines _grilling_check_contradiction"
else
    check_fail "module missing _grilling_check_contradiction"
fi

# Check 6: literal token context_file appears (parameter convention).
if grep -qF 'context_file' "$module"; then
    check_pass "module references context_file (MIT-007 wiring parameter)"
else
    check_fail "module missing context_file reference"
fi

# Check 7: caller-set var _GRILLING_CURRENT_QKEY referenced.
if grep -qF '_GRILLING_CURRENT_QKEY' "$module"; then
    check_pass "module reads caller-set _GRILLING_CURRENT_QKEY"
else
    check_fail "module missing _GRILLING_CURRENT_QKEY reference"
fi

# Check 8: _grilling_check_contradiction body is non-trivial (>5 lines between
# the function opener `_grilling_check_contradiction() {` and matching `}`).
fn_body=$(awk '/^_grilling_check_contradiction\(\) \{/,/^\}/' "$module")
fn_lines=$(printf '%s\n' "$fn_body" | wc -l | tr -d ' ')
if [ "${fn_lines:-0}" -gt 5 ]; then
    check_pass "_grilling_check_contradiction body is non-trivial ($fn_lines lines > 5 — no longer a stub)"
else
    check_fail "_grilling_check_contradiction body too small ($fn_lines lines, looks like the T03 stub)"
fi

# Check 9: functional smoke test — sandboxed source + invoke with a
# contradicting accumulator emits `contradiction:` on stdout.
smoke_dir=""
smoke_dir=$(mktemp -d)
smoke_accum="$smoke_dir/partial-answers.yml"
printf 'target-user: consumer\n' > "$smoke_accum"

smoke_out="$smoke_dir/smoke.out"
PROJECT_DIR="$smoke_dir" \
_GRILLING_CURRENT_QKEY="target-user" \
bash -c ". \"$module\" && ask_one 'Refine?' 'enterprise' '$smoke_accum'" \
    < <(printf 'y\n!attest-reason\n') \
    > "$smoke_out" 2>/dev/null \
    || true

if grep -qF 'contradiction: target-user' "$smoke_out"; then
    check_pass "functional smoke: contradiction: target-user fired against contradicting accumulator"
else
    check_fail "functional smoke: contradiction: line missing (smoke_out=$(cat "$smoke_out" 2>/dev/null))"
fi

if grep -qF 'attestation:' "$smoke_out"; then
    check_pass "functional smoke: attestation: surfaced on accept-with-attestation reconciliation"
else
    check_fail "functional smoke: attestation: line missing"
fi

rm -rf "$smoke_dir"

echo ""
echo "SUMMARY: m033-p02-grilling-shell-contradiction-detection.sh pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
