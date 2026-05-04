#!/usr/bin/env bash
# m033-p03-rich-context-import-shape.sh
#
# Asserts the FR-8 / MIT-005 rich-context import path is filled in-place
# inside scripts/lifecycle/ingest-codebase.sh (T04 deliverable). Runs the
# functional smoke test against tests/fixtures/m033-stack-fixture-ts-saas/
# and the negative smoke test against tests/fixtures/m033-stack-fixture-py-cli/.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/scripts/lifecycle/ingest-codebase.sh"
TS_FIXTURE="$PROJECT_ROOT/tests/fixtures/m033-stack-fixture-ts-saas"
PY_FIXTURE="$PROJECT_ROOT/tests/fixtures/m033-stack-fixture-py-cli"

pass=0
fail=0

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

assert_negative_token() {
    local token="$1"
    if grep -qF "$token" "$TARGET"; then
        fail=$((fail + 1))
        echo "FAIL: forbidden token still present: $token" >&2
        grep -nF "$token" "$TARGET" >&2
    else
        pass=$((pass + 1))
        echo "PASS: forbidden token absent: $token"
    fi
}

# --- File presence ---
if [ ! -f "$TARGET" ]; then
    echo "FAIL: scripts/lifecycle/ingest-codebase.sh missing" >&2
    echo "SUMMARY: m033-p03-rich-context-import-shape pass=0 fail=1"
    exit 1
fi
pass=$((pass + 1))
echo "PASS: scripts/lifecycle/ingest-codebase.sh exists"

# --- Load-bearing tokens (rich-context branch surface) ---
assert_token 'context_source: imported-from-existing'
assert_token '_imported-context'
assert_token 'MEM-DR-'
assert_token 'imported_context_loaded'
assert_token 'current_milestone'
assert_token 'BEGIN CUSTOM'
assert_token 'MILESTONE-AUDIT.md'

# --- Block markers preserved + stub removed ---
assert_token '# >>> rich-context-branch >>>'
assert_token '# <<< rich-context-branch <<<'
assert_negative_token 'true # T04 fills this block'

# --- Functional smoke test against TS-SaaS fixture ---
STAGING_TS="$(mktemp -d)"
trap 'rm -rf "$STAGING_TS" "$STAGING_PY" 2>/dev/null || true' EXIT

if [ ! -d "$TS_FIXTURE" ]; then
    fail=$((fail + 1))
    echo "FAIL: TS-SaaS fixture missing: $TS_FIXTURE" >&2
else
    cp -R "$TS_FIXTURE"/. "$STAGING_TS"/
    rm -rf "$STAGING_TS/.orchestrator/knowledge" 2>/dev/null || true
    rm -rf "$STAGING_TS/.orchestrator/milestones" 2>/dev/null || true
    rm -f "$STAGING_TS/.orchestrator/execution-log.jsonl" 2>/dev/null || true

    bash "$TARGET" --project-dir "$STAGING_TS" --yes >/tmp/m033-p03-rci-stdout.log 2>/tmp/m033-p03-rci-stderr.log
    rc=$?
    if [ "$rc" -eq 0 ]; then
        pass=$((pass + 1))
        echo "PASS: TS-SaaS smoke ingest exit 0"
    else
        fail=$((fail + 1))
        echo "FAIL: TS-SaaS smoke ingest exit $rc" >&2
        cat /tmp/m033-p03-rci-stderr.log >&2 || true
    fi

    SENTINEL_FILE="$STAGING_TS/.orchestrator/milestones/_imported-context/_imported-context.md"
    if [ -f "$SENTINEL_FILE" ]; then
        pass=$((pass + 1))
        echo "PASS: sentinel file emitted at _imported-context/_imported-context.md"
    else
        fail=$((fail + 1))
        echo "FAIL: sentinel file missing: $SENTINEL_FILE" >&2
    fi

    if [ -f "$SENTINEL_FILE" ] && grep -qF 'context_source: imported-from-existing' "$SENTINEL_FILE"; then
        pass=$((pass + 1))
        echo "PASS: sentinel carries context_source: imported-from-existing"
    else
        fail=$((fail + 1))
        echo "FAIL: sentinel missing context_source: imported-from-existing" >&2
    fi

    MEM_DR_001="$STAGING_TS/.orchestrator/knowledge/decisions/MEM-DR-DEMO-001.md"
    MEM_DR_002="$STAGING_TS/.orchestrator/knowledge/decisions/MEM-DR-DEMO-002.md"
    if [ -f "$MEM_DR_001" ]; then
        pass=$((pass + 1))
        echo "PASS: MEM-DR-DEMO-001.md emitted"
    else
        fail=$((fail + 1))
        echo "FAIL: MEM-DR-DEMO-001.md missing" >&2
    fi
    if [ -f "$MEM_DR_002" ]; then
        pass=$((pass + 1))
        echo "PASS: MEM-DR-DEMO-002.md emitted"
    else
        fail=$((fail + 1))
        echo "FAIL: MEM-DR-DEMO-002.md missing" >&2
    fi

    # JSONL imported_context_loaded event recorded.
    JSONL_LOG="$STAGING_TS/.orchestrator/execution-log.jsonl"
    if [ -f "$JSONL_LOG" ]; then
        ic_count=$(grep -cF '"event_type":"imported_context_loaded"' "$JSONL_LOG" || true)
        if [ "$ic_count" -ge 1 ]; then
            pass=$((pass + 1))
            echo "PASS: JSONL log carries imported_context_loaded event (count=$ic_count)"
        else
            fail=$((fail + 1))
            echo "FAIL: JSONL log missing imported_context_loaded event" >&2
            cat "$JSONL_LOG" >&2 || true
        fi
    else
        fail=$((fail + 1))
        echo "FAIL: JSONL log missing: $JSONL_LOG" >&2
    fi

    # README-oracle expected MEM count = 8.
    arch_count=$(ls "$STAGING_TS/.orchestrator/knowledge/architecture"/MEM-*.md 2>/dev/null | wc -l | tr -d ' ')
    conv_count=$(ls "$STAGING_TS/.orchestrator/knowledge/conventions"/MEM-*.md 2>/dev/null | wc -l | tr -d ' ')
    dec_count=$(ls "$STAGING_TS/.orchestrator/knowledge/decisions"/MEM-*.md 2>/dev/null | wc -l | tr -d ' ')
    total_count=$((arch_count + conv_count + dec_count))
    if [ "$total_count" -eq 8 ]; then
        pass=$((pass + 1))
        echo "PASS: TS-SaaS oracle count met total=$total_count (arch=$arch_count conv=$conv_count dec=$dec_count)"
    else
        fail=$((fail + 1))
        echo "FAIL: TS-SaaS oracle count mismatch total=$total_count (expected 8) arch=$arch_count conv=$conv_count dec=$dec_count" >&2
    fi
fi

# --- Negative smoke test against py-cli fixture (no .orchestrator/) ---
STAGING_PY="$(mktemp -d)"
if [ ! -d "$PY_FIXTURE" ]; then
    fail=$((fail + 1))
    echo "FAIL: py-cli fixture missing: $PY_FIXTURE" >&2
else
    cp -R "$PY_FIXTURE"/. "$STAGING_PY"/
    rm -rf "$STAGING_PY/.orchestrator" 2>/dev/null || true

    bash "$TARGET" --project-dir "$STAGING_PY" --yes >/tmp/m033-p03-rci-py-stdout.log 2>/tmp/m033-p03-rci-py-stderr.log
    rc_py=$?
    if [ "$rc_py" -eq 0 ]; then
        pass=$((pass + 1))
        echo "PASS: py-cli smoke ingest exit 0"
    else
        fail=$((fail + 1))
        echo "FAIL: py-cli smoke ingest exit $rc_py" >&2
        cat /tmp/m033-p03-rci-py-stderr.log >&2 || true
    fi

    PY_SENTINEL_DIR="$STAGING_PY/.orchestrator/milestones/_imported-context"
    if [ ! -d "$PY_SENTINEL_DIR" ]; then
        pass=$((pass + 1))
        echo "PASS: py-cli rich-context branch did not fire (no sentinel directory)"
    else
        fail=$((fail + 1))
        echo "FAIL: py-cli sentinel directory unexpectedly present: $PY_SENTINEL_DIR" >&2
    fi
fi

# --- Final summary ---
echo "SUMMARY: m033-p03-rich-context-import-shape pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
