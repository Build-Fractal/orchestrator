---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P06"
milestone: "M035"
provides:
  - "tools/verify/m035-p06-phase-suite.sh (summing-counters phase-suite aggregator chaining all six P06 per-truth verifiers — T01 config-schema-shape + T02 multi-source-dispatch-shape + T03 update-run-jsonl-emission-shape + T04 update-skill-doc-multi-source-shape + T05 acceptance-battery-shape + T06 milestone-close-shape; BATTERY: pass=69 fail=0 skip=0 post-close; SC-16 evidence) + tools/verify/m035-p06-milestone-close-shape.sh (9-assertion structural verifier wrapping the SC-16 oracle: M035-VALIDATED present + carries ISO 8601 UTC timestamp + M035-SUMMARY.md present + required H1/H2 headings + acceptance-battery reference + BATTERY rollup citation + validate-milestone.sh M035 PASS; BATTERY pass=9) + .orchestrator/milestones/M035/M035-VALIDATED (single-line marker, ISO 8601 UTC timestamp 2026-05-10T02:08:07Z) + .orchestrator/milestones/M035/M035-SUMMARY.md (145-line milestone-grain summary per the M032/M037 template shape — enumerates every phase + every #Q + every D + every MOS + every pattern + every caveat) + .orchestrator/observability/2026-05-10.jsonl (milestone-grain unit_close event for M035: result=success, verification_result=pass, completed_at=2026-05-10T02:08:07Z); inline pre-T06 reconciliation removing P05-SUMMARY.md key_files /tmp/m035-p05-t03-yaml-validate.sh staged-probe entry that broke the validate-milestone.sh key-file existence check (same shape as the T05.5 reconciliation pattern)"
requires:
  - "from:M035/P06-T01 what:m035-p06-config-schema-shape.sh (BATTERY pass=7) from:M035/P06-T02 what:m035-p06-multi-source-dispatch-shape.sh (BATTERY pass=13) from:M035/P06-T03 what:m035-p06-update-run-jsonl-emission-shape.sh (BATTERY pass=12) from:M035/P06-T04 what:m035-p06-update-skill-doc-multi-source-shape.sh (BATTERY pass=12) from:M035/P06-T05 what:m035-p06-acceptance-battery-shape.sh (BATTERY pass=16) + tests/m035-acceptance/run-acceptance-battery.sh (milestone-grain rollup gate) from:disk what:tools/verify/m035-p05-phase-suite.sh as pattern reference for the summing-counters aggregator form from:disk what:scripts/verify/validate-milestone.sh as framework-side milestone validator invoked BEFORE marker write from:disk what:.orchestrator/milestones/M032/M032-SUMMARY.md and .orchestrator/milestones/M037/M037-SUMMARY.md as the recent canonical milestone-summary shapes from:disk what:every P0N/P0N-SUMMARY.md (P00 → P05) to compile the M035-SUMMARY.md What was built section"
affects:
  - "M035 milestone closure (writes M035-VALIDATED + M035-SUMMARY.md + milestone-grain unit_close JSONL; satisfies SC-16 oracle); downstream state machine (validate-milestone.sh M035 reports 185/185 PASS so derive-phase.sh routes M035 to complete state); roadmap state (P06 checkbox flip from [ ] to [x] required to let read-roadmap.sh see P06 as complete; this task-grain bookkeeping was missed at the original close 2026-05-09 22:25 EDT and reconciled 2026-05-11 via the M035 T06 drift fix)"
key_files:
  - "tools/verify/m035-p06-phase-suite.sh,tools/verify/m035-p06-milestone-close-shape.sh,.orchestrator/milestones/M035/M035-VALIDATED,.orchestrator/milestones/M035/M035-SUMMARY.md,.orchestrator/milestones/M035/phases/P05/P05-SUMMARY.md,.orchestrator/milestones/M035/phases/P06/P06-SUMMARY.md,.orchestrator/observability/2026-05-10.jsonl"
key_decisions:
  - "SC-16 (milestone-close oracle — M035-VALIDATED + M035-SUMMARY.md + validate-milestone.sh M035 PASS); AD-19 single-script-file shape (both new verifiers); milestone-close ordering load-bearing (battery PASS → validate-milestone PASS → write SUMMARY → write VALIDATED → emit unit_close JSONL → re-run milestone-close-shape verifier — inverting this order falsely advertises milestone closure); summing-counters phase-suite form (mirrors P05 T06; right shape because P06 children have heterogeneous BATTERY counts: 7/13/12/12/16/9 → 69); pre-T06 reconciliation pattern (T06 surfaced P05-SUMMARY.md /tmp/ staged-probe key_file and removed inline rather than deferring — same shape as T05.5 reconciliation)"
patterns_established:
  - "summing-counters-phase-suite-form (mirrors P05 T06 — sums each child verifier's BATTERY pass/fail/skip counts rather than counting verifiers as units; right shape when child verifiers have heterogeneous BATTERY counts as P06 does — 7+13+12+12+16+9=69); milestone-close-shape-as-SC-16-oracle-wrapper (single shape verifier asserts marker + summary + validate-milestone.sh PASS in 9 assertions; gives the phase-suite a tractable BATTERY contribution rather than embedding the oracle invocation inline); milestone-close-ordering-strict (battery PASS → validate-milestone PASS → write SUMMARY → write VALIDATED → emit unit_close JSONL → re-run milestone-close-shape verifier; inverting falsely advertises closure); pre-T06-inline-reconciliation (P05-SUMMARY.md key_files /tmp/ staged-probe path removed inline at milestone close rather than as a follow-up paper-cut — mirrors T05.5 reconciliation pattern; defensible at close-time because validate-milestone.sh would otherwise FAIL the key-file existence check)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P06/tasks/T06-phase-suite-and-milestone-close-PLAN.md"
duration: "approx 100m"
verification_result: "pass"
completed_at: "2026-05-10T02:08:07Z"
---

T06 closes M035 by chaining all six P06 per-truth verifiers into a single summing-counters aggregator, wrapping the SC-16 oracle as a shape verifier, and writing the three milestone-close artifacts (M035-VALIDATED + M035-SUMMARY.md + milestone-grain unit_close JSONL).

Three deliverable surfaces:

1. **`tools/verify/m035-p06-phase-suite.sh`** — 79 lines, AD-19 single-script-file shape, Bash 3.2 compatible. Iterates `tools/verify/m035-p06-{config-schema,multi-source-dispatch,update-run-jsonl-emission,update-skill-doc-multi-source,acceptance-battery,milestone-close}-shape.sh`, parses each child's `BATTERY:` rollup line via `grep -E '^BATTERY:'` + `sed -E 's/.*pass=([0-9]+).*/\1/'`, defensively coerces non-numeric or empty parses to `0` via `case "$X" in ''|*[!0-9]*) X=0 ;;`, sums pass/fail/skip counters, emits a single canonical `BATTERY: pass=69 fail=0 skip=0` rollup, exits 0 iff `total_fail=0`. SKIP-when-not-found semantics on each child (the `[ ! -x "$v" ]` branch) tolerate the milestone-close-shape verifier's chicken-and-egg first run. Mirrors the P05 T06 summing-counters form verbatim — the right shape because P06's six children have heterogeneous BATTERY counts (7/13/12/12/16/9).

2. **`tools/verify/m035-p06-milestone-close-shape.sh`** — 99 lines, AD-19 single-script-file shape, Bash 3.2 compatible. Sources `scripts/lib/errors.sh` for `emit_result`. Asserts in order: `M035-VALIDATED` exists + non-empty + carries an ISO 8601 UTC timestamp matching `[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z`; `M035-SUMMARY.md` exists + carries H1 `# M035 — packaging & distribution` + H2 `## What was built` + H2 `## Verification` + references `tests/m035-acceptance/run-acceptance-battery.sh` + cites a `BATTERY:` rollup line; `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M035` exits 0. Nine assertions, `BATTERY: pass=9 fail=0`. The verifier is the SC-16 oracle wrapped as a tractable BATTERY contribution to the phase-suite chain rather than embedding `validate-milestone.sh` invocation inline.

3. **Milestone-close artifacts** — written in strict ordering:
   1. `bash tests/m035-acceptance/run-acceptance-battery.sh` → `BATTERY: pass=174 fail=0 skip=2`
   2. `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M035` → `VALIDATE: PASS — 185/185 checks passed`
   3. Author `M035-SUMMARY.md` (145 lines, per the M032/M037 template shape — H1 + ## What was built + ## Plan-phase Open Questions resolved + ## Manual Operator Steps deferred + ## Verification + ## Patterns established + ## Caveats and follow-ups + ## Next milestone)
   4. Write `M035-VALIDATED` marker (single line, timestamped 2026-05-10T02:08:07Z)
   5. Append milestone-grain `unit_close` event to `.orchestrator/observability/2026-05-10.jsonl` (result=success, verification_result=pass, completed_at=2026-05-10T02:08:07Z, summary_path pointer)
   6. Re-run `m035-p06-milestone-close-shape.sh` → `BATTERY: pass=9 fail=0`
   7. Re-run `m035-p06-phase-suite.sh` → `BATTERY: pass=69 fail=0 skip=0`

Inverting this ordering would falsely advertise milestone closure (write the marker before the gates pass).

## Pre-T06 inline reconciliation

`validate-milestone.sh` flagged a missing `key_files` path in `P05-SUMMARY.md`: `/tmp/m035-p05-t03-yaml-validate.sh` — a staged probe from P05/T03 that lives in `/tmp` and breaks the key-file existence check at milestone close. Removed inline rather than deferring to a follow-up paper-cut, mirroring the T05.5 reconciliation pattern. Defensible at close-time because `validate-milestone.sh M035 = PASS` is a load-bearing milestone-close gate.

## Patterns established

- **Summing-counters phase-suite form** — mirrors P05 T06; right shape when child verifiers have heterogeneous BATTERY counts (7+13+12+12+16+9=69) rather than counting verifiers as one-unit-each.
- **Milestone-close-shape as SC-16 oracle wrapper** — single shape verifier asserts marker + summary + `validate-milestone.sh` PASS in 9 assertions, giving the phase-suite chain a tractable BATTERY contribution rather than embedding the oracle invocation inline.
- **Milestone-close ordering strict** — battery PASS → validate-milestone PASS → write SUMMARY → write VALIDATED → emit unit_close JSONL → re-run milestone-close-shape verifier. Inverting falsely advertises closure.
- **Pre-T06 inline reconciliation** — close-time fix for a staged `/tmp/` path in upstream phase summary, mirroring the T05.5 reconciliation pattern. Defensible because the validate-milestone gate would otherwise FAIL.

## Verification

- `bash tools/verify/m035-p06-phase-suite.sh` → `BATTERY: pass=69 fail=0 skip=0` (post-close — all six children PASS: T01 7/7 + T02 13/13 + T03 12/12 + T04 12/12 + T05 16/16 + T06 milestone-close-shape 9/9)
- `bash tools/verify/m035-p06-milestone-close-shape.sh` → `BATTERY: pass=9 fail=0`
- `bash tests/m035-acceptance/run-acceptance-battery.sh` → `BATTERY: pass=174 fail=0 skip=2`
- `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M035` → `VALIDATE: PASS — 185/185 checks passed`
- `.orchestrator/milestones/M035/M035-VALIDATED` on disk, timestamped 2026-05-10T02:08:07Z
- `.orchestrator/observability/2026-05-10.jsonl` carries the milestone-grain unit_close event

## Caveats and follow-ups

- **Task-grain bookkeeping was skipped at the original close** (commit `2477faef`, 2026-05-09 22:25 EDT). This SUMMARY and the matching `M035/P06/T06` `unit_close` JSONL entry in `.orchestrator/milestones/M035/execution-log.jsonl` were reconciled 2026-05-11 via the M035 T06 roadmap-vs-disk drift fix. The roadmap checkbox `- [ ] **P06**` was also flipped to `- [x]` as part of the same reconciliation; without it `read-roadmap.sh` reported P06 as `incomplete` and `find-active-milestone.sh` reported `M035 executing C` despite M035-VALIDATED being on disk.
- **MOS-3 / MOS-4 / MOS-5 deferred to first `v*` tag publication** per the milestone-grain summary's Manual Operator Steps section — homebrew first-release smoke, curl-pipe-bash first-release smoke, synthetic `v0.0.0-test` tag push against a fork.
- **Anchor-shape vs heading-shape divergence** for DECISIONS rows (`{ #dr-code-NNN }` anchor-shape vs `### D### — title` heading-shape) — known paper-cut deferred post-launch.

## Out-of-scope-found

- None within T06's strict close-time scope. The pre-T06 P05-SUMMARY.md `/tmp/` key_file reconciliation was inline-scoped as a milestone-close-gate dependency, not as a new task.
