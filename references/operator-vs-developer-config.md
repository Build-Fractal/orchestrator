# Operator vs Developer Config — the Subtraction Asymmetry

**Audience**: Anyone touching `orchestrator-config.yml`, runtime
detection, `ORCHESTRATOR_ROOT` resolution, hook configuration,
installer scripts, or any surface that lets one party constrain
another party's behavior.

**Captured**: 2026-04-27 (proposal:
`.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`
Change 4).
**Ratified**: 2026-05-11 (Path 1 ratification of the Tier 2 XXII + XII
inheritance amendment; this doc is one of two Change 4/6 reference
artifacts that land alongside the constitution v2.2.0 bump).

## The asymmetry, stated

The orchestrator carries two distinct configuration audiences whose
authority is **not symmetric**:

- **Developers** (those building orchestrator features, milestone
  authors, hook authors, plugin authors, recipe authors) MAY **extend**
  the orchestrator's tool surface. They add commands, scripts,
  templates, hooks, knowledge entries, and runtime adapters. New
  capabilities flow in through this surface.

- **Operators** (those running the orchestrator on their own project,
  via Claude Code / Codex CLI / Cursor) MAY **restrict** the
  orchestrator's tool surface. They set environment variables, scope
  `ORCHESTRATOR_ROOT`, disable hooks, narrow runtime detection,
  filter the active capability profile. They do not add new
  capabilities.

> **Plugins and skills extend. Operators filter.**

## Why the asymmetry matters

If operators could *extend* the orchestrator's tool surface from
their `.env` or config knobs, two failure modes appear immediately:

1. **Capability drift across projects.** Two orchestrator users
   running the "same" milestone would dispatch against subtly
   different tool surfaces — one with an extra hook, another with
   an extra runtime adapter. Verification scripts, knowledge graphs,
   and reproducibility guarantees would all hold only relative to
   the local extension surface. Constitution Principle IX
   (Reproducibility Over Convenience) would erode silently.

2. **Supply-chain attack surface.** A malicious project-local
   config could register a hook that runs during every dispatch
   without ever editing the orchestrator's installed surface. The
   installer's signed artifact integrity (`Tier 2 XXII Distribution
   Surface Integrity`, inherited 2026-05-11) would not catch this
   because the extension would not pass through the installer.

The asymmetry closes both modes: extensions must land in the
orchestrator's developer surface (where they're versioned,
reviewable, signed at distribution, and visible to every operator);
operator overrides may only *narrow* what the orchestrator does on
their machine.

## What each audience can touch

### Developer-extensible surfaces (extend authority)

- `commands/*.md` — adds skills.
- `scripts/**/*.sh` — adds helpers.
- `templates/**` — adds recipes, schemas, contracts.
- `references/**`, `docs/**`, `knowledge/**` — adds documentation
  and structured knowledge nodes.
- `hooks/*.yml` (developer-installed) — adds default lifecycle hooks
  that ship with the runtime.
- `packaging/bundle/<runtime>/manifest.txt` — declares what ships in
  each installable bundle (`Tier 2 XXII`, force-include discipline).
- `scripts/dispatch/adapters/backend/*.sh` and
  `scripts/runtime/<runtime>/` — adds dispatch + runtime adapters.

### Operator-restrictable surfaces (filter authority)

- `.env` / shell environment — `ORCHESTRATOR_ROOT`,
  `CONVERSUS_PROVIDER`, `ORCHESTRATOR_TIER2_LIVE`, intensity
  overrides, capability-profile narrowing.
- `.orchestrator/config/orchestrator-config.yml` (operator-edited
  copy of `templates/orchestrator-config-default.yml`) — knob values
  only, never knob *registration*. Adding an unrecognized key is a
  no-op (and `scripts/diagnostics/check-dead-infra.sh` flags it).
- `.claude/settings.json` / `.codex/...` / `.cursor/...` — operator
  may deny permissions, narrow tool allowlists, disable individual
  hooks.
- `--profile=quick|standard|full` and intensity-recommend overrides
  — operator picks a less-expensive process tier; they cannot pick
  one above what their capability profile supports.

## Mechanical consequences

1. **Config-knob registration is developer-only.** New keys in
   `templates/orchestrator-config-default.yml` ship through the
   orchestrator's distribution surface, not through operator
   config. `check-dead-infra.sh` enforces this: an operator-only
   key would either not be read anywhere (caught as dead infra) or
   would be silently ignored by the runtime (caught as no-op drift).

2. **Hook registration is developer-only.** Hooks listed in
   `hooks.yaml` come from the developer surface. Operator
   restriction lives in the runtime's settings (Claude Code
   `settings.json` `permissions`, Codex CLI denylists). An
   operator-added hook that ran without developer review would
   violate constitution Principle XII (Hook Isolation).

3. **Installer signing covers the developer surface only.** Tier 2
   XXII's force-include discipline guarantees every shipped artifact
   appears in a manifest. Operator-side overrides happen *after*
   installation and are not signed by the orchestrator — they're
   the operator's local responsibility.

4. **Capability detection is one-directional.** Probes in
   `scripts/lifecycle/init-project.sh` and the
   capability-profile resolver detect what the operator's runtime
   *can do* and *narrow* the orchestrator's behavior to that
   subset. They never *expand* the orchestrator's behavior on the
   basis of detected operator capability (e.g., "this machine has
   X tool, so let's start using it" — wrong: developer authors X-
   tool support deliberately, then ships it).

## Worked example — M025 installer coexistence

M025 (closed 2026-04-23) surfaced this asymmetry concretely. The
installer carried a `--force` flag that operators could pass to
overwrite an existing orchestrator installation. The flag *narrows*
the installer's safety guard (a developer-shipped check); it does
*not* add a new install mode. The same surface intentionally does
**not** carry an `--also-install <plugin>` flag, because such a flag
would let an operator extend the orchestrator's tool surface from
the installer side — bypassing the developer-side review the
orchestrator's distribution surface depends on.

When future milestones (e.g., M010 Managed Agents + Codex Cloud)
introduce hosted dispatch backends, this asymmetry should be the
first design constraint applied: hosted backends are developer-side
adapters (extension); operator-side knobs select which adapter to
use (filter).

## See also

- `.orchestrator/memory/constitution.md` Principle IX (Reproducibility
  Over Convenience), Principle XII (Hook Isolation), VIII (No Dead
  Infrastructure).
- [`CONFORMANCE.md`](../CONFORMANCE.md) § Component-tier declarations
  — Tier 2 XXII (Distribution Surface Integrity) inheritance row +
  conversus Tier 2 XII (No Dead Infrastructure) inheritance row +
  three-bucket structure.
- `references/installation.md` — installer surface contract.
- `scripts/lifecycle/init-project.sh` — capability detection.
- `templates/orchestrator-config-default.yml` — canonical config-knob
  registry.
