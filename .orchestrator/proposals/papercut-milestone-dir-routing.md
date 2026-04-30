---
type: paper-cut
status: open
created: 2026-04-30
source: M030 dogfood — `orchestrator:auto` failed to find newly-planned milestone
investigate-by: end of M030 (or fold into M028's autonomous-hardening tail)
---

# Paper-Cut: orchestrator commands wrote M030 artifacts to `specs/NNN-slug/` instead of `.orchestrator/milestones/M###/`

## Symptom

After completing `orchestrator:evaluate` → `orchestrator:discuss` → `orchestrator:roadmap` → `orchestrator:plan-phase` for M030, invoking `orchestrator:auto` reported `NONE` from `find-active-milestone.sh`.

Cause: every M030 artifact (`M030-CONTEXT.md`, `M030-EVALUATION.md`, `M030-ROADMAP.md`, `phases/P00/P00-PLAN.md`, three task plans) was written under `specs/032-adaptive-model-selection/`. `find-active-milestone.sh` only scans `.orchestrator/milestones/M###/`, so the milestone was invisible to auto despite being fully planned.

All prior milestones (M002–M028) live at `.orchestrator/milestones/M###/`. The path mismatch is the bug, not the user's invocation.

## Manual remediation (already applied 2026-04-30)

`mv` of the four artifacts into `.orchestrator/milestones/M030/`. Path-reference rewrites inside the moved files for refs to sibling milestone artifacts (CONTEXT, ACCEPTANCE-EVIDENCE). Refs to `spec.md` and `conversus/` left untouched — the spec dir is the correct home for human-authored spec inputs.

## Root cause hypotheses (not yet investigated)

The orchestrator commands accept a `<milestone-dir>` parameter and write where told. Either:

A. **`orchestrator:evaluate` / `orchestrator:roadmap` / `orchestrator:plan-phase` agents inferred `<milestone-dir>` from the spec slug** (`specs/NNN-slug/`) rather than `.orchestrator/milestones/M###/`. The spec-kit lineage of the project makes `specs/NNN-slug/` an attractive default but it's wrong for orchestrator state.

B. **The plan-phase command rubric does not enforce milestone-dir shape**. `commands/plan-phase.md:236` says "Write the phase plan to `<milestone-dir>/phases/P##/P##-PLAN.md`" but does not require `<milestone-dir>` to match `.orchestrator/milestones/M###/` form.

C. **No upstream gate validates artifact location**. `find-active-milestone.sh` only reads from `.orchestrator/milestones/`; nothing warns when a milestone-shaped artifact lands elsewhere.

## Fix shape candidates (for whichever milestone adopts this)

1. **Add path validation to plan-phase / roadmap / evaluate**: refuse to write outside `.orchestrator/milestones/M###/`, or warn loudly. This is the cheapest and the path most consistent with M028's "shape-guard" lineage.
2. **Add doctor check**: `orchestrator:doctor` flags any `M###-{CONTEXT,EVALUATION,ROADMAP}.md` outside `.orchestrator/milestones/`. Catches drift after the fact.
3. **Migration helper**: `scripts/migrate/relocate-milestone.sh <from> <to>` codifies the manual `mv + path-rewrite` performed today, so future occurrences self-heal.

Option 1 is the load-bearing fix. Option 2 is a backstop. Option 3 only matters if the bug recurs across multiple users.

## Where this goes

Best home is either **M028's autonomous-hardening tail** (it already targets shape-guard / planner-template hardening) or a new shape class in M028's AP-### catalog. Defer to whoever picks up the next planning-time hardening cycle.

## Cross-reference

- M028 brief: `.orchestrator/proposals/M028-autonomous-hardening-v3.md` (autonomous hardening shape classes)
- CLAUDE.md "M032 spec-side invariant for staged-dirs collision" — adjacent invariant (project-owned paths must not collide with staged dirs); this paper-cut is the orchestrator-state version of the same shape concern.
