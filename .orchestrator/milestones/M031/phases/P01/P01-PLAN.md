---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M031"
goal: "Make knowledge + M018 compression unconditional for Quick-intensity dispatches: extend scripts/dispatch/build-context.sh with a --profile=quick|standard|full flag (touched-files-only / phase / milestone-plus-deps scope; 1-hop / 2-hop / full provenance traversal; per-profile Decisions + glossary policy) and a --meta-out <file> JSON sidecar (FR-2 + AD-11); add the quick_knowledge_token_budget knob to templates/orchestrator-config-default.yml (FR-5 / AD-5; default 800 per P00); wire empirical-baseline.sh's --post-m031-emitter to a Quick-profile wrapper that captures the post-M031 baseline JSONL while the pre-FR-4 skip branch is still live (AD-14 single-window discipline); only THEN amend commands/dispatch.md:21 to remove the 'Skip payload assembly' Quick branch and replace it with 'knowledge + compression with the Quick profile' (FR-4); ship the SC-1 / SC-2 / SC-3 / SC-15 acceptance tests under tests/m031-acceptance/ and the P01 phase-suite verifier set under tools/verify/m031-p01-*.sh aggregated by tools/verify/m031-p01-phase-suite.sh."
demo_sentence: "An operator runs `bash scripts/dispatch/build-context.sh --profile=quick --task-plan tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt --out /tmp/payload.md --meta-out /tmp/meta.json` and observes (a) /tmp/payload.md contains a Knowledge section with 1-hop touched-file hits and no Decisions section, (b) /tmp/meta.json is a valid JSON object with exactly the keys mem_count, total_tokens, profile, compression_applied, snip_applied (profile=quick); greps `Skip payload assembly` against commands/dispatch.md and observes zero matches; greps `Quick profile` against commands/dispatch.md and observes at least one match; runs `bash tests/m031-acceptance/test-quick-injects-knowledge.sh` (SC-1), `bash tests/m031-acceptance/test-build-context-profile.sh` (SC-2 per AD-13), `bash tests/m031-acceptance/test-compression-applies-to-quick.sh` (SC-3 per AD-17), `bash tests/m031-acceptance/test-quick-budget-median.sh` (SC-15 per AD-18) and observes exit 0 from each; runs `bash tools/verify/m031-p01-phase-suite.sh` and observes `SUMMARY: m031-p01-phase-suite.sh pass=N fail=0`; observes that tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl exists with exactly 20 records carrying `path: \"post-m031\"` and non-zero `knowledge_section_tokens`."
risk: "high"
depends_on: ["P00"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m031-p01-*` prefix avoids collision with M030's
     existing `p01-*` verifiers in the shared tools/verify/ tree. -->

### Truths

- `scripts/dispatch/build-context.sh` accepts `--profile=quick|standard|full` and `--meta-out <file>` flags (FR-2 + AD-11). The Quick profile sets scope to touched-files-only, traversal to 1-hop direct hits, no Decisions section, and a glossary slice over touched terms only. Standard sets phase scope, 2-hop traversal, phase-relevant Decisions, phase-touched glossary. Full sets milestone-plus-dependencies scope, full provenance traversal, all milestone Decisions, full glossary. The `--meta-out` flag writes a JSON sidecar with the minimum schema `{mem_count, total_tokens, profile, compression_applied, snip_applied}` per AD-11.
  - Check: `bash tools/verify/m031-p01-build-context-profile-shape.sh`

- The Quick profile path runs `build-context.sh` end-to-end (CON-1 invariant — every dispatch path emits a `payload_breakdown` JSONL record). There is NO "skip context" exit; only "scope it tighter" via `--profile=quick`. Knowledge-section assembly, M018 tier-1 paging, and M018 tier-2 snip all participate when their respective config tiers are enabled (CON-2).
  - Check: `bash tools/verify/m031-p01-quick-no-skip-branch.sh`

- `templates/orchestrator-config-default.yml` is unchanged with respect to the three P00 knobs (`quick_knowledge_token_budget: 800`, `entry_routing_confidence_floor: 0.7`, `tier_a_plus_prompt_summary_lines: 8`); P01 does NOT re-declare or modify these knobs. The `quick_knowledge_token_budget` is the advisory ceiling that M018 tier-2 snip enforces per FR-5 + AD-13. (P01 reads the knob; it does not write it. P00 owns the write.)
  - Check: `bash tools/verify/m031-p01-config-knobs-stable.sh`

- `commands/dispatch.md` no longer contains the literal phrase "Skip payload assembly" anywhere in the file (FR-4). The Quick row of the intensity table reads "Full payload assembly via `build-context.sh --profile=quick` (touched-files-only scope, 1-hop traversal, no Decisions, glossary slice over touched terms only). Knowledge + M018 compression apply unconditionally per CON-1." or equivalent prose containing the literal token "Quick profile" (FR-4 verbatim contract).
  - Check: `bash tools/verify/m031-p01-dispatch-md-reconciliation.sh`

- `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl` exists with exactly 20 JSONL records (one per corpus task), each carrying `path: "post-m031"` and a non-zero `knowledge_section_tokens` field. The capture happened by running `bash tests/m031-acceptance/empirical-baseline.sh --post-m031-emitter <wrapper>` BEFORE the FR-4 amendment to commands/dispatch.md landed (AD-14 single-window discipline). The post-M031 emitter wrapper script is `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh` and invokes `build-context.sh --profile=quick` against each corpus task.
  - Check: `bash tools/verify/m031-p01-post-baseline-jsonl-population.sh`

- `tests/m031-acceptance/test-quick-injects-knowledge.sh` (SC-1) exists, is executable, and exits 0 against a freshly-assembled Quick-profile payload. Asserts: the assembled payload's manifest shows non-zero `knowledge_section_tokens` and either non-zero `tier1_replacements` or an empty-cache-hit record in the JSONL `payload_breakdown` stream.
  - Check: `bash tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh`

- `tests/m031-acceptance/test-build-context-profile.sh` (SC-2 per AD-13) exists, is executable, and exits 0. Asserts: against a Quick-profile payload constructed to exceed `quick_knowledge_token_budget` from a fixture under `tests/m031-acceptance/fixtures/empirical-baseline/`, (a) a tier-2 snip JSONL record is emitted at the budget boundary AND (b) the final Knowledge section in the assembled payload is ≤ `quick_knowledge_token_budget` tokens. The SC has NO ±20% tolerance clause (AD-13 dropped it).
  - Check: `bash tools/verify/m031-p01-test-build-context-profile-shape.sh`

- `tests/m031-acceptance/test-compression-applies-to-quick.sh` (SC-3 per AD-17) exists, is executable, and exits 0. The fixture explicitly constructs a Quick-profile payload exceeding the M018 tier-1 `inline_threshold_tokens` value documented in `references/RUNTIME-ASSUMPTIONS.md` (1500 tokens per P00). Asserts: tier-1 paging records AND tier-2 snip records appear in the JSONL stream when the constructed payload meets the threshold. The fixture is prescriptive (constructs a payload that meets the threshold); it does not vacuously pass at sub-threshold sizes.
  - Check: `bash tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh`

- `tests/m031-acceptance/test-quick-budget-median.sh` (SC-15 per AD-18) exists, is executable, and exits 0. Asserts: median `knowledge_section_tokens` emitted by `build-context.sh --profile=quick` across the 20-task P00 corpus (`tests/m031-acceptance/fixtures/empirical-baseline/task-NN.txt`) is ≤ `quick_knowledge_token_budget` (800 per P00). This is the absolute median compliance check — independent of the pre-M031 baseline (SC-11 covers the relative comparison).
  - Check: `bash tools/verify/m031-p01-test-quick-budget-median-shape.sh`

- `tools/verify/m031-p01-phase-suite.sh` exists, is executable, and invokes every P01 gate in order, exits 0 iff every sub-gate passes, and emits a single line `SUMMARY: m031-p01-phase-suite.sh pass=N fail=M` before exit. The suite includes (in order): `m031-p01-build-context-profile-shape.sh`, `m031-p01-quick-no-skip-branch.sh`, `m031-p01-config-knobs-stable.sh`, `m031-p01-dispatch-md-reconciliation.sh`, `m031-p01-post-baseline-jsonl-population.sh`, `m031-p01-test-quick-injects-knowledge-shape.sh`, `m031-p01-test-build-context-profile-shape.sh`, `m031-p01-test-compression-applies-to-quick-shape.sh`, `m031-p01-test-quick-budget-median-shape.sh`. (Nine sub-gates plus the suite line.)
  - Check: `bash tools/verify/m031-p01-phase-suite.sh`

- The SC-12 scope-guard invariant holds for the P01 diff: P01 modifies only files declared in this phase's "Files Likely Touched" list. None of `knowledge/**` schema files, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/` are touched.
  - Check: `bash tools/verify/m031-p01-scope-guard.sh`

### Artifacts

- `scripts/dispatch/build-context.sh` (min existing-baseline+40 lines, contains "--profile", contains "--meta-out", contains "quick", contains "1-hop", contains "mem_count", contains "compression_applied") — modify
- `commands/dispatch.md` (min existing-baseline-3 lines accounting for FR-4 deletion, MUST NOT contain "Skip payload assembly", contains "Quick profile") — modify
- `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh` (min 25 lines, contains "build-context.sh", contains "--profile=quick", contains "post-m031", contains "knowledge_section_tokens") — create
- `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl` (min 20 lines, contains "post-m031", contains "knowledge_section_tokens") — create
- `tests/m031-acceptance/test-quick-injects-knowledge.sh` (min 30 lines, contains "SC-1", contains "knowledge_section_tokens", contains "payload_breakdown") — create
- `tests/m031-acceptance/test-build-context-profile.sh` (min 35 lines, contains "SC-2", contains "AD-13", contains "tier-2 snip", contains "quick_knowledge_token_budget") — create
- `tests/m031-acceptance/test-compression-applies-to-quick.sh` (min 35 lines, contains "SC-3", contains "AD-17", contains "inline_threshold_tokens", contains "1500") — create
- `tests/m031-acceptance/test-quick-budget-median.sh` (min 35 lines, contains "SC-15", contains "AD-18", contains "median", contains "quick_knowledge_token_budget") — create
- `tools/verify/m031-p01-build-context-profile-shape.sh` (min 35 lines, contains "--profile", contains "--meta-out", contains "quick", contains "mem_count") — create
- `tools/verify/m031-p01-quick-no-skip-branch.sh` (min 25 lines, contains "Skip payload", contains "build-context.sh") — create
- `tools/verify/m031-p01-config-knobs-stable.sh` (min 30 lines, contains "quick_knowledge_token_budget", contains "entry_routing_confidence_floor", contains "tier_a_plus_prompt_summary_lines") — create
- `tools/verify/m031-p01-dispatch-md-reconciliation.sh` (min 25 lines, contains "Skip payload assembly", contains "Quick profile", contains "FR-4") — create
- `tools/verify/m031-p01-post-baseline-jsonl-population.sh` (min 25 lines, contains "post-m031-baseline.jsonl", contains "post-m031", contains "20") — create
- `tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh` (min 25 lines, contains "test-quick-injects-knowledge.sh", contains "SC-1") — create
- `tools/verify/m031-p01-test-build-context-profile-shape.sh` (min 25 lines, contains "test-build-context-profile.sh", contains "SC-2", contains "AD-13") — create
- `tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh` (min 25 lines, contains "test-compression-applies-to-quick.sh", contains "SC-3", contains "AD-17") — create
- `tools/verify/m031-p01-test-quick-budget-median-shape.sh` (min 25 lines, contains "test-quick-budget-median.sh", contains "SC-15", contains "AD-18") — create
- `tools/verify/m031-p01-phase-suite.sh` (min 40 lines, contains "SUMMARY:", contains "m031-p01-build-context-profile-shape", contains "m031-p01-quick-no-skip-branch", contains "m031-p01-dispatch-md-reconciliation", contains "m031-p01-phase-suite") — create
- `tools/verify/m031-p01-scope-guard.sh` (min 30 lines, contains "knowledge/", contains "scripts/cost", contains "scripts/dispatch/adapters/router", contains "scripts/auto/loop", contains "SC-12") — create

### Key Links

- `scripts/dispatch/build-context.sh` → `templates/orchestrator-config-default.yml` (the `--profile=quick` traversal aggressiveness reads `quick_knowledge_token_budget` from the active config; basename appears in build-context.sh prose)
- `scripts/dispatch/build-context.sh` → `references/RUNTIME-ASSUMPTIONS.md` (M018 tier-1 `inline_threshold_tokens` value documented at P00; build-context.sh references the consuming SC-3 + the resolution path)
- `commands/dispatch.md` → `scripts/dispatch/build-context.sh` (FR-4 reconciliation: Quick branch invokes build-context.sh with `--profile=quick` instead of skipping)
- `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh` → `scripts/dispatch/build-context.sh` (the post-M031 emitter wrapper invokes build-context.sh `--profile=quick`)
- `tests/m031-acceptance/test-quick-injects-knowledge.sh` → `scripts/dispatch/build-context.sh` (SC-1 fixture invokes build-context.sh with `--profile=quick` and asserts knowledge inject)
- `tests/m031-acceptance/test-build-context-profile.sh` → `templates/orchestrator-config-default.yml` (SC-2 reads `quick_knowledge_token_budget` from the active config to compute the budget boundary)
- `tests/m031-acceptance/test-compression-applies-to-quick.sh` → `references/RUNTIME-ASSUMPTIONS.md` (SC-3 fixture constructs a payload exceeding the M018 tier-1 threshold value documented at P00)
- `tests/m031-acceptance/test-quick-budget-median.sh` → `tests/m031-acceptance/fixtures/empirical-baseline/` (SC-15 reads the 20-task corpus to compute median knowledge_section_tokens)
- `tools/verify/m031-p01-phase-suite.sh` → `tools/verify/m031-p01-build-context-profile-shape.sh` (suite invokes build-context profile shape gate)
- `tools/verify/m031-p01-phase-suite.sh` → `tools/verify/m031-p01-dispatch-md-reconciliation.sh` (suite invokes dispatch.md FR-4 reconciliation gate)
- `tools/verify/m031-p01-phase-suite.sh` → `tools/verify/m031-p01-post-baseline-jsonl-population.sh` (suite invokes post-baseline JSONL gate)

## Tasks

### T01: build-context.sh `--profile` + `--meta-out` (FR-2 + AD-11) — additive surface, no skip-branch removal yet

See `tasks/T01-build-context-profile-PLAN.md`.

T01 is the load-bearing edit. It extends `scripts/dispatch/build-context.sh` with the `--profile=quick|standard|full` flag and the `--meta-out <file>` JSON sidecar. Crucially T01 does NOT touch `commands/dispatch.md` — the live Quick-skip branch in `commands/dispatch.md:21` MUST stay live until T02 captures the post-M031 baseline JSONL (AD-14 single-window discipline). T01 ships the `m031-p01-build-context-profile-shape.sh` + `m031-p01-quick-no-skip-branch.sh` + `m031-p01-config-knobs-stable.sh` verifiers under `tools/verify/`.

### T02: AD-14 post-M031 capture + FR-4 reconciliation of `commands/dispatch.md:21`

See `tasks/T02-ad14-capture-and-fr4-PLAN.md`.

T02 wires the post-M031 emitter wrapper at `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh` (calls T01's `build-context.sh --profile=quick` against each corpus task), runs `tests/m031-acceptance/empirical-baseline.sh --post-m031-emitter <wrapper>` to capture exactly 20 records into `post-m031-baseline.jsonl`, AND ONLY THEN amends `commands/dispatch.md:21` to remove the "Skip payload assembly" Quick branch and replace it with the FR-4 canonical Quick-profile language. The order is normative and gated by the pre-condition that the new `post-m031-baseline.jsonl` exists with 20 records before the amendment lands. Ships `m031-p01-post-baseline-jsonl-population.sh` + `m031-p01-dispatch-md-reconciliation.sh` verifiers.

### T03: SC-1 / SC-2 / SC-3 / SC-15 acceptance tests

See `tasks/T03-acceptance-tests-PLAN.md`.

T03 ships the four SC acceptance scripts under `tests/m031-acceptance/` (test-quick-injects-knowledge.sh, test-build-context-profile.sh, test-compression-applies-to-quick.sh, test-quick-budget-median.sh) and their corresponding shape verifiers under `tools/verify/m031-p01-*-shape.sh`. Each acceptance script invokes T01's amended `build-context.sh` and asserts the SC contracts verbatim from the spec (SC-1, SC-2 per AD-13, SC-3 per AD-17, SC-15 per AD-18).

### T04: P01 phase-suite aggregator + SC-12 scope-guard

See `tasks/T04-phase-suite-and-scope-guard-PLAN.md`.

T04 ships `tools/verify/m031-p01-phase-suite.sh` (chains all nine P01 gates straight-line, AD-19 compliant) and `tools/verify/m031-p01-scope-guard.sh` (SC-12 — asserts the P01 diff touches no path under `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`). The suite emits a single SUMMARY line with `pass=N fail=M`.

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03 ──▶ T04
```

Strict linear chain. T01 ships the additive `--profile` + `--meta-out` surface (no destructive edits). T02 depends on T01 because the post-M031 emitter wrapper invokes T01's amended `build-context.sh --profile=quick`. T02 captures the post-M031 baseline JSONL BEFORE amending `commands/dispatch.md:21` (AD-14 single-window: both code paths must be live during the capture window). T03 depends on T02 because the SC tests assert against the post-T02 system state (FR-4 reconciliation in dispatch.md). T04 depends on T03 because the phase-suite aggregator invokes the shape verifiers shipped alongside the SC tests in T03.

## Files Likely Touched

- `scripts/dispatch/build-context.sh` (modify)
- `commands/dispatch.md` (modify)
- `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh` (create)
- `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl` (create)
- `tests/m031-acceptance/test-quick-injects-knowledge.sh` (create)
- `tests/m031-acceptance/test-build-context-profile.sh` (create)
- `tests/m031-acceptance/test-compression-applies-to-quick.sh` (create)
- `tests/m031-acceptance/test-quick-budget-median.sh` (create)
- `tools/verify/m031-p01-build-context-profile-shape.sh` (create)
- `tools/verify/m031-p01-quick-no-skip-branch.sh` (create)
- `tools/verify/m031-p01-config-knobs-stable.sh` (create)
- `tools/verify/m031-p01-dispatch-md-reconciliation.sh` (create)
- `tools/verify/m031-p01-post-baseline-jsonl-population.sh` (create)
- `tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh` (create)
- `tools/verify/m031-p01-test-build-context-profile-shape.sh` (create)
- `tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh` (create)
- `tools/verify/m031-p01-test-quick-budget-median-shape.sh` (create)
- `tools/verify/m031-p01-phase-suite.sh` (create)
- `tools/verify/m031-p01-scope-guard.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-4]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. The post-m031-baseline.jsonl
     is technically WRITTEN by T02 invoking the harness (which emits the
     records), but the harness invocation is part of T02's Steps. -->
