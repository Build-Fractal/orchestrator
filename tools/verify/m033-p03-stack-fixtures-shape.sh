#!/usr/bin/env bash
# m033-p03-stack-fixtures-shape.sh
#
# Asserts the three FR-7 stack fixtures exist with the documented shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

assert_path() {
    local p="$1"
    local label="$2"
    if [ -e "$PROJECT_ROOT/$p" ]; then
        pass=$((pass + 1))
        echo "PASS: $label: $p"
    else
        fail=$((fail + 1))
        echo "FAIL: $label missing: $p" >&2
    fi
}

assert_grep_token() {
    local f="$1"
    local token="$2"
    local abs="$PROJECT_ROOT/$f"
    if [ ! -f "$abs" ]; then
        fail=$((fail + 1))
        echo "FAIL: cannot grep — file missing: $f" >&2
        return
    fi
    if grep -qF "$token" "$abs"; then
        pass=$((pass + 1))
        echo "PASS: $f contains $token"
    else
        fail=$((fail + 1))
        echo "FAIL: $f missing token: $token" >&2
    fi
}

# TS SaaS fixture
assert_path "tests/fixtures/m033-stack-fixture-ts-saas" "ts-saas dir"
assert_path "tests/fixtures/m033-stack-fixture-ts-saas/package.json" "ts-saas package.json"
assert_path "tests/fixtures/m033-stack-fixture-ts-saas/src" "ts-saas src/"
assert_path "tests/fixtures/m033-stack-fixture-ts-saas/README.md" "ts-saas README"
assert_path "tests/fixtures/m033-stack-fixture-ts-saas/ARCHITECTURE.md" "ts-saas ARCHITECTURE"
assert_path "tests/fixtures/m033-stack-fixture-ts-saas/tests" "ts-saas tests/"
assert_path "tests/fixtures/m033-stack-fixture-ts-saas/.orchestrator/DECISIONS.md" "ts-saas DECISIONS"
assert_path "tests/fixtures/m033-stack-fixture-ts-saas/README-oracle.md" "ts-saas oracle"
assert_grep_token "tests/fixtures/m033-stack-fixture-ts-saas/.orchestrator/DECISIONS.md" "DR-DEMO-001"
assert_grep_token "tests/fixtures/m033-stack-fixture-ts-saas/.orchestrator/DECISIONS.md" "DR-DEMO-002"
assert_grep_token "tests/fixtures/m033-stack-fixture-ts-saas/README-oracle.md" "expected MEM count"
assert_grep_token "tests/fixtures/m033-stack-fixture-ts-saas/README-oracle.md" "expected categories"

# Py CLI fixture
assert_path "tests/fixtures/m033-stack-fixture-py-cli" "py-cli dir"
assert_path "tests/fixtures/m033-stack-fixture-py-cli/pyproject.toml" "py-cli pyproject"
assert_path "tests/fixtures/m033-stack-fixture-py-cli/src" "py-cli src/"
assert_path "tests/fixtures/m033-stack-fixture-py-cli/README.md" "py-cli README"
assert_path "tests/fixtures/m033-stack-fixture-py-cli/tests" "py-cli tests/"
assert_path "tests/fixtures/m033-stack-fixture-py-cli/README-oracle.md" "py-cli oracle"
assert_grep_token "tests/fixtures/m033-stack-fixture-py-cli/README-oracle.md" "expected MEM count"
assert_grep_token "tests/fixtures/m033-stack-fixture-py-cli/README-oracle.md" "expected categories"

# Rust library fixture
assert_path "tests/fixtures/m033-stack-fixture-rust-library" "rust-library dir"
assert_path "tests/fixtures/m033-stack-fixture-rust-library/Cargo.toml" "rust-library Cargo.toml"
assert_path "tests/fixtures/m033-stack-fixture-rust-library/src" "rust-library src/"
assert_path "tests/fixtures/m033-stack-fixture-rust-library/README.md" "rust-library README"
assert_path "tests/fixtures/m033-stack-fixture-rust-library/tests" "rust-library tests/"
assert_path "tests/fixtures/m033-stack-fixture-rust-library/README-oracle.md" "rust-library oracle"
assert_grep_token "tests/fixtures/m033-stack-fixture-rust-library/README-oracle.md" "expected MEM count"
assert_grep_token "tests/fixtures/m033-stack-fixture-rust-library/README-oracle.md" "expected categories"

echo "SUMMARY: m033-p03-stack-fixtures-shape pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
