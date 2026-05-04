#!/usr/bin/env bash
# m033-p03-ingest-codebase-md-shape.sh
#
# Asserts the FR-7 / FR-8 documentation surface at commands/ingest-codebase.md
# carries the load-bearing tokens and the MEM012 frontmatter shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/commands/ingest-codebase.md"

pass=0
fail=0

assert_file_exists() {
    if [ -f "$TARGET" ]; then
        pass=$((pass + 1))
        echo "PASS: commands/ingest-codebase.md exists"
    else
        fail=$((fail + 1))
        echo "FAIL: commands/ingest-codebase.md missing" >&2
    fi
}

assert_token() {
    local token="$1"
    if grep -qF "$token" "$TARGET"; then
        pass=$((pass + 1))
        echo "PASS: token present: $token"
    else
        fail=$((fail + 1))
        echo "FAIL: missing load-bearing token: $token" >&2
    fi
}

assert_frontmatter_description() {
    local first_line
    first_line=$(head -1 "$TARGET")
    if [ "$first_line" = "---" ]; then
        if grep -qE '^description:' "$TARGET"; then
            pass=$((pass + 1))
            echo "PASS: YAML frontmatter description: field present"
        else
            fail=$((fail + 1))
            echo "FAIL: missing description: in frontmatter" >&2
        fi
    else
        fail=$((fail + 1))
        echo "FAIL: file does not open with YAML frontmatter ---" >&2
    fi
}

assert_file_exists
if [ ! -f "$TARGET" ]; then
    echo "SUMMARY: m033-p03-ingest-codebase-md-shape pass=$pass fail=$fail"
    exit 1
fi

assert_frontmatter_description
assert_token "orchestrator:ingest-codebase"
assert_token "FR-7"
assert_token "FR-8"
assert_token "ingest-codebase.sh"
assert_token "deterministic"
assert_token "_imported-context"
assert_token "DR-"
assert_token "context_source"
assert_token "MEM-DR-"
assert_token "#Q-3"
assert_token "#Q-11"

echo "SUMMARY: m033-p03-ingest-codebase-md-shape pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
