---
schema_version: "1.0"
type: milestone-summary
id: "M024"
parent: "028-universal-intake-routing"
milestone: "M024"
provides:
  - "Universal intake (idea/paragraph/fragment/spec/empty_qa shapes); six-axis proposal artifact; approval-gate verb dispatcher (approve|cancel|revise|manual|skip); degenerate fast-path; revision flow with version-suffix archive; pre-M023 design-gate graceful degradation; 15 intake scripts; 65 phase verifiers + 7 phase-suite aggregators; 15 phase tests; templates/intake-proposal.md and templates/intake-qa-questions.md; auto_proceed config knob"
requires:
  - "M014 interim-manifest read direction; M020 schema-authority for transient frontmatter axes (D024 handshake); 028-universal-intake-routing feature spec"
affects:
  - "M023 (Design Layer) — manual/skip verbs flip from pre-M023 degradation to operator-opt-out fallback when m023_shipped probe flips; M013 (GitHub integration) — proposal.md is addressable for future PR-comment workflows"
key_files:
  - "scripts/intake/shape-detect.sh,scripts/intake/proposal-emit.sh,scripts/intake/intake-id-allocate.sh,scripts/intake/paragraph-classify.sh,scripts/intake/spec-shape-classify.sh,scripts/intake/approval-gate.sh,scripts/intake/qa-loop.sh,scripts/intake/revise.sh,scripts/intake/axis-rederive.sh,scripts/intake/design-gate-classify.sh,scripts/intake/design-gate-degradation.sh,scripts/intake/route-to-specify.sh,scripts/intake/route-to-dispatch.sh,scripts/intake/m014-manifest-read.sh,templates/intake-proposal.md,templates/intake-qa-questions.md,commands/evaluate.md,scripts/state/read-config.sh,templates/orchestrator-config-default.yml,specs/028-universal-intake-routing/spec.md"
key_decisions:
  - "D025 — pending_design_authored_manually transient frontmatter key under M024 schema authority; AD-3 — proposal frontmatter pinned at schema_version 1.0; AD-1 — auto_proceed is project-config-only (no per-invocation CLI flag); SB-3 — proposal write-confinement to .orchestrator/intake/id/ directory; FR-6 — byte-compatible legacy spec-path evaluation output preserved; FR-7 — pre-M023 message byte-pinned across three sites for grep-F stability"
patterns_established:
  - "pure-decision-emitter (15 leaf scripts in scripts/intake); two-mode pure-leaf script (probe-only emitter + branch mutator gated by mutually-exclusive flag groups); closed-enum routing axis (every proposal axis grep-assertable); phase-suite shape with MEM002 parallel-array tracker; env-override matrix testing for not-yet-shipped probes; idempotent halt-and-flip cycle for operator-authored external artifacts"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P01/P01-SUMMARY.md,.orchestrator/milestones/M024/phases/P02/P02-SUMMARY.md,.orchestrator/milestones/M024/phases/P03/P03-SUMMARY.md,.orchestrator/milestones/M024/phases/P04/P04-SUMMARY.md,.orchestrator/milestones/M024/phases/P05/P05-SUMMARY.md,.orchestrator/milestones/M024/phases/P06/P06-SUMMARY.md,.orchestrator/milestones/M024/phases/P07/P07-SUMMARY.md"
duration: "949m"
verification_result: "pass"
completed_at: "2026-04-26T14:19:23Z"
observability_surfaces:
  - "execution-log.jsonl per-task records (29 tasks); auto_proceeded boolean in proposal frontmatter for fast-path observability; cancelled_at and revised_from fields in proposal frontmatter"
---

M024 — **Universal Intake & Routing** — extends `orchestrator:evaluate` so any input shape (idea, paragraph, fragment, spec, empty + Q&A) produces a single reviewable six-axis proposal artifact at `.orchestrator/intake/<id>/proposal.md` that gates dispatch on Constitution Principle III.

## What Was Built

**Seven phases shipped, 116/116 milestone-validation checks PASS.**

- **P01 — Foundation**: input-shape detector (`shape-detect.sh`), intake-id allocator with [M020](../../milestones/M020/index.md) schema-authority backing, six-axis proposal template (`templates/intake-proposal.md`), and the proposal emitter stub (`proposal-emit.sh`). Establishes the `.orchestrator/intake/<id>/` write-confinement boundary (SB-3) and pins the proposal frontmatter at `schema_version: "1.0"` (AD-3).
- **P02 — Spec-path backcompat**: spec deep-classifier (`spec-shape-classify.sh`) preserves byte-compatible legacy evaluation output (FR-6) while emitting a parallel proposal with `input_shape: spec`. [M014](../../milestones/M014/index.md) interim-manifest reads pass through `m014-manifest-read.sh`.
- **P03 — Paragraph + approval-gate**: paragraph deep-classifier (`paragraph-classify.sh`), the approve/cancel/revise verb dispatcher (`approval-gate.sh`), and downstream routers (`route-to-specify.sh`, `route-to-dispatch.sh`).
- **P04 — Degenerate fast-path**: Tier A + Quick + no-conversus + no-design auto-proceeds without an approval prompt. Gated by the new `auto_proceed` config key (`templates/orchestrator-config-default.yml`); per AD-1 there is no per-invocation CLI flag.
- **P05 — Empty input + Q&A**: up-to-5-turn Q&A loop (`qa-loop.sh`) with embedded transcript in the emitted proposal. Short-circuit forces `low_confidence: true` to block fast-path under-confidence.
- **P06 — Revision flow**: `revise.sh` re-emits with version-suffix archive (prior `proposal.md` saved as `proposal-v<N>.md`), axis re-derivation (`axis-rederive.sh`) propagating dependent-axis updates, and approval-state reset.
- **P07 — Design-gate axis + pre-M023 graceful degradation**: `design-gate-classify.sh` (13-token `grep -wE` whole-word classifier), `design-gate-degradation.sh` (two-mode probe-only emitter + branch mutator), `manual` and `skip` verbs in `approval-gate.sh`, FR-7 byte-pinned message stable across three sites, M023-shipping invoke-time probe with `M023_SHIPPED_PROBE_OVERRIDE` env override.

## Cross-Cutting Patterns

- **Pure decision emitter**: every leaf classifier writes nothing — emits `key=value` lines to stdout, validates against closed enums, exits 0/1/2 by contract. The only mutators are the proposal emitter, the revision script, and the design-gate manual-branch handler, all confined to the `--proposal` path under SB-3 write-confinement. Proven across 15 leaf scripts in `scripts/intake/`.
- **Two-mode pure-leaf script**: `design-gate-degradation.sh` demonstrates a single script can be both a probe-only decision emitter AND a frontmatter mutator, gated by mutually-exclusive flag groups (`--probe-only` vs `--branch=manual|skip`).
- **Closed-enum frontmatter axis**: every routing axis in the proposal template uses a closed enum (`input_shape ∈ {idea, paragraph, fragment, spec, empty_qa}`, `design_gate ∈ {none, walkthrough}`, etc.) so verifiers can grep-assert without fuzzy parsing. Establishes the M024 schema-evolution discipline that complements M020's MEM031 status: vocabulary.
- **Phase-suite shape**: each P0X ships an `m024-p0x-suite.sh` aggregator that runs all phase tests + verifiers in one call, using MEM002 parallel-array trackers (bash 3.2 portable). Total: 65 phase verifiers + 7 suite aggregators + 15 phase tests across the milestone.
- **Env-override matrix testing**: `M023_SHIPPED_PROBE_OVERRIDE` closed-enum (`stub|live`) with synthetic-ROOT positive disk-probe coverage gives full state-space test coverage without depending on real M023 ship state. Reusable shape for any future "depends on a not-yet-shipped milestone" probe.
- **Idempotent halt-and-flip cycle**: design-gate manual branch establishes the pattern of first-invoke halts (sets `pending_*: true`) → operator authors external artifact → follow-up flips terminal state, with re-invokes no-oping until the external artifact exists. D025 documents the closed-enum semantics.

## Decisions Registered

- **D025 (M024/P07)**: `pending_design_authored_manually` transient frontmatter key for the FR-7 manual-branch halt-and-flip cycle. Closed-enum `true | false`, initialized false on every fresh emit, mutated only by `design-gate-degradation.sh --branch manual`. Anchors M024's schema-evolution authority over the intake-proposal frontmatter (parallel to M020's authority over knowledge-entry frontmatter per D024).

## Forward Bindings

- **M023 (Design Layer)** is the next consumer. The pre-M023 `manual` and `skip` verbs become operator-opt-out fallbacks rather than M023-not-yet-shipped degradation; the `m023_shipped` probe flips and `recommended_command` gains `orchestrator:design`. Wiring lives behind the `m023_shipped=true` branch already in `proposal-emit.sh`'s recommended-command guard.
- **M020 schema authority**: M024 frontmatter additions (six routing axes + transient flags) coexist with but do not bypass M020's MEM031 status: vocabulary — the intake-proposal frontmatter is M024-authoritative; knowledge entries remain M020-authoritative.
- **[M013](../../milestones/M013/index.md) GitHub integration**: the proposal artifact at `.orchestrator/intake/<id>/proposal.md` is naturally addressable for future PR-comment workflows; no integration shipped this milestone.

## Verification

Phase suites green at every transition. Final milestone validation: **116/116 PASS** via `scripts/verify/validate-milestone.sh`.
