---
schema_version: "1.0"
type: proposal
status: pending
priority: high (blocks PBJ wiki-deploy correctness; M035 pre-launch slot)
captured_at: "2026-05-07"
captured_by: "PBJ-central downstream agent (M037 round-5 dogfood)"
folds_into: "M035 P00/P01 (Layer 1 stub-freshness diagnostic) + M035 P00/P01 install-template (Layer 2 Pages-deploy notification)"
relates_to:
  - ".orchestrator/proposals/papercut-sweep-wiki-deploy-2026-05-07.md (Finding 2 — wiki-deploy reports OK without verifying Pages rebuilt; same notification-gap surface)"
  - ".orchestrator/proposals/M037-fr-12-17-deferred-scope.md (post-launch wiki polish — Layer 1 strictly pre-launch, not deferrable)"
---

# Paper-Cut: wiki-stub freshness gap allows mkdocs silent failure when planner renames a task plan

## Finding (PBJ-central round-5 dogfood, 2026-05-07)

`orchestrator:plan-phase` re-planning of PBJ-central P02 (commit `8c7c7da`) renamed `T03-cli-entrypoint-and-verifiers` → `T03-cli-and-verifiers` in `.orchestrator/`. The committed wiki stub at `wiki/docs/<…>/T03-cli-entrypoint-and-verifiers.md` still pointed at the **old** canonical path. The Pages workflow on that commit failed silently at `mkdocs build` with:

```
No files found including '.../T03-cli-entrypoint-and-verifiers-PLAN.md'.
```

The deployed site was therefore stuck at the round-4 state from the prior day — **including** missing the round-5 `navigation.sections` drop landed earlier today — and only today's stub regen unblocked it. This is the exact silent-failure mode the PBJ-team-this-week deadline cannot afford.

## Two layers (separate fix shapes, same incident)

### Layer 1 — Orchestrator-owned: `wiki-stubs-fresh.sh` diagnostic + pre-build gate

**Surface area**: `scripts/diagnostics/wiki-stubs-fresh.sh` (new) + install-template `.github/workflows/pages.yml` (gate wiring) + optional fold into `commands/verify.md`.

**Fix shape**:

1. **New script `scripts/diagnostics/wiki-stubs-fresh.sh`** — runs `wiki-generate-stubs.sh` + `wiki-generate-nav.sh` against a tmp dir, diffs against `wiki/docs/` + `wiki/mkdocs.yml`. Exit non-zero on drift with a clear message naming the drifted files and the fix (`run scripts/wiki/wiki-generate-stubs.sh && scripts/wiki/wiki-generate-nav.sh && git add wiki/`).
2. **Install-template `.github/workflows/pages.yml` pre-build gate** — call `bash scripts/diagnostics/wiki-stubs-fresh.sh` before `mkdocs build`. Failure surfaces as "stubs are stale, run regen + commit" rather than the cryptic mkdocs include-markdown error.
3. **Local pre-push convention** — same script invokable before push. Optional fold into `orchestrator:verify` for milestone-grain assurance.

**Why this preserves [M012](../milestones/M012/index.md)'s pattern**: stubs stay committed (no auto-commit, no derived-artifact drift between local serve and deploy). The diagnostic *catches* drift loudly rather than papering over it.

**Severity**: medium-high. Bites every plan-phase that renames a task plan (which happens whenever a plan is amended after stubs ship). Today's incident on PBJ-central blocked an entire day of round-5 visibility. Pre-launch consequence: the very pattern we expect adopters to use (plan → ship wiki → iterate plan) silently breaks the wiki view.

**Acceptance**:
1. **Given** a plan-phase rename of an existing task plan, **When** the next CI Pages build runs, **Then** the build fails with a "wiki stubs stale" message that names the drifted file and the regen command (not the cryptic mkdocs include error).
2. **Given** stubs are in sync, **When** the diagnostic runs locally or in CI, **Then** exit 0 and no diff output.
3. **Given** an operator runs `bash scripts/diagnostics/wiki-stubs-fresh.sh` before push, **When** there is drift, **Then** the diagnostic prints the same drift report shape as the CI gate and exits non-zero.

**Folds into**: [M035](../milestones/M035/index.md) P00 or P01 — composes naturally with the `--mode=symlink` install + version-drift warning pre-launch dev-ergonomics scope. Layer 1 is **strictly pre-launch**, not deferrable: PBJ-central's daily wiki cadence is the exact dogfood loop [M037](../milestones/M037/index.md) was supposed to enable, and this paper-cut directly contaminates that loop.

### Layer 2 — Install-template-owned: Pages-deploy failure visibility

**Surface area**: install-template `.github/workflows/pages.yml` (notification block).

**Finding**: The failed Pages run for `8c7c7da` produced no operator-visible notification — only surfaced because PBJ ran `gh run list` by happenstance. Under normal use the wiki silently stays stale until someone notices.

**Fix shape**: smaller and arguably outside orchestrator runtime — a notification surface in the install-template's `.github/workflows/pages.yml`. Concretely:

1. **GitHub Actions failure annotation** on the failing step (already supported by GHA — set `continue-on-error: false` + use `actions/github-script` or `mikepenz/action-junit-report`-style annotation to emit a checkrun failure with a non-cryptic title).
2. **Optional `notification:` block** keyed on workflow_run conclusion=failure that posts to a configurable webhook (Slack/Discord) declared in install-template `secrets`. Default-disabled, opt-in via a `wiki.pages_failure_notify:` config key paralleling existing wiki options.
3. **Documentation** in `references/installation.md` (or `wiki/docs/HOW-TO/wiki-deploy.md` already shipped by M037) calling out that operators should subscribe to GitHub workflow failure notifications for the Pages workflow until L2 ships. (Layer 2 is lower priority than Layer 1; L1 catches drift *before* Pages runs, which is the load-bearing case.)

**Severity**: medium. Composes with `papercut-sweep-wiki-deploy-2026-05-07.md` Finding 2 (wiki-deploy reports OK without verifying Pages rebuilt) — same notification-gap surface from a different direction. Both fix the "operator does not learn that the deployed wiki is stale."

**Folds into**: M035 P00/P01 install-template hardening, or stays standalone as install-template paper-cut depending on M035 plan-phase scope decision (`#Q-G2`-adjacent — this is install-template scope, not packaging-channel scope).

## Why a paper-cut, not a milestone amendment

Layer 1 is ~1 script + a workflow gate line + ~1 acceptance test fixture. Layer 2 is ~1 workflow annotation + optional config key. Neither warrants a new milestone or a spec amendment to M035 (which is already at Pass 3 BLOCK with five P0 mitigations queued). The natural integration is folding into the M035 P00/P01 pre-launch dev-ergonomics scope at `orchestrator:discuss` time — surfaced via `/orchestrator-discuss` Open Questions so the roadmap step picks it up.

## Originating context

- **Incident commit**: PBJ-central `8c7c7da` (Pages build failed silently)
- **Affected change**: M037 round-5 `navigation.sections` drop (collapsible-drawer left-nav refresh) — invisibly stuck at round-4 wiki state
- **Surfacing route**: PBJ downstream agent caught it via `gh run list` and reported upstream
- **Today's unblock**: stub regen + push (manual, not gated)

## Questions for `/orchestrator-discuss` Open Questions block

- **Layer 1 placement**: M035 P00 (baseline-hardening alongside US-3 bash 3.2 exit-code fix and US-4 installer `.gitignore`) vs. P01 (alongside US-1 `--mode=symlink` and US-2 drift warning)? P00 has stronger thematic fit (CI/install integrity); P01 has stronger sequencing fit (lands with wiki-deploy-relevant operator-facing changes).
- **Layer 2 ownership**: M035 P00/P01 install-template scope, or peel out as an install-template-only paper-cut tracked alongside `papercut-handoff-wiki-publishing-robustness-2026-05-07.md`?
- **`orchestrator:verify` integration**: fold the Layer 1 diagnostic into `commands/verify.md` for milestone-grain assurance (`scripts/diagnostics/wiki-stubs-fresh.sh` becomes a verify-tier check), or keep it CI-gate-only?
