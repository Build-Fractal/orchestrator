---
schema_version: "1.0"
type: phase-summary
id: "P07"
parent: "M024"
milestone: "M024"
provides:
  - "design-gate-classifier-script,design-gate-verify-script,scripts/intake/design-gate-degradation.sh; scripts/verify/m024-p07-degradation-script.sh; scripts/verify/m024-p07-pinned-message.sh; scripts/verify/m024-p07-m023-probe.sh,proposal-emit.sh wired to design-gate-classify.sh + recommended_command guard against orphan orchestrator:design; approval-gate.sh accepts manual|skip verbs delegating to design-gate-degradation.sh; templates/intake-proposal.md gains pending_design_authored_manually transient key; 3 new verify scripts (skip-branch,manual-branch,approval-gate-design-verbs),tests/test-design-gate-degradation.sh; tests/test-design-gate-skip.sh; tests/test-design-gate-manual.sh; scripts/verify/m024-p07-no-orphan-design-cmd.sh; scripts/verify/m024-p07-write-confinement.sh; scripts/verify/m024-p07-evaluate-md.sh; scripts/verify/m024-p07-suite.sh; commands/evaluate.md Pre-M023 section update; .orchestrator/DECISIONS.md D025 row"
requires:
  - "P01,P03"
affects:
  - "none"
key_files:
  - "scripts/intake/design-gate-classify.sh,scripts/verify/m024-p07-design-gate-classify.sh,scripts/intake/design-gate-degradation.sh,scripts/verify/m024-p07-degradation-script.sh,scripts/verify/m024-p07-pinned-message.sh,scripts/verify/m024-p07-m023-probe.sh,scripts/intake/proposal-emit.sh,scripts/intake/approval-gate.sh,templates/intake-proposal.md,scripts/verify/m024-p07-skip-branch.sh,scripts/verify/m024-p07-manual-branch.sh,scripts/verify/m024-p07-approval-gate-design-verbs.sh,tests/test-design-gate-degradation.sh,tests/test-design-gate-skip.sh,tests/test-design-gate-manual.sh,scripts/verify/m024-p07-no-orphan-design-cmd.sh,scripts/verify/m024-p07-write-confinement.sh,scripts/verify/m024-p07-evaluate-md.sh,scripts/verify/m024-p07-suite.sh,commands/evaluate.md,.orchestrator/DECISIONS.md"
key_decisions:
  - "13-token-canonical-set,grep-wE-whole-word-match,pure-decision-emitter-no-side-effects,Invoke-time M023 probe (no caching across invocations) per #DQ-2 option b; FR-7 message byte-pinned across three sites; M023_SHIPPED_PROBE_OVERRIDE closed enum stub|live for regression testing; pending_design_authored_manually transient frontmatter flag for manual-branch first/follow-up state; manual branch keeps pending_approval=true on completion (no auto-proceed),Recommended_command guard runs after axis resolution and uses inline (env-override + disk-probe) probe shape rather than --probe-only since proposal not yet rendered; DESIGN_AXES_DONE flag mirrors PARA/SPEC/QA pattern; manual/skip verbs in approval-gate forward stdout/stderr from design-gate-degradation.sh verbatim,D025 commits pending_design_authored_manually closed-enum semantics under M020/MEM031 schema-authority handshake; verifier regex for m023_shipped gate broadened to include POSIX-style [ $var = true ] shape"
patterns_established:
  - "design-gate-axis-classifier,Two-mode pure-leaf script (probe-only emitter + branch-mode mutator); env-override matrix with synthetic ROOT for positive disk-probe testing; idempotent manual-branch follow-up (re-invoke until DESIGN.md exists),DESIGN_AXES_DONE deep-classifier skip flag; inline-probe-shape for pre-render guards; transient frontmatter key (pending_design_authored_manually) initialized false on every fresh emit,only mutator is manual-branch handler,P07 phase-suite shape (3 phase tests + 10 per-claim verifies,13 total via MEM002 parallel-array tracker); doc-only forward-reference labelling pattern (orchestrator:design only mentioned within 10 lines of post-M023 marker for grep-based no-orphan verifier)"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P07/tasks/T01-SUMMARY.md, .orchestrator/milestones/M024/phases/P07/tasks/T02-SUMMARY.md, .orchestrator/milestones/M024/phases/P07/tasks/T03-SUMMARY.md, .orchestrator/milestones/M024/phases/P07/tasks/T04-SUMMARY.md"
duration: "810m"
verification_result: "pass"
completed_at: "2026-04-26T13:16:00Z"
observability_surfaces:
  - "none"
---

## What Was Built

P07 wires the **design gate** axis end-to-end into the M024 intake/proposal flow as a degraded-but-functional pre-M023 path.

- **T01 — Design-gate classifier** (`scripts/intake/design-gate-classify.sh`): pure decision emitter that scans `--input` text or `--spec-path` body for 13 design-domain tokens (`ui UI render design layout screen view panel viewer dashboard interface visual theme`) using `grep -wE` whole-word matching. Emits `design_gate=<none|walkthrough>` + `design_gate_confidence=<low|high>` based on hit count (0/1/≥2).
- **T02 — Degradation script** (`scripts/intake/design-gate-degradation.sh`): two-mode helper. `--probe-only` returns the M023-shipping probe verdict (env override `M023_SHIPPED_PROBE_OVERRIDE=stub|live` plus disk-probe fallback) plus the FR-7 byte-pinned guidance message; branch-mode (`--branch=manual|skip`) mutates the proposal frontmatter (`design_skipped`, `design_authored_manually`, `pending_design_authored_manually`, `pending_approval`, `proceeded_at`).
- **T03 — Wiring**: `scripts/intake/proposal-emit.sh` now invokes the classifier (sec 5b) to populate `design_gate` + `design_gate_confidence`, plus a recommended-command guard (sec 5c) that prevents an orphan `orchestrator:design` recommendation pre-M023. `scripts/intake/approval-gate.sh` accepts the new `manual` and `skip` verbs, delegating to `design-gate-degradation.sh` after validating `design_gate=walkthrough` and `m023_shipped=false`. `templates/intake-proposal.md` gains the `pending_design_authored_manually` transient frontmatter key.
- **T04 — Phase suite + closeout**: 3 phase tests (`tests/test-design-gate-{degradation,skip,manual}.sh`) and 4 verify scripts (`m024-p07-{no-orphan-design-cmd,write-confinement,evaluate-md,suite}.sh`) bring the P07 verify count to 13 PASS lines through the suite. `commands/evaluate.md` Pre-M023 section was flipped from "stubbed" to "wired in P07" with FR-7 message and manual/skip verb table. D025 row appended to `.orchestrator/DECISIONS.md`.

## Key Decisions

- **D025 (closed-enum semantics)**: `pending_design_authored_manually` joins the M020/MEM031 schema-authority registry as a transient frontmatter key. First manual-branch invocation sets it true and halts; follow-up invocations (DESIGN.md authored externally) flip it to permanent `design_authored_manually=true` + `pending_approval=true`.
- **Invoke-time probe (no caching)**: The M023-shipping probe runs at invocation time per #DQ-2 option b — env override first, disk probe fallback. Prevents stale-cache issues during M023 development.
- **FR-7 byte-pinning**: The pre-M023 guidance message is byte-stable across three sites — degradation script source, evaluate.md, and probe-only stderr emission. The `m024-p07-pinned-message.sh` verifier enforces this.
- **No-orphan guard**: `proposal-emit.sh`'s recommended-command logic explicitly guards against emitting `orchestrator:design` before M023 ships; the verifier asserts no orphan reference outside the explicit post-M023 marker block.

## Patterns Established

- **Two-mode pure-leaf script**: A single script can be a pure decision emitter (probe-only) AND a frontmatter mutator (branch-mode), gated by mutually-exclusive flag groups, with the only mutator path operating on a dedicated `--proposal` path under SB-3 write-confinement.
- **Env-override matrix testing**: `M023_SHIPPED_PROBE_OVERRIDE` closed-enum with synthetic-ROOT positive disk-probe coverage — gives full state-space coverage without depending on the real M023 ship state.
- **Idempotent manual-branch follow-up**: The first invocation halts pending external authoring; re-invocations after DESIGN.md exists complete the flip without duplicate side effects.
- **DESIGN_AXES_DONE skip flag**: Mirrors the PARA/SPEC/QA deep-classifier pattern — once the design axis is resolved by the leaf classifier, downstream classifiers skip it.
- **P07 phase-suite shape**: 3 phase tests + 10 per-claim verifies + 1 aggregating suite script with parallel-array tracker (MEM002) — 13 PASS lines total.

## Verification Results

P07 verification suite: **13/13 PASS**. Regression checks: M024/P03 suite (3 PASS) and M024/P06 suite still green. No external modifications detected during phase transition.

## Forward Bindings

- `recommended_command` no longer mentions `orchestrator:design` outside the explicit post-M023 marker block — when M023 ships, the `m023_shipped=true` branch in the recommended-command logic activates and the no-orphan verifier's marker block is removed in the same commit.
- `design-gate-classify.sh` token table is intentionally narrow; M023 is free to extend it (the rule table in the script header is the canonical reference).
- `pending_design_authored_manually` is a transient frontmatter key; M020 schema authority will graduate or retire it as part of milestone consolidation.
