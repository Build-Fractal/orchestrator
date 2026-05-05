#!/usr/bin/env bash
# m033-p02-grilling-shell-shape.sh
#
# Verifier for M033/P02/T03: asserts that scripts/lifecycle/grilling-shell.sh
# exists, is sourceable, defines `ask_one` with the documented signature, ships
# the recommendation-not-interrogation framing, and reserves the fenced SSOT
# comment block markers (`grilling-protocol-rules`, `contradiction-pairs`,
# `glossary-triggers`) that T04 will populate.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no process
# substitution. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m033-p02-grilling-shell-shape.sh
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
    echo "SUMMARY: m033-p02-grilling-shell-shape.sh pass=0 fail=1"
    exit 1
fi
check_pass "scripts/lifecycle/grilling-shell.sh exists"

# Check 2: literal token ask_one present.
if grep -q -F 'ask_one' "$module"; then
    check_pass "module contains literal token ask_one"
else
    check_fail "module missing literal token ask_one"
fi

# Check 3: literal token recommendation: present (load-bearing prefix).
if grep -q -F 'recommendation:' "$module"; then
    check_pass "module contains load-bearing token recommendation:"
else
    check_fail "module missing load-bearing token recommendation:"
fi

# Check 4: literal token answer: present (load-bearing prefix).
if grep -q -F 'answer:' "$module"; then
    check_pass "module contains load-bearing token answer:"
else
    check_fail "module missing load-bearing token answer:"
fi

# Check 5: CON-5 reference present in comments.
if grep -q -F 'CON-5' "$module"; then
    check_pass "module references CON-5 (sequential-never-batched invariant)"
else
    check_fail "module missing CON-5 reference"
fi

# Check 6: MIT-007 reference present in comments.
if grep -q -F 'MIT-007' "$module"; then
    check_pass "module references MIT-007 (contradiction detection)"
else
    check_fail "module missing MIT-007 reference"
fi

# Check 7: FR-17 reference present in comments.
if grep -q -F 'FR-17' "$module"; then
    check_pass "module references FR-17 (conversational-shell module spec)"
else
    check_fail "module missing FR-17 reference"
fi

# Check 8: grilling-protocol-rules SSOT block marker present.
if grep -q -F 'grilling-protocol-rules' "$module"; then
    check_pass "module contains grilling-protocol-rules SSOT block marker"
else
    check_fail "module missing grilling-protocol-rules SSOT block marker"
fi

# Check 9: contradiction-pairs SSOT block marker present (reserved for T04).
if grep -q -F 'contradiction-pairs' "$module"; then
    check_pass "module reserves contradiction-pairs SSOT block marker"
else
    check_fail "module missing contradiction-pairs SSOT block marker (T04 reservation)"
fi

# Check 10: glossary-triggers SSOT block marker present (reserved for T04).
if grep -q -F 'glossary-triggers' "$module"; then
    check_pass "module reserves glossary-triggers SSOT block marker"
else
    check_fail "module missing glossary-triggers SSOT block marker (T04 reservation)"
fi

# Check 11: fenced-block opener `# >>> grilling-protocol-rules >>>` present.
if grep -q -F '# >>> grilling-protocol-rules >>>' "$module"; then
    check_pass "module has fenced opener for grilling-protocol-rules"
else
    check_fail "module missing fenced opener # >>> grilling-protocol-rules >>>"
fi

# Check 12: fenced-block opener `# >>> contradiction-pairs >>>` present.
if grep -q -F '# >>> contradiction-pairs >>>' "$module"; then
    check_pass "module has fenced opener for contradiction-pairs"
else
    check_fail "module missing fenced opener # >>> contradiction-pairs >>>"
fi

# Check 13: fenced-block opener `# >>> glossary-triggers >>>` present.
if grep -q -F '# >>> glossary-triggers >>>' "$module"; then
    check_pass "module has fenced opener for glossary-triggers"
else
    check_fail "module missing fenced opener # >>> glossary-triggers >>>"
fi

# Check 14: NO top-level `set -e` / `set -u` / `set -o pipefail` (sourceability).
# Strip blank lines and comments, then check that no top-level (column 1) `set`
# command appears outside a function body. Heuristic: search for lines that
# start with `set -` at the very beginning of the line (no leading whitespace)
# AND are not inside a function. Simpler heuristic adequate for shape: assert
# no `^set -` line appears at all in the file.
if grep -qE '^set -' "$module"; then
    check_fail "module has top-level set - directive (would corrupt caller settings on source)"
else
    check_pass "module has no top-level set - directive (sourceability preserved)"
fi

# Check 15: NO top-level `exit` calls (sourceability — exit would kill caller).
# Heuristic: search for lines that start with `exit` at column 1, optionally
# followed by a number. Inside functions exit is indented; this catches the
# stray top-level case.
if grep -qE '^exit( |$|[0-9])' "$module"; then
    check_fail "module has top-level exit (would kill the sourcing caller)"
else
    check_pass "module has no top-level exit (sourceability preserved)"
fi

# Check 16: stub helper _grilling_check_contradiction defined (callable name
# stable across T03 -> T04).
if grep -q -F '_grilling_check_contradiction' "$module"; then
    check_pass "module defines stub _grilling_check_contradiction (T04 will populate body)"
else
    check_fail "module missing stub _grilling_check_contradiction"
fi

# Check 17: stub helper _grilling_glossary_update defined (callable name
# stable across T03 -> T04).
if grep -q -F '_grilling_glossary_update' "$module"; then
    check_pass "module defines stub _grilling_glossary_update (T04 will populate body)"
else
    check_fail "module missing stub _grilling_glossary_update"
fi

# Check 18: sourceable smoke — sourcing the module in a sandboxed bash subshell
# does not exit non-zero. Use a subshell so any function definitions do not
# leak into the verifier's environment.
sourcetest_out="$(bash -c '. '"\"$module\""' >/dev/null 2>&1 && echo OK')"
if [ "$sourcetest_out" = "OK" ]; then
    check_pass "module sources cleanly (no non-zero exit on source)"
else
    check_fail "module failed to source cleanly"
fi

# Check 19: ask_one is a function after sourcing — declare -F reports it.
declF_out="$(bash -c '. '"\"$module\""' >/dev/null 2>&1 ; declare -F ask_one')"
case "$declF_out" in
    *ask_one*)
        check_pass "ask_one is defined as a function after sourcing"
        ;;
    *)
        check_fail "ask_one is NOT defined as a function after sourcing (declare -F output: $declF_out)"
        ;;
esac

# Check 20: functional smoke — sourcing the module and invoking
# `ask_one 'What is your stack?' 'web-saas'` against simulated stdin `y\n`
# yields output that contains both `recommendation: web-saas` and
# `answer: web-saas`, with `recommendation:` appearing before `answer:`.
smoke_out="$(printf 'y\n' | bash -c '. '"\"$module\""' ; ask_one "What is your stack?" "web-saas"' 2>/dev/null)"

if echo "$smoke_out" | grep -q -F 'recommendation: web-saas'; then
    check_pass "smoke: stdout contains recommendation: web-saas"
else
    check_fail "smoke: stdout missing recommendation: web-saas (got: $smoke_out)"
fi

if echo "$smoke_out" | grep -q -F 'answer: web-saas'; then
    check_pass "smoke: stdout contains answer: web-saas"
else
    check_fail "smoke: stdout missing answer: web-saas (got: $smoke_out)"
fi

# Check 21: recommendation-not-interrogation ordering — recommendation: must
# appear on a line BEFORE answer: in stdout.
rec_line="$(echo "$smoke_out" | grep -n -F 'recommendation:' | head -1 | cut -d: -f1)"
ans_line="$(echo "$smoke_out" | grep -n -F 'answer:' | head -1 | cut -d: -f1)"
if [ -n "$rec_line" ] && [ -n "$ans_line" ] && [ "$rec_line" -lt "$ans_line" ]; then
    check_pass "ordering: recommendation: precedes answer: (recommendation-not-interrogation framing)"
else
    check_fail "ordering: recommendation: did not precede answer: (rec_line=$rec_line ans_line=$ans_line)"
fi

# Check 22: ask_one is defined as a single function (not a loop wrapper).
# Heuristic for the sequential-not-batched invariant at the SSOT-shape level:
# the body of ask_one (between `ask_one() {` and the matching closing `}`)
# does not contain a `for ` or `while ` loop wrapping multiple `ask_one`
# invocations. Implementation: simply assert ask_one() body contains no
# nested `ask_one` invocation, which would imply self-batching.
ask_one_body="$(awk '/^ask_one\(\) \{/,/^\}/' "$module")"
# Count lines whose first non-whitespace token is `ask_one` — i.e. self-invocations.
# This excludes diagnostic strings like `echo "usage: ask_one ..."` that merely
# mention the function name.
nested_count="$(echo "$ask_one_body" | grep -cE '^[[:space:]]+ask_one[[:space:]]')"
# In the canonical T03 shape there are zero nested invocations — `ask_one`
# does not call itself.
if [ "${nested_count:-0}" -eq 0 ]; then
    check_pass "ask_one body has no nested ask_one invocations (sequential-not-batched at the function level)"
else
    check_fail "ask_one body contains $nested_count nested ask_one invocations (CON-5 violation risk)"
fi

# Check 23: ask_one body uses printf (not echo -e) for load-bearing prefixes.
# Per the constraint: `recommendation:` and `answer:` line prefixes are
# load-bearing — use printf (not echo -e).
if echo "$ask_one_body" | grep -q -F "printf 'recommendation:"; then
    check_pass "ask_one uses printf for load-bearing recommendation: prefix"
else
    check_fail "ask_one does not use printf for recommendation: (constraint violation)"
fi

if echo "$ask_one_body" | grep -q -F "printf 'answer:"; then
    check_pass "ask_one uses printf for load-bearing answer: prefix"
else
    check_fail "ask_one does not use printf for answer: (constraint violation)"
fi

echo ""
echo "SUMMARY: m033-p02-grilling-shell-shape.sh pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
