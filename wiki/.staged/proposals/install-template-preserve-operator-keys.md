# Brief — install-template should preserve operator-authored config.yml keys

**Status:** Deferred — fast-follow for M025/[M033](../milestones/M033/index.md) install territory.
**Authored:** 2026-05-06.
**Surfaced by:** PBJ-central-mono-repo's round-2 wiki dogfood report
(2026-05-06). Same operator session that produced the B5/B7/B8 paper-cut
sweep.

## Problem

`install-claude-code.sh --force` clobbers operator-authored sections of
`.orchestrator/config.yml`. Specifically: when an operator has authored
a `wiki:` block (declaring `extra_dirs:`, `extra_dir_labels:`, etc.),
re-running the installer with `--force` overwrites the file with the
template default, losing all operator config.

## Why this matters

The installer already preserves operator-owned `wiki/` directory
contents via the collision-skip pattern (operator-authored
`wiki/glossary.md`, `wiki/docs/index.md`, etc. survive `--force`). The
same semantic should extend to `.orchestrator/config.yml` keys: the
template ships pinned defaults; the operator extends with project-
specific config; `--force` should re-apply the template's keys without
clobbering operator-added ones.

This pattern surfaces every time an operator runs `orchestrator:update`
(the M035-prelaunch interim wrapper around `install-claude-code.sh
--force`). PBJ-central hit it after the round-1 paper-cut sweep landed
— operator ran `orchestrator:update`, re-ran wiki tooling, found their
`wiki:` block had been wiped.

## Workaround today

After `orchestrator:update`, re-author the `wiki:` block. Trivially
recoverable, but a paper-cut that the round-2 dogfood operator flagged
explicitly.

## Sequencing

This is **M025/M033 install-territory** work, NOT a wiki-tooling fix.
Belongs as a fast-follow when [M025](../milestones/M025/index.md) (installer coexistence) or M033
(project onboarding experience) next surface for paper-cut work, OR
when [M035](../milestones/M035/index.md) P00–P01 (pre-launch dev-ergonomics) ships and revisits the
install/update surface.

Two candidate fix shapes (cheaper-first):

1. **YAML-merge in install-claude-code.sh.** When `--force` is in
   effect AND a destination `.orchestrator/config.yml` exists, parse
   both the template and the destination, merge the destination's
   values over the template's defaults (top-level keys + nested
   per-key), and write the merged result. Bash 3.2 + awk parser
   tractable for the orchestrator's YAML shape (no anchors, no flow
   maps, no multi-doc) but requires careful handling of the `wiki:`
   block's nested structure.

2. **Marker-bracketed regions** mirroring the
   `# >>> orchestrator:recent-changes >>>` / `<<<` pattern already
   used in `CLAUDE.md`. Template ships a `# >>> orchestrator-defaults
   >>>` ... `# <<< orchestrator-defaults <<<` region; everything outside
   is operator territory and `--force` only re-renders content inside
   the markers. Lower implementation cost than YAML merge but requires
   the operator's existing `config.yml` to migrate (one-time cost).

Recommendation: option 2 (marker-bracketed). Mirrors an established
orchestrator pattern. The migration cost is one-shot — every operator
hits it once and the round-1 collision-skip semantics already tells
them what to expect.

## Acceptance shape

- Fresh install (no destination) → behaves as today (writes template).
- `--force` against an existing config that has only template-shape
  keys → behaves as today (re-applies template).
- `--force` against an existing config with operator-added keys
  (e.g., `wiki.extra_dirs:`) → preserves operator keys; re-applies
  template defaults to the marker-bracketed (or template-owned) region.
- Regression fixture under `tests/m025-acceptance/` or
  `tests/m033-acceptance/` covering the three cases.
- Hand-tested with PBJ-central via `orchestrator:update` round-trip.

## Out of scope

The `wiki/` collision-skip pattern is already correct and stays as-is.
The full M035 packaging surface (npm + homebrew + curl-pipe-bash) ships
the same template; the marker-bracketed pattern (or YAML merge) needs
to fire identically across all three publishing pipelines.
