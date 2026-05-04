# Imported-Context Sentinel — `_imported-context/` (M033/P03/T04 #Q-11)

This document is the SSOT for the `_imported-context/` sentinel convention
introduced by M033/P03/T04 (FR-8 / MIT-005 rich-context import path). It
documents (1) the sentinel directory + filename, (2) the path-resolver
precedence rule, (3) the downstream-traverser convention for `_*`-prefix
entries under `.orchestrator/milestones/`, (4) the frontmatter SSOT
marker `context_source: imported-from-existing`, and (5) the
`MEM-DR-*` cross-reference convention.

## Why a sentinel?

`scripts/lifecycle/ingest-codebase.sh` may run on a project that has
**no active milestone configured** (no `current_milestone:` field in
`<project-dir>/.orchestrator/config.yml`). In that pre-milestone window
the rich-context import path still has work to do — operators arrive
with `<project-dir>/.orchestrator/DECISIONS.md` carrying `DR-` entries,
or a `MILESTONE-AUDIT.md`, or a populated CLAUDE.md custom block — but
there is no milestone-scoped emit target yet.

The sentinel `<project-dir>/.orchestrator/milestones/_imported-context/`
is the canonical pre-milestone-configured emit target. The leading
`_` prefix is the load-bearing token: any `_*`-prefix entry under
`.orchestrator/milestones/` is treated as a **special non-milestone
class** by every downstream traverser that enumerates milestones.

## Path-resolver precedence

`scripts/lifecycle/ingest-codebase.sh` resolves the rich-context emit
path with the following precedence:

1. **Active milestone configured.** When
   `<project-dir>/.orchestrator/config.yml` declares
   `current_milestone: <id>`, emit to
   `<project-dir>/.orchestrator/milestones/<id>/<id>-CONTEXT.md`.
   This filename keeps the imported-context discoverable by the
   existing milestone-context machinery (M005 D-row precedent —
   `<id>-CONTEXT.md` is the conventional milestone-context filename).

2. **No active milestone.** When `current_milestone:` is absent or
   empty, emit to
   `<project-dir>/.orchestrator/milestones/_imported-context/_imported-context.md`.
   The filename matches the directory name so the sentinel surface is
   self-documenting.

The branch is the load-bearing #Q-11 decision: pre-milestone-configured
projects get the sentinel; milestone-configured projects get the
natively-authored path. Per M020 D024 reversibility — operators who
later configure a milestone can `mv _imported-context/_imported-context.md
M<id>/<id>-CONTEXT.md` to migrate the file (no schema change).

## Downstream-traverser convention

Any `_*`-prefix directory under `<project-dir>/.orchestrator/milestones/`
is a **special non-milestone class**. Traversers that enumerate
milestones MUST skip `_*` entries (otherwise they treat
`_imported-context/` as an active milestone and fail validation).

The skip clause is a four-line `case` statement, bash 3.2 compatible,
inlined at every traverser site (no shared helper — single-grep-token
discoverable):

```bash
for d in "$milestones_dir"/*/; do
  base="$(basename "$d")"
  case "$base" in
    _*) continue ;;  # skip imported-context sentinel (M033/P03/T04 / #Q-11)
  esac
  # ... existing logic
done
```

### Concrete traverser obligations

The following downstream traversers honor the `_*`-prefix skip clause:

- `scripts/diagnostics/check-plans.sh` — milestone-glob enumeration of
  `*-PLAN.md` files at `.orchestrator/milestones/*/phases/*/tasks/`. The
  `_*`-prefix skip clause is applied at the enumeration site so
  `_imported-context/` does not pollute the plan-shape audit.
- `scripts/diagnostics/check-constitution.sh` — milestone-glob
  enumeration of plan files under `.orchestrator/milestones/*/phases/`.
  Same skip clause, same site.
- `scripts/diagnostics/run-doctor.sh` — orchestrator dispatcher;
  delegates milestone enumeration to the two checks above. The skip
  clause lands in the delegates, not the orchestrator.

The plan-listed candidates that resolve a single milestone path passed
as an argument (`scripts/state/derive-phase.sh`,
`scripts/dispatch/build-context.sh`,
`scripts/verify/validate-milestone.sh`,
`scripts/state/read-roadmap.sh`) do NOT enumerate milestones, so the
skip clause is unnecessary at those sites. The omission is deliberate.

The annotation is **additive** — it does NOT change behavior for
projects without imported-context entries. The cross-phase regression
verifier (T05 deliverable) re-runs `tools/verify/m033-p01-phase-suite.sh`
and `tools/verify/m033-p02-phase-suite.sh` after T04's annotations
land, asserting both still pass.

### `build-context.sh` and imported-context surfacing

`scripts/dispatch/build-context.sh` does NOT enumerate milestones (it
resolves a single `MILESTONE_ID` from state). It MAY surface
imported-context via dedicated injection in a future milestone — the
sentinel filename is stable + grep-discoverable
(`grep -F context_source: imported-from-existing`) so a future
build-context section handler can locate and inject the sentinel
without rescanning the milestone tree.

## Frontmatter SSOT marker

The imported-context file carries the load-bearing frontmatter marker
`context_source: imported-from-existing`. Downstream tools detect
imported-context vs natively-authored context by greping this field
(NOT by path — operators may migrate sentinel files into milestone
directories, so path-based detection is fragile).

```yaml
---
schema_version: "1.0"
type: imported-context
context_source: imported-from-existing
imported_at: <ISO 8601 UTC timestamp>
source_files:
  - .orchestrator/DECISIONS.md
  - .orchestrator/MILESTONE-AUDIT.md
  - CLAUDE.md (custom block)
---
```

## `MEM-DR-*` cross-reference convention

For every `DR-<id>` entry detected in
`<project-dir>/.orchestrator/DECISIONS.md`, the rich-context branch
emits a `<project-dir>/.orchestrator/knowledge/decisions/MEM-DR-<id>.md`
**cross-reference MEM**. The MEM is **provenance-preserving** — the
body is a single-line reference back to the source `DR-<id>` row, NOT
a duplicate-authoring of the source content (FR-8 invariant).

```yaml
---
schema_version: "1.0"
type: knowledge-mem
category: decisions
status: graduated
source_path: .orchestrator/DECISIONS.md
signal_kind: dr-cross-reference
dr_id: <id>
derived_from_codebase_ingest: true
---

# MEM-DR-<id>

Cross-reference to `DR-<id>` in `.orchestrator/DECISIONS.md`. Provenance-preserving — see source for canonical content.
```

The cross-reference fits inside the existing M020 `decisions` knowledge
category — **no new MEM kinds** introduced (M020 Knowledge-Layer
Boundary). Idempotency: re-runs detect existing
`derived_from_codebase_ingest: true` MEMs by stable ID and skip without
overwriting.

## References

- M033 spec: `specs/036-project-onboarding-experience/spec.md` — FR-8 /
  MIT-005 (rich-context import path).
- M033/P03 plan: `.orchestrator/milestones/M033/phases/P03/P03-PLAN.md`.
- T04 plan: `.orchestrator/milestones/M033/phases/P03/tasks/T04-rich-context-import-PLAN.md`.
- #Q-11 (discuss-phase resolution): pre-milestone-configured projects
  get the sentinel; milestone-configured projects get the
  natively-authored path.
- M020 Knowledge-Layer Boundary: cross-reference fits inside existing
  `decisions` category; no new MEM kinds.
- M005 D-row precedent: `<id>-CONTEXT.md` filename convention.
