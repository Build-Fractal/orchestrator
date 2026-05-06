#!/usr/bin/env bash
# tools/verify/m029-p01-sc2-shape.sh
#
# M029/P01/T03 SC-2 wrapper verifier: asserts that the SC-2 fixture
# milestone tree + acceptance script exist with the required shape, and
# that the SC-2 acceptance script exits 0.
#
# Spec references: FR-2, SC-2.
# Contract source: references/status-headline-shape.md.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SC2="$PROJECT_ROOT/tests/m029-acceptance/p01-sc2-headline.sh"
FIXTURE="$PROJECT_ROOT/tests/m029-acceptance/fixtures/status-headline-executing.fixture"
M_DIR="$FIXTURE/milestones/M999"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# Gate: SC-2 script exists.
if [ ! -f "$SC2" ]; then
    bad "SC-2 acceptance script missing at $SC2"
    printf 'SUMMARY: m029-p01-sc2-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
ok "SC-2 acceptance script exists"

# Gate: fixture directory exists.
if [ ! -d "$FIXTURE" ]; then
    bad "fixture directory missing at $FIXTURE"
    printf 'SUMMARY: m029-p01-sc2-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
ok "fixture directory exists"

# Gate: SC-2 script executable.
if [ -x "$SC2" ]; then
    ok "SC-2 acceptance script is executable"
else
    bad "SC-2 acceptance script is NOT executable"
fi

# Header references SC-2 + FR-2.
HEADER=$(head -40 "$SC2")
if printf '%s' "$HEADER" | grep -q 'SC-2'; then
    ok "SC-2 script header references SC-2"
else
    bad "SC-2 script header missing 'SC-2' reference"
fi
if printf '%s' "$HEADER" | grep -q 'FR-2'; then
    ok "SC-2 script header references FR-2"
else
    bad "SC-2 script header missing 'FR-2' reference"
fi

# Fixture milestone tree shape.
if [ -f "$M_DIR/M999-ROADMAP.md" ]; then
    ok "fixture roadmap M999-ROADMAP.md present"
else
    bad "fixture roadmap M999-ROADMAP.md missing"
fi
if [ -f "$M_DIR/phases/P01/P01-SUMMARY.md" ]; then
    ok "fixture P01-SUMMARY.md present"
else
    bad "fixture P01-SUMMARY.md missing"
fi
if [ -f "$M_DIR/execution-log.jsonl" ]; then
    ok "fixture execution-log.jsonl present"
else
    bad "fixture execution-log.jsonl missing"
fi

# Fixture execution-log carries at least one dispatch_usage record.
if [ -f "$M_DIR/execution-log.jsonl" ] \
        && grep -q '"dispatch_usage"' "$M_DIR/execution-log.jsonl"; then
    ok "fixture execution-log.jsonl carries >=1 dispatch_usage record"
else
    bad "fixture execution-log.jsonl has no dispatch_usage record"
fi

# Run the SC-2 acceptance script and assert exit 0.
SC2_OUT="$(mktemp)"
set +e
bash "$SC2" >"$SC2_OUT" 2>&1
sc2_rc=$?
set -e
if [ "$sc2_rc" -eq 0 ]; then
    ok "SC-2 acceptance script exits 0 (rc=$sc2_rc)"
else
    bad "SC-2 acceptance script exit non-zero (rc=$sc2_rc)"
    sed 's/^/   | /' "$SC2_OUT" >&2
fi
rm -f "$SC2_OUT"

printf 'SUMMARY: m029-p01-sc2-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
