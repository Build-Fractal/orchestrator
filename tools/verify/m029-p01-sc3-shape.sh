#!/usr/bin/env bash
# tools/verify/m029-p01-sc3-shape.sh
#
# M029/P01/T04 SC-3 wrapper verifier: asserts the SC-3 fixtures + acceptance
# script exist with the required shape, the degraded fixture's
# execution-log.jsonl carries intentionally-malformed content, and the SC-3
# acceptance script exits 0.
#
# Spec references: FR-3, SC-3, AD-2, AD-7.
# Contract source: references/status-json-schema.md.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SC3="$PROJECT_ROOT/tests/m029-acceptance/p01-sc3-format-json.sh"
FIXTURE_HAPPY="$PROJECT_ROOT/tests/m029-acceptance/fixtures/status-json-executing.fixture"
FIXTURE_DEGRADED="$PROJECT_ROOT/tests/m029-acceptance/fixtures/status-json-degraded.fixture"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# Gate -- SC-3 script + both fixture dirs.
if [ ! -f "$SC3" ]; then
    bad "SC-3 acceptance script missing at $SC3"
    printf 'SUMMARY: m029-p01-sc3-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
ok "SC-3 acceptance script exists"

if [ ! -d "$FIXTURE_HAPPY" ]; then
    bad "happy-path fixture directory missing at $FIXTURE_HAPPY"
    printf 'SUMMARY: m029-p01-sc3-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
ok "happy-path fixture directory exists"

if [ ! -d "$FIXTURE_DEGRADED" ]; then
    bad "degraded fixture directory missing at $FIXTURE_DEGRADED"
    printf 'SUMMARY: m029-p01-sc3-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
ok "degraded fixture directory exists"

# SC-3 script executable.
if [ -x "$SC3" ]; then
    ok "SC-3 script is executable"
else
    bad "SC-3 script is NOT executable"
fi

# Header references SC-3 + FR-3.
HEADER=$(head -40 "$SC3")
if printf '%s' "$HEADER" | grep -q 'SC-3'; then
    ok "SC-3 script header references SC-3"
else
    bad "SC-3 script header missing 'SC-3' reference"
fi
if printf '%s' "$HEADER" | grep -q 'FR-3'; then
    ok "SC-3 script header references FR-3"
else
    bad "SC-3 script header missing 'FR-3' reference"
fi

# SC-3 script greps for schema_version, 1.0, jq -e, ANSI.
if grep -q 'schema_version' "$SC3"; then
    ok "SC-3 script asserts schema_version"
else
    bad "SC-3 script does not mention schema_version"
fi
if grep -q '"1\.0"' "$SC3"; then
    ok "SC-3 script asserts \"1.0\" literal"
else
    bad "SC-3 script does not assert \"1.0\" literal"
fi
if grep -q 'jq -e' "$SC3"; then
    ok "SC-3 script uses jq -e (per-key presence assertions)"
else
    bad "SC-3 script does not use jq -e"
fi
if grep -qE 'AD-2|ANSI' "$SC3"; then
    ok "SC-3 script references AD-2/ANSI invariant"
else
    bad "SC-3 script missing AD-2/ANSI invariant reference"
fi

# Fixture milestone tree shape -- happy.
HAPPY_M="$FIXTURE_HAPPY/milestones/M999"
if [ -f "$HAPPY_M/M999-ROADMAP.md" ]; then
    ok "happy fixture: M999-ROADMAP.md present"
else
    bad "happy fixture: M999-ROADMAP.md missing"
fi
if [ -f "$HAPPY_M/phases/P01/P01-SUMMARY.md" ]; then
    ok "happy fixture: phases/P01/P01-SUMMARY.md present"
else
    bad "happy fixture: phases/P01/P01-SUMMARY.md missing"
fi
if [ -f "$HAPPY_M/execution-log.jsonl" ]; then
    ok "happy fixture: execution-log.jsonl present"
else
    bad "happy fixture: execution-log.jsonl missing"
fi

# Fixture milestone tree shape -- degraded.
DEG_M="$FIXTURE_DEGRADED/milestones/M999"
if [ -f "$DEG_M/M999-ROADMAP.md" ]; then
    ok "degraded fixture: M999-ROADMAP.md present"
else
    bad "degraded fixture: M999-ROADMAP.md missing"
fi
if [ -f "$DEG_M/execution-log.jsonl" ]; then
    ok "degraded fixture: execution-log.jsonl present"
else
    bad "degraded fixture: execution-log.jsonl missing"
fi

# Degraded fixture's execution-log carries at least one line that is NOT
# a complete JSON object on its own. Heuristic: a line that does not match
# the canonical "starts with `{` and ends with `}`" pattern after trim.
if [ -f "$DEG_M/execution-log.jsonl" ]; then
    bad_lines=0
    while IFS= read -r line || [ -n "$line" ]; do
        trimmed=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
        if [ -z "$trimmed" ]; then
            continue
        fi
        case "$trimmed" in
            \{*\}) ;;  # plausible JSON object; skip
            *) bad_lines=$((bad_lines + 1)) ;;
        esac
    done <"$DEG_M/execution-log.jsonl"
    if [ "$bad_lines" -gt 0 ]; then
        ok "degraded fixture execution-log.jsonl carries intentionally-malformed line(s) (count=$bad_lines)"
    else
        bad "degraded fixture execution-log.jsonl has no malformed lines (degraded path won't trigger)"
    fi
fi

# Run the SC-3 acceptance script and assert exit 0.
SC3_OUT="$(mktemp)"
set +e
bash "$SC3" >"$SC3_OUT" 2>&1
sc3_rc=$?
set -e
if [ "$sc3_rc" -eq 0 ]; then
    ok "SC-3 acceptance script exits 0 (rc=$sc3_rc)"
else
    bad "SC-3 acceptance script exit non-zero (rc=$sc3_rc)"
    sed 's/^/   | /' "$SC3_OUT" >&2
fi
rm -f "$SC3_OUT"

printf 'SUMMARY: m029-p01-sc3-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
