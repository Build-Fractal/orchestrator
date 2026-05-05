#!/usr/bin/env bash
# tools/verify/m033-p01-validate-report-fixtures-shape.sh
#
# M033 P01 T04 verifier (FR-19 / SC-15).
# Asserts the two report fixtures exist and exercise the validator's
# pass/fail branches end-to-end:
#   - fixtures/report-pass.md  -> validate-report.sh exits 0
#   - fixtures/report-fail.md  -> validate-report.sh exits non-zero
#                                 AND stderr contains "friction_blockers=1"
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
BASE="$PROJECT_ROOT/tests/m033-acceptance/friendly-tester-pass"
VALIDATOR="$BASE/validate-report.sh"
PASS_FIXTURE="$BASE/fixtures/report-pass.md"
FAIL_FIXTURE="$BASE/fixtures/report-fail.md"

pass=0
fail=0

check() {
    desc="$1"
    rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s\n' "$desc"
        fail=$((fail + 1))
    fi
}

# 1. Fixture files exist.
if [ -f "$PASS_FIXTURE" ]; then
    check "fixtures/report-pass.md exists" 0
else
    check "fixtures/report-pass.md exists" 1
fi

if [ -f "$FAIL_FIXTURE" ]; then
    check "fixtures/report-fail.md exists" 0
else
    check "fixtures/report-fail.md exists" 1
fi

# 2. Validator exists and is executable -- prerequisite for fixture runs.
if [ -x "$VALIDATOR" ]; then
    check "validate-report.sh executable (prerequisite)" 0
else
    check "validate-report.sh executable (prerequisite)" 1
    printf 'SUMMARY: m033-p01-validate-report-fixtures-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 3. Pass fixture has friction_blockers: 0 in frontmatter.
pass_blockers=$(awk '/^friction_blockers: /{print $2; exit}' "$PASS_FIXTURE" | tr -d ' "')
if [ "${pass_blockers:-X}" = "0" ]; then
    check "report-pass.md frontmatter friction_blockers=0" 0
else
    printf 'FAIL: report-pass.md friction_blockers expected 0, got "%s"\n' "$pass_blockers"
    fail=$((fail + 1))
fi

# 4. Fail fixture has friction_blockers: 1 in frontmatter.
fail_blockers=$(awk '/^friction_blockers: /{print $2; exit}' "$FAIL_FIXTURE" | tr -d ' "')
if [ "${fail_blockers:-X}" = "1" ]; then
    check "report-fail.md frontmatter friction_blockers=1" 0
else
    printf 'FAIL: report-fail.md friction_blockers expected 1, got "%s"\n' "$fail_blockers"
    fail=$((fail + 1))
fi

# 5. Run validator against pass fixture: must exit 0.
tmp_pass_stderr="$(mktemp -t m033-p01-pass-stderr.XXXXXX)"
tmp_pass_stdout="$(mktemp -t m033-p01-pass-stdout.XXXXXX)"
set +e
bash "$VALIDATOR" "$PASS_FIXTURE" >"$tmp_pass_stdout" 2>"$tmp_pass_stderr"
pass_rc=$?
set -e
if [ "$pass_rc" -eq 0 ]; then
    check "validator exit 0 against report-pass.md" 0
else
    printf 'FAIL: validator exit %d against report-pass.md\n' "$pass_rc"
    fail=$((fail + 1))
fi
# stdout should contain "PASS:" line.
if grep -q '^PASS: ' "$tmp_pass_stdout"; then
    check "validator stdout contains 'PASS:' line on pass fixture" 0
else
    check "validator stdout contains 'PASS:' line on pass fixture" 1
fi
rm -f "$tmp_pass_stderr" "$tmp_pass_stdout"

# 6. Run validator against fail fixture: must exit non-zero AND stderr
#    must contain "friction_blockers=1".
tmp_fail_stderr="$(mktemp -t m033-p01-fail-stderr.XXXXXX)"
tmp_fail_stdout="$(mktemp -t m033-p01-fail-stdout.XXXXXX)"
set +e
bash "$VALIDATOR" "$FAIL_FIXTURE" >"$tmp_fail_stdout" 2>"$tmp_fail_stderr"
fail_rc=$?
set -e
if [ "$fail_rc" -ne 0 ]; then
    check "validator exit non-zero against report-fail.md" 0
else
    check "validator exit non-zero against report-fail.md" 1
fi
if grep -qF 'friction_blockers=1' "$tmp_fail_stderr"; then
    check "validator stderr contains 'friction_blockers=1' on fail fixture" 0
else
    check "validator stderr contains 'friction_blockers=1' on fail fixture" 1
fi
rm -f "$tmp_fail_stderr" "$tmp_fail_stdout"

# 7. Length floors (>=15 lines per fixture).
pass_lines=$(wc -l < "$PASS_FIXTURE" | tr -d ' ')
fail_lines=$(wc -l < "$FAIL_FIXTURE" | tr -d ' ')
if [ "$pass_lines" -ge 15 ]; then
    check "report-pass.md length >=15 lines (got $pass_lines)" 0
else
    check "report-pass.md length >=15 lines (got $pass_lines)" 1
fi
if [ "$fail_lines" -ge 15 ]; then
    check "report-fail.md length >=15 lines (got $fail_lines)" 0
else
    check "report-fail.md length >=15 lines (got $fail_lines)" 1
fi

printf 'SUMMARY: m033-p01-validate-report-fixtures-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
