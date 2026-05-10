---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P02"
milestone: "M031"
provides:
  - "tools/verify/m031-p02-phase-suite.sh,tools/verify/m031-p02-scope-guard.sh,11-gate phase-suite straight-line aggregator,SC-12 scope-guard with dual-prefix permissive carve-out (.orchestrator/observability + .orchestrator/tier-a-plus),MEM hit_count carve-out inherited verbatim from P01"
requires:
  - "T01,T02,T03,T04"
affects:
  - "P03,P04"
key_files:
  - "tools/verify/m031-p02-phase-suite.sh,tools/verify/m031-p02-scope-guard.sh"
key_decisions:
  - "phase-suite gate ordering follows T01->T05 dependency order with scope-guard last,added .orchestrator/tier-a-plus/ as second permissive prefix alongside .orchestrator/observability/,MEM hit_count-only carve-out function copied verbatim from P01 (project-wide convention now),no edits to T01-T04 deliverables per plan-time discipline (3 pre-existing key-link FAILs forwarded for P02 close-out remediation)"
patterns_established:
  - "phase-suite straight-line N-gate aggregation repeats across milestones (P01:9 / P02:11),SC-12 scope-guard with dual-prefix permissive carve-out (observability + per-flow scratch),MEM hit_count-only carve-out invariantly inherited verbatim across phases"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P02/tasks/T05-phase-suite-and-scope-guard-PLAN.md,tools/verify/m031-p02-phase-suite.sh,tools/verify/m031-p02-scope-guard.sh"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-01T19:34:21Z"
---

T05 ships the M031/P02 phase-close gates: an 11-gate phase-suite aggregator and the SC-12 scope-guard.

## What was built

- `tools/verify/m031-p02-phase-suite.sh` (133 lines, executable). Mirrors the M031/P01 phase-suite shape verbatim (straight-line, AD-19 compliant, no array loops, no compound chains, no eval). Eleven literal `bash <verifier>` invocations, each followed by `rc=$?` and `emit_gate_result`. Gates do NOT short-circuit on failure (operator sees the full report). Final stdout: `SUMMARY: m031-p02-phase-suite.sh pass=N fail=M`. Exit 0 iff every sub-gate exits 0. Sub-gate inventory: 4 from T01, 2 from T02, 2 from T03, 2 from T04, 1 from T05 (the scope-guard itself). On the clean run: `pass=11 fail=0`.

- `tools/verify/m031-p02-scope-guard.sh` (271 lines, executable). Enforces the SC-12 normative block-list (`knowledge/`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`) inherited verbatim from P01. Allow-list is the P02 surface (10 source/test files + 10 shape verifiers + this T05 pair + 12 phase-and-task plan/summary paths under `.orchestrator/milestones/M031/phases/P02/`). Two permissive prefixes: `.orchestrator/observability/` (inherited from P01) and `.orchestrator/tier-a-plus/` (per-flow scratch artifacts written during T04 router test runs). The `is_mem_hitcount_only_carveout()` helper is copied verbatim from `tools/verify/m031-p01-scope-guard.sh` so orchestrator-emitted MEM `hit_count` drift on `knowledge/(conventions|lessons|patterns)/MEM*.md` continues to surface as `OK` rather than a hard violation. Final stdout: `SUMMARY: m031-p02-scope-guard.sh pass=N fail=M block_list_violations=K mem_hitcount_carveouts=L`. Exit 0 iff `block_list_violations=0`.

## Key decisions

- Phase-suite gate ordering follows T01 -> T02 -> T03 -> T04 -> T05 dependency order so the report reads top-down. The scope-guard runs LAST so a clean diff is required for green (any pre-existing block-list violation surfaces as the final FAIL line).
- `.orchestrator/tier-a-plus/` added as a permissive prefix alongside `.orchestrator/observability/`. P02 introduces per-flow scratch artifacts under that prefix during T04 router test runs; treating it as permissive matches the P01 observability JSONL pattern.
- Two distinct envelope conventions remain in P02 (inherited from P01): `RESULT: SC-N pass` for SC tests; `SUMMARY: <verifier> pass=N fail=M` for shape verifiers. T05 does NOT change this convention.

## Patterns established

- Phase-suite straight-line N-gate aggregation pattern repeats for the second time (P01 had 9 gates, P02 has 11). The pattern is now load-bearing across milestones; future phases can mechanically clone it.
- SC-12 scope-guard pattern repeats with two-prefix permissive carve-out (observability + per-flow scratch). Future phases with their own scratch directories can follow the same dual-prefix shape.
- MEM `hit_count`-only carve-out is now invariantly inherited verbatim across phases — confirming it as a project-wide pattern for handling orchestrator-emitted side-effect drift on knowledge files.

## Verification

- `bash tools/verify/m031-p02-phase-suite.sh` -> rc=0, `SUMMARY: m031-p02-phase-suite.sh pass=11 fail=0`. Idempotent (two consecutive runs produce byte-identical output).
- `bash tools/verify/m031-p02-scope-guard.sh` -> rc=0, `SUMMARY: m031-p02-scope-guard.sh pass=31 fail=0 block_list_violations=0 mem_hitcount_carveouts=31`. WARN lines surface pre-existing session-entry working-tree drift ([M036](../../../../../milestones/M036/index.md) work, CLAUDE.md edits, spec-033, references, build-context.sh, p00-phase-suite.sh) — none of which is P02-scoped; expected per upstream T04 report.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P02/` -> 94 PASS / 3 FAIL. The 3 FAILs are pre-existing T04 deliverables: phase plan declares key-links from `scripts/intake/route-to-dispatch.sh` to literal `templates/dispatch-role-{research,plan,build}.md` filenames, but T04 wrote the path as a parameterized string `templates/dispatch-role-${_r_role}.md` (line 196). Fixing this would require editing T04 deliverables which T05 plan-time discipline forbids ("No edits to upstream P02 deliverables in T05 — T01–T04 outputs stay frozen"). Forwarded for resolution as a P02 close-out remediation.

## Forward-looking notes for P03+

- The phase-suite is now extensible: future maintainers extending P02 (or referencing the P02 close-out gate) MUST update the expected `SUMMARY: pass=N` count in the P04 acceptance-battery aggregator if any new gate is added.
- The 3 key-link FAILs from `check-must-haves.sh` are forwarded as a phase-close remediation: either amend the router to include literal `dispatch-role-research.md` / `dispatch-role-plan.md` / `dispatch-role-build.md` strings (e.g. in a `# References:` comment block, mirroring the P01 build-context.sh remediation), OR amend the P02-PLAN.md key-links table to drop the literal-filename expectation in favor of the parameterized form. The fix belongs to a P02 close-out housekeeping commit, not T05.
- Pre-existing M036 / CLAUDE.md / spec-033 working-tree drift continues to surface as WARN in the scope-guard. P02 close should commit it onto a separate housekeeping branch before milestone consolidation, matching the recommendation forwarded from P01.
