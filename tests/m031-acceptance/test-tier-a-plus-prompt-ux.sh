#!/usr/bin/env bash
# tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh
#
# M031/P02/T03 -- SC-16 / AD-20 acceptance test for the Tier A+
# approval prompt helper at scripts/intake/lib/tier-a-plus-prompt.sh.
#
# Asserts the seven AD-20 UX-protocol clauses:
#
#   1. Plain-language framing -- captured prompt body contains ZERO
#      occurrences of the literal token `null`, the open-brace and
#      close-brace characters, and the CON-7 scaffold-placeholder
#      bracket-TODO byte pattern. The byte pattern is constructed at
#      runtime via printf so the test source itself does not embed
#      the prohibited literal (mirrors the source-side discipline
#      the helper applies to its own prompt body).
#   2. Inline research summary -- the first 8 lines of the fixture
#      research.md appear verbatim in the captured body (P00 default
#      tier_a_plus_prompt_summary_lines = 8).
#   3. Three named single-keystroke options labels appear in the body
#      (`(y) plan against this research`, `(n) re-run research with
#      different framing`, `(c) abort this Tier A+ flow`).
#   4. Ellipsis line of the form `(N more lines at <path>)` appears
#      exactly once. With this 20-line fixture and the P00 default
#      tier_a_plus_prompt_summary_lines = 8 the literal substring
#      checked is `(12 more lines at <fixture-path>)`.
#   5. Resume-vs-rerun marker -- the body contains either
#      `[resume from prior research]` or
#      `[fresh research from this session]`.
#   6. --yes skip -- a single `research: <path>` audit line emits to
#      stderr and the helper exits 0.
#   7. Path emission discipline -- the audit line emits in --yes mode
#      AND in interactive mode (helper writes the audit to stderr in
#      both paths so a single grep against stderr is sufficient
#      regardless of mode).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Output envelope:
#   RESULT: SC-16 pass   on success
#   RESULT: SC-16 fail   plus diagnostic lines on failure
#
# Exit 0 iff every clause holds.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

helper="$PROJECT_ROOT/scripts/intake/lib/tier-a-plus-prompt.sh"

fail_count=0
fail_messages=""

record_fail() {
    fail_count=$((fail_count + 1))
    fail_messages="$fail_messages
  - $1"
}

# Stage a deterministic fixture under a sandboxed working directory.
# The fixture has exactly 20 lines so the ellipsis count is the
# unambiguous 12 (= 20 - 8 inline at the P00 default).
work_dir="${TMPDIR:-/tmp}/m031-p02-t03-sc16-$$"
rm -rf "$work_dir"
mkdir -p "$work_dir"
fixture_dir="$work_dir/.orchestrator/tier-a-plus/sc16-test"
mkdir -p "$fixture_dir"
fixture_path="$fixture_dir/research.md"

i=1
while [ "$i" -le 20 ]; do
    printf 'Fixture line %02d body content for SC-16\n' "$i" >> "$fixture_path"
    i=$((i + 1))
done

stdout_file="$work_dir/yes-stdout.txt"
stderr_file="$work_dir/yes-stderr.txt"

# Clause 6: --yes mode emits exactly one `research: <path>` line to
# stderr and exits 0.
bash "$helper" \
    --research-path "$fixture_path" \
    --task-slug sc16-test \
    --yes \
    >"$stdout_file" 2>"$stderr_file"
yes_rc=$?

if [ "$yes_rc" -ne 0 ]; then
    record_fail "--yes mode exited $yes_rc (expected 0)"
fi

audit_line_count=$(grep -c "^research: $fixture_path$" "$stderr_file" || true)
if [ "$audit_line_count" -ne 1 ]; then
    record_fail "--yes mode stderr does not contain exactly one 'research: $fixture_path' line (saw $audit_line_count)"
fi

# Clauses 1..5 + 7: drive the interactive prompt via the
# --no-prompt-mode bypass to exercise the printable body without
# blocking on `read`. Map operator-pressed `y` -> exit 0.
int_stdout="$work_dir/int-stdout.txt"
int_stderr="$work_dir/int-stderr.txt"

bash "$helper" \
    --research-path "$fixture_path" \
    --task-slug sc16-test \
    --no-prompt-mode y \
    >"$int_stdout" 2>"$int_stderr"
int_rc=$?

if [ "$int_rc" -ne 0 ]; then
    record_fail "interactive (--no-prompt-mode y) exited $int_rc (expected 0)"
fi

# Clause 7 (interactive): audit line still present on stderr.
int_audit_count=$(grep -c "^research: $fixture_path$" "$int_stderr" || true)
if [ "$int_audit_count" -ne 1 ]; then
    record_fail "interactive mode stderr missing 'research: $fixture_path' audit line (saw $int_audit_count)"
fi

# Clause 2: first 8 fixture lines appear verbatim in the body.
inline_missing=0
i=1
while [ "$i" -le 8 ]; do
    expected=$(printf 'Fixture line %02d body content for SC-16' "$i")
    if ! grep -F -q "$expected" "$int_stdout"; then
        inline_missing=1
        record_fail "inline summary missing fixture line $i ('$expected')"
    fi
    i=$((i + 1))
done

if [ "$inline_missing" -eq 0 ]; then
    : # all 8 lines present
fi

# Clause 4: ellipsis count + path. The fixture has 20 lines and the
# inline budget is 8, so exactly 12 lines should be reported. We
# assert the literal substring `(12 more lines at <path>)`.
ellipsis_expected=$(printf '(12 more lines at %s)' "$fixture_path")
if ! grep -F -q "$ellipsis_expected" "$int_stdout"; then
    record_fail "ellipsis line missing or wrong count -- expected literal '$ellipsis_expected'"
fi

# Clause 3: all three named option labels appear.
if ! grep -F -q '(y) plan against this research' "$int_stdout"; then
    record_fail "option label '(y) plan against this research' missing"
fi
if ! grep -F -q '(n) re-run research with different framing' "$int_stdout"; then
    record_fail "option label '(n) re-run research with different framing' missing"
fi
if ! grep -F -q '(c) abort this Tier A+ flow' "$int_stdout"; then
    record_fail "option label '(c) abort this Tier A+ flow' missing"
fi

# Clause 5: resume-or-fresh marker present.
marker_present=0
if grep -F -q '[resume from prior research]' "$int_stdout"; then
    marker_present=1
fi
if grep -F -q '[fresh research from this session]' "$int_stdout"; then
    marker_present=1
fi
if [ "$marker_present" -ne 1 ]; then
    record_fail "neither resume-from-prior nor fresh-from-session marker present in body"
fi

# Clause 1a: zero occurrences of `null` in the captured body.
if grep -F -q 'null' "$int_stdout"; then
    record_fail "captured body contains forbidden literal 'null'"
fi

# Clause 1b: zero occurrences of the JSON-object brace characters in
# the captured body. Open brace + close brace each checked separately
# to keep the assertion explicit.
open_brace=$(printf '\173')
close_brace=$(printf '\175')
if grep -F -q "$open_brace" "$int_stdout"; then
    record_fail "captured body contains forbidden open-brace character"
fi
if grep -F -q "$close_brace" "$int_stdout"; then
    record_fail "captured body contains forbidden close-brace character"
fi

# Clause 1c: zero occurrences of the CON-7 scaffold-placeholder
# bracket-TODO byte pattern. Pattern constructed via printf so this
# test source itself does not embed the prohibited literal.
scaffold_pattern=$(printf '\133TODO: ')
if grep -F -q "$scaffold_pattern" "$int_stdout"; then
    record_fail "captured body contains forbidden CON-7 scaffold-placeholder byte pattern"
fi

# Cleanup the sandbox.
rm -rf "$work_dir"

if [ "$fail_count" -eq 0 ]; then
    echo "RESULT: SC-16 pass"
    exit 0
fi

echo "RESULT: SC-16 fail"
printf 'FAIL count: %d\n' "$fail_count"
printf 'Diagnostics:%s\n' "$fail_messages"
exit 1
