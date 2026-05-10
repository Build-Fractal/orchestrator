---
schema_version: "1.0"
type: phase-plan
phase: "P00"
milestone: "M031"
goal: "Capture the AD-1..AD-20 amendments into specs/034-right-sized-entry/spec.md so downstream phases reference pinned phase IDs and SC numbers; build the AD-15-stratified 20-task fixture corpus at tests/m031-acceptance/fixtures/empirical-baseline/ with CORPUS-MANIFEST.md and the AD-14-frozen pre-M031 stub; document the M018 tier-1 threshold in references/RUNTIME-ASSUMPTIONS.md per AD-17; pin the new config defaults (quick_knowledge_token_budget=800, entry_routing_confidence_floor=0.7, tier_a_plus_prompt_summary_lines=8) in templates/orchestrator-config-default.yml; ship empirical-baseline.sh (FR-18 harness) + verify-baseline-ordering.sh (SC-13 Option B per AD-12 with Option A fallback) + the captured pre-M031 baseline JSONL — all committed BEFORE P01's first commit lands so the AD-14 single-window discipline holds."
demo_sentence: "An operator reads specs/034-right-sized-entry/spec.md and counts AD-1..AD-20 in the gate-mitigation block, finds canonical SC-15 (AD-18 absolute budget compliance) and SC-16 (AD-20 prompt UX) and a renumbered SC-13 (AD-12 ordering verifier) and SC-14 N≥15; reads tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md and confirms 20 entries stratified per AD-15 (5 historical 2H/2M/1L + 5 synthetic edge-case + 10 spread across ≥3 categories); confirms tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh is executable and emits one JSONL record per task when invoked; greps references/RUNTIME-ASSUMPTIONS.md for the M018 tier-1 inline_threshold_tokens=1500 documentation; greps templates/orchestrator-config-default.yml for the three pinned knobs; runs bash tools/verify/p00-phase-suite.sh and observes SUMMARY: pass=N fail=0 with exit 0; runs bash tests/m031-acceptance/empirical-baseline.sh against the corpus and observes a JSONL emission per task; confirms via git log that no commit modifies scripts/dispatch/build-context.sh or commands/dispatch.md:21 has landed yet (P01's work is gated)."
risk: "medium"
depends_on: []
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Verifier scripts live under tools/verify/ — project-owned path,
     slug-bearing filenames so install-clobber risk is contained.
     Each verifier is co-authored alongside its corresponding artifact
     within the SAME task (plan-time discipline rule 2). -->

### Truths

- `specs/034-right-sized-entry/spec.md` contains AD-1 through AD-20 folded in (header pattern `**AD-1.` through `**AD-20.`), preserves the original Open Questions / Gate Findings sections as audit trail, renumbers SC-13 to the AD-12 ordering-verifier shape (Option B preferred per AD-12, Option A fallback documented), adds SC-15 (AD-18 median absolute budget compliance) and SC-16 (AD-20 prompt UX integration test), updates SC-14 to assert `N ≥ 15`, and pins phase IDs (P00..P04) where AD bodies refer to "this phase" or "P00 of the roadmap-pinned plan."
  - Check: `bash tools/verify/p00-spec-foldin-shape.sh`

- `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md` exists with YAML frontmatter (`schema_version: "1.0"`, `type: empirical-baseline-corpus`, `milestone: "M031"`, `phase: "P00"`, `created_at`, `stratification_constraint: "AD-15"`) and a body documenting exactly 20 corpus entries stratified per AD-15: ≥5 historical-JSONL-derived tasks (2 high-cost / 2 medium / 1 low by pre-M031 rediscovery cost) + ≥5 synthetic edge-case tasks (empty / 1-file / 5-file / 10-file / doc-only) + ≥10 tasks spread across ≥3 categories (bugfix / doc / feature). Each entry carries `task_id` + `category` + `cost_class` + `provenance` (file path or "synthetic") + `rationale`.
  - Check: `bash tools/verify/p00-corpus-manifest-shape.sh`

- The corpus directory `tests/m031-acceptance/fixtures/empirical-baseline/` contains exactly 20 task-fixture inputs (`task-NN.txt` or equivalent), each referenced by `task_id` in `CORPUS-MANIFEST.md` and each readable by `pre-m031-stub.sh`.
  - Check: `bash tools/verify/p00-corpus-population.sh`

- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` exists, is executable, and freezes the pre-M031 dispatch path semantics — when invoked with a task fixture path, it emits exactly one JSONL line on stdout matching the schema `{"task_id":"<id>","path":"pre-m031","knowledge_section_tokens":0,"compression_applied":false,"snip_applied":false,"total_task_tokens":<int>,"verifier_pass":<bool>}`. The stub MUST NOT call `scripts/dispatch/build-context.sh` (the P01 surface) — pre-M031 by definition skips it. The stub is the AD-14 frozen capture that survives FR-4's removal of the live skip branch.
  - Check: `bash tools/verify/p00-pre-stub-shape.sh`

- `references/RUNTIME-ASSUMPTIONS.md` documents the [M018](../../../../milestones/M018/index.md) tier-1 inline_threshold_tokens default value (`1500` per `templates/orchestrator-config-default.yml:87` as of P00 plan time), names the consuming SC (SC-3 amended per AD-17 — fixture must construct a payload exceeding this threshold), and notes the source-of-truth resolution path (`compression.tier1.inline_threshold_tokens` in the active orchestrator config).
  - Check: `bash tools/verify/p00-runtime-assumptions-foldin.sh`

- `templates/orchestrator-config-default.yml` declares the three M031 knobs with the P00 pinned defaults: `quick_knowledge_token_budget: 800` (FR-5 / AD-5), `entry_routing_confidence_floor: 0.7` (FR-11 / OQ-4), `tier_a_plus_prompt_summary_lines: 8` (AD-20). Each knob has an inline comment naming the M031 FR or AD that owns it.
  - Check: `bash tools/verify/p00-config-defaults-pinned.sh`

- `tests/m031-acceptance/empirical-baseline.sh` exists, is executable, and is the FR-18 harness: when invoked it iterates the 20 corpus tasks, runs `pre-m031-stub.sh` against each, appends one JSONL record per task to `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl`, and exits 0 if all 20 records emit cleanly. The harness reads the post-M031 emission path from `--post-m031-emitter <path>` (defaulting to a non-existent path that triggers a clean "post-M031 capture not yet available" notice) so P01's first task can plug in the real post-M031 path without harness rework.
  - Check: `bash tools/verify/p00-baseline-harness-shape.sh`

- `tests/m031-acceptance/verify-baseline-ordering.sh` exists per AD-12 / SC-13 (renumbered) — it asserts the first commit touching `tests/m031-acceptance/fixtures/empirical-baseline/` predates the first commit touching `scripts/dispatch/build-context.sh` and `commands/dispatch.md` (the FR-2 and FR-4 surfaces). The verifier prefers Option B (`git log --diff-filter=A --follow` on each path) and falls back to Option A (a documented protocol-note exit code) when `git log` is unavailable (shallow clone). The active option is recorded in `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` based on observed CI environment.
  - Check: `bash tools/verify/p00-ordering-verifier-shape.sh`

- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl` exists with exactly 20 JSONL records (one per corpus task), each carrying the pre-M031 schema (`path: "pre-m031"`, `knowledge_section_tokens: 0`). This is the AD-14 single-window capture: the records are committed at P00 close and never regenerated.
  - Check: `bash tools/verify/p00-pre-baseline-jsonl-population.sh`

- `tools/verify/p00-phase-suite.sh` invokes all eight P00 gates (spec-foldin-shape, corpus-manifest-shape, corpus-population, pre-stub-shape, runtime-assumptions-foldin, config-defaults-pinned, baseline-harness-shape, ordering-verifier-shape, pre-baseline-jsonl-population) in order, exits 0 iff every sub-gate passes, and emits a single line `SUMMARY: p00-phase-suite.sh pass=N fail=M` before exit.
  - Check: `bash tools/verify/p00-phase-suite.sh`

### Artifacts

- `specs/034-right-sized-entry/spec.md` (min 250 lines, contains "AD-1.", contains "AD-20.", contains "SC-15", contains "SC-16", contains "N ≥ 15") — modify
- `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md` (min 80 lines, contains "schema_version", contains "type: empirical-baseline-corpus", contains "AD-15", contains "stratification", contains "historical", contains "synthetic") — create
- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` (min 30 lines, contains "pre-m031", contains "knowledge_section_tokens", contains "task_id") — create
- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl` (min 20 lines, contains "pre-m031", contains "knowledge_section_tokens") — create
- `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` (min 15 lines, contains "Option A", contains "Option B", contains "selected") — create
- `tests/m031-acceptance/empirical-baseline.sh` (min 50 lines, contains "FR-18", contains "pre-m031-stub", contains "pre-m031-baseline.jsonl", contains "post-m031-emitter") — create
- `tests/m031-acceptance/verify-baseline-ordering.sh` (min 40 lines, contains "AD-12", contains "build-context.sh", contains "dispatch.md", contains "git log") — create
- `references/RUNTIME-ASSUMPTIONS.md` (min existing-baseline+15 lines, contains "M018 tier-1", contains "inline_threshold_tokens", contains "1500", contains "AD-17") — modify
- `templates/orchestrator-config-default.yml` (min existing-baseline+10 lines, contains "quick_knowledge_token_budget: 800", contains "entry_routing_confidence_floor: 0.7", contains "tier_a_plus_prompt_summary_lines: 8") — modify
- `tools/verify/p00-spec-foldin-shape.sh` (min 40 lines, contains "AD-1", contains "AD-20", contains "SC-15", contains "SC-16") — create
- `tools/verify/p00-corpus-manifest-shape.sh` (min 40 lines, contains "schema_version", contains "stratification", contains "historical", contains "synthetic") — create
- `tools/verify/p00-corpus-population.sh` (min 25 lines, contains "task-", contains "20") — create
- `tools/verify/p00-pre-stub-shape.sh` (min 25 lines, contains "pre-m031", contains "knowledge_section_tokens", contains "executable") — create
- `tools/verify/p00-runtime-assumptions-foldin.sh` (min 25 lines, contains "M018 tier-1", contains "inline_threshold_tokens") — create
- `tools/verify/p00-config-defaults-pinned.sh` (min 30 lines, contains "quick_knowledge_token_budget", contains "entry_routing_confidence_floor", contains "tier_a_plus_prompt_summary_lines") — create
- `tools/verify/p00-baseline-harness-shape.sh` (min 30 lines, contains "empirical-baseline.sh", contains "FR-18", contains "post-m031-emitter") — create
- `tools/verify/p00-ordering-verifier-shape.sh` (min 30 lines, contains "verify-baseline-ordering.sh", contains "git log", contains "Option") — create
- `tools/verify/p00-pre-baseline-jsonl-population.sh` (min 25 lines, contains "pre-m031-baseline.jsonl", contains "20") — create
- `tools/verify/p00-phase-suite.sh` (min 35 lines, contains "SUMMARY:", contains "p00-spec-foldin-shape", contains "p00-corpus-manifest-shape", contains "p00-pre-stub-shape", contains "p00-baseline-harness-shape", contains "p00-phase-suite") — create

### Key Links

- `specs/034-right-sized-entry/spec.md` → [`.orchestrator/milestones/M031/M031-CONTEXT.md`](../../../../milestones/M031/M031-CONTEXT.md) (folded AD bodies preserve their CONTEXT.md provenance via inline citation; the audit trail allows future readers to trace AD-N to the originating context-draft block)
- `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md` → `specs/034-right-sized-entry/spec.md` (AD-15's stratification requirement is the manifest's normative source)
- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` → `commands/dispatch.md` (the stub freezes the pre-FR-4 Quick-skip semantics from `commands/dispatch.md:21`)
- `references/RUNTIME-ASSUMPTIONS.md` → `templates/orchestrator-config-default.yml` (RUNTIME-ASSUMPTIONS documents the inline_threshold_tokens value sourced from the config template)
- `tests/m031-acceptance/empirical-baseline.sh` → `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` (harness invokes stub once per corpus task)
- `tests/m031-acceptance/verify-baseline-ordering.sh` → `scripts/dispatch/build-context.sh` (ordering check asserts corpus-commit precedes build-context.sh-modification commit)
- `tools/verify/p00-phase-suite.sh` → `tools/verify/p00-spec-foldin-shape.sh` (suite invokes spec-foldin gate)
- `tools/verify/p00-phase-suite.sh` → `tools/verify/p00-pre-stub-shape.sh` (suite invokes pre-stub gate)
- `tools/verify/p00-phase-suite.sh` → `tools/verify/p00-baseline-harness-shape.sh` (suite invokes harness-shape gate)

## Tasks

### T01: Spec-body fold-in (AD-1..AD-20 → spec.md)

See `tasks/T01-spec-foldin-PLAN.md`.

### T02: Corpus authorship + pre-M031 stub + RUNTIME-ASSUMPTIONS + pinned defaults

See `tasks/T02-corpus-and-defaults-PLAN.md`.

### T03: Empirical-baseline harness + ordering verifier + pre-baseline JSONL capture + phase suite

See `tasks/T03-harness-and-suite-PLAN.md`.

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03
```

Linear chain. T01 folds AD-1..AD-20 into spec.md so T02 + T03 reference the canonical SC numbers (SC-15, SC-16) and the renumbered SC-13 by name. T02 builds the 20-task corpus + manifest + pre-M031 stub + RUNTIME-ASSUMPTIONS update + pinned config defaults. T03 builds the empirical-baseline.sh harness + verify-baseline-ordering.sh + captures the pre-M031 baseline JSONL into `pre-m031-baseline.jsonl` + ships the `p00-phase-suite.sh` aggregator.

The chain is strict: T03's harness reads T02's `pre-m031-stub.sh`; T02's manifest references the SC vocabulary that T01 pins; T01 has no upstream and runs first.

## Files Likely Touched

- `specs/034-right-sized-entry/spec.md` (modify)
- `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md` (create)
- `tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt` through `task-20.txt` (create — 20 fixture inputs)
- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` (create)
- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl` (create)
- `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` (create)
- `tests/m031-acceptance/empirical-baseline.sh` (create)
- `tests/m031-acceptance/verify-baseline-ordering.sh` (create)
- `references/RUNTIME-ASSUMPTIONS.md` (modify)
- `templates/orchestrator-config-default.yml` (modify)
- `tools/verify/p00-spec-foldin-shape.sh` (create)
- `tools/verify/p00-corpus-manifest-shape.sh` (create)
- `tools/verify/p00-corpus-population.sh` (create)
- `tools/verify/p00-pre-stub-shape.sh` (create)
- `tools/verify/p00-runtime-assumptions-foldin.sh` (create)
- `tools/verify/p00-config-defaults-pinned.sh` (create)
- `tools/verify/p00-baseline-harness-shape.sh` (create)
- `tools/verify/p00-ordering-verifier-shape.sh` (create)
- `tools/verify/p00-pre-baseline-jsonl-population.sh` (create)
- `tools/verify/p00-phase-suite.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-3]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. -->
