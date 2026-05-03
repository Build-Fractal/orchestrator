---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M031"
milestone: "M031"
provides:
  - "spec-body fold-in (AD-1..AD-20),SC-15 + SC-16 added,SC-2/SC-3/SC-11/SC-13 rewritten,SC-14 raised to N >= 15,p00-spec-foldin-shape.sh verifier,20-task AD-15 corpus + manifest + AD-14 pre-M031 stub + AD-17 RUNTIME-ASSUMPTIONS fold-in + 3 M031 config defaults + 5 P00 verifiers,FR-18 empirical-baseline harness + AD-12/SC-13 ordering verifier (Option B preferred / Option A fallback) + AD-14 frozen pre-m031-baseline.jsonl (20 records) + SC13-OPTION.md + 4 P00 verifiers + p00-phase-suite.sh aggregating all 9 P00 gates"
requires:
  - "none"
affects:
  - "P01"
key_files:
  - "specs/034-right-sized-entry/spec.md,tools/verify/p00-spec-foldin-shape.sh,tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md,tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh,references/RUNTIME-ASSUMPTIONS.md,templates/orchestrator-config-default.yml,tools/verify/p00-corpus-manifest-shape.sh,tools/verify/p00-corpus-population.sh,tools/verify/p00-pre-stub-shape.sh,tools/verify/p00-runtime-assumptions-foldin.sh,tools/verify/p00-config-defaults-pinned.sh,tests/m031-acceptance/empirical-baseline.sh,tests/m031-acceptance/verify-baseline-ordering.sh,tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl,tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md,tools/verify/p00-baseline-harness-shape.sh,tools/verify/p00-ordering-verifier-shape.sh,tools/verify/p00-pre-baseline-jsonl-population.sh,tools/verify/m031-p00-phase-suite.sh"
key_decisions:
  - "AD-12 Option B preferred for SC-13 (git-history check); AD-13 ±20% literal removed globally including audit-trail; AD-18 SC-15 added; AD-20 SC-16 added,cost_class derived from duration_s (total_tokens/re_dispatch_count absent from live records,manifest documents the substitution); 3 new knobs added at top level not folded into compression: block (matches auto_proceed shape); auto_proceed left at line 27 (P04 ratification job,not a P00 knob-flip),SC-13 Option A selected (corpus path uncommitted at T03-execution time,git log returns empty for the corpus path so Option B has no defined LHS; SC-14 effective N=14; operators may re-run after T03+P01 commits land to upgrade to Option B); harness median uses lower-middle for even-N to avoid bash 3.2 floating-point math (stable for inequality-based SC-11 verdict); pass-rate fixed-point integer comparison sidesteps shell FP entirely"
patterns_established:
  - "post-roadmap spec fold-in (defer ratified ADs into spec body until phase IDs pinned); inverted-polarity grep verifier with explicit comment guarding the inversion against future maintainer 'fixes',AD-14 single-window stub pattern (frozen pre-state capture before destructive surface modification,stub MUST NOT call the surface it captures); inverted-grep verifier with comment-vs-code distinction (allow header-comment references to a path while rejecting non-comment invocations),AD-14 single-window harness pattern (--post-m031-emitter seam = empty default emits 'capture pending' on stderr + exit 0,P01 first task supplies real emitter to satisfy 'simultaneously while both code paths are live'); harness re-runnability via deterministic stub + truncate-on-capture (idempotent re-runs produce identical pre-m031-baseline.jsonl bytes); phase-suite straight-line nine-gate aggregation (no array loops,AD-19 compliant) with per-gate OK:/FAIL: + final SUMMARY: pass=N fail=M"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P00/tasks/T01-SUMMARY.md, .orchestrator/milestones/M031/phases/P00/tasks/T02-SUMMARY.md, .orchestrator/milestones/M031/phases/P00/tasks/T03-SUMMARY.md"
duration: "195m"
verification_result: "pass"
completed_at: "2026-05-01T16:48:44Z"
observability_surfaces:
  - "none"
---

## What Was Built

P00 establishes the **measurement floor** for M031 before any of the surface-modifying phases (P01–P04) touch live code. Three tasks, executed in dependency order:

- **T01 (spec-foldin):** Folded AD-1..AD-20 verbatim into `specs/034-right-sized-entry/spec.md` under a new `## Architectural Decisions (folded post-discuss 2026-05-01)` section, each AD carrying provenance back to `M031-CONTEXT.md`. Rewrote SC-2 (AD-13 ±20% drop), SC-3 (AD-17 inline_threshold_tokens), SC-11 (AD-14 single-window discipline), SC-13 (AD-12 Option B git-history ordering); added SC-15 (AD-18 median absolute budget compliance) and SC-16 (AD-20 prompt UX integration); raised SC-14 to `N ≥ 15`. Spec grew 267 → 408 lines. Original Open Questions / Gate Findings sections preserved as audit trail.
- **T02 (corpus-and-defaults):** Authored the AD-15 stratified 20-task corpus (`CORPUS-MANIFEST.md` + 20 task fixtures: 5 historical-derived with real `<milestone>/<phase>/<task>` provenance, 5 synthetic edge cases, 10 category-spread fillers) — manifest expanded to 145 lines covering stratification rationale, provenance audit trail, and reproduction protocol. Authored the AD-14 `pre-m031-stub.sh` frozen-state capture (94 lines, executable, MUST NOT call `scripts/dispatch/build-context.sh`). Folded the M018 Tier-1 `inline_threshold_tokens` precondition into `references/RUNTIME-ASSUMPTIONS.md`. Pinned three M031 knobs in `templates/orchestrator-config-default.yml` (`quick_knowledge_token_budget: 800`, `entry_routing_confidence_floor: 0.7`, `tier_a_plus_prompt_summary_lines: 8`).
- **T03 (harness-and-suite):** Built the FR-18 empirical-baseline harness (`tests/m031-acceptance/empirical-baseline.sh`, 255 lines, `--post-m031-emitter` seam ready for P01-first-task wire-in). Built the AD-12/SC-13 ordering verifier (`verify-baseline-ordering.sh`, 101 lines, Option B preferred / Option A documented fallback). Materialized the AD-14 frozen `pre-m031-baseline.jsonl` (exactly 20 records, schema `path: "pre-m031"`, `knowledge_section_tokens: 0`). Wrote 3 task-level verifiers + the 9-gate `p00-phase-suite.sh` aggregator.

## Key Decisions

- **AD-12 SC-13 Option A selected** (T03/SC13-OPTION.md) — corpus path was uncommitted at T03-execution time; `git log --diff-filter=A` returns empty for the corpus, so Option B has no defined LHS. Effective `N=14` for SC-14. Documented for upgrade to Option B after T03+P01 commits land.
- **Cost-class proxy substitution** — AD-15 plan named `total_tokens` + `re_dispatch_count` as cost-class proxies, but those fields are absent from live `unit_close` records. Manifest documents the substitution: `duration_s` is the nearest observed proxy (high ≥ 5000s, medium 2500–4500s, low ≤ 60s); `verification_pass_rate` was 1.0 across all candidate records, providing no class signal.
- **Three new config knobs at top level** — not folded into the existing `compression:` block. Matches the `auto_proceed` shape (top-level scalar with FR/AD ownership comment) and avoids over-coupling.
- **AD-13 ±20% literal removed globally** — including the audit-trail line. Verifier 7 in `p00-spec-foldin-shape.sh` is inverted-polarity (assert absence) with an explicit comment guarding against a future maintainer "typo fix."

## Patterns Established

- **Post-roadmap spec fold-in** — defer ratified ADs into the spec body until phase IDs are pinned.
- **AD-14 single-window stub pattern** — frozen pre-state capture before destructive surface modification; the stub MUST NOT call the surface it captures (header-comment references allowed, non-comment invocations rejected).
- **AD-14 single-window harness pattern** — `--post-m031-emitter` seam: empty default emits "capture pending" on stderr and exits 0; P01 first task supplies the real emitter to satisfy "simultaneously while both code paths are live."
- **Inverted-polarity grep verifiers** — assert absence with an explicit comment guarding the inversion against well-intentioned future "fixes."
- **Phase-suite straight-line aggregation** — no array loops (AD-19 compliant), per-gate `OK:`/`FAIL:` lines plus a final `SUMMARY: pass=N fail=M` envelope.
- **Bash 3.2 fixed-point comparison** — pass-rate via integer arithmetic to sidestep shell floating-point entirely (stable inequality verdicts for SC-11).

## Verification

- All P00 task-level verifiers green: T01 `p00-spec-foldin-shape.sh pass=7 fail=0`; T02 `p00-corpus-manifest-shape.sh pass=4`, `p00-corpus-population.sh pass=2`, `p00-pre-stub-shape.sh pass=5`, `p00-runtime-assumptions-foldin.sh pass=5`, `p00-config-defaults-pinned.sh pass=5`; T03 `p00-baseline-harness-shape.sh pass=6`, `p00-ordering-verifier-shape.sh pass=5`, `p00-pre-baseline-jsonl-population.sh pass=4`. Aggregated `p00-phase-suite.sh pass=9 fail=0`.
- Phase-level `check-must-haves.sh` clean (one transient gap on CORPUS-MANIFEST line-count remediated mid-loop by expanding the manifest from 68 → 145 lines without touching frontmatter or entry rows).
- `check-boundary-map.sh` SKIP — P00 has no boundary-map produce items declared (foundation phase).
- No P01 surfaces touched (`scripts/dispatch/build-context.sh`, `commands/dispatch.md`, `commands/evaluate.md`, `references/tier-definitions.md` preserved). AD-14 single-window discipline + SC-12 scope-guard intact.
