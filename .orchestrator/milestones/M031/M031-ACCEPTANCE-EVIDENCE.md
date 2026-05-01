---
schema_version: "1.0"
type: acceptance-evidence
milestone: "M031"
generated_at: "2026-05-01T22:49:15Z"
battery_path: "tests/m031-acceptance/run-acceptance-battery.sh"
sc13_option: "A"
---

# M031 -- Acceptance Evidence Ledger

This document captures the green-run evidence for M031 (right-sized
entry). It mirrors the M030 acceptance-evidence convention and serves
as the milestone-close audit trail.

## Battery Result

```
BATTERY: pass=15 fail=0
```

(N = 15 under Option A; N = 16 under Option B. SC13-OPTION.md records
Option A active because no committed git history covers the corpus path
at evaluation time -- `verify-baseline-ordering.sh` reclassified SC-13
as a P00 protocol note and dropped from SC-14's count.)

## Per-SC Roll-Up

| ID    | Path                                                       | Outcome |
|-------|------------------------------------------------------------|---------|
| SC-1  | tests/m031-acceptance/test-quick-injects-knowledge.sh      | PASS    |
| SC-2  | tests/m031-acceptance/test-build-context-profile.sh        | PASS    |
| SC-3  | tests/m031-acceptance/test-compression-applies-to-quick.sh | PASS    |
| SC-5  | tests/m031-acceptance/test-tier-a-plus-classifier.sh       | PASS    |
| SC-6  | tests/m031-acceptance/test-tier-a-plus-flow.sh             | PASS    |
| SC-16 | tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh        | PASS    |
| SC-7  | tests/m031-acceptance/test-universal-entry-trivial.sh      | PASS    |
| SC-8  | tests/m031-acceptance/test-universal-entry-lowconf.sh      | PASS    |
| SC-9  | tests/m031-acceptance/doc-drift-verifier.sh                | PASS    |
| SC-10 | tests/m031-acceptance/test-auto-proceed-default.sh         | PASS    |
| SC-12 | tests/m031-acceptance/scope-guard.sh                       | PASS    |
| AD-9  | tests/m031-acceptance/test-doctor-compound-change.sh       | PASS    |
| AD-19 | tests/m031-acceptance/test-budget-drift-warning.sh         | PASS    |
| SC-15 | tests/m031-acceptance/test-quick-budget-median.sh          | PASS    |
| SC-11 | tests/m031-acceptance/empirical-baseline.sh --compare      | PASS    |
| SC-13 | tests/m031-acceptance/verify-baseline-ordering.sh          | N/A (Option A protocol note) |

The roll-up order mirrors the order in which the battery aggregator
emits its `BATTERY-PASS:` lines (which mirrors the dependency order
P01 -> P02 -> P03 -> P04 -> P00 baseline tail). SC-13 is recorded as
N/A under Option A and is not counted in `BATTERY: pass=N`.

## Run Metadata

- **Timestamp** (ISO-8601 UTC): `2026-05-01T22:49:15Z`
- **SC-13 option active**: `A`
- **Battery N**: `15`
- **Battery aggregator path**: `tests/m031-acceptance/run-acceptance-battery.sh`
- **SC-11 verdict**: `wins` (pre_median_tokens=3500 post_median_tokens=10185 pre_pass_rate=1.0000 post_pass_rate=1.0000)

## SC-13 Option Active

Option A (fallback, recorded in `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md`).
Option A applies when `git log` against the corpus path returns empty
because the corpus directory was created and populated in the same
uncommitted working tree as the P01 first task -- there is no committed
git history covering the corpus path yet, so Option B's
`corpus_first_commit_ct < protected_first_commit_ct` assertion has no
defined left-hand side. The verifier emits
`ORDERING: option=A verdict=protocol-note` and SC-13 reclassifies as a
P00 protocol note. The single-window discipline of AD-14 is preserved
by procedure (T03 capture committed BEFORE P01 first-task amendment
of `commands/dispatch.md:21`).

Operators can re-run `verify-baseline-ordering.sh` after both commits
exist; under that condition Option B will succeed and SC-14's count
recovers `N >= 16`. The battery aggregator may then re-evaluate this
file to upgrade the selected option.

## Cross-References

- Milestone roadmap: `.orchestrator/milestones/M031/M031-ROADMAP.md`
- Milestone context: `.orchestrator/milestones/M031/M031-CONTEXT.md`
- Milestone evaluation: `.orchestrator/milestones/M031/M031-EVALUATION.md`
- Milestone summary: `.orchestrator/milestones/M031/M031-SUMMARY.md` (consolidated post-phase by `orchestrator:consolidate`)
- Feature spec: `specs/034-right-sized-entry/spec.md`
- Per-phase summaries: `.orchestrator/milestones/M031/phases/P0[0-4]/P0[0-4]-SUMMARY.md`
- Phase plan: `.orchestrator/milestones/M031/phases/P04/P04-PLAN.md`
- Battery aggregator: `tests/m031-acceptance/run-acceptance-battery.sh`
- Phase-suite aggregator: `tools/verify/m031-p04-phase-suite.sh`
- Phase-grain scope-guard: `tools/verify/m031-p04-scope-guard.sh`
