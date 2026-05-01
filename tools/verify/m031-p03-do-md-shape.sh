#!/usr/bin/env bash
# tools/verify/m031-p03-do-md-shape.sh
#
# M031/P03/T01 shape verifier (project-owned, slug-bearing under
# tools/verify/) for commands/do.md.
#
# Asserts:
#   1) commands/do.md exists and is >= 60 lines.
#   2) the file body contains required literal substrings:
#        - orchestrator:do
#        - tier_a_plus
#        - do-entry.sh
#        - Referenced Scripts
#   3) YAML frontmatter starts at line 1 (head -1 matches ^---$).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/commands/do.md"

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

# 1) Existence.
if [ -f "$target" ]; then
    ok "commands/do.md exists at $target"
else
    ng "commands/do.md missing at $target"
    printf 'SUMMARY: m031-p03-do-md-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) Line count >= 60.
target_lines=$(awk 'END {print NR}' "$target")
if [ "$target_lines" -ge 60 ]; then
    ok "commands/do.md has $target_lines lines (>= 60)"
else
    ng "commands/do.md has $target_lines lines (< 60)"
fi

# 3) Required literal substrings.
check_literal() {
    local label="$1"
    local needle="$2"
    if grep -qF "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_literal "orchestrator:do" "orchestrator:do"
check_literal "tier_a_plus" "tier_a_plus"
check_literal "do-entry.sh" "do-entry.sh"
check_literal "Referenced Scripts" "Referenced Scripts"

# 4) YAML frontmatter at line 1.
first_line=$(head -1 "$target")
if [ "$first_line" = "---" ]; then
    ok "YAML frontmatter starts at line 1"
else
    ng "YAML frontmatter does not start at line 1 (got: $first_line)"
fi

printf 'SUMMARY: m031-p03-do-md-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
