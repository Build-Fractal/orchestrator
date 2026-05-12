# Proposal: M041 — `scripts/wiki/` framework-owned carve-out

**Captured**: 2026-05-12 from PBJ-central wiki-decorator iteration cycle (3 rounds, V1.0 → V1.3, commits `fe893b11` upstream / `fa19147` PBJ-side).
**Shape**: Post-launch fast-follow, demand-driven. Sized ~M037-P02-tier (single milestone, 6–10 SCs, ~1 week).
**Predecessors**: M035 packaging-distribution (closed 2026-05-09 — established the installer-owned vs operator-owned classification that this proposal refines). M037 wiki team-feedback-ready (closed 2026-05-07 — shipped the wiki tooling whose iteration friction motivates the carve-out).
**Source**: PBJ live dogfood. PBJ raised this directly as Ask #4 in their 2026-05-12 regression report after running `orchestrator:update` and observing the installer skip `scripts/` as `oracle=operator-owned result=skip-operator-owned`. PBJ's framing: customer-visible-output producers under `scripts/wiki/` are framework-provided tooling, not operator-authored project scripts. Wholesale operator-owned classification on `scripts/` is too coarse.

## Why this is post-launch (not pre-launch)

The launch event shipped 2026-05-09 (M035). PBJ has a working manual-`cp` bridge documented in their `reference_wiki_decorator_verification.md` memory. The friction is real but tolerable. Pre-launch dogfood signal (PBJ) is the only consumer hitting this; broader signal arrives after launch. Sizing the milestone correctly requires understanding which other `scripts/*` subdirs deserve similar carve-outs — that question only resolves with the second and third downstream consumers in play.

## Driving context — DR-WIKI-CYCLE-005

PBJ-central commit history records a silent-regression incident where a `scripts/wiki/wiki-decorate-build.py` edit (in a gitignored file under wholesale `scripts/` ignore) drifted between upstream framework and PBJ-local mirror, with no `git status` or PR-review signal. PBJ's defense was to narrow their `.gitignore` to track 5 customer-visible wiki scripts (PBJ commit `480e8b9`). That's the right fix on the PBJ side, but it doesn't address the upstream-iterate-downstream-gets-it failure mode at framework level.

The 3-round V1.x cycle (2026-05-12) made the lifecycle pain concrete:
- 0/10 → 3/10 → 5/10 → 10/10 baseline-parity trajectory.
- Each round required PBJ to manually `cp` the upstream candidate over their tracked mirror, run live-corpus verification, report regressions, then revert if non-empty.
- The friction was tolerable because the cycle was bounded (3 handoffs). For ongoing wiki tooling iteration (V1.4, V2.0, ...), the manual-`cp` step becomes ergonomic dead weight.

## Goal

After M041 ships, framework-provided `scripts/wiki/*` files auto-update via `orchestrator:update` like commands/, skills/, templates/, and references/ already do. Operator authority over local edits is preserved via an explicit opt-in override sidecar — operators who legitimately fork a framework script declare it, and the installer respects the declaration.

Three concrete invariants:

1. **Default-update**: `scripts/wiki/*` is framework-owned by default. `orchestrator:update` overwrites it.
2. **Explicit-opt-out**: operator declares forks via `.orchestrator/operator-owned-overrides.txt` (or similar sidecar). Listed paths are preserved verbatim across updates. Sidecar is project-owned and committed; not regenerated.
3. **Drift visibility**: when an operator fork is declared, `orchestrator:status` or `orchestrator:doctor` reports the fork existence + last upstream SHA the fork diverged from, so operators can audit cumulative drift without surprises.

## Strict scope

This is **per-file ownership classification refinement**, not:

- **A general scripts/ refactor.** Other `scripts/*` subdirs (`dispatch/`, `verify/`, `state/`, etc.) stay operator-owned in this milestone. Per-subdir classification is M041 follow-on once second/third downstream consumers signal which subdirs they need iteration on.
- **A new installation mechanism.** Existing installer machinery (`install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`) gets the new classification; no new install flow.
- **A general fork-management UX.** The `operator-owned-overrides.txt` sidecar is the minimum viable shape. Listing/editing it stays a manual operator action; no special-purpose CLI.
- **Retroactive cleanup of PBJ's local fork posture.** PBJ already tracks upstream verbatim at their `fa19147`. This milestone removes the manual-`cp` requirement for future updates; it doesn't reach back to fix historical artifacts.

## Phase breakdown (preliminary)

### P01 — Per-file ownership classification

- New oracle `scripts-wiki-framework-owned`: returns `result=overwrite` for files under `scripts/wiki/`, gated by absence from `operator-owned-overrides.txt`.
- Wire into `install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh` — three identical changes.
- `operator-owned-overrides.txt` sidecar: line-per-path, comment-prefix support, project-relative.
- Acceptance: `orchestrator:update` on a project with no overrides file replaces `scripts/wiki/wiki-decorate-build.py` with upstream. Same project with `scripts/wiki/wiki-decorate-build.py` listed in the sidecar preserves the file byte-identical.

### P02 — Drift visibility

- `orchestrator:status` headline-block extension: if `operator-owned-overrides.txt` exists and lists files, surface count + first-3 paths in the status block.
- `orchestrator:doctor` per-fork audit: for each listed file, compute upstream `sha256` at HEAD vs local; report drift.
- Per-file metadata in `.orchestrator/install-meta.txt`: `fork_origin_sha` (the upstream SHA the fork was last reconciled against) — populated when operator adds a file to the overrides list.

### P03 — Rollback story integration

- M035 rollback flow (`install-claude-code.sh --rollback`) preserves fork declarations across rollback. Files in `operator-owned-overrides.txt` are NOT touched by rollback restore (since they're operator-owned). `unit_close` JSONL emission records fork-skip count.

### P04 — Friendly-tester pass

- One greenfield project + one existing-project flow exercised against the four init branches. Tester runs `orchestrator:update`, edits a `scripts/wiki/*` file, adds it to overrides, re-runs update, verifies preservation.
- Same as M033 friendly-tester pass posture: requires a human tester not familiar with orchestrator.

## Acceptance criteria (preliminary)

- SC-1: Framework iteration on `scripts/wiki/wiki-decorate-build.py` reaches a downstream project via `orchestrator:update` with zero operator intervention.
- SC-2: Operator-declared fork survives `orchestrator:update` byte-identical.
- SC-3: `orchestrator:update` on a clean install (no overrides) is idempotent — running twice produces no second-pass changes.
- SC-4: `orchestrator:status` surfaces fork count if non-zero.
- SC-5: `orchestrator:doctor` per-fork audit returns SHA-precise drift state.
- SC-6: M035 rollback flow honors overrides.
- SC-7: All three runtime installers (CC/Codex/Cursor) honor the carve-out identically.
- SC-8: Per-runtime acceptance battery green.
- SC-9–10: Friendly-tester pass on greenfield + existing-project flows.

## Open questions

- **#Q-1**: Should `scripts/wiki/` carve-out also include `scripts/wiki/*.sh` (the non-Python helpers — `wiki-generate-stubs.sh`, `wiki-generate-nav.sh`, `wiki-deploy.sh`, `wiki-milestone-titles.sh`)? PBJ's gitignore narrowing already tracks all 5; M041 should match that scope.
- **#Q-2**: Sidecar location — `.orchestrator/operator-owned-overrides.txt` vs `.orchestrator/install-overrides.txt` vs `.orchestrator/operator-forks.txt`? The first is most descriptive but longest. Defer to operator preference at planning time.
- **#Q-3**: Glob support in sidecar? `scripts/wiki/*.py` rather than per-file. Open — adds complexity but matches gitignore patterns familiar to operators.
- **#Q-4**: Should installer warn at install time when an override is declared for a file that no longer exists upstream (operator-fork-of-deleted)? Probably yes — silent acceptance is a footgun.

## Sequencing — post-launch fast-follow queue position

Per CLAUDE.md "Forward Roadmap" post-launch queue, M041 slots between:

> M009 (multi-runtime parity audit) → M023 (design layer) → M034 (interactive review gates) + M038 (living documents) + M040 (ambient feedback loop) [grouped demand-driven slot] → **M041 (scripts/wiki/ carve-out)** → M036b (reference-corpus post-launch slice) → wiki-ux-deep + external-tool-adapters → M010

Or earlier if PBJ-style downstream iteration becomes a recurring pattern. The demand signal is "downstream consumer hits manual-`cp` friction again." If that happens twice more before the queue reaches M041's natural position, promote.

## Relationship to `.gitignore` narrowing handoff

PBJ's `scripts-gitignore-narrowing-2026-05-12.md` handoff was closed as NO-OP upstream (the orchestrator-emitted `.gitignore` template doesn't wholesale-ignore `scripts/`). M041 makes the gitignore-narrowing posture *unnecessary* — once `scripts/wiki/` is framework-owned and reliably updated, PBJ's defensive tracking of 5 wiki scripts becomes load-bearing only as a regression detector, not as a fork-preservation mechanism. Operators can choose to drop the narrowing after M041 ships; PBJ has indicated they'll keep it for the regression-detector value.

## Brief authoring posture

This brief is captured pre-`orchestrator:specify` so the context is durable while fresh. Promotion to formal milestone follows the standard proposal-lifecycle posture: deliberate, not automatic. When queue reaches M041, this brief feeds into `orchestrator:specify` for spec authoring.
