---
schema_version: "1.0"
type: context-draft
milestone: "M032"
status: finalized
created_at: "2026-05-03"
finalized_at: "2026-05-03"
paired_with: "M033"
session_kind: "combined-paired"
---

## Architectural Decisions

The 11 conversus-mitigation amendments folded into spec 035 (MIT-001..MIT-011) are baseline-locked and not relitigated here. They are the spec's load-bearing surface; this context draft captures the *paired-launch coordination decisions* that operate atop them, plus the M032-specific scope-and-boundary decisions the discussion phase produces.

**AD-1. M032 + M033 ship as one paired-development workstream.** Per the 2026-05-03 launch sequencing amendment and CON-3 (paired-launch contract), M032 and M033 are not sequential. They are one workstream with internal phases that interleave. The Q3 launch-sequencing-amendment open question ("single dispatcher vs. two with handoffs") resolves to **single coordinated workstream with explicit per-seam acceptance gates** (see AD-3). Reasoning: the three load-bearing seams (AD-3) are most cheaply de-risked by exercising them continuously across both milestones' development, not by sequential build-then-integrate.

**AD-2. Milestone-close discipline mirrors M030/M031** — acceptance battery + `M032-VALIDATED` marker + signed attestation for the SC-5 live-deploy skip-vs-pass distinction (per MIT-001's three-category battery format). SC-12's `pass=10 skip=1 fail=0` outcome is acceptable only with a signed attestation in `M032-SUMMARY.md` declaring SC-5 was executed in an authenticated environment and produced pass. The signed-attestation gate IS the M013/M014 counter-pattern (CON-5).

**AD-3. The three load-bearing paired seams are explicitly named and continuously tested.** The CON-3 paired-launch contract identifies three seams that the M033 spec also calls load-bearing in its CON-1:
  - **Seam-A: Shared install-bundle surface.** Spec 035 FR-1 (`project_assets:` schema) is the surface; M033's onboarding flows consume it. Any change to the schema is a paired change.
  - **Seam-B: `--with-wiki` failure-propagation contract.** Spec 035 FR-11 (init-with-wiki passthrough with init-complete-wiki-pending atomicity model) is the contract; M033 spec FR-15 consumes it with explicit two-mode SC-9 testing per M033-MIT-001 (stub mode in M033/P01..P04, real mode in M033/P05). M032/P02's closure unblocks M033/P05's real-mode testing.
  - **Seam-C: `wiki/glossary.md` format.** Spec 035 FR-15 (glossary path convention + scanner integration) is the surface owner; M033 spec FR-18 is the primary writer (grilling-shell writes inline as terms resolve). The file-format contract (alphabetized term entries with one-line definitions and at most two-line elaborations per spec 035 US-6) is shared invariant.
  Continuous integration testing on these three seams is the concrete operationalization of the paired-launch model. See AD-4 for the cadence.

**AD-4. Paired-integration testing cadence = every commit to either spec's milestone branch** (resolves M033 spec #Q-10 in M032's direction). The seams are ~3 thin scripts (one per seam) that run as part of CI for both milestone branches. Failure on any seam is a paired-launch failure that blocks both milestones. Reasoning: the cost of a CI run on three thin scripts is trivial; the cost of discovering a seam-bug at integration time (M033/P05) is high.

**AD-5. FR-6 self-application gate scheduling.** FR-6 templating (spec 035) converts `wiki/mkdocs.yml` to placeholder tokens — without the self-application step (per MIT-002) the orchestrator's own wiki breaks for the duration of paired development. The self-application step ships as part of FR-6's delivery PR (not deferred), AND the M032 FR-6 implementation phase MUST run before FR-7..FR-22 phases that consume the rendered wiki for development preview. Phase ordering: FR-6 + self-application → other wiki tooling extensions. The orchestrator repo's wiki-serve continuity is a CON-3 + CON-5 invariant during paired development.

**AD-6. P00 baseline = reuse the 2026-04-28 PBJ bootstrap session evidence (Findings A-K).** Per spec 035 Assumption A-3, the empirical signal for the 11 mitigations is already on disk from the 2026-04-28 bootstrap session. M032 does NOT add a P00 empirical-baseline phase the way M030/M031 did — the empirical baselining was already paid in the brief. Phase 0 work is the FR-6 self-application + initial bundle migration plumbing (mechanical), not new empirical investigation.

**AD-7. SC-5 throwaway-GH-fixture protocol is a P03 deliverable.** The live-fixture acceptance test (FR-21) requires `gh repo create <ts>-m032-fixture --private` and `gh repo delete <ts>-m032-fixture --yes` teardown. The throwaway-fixture protocol must be documented at `tests/m032-acceptance/throwaway-fixture-protocol.md` with explicit teardown verification (no orphan branches, no leaked `.orchestrator/` files) before SC-5 is considered shippable. P03 is the natural home (FR-9 + FR-10 deploy scope phase).

**AD-8. Constitution Principle XVI compliance is mechanical.** SC-11's `run-doctor.sh` no-warning assertion + SC-11 FR-6 self-application loop closure are the mechanical Principle XVI compliance test. M032 ships under Principle XVI as the asset-distribution surface compliance test (M033 will be the content-authoring compliance test). Both milestones' compliance is asserted at milestone close.

## Scope Boundaries

**In scope** for M032 (and not relitigated):
- All 22 functional requirements FR-1..FR-22 from spec 035 (with FR-22 rewritten per MIT-003 to use the dual-oracle hierarchy).
- All 14 success criteria SC-1..SC-14 from spec 035 (with SC-5/SC-11/SC-12/SC-13/SC-14 amended per MIT-001/002/004/008).
- The 6 spec constraints CON-1..CON-6 (CC-only launch posture, project-owned-vs-staged-dirs invariant, M033-paired-launch contract, no-regression-on-existing-installs, live-fixture-discipline, glossary-load-bearing-for-M033).
- The deferred-from-papercut-sweep spec-side invariant for staged-dirs collision (CON-2 / FR-22).
- The throwaway-GH-fixture protocol (AD-7).
- FR-6 self-application gate (AD-5 / MIT-002).

**Out of scope** for M032 (deferred to other milestones or post-launch):
- All 12 NG-1..NG-12 entries from spec 035 (mkdocs replacement, wiki-content-authoring, search backends, custom domains, Vercel/Netlify/Cloudflare adapters, comment moderation, i18n, auto-creating Giscus categories, Windows symlink mode, direct mkdocs gh-deploy, AGENTS.md bilateral fallback, auto-pip).
- The runtime-targeted-instruction-file scoping bug (NG-11) — separate work; affects M032 + M033 boundary but is not in either's scope.
- The wiki-UX-deep + external-tool-adapters proposal — post-launch fast-follow per CLAUDE.md roadmap.
- M036b reference-corpus wiki projection (P08) — blocked by M032 closure; ships post-launch.
- Post-launch design-layer M023 + multi-runtime parity audit M009 + Managed Agents M010 — all explicitly post-launch per CLAUDE.md roadmap.

**Boundary with M033 (the paired milestone):**
- M032 OWNS: the bundle/install plumbing, `wiki-init.sh` command + scopes, mkdocs/Giscus templating, scanner extensions, glossary path convention + adapter, the `--with-wiki` failure-propagation interface (FR-11).
- M033 CONSUMES: FR-11 from M033's `start --with-wiki` pass-through (M033 FR-15); FR-15 + FR-16 from M033's grilling-shell inline glossary writes (M033 FR-18).
- NEITHER OWNS unilaterally: the integration test scripts on the three load-bearing seams (AD-3) — these are paired-shared artifacts at `tests/paired-m032-m033/seam-*.sh`.

## Design Constraints

- **CC-only launch posture (spec 035 CON-1)**: Codex CLI / Cursor pass-through is in-scope at the bundle/install layer (FR-2 covers all three installers); live `--deploy` testing is CC-only. M009 picks up multi-runtime parity post-launch.
- **POSIX-only symlink mode (NG-9 / FR-3)**: Windows fails closed with clear diagnostic. Aligns with CC-only posture and Constitution XIV (no speculative complexity).
- **Byte-identical migration for existing consumers (CON-4)**: FR-2's migration produces byte-identical install output for every existing consumer at `mode: copy`. The pre-M032 consumer bootstrapping policy (FR-2 / FR-22 / MIT-006) is the load-bearing test of this discipline.
- **Live-fixture discipline (CON-5)**: FR-21 mandates a live throwaway GH repo for the deploy end-to-end test. Direct M013/M014 counter-pattern. The `M032_DEPLOY_PROPAGATION_TIMEOUT` default 90s is a deliberate accommodation of GH Pages propagation latency.
- **Glossary-load-bearing-for-M033 (CON-6)**: FR-15 + FR-16 MUST land in M032 (not deferred to post-launch). Phase placement resolved at clarify (#Q-4 → P02 alongside `wiki-init`).
- **Paired-launch contract (CON-3)**: bidirectional with M033. AD-1..AD-4 codify the operationalization.
- **The 2026-05-15 PBJ pilot deadline drives the M032+M033 paired ship date** (Assumption A-3). The 2026-05-03 launch sequencing amendment trades ~1 week of paired-development overhead + friendly-tester buffer against the higher cost of seam-bugs discovered late.
- **`gh` CLI required for FR-8 + FR-9 + FR-21** (Assumption A-2). Missing `gh` is detected and surfaced; baseline `wiki-init` (default scope) does not require `gh`.
- **Python 3.x + pip3 required at `--with-wiki` time** (FR-12). Missing toolchain emits platform-aware diagnostic. Behavior for absent Python is fail-closed-with-actionable-message; per #Q-2 default is print-install-command-and-exit (with `--auto-pip` opt-in).

## Open Questions

- **#Q-A RESOLVED at finalize-2026-05-03 — M032 closes on its own gate; cross-milestone routing for blockers**: M032's milestone close is conditioned on its own SC-12 + signed-attestation discipline; M033's friendly-tester report is M033's gate. If the friendly-tester surfaces a `friction_blocker` rooted in M032 surface (e.g., `wiki-init --deploy` failure UX), the blocker IS a paired-launch failure that re-opens M032 for the targeted fix. Both milestones' execution logs (FR-22 + spec 035 FR-9 audit-trail) record the cross-milestone routing decision. M033 spec #Q-A mirrored.
- **#Q-B RESOLVED at finalize-2026-05-03 — M032 lands all three seam-test scripts at `tests/paired-m032-m033/seam-{A,B,C}.sh`**; both milestones' CI blocks on their failure (paired-launch invariant). Phase placement: lands alongside M032/P02 (`wiki-init` shipping phase) so the seams are exercisable from M033's first paired-development commit.
- **#Q-C RESOLVED at finalize-2026-05-03 — M032/P02 closure is a hard pre-condition for M033/P05 START** (not just close); M032's roadmap MUST schedule P02 to close at least **1 week before M033/P05 starts** to absorb integration-bug discovery. This binds M032's P02 ship-date to M033's P05 start-date; deviation requires explicit re-coordination of both roadmaps.
- **#Q-D Friendly-tester recruiting (paired with M033 #Q-1) — RESOLVED at finalize-2026-05-03**: maintainer (Brett) recruits 1–2 outsiders by **2026-05-08** via personal network or developer Slack/Discord. If recruiting fails by **2026-05-12**, fall back to `M033_SKIP_FRIENDLY_TESTER_PASS=1` per US-8 AS-5 with documented cold-start risk acknowledged in `M033-SUMMARY.md`. M032 inherits the same gate transitively (per #Q-A).
- **Q2 of launch sequencing amendment (M036a live-LLM smoke test)**: parallel pre-pilot insurance step before 2026-05-08; not in M032's scope but coordinated with the same pilot deadline. Informational here.
- **All 6 of spec 035's Open Questions (#Q-1..#Q-6) are RESOLVED at clarify-2026-05-03 except #Q-6 which is deferred per NG-11**. They do not re-open here unless paired-discuss surfaces a new dimension. None did during this session.
- **All 6 of spec 035's Open Questions (#Q-1..#Q-6) are RESOLVED at clarify-2026-05-03 except #Q-6 which is deferred per NG-11**. They do not re-open here unless paired-discuss surfaces a new dimension. None did during this session.
