---
schema_version: "1.0"
type: proposal
title: "Out-of-tree runtime footprint refactor (deferred post-launch)"
status: deferred-post-launch
target_milestone: "M0xx (unnumbered — slot post-launch between M009 and M010)"
captured: "2026-05-09"
captured_at: "M033 friendly-tester walkthrough (maintainer-led)"
parent_proposals:
  - ".orchestrator/proposals/post-launch-wiki-ux-and-adapters.md"
  - ".orchestrator/proposals/M035-packaging-distribution.md"
absorption_candidate: "M009 (post-launch multi-runtime parity audit)"
---

# M0xx — Out-of-Tree Runtime Footprint Refactor

## Why this exists

The maintainer-led friendly-tester walkthrough on 2026-05-09 (report at
`tests/m033-acceptance/friendly-tester-pass/reports/2026-05-09-maintainer-advisory.md`)
surfaced that pointing `bash scripts/lifecycle/start.sh --project-dir <existing-codebase>`
writes **9 items at the project root**: `.orchestrator/`, `CLAUDE.md`, `AGENTS.md`,
`.gitignore`, `commands/`, `references/`, `scripts/`, `templates/`, `wiki/`.

A stranger pointing the installer at their real repository finds it heavily
mutated, and any pre-existing top-level `commands/`, `scripts/`, `templates/`,
or `wiki/` directories would collide silently.

**Today's mitigation (commit 852416b4)** added a pre-flight warning that
enumerates the 9 items, runs a collision check that refuses with `exit 2` on
conflict, and prompts for explicit confirmation before any write. That
addresses the *surprise*. It does **not** address the underlying *invasiveness*
— the orchestrator runtime still installs five large directories into the
host repo's working tree, which is a heavy footprint for what is conceptually
a tooling install.

This proposal captures the deeper-fix design question that surfaced during
that walkthrough so the conversation isn't lost.

## Proposed shape

Move runtime artifacts out of the project's working tree:

**In-tree (small, project-specific, version-controlled by the consumer):**

- `.orchestrator/` — project state (milestones, phases, knowledge, locks)
- `CLAUDE.md` — Claude Code instruction file
- `AGENTS.md` — Codex CLI instruction file
- `.gitignore` — orchestrator state ignores

**Out-of-tree (large, runtime-cached, owned by the orchestrator install):**

- `commands/` — agent instruction documents
- `references/` — architecture / engine / events docs
- `scripts/` — helper scripts (state, dispatch, engine, verify, knowledge, lifecycle, ...)
- `templates/` — output templates
- `wiki/` — wiki tooling (mkdocs config, themes, plugins)

→ Installed at something like `~/.claude/projects/<slug>/runtime/` (exact
path is a design question — see Open Questions below).

Skill registration in `packaging/install/install-claude-code.sh` (and
parallel `install-codex.sh` / `install-cursor.sh`) rewrites paths to point
at the cache location. Every script that reads `templates/foo.md` or
`references/bar.md` gains a resolver shim — e.g.
`$ORCHESTRATOR_RUNTIME/templates/foo.md` — defaulting to the in-tree path
when the env var is unset (preserves dogfooding-self-as-runtime).

The shape of the shipped install would feel closer to a typical CLI tool
install: a small project-side footprint + a tool-side runtime cache, rather
than a 9-item bulk-copy into the project's working tree.

## Known scope (off the top — refine when this enters real planning)

These are surfaces that will need touching. Not exhaustive; surfaces a
queue-entry pass for `orchestrator:specify` to enumerate properly.

1. **Skill registration paths rewrite** — `packaging/install/install-claude-code.sh`
   plus parallel codex/cursor installers. Every registered skill currently
   resolves to `<project>/commands/<name>.md`; needs to resolve to
   `$ORCHESTRATOR_RUNTIME/commands/<name>.md`.
2. **Template resolver shim** — every script that opens `templates/foo.md`
   gets `$ORCHESTRATOR_RUNTIME` indirection. There are 80+ scripts in
   `scripts/`; not every one reads templates, but the audit pass is real work.
3. **References resolver shim** — `CLAUDE.md` link rewrites, wiki ingestion
   that pulls from `references/`, in-script `references/<name>.md` reads.
4. **Wiki tooling reconciliation** — [M032](../milestones/M032/index.md) just shipped (2026-05-05) with
   `wiki-init.sh --deploy` baking in-tree `wiki/` assumptions. [M037](../milestones/M037/index.md) just
   shipped (2026-05-07) with reader-side polish landed against the same
   in-tree `wiki/`. Both will need migration to the cache-resident shape
   (or `wiki/` stays in-tree as a deliberate exception — see Open Questions).
5. **[M035](../milestones/M035/index.md) packaging assumptions** — P00–P05 closed (or are about to close)
   assuming in-tree install via `packaging/install/install-claude-code.sh`.
   P06 (`orchestrator:update` multi-source dispatch) is built on the same
   assumption. Migration story for already-installed projects is
   non-trivial.
6. **Existing dogfood projects (PBJ-central, lakeledger, bbt-companion)**
   — already installed in-tree under the current scheme. Need a migration
   adapter that detects "old shape" and rewrites to "new shape," or a
   coexistence story that lets old installs keep working.
7. **[M033](../milestones/M033/index.md) verifiers (`tools/verify/m033-*.sh`)** — many grep for in-tree
   paths to confirm install correctness. Each gets re-pointed at the cache
   resolver.
8. **`start.sh` reference to `references/branch-detection.md`** — the
   parity verifier locks the file location at the in-tree path. Either the
   reference moves to a project-side location, or the resolver gets used.
9. **The `orchestrator:update` story** — once runtime lives in a cache,
   updating *is* updating the cache (good: single update touches all
   projects sharing that cache). But version-drift between the project's
   expected runtime version and the cached runtime version becomes a new
   class of failure mode — needs explicit version-pin / version-check
   surface.

## Why now is wrong (the deferral)

This was discussed today and the decision landed on **don't refactor now**.
Reasons, in priority order:

- **M035 P00–P05 closed assuming in-tree install.** P06 (the next M035
  phase) is `orchestrator:update` multi-source dispatch — built on the same
  assumption. Changing install topology *right before* the launch milestone
  closes is high-risk for a class of bug (path-resolution drift, install
  shape drift across npm/homebrew/curl-pipe-bash channels) that we have no
  good detection story for yet.
- **Pre-flight warning may be 80% sufficient.** The friendly-tester report
  is from a maintainer who already knows the orchestrator. Real outsiders
  haven't yet hit this path with the warning live. F8/F9 friction may
  largely resolve once the warning + collision check + confirmation prompt
  is in front of someone who hasn't seen the install before. We'd be
  refactoring on n=0 evidence.
- **The right design is dogfood-signal-dependent.** Multiple cache-dir
  shapes are plausible (`~/.claude/projects/<slug>/runtime/`,
  `$XDG_CACHE_HOME/orchestrator/<project-hash>/`, per-runtime vs
  cross-runtime). Picking pre-launch means picking blind. Real-user signal
  on what feels *natural* is worth more than designer-intuition picks.

## Sequencing recommendation

Post-launch, demand-driven. Specifically:

- **NOT before M035 closes.** Don't change install topology mid-launch.
  M035 P02–P06 publishing pipelines need to ship against a stable shape.
- **NOT before a real-outside friendly-tester pass against the
  pre-flight-warning UX completes.** The whole question of "is the
  invasiveness still a blocker after the warning" only resolves with at
  least one cold-start outsider walking the install and reporting back.
- **THEN, IFF first real testers still bounce off the in-tree footprint
  after the warning** — promote this proposal to a milestone. Suggested
  slot in the post-launch fast-follow queue (per CLAUDE.md "Forward
  Roadmap"): between **M009 (multi-runtime parity audit)** and **M010
  (Managed Agents + Codex Cloud)**. M009 is the natural absorption
  candidate — see below.
- **IF first real testers don't bounce** — file as `won't-fix` (the
  warning was sufficient) or fold the residual cleanup into M009, which
  already does runtime topology work for non-CC backends.

## Natural absorption candidate: M009

M009 (post-launch multi-runtime parity audit) already plans to touch
runtime topology — Codex CLI and Cursor have their own cache / instruction
conventions (`~/.codex/...`, Cursor's settings dir), and the parity audit
necessarily addresses "where does the runtime live per backend." That is
the same conversation as this proposal's "where does the cache live."

If this proposal gets promoted, the cleanest path may be a **scope
extension to M009** rather than a standalone milestone — M009 is already
going to authorize per-runtime path resolvers, and out-of-tree footprint
is a generalization of that work.

## Cross-references

- **Mitigation commit**: `852416b4` (M033 friendly-tester UX: warm
  welcome + `--help` + pre-flight + actionable migrate dead-end)
- **Friction source**:
  `tests/m033-acceptance/friendly-tester-pass/reports/2026-05-09-maintainer-advisory.md`
  — the friendly-tester advisory report that surfaced the 9-item footprint
  as F8/F9 blockers
- **Related deferred work**:
  [`.orchestrator/proposals/post-launch-wiki-ux-and-adapters.md`](../proposals/post-launch-wiki-ux-and-adapters.md) — also
  touches wiki topology; would intersect on the `wiki/` cache-or-in-tree
  question
- **Constitution**: Principle XVI (Distribution Surface Integrity) — if
  amended per [`.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`](../proposals/constitution-amendment-inclusion-criteria.md),
  this proposal becomes a direct compliance test of that principle (the
  install footprint *is* the distribution surface)
- **M009** (post-launch multi-runtime parity audit) — natural absorption
  candidate per § "Natural absorption candidate" above
- **M035-packaging-distribution** —
  [`.orchestrator/proposals/M035-packaging-distribution.md`](../proposals/M035-packaging-distribution.md). P06
  (`orchestrator:update`) is built on in-tree install assumptions; any
  out-of-tree refactor must compose with whatever P06 ships.

## Open questions

- **Where exactly does the runtime cache live?**
  `~/.claude/projects/<slug>/runtime/` keeps it adjacent to Claude Code's
  existing project-state directory.
  `$XDG_CACHE_HOME/orchestrator/<project-hash>/` is more conventional for
  a CLI tool. Per-runtime (`~/.claude/...` for CC, `~/.codex/...` for
  Codex CLI) keeps each runtime self-contained but duplicates the cache;
  cross-runtime (`~/.config/orchestrator/...`) shares the cache but
  introduces lock contention.
- **How does `orchestrator:update` (M035 P06) interact with a
  cache-dir runtime?** Single-source-of-truth question: when the project
  pins runtime version `v0.9.4` but the cache has `v0.9.5`, who wins?
  Auto-upgrade, auto-downgrade, prompt, or refuse? Version-drift becomes
  a new failure mode that doesn't exist today (because today, in-tree IS
  the runtime).
- **Migration path for already-installed projects.** PBJ-central,
  lakeledger, and bbt-companion already have the 9-item in-tree shape.
  Options: (a) in-place rewrite (orchestrator detects old shape, moves
  runtime to cache, leaves in-tree shim that warns); (b) parallel-install
  with deprecation (old shape keeps working, new shape recommended for
  new installs); (c) tooling-assisted migration (`orchestrator:migrate
  --to=cache-runtime` one-shot command).
- **Does `--with-wiki` change shape?** `wiki/` is currently in-tree
  because the wiki *is* the project's view — readers of `wiki/docs/`
  expect to find the project's content there, not in a tool cache. Does
  `wiki/` stay in-tree as a deliberate exception (only `commands/` /
  `references/` / `scripts/` / `templates/` move out), or does the wiki
  also go to the cache and serve from there?
- **What about `tests/`?** Today the orchestrator's own test suite lives
  in-tree because dogfooding-self-as-runtime is the development workflow.
  In a cache-runtime shape, do consumer projects get a `tests/` directory
  at all? Probably not — but the dogfooding-self-as-runtime path needs to
  keep working, so the resolver shim's "fall back to in-tree when env
  var unset" behavior is load-bearing.

## What unblocks taking this on

- **M035 close** (specifically P06) — establishes the post-launch install
  shape this proposal would refactor against.
- **At least one cold-start friendly-tester run** against the
  pre-flight-warning UX (commit 852416b4), reporting whether the
  invasiveness still feels blocking after the warning is in front of them.
- **Demand signal** — at least one real user (PBJ team member, lakeledger
  consumer, or new pilot) saying "the install footprint is keeping me
  from adopting" after seeing the warning. Without that signal, the
  refactor is speculative.
