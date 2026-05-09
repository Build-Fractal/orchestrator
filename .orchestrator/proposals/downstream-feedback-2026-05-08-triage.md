# Downstream Agent Feedback — 2026-05-08 Triage

**Intake date:** 2026-05-08
**Sources:** LakeLedger M075, PBJ Stage 3 + wiki rollout, bbt-crm corpus dogfood
**Triage status:** complete
**Next milestone (post-triage):** M035 P00–P06 (packaging & distribution)

This file tracks disposition for a batch of bug reports and feature requests received 2026-05-08 from three downstream projects exercising orchestrator. Triage shape: each item gets a row in the table below; fix-now items land as separate commits referenced inline; deferred items get standalone proposal docs in this directory.

## Intake Table

| ID | Source | Type | Surface | Severity | Disposition | Commit |
|----|--------|------|---------|----------|-------------|--------|
| A | LakeLedger M075 | Feature RFC | new `/orchestrator-discuss-phase` command | Medium | Proposal — `orchestrator-discuss-phase-command.md` | (proposal doc) |
| B1 | PBJ Stage 3 | Docs | `commands/plan-phase.md` (brand-new milestone bootstrap) | Low | Fix-now | `54535afb` |
| B2 | PBJ Stage 3 | Bug | init scripts (intensity drift) | Low | Fix-now | `99e00746` |
| B3 | PBJ Stage 3 | Bug | `scripts/engine/intensity-gate.sh` (case-sensitivity) | Low | Fix-now | `2131c10c` |
| B4 | PBJ Stage 3 | Observation | plan-phase prompt size | n/a | Captured below — no fix |
| C1 | bbt-crm | Bug | `materials-intake.sh` `--resolve` parsed-not-consumed | High | Fix-now | `735641fc` |
| C2 | bbt-crm | Bug | `materials-intake.sh` FD-0 stdin-steal (labeling) | High | Fix-now | `35ffff61` |
| C3 | bbt-crm | Bug | `materials-intake.sh` FD-0 stdin-steal (`reconcile_terminal`) | High | Fix-now | `743970e5` |
| C4 | bbt-crm | Bug | `materials-intake.sh` PDF probe-only pollutes conflicts | High | Fix-now (skip-with-diagnostic) | `37aafeea` |
| C5 | bbt-crm | Observation | `enumerate_materials` non-recursive + dual-purpose `--project-dir` | n/a | Captured below — no fix |
| D | PBJ wiki | Bug | `emit-managed-gitignore.sh` missing M035 rollback sidecars | Low | Fix-now | `ad1125a1` |
| E1 | bbt-crm | Bug | `extract-manifest.sh` YAML block-scalar (`\|`/`>`) | Medium | Fix-now | `9d5a1ace` |
| E2 | bbt-crm | Bug | `rebuild-index.sh` ignores REF chunks (`chunk_id` fallback) | High | Fix-now | `53aeb2ea` |
| E3 | bbt-crm | Architectural | concurrent-agent commit isolation | High | Proposal — `concurrent-agent-commit-isolation.md` | (proposal doc) |

## Informational items (no fix)

### B4 — Plan-phase prompt size when invoked sequentially by an LLM

The reporter notes that running four `orchestrator:plan-phase` invocations in sequence loads `commands/plan-phase.md` four times — AD-19 forbidden-shape enumeration, plan-time discipline, naming conventions, error handling, idempotency rules. They didn't propose a fix because the trade-off isn't clean: trimming the prompt may cost output quality more than it saves context.

Decision: leave as-is. The verbose prompt is what makes the skill outputs reliable. Re-evaluate post-launch if multiple users surface the cost. Possible future direction: split into "first invocation full prompt" + "subsequent invocation abbreviated prompt" with a session-cache hint.

### C5 — `enumerate_materials` non-recursive + `--project-dir` dual-purpose

The reporter observes that `materials-intake.sh` scans only the top level of `--project-dir` and uses the same path as the intake-output root. Operators with materials in a sub-folder must either (a) stage at project root (polluting it) or (b) pass `--project-dir <subfolder>` (dropping intake outputs into the subfolder). Their workaround: a stash-shield pattern renaming `CLAUDE.md`/`AGENTS.md`/`package*.json`/`tsconfig.json` to dot-prefixed names so the `*.md`/`*.json` glob skipped them.

Decision: capture as a known constraint. Real fix is a `--source-dir` flag independent of `--project-dir`, plus a docs note about the workaround. Defer to a future M033-followup paper-cut sweep — not blocking M035, not blocking corpus dogfood.

## Fix-now batch summary

Six commits land as part of this batch. Sub-agent investigations land four more (C-cluster split into separate commits per defect, E1, plus the two proposal docs).

## Deferred proposals

- `orchestrator-discuss-phase-command.md` — phase-level discussion gate, mirrors milestone-level discuss; gate-findings-aware. Demand-driven slot, sibling to M034 (interactive review gates).
- `concurrent-agent-commit-isolation.md` — three-layer fix design (pre-commit hook → lock-aware git add → per-session worktree). Architectural; ships when first multi-agent contention pattern is reproduced upstream.

## Source documents

Original handoffs are not stored in-repo. Reproduction:

- LakeLedger M075 RFC — `~/Sites/lake-ledger/docs/UPSTREAM-FEATURE-PROMPT-orchestrator-discuss-phase.md` (or equivalent)
- PBJ Stage 3 — `~/Sites/pbj-central-mono-repo/docs/UPSTREAM-PATCH-HANDOFF-plan-phase-ux-gaps.md`
- PBJ wiki — `~/Sites/pbj-central-mono-repo/docs/UPSTREAM-PATCH-HANDOFF-managed-gitignore-rollback-sidecars.md`
- bbt-crm — `~/Sites/bbt-crm/.orchestrator/intake/20260509T025041Z/` and bbt-crm M036 round-2 report
