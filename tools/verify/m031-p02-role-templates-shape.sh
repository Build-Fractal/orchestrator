#!/usr/bin/env bash
# m031-p02-role-templates-shape.sh
#
# Verifier for M031/P02/T02: asserts that the three Tier A+ role templates
# (templates/dispatch-role-research.md, dispatch-role-plan.md,
# dispatch-role-build.md) exist, are >= 25 lines, declare the
# `type: dispatch-role` schema entry plus their per-role `role:` value,
# and contain the role-specific required literal substrings documented
# in the M031 P02 T02 task plan.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no process
# substitution. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m031-p02-role-templates-shape.sh
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

tpl_research="$PROJECT_ROOT/templates/dispatch-role-research.md"
tpl_plan="$PROJECT_ROOT/templates/dispatch-role-plan.md"
tpl_build="$PROJECT_ROOT/templates/dispatch-role-build.md"

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

# Helper: assert file exists, is non-empty, and has >= 25 lines.
check_file_present() {
    label="$1"
    path="$2"
    if [ ! -f "$path" ]; then
        check_fail "$label missing at $path"
        return 1
    fi
    if [ ! -s "$path" ]; then
        check_fail "$label is empty at $path"
        return 1
    fi
    line_count=$(wc -l < "$path" | tr -d ' ')
    if [ "$line_count" -lt 25 ]; then
        check_fail "$label has $line_count lines (<25 required) at $path"
        return 1
    fi
    check_pass "$label exists with $line_count lines (>= 25): $path"
    return 0
}

# Helper: assert file contains a literal substring.
check_literal() {
    label="$1"
    path="$2"
    needle="$3"
    if [ ! -f "$path" ]; then
        check_fail "$label cannot grep -- file missing: $path"
        return 1
    fi
    if grep -q -- "$needle" "$path"; then
        check_pass "$label contains literal: $needle"
        return 0
    fi
    check_fail "$label missing literal: $needle"
    return 1
}

# Check group 1: research template presence + line count.
check_file_present "dispatch-role-research.md" "$tpl_research"

# Check group 2: research template schema (frontmatter type + role).
check_literal "research:type" "$tpl_research" 'type: dispatch-role'
check_literal "research:role" "$tpl_research" 'role: research'

# Check group 3: research template required tokens (findings, research.md,
# Quick, --meta-out).
check_literal "research:findings" "$tpl_research" 'findings'
check_literal "research:research.md" "$tpl_research" 'research.md'
check_literal "research:Quick" "$tpl_research" 'Quick'
check_literal "research:--meta-out" "$tpl_research" '--meta-out'

# Check group 4: plan template presence + line count.
check_file_present "dispatch-role-plan.md" "$tpl_plan"

# Check group 5: plan template schema (frontmatter type + role).
check_literal "plan:type" "$tpl_plan" 'type: dispatch-role'
check_literal "plan:role" "$tpl_plan" 'role: plan'

# Check group 6: plan template required tokens (PLAN.md, Steps,
# Verification, single-script-file).
check_literal "plan:PLAN.md" "$tpl_plan" 'PLAN.md'
check_literal "plan:Steps" "$tpl_plan" 'Steps'
check_literal "plan:Verification" "$tpl_plan" 'Verification'
check_literal "plan:single-script-file" "$tpl_plan" 'single-script-file'

# Check group 7: build template presence + line count.
check_file_present "dispatch-role-build.md" "$tpl_build"

# Check group 8: build template schema (frontmatter type + role).
check_literal "build:type" "$tpl_build" 'type: dispatch-role'
check_literal "build:role" "$tpl_build" 'role: build'

# Check group 9: build template required tokens (plan.md, verifiers,
# inline, Quick).
check_literal "build:plan.md" "$tpl_build" 'plan.md'
check_literal "build:verifiers" "$tpl_build" 'verifiers'
check_literal "build:inline" "$tpl_build" 'inline'
check_literal "build:Quick" "$tpl_build" 'Quick'

echo "SUMMARY: m031-p02-role-templates-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
