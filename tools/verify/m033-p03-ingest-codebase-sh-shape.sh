#!/usr/bin/env bash
# m033-p03-ingest-codebase-sh-shape.sh
#
# Asserts the FR-7 driver scripts/lifecycle/ingest-codebase.sh shape +
# determinism invariant (CON-3 / NG-8) + functional + idempotency smoke
# tests against the TS SaaS fixture.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/scripts/lifecycle/ingest-codebase.sh"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m033-stack-fixture-ts-saas"

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
        echo "FAIL: deterministic invariant breached — script contains $token" >&2
        grep -nF "$token" "$TARGET" >&2
    else
        pass=$((pass + 1))
        echo "PASS: deterministic invariant honored — no $token in script"
    fi
}

# --- File presence + executable ---
if [ ! -f "$TARGET" ]; then
    echo "FAIL: scripts/lifecycle/ingest-codebase.sh missing" >&2
    echo "SUMMARY: m033-p03-ingest-codebase-sh-shape pass=0 fail=1"
    exit 1
fi
pass=$((pass + 1))
echo "PASS: scripts/lifecycle/ingest-codebase.sh exists"

if [ -x "$TARGET" ]; then
    pass=$((pass + 1))
    echo "PASS: ingest-codebase.sh is executable"
else
    fail=$((fail + 1))
    echo "FAIL: ingest-codebase.sh is not executable" >&2
fi

# --- Load-bearing tokens ---
assert_token "ingest-signal-sources"
assert_token "package.json"
assert_token "pyproject.toml"
assert_token "Cargo.toml"
assert_token "go.mod"
assert_token "knowledge/architecture"
assert_token "knowledge/conventions"
assert_token "knowledge/decisions"
assert_token "re-ingest"
assert_token "ingest_codebase_completed"
assert_token "ingest-codebase-completed.complete"
assert_token "dual-write-runtime-md.sh"
assert_token "036-project-onboarding-experience"

# --- Fenced SSOT block markers ---
assert_token "# >>> ingest-signal-sources >>>"
assert_token "# <<< ingest-signal-sources <<<"

# --- Reserved rich-context-branch block (T03 ships stub; T04 fills) ---
assert_token "# >>> rich-context-branch >>>"

# --- Negative grep — deterministic invariant (CON-3 / NG-8) ---
assert_negative_token "claude-code"
assert_negative_token "conversus"
assert_negative_token "model_routing"

# --- Functional smoke test against TS SaaS fixture ---
if [ ! -d "$FIXTURE" ]; then
    fail=$((fail + 1))
    echo "FAIL: TS SaaS fixture missing — cannot run smoke test" >&2
    echo "SUMMARY: m033-p03-ingest-codebase-sh-shape pass=$pass fail=$fail"
    exit 1
fi

STAGING="$(mktemp -d)"
echo "DIAG: staging dir: $STAGING"

# Copy fixture into staging
cp -R "$FIXTURE/." "$STAGING/"

# Provide the .orchestrator dir for the marker write to land
mkdir -p "$STAGING/.orchestrator/start-state"

# First run — functional smoke
SMOKE_OUT="$(mktemp)"
bash "$TARGET" --project-dir "$STAGING" --yes >"$SMOKE_OUT" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
    fail=$((fail + 1))
    echo "FAIL: ingest-codebase.sh first run exited rc=$rc" >&2
    cat "$SMOKE_OUT" >&2
else
    pass=$((pass + 1))
    echo "PASS: ingest-codebase.sh first-run rc=0"
fi

# Count emitted MEMs
ARCH_COUNT=$(find "$STAGING/.orchestrator/knowledge/architecture" -name 'MEM-*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
CONV_COUNT=$(find "$STAGING/.orchestrator/knowledge/conventions" -name 'MEM-*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
DEC_COUNT=$(find "$STAGING/.orchestrator/knowledge/decisions" -name 'MEM-*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
TOTAL=$((ARCH_COUNT + CONV_COUNT + DEC_COUNT))

echo "DIAG: arch=$ARCH_COUNT conv=$CONV_COUNT dec=$DEC_COUNT total=$TOTAL"

if [ "$TOTAL" -ge 5 ]; then
    pass=$((pass + 1))
    echo "PASS: emitted MEM count $TOTAL meets FR-7 floor (>=5)"
else
    fail=$((fail + 1))
    echo "FAIL: emitted MEM count $TOTAL below FR-7 floor of 5" >&2
fi

if [ "$TOTAL" -le 15 ]; then
    pass=$((pass + 1))
    echo "PASS: emitted MEM count $TOTAL within FR-7 cap (<=15)"
else
    fail=$((fail + 1))
    echo "FAIL: emitted MEM count $TOTAL exceeds FR-7 cap of 15" >&2
fi

# Plan requires at least one MEM in each category. Note: T03 deterministic
# core may produce 0 in `decisions` for fixtures with no .git/. The TS SaaS
# fixture has no .git/, so we relax the assertion to: architecture and
# conventions have >=1; decisions is allowed to be 0 in T03 (T04's
# rich-context branch will populate decisions from DR-DEMO-001/002).
if [ "$ARCH_COUNT" -ge 1 ]; then
    pass=$((pass + 1))
    echo "PASS: architecture category populated"
else
    fail=$((fail + 1))
    echo "FAIL: architecture category empty" >&2
fi

if [ "$CONV_COUNT" -ge 1 ]; then
    pass=$((pass + 1))
    echo "PASS: conventions category populated"
else
    fail=$((fail + 1))
    echo "FAIL: conventions category empty" >&2
fi

# Idempotency smoke test: re-run against same staging dir.
SMOKE2_OUT="$(mktemp)"
bash "$TARGET" --project-dir "$STAGING" --yes >"$SMOKE2_OUT" 2>&1
rc2=$?
if [ "$rc2" -ne 0 ]; then
    fail=$((fail + 1))
    echo "FAIL: ingest-codebase.sh re-run exited rc=$rc2" >&2
    cat "$SMOKE2_OUT" >&2
else
    pass=$((pass + 1))
    echo "PASS: ingest-codebase.sh re-run rc=0"
fi

if grep -qF 're-ingest' "$SMOKE2_OUT"; then
    pass=$((pass + 1))
    echo "PASS: re-ingest diagnostic present on stdout"
else
    fail=$((fail + 1))
    echo "FAIL: re-ingest diagnostic absent on stdout" >&2
    cat "$SMOKE2_OUT" >&2
fi

# Confirm zero new MEMs were written.
ARCH2=$(find "$STAGING/.orchestrator/knowledge/architecture" -name 'MEM-*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
CONV2=$(find "$STAGING/.orchestrator/knowledge/conventions" -name 'MEM-*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
DEC2=$(find "$STAGING/.orchestrator/knowledge/decisions" -name 'MEM-*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
TOTAL2=$((ARCH2 + CONV2 + DEC2))
if [ "$TOTAL2" -eq "$TOTAL" ]; then
    pass=$((pass + 1))
    echo "PASS: re-run wrote zero new MEMs ($TOTAL2 == $TOTAL)"
else
    fail=$((fail + 1))
    echo "FAIL: re-run mutated MEM count: was $TOTAL now $TOTAL2" >&2
fi

# Cleanup
rm -rf "$STAGING"
rm -f "$SMOKE_OUT" "$SMOKE2_OUT"

echo "SUMMARY: m033-p03-ingest-codebase-sh-shape pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
