#!/usr/bin/env bash
# tools/verify/m031-p04-evidence-ledger-shape.sh
#
# M031/P04/T04 shape verifier (project-owned, slug-bearing under
# tools/verify/) for .orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md
# -- the milestone-close evidence ledger.
#
# Asserts:
#   1) .orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md exists.
#   2) the file body contains required literal substrings:
#        - BATTERY:        (one captured aggregator line)
#        - M031            (milestone identifier)
#        - SC-              (per-SC roll-up grain)
#
# NOTE: At T04 close this verifier is EXPECTED TO FAIL because T05 has
# not yet authored the evidence ledger. T04 ships the verifier as the
# surface contract; T05 ships the artifact it gates. Once T05 commits
# M031-ACCEPTANCE-EVIDENCE.md the verifier becomes load-bearing and is
# pulled into the M031 phase-suite + milestone close gate.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md"

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
    ok "M031-ACCEPTANCE-EVIDENCE.md exists at $target"
else
    ng "M031-ACCEPTANCE-EVIDENCE.md missing at $target (T05 ships this artifact)"
    printf 'SUMMARY: m031-p04-evidence-ledger-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) Required literal substrings.
check_literal() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_literal "BATTERY: aggregator line" "BATTERY:"
check_literal "M031 milestone tag"       "M031"
check_literal "SC- per-SC roll-up grain" "SC-"

printf 'SUMMARY: m031-p04-evidence-ledger-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
