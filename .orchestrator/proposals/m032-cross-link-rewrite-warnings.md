# Brief — M032 cross-link rewrite warnings (B5)

**Status:** Deferred — needs hypothesis validation before patching.
**Authored:** 2026-05-06.
**Surfaced by:** PBJ-central-mono-repo wiki-init dogfood, 2026-05-06.

## Problem

Canonical orchestrator docs (`.orchestrator/DECISIONS.md`,
`.orchestrator/KNOWLEDGE.md`) contain
`[link](../../.orchestrator/knowledge/foo.md)`-style cross-references.
When mkdocs-include-markdown projects them into stubs at
`wiki/docs/decisions.md` etc., the relative paths don't rewrite cleanly
because the source and stub sit at different depths. mkdocs emits ~20
WARNING lines per build; `--strict` build fails.

Pre-existing across every consumer project — not introduced by any
recent change. PBJ-central-mono-repo's wiki standup surfaced it
operationally; the orchestrator's own wiki has tolerated it because we
don't currently run `--strict`.

## Hypothesis

mkdocs-include-markdown-plugin's `rewrite-relative-urls=true` (set in
`scripts/wiki/wiki-generate-stubs.sh:215, 275`) likely doesn't handle
the `../../` upward-traversal pattern that orchestrator authors
naturally write inside `.orchestrator/`. The plugin probably rewrites
forward-relative siblings cleanly but breaks on upward traversal that
crosses out of the source dir.

**Validation required before patching.** Build a minimal repro fixture:
canonical doc with `../../.orchestrator/knowledge/foo.md` link, projected
into stub at varying depth. Capture exact mkdocs warnings. Then decide.

## Three candidate fixes (in order of cost)

1. **sed-pass post-projection** — wiki-generate-stubs.sh (or a sibling
   `wiki-rewrite-links.sh`) post-processes each generated stub: rewrites
   `../../.orchestrator/<rel>` to either an absolute repo-root-relative
   path or to a sibling-projected wiki path. Lowest blast radius.
   Maintains canonical-source-of-truth at `.orchestrator/`. Breaks if
   include-markdown re-runs the include after the sed pass — needs
   confirmation that sed runs after final projection.

2. **Convention shift to absolute paths in canonical docs** — change
   the convention to `[link](/orchestrator-knowledge/foo.md)` or similar
   absolute paths that include-markdown can rewrite without
   path-arithmetic. Low tooling change, high content change (many
   canonical docs to migrate). Brittle if mkdocs/include-markdown's
   absolute-path handling differs.

3. **Sibling-file projection** — wiki tooling emits sibling files under
   `wiki/docs/` mirroring source paths, so cross-links resolve
   intra-wiki without traversing back to `.orchestrator/`. Largest
   change; highest correctness margin.

## Acceptance shape

- Repro fixture builds without `--strict` warnings.
- Real `wiki-strict-build.sh` against the orchestrator's own corpus
  passes.
- No regression on existing M012/M032 acceptance battery.

## Sequencing

Belongs as a **demand-driven post-launch fast-follow** if `--strict`
build doesn't block any consumer. If it does block PBJ-central-mono-repo
or another adopter, escalate to pre-launch.

PBJ-central can build without `--strict` today — workaround documented
in the return prompt. So this is fast-follow priority, not blocker.
