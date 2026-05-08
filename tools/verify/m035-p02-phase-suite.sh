#!/usr/bin/env bash
# tools/verify/m035-p02-phase-suite.sh
# M035 P02 phase-suite aggregator. Runs every per-task verifier in
# sequence and emits BATTERY: pass=N fail=N.
#
# Mirrors the M030/M032/M029/M037/M035-P01.5 phase-suite convention so
# consolidate-time grep aggregation is consistent across milestone
# batteries.
set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$REPO"

VERIFIERS=(
    "tools/verify/m035-p02-package-json-shape.sh"
    "tools/verify/m035-p02-bin-entry.sh"
    "tools/verify/m035-p02-postinstall-shape.sh"
    "tools/verify/m035-p02-installation-doc-exclusion-list.sh"
    "tools/verify/m035-p02-byte-equivalence-skeleton.sh"
    "tools/verify/m035-p02-release-workflow-shape.sh"
    "tools/verify/m035-p02-bundle-hygiene-filter.sh"
    "tools/verify/m035-p02-npm-pack-contents.sh"
)

pass=0
fail=0
ERR_LOG="$REPO/.m035-p02-phase-suite-$$.err"

for v in "${VERIFIERS[@]}"; do
    if [ ! -x "$v" ]; then
        echo "FAIL: $v missing or not executable"
        fail=$((fail + 1))
        continue
    fi
    if bash "$v" >/dev/null 2>"$ERR_LOG"; then
        echo "PASS: $v"
        pass=$((pass + 1))
    else
        echo "FAIL: $v (stderr below)"
        cat "$ERR_LOG" >&2 || true
        fail=$((fail + 1))
    fi
done
rm -f "$ERR_LOG" 2>/dev/null || true

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
