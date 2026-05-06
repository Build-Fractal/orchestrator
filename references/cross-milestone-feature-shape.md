---
schema_version: "1.0"
type: cross-milestone-feature-shape
milestone: "M029"
phase: "P02"
created_at: "2026-05-05"
---

# Cross-Milestone Feature Shape

This document is the canonical Principle III design contract for the
cross-milestone feature data model consumed by `orchestrator:where`
(FR-13 / AD-6 of the M029 spec at
`specs/037-roadmap-visibility-cli-ux/spec.md`). Per AD-6 (recorded at
`.orchestrator/milestones/M029/M029-CONTEXT.md`) this contract MUST be
on disk before any FR-13 implementation work begins. T03 (the
`scripts/diagnostics/render-position.sh` tree renderer) and T04 (the
mixed-state golden fixtures) BOTH consume this contract; the gate
verifier `tools/verify/m029-p02-cross-milestone-shape-contract.sh`
mechanically asserts every required section and token so downstream
implementations cannot silently drift.

## Purpose

The `orchestrator:where` renderer is feature-grain: when a feature
spec spans multiple milestones, `where` renders the full feature view
and marks the active milestone within it. AD-6 (the authorising
decision recorded at
`.orchestrator/milestones/M029/M029-CONTEXT.md` § AD-6) locks the
data model: feature-spec frontmatter MAY declare an explicit
`milestones: [M###, ...]` list (additive); existing singular
`milestone:` is retained for backward compatibility. AD-6 also resolves
#Q-G5 (cross-milestone data-model shape) and pairs with the #Q-5
resolution (cross-milestone-inactive-render-shape, locked at this P02
plan-phase) and #Q-G8 (FR-8 marker canonical form).

This document is the SSOT for the cross-milestone data model. Its
consumers are:

- `commands/where.md` — the LLM-instruction skill that operators invoke
  via `orchestrator:where`.
- `scripts/diagnostics/render-position.sh` — the executable renderer
  that emits the tree.
- `scripts/diagnostics/summarize-milestone.sh` — the AD-4 SC-8 oracle
  helper that produces the per-milestone progress block embedded in
  the rendered tree.
- `scripts/state/find-active-milestone.sh` — the existing active
  milestone resolver consumed by the renderer to identify which
  milestone in the cross-milestone feature view is currently active.

The contract MUST NOT contain executable code — only documentation.
Implementation lives in T03 (`render-position.sh` parsing logic). Per
Principle III + AD-6, contract is upstream of code.

## Frontmatter Schema

A `type: feature-spec` document declares its milestone span via one of
two forms. The schema is **exactly-one-of**: a feature spec MUST
declare exactly one of the two; declaring both is a schema violation;
declaring neither implies the spec is feature-less (e.g. an
architectural amendment) and `where` does not render it.

### Singular form (legacy, retained)

```yaml
---
type: feature-spec
milestone: "M###"
---
```

The singular `milestone:` field carries the single canonical milestone
for the feature. Existing specs that already use this form continue to
parse correctly without modification. The renderer treats the singular
value as a single-element list `[M###]`.

### Plural form (new, AD-6)

```yaml
---
type: feature-spec
milestones: [M###, M###, ...]
---
```

The plural `milestones:` list is the explicit declaration when the
feature spans multiple milestones. The FIRST element is the canonical
entry point for the feature. Order in the list is preserved by the
renderer and reflects the feature's intended sequencing (e.g.
`milestones: [M036a, M036b]` for the M036 reference-corpus split).

### Exactly-one-of rule

A feature spec MUST declare exactly one of the two. Declaring both
`milestone:` and `milestones:` simultaneously is a schema violation —
the renderer treats this as ambiguous and emits a stderr `WARN:` line
identifying the ambiguity, then prefers the plural form for render
purposes (Principle XV: surgical precision; we do not crash on a
recoverable ambiguity, but we surface the drift loudly).

### Backward compatibility

Existing specs with only `milestone:` continue to parse correctly
without modification. The M033 spec migration (AD-6 / NG-3 noted in
`M029-CONTEXT.md`) — i.e. migrating spec 033's frontmatter from
`milestone: "M036 (split: ...)"` to `milestones: [M036a, M036b]` — is
**not** part of M029. That migration defers to M036b planning entry.

## Reverse-Lookup Advisory Validation

At render time, `scripts/diagnostics/render-position.sh` performs a
reverse-lookup advisory check:

1. Enumerate `.orchestrator/milestones/M*/M*-EVALUATION.md`.
2. For each EVALUATION.md, extract the `feature_ref:` frontmatter
   field. Group milestone IDs by `feature_ref`.
3. For each feature being rendered, cross-reference the spec's
   declared milestone set (from the `milestone:` or `milestones:`
   frontmatter) against the discovered set from the reverse lookup.
4. On mismatch, emit `WARN: feature <slug> spec frontmatter declares
   <set>; reverse-lookup discovered <set>; using spec` on stderr and
   continue render using the spec's declaration (Principle XI — spec
   is authoritative).

The advisory is **never a hard error**. Render proceeds. Spec drift is
a known operational pattern that the renderer surfaces but does not
block on. Rationale: a transient mismatch (e.g. an `M###` directory
was created but `M###-EVALUATION.md` has not been written yet) MUST
NOT block an operator's `where` invocation. The `WARN:` channel
surfaces drift without crashing the render path.

The reverse-lookup is deliberately advisory rather than authoritative
because the EVALUATION.md is a derived artifact. The feature spec is
the source of truth (Principle XI). Rejected alternatives (option (b)
reverse-lookup-only, option (c) external manifest) are recorded in
AD-6 at `M029-CONTEXT.md`.

## Inactive Milestone Render Shape

This section pins the **#Q-5 resolution** (cross-milestone-inactive-
render-shape), captured under AD-6 at `M029-CONTEXT.md` and locked
here at the P02 plan-phase.

### Default (collapsed)

By default, every milestone in the cross-milestone feature view that
is NOT the active milestone renders as a SINGLE collapsed line:

```
<glyph> M### <name>  ▓░ X% (k/n phases)
```

Where:

- `<glyph>` is one of `✓ ▶ ◇ ✗` per the Marker Glyph Set below.
- `M### <name>` is the milestone ID + short name (e.g. `M036a
  Reference-Corpus Pre-Launch Slice`).
- `▓░ X% (k/n phases)` is the milestone-grain progress bar +
  percentage + per-phase tally produced by
  `scripts/diagnostics/summarize-milestone.sh` (the AD-4 SC-8 oracle).

### `--expand-all` override

Passing `--expand-all` to `orchestrator:where` expands every
milestone's full phase tree (active + inactive). Each inactive
milestone's collapsed line becomes the parent of its full phase tree.

### Active milestone is always expanded

The active milestone is always expanded regardless of `--expand-all`.
The active milestone is identified via
`scripts/state/find-active-milestone.sh`. When the active milestone
sits inside a cross-milestone feature view, the renderer marks it
visually (the operator's eye lands on `▶` glyphs in the active
milestone's phase rows) and renders its full phase tree inline.

## Marker Glyph Set

The canonical glyph alphabet for `orchestrator:where`. Every renderer,
fixture, and verifier in P02 MUST use exactly this glyph set. No other
glyphs may appear in v1 deliverables.

| Glyph | Meaning                                                    |
|-------|------------------------------------------------------------|
| `✓`   | phase / task complete                                      |
| `▶`   | phase / task currently executing                           |
| `◇`   | phase / task pending (not yet started)                     |
| `✗`   | phase / task failed (last verify result was `fail`)        |
| `▽`   | savings marker for `--live` mode (FR-8)                    |

### `▽` savings marker — canonical compact form (#Q-G8 resolution)

The compression-savings marker used by `orchestrator:where --live`
(FR-8) has a single canonical compact form, locked here per the #Q-G8
resolution in AD-6 / `M029-CONTEXT.md`:

```
▽ saved Nk
```

Where `N` is the integer kilobyte count of compression savings
observed since the live-tail began. Any verbose suffix that appends
provenance after the magnitude (cache-reuse attribution, tier
labelling, savings-source narration) is reserved for a future
`--verbose` mode and MUST NOT appear in v1 fixtures, verifiers, or
production output. The verifier
`tools/verify/m029-p02-cross-milestone-shape-contract.sh` asserts the
canonical form `saved Nk` is present in this document AND that no
verbose-suffix tokens appear.

A reordered form with numeric prefix before the verb (e.g.
magnitude-then-verb) is also NOT canonical and MUST NOT appear in P02
deliverables; the canonical order is verb-then-magnitude (`saved Nk`).

## Cross-References

- `commands/where.md` — consumer (the LLM-instruction skill that reads
  this contract for its rendering directives).
- `scripts/diagnostics/render-position.sh` — consumer (the executable
  renderer that parses feature-spec frontmatter per the schema in
  this document).
- `scripts/diagnostics/summarize-milestone.sh` — consumer (the AD-4
  SC-8 oracle that produces the milestone-grain progress bar embedded
  in the collapsed inactive-milestone line shape).
- `scripts/state/find-active-milestone.sh` — active-milestone
  resolver; the renderer consults it to determine which milestone in
  the cross-milestone feature view is currently active and therefore
  always expanded.
- `specs/037-roadmap-visibility-cli-ux/spec.md` — the M029 spec
  carries FR-13 (cross-milestone feature renderer) and the SC-5
  mixed-state golden fixture acceptance criteria.
- `.orchestrator/milestones/M029/M029-CONTEXT.md` — the authorising
  decision record. AD-6 (cross-milestone feature data model + #Q-G5
  resolution); #Q-5 (inactive-milestone render shape); #Q-G8 (FR-8
  marker canonical form `▽ saved Nk`).
- `references/status-headline-shape.md` — sibling P01 design contract;
  this document mirrors its 8-section H2 structure.
- `references/status-json-schema.md` — sibling P01 design contract;
  this document mirrors its versioning-policy section style.
