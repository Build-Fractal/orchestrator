# Proposal — Bundle Hygiene: Pre-Publish Filter for project_assets

**Status:** Deferred — documented for pickup when launch re-enters scope.
**Priority:** Required for launch (any package-manager publishing); explicitly NOT blocking current internal dogfood work.
**Authored:** 2026-05-06.
**Surfaced by:** Mid-session audit during M036a P03 source-doc fix.

## Background

The orchestrator's install bundle is governed by
`packaging/bundle/manifest.yml::project_assets:`, which enumerates the
directories copied into adopter projects: `commands/`, `scripts/`,
`references/`, `templates/`, `wiki/`. Everything outside that whitelist
(`.orchestrator/`, `specs/`, `tests/`, `tools/`, `docs/`, repo-root
`CLAUDE.md`) correctly stays dogfood-only.

The whitelist is correct at **directory** granularity. The bundle
build (`packaging/bundle/build-bundle.sh`) does not filter **within**
those directories. Whole-directory copy means dogfood artifacts
accumulating inside whitelisted directories ship to adopters.

## Quantified gap (2026-05-06 measurement)

- **`scripts/verify/` — 851 files; 791 (93%) match the milestone
  pattern `m[0-9]*-p[0-9]*-*`** and are project-internal acceptance
  verifiers. Example: `m036-p03-gate-helper-shape.sh` asserts
  `extract_tier_2_invoke_gate()` is defined in this orchestrator's
  own `scripts/knowledge/lib/extract-tier-2-gate.sh`. Useless to
  adopters; ships today.
- **`templates/conversus-presets/`** — 6 presets. Reusable:
  `normalize-fidelity`, `tier-2-fidelity`, `classify-comment`.
  Milestone-bespoke (dogfood-only): `m013-uat-defect-merge`,
  `compression-grammar`, `spec-pressure-test`.
- **`references/`** — 15+ docs; mix of evergreen architecture and
  potentially milestone postmortems. Not yet audited.
- **`commands/`** — 13 commands; likely all adopter-relevant. Not
  yet audited.
- **`wiki/`** — [M032](../milestones/M032/index.md) deliverable, recently shipped. Not yet audited.

## Why this matters

The first homebrew tap, npm publish, or curl-pipe-bash install will
land 791 milestone-specific verifiers + several milestone-bespoke
presets in adopter `scripts/verify/` and `templates/`. Bundle hygiene
is a launch gate, not an afterthought.

## Why this is deferred

Internal dogfood velocity is current priority. The orchestrator works
fine for the author today with all dogfood artifacts in place — they
provide value in the build-the-orchestrator workflow. Filtering only
matters when bytes leave this repo for adopter projects.

## Proposed mechanism (compose two cheap rules)

1. **Pattern exclusion** in `build-bundle.sh`: any file in
   `scripts/verify/` (and parallel locations) matching
   `m[0-9]*-p[0-9]*-*` is excluded. **One rule kills 791 files.**
2. **Magic-comment opt-out**: a `# bundle: dogfood-only` header line
   in any file (or `bundle: dogfood-only` frontmatter for YAML/MD)
   excludes it. Self-documenting; catches the long-tail of milestone-
   bespoke presets and reference docs that don't follow a naming
   pattern.

The combination: the pattern catches the bulk mechanically; the
comment catches everything else explicitly. Authors mark dogfood-only
as they create new artifacts; existing artifacts get retroactively
tagged in a single audit pass.

## Suggested slot

**[M035](../milestones/M035/index.md) P02 fold-in.** The launch-event milestone's bundle-publishing
phase already needs a clean bundle; add the filter pass as a sibling
task. Estimate ~½ day for the audit + ~½ day for the build-bundle.sh
change + verifier:

1. Audit current `commands/`, `scripts/`, `templates/`, `references/`,
   `wiki/` for dogfood content; tag with `# bundle: dogfood-only`.
2. Update `build-bundle.sh` to honor pattern exclusion + magic
   comment during bundle assembly.
3. Add `tools/verify/m035-bundle-hygiene.sh` that asserts the staged
   bundle excludes all milestone-pattern files AND all magic-comment
   tagged files.
4. Update `packaging/bundle/manifest.yml` documentation to reference
   the filter convention so future authors know the contract.

Alternative slot: M035 P00.5 if P02–P06 publishing automation needs
the clean bundle as a precondition. Fold-in is probably right — the
publishing pipelines fail closed if they're staging dirty bundles
anyway.

## What this is NOT

- **Not** a refactor of existing dogfood. Artifacts stay where they
  are; just excluded from the install bundle.
- **Not** a re-org of `scripts/verify/`. Milestone-pattern files
  stay in their current location for in-repo dogfood use.
- **Not** a soft-deletion mechanism. If something is dogfood-only,
  the convention says so explicitly via comment or pattern.

## Open questions

- **Q1.** Should magic-comment apply to the whole bundle whitelist,
  or only to the five content directories (`commands/`, `scripts/`,
  `templates/`, `references/`, `wiki/`)? Probably the five; hooks /
  skills / config are tiny and curated.
- **Q2.** Does `wiki/` (M032) need filtering, or is it already
  adopter-shaped? Quick audit before M035 P02.
- **Q3.** `tools/verify/` is not in `project_assets:` today.
  Confirm that's correct — adopters running their own milestones
  would need their own verifier conventions, not ours.
- **Q4.** Should the hygiene verifier run on every build, or only at
  release time? Probably every build (cheap), so drift doesn't
  accumulate between releases.

## Pickup signal

Treat this as actionable when **any** of:

- M035 enters planning (P02–P06 publishing requires a clean bundle).
- An adopter (real or pilot tester) reports the 791-verifier dump.
- A second pre-launch milestone touches `scripts/verify/` or
  `templates/` and the dogfood/product confusion costs review time.
