---
schema_version: "1.0"
type: proposal
status: pending
priority: high
captured_at: "2026-05-06"
captured_by: "M037/P01/T06 executor (during plan-step path resolution check)"
folds_into: "M035 P02–P06 (packaging & distribution, pre-launch)"
---

# Paper-Cut: `packaging/bundle/config/orchestrator.default.yml` is a hand-authored 12-line stub, not a copy/symlink of `templates/orchestrator-config-default.yml`

## Finding (M037/P01/T06 surfaced)

`packaging/bundle/config/orchestrator.default.yml` (the bundle-staged copy of the orchestrator's default config consumed by all three installers via `cfg_src="$BUNDLE/config/orchestrator.default.yml"`) is a **hand-authored 12-line stub**, not a copy or symlink of the canonical **175-line** `templates/orchestrator-config-default.yml`. Verified by the T06 executor:

```
$ diff packaging/bundle/config/orchestrator.default.yml templates/orchestrator-config-default.yml
1,175c1,12
< [175-line canonical template …]
---
> [12-line bundle stub …]
```

The stub appears to predate [M037](../milestones/M037/index.md) (no recent commit touched it) and predates the convention of using `templates/orchestrator-config-default.yml` as the single source of truth for installer defaults.

## Practical impact

**T01's `wiki: landing_cards: []` schema entry does NOT reach consumer projects via the install bundle today.** The yaml-merge primitive shipped by T06 (`scripts/lib/yaml-merge.sh`) cannot introduce a top-level namespace the bundle's framework-default doesn't declare:

- Greenfield install (`orchestrator:init` on a fresh project) → consumer's `.orchestrator/config.yml` reflects whatever's in the 12-line stub, **not** the 175-line canonical template. Operator never sees the `wiki:` block, never gets the `landing_cards:` schema, can't customize their card-grid homepage without manually authoring the namespace.
- Refresh install (consumer running `orchestrator:update` against an existing `.orchestrator/config.yml`) → the merge primitive's framework-default arg is the 12-line stub, so the merge cannot append the `wiki:` namespace as a "new orchestrator-managed default" (one of the three plan §32-35 cases).
- Same problem applies to every other namespace added since the 12-line stub was last refreshed: `wiki:`, possibly others depending on what's in the stub vs. canonical.

The orchestrator's self-application path is unaffected (target == bundle stub on this repo would mean the orchestrator's own `.orchestrator/config.yml` would be a 12-line subset, but in practice the orchestrator's config is operator-curated, not bundle-derived). The blast radius is **consumer-project install/refresh paths only**.

## Why this is now blocking

PBJ-central is the live dogfood signal for M037 (and the rest of the orchestrator's pre-launch validation). The PBJ team is opening their wiki **this week** per the M037 brief. If they install the orchestrator via `packaging/install/install-claude-code.sh` AFTER [M035](../milestones/M035/index.md) ships (the package-manager publishing event), they will not see the `wiki: landing_cards:` schema in their `.orchestrator/config.yml` — the central declarative surface for customizing their wiki homepage. They'd have to hand-author the namespace from documentation.

This wasn't blocking pre-M037 because no consumer-facing schema additions had landed since the stub was last touched. M037's `wiki:` block is the first consumer-visible namespace gap.

## Options

### Option A — Symlink the bundle stub to the canonical template (smallest fix)

```bash
rm packaging/bundle/config/orchestrator.default.yml
ln -s ../../../templates/orchestrator-config-default.yml \
       packaging/bundle/config/orchestrator.default.yml
```

**Pros**: One-line fix; canonical template is now the single source of truth; future schema additions in `templates/` automatically reach the bundle.

**Cons**: Symlinks may not survive bundle packaging (depends on M035's tarball/npm publish path — symlinks across `npm pack` boundaries get followed and de-symlinked, which is fine; symlinks across `git archive` are preserved as symlinks, which may break for consumers extracting via curl-pipe-bash). Verify M035's bundle staging treats symlinks correctly before adopting.

### Option B — Replace the stub with a `cp` of the canonical template (low-risk fix)

```bash
cp templates/orchestrator-config-default.yml \
   packaging/bundle/config/orchestrator.default.yml
```

**Pros**: No symlink concerns; identical bytes on disk in the bundle; portable across all packaging pipelines.

**Cons**: Two copies of the same file; future schema additions in `templates/` require a parallel update to the bundle copy (drift risk). Mitigation: add a `tools/verify/m0XX-bundle-config-mirror.sh` verifier that asserts the two files are byte-identical, run as part of M035's pre-publish checks.

### Option C — Build step that materializes the bundle stub from the canonical template (M035 P00 deliverable)

Add a `packaging/bundle/build-bundle.sh` step (the existing bundle build script) that copies `templates/orchestrator-config-default.yml` → `packaging/bundle/config/orchestrator.default.yml` immediately before tarball/npm publish. The on-disk stub becomes a build-time artifact, not a checked-in file.

**Pros**: Single source of truth in `templates/`; no manual sync required; idiomatic build-step approach.

**Cons**: Requires `build-bundle.sh` modification; the stub is still checked in (or moved to a generated path). M035 P00 is the natural home for this work — the proposal lives at [`.orchestrator/proposals/M035-packaging-distribution.md`](../proposals/M035-packaging-distribution.md) and the gap fits cleanly into its scope.

## Recommendation

**Option C** (build-step materialization in M035 P00) is the right architectural fix. **Option B** (cp + verifier) is the right immediate-mitigation if M035 P00 won't ship before the PBJ-team install window opens.

Decision deferred to M035 P00 entry. If the PBJ team installs the orchestrator pre-M035, surface this as a known limitation in the install README until the build step lands.

## Surface-back hooks

- **M035 P00 plan-time**: must consume this paper-cut as a load-bearing finding; either resolves Option B (immediate) or Option C (architectural) and ships a verifier (`m035-pXX-bundle-config-mirror.sh` or equivalent) asserting the bundle stub matches the canonical template byte-identical.
- **M037 P02 plan-time** (when it enters the queue): must check this paper-cut's status. If still pending, either skip schema additions to `templates/orchestrator-config-default.yml` until M035 lands OR explicitly note in the P02 plan that consumer-project install paths are gapped pending M035.

## Cross-references

- [`.orchestrator/proposals/M035-packaging-distribution.md`](../proposals/M035-packaging-distribution.md) — the natural home for the architectural fix.
- [`.orchestrator/milestones/M037/phases/P01/tasks/T06-yaml-merge-and-install-emission-SUMMARY.md`](../milestones/M037/phases/P01/tasks/T06-yaml-merge-and-install-emission-SUMMARY.md) — surfaces this finding inline.
- [`.orchestrator/milestones/M037/phases/P01/P01-SUMMARY.md`](../milestones/M037/phases/P01/P01-SUMMARY.md) — affects-downstream entry calls out the M035 dependency.
- `templates/orchestrator-config-default.yml` — canonical template, 175 lines.
- `packaging/bundle/config/orchestrator.default.yml` — 12-line stub on disk.
- `packaging/install/install-claude-code.sh:429` (and parallel in `install-codex.sh`, `install-cursor.sh`) — consumer of `cfg_src="$BUNDLE/config/orchestrator.default.yml"`.
