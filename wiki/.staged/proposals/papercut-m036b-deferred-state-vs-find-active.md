# Paper-cut: M036b deferred state collides with find-active-milestone selection

**Captured**: 2026-05-05 (during [M029](../milestones/M029/index.md) entry readiness check)
**Shape**: Single PR, ≤1 day
**Independent**: Yes — no milestone needed.

## Problem

`scripts/state/find-active-milestone.sh` returns `[M036](../milestones/M036/index.md) planning C` because M036's roadmap has P08 + P09 (the M036b post-launch slice) marked `[ ]` unchecked, and `derive-phase.sh` Rule 3b ("Active phase has no plan file → planning") fires on the first unchecked phase.

This is technically correct from the state machine's view — M036b genuinely isn't done — but it's misleading because M036b is **intentionally deferred until post-launch demand-signal arrives**. There is no `M036-VALIDATED` and no `M036-SUMMARY.md` because the milestone's scope was split mid-flight (2026-05-01 amendment) and the M036a slice closed without milestone-level closure.

## Why it matters now

Once M029 enters `orchestrator:specify`, M029 lives in `pre-planning` / `discussing` state for some hours/days before its roadmap and first phase plan land. During that window, `orchestrator:auto` (without explicit `milestone=M029`) will pick up M036 as the auto-eligible target — because M036 is in `planning` state and is Tier C. The operator footgun: an unattended `auto` invocation could start dispatching M036b post-launch work that's supposed to be deferred.

The documented escape hatch is `orchestrator:auto milestone=M029` (per `commands/auto.md` § "Explicit milestone targeting"). That works, but it's a discipline gate, not an infrastructure guard.

## Three candidate fixes (pick one)

### Option A — write M036 milestone closure for the M036a slice (1–2 hours)

Treat M036a's scope as M036's milestone-grain scope:
- Author `M036-SUMMARY.md` covering P00–P07 deliverables only.
- Author `M036-VALIDATED` marker.
- Append a milestone-grain `unit_close` JSONL record.
- Edit `M036-ROADMAP.md`: remove P08/P09 entries from the phase list (preserve the `## Milestone Split` prose section as forward-pointing context). Add a "Deferred to future milestone" annotation listing the P08/P09 work that gets re-planned when demand arrives.
- Future M036b work opens as a new milestone (probably [M037](../milestones/M037/index.md) by then, or M036b/ as a sibling directory if the convention is honored).

**Pros**: orchestrator state-machine matches reality (M036 is closed for its committed scope). `find-active-milestone` stops returning M036. Operator's mental model is "M036 closed; next M036-shaped work is a new milestone if/when it ships."

**Cons**: P08/P09 entries leave the roadmap. Slight loss of forward-pointing visibility (mitigated by retaining the prose section).

### Option B — deferred-marker convention `[~]` honored by `derive-phase.sh` (½ day)

- Extend `derive-phase.sh` to recognize `- [~] **P##**:` as "phase exists in the roadmap but is intentionally deferred; do not select as active phase."
- Edit `M036-ROADMAP.md`: change P08/P09 from `[ ]` to `[~]`.
- Update `read-roadmap.sh active-phase` to skip `[~]` entries when looking for the next phase to work on.
- Document the convention in `references/state-machine.md`.

**Pros**: General-purpose. Future split-mid-flight milestones can use the same convention. Roadmap retains forward-pointing visibility for the deferred phases.

**Cons**: New convention; small risk of script drift across `derive-phase` / `read-roadmap` / `auto-loop` / `validate-milestone` (all four read checkbox state). Test surface expands.

### Option C — separate milestone directory `.orchestrator/milestones/M036b/` (½ day)

- Create `.orchestrator/milestones/M036b/` with its own `M036b-ROADMAP.md`, `M036b-CONTEXT.md`, etc.
- Move P08/P09 phase definitions to the M036b roadmap.
- Edit `M036-ROADMAP.md`: remove P08/P09; add forward-pointing note.
- Author `M036-SUMMARY.md` + `M036-VALIDATED` (same as Option A).
- M036b stays in `pre-planning` (directory exists but no roadmap-with-phases yet) — but actually, with M036b-ROADMAP.md present and unchecked phases, M036b would be `planning` and the same footgun reappears unless we leave M036b-ROADMAP.md absent until the milestone is ready to plan.

**Pros**: Honors the M036a-vs-M036b naming distinction the spec already uses. Strongest separation.

**Cons**: Most work. Sets precedent for letter-suffixed milestone IDs. The footgun reappears the moment M036b's roadmap lands.

## Recommendation

**Option A** today (1–2 hours) — write the M036 closure for the M036a slice, drop the P08/P09 roadmap entries with a forward-pointing note. Defer Option B (general-purpose `[~]` convention) until a second case forces it.

The M036b post-launch work was already going to need its own re-spec (demand-driven, at a future date) — whether that lands as "M037" or as a fresh M036b doesn't matter for today's launch readiness.

## Out of scope

- Re-litigating whether M036b ships at all. The existing post-launch fast-follow queue (M009 → M023 → M034 → M036b → external-tool-adapters → M010) stays as-is.
- Renaming M036 to M036a on disk — the milestone-summary frontmatter can carry the M036a scope-distinction without renaming the directory.

## Workaround until shipped

Use `orchestrator:auto milestone=M029` explicitly when invoking auto on M029 (and analogously for any other milestone). The escape hatch is documented in `commands/auto.md` § "Explicit milestone targeting" and works correctly today.
