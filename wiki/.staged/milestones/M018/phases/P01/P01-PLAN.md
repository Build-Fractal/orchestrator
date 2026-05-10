---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M018"
goal: "Ship a versioned tier-by-tier compression grammar contract, a clean-passing lint verifier, a RUNTIME-ASSUMPTIONS entry covering compression-grammar runtime expectations, and a PASS verdict from the conversus --strict gate against the contract before phase close."
demo_sentence: "Operator opens references/compression-grammar.md and sees per-tier preserves/applies-to blocks plus the marker grammar; runs scripts/verify/compression-grammar-lint.sh and gets PASS; opens .orchestrator/milestones/M018/phases/P01/conversus/gate-result.md and sees verdict: PASS."
risk: "high"
depends_on: ["P00"]
---

## Must-Haves

### Truths

<!-- Per AD-19, every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(... | ...). -->

- `references/compression-grammar.md` exists with a versioned per-tier contract — every tier section (filter, tier1, tier2, tier3) carries an `applies-to:` block enumerating artifact classes and a `preserves:` block enumerating byte-pattern regexes; the marker grammar `<!-- compressed:tierN ... -->` is documented; the additive emitter-schema invariant (CON-5) is stated verbatim.
  - Check: `bash scripts/verify/m018-p01-grammar-shape.sh`
- `scripts/verify/compression-grammar-lint.sh` parses the grammar contract and exits 0; rejects any tier section missing `applies-to:` or `preserves:`; emits one PASS line per (tier, artifact-class, preserved-pattern) triple.
  - Check: `bash scripts/verify/m018-p01-lint-clean.sh`
- The grammar contract defends against the SC-9 calibrated 34.7% floor by naming, in-document, the per-tier modeling assumptions from P00's probe (filter ≈ 13%, tier1 ≈ 6.3%, tier2 ≈ 25.5%, tier3 ≈ 12.2%) and the aggregate target ≥ 34.7% so reviewers can dispute the assumptions on paper rather than after tier code lands.
  - Check: `bash scripts/verify/m018-p01-sc9-traceability.sh`
- `RUNTIME-ASSUMPTIONS.md` carries an `## M018/P01: <name>` entry with the four required subsections (Claude Code assumption, Codex/Cursor fallback, Milestone/phase, M009 obligation) describing the compression-grammar runtime expectations (zero-LLM tiers byte-identical across runtimes; Tier 3 LLM call routes through dispatch-interface.sh).
  - Check: `bash scripts/verify/m018-p01-runtime-assumptions.sh`
- [`.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md`](../../../../milestones/M018/phases/P01/conversus/gate-result.md) exists with frontmatter `verdict: "PASS"`; the conversus `--strict` gate ran against `references/compression-grammar.md` using a preset that exercises the red/blue advocate model.
  - Check: `bash scripts/verify/m018-p01-conversus-pass.sh`
- CLAUDE.md and AGENTS.md `recent-changes` block both name M018/P01 grammar-contract close (dual-write produced via `scripts/util/dual-write-runtime-md.sh` — never edit AGENTS.md directly).
  - Check: `bash scripts/verify/m018-p01-dual-write-recent.sh`

### Artifacts

- `references/compression-grammar.md` (min 200 lines, contains "preserves:")
- `scripts/verify/compression-grammar-lint.sh` (min 80 lines, contains "applies-to")
- `scripts/verify/m018-p01-grammar-shape.sh` (min 30 lines, contains "marker grammar")
- `scripts/verify/m018-p01-lint-clean.sh` (min 20 lines, contains "compression-grammar-lint")
- `scripts/verify/m018-p01-sc9-traceability.sh` (min 20 lines, contains "34.7")
- `scripts/verify/m018-p01-runtime-assumptions.sh` (min 20 lines, contains "M018/P01")
- `scripts/verify/m018-p01-conversus-pass.sh` (min 20 lines, contains "verdict")
- `scripts/verify/m018-p01-dual-write-recent.sh` (min 20 lines, contains "M018/P01")
- `templates/conversus-presets/compression-grammar.yml` (min 50 lines, contains "red-advocate")
- [`.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md`](../../../../milestones/M018/phases/P01/conversus/gate-result.md) (min 5 lines, contains "PASS")
- `RUNTIME-ASSUMPTIONS.md` (min 60 lines, contains "M018/P01")
- [`.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md`](../../../../milestones/M018/phases/P01/P01-SUMMARY.md) (min 40 lines, contains "PASS")

### Key Links

- [`.orchestrator/milestones/M018/phases/P01/P01-PLAN.md`](../../../../milestones/M018/phases/P01/P01-PLAN.md) → [`.orchestrator/milestones/M018/M018-ROADMAP.md`](../../../../milestones/M018/M018-ROADMAP.md)
- [`.orchestrator/milestones/M018/phases/P01/P01-PLAN.md`](../../../../milestones/M018/phases/P01/P01-PLAN.md) → `specs/030-context-compression-layer/spec.md`
- `references/compression-grammar.md` → `.orchestrator/scratch/m018-section-distribution-output.json`
- `scripts/verify/compression-grammar-lint.sh` → `references/compression-grammar.md`
- [`.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md`](../../../../milestones/M018/phases/P01/conversus/gate-result.md) → `references/compression-grammar.md`
- `RUNTIME-ASSUMPTIONS.md` → `references/compression-grammar.md`

## Tasks

### T01: Author the compression-grammar contract

See [`.orchestrator/milestones/M018/phases/P01/tasks/T01-grammar-contract-PLAN.md`](../../../../milestones/M018/phases/P01/tasks/T01-grammar-contract-PLAN.md).

### T02: Lint script + RUNTIME-ASSUMPTIONS entry + dual-write recent-changes

See [`.orchestrator/milestones/M018/phases/P01/tasks/T02-lint-and-runtime-PLAN.md`](../../../../milestones/M018/phases/P01/tasks/T02-lint-and-runtime-PLAN.md).

### T03: Conversus --strict gate run + archive + P01 summary

See [`.orchestrator/milestones/M018/phases/P01/tasks/T03-conversus-gate-PLAN.md`](../../../../milestones/M018/phases/P01/tasks/T03-conversus-gate-PLAN.md).

## Task Dependencies

```
T01 ──► T02 ──► T03
```

T01 ships the grammar document. T02 ships the verifiers (including the lint script that parses T01's output) plus the RUNTIME-ASSUMPTIONS row and the CLAUDE.md/AGENTS.md `recent-changes` refresh. T03 runs the conversus `--strict` gate against T01's contract, archives the result under `.orchestrator/milestones/M018/phases/P01/conversus/`, requires PASS, and writes P01-SUMMARY.md.

## Files Likely Touched

- `references/compression-grammar.md` (create — T01)
- `scripts/verify/compression-grammar-lint.sh` (create — T02)
- `scripts/verify/m018-p01-grammar-shape.sh` (create — T02)
- `scripts/verify/m018-p01-lint-clean.sh` (create — T02)
- `scripts/verify/m018-p01-sc9-traceability.sh` (create — T02)
- `scripts/verify/m018-p01-runtime-assumptions.sh` (create — T02)
- `scripts/verify/m018-p01-conversus-pass.sh` (create — T03)
- `scripts/verify/m018-p01-dual-write-recent.sh` (create — T02)
- `templates/conversus-presets/compression-grammar.yml` (create — T03)
- `RUNTIME-ASSUMPTIONS.md` (modify — T02 appends M018/P01 entry)
- `CLAUDE.md` (modify — T02 refreshes `orchestrator:recent-changes` block)
- `AGENTS.md` (modify — T02 via `scripts/util/dual-write-runtime-md.sh`; never edited directly)
- `.orchestrator/milestones/M018/phases/P01/conversus/conversus.yml` (create — T03 via conversus adapter)
- [`.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md`](../../../../milestones/M018/phases/P01/conversus/gate-result.md) (create — T03)
- [`.orchestrator/milestones/M018/phases/P01/conversus/summary/final.md`](../../../../milestones/M018/phases/P01/conversus/summary/final.md) (create — T03 via conversus adapter)
- [`.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md`](../../../../milestones/M018/phases/P01/P01-SUMMARY.md) (create — T03)
