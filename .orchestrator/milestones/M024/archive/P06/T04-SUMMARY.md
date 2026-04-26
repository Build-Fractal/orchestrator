---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P06"
milestone: "M024"
provides:
  - "tests/test-revision-flow.sh; tests/test-revision-version-preservation.sh; scripts/verify/m024-p06-write-confinement.sh; scripts/verify/m024-p06-evaluate-md.sh; scripts/verify/m024-p06-suite.sh; commands/evaluate.md revise-verb description updated to wired-in-P06 phrasing"
requires:
  - "T01 (scripts/intake/axis-rederive.sh); T02 (scripts/intake/revise.sh, proposal-emit.sh --axes-from); T03 (approval-gate.sh wired revise verb + --no-apply); P03 (commands/evaluate.md revise-verb sentence to rewrite)"
affects:
  - "commands/evaluate.md (one-line revise-verb description rewrite, FR-6 byte-compat preserved on legacy spec path); closes M024 P06 phase suite at 10/10 PASS"
key_files:
  - "tests/test-revision-flow.sh, tests/test-revision-version-preservation.sh, scripts/verify/m024-p06-write-confinement.sh, scripts/verify/m024-p06-evaluate-md.sh, scripts/verify/m024-p06-suite.sh, commands/evaluate.md"
key_decisions:
  - "Write-confinement allowlist extended with `diff_marker` token to recognize revise.sh's mktemp-bound idempotency marker (it was caught by the tightened P03 regex even though the underlying file path is in /tmp); allowlist remains a curated set of mktemp-variable names rather than a heuristic on `mktemp` flow, keeping the regex deterministic per closed-enum spirit"
patterns_established:
  - "Phase-suite dual-use of MEM002 parallel-array tracker — `m024-p06-suite.sh` runs both the cross-cutting tests/*.sh phase tests and the per-task scripts/verify/*.sh single-purpose verifies through one `run_one` indirection; PASS/FAIL summary captures every entry in a single SUMMARY: N/N line per AD-19 single-script-file shape"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P06/tasks/T04-PAYLOAD.md, .orchestrator/milestones/M024/phases/P06/tasks/T04-PLAN.md"
duration: "8m"
verification_result: "pass"
completed_at: "2026-04-26T04:33:06Z"
---

## Summary

T04 is the P06 fan-in: two phase-level revision-flow tests, two new write-confinement and evaluate.md verify scripts, and a 10-entry MEM002 parallel-array suite tracker. Plus a one-line revise-verb description rewrite in `commands/evaluate.md` flipping the P03 placeholder ("full revision body lands in P05; P03 records revision intent only") to the wired-in-P06 phrasing referencing `scripts/intake/revise.sh`.

## What was built

- **`tests/test-revision-flow.sh`** — end-to-end happy path. Emits a Tier B paragraph proposal, revises scope_tier B → C via `approval-gate.sh --verb revise`, and asserts: prior content archived as `proposal-v1.md` with original tier preserved; current `proposal.md` carries `scope_tier: "C"` plus rederived dependents (`decomposition: "milestone-with-phases"`, `recommended_command: "orchestrator:specify"`); approval state reset (`pending_approval: true`, `approved_at: null`, `cancelled_at: null`); `## Original Input` body byte-identical across the revision.
- **`tests/test-revision-version-preservation.sh`** — two consecutive revises with FR-14 idempotent no-op on the third. Asserts `proposal-v1.md` byte-identical to the original emit; `proposal-v2.md` byte-identical to the post-first-revise content; `proposal-v1.md` not mutated by the second revise; third revise (same value as current) emits `revised=false reason=identical-axes` and produces no `proposal-v3.md` archive.
- **`scripts/verify/m024-p06-write-confinement.sh`** — SB-3 write-confinement check across `scripts/intake/axis-rederive.sh` + `scripts/intake/revise.sh`; reuses the tightened P03 regex `[[:space:]]>[[:space:]]*[^&[:space:]/]` and an allowlist of mktemp scratch-variable tokens (`tmp_render`, `axes_tmp`, `qa_tx_tmp`, `arc_qa_tmp`, `body-src`, `diff_marker`) plus path patterns (`/tmp`, `.orchestrator/intake`, `.bak`). Spot-checks that `proposal-emit.sh` carries `axes-from` wiring and `approval-gate.sh` carries `revised_to` wiring.
- **`scripts/verify/m024-p06-evaluate-md.sh`** — three assertions on `commands/evaluate.md`: (1) literal `wired in P06` present, (2) `scripts/intake/revise.sh` referenced, (3) legacy `P03 surface-only` string absent.
- **`scripts/verify/m024-p06-suite.sh`** — MEM002 parallel-array tracker (bash 3.2 safe, no `declare -A`) running 10 entries: 2 phase-level tests + 8 per-task verifies (axis-rederive, revise-script, version-suffix, axes-from-flag, approval-gate-revise-wired, rederive-rationale, write-confinement, evaluate-md). Emits `PASS:`/`FAIL:` per entry plus a single `SUMMARY: N/N PASS` line.
- **`commands/evaluate.md`** — one-line edit on the revise verb description: `revise <axis>=<value>` — wired in P06: full re-emit via `scripts/intake/revise.sh` (prior `proposal.md` archived as `proposal-v<N>.md`, dependent axes re-derived, approval state reset). FR-12.

## Key decisions / patterns

- **Allowlist extension for `diff_marker`** — `revise.sh` line 94 (`echo "DIFF" >> "$diff_marker"`) initially tripped the write-confinement regex even though `diff_marker=$(mktemp)` confines the path to `/tmp`. The fix kept the curated-token allowlist style (deterministic, closed-enum) rather than introducing variable-flow analysis. A future cleanup could collapse all mktemp scratch-variable names to a single convention (`*_scratch`) and reduce the allowlist to one regex token.
- **Suite-tracker dual-use** — `m024-p06-suite.sh` runs both `tests/test-*.sh` phase tests and `scripts/verify/m024-p06-*.sh` per-task verifies through one `run_one` helper, treating the test/verify distinction as a label-only decision. This is the same shape used by `m024-p03-suite.sh` and `m024-p04-suite.sh`; T04 promotes it as the canonical phase-fan-in pattern.

## Verification

`bash scripts/verify/m024-p06-suite.sh` → all 10 entries PASS:

- `PASS: test-revision-flow.sh`
- `PASS: test-revision-version-preservation.sh`
- `PASS: m024-p06-axis-rederive`
- `PASS: m024-p06-revise-script`
- `PASS: m024-p06-version-suffix`
- `PASS: m024-p06-axes-from-flag`
- `PASS: m024-p06-approval-gate-revise-wired`
- `PASS: m024-p06-rederive-rationale`
- `PASS: m024-p06-write-confinement`
- `PASS: m024-p06-evaluate-md`
- `SUMMARY: 10/10 PASS`
- `PASS: M024/P06 suite — revision flow + version preservation + rationale + wired approval-gate`

P01–P05 suites all continue to PASS (re-run after T04 edits): `m024-p01-suite.sh`, `m024-p02-suite.sh`, `m024-p03-suite.sh`, `m024-p04-suite.sh`, `m024-p05-suite.sh` — each exits 0 with no regression.

## Concerns

None. Allowlist extension for `diff_marker` is constrained to the named write-set (`scripts/verify/m024-p06-write-confinement.sh`) and consistent with the curated-token pattern P03 established. No scope widening.
