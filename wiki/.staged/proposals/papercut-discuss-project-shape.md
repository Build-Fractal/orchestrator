# Paper-Cut Proposal: Project-Shape Classifier in `orchestrator:discuss`

**Captured**: 2026-05-04 from the GSD-2 adoption scan (`gsd-2-adoption-scan-2026-05-04.md` §3).
**Shape**: Single PR — amendment to `orchestrator:discuss` (`commands/discuss.md` + helper script + acceptance test). ~0.5–1 day.
**Sequencing**: Independent of [M033](../milestones/M033/index.md) / [M032](../milestones/M032/index.md) / [M029](../milestones/M029/index.md) — can land any time after M033 closes (which it has). Does not block any pre-launch milestone; does not require any pre-launch milestone.
**Source**: GSD v2.79 commit `91deb109` (`feat(discuss): scale questioning depth via project shape classifier`). One of 14 items in the parent scan.

## Goal

Have `orchestrator:discuss` emit a project-shape verdict (`simple | complex`) early in its flow, persist it to the active context-draft (or `.orchestrator/PROJECT.md`), and have downstream `discuss`-stage invocations read the verdict and adapt cadence.

## Why a paper-cut, not a milestone

Single command amendment + small helper + acceptance test. Discoverable in one PR. No new artifact types, no manifest changes, no observability extensions.

## What ships

### `commands/discuss.md` amendment

- After the initial scope-detection step, run a deterministic shape classifier (small set of heuristics: spec line count, requirement count, NFR count, downstream-dependency count, prior-discussion presence)
- Emit `## Project Shape: simple | complex` section into the active context-draft
- Persist verdict so subsequent `discuss` invocations read it without re-classifying

### Downstream cadence rules

Subsequent `discuss` invocations read the verdict and adjust:

| Verdict | Round count | Question style |
|---|---|---|
| `simple` | 1–2 plain-text rounds | Open-ended; skip deep-investigation gates |
| `complex` | Full grilling-protocol cadence | Structured questions with 3–4 *researched* options + "Other — let me discuss" escape hatch |

The `complex` rubric mirrors GSD's contract. Binary depth-check / wrap-up gates and class/status enumerations are exempt from the structured-question requirement.

### Acceptance test

Fixture pair: a `simple`-shape project (5 requirements, no NFRs, single phase) and a `complex`-shape project (50 requirements, 8 NFRs, multi-phase). Run `orchestrator:discuss` against each; assert verdict matches expectation; assert downstream invocation reads cached verdict.

## Why independent of any milestone

This composes with M033 (which has already authored the four-branch onboarding flow) but doesn't need M033 to ship. M033's `start` flow could optionally consume the verdict, but the value lands without that integration — `orchestrator:discuss` itself becomes more cadence-aware on day one. M029 doesn't touch `discuss`. M032 doesn't touch `discuss`. The amendment stands alone.

## Composition with existing axes

We already have:
- **Tier A/B/C** from `orchestrator:evaluate` (project-scope tier)
- **Quick/Standard/Full** from [M031](../milestones/M031/index.md) (per-task intensity profile)

Project-shape adds a third axis specifically for **discuss-cadence**. The three compose:
- Tier C + complex shape → full grilling protocol, structured options required
- Tier C + simple shape → light grilling, plain-text rounds
- Tier A + simple shape → degenerate path (M031's existing Tier A flow, no shape impact)

Shape is finer-grained than Tier (a Tier C project can still be shape-simple — small but inherently Tier C because it's downstream-of-spec) and orthogonal to per-task intensity (which fires later, at task dispatch time).

## Heuristics for the classifier (preliminary)

A `simple` verdict requires ALL of:
- ≤10 requirements
- ≤2 NFRs
- ≤1 phase
- No prior `discuss` invocations on this project (no accumulated complexity signal)
- No detected cross-milestone dependencies in the spec

Anything else is `complex`. Operator can override via `--shape=simple|complex` flag.

(Exact thresholds calibrated during PR via `orchestrator:specify` against fixture corpus.)

## Cross-references

- Parent scan: `gsd-2-adoption-scan-2026-05-04.md` §3
- M033 onboarding-experience brief: optional future integration (M033 closed; future amendment can wire in if useful)
- M031 right-sized entry: per-task intensity axis composes with this
- GSD source: commit `91deb109` in `gsd-build/gsd-2`

## Open questions

1. **Verdict storage location**: context-draft section vs `.orchestrator/PROJECT.md` section? Recommendation: context-draft (where `orchestrator:discuss` already writes), promoted to `.orchestrator/PROJECT.md` if a CLAUDE.md-equivalent project-summary doc exists.
2. **Operator override semantics**: `--shape=simple` forces simple even if heuristics say complex (operator knows best). Should there be a "warn-but-honor" intermediate behavior? Recommendation: honor silently; operator override is intentional.
3. **Re-classification triggers**: when should the verdict be re-evaluated? Recommendation: explicit `--reclassify` flag only; never auto-re-evaluate (verdict is sticky once set).
