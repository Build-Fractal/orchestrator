---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P05"
milestone: "M035"
provides:
  - "tools/verify/m035-p05-phase-suite.sh phase-suite aggregator (~75 lines, executable, AD-19 single-script-file shape, bash 3.2 compatible) — chains all eight P05 per-truth verifiers in T01->T05 order, parses each verifier's BATTERY line and sums pass/fail/skip into a consolidated rollup, emits per-verifier PASS/FAIL decisions plus final BATTERY: pass=50 fail=0 skip=1 line, exit 0 iff total_fail=0; load-bearing for validate-milestone.sh M035 phase-grain oracle invocation and milestone acceptance-battery grep-aggregation"
requires:
  - "from:P05/T01 what:tools/verify/m035-p05-rollback-marker-shape.sh + tools/verify/m035-p05-rollback-snapshot-presence.sh; from:P05/T02 what:tools/verify/m035-p05-rollback-driver-shape.sh + tools/verify/m035-p05-update-skill-doc-shape.sh; from:P05/T03 what:tools/verify/m035-p05-release-workflow-signing-shape.sh; from:P05/T04 what:tools/verify/m035-p05-installation-doc-verifying-integrity.sh; from:P05/T05 what:tools/verify/m035-p05-signature-verification.sh + tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh; from:P02/T05 what:tools/verify/m035-p02-phase-suite.sh as aggregator-shape pattern reference"
affects:
  - "P05"
key_files:
  - "tools/verify/m035-p05-phase-suite.sh"
key_decisions:
  - "AD-19 single-script-file shape (every verifier invocation is bash $v inside a for loop, no compound chains, no process substitution); CON-3/AP-009 (output capture to mktemp tempfiles read with grep — not <(...) substitution); CON-5 (BATTERY-line shape consistent with m029/m030/m032/m037/m035-p015/m035-p02 phase-suite convention enabling consolidate-time grep aggregation across milestone batteries); Plan-Time-Discipline Rule 6 (milestone-prefixed slug per M001 P00 convention amendment, avoiding the missing-prefix collision that lost M030's aggregator); Plan-Time-Discipline Rule 2 (defensive missing-verifier branch is belt-and-suspenders, not a substitute for T01-T05 actually shipping their verifiers — and they all do)"
patterns_established:
  - "BATTERY-line-summing-aggregator-shape (T06 sums internal counters across child verifiers — pass=50 fail=0 skip=1 — vs P02's verifier-unit-counting form pass=8 fail=0; the summing form is the right shape when the milestone-grain rollup needs assertion-count granularity and skip-line propagation, e.g. T05 cosign-live SKIP); battery-line-skip-default-via-case-pattern (case pattern \"$battery_line\" in *skip=*) parse-with-sed ;; *) k=0 ;; esac is bash 3.2 compatible and avoids relying on sed default-when-no-match behavior); mktemp-tempfile-output-capture (>\"$out_log\" 2>\"$err_log\" plain-redirection-not-process-substitution survives both AP-009 shape-guard and AD-19 single-script-file constraint while permitting per-verifier failure forensics — cat $err_log >&2 only on FAIL); byte-equivalence-test-dominates-aggregator-wall-clock (~12min for tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh due to real install + re-install + rollback cycle against mktemp fixtures; verifiers T01-T07 complete combined in <2s; if validate-milestone.sh M035 runs all phase aggregators sequentially P05 will dominate milestone validation runtime — caveat for milestone-close planning)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P05/tasks/T06-phase-suite-aggregator-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-05-09T03:21:49Z"
---

T06 ships `tools/verify/m035-p05-phase-suite.sh` (~75 lines, executable, AD-19 single-script-file shape, bash 3.2 compatible) — the phase-suite aggregator that chains every P05 per-truth verifier in T01→T05 dependency order and emits a single consolidated `BATTERY: pass=N fail=N skip=K` rollup line.

Aggregator contract: iterates the eight verifiers (T01: rollback-marker-shape + rollback-snapshot-presence; T02: rollback-driver-shape + update-skill-doc-shape; T03: release-workflow-signing-shape; T04: installation-doc-verifying-integrity; T05: signature-verification + rollback-byte-equivalence), captures each verifier's stdout + stderr to mktemp tempfiles, parses the canonical `BATTERY:` line via `grep -E '^BATTERY:' | tail -1`, extracts `pass=`/`fail=`/`skip=` counters with `sed -E` regex (skip defaulted to 0 when absent via `case` pattern match), sums them across all verifiers, emits per-verifier `PASS:`/`FAIL:` decisions on stdout, and concludes with the rollup line. Exit 0 iff `total_fail=0`.

Differs intentionally from the P02 aggregator pattern (`tools/verify/m035-p02-phase-suite.sh`): P02 counts verifiers as units (8 verifiers run → `BATTERY: pass=8 fail=0`) and has no skip awareness. T06 sums the *internal* counts (50 individual assertions across the 8 verifiers → `BATTERY: pass=50 fail=0 skip=1`) so the milestone-grain consolidate-time grep aggregation reflects total assertion count, not just verifier count, and so T05's cosign-live SKIP propagates to the milestone battery — required because `validate-milestone.sh M035` will fold this aggregator's BATTERY line into the milestone-grain rollup. The task plan's "Expected Output" specified the summing form (50/0/1) — followed literally.

Verification end-to-end: `bash tools/verify/m035-p05-phase-suite.sh` → all 8 verifiers green, final line `BATTERY: pass=50 fail=0 skip=1`, exit 0, elapsed ~12 minutes (the byte-equivalence acceptance test does real install + re-install + rollback against mktemp fixtures and accounts for ~12min of that wall-clock — verifiers T01-T07 complete in <2s combined). Matches the planning agent's projected close exactly. The skip=1 originates from T05's signature-verification.sh cosign-live gate (COSIGN_AVAILABLE=1 + M035_P05_LIVE_RELEASE_DIR both unset locally).

Patterns established: `BATTERY-line-summing-aggregator-shape` (sums internal counters across child verifiers vs P02's verifier-unit-counting form — the right shape when the milestone-grain rollup needs assertion-count granularity and skip-line propagation). Caveat: byte-equivalence test is the wall-clock dominant factor (~12min) — if `validate-milestone.sh M035` runs all phase aggregators sequentially, P05's aggregator will dominate the milestone validation runtime.

P05 phase-suite is now complete and ready for phase close: 5 functional tasks (T01-T05) + 8 task-grain verifiers + 1 phase-suite aggregator (T06) + acceptance evidence. `BATTERY: pass=50 fail=0 skip=1`.
