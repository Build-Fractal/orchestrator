#!/usr/bin/env bash
# tests/m029-acceptance/p01-sc3-format-json.sh -- M029 P01 SC-3 acceptance.
#
# Exercises FR-3 (`orchestrator:status --format=json`) plus AD-2 (the
# unconditional ANSI-strip rule) plus AD-7 (`schema_version: "1.0"` from
# day 1). Drives the JSON renderer
# (`scripts/diagnostics/render-status-json.sh`) against two fixture
# milestone trees:
#
#   1. Happy path -- tests/m029-acceptance/fixtures/status-json-executing.fixture/
#   2. Degraded   -- tests/m029-acceptance/fixtures/status-json-degraded.fixture/
#
# Asserts:
#   - stdout is parseable JSON.
#   - schema_version == "1.0".
#   - All required top-level keys are present (jq -e per key).
#   - All required section keys are present under .sections.
#   - The AD-2 unconditional-strip invariant holds: NO ANSI escape
#     sequences appear anywhere under .sections.
#   - The degraded-state path produces .state == "degraded" + a
#     non-empty .parse_errors array; .schema_version remains "1.0".
#
# Spec references: FR-3, SC-3, AD-2, AD-7.
# Contract reference: references/status-json-schema.md.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RENDER="$PROJECT_ROOT/scripts/diagnostics/render-status-json.sh"
FIXTURE_HAPPY_SRC="$PROJECT_ROOT/tests/m029-acceptance/fixtures/status-json-executing.fixture"
FIXTURE_DEGRADED_SRC="$PROJECT_ROOT/tests/m029-acceptance/fixtures/status-json-degraded.fixture"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

TMP="$(mktemp -d -t m029-sc3-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# Gate -- renderer + fixtures present.
if [ ! -x "$RENDER" ]; then
    bad "render-status-json.sh missing or not executable at $RENDER"
    printf 'SC-3: pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
if [ ! -d "$FIXTURE_HAPPY_SRC" ] || [ ! -d "$FIXTURE_DEGRADED_SRC" ]; then
    bad "fixture directories missing"
    printf 'SC-3: pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Copy fixtures to tmpdir so test runs do not pollute committed sources.
cp -R "$FIXTURE_HAPPY_SRC" "$TMP/happy"
cp -R "$FIXTURE_DEGRADED_SRC" "$TMP/degraded"

HAPPY_OUT="$TMP/sc3-json.out"
DEGRADED_OUT="$TMP/sc3-degraded.out"

# --- Happy path ------------------------------------------------------------
set +e
bash "$RENDER" --orchestrator-root "$TMP/happy" --milestone M999 >"$HAPPY_OUT" 2>"$TMP/happy.err"
happy_rc=$?
set -e
if [ "$happy_rc" -eq 0 ]; then
    ok "happy-path renderer exits 0"
else
    bad "happy-path renderer exit non-zero (rc=$happy_rc)"
    sed 's/^/   | /' "$TMP/happy.err" >&2
fi

# Parseable JSON.
if jq empty "$HAPPY_OUT" >/dev/null 2>&1; then
    ok "happy-path stdout is parseable JSON (jq empty exit 0)"
else
    bad "happy-path stdout is NOT parseable JSON"
fi

# schema_version == "1.0".
if jq -e '.schema_version == "1.0"' "$HAPPY_OUT" >/dev/null 2>&1; then
    ok "happy-path schema_version == \"1.0\" (AD-7)"
else
    bad "happy-path schema_version != \"1.0\""
fi

# Required top-level keys.
for key in schema_version milestone_id milestone_name phase_index phase_count \
           phase_percent_complete lock_state last_dispatch_recency \
           last_verify_result sections ; do
    if jq -e --arg k "$key" '. | has($k)' "$HAPPY_OUT" >/dev/null 2>&1; then
        ok "happy-path top-level key present: .$key"
    else
        bad "happy-path top-level key missing: .$key"
    fi
done

# Required section keys.
for sec in progress blockers execution_history telemetry_metrics \
           efficiency_footer next_action ; do
    if jq -e --arg k "$sec" '.sections | has($k)' "$HAPPY_OUT" >/dev/null 2>&1; then
        ok "happy-path section key present: .sections.$sec"
    else
        bad "happy-path section key missing: .sections.$sec"
    fi
done

# AD-2 unconditional-strip invariant: NO ANSI escapes anywhere under .sections.
ANSI_HITS=$(jq -r '.sections | values[]' "$HAPPY_OUT" 2>/dev/null \
            | grep -c $'\x1b\\[' || true)
if [ "$ANSI_HITS" -eq 0 ]; then
    ok "AD-2 invariant: NO ANSI escape sequences under .sections"
else
    bad "AD-2 invariant VIOLATED: $ANSI_HITS ANSI escape match(es) under .sections"
fi

# --- Degraded-state path ---------------------------------------------------
set +e
bash "$RENDER" --orchestrator-root "$TMP/degraded" --milestone M999 >"$DEGRADED_OUT" 2>"$TMP/degraded.err"
deg_rc=$?
set -e
if [ "$deg_rc" -eq 0 ]; then
    ok "degraded-path renderer exits 0 (corrupt JSONL is NOT fatal)"
else
    bad "degraded-path renderer exit non-zero (rc=$deg_rc)"
    sed 's/^/   | /' "$TMP/degraded.err" >&2
fi

if jq empty "$DEGRADED_OUT" >/dev/null 2>&1; then
    ok "degraded-path stdout is parseable JSON"
else
    bad "degraded-path stdout is NOT parseable JSON"
fi

if jq -e '.state == "degraded"' "$DEGRADED_OUT" >/dev/null 2>&1; then
    ok "degraded-path .state == \"degraded\""
else
    bad "degraded-path .state != \"degraded\""
fi

if jq -e '.parse_errors | length > 0' "$DEGRADED_OUT" >/dev/null 2>&1; then
    ok "degraded-path .parse_errors has length > 0"
else
    bad "degraded-path .parse_errors is empty or missing"
fi

# schema_version still "1.0" under degraded path.
if jq -e '.schema_version == "1.0"' "$DEGRADED_OUT" >/dev/null 2>&1; then
    ok "degraded-path schema_version == \"1.0\" (preserved across degraded state)"
else
    bad "degraded-path schema_version != \"1.0\""
fi

# AD-2 invariant under degraded path.
ANSI_HITS_D=$(jq -r '.sections | values[]' "$DEGRADED_OUT" 2>/dev/null \
            | grep -c $'\x1b\\[' || true)
if [ "$ANSI_HITS_D" -eq 0 ]; then
    ok "degraded-path AD-2 invariant: NO ANSI escape sequences under .sections"
else
    bad "degraded-path AD-2 invariant VIOLATED: $ANSI_HITS_D match(es)"
fi

printf 'SC-3: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
