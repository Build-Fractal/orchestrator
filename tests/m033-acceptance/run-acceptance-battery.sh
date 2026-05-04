#!/usr/bin/env bash
# tests/m033-acceptance/run-acceptance-battery.sh
# M033/P05/T04 -- SC-14 acceptance battery runner.
# MIT-002: explicit enumeration of all 13 named scripts (NOT phase-prefix grouping).
# CON-1 / MIT-001: stub-mode tests produce pass not skip; SC-14 skip=0 invariant.
#
# Modeled byte-for-byte on tests/m030-acceptance/run-acceptance-battery.sh
# and tests/m031-acceptance/run-acceptance-battery.sh.
#
# Final stdout line: `BATTERY: pass=N fail=M`. Exits 0 iff fail=0.
#
# Env vars propagated to child invocations (when set in runner environment;
# bash automatically forwards exported vars to children, so the runner does
# NOT need to explicitly set them — only document the contract):
#   M033_FR15_STUB=1            -- triggers SC-9 stub-mode wiki-init invocation
#   M033_FR15_STUB_EXIT_CODE=N  -- synthetic wiki-init exit code (failure tests)
#   M033_GHINIT_STUB=1          -- triggers SC-10 stub-mode github-init invocation
#   M033_GHINIT_STUB_EXIT_CODE=N -- synthetic github-init exit code
#
# Discovery model (MIT-002): explicit enumeration. Multiple scripts share a
# phase prefix (`p04-materials-intake.sh` / `p04-ideation.sh`; `p07-*` x4;
# `p08-*` x2) -- each represents a distinct concern. The battery enumerates
# all 13 named scripts via literal `run_sc` calls. NO phase-prefix grouping.
#
# Closed enumeration roster (reverse-traceable from M033-SUMMARY.md SC-1..SC-13
# verdicts to script paths). Each row is the load-bearing identity used by
# the M033-VALIDATED gate's SC-by-SC pass roster lookup:
#   SC-1  -> p01-start-branch-routing.sh   (FR-1/FR-2 branch detection)
#   SC-2  -> p02-constitution-author.sh    (FR-3 constitution authoring)
#   SC-3  -> p03-ingest-codebase.sh        (FR-7 deterministic codebase scan)
#   SC-4  -> p04-materials-intake.sh       (FR-9 PBJ intake + reconciliation)
#   SC-5  -> p04-ideation.sh               (FR-10 ideation grilling-protocol)
#   SC-6  -> p05-migrate-routing.sh        (FR-11/FR-12 migrate-then-ingest)
#   SC-7  -> p06-customblock-draft.sh      (FR-13/FR-14 customblock-drafter)
#   SC-8  -> p07-friendly-tester-protocol.sh (CON-7 friendly-tester pass)
#   SC-9  -> p08-with-wiki-passthrough.sh  (FR-15 wiki paired-launch)
#   SC-10 -> p08-with-github-passthrough.sh (FR-16 github paired-launch)
#   SC-11 -> p07-grilling-shell.sh         (FR-17 grilling-shell core API)
#   SC-12 -> p07-resume-on-partial-state.sh (FR-20 resume-on-partial-state)
#   SC-13 -> p07-observability-records.sh  (FR-22 JSONL observability)
#
# SC-14 (this battery) and SC-15 (M033-VALIDATED) and SC-16 (unit_close) are
# milestone-grain criteria covered by T05's phase-suite + close gate, not by
# acceptance scripts under tests/m033-acceptance/.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

run_sc() {
    # $1 SC label  $2 verifier path
    local label="$1"
    local path="$2"
    bash "$path"
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        pass=$((pass + 1))
        printf 'BATTERY-PASS: %s (%s)\n' "$label" "$path"
    else
        fail=$((fail + 1))
        printf 'BATTERY-FAIL: %s (%s) exited %d\n' "$label" "$path" "$rc"
    fi
}

# ---------- 13 named scripts in explicit-enumeration order (MIT-002) ----------
run_sc "SC-1"  "$PROJECT_ROOT/tests/m033-acceptance/p01-start-branch-routing.sh"
run_sc "SC-2"  "$PROJECT_ROOT/tests/m033-acceptance/p02-constitution-author.sh"
run_sc "SC-3"  "$PROJECT_ROOT/tests/m033-acceptance/p03-ingest-codebase.sh"
run_sc "SC-4"  "$PROJECT_ROOT/tests/m033-acceptance/p04-materials-intake.sh"
run_sc "SC-5"  "$PROJECT_ROOT/tests/m033-acceptance/p04-ideation.sh"
run_sc "SC-6"  "$PROJECT_ROOT/tests/m033-acceptance/p05-migrate-routing.sh"
run_sc "SC-7"  "$PROJECT_ROOT/tests/m033-acceptance/p06-customblock-draft.sh"
run_sc "SC-8"  "$PROJECT_ROOT/tests/m033-acceptance/p07-friendly-tester-protocol.sh"
run_sc "SC-9"  "$PROJECT_ROOT/tests/m033-acceptance/p08-with-wiki-passthrough.sh"
run_sc "SC-10" "$PROJECT_ROOT/tests/m033-acceptance/p08-with-github-passthrough.sh"
run_sc "SC-11" "$PROJECT_ROOT/tests/m033-acceptance/p07-grilling-shell.sh"
run_sc "SC-12" "$PROJECT_ROOT/tests/m033-acceptance/p07-resume-on-partial-state.sh"
run_sc "SC-13" "$PROJECT_ROOT/tests/m033-acceptance/p07-observability-records.sh"

# ---------- Aggregate (no skip mechanism per SC-14 invariant) ----------
printf 'BATTERY: pass=%s fail=%s\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
