---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M029"
goal: "Ship orchestrator:where at-rest tree renderer + cost column + cross-milestone data model + AD-9 sentinel mechanism, gated by SC-5/SC-6/SC-13/SC-14 acceptance + a five-task phase-suite aggregator."
demo_sentence: "A developer running orchestrator:where against the SC-5 mixed-state fixture sees a tree with the documented glyph set (✓ ▶ ◇ ✗ ▽), an M027-sourced per-row cost column, a milestone progress bar, and a byte-identical render against tests/m029-acceptance/fixtures/where-mixed-state.golden modulo the enumerated #Q-G6 timestamp patterns; a pre-M019 milestone renders without the cost column and without stderr noise; the SC-14 sentinel harness asserts no .orchestrator/ mutation across the read."
risk: "medium"
depends_on: ["P01"]
---

## Must-Haves

### Truths

<!-- Behavioral truths that scripts/verify/check-must-haves.sh checks via the bound script-file shape (AD-19). Every Check is a single bash <path> invocation; no inline compound, no plain subshell, no $() with pipes. Project-owned per-phase verifiers live under tools/verify/ with the m029-p02-* slug prefix; framework-owned verifiers live under scripts/verify/. -->

- The AD-6 cross-milestone data-model contract document exists at `references/cross-milestone-feature-shape.md` and pins the exactly-one-of `milestone:` ⊕ `milestones:` rule + reverse-lookup advisory + collapsed/expanded inactive-render shape (#Q-5 resolution).
  - Check: `bash tools/verify/m029-p02-cross-milestone-shape-contract.sh`

- `scripts/diagnostics/summarize-milestone.sh` exists, is executable, emits a fixed-order key=value block (`phase_count=...`, `phases_complete=...`, `tasks_remaining=...`, `intensity=...`) read-only against the active milestone, and accepts `--milestone <M###>` as the AD-4 SC-8 oracle interface.
  - Check: `bash tools/verify/m029-p02-summarize-milestone-shape.sh`

- `scripts/diagnostics/render-position.sh` exists, is executable, sources the AD-1 invocation-context resolver and emits a tree using the documented glyph set (`✓ ▶ ◇ ✗ ▽`) with milestone progress bar + per-row cost column, suppresses the cost column silently on pre-M019 milestones (FR-6/CON-3), and never invokes `gh` / GitHub APIs (FR-11/CON-4/SC-13).
  - Check: `bash tools/verify/m029-p02-render-position-shape.sh`

- `commands/where.md` exists with the canonical 8-section command-doc shape, declares read-only discipline (CON-1/FR-14), references `scripts/diagnostics/render-position.sh` + `scripts/state/detect-invocation-context.sh` + `references/cross-milestone-feature-shape.md`, and embeds the documented glyph legend.
  - Check: `bash tools/verify/m029-p02-where-skill-shape.sh`

- The SC-5 mixed-state golden fixture covers all four glyph states (`✓ ▶ ◇ ✗`) and is byte-stable under the #Q-G6 enumerated timestamp-strip regex set; `tests/m029-acceptance/timestamp-strip.sh` enumerates exactly the #Q-G6 patterns; the FR-8 marker canonical form `▽ saved Nk` (#Q-G8 resolution) is the only form that appears in fixtures and verifiers (no `▽ 4k saved` or `▽ saved Nk via tier1 cache reuse` strings anywhere in P02 deliverables).
  - Check: `bash tools/verify/m029-p02-sc5-fixtures-shape.sh`

- The SC-14 sentinel-file harness implements the AD-9 mechanism (write `.orchestrator/.m029-sc14-sentinel` immediately before the read; assert no `.orchestrator/` file other than the sentinel itself has an mtime newer than the sentinel after the read).
  - Check: `bash tools/verify/m029-p02-sentinel-harness-shape.sh`

- The SC-5 acceptance script renders `orchestrator:where` against the mixed-state fixture, normalizes the output via `timestamp-strip.sh`, and diffs against `where-mixed-state.golden` with exit 0.
  - Check: `bash tools/verify/m029-p02-sc5-shape.sh`

- The SC-6 acceptance script renders against the pre-M019 fixture and asserts the cost column is omitted AND stderr is empty (no warning).
  - Check: `bash tools/verify/m029-p02-sc6-shape.sh`

- The SC-13 anti-coupling guard asserts `grep -r '/integrations/github' specs/037-roadmap-visibility-cli-ux/ scripts/diagnostics/render-position.sh` returns no match in the headline rendering path (FR-11/CON-4 enforcement).
  - Check: `bash tools/verify/m029-p02-sc13-shape.sh`

- The SC-14 acceptance script wraps the sentinel harness around `orchestrator:where` against the mixed-state fixture and asserts the readonly invariant holds (no `.orchestrator/` mtime newer than the sentinel except the sentinel itself).
  - Check: `bash tools/verify/m029-p02-sc14-shape.sh`

- The P02 phase-suite aggregator chains all P02 gate verifiers (mirrors `m029-p01-phase-suite.sh` shape) and emits `SUMMARY: m029-p02-phase-suite.sh pass=N fail=0` on success; `validate-milestone.sh M029` will consume this suite alongside P01 and P03 phase-suites.
  - Check: `bash tools/verify/m029-p02-phase-suite.sh`

### Artifacts

- `references/cross-milestone-feature-shape.md` (min 50 lines, contains "milestones:")
- `scripts/diagnostics/summarize-milestone.sh` (min 60 lines, contains "phase_count=")
- `scripts/diagnostics/render-position.sh` (min 120 lines, contains "▶ ◇ ✓ ✗")
- `commands/where.md` (min 60 lines, contains "orchestrator:where")
- `tests/m029-acceptance/fixtures/where-mixed-state.golden` (min 10 lines, contains "▶")
- `tests/m029-acceptance/timestamp-strip.sh` (min 20 lines, contains "ago")
- `tests/m029-acceptance/sentinel-harness.sh` (min 30 lines, contains "m029-sc14-sentinel")
- `tests/m029-acceptance/p02-sc5-where-mixed-state.sh` (min 25 lines, contains "where-mixed-state.golden")
- `tests/m029-acceptance/p02-sc6-where-pre-m019.sh` (min 20 lines, contains "pre-m019")
- `tests/m029-acceptance/p02-sc13-anti-coupling.sh` (min 15 lines, contains "/integrations/github")
- `tests/m029-acceptance/p02-sc14-readonly.sh` (min 20 lines, contains "sentinel")
- `tests/m029-acceptance/p02-acceptance-battery.sh` (min 20 lines, contains "BATTERY:")
- `tools/verify/m029-p02-phase-suite.sh` (min 80 lines, contains "SUMMARY: m029-p02-phase-suite.sh")

### Key Links

- `commands/where.md` → `scripts/diagnostics/render-position.sh`
- `commands/where.md` → `scripts/state/detect-invocation-context.sh`
- `commands/where.md` → `references/cross-milestone-feature-shape.md`
- `scripts/diagnostics/render-position.sh` → `scripts/state/detect-invocation-context.sh`
- `scripts/diagnostics/render-position.sh` → `scripts/diagnostics/metrics-rollup.sh`
- `tests/m029-acceptance/p02-sc5-where-mixed-state.sh` → `tests/m029-acceptance/timestamp-strip.sh`
- `tests/m029-acceptance/p02-sc14-readonly.sh` → `tests/m029-acceptance/sentinel-harness.sh`
- `tools/verify/m029-p02-phase-suite.sh` → `tools/verify/m029-p02-render-position-shape.sh`

## Tasks

### T01: Cross-milestone data-model design contract + reverse-lookup advisory + shape verifier

See `tasks/T01-cross-milestone-data-model-PLAN.md`.

### T02: `summarize-milestone.sh` AD-4 oracle interface

See `tasks/T02-summarize-milestone-PLAN.md`.

### T03: `render-position.sh` + `commands/where.md` (FR-5, FR-6, CON-3, CON-4)

See `tasks/T03-render-position-and-where-skill-PLAN.md`.

### T04: SC-5/SC-6/SC-13/SC-14 fixtures + acceptance scripts + sentinel harness (AD-9, #Q-G6, #Q-G8)

See `tasks/T04-fixtures-and-sc-acceptance-PLAN.md`.

### T05: P02 close gates — phase-suite + acceptance battery + readonly-invariant + scope-guard

See `tasks/T05-phase-close-gates-PLAN.md`.

## Task Dependencies

```
T01 ──► T03 ──► T04 ──► T05
        ▲
T02 ────┘
```

- T01 (cross-milestone contract) must land first because T03's `render-position.sh` reads the contract for its frontmatter parsing rules.
- T02 (summarize-milestone helper) is independent of T01 but is consumed by T03's per-milestone summary lines on the tree; can run in parallel with T01.
- T03 depends on both T01 and T02; produces `render-position.sh` + `commands/where.md`.
- T04 depends on T03 (fixtures and acceptance scripts test the renderer T03 ships).
- T05 depends on T04 (phase-suite aggregator chains every prior verifier; battery wraps every prior SC acceptance script).

## Files Likely Touched

- `references/cross-milestone-feature-shape.md` (create)
- `scripts/diagnostics/summarize-milestone.sh` (create)
- `scripts/diagnostics/render-position.sh` (create)
- `commands/where.md` (create)
- `tests/m029-acceptance/fixtures/where-mixed-state.golden` (create)
- `tests/m029-acceptance/fixtures/where-mixed-state.fixture/` (create — directory tree containing milestones/M998/...)
- `tests/m029-acceptance/fixtures/where-pre-m019.fixture/` (create — directory tree containing milestones/M997/...)
- `tests/m029-acceptance/timestamp-strip.sh` (create)
- `tests/m029-acceptance/sentinel-harness.sh` (create)
- `tests/m029-acceptance/p02-sc5-where-mixed-state.sh` (create)
- `tests/m029-acceptance/p02-sc6-where-pre-m019.sh` (create)
- `tests/m029-acceptance/p02-sc13-anti-coupling.sh` (create)
- `tests/m029-acceptance/p02-sc14-readonly.sh` (create)
- `tests/m029-acceptance/p02-acceptance-battery.sh` (create)
- `tools/verify/m029-p02-cross-milestone-shape-contract.sh` (create)
- `tools/verify/m029-p02-summarize-milestone-shape.sh` (create)
- `tools/verify/m029-p02-render-position-shape.sh` (create)
- `tools/verify/m029-p02-where-skill-shape.sh` (create)
- `tools/verify/m029-p02-sc5-fixtures-shape.sh` (create)
- `tools/verify/m029-p02-sentinel-harness-shape.sh` (create)
- `tools/verify/m029-p02-sc5-shape.sh` (create)
- `tools/verify/m029-p02-sc6-shape.sh` (create)
- `tools/verify/m029-p02-sc13-shape.sh` (create)
- `tools/verify/m029-p02-sc14-shape.sh` (create)
- `tools/verify/m029-p02-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p02-readonly-invariant.sh` (create)
- `tools/verify/m029-p02-scope-guard.sh` (create)
- `tools/verify/m029-p02-phase-suite.sh` (create)
