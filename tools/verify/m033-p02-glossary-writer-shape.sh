#!/usr/bin/env bash
# m033-p02-glossary-writer-shape.sh
#
# Verifier for M033/P02/T04: asserts that the FR-18 glossary inline-update
# writer in scripts/lifecycle/grilling-shell.sh is live (not the T03 stub),
# the # >>> glossary-triggers >>> SSOT block is populated with at least 3
# trigger keys, and a sandboxed functional smoke test demonstrates an entry
# is written to <PROJECT_DIR>/wiki/glossary.md and is idempotent on identical
# input.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m033-p02-glossary-writer-shape.sh
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
    echo "SUMMARY: m033-p02-glossary-writer-shape.sh pass=0 fail=1"
    exit 1
fi
check_pass "scripts/lifecycle/grilling-shell.sh exists"

# Check 2: glossary-triggers SSOT block populated with at least 3 trigger keys.
# Extract lines between fenced markers; count quoted-or-bare slug lines.
trig_block=$(awk '/^# >>> glossary-triggers >>>/{f=1; next} /^# <<< glossary-triggers <<</{f=0} f' "$module")
trig_count=$(printf '%s\n' "$trig_block" | grep -E '^[[:space:]]*"?[a-z][a-z0-9-]*"?$' | wc -l | tr -d ' ')

if [ "${trig_count:-0}" -ge 3 ]; then
    check_pass "glossary-triggers SSOT block populated with $trig_count keys (>=3)"
else
    check_fail "glossary-triggers SSOT block has $trig_count keys (need >=3)"
fi

# Check 3: literal token FR-18 present.
if grep -qF 'FR-18' "$module"; then
    check_pass "module references FR-18 (inline glossary writer spec)"
else
    check_fail "module missing FR-18 reference"
fi

# Check 4: literal token glossary.md present.
if grep -qF 'glossary.md' "$module"; then
    check_pass "module references glossary.md"
else
    check_fail "module missing glossary.md reference"
fi

# Check 5: literal token wiki/ present (the FR-18 directory convention).
if grep -qF 'wiki/' "$module"; then
    check_pass "module references wiki/ directory"
else
    check_fail "module missing wiki/ reference"
fi

# Check 6: function name _grilling_glossary_update defined.
if grep -qF '_grilling_glossary_update' "$module"; then
    check_pass "module defines _grilling_glossary_update"
else
    check_fail "module missing _grilling_glossary_update"
fi

# Check 7: alphabetized-insert mechanism present (literal token or awk usage).
if grep -qF 'alphabetized-insert' "$module"; then
    check_pass "module documents alphabetized-insert mechanism"
elif grep -qF 'awk' "$module"; then
    check_pass "module uses awk (alphabetized-insert mechanism)"
else
    check_fail "module missing alphabetized-insert/awk mechanism"
fi

# Check 8: _grilling_glossary_update body is non-trivial (>10 lines).
fn_body=$(awk '/^_grilling_glossary_update\(\) \{/,/^\}/' "$module")
fn_lines=$(printf '%s\n' "$fn_body" | wc -l | tr -d ' ')
if [ "${fn_lines:-0}" -gt 10 ]; then
    check_pass "_grilling_glossary_update body is non-trivial ($fn_lines lines > 10 — no longer a stub)"
else
    check_fail "_grilling_glossary_update body too small ($fn_lines lines, looks like the T03 stub)"
fi

# Check 9-10: functional smoke — invoke ask_one with a glossary trigger, assert
# entry is written, then re-invoke and assert byte-equality (idempotency).
smoke_dir=""
smoke_dir=$(mktemp -d)
smoke_glossary="$smoke_dir/wiki/glossary.md"

smoke_out="$smoke_dir/smoke.out"
PROJECT_DIR="$smoke_dir" \
_GRILLING_CURRENT_QKEY="framework-chosen" \
bash -c ". \"$module\" && ask_one 'Which framework?' 'beta' ''" \
    < <(printf 'y\n') \
    > "$smoke_out" 2>/dev/null \
    || true

if [ -f "$smoke_glossary" ] && grep -qE '^beta: ' "$smoke_glossary"; then
    check_pass "functional smoke: glossary entry written for trigger qkey"
else
    check_fail "functional smoke: glossary file missing or no beta entry (path=$smoke_glossary)"
fi

# Snapshot for idempotency check.
smoke_snapshot="$smoke_dir/glossary.snapshot"
if [ -f "$smoke_glossary" ]; then
    cp "$smoke_glossary" "$smoke_snapshot"
fi

PROJECT_DIR="$smoke_dir" \
_GRILLING_CURRENT_QKEY="framework-chosen" \
bash -c ". \"$module\" && ask_one 'Which framework?' 'beta' ''" \
    < <(printf 'y\n') \
    > "$smoke_dir/smoke2.out" 2>/dev/null \
    || true

if [ -f "$smoke_snapshot" ] && cmp -s "$smoke_glossary" "$smoke_snapshot"; then
    check_pass "functional smoke: glossary byte-identical after re-trigger (idempotency)"
else
    check_fail "functional smoke: glossary mutated on identical re-trigger"
fi

rm -rf "$smoke_dir"

echo ""
echo "SUMMARY: m033-p02-glossary-writer-shape.sh pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
