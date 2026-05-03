---
schema_version: "1.0"
type: context-draft
milestone: "M033"
status: finalized
created_at: "2026-05-03"
finalized_at: "2026-05-03"
paired_with: "M032"
session_kind: "combined-paired"
---

## Architectural Decisions

The 7 conversus-mitigation amendments folded into spec 036 (MIT-001..MIT-007) are baseline-locked and not relitigated here. They are the spec's load-bearing surface; this context draft captures the *paired-launch coordination decisions* (mirrored from M032-CONTEXT.md AD-1..AD-4 — the paired session resolved both at once) plus the M033-specific decisions the discussion phase produces.

**AD-1. M032 + M033 ship as one paired-development workstream** *(mirrored from M032 AD-1)*. Per the 2026-05-03 launch sequencing amendment + spec 036 CON-1. Single coordinated workstream with explicit per-seam acceptance gates. Three load-bearing seams (AD-2) are de-risked by continuous integration testing across both milestones' development.

**AD-2. The three load-bearing paired seams are explicitly named** *(mirrored from M032 AD-3, restated from M033 perspective)*:
  - **Seam-A: Shared install-bundle surface.** M032 owns spec 035 FR-1 (`project_assets:` schema); M033 consumes it for its own command-shipping needs (M033 ships 7 new commands + 6 new scripts via the same bundle).
  - **Seam-B: `--with-wiki` failure-propagation contract.** M033 spec FR-15 consumes M032 spec 035 FR-11 with two-mode SC-9 testing per M033-MIT-001. **The two-mode contract is the load-bearing M033-side response to the M032/P02-may-not-be-closed-yet reality**: M033/P01..P04 runs SC-9 under `M033_FR15_STUB=1`, M033/P05 runs against the real surface.
  - **Seam-C: `wiki/glossary.md` format.** M033 is the *primary writer* (FR-18: grilling-shell writes inline as terms resolve); M032 owns the path convention + scanner integration (spec 035 FR-15). Format invariant (alphabetized term entries with one-line definitions and at most two-line elaborations) is shared.

**AD-3. Friendly-tester pass on the four init branches is the LOAD-BEARING pre-roadmap requirement.** Per the 2026-05-03 launch sequencing amendment ("the friendly-tester pass on M033's four init branches before lock"). This is **non-negotiable** for milestone close (CON-2 + SC-15 + FR-19). Per the user's explicit request during this paired-discuss session, the friendly-tester pass is surfaced HERE as an explicit pre-roadmap requirement (not merely a SC-15 artifact). Operationalization:
  - Recruit 1–2 outsiders before M033/P01 lock (Q-1 below).
  - The protocol artifact + report template + validate-report.sh ship in P01 (FR-19) so recruiting can begin in parallel with implementation.
  - Each tester walks all four branches, 30 minutes each = ~2 hours per tester.
  - SC-15 mechanically gates `M033-VALIDATED`: `friction_blockers: 0` AND `eligible_testers ≥ 1`, OR `M033_SKIP_FRIENDLY_TESTER_PASS=1` signed-attestation in `M033-SUMMARY.md`.
  - **The tester must NOT be familiar with the orchestrator** (per FR-19 tester-eligibility checklist) — outsiders only; another orchestrator maintainer is excluded.
  - Synthetic test fixtures cannot replace the warm-body signal — this is the launch sequencing amendment's load-bearing claim.

**AD-4. RISK-006 disambiguation-question implementation is in P01 scope** *(resolves disputed RISK-006 per arbiter ruling)*. Per MIT-006, FR-2 rule 3 (`.git/` with ≥1 commit → existing-codebase) routes git-initialized greenfield users to `existing-codebase` silently; the disambiguation-question implementation extension converts the silent routing failure into a visible disambiguation moment. The arbiter ruled that this implementation extension (not just the spec text addition) is the v1 fix. P01 is the natural home (FR-1 / FR-2 phase), AND `M033_FRIENDLY_TESTER_PASS` empirical signal is the post-launch validation for whether rule 3's `.git/` clause needs further narrowing.

**AD-5. MIT-003 PBJ fixture creation is a P01 deliverable, not a P04 deliverable.** Per FR-23 (added per MIT-003): the PBJ acceptance test fixture at `tests/fixtures/m033-pbj-materials-fixture/` MUST exist as a P01 deliverable. Rationale: SC-4 runs `p04-materials-intake.sh` against this fixture; SC-14's `pass=13 skip=0 fail=0` requirement means a missing fixture fails the battery. Fixture construction is curatorial work (~1 day) requiring identification of 5 inconsistency types from the 2026-04-28 PBJ session evidence + synthesis of fixture documents. P01 has the natural slot.

**AD-6. The grilling-shell module (FR-17) is a P02 deliverable shipped before P03/P04/P05's calling commands.** The uniform `ask_one <question> <recommendation> [<context-file>]` API is consumed by FR-3 (constitution-author), FR-9 (materials-intake), FR-10 (ideation), FR-13 (customblock-draft). Shipping the module first means each calling command's implementation is the wiring, not the module re-invention. Per MIT-007, the `[<context-file>]` parameter MUST be wired for live contradiction detection during normal sessions (not only resume) — this is a P02 architectural invariant the calling commands inherit.

**AD-7. M033-VALIDATED gate composition is three-part: SC-14 `skip=0` AND SC-15 friendly-tester verdict AND SC-16 NNN floor.** All three are mechanical (SC-14 from acceptance battery exit code, SC-15 from validate-report.sh, SC-16 from validate-milestone.sh). The signed-attestation escalation paths exist for SC-14 (skip>0 with attestation) and SC-15 (`M033_SKIP_FRIENDLY_TESTER_PASS=1` with attestation), but NOT for SC-16 (NNN floor is non-negotiable per the spec text). This three-part gate IS the launch first-impression promise's mechanical backstop.

**AD-8. The M033 phase shape is 5 phases (P01..P05) plus an artifact-ship in P01.** Brief recommended 5 phases (P00 baseline + P01..P05). P00 baseline reuses the 2026-04-28 PBJ bootstrap session evidence and the 2026-04-29 dogfood addendum (per spec 036 Assumption A-5) — a separate empirical-baseline phase is unwarranted. The friendly-tester PROTOCOL artifact ships in P01 (so recruiting begins in parallel), but the friendly-tester PASS itself runs in parallel with P02..P05 and gates close after P05. Final phase shape is `orchestrator:roadmap`'s call; 5 is the planning starting point.

**AD-9. Constitution Principle XVI compliance is mechanical** *(mirrored from M032 AD-8 in spirit)*. M033 ships under Principle XVI as the **content-authoring** compliance test (M032 was the asset-distribution test). FR-6's standalone-gate verifier (zero `speckit.*` references in any output) is the mechanical enforcement; CON-3 makes the invariant explicit. Both milestones' compliance is asserted at milestone close.

**AD-10. The 7 net-new commands (start, constitution, ingest-codebase, materials-intake, ideation, customblock-draft) inherit M030's adaptive model routing** for surgical-character tasks (Assumption A-4). M030 closure (2026-05-01) is a hard upstream dependency — confirmed satisfied. No M033 work re-litigates model selection.

## Scope Boundaries

**In scope** for M033 (and not relitigated):
- All 23 functional requirements FR-1..FR-23 from spec 036 (FR-23 added per MIT-003).
- All 17 success criteria SC-1..SC-17 from spec 036 (SC-3/SC-5/SC-9/SC-14 amended per MIT-001/002/005/007).
- The 6 spec constraints CON-1..CON-6 (M032-paired-launch contract, friendly-tester-pass load-bearing, standalone-posture-content-authoring, deterministic-not-LLM drift detection, grilling-protocol non-batchable, resume-on-partial-state required).
- The friendly-tester protocol artifact + report template + validate-report.sh (FR-19) shipped in P01 to unblock recruiting.
- The PBJ acceptance test fixture (FR-23 / MIT-003) shipped in P01.
- The disambiguation-question implementation extension for git-initialized greenfield (MIT-006 / RISK-006 arbiter ruling) shipped in P01.

**Out of scope** for M033 (deferred to other milestones or post-launch):
- All 16 NG-1..NG-16 entries from spec 036 — including: knowledge graph schema redesign (M020), bundle/install infrastructure (M032), spec authoring (orchestrator:specify), migration logic (orchestrator:migrate), universal small-task entry (M031), adaptive model selection (M030), AI-magic constitution generation, deep semantic codebase understanding, wiki/GH integration redesign, multi-language i18n, persistent interactive shell, profile-driven onboarding, migration from non-spec-kit/GSD tools, re-onboarding flow, cloud/team onboarding, AGENTS.md bilateral-fallback bug.
- M033.5 codebase-ingestion LLM-augmentation — demand-driven post-launch (per #Q-3).
- Expanded constitution-starter library beyond 3 stacks — demand-driven post-launch (per #Q-2).
- Auto-triggering `--with-conversus-stress-test` in ideation — demand-driven post-launch (per #Q-7).

**Boundary with M032 (the paired milestone):**
- M033 OWNS: 7 new commands (start, constitution, ingest-codebase, materials-intake, ideation, customblock-draft + grilling-shell module), 3 stack-starter templates, 3 reference docs (branch-detection, constitution-starter-format, customblock-format), 4-branch friendly-tester protocol artifact + report template + validate-report.sh, the PBJ fixture, the grilling-shell as PRIMARY WRITER for `wiki/glossary.md`.
- M033 CONSUMES: spec 035 FR-1 bundle schema (Seam-A); spec 035 FR-11 `--with-wiki` failure-propagation (Seam-B); spec 035 FR-15 + FR-16 glossary path + adapter (Seam-C); orchestrator:migrate (M015); orchestrator:github-init (M013); M027/M019 observability infrastructure; M030 adaptive model routing; M020 knowledge-graph kinds; M031 Quick/Standard/Full traversal contract.
- NEITHER OWNS unilaterally: the integration test scripts on the three load-bearing seams (paired-shared at `tests/paired-m032-m033/seam-*.sh` per M032 AD-4 / #Q-B).

## Design Constraints

- **Friendly-tester pass is the load-bearing gate (CON-2)**: per launch sequencing amendment + AD-3. Non-negotiable for milestone close without signed attestation. Outsiders only.
- **Standalone posture content-authoring (CON-3)**: zero `speckit.*` dependencies anywhere in M033-shipped surface. FR-6 standalone-gate verifier is the mechanical enforcement.
- **M032-paired-launch contract (CON-1)**: bidirectional with M032. AD-1..AD-2 codify the operationalization. AD-3 makes the friendly-tester gate the empirical validation surface for the paired surfaces.
- **Deterministic drift detection (CON-4)**: FR-9's drift detection is deterministic (ID misalignment, scheme contradictions, orphan references). No LLM-magic merge. Operator stays in control of every conflict.
- **Grilling-protocol non-batchable (CON-5)**: FR-17's grilling-shell presents questions sequentially. Hard architectural invariant; calling commands MAY NOT bypass.
- **Resume-on-partial-state required (CON-6)**: FR-20's marker-file-based partial-state detection is required for milestone close, not optional. Mid-flow Ctrl+C MUST NOT cascade.
- **CC-only launch posture (NG-equivalent)**: per CLAUDE.md launch posture. M033's flows route to M030 for adaptive model selection.
- **The 2026-05-15 PBJ pilot deadline drives M032+M033 paired ship date** (Assumption A-3 + spec 035 A-3). The paired-development overhead + friendly-tester buffer (~1 week) is absorbed against the higher cost of cold-start UX bugs discovered at launch.
- **External-tool dependencies**: `gh` CLI (FR-16 + FR-9 paired with M032's FR-9 + FR-21); `textutil`/`pdftotext` (FR-9 PDF intake); `$EDITOR` (FR-3 + FR-13 review pass).
- **MIT-001 two-mode SC-9 contract is the architectural reconciliation between paired-development reality and SC-14 `skip=0` requirement**. The stub mode runs in P01..P04 (M032/P02 not yet closed), the real mode runs in P05 (M032/P02 closed). Both modes pass; neither skips.

## Open Questions

- **#Q-1 RESOLVED at finalize-2026-05-03 — Friendly-tester recruiting**: maintainer (Brett) recruits 1–2 outsiders by **2026-05-08** via personal network or developer Slack/Discord (target gives 4–7 days for tester scheduling before M033/P05 close). If recruiting fails by **2026-05-12**, fall back to `M033_SKIP_FRIENDLY_TESTER_PASS=1` per US-8 AS-5 with documented cold-start risk acknowledged in `M033-SUMMARY.md`. **Operator action**: recruiting outreach should begin immediately (no later than 2026-05-04) to maximize the 5-day recruiting window. Mirrors launch sequencing amendment Q1 + M032 #Q-D.
- **#Q-2 stack-starter library expansion criterion**: spec 036 #Q-2. Resolution: ship 3 stacks (web-saas, cli-tool, library) for v1; the demand-driven trigger to expand to brief's 8 is ≥2 distinct external requests for a stack post-launch.
- **#Q-3 codebase-ingestion LLM-augmentation trigger**: spec 036 #Q-3. Resolution: friendly-tester pass surfaces "deterministic seed too thin" as `friction_warnings ≥ 2` across multiple testers triggers M033.5 expansion.
- **#Q-4 migrate-then-ingest ordering re-validation**: spec 036 #Q-4. Resolution: confirm migrate-then-ingest with duplicate-MEM prevention; M015 + M020 closures don't change the ordering.
- **#Q-5 AGENTS.md bilateral-fallback impact on customblock-draft**: spec 036 #Q-5. Resolution: dual-write per FR-21 default ON (matches M014 pattern); respect `dual_write_agents: false` config flag.
- **#Q-6 conflict-threshold tunability**: spec 036 #Q-6. Resolution: `M033_CONFLICT_FILE_THRESHOLD` defaults to 5; surface in `references/` for operator tuning.
- **#Q-7 ideation stress-test default**: spec 036 #Q-7. Resolution: keep opt-in for v1; auto-triggering surfaces as M033.5 demand-driven.
- **#Q-8 customblock prescriptive-vs-freeform**: spec 036 #Q-8. Resolution: prescriptive 5-section structure with operator-additions-preserved-verbatim escape hatch.
- **#Q-9 friendly-tester fixture-vs-real-project**: spec 036 #Q-9. Resolution: real outsider's project for ≥1 tester; synthetic fixtures as supplementary signal. Both modes accepted at SC-15.
- **#Q-10 paired-launch integration testing cadence**: spec 036 #Q-10 / M032 AD-4. Resolution: every commit to either spec's milestone branches; failure on any of the three seams blocks both milestones.
- **#Q-11 imported-context sentinel convention**: spec 036 #Q-11 (added per MIT-005). Resolution: document `_imported-context/` convention in `references/` alongside milestone directory schema; downstream traversers treat any `_*` prefix as special non-milestone class. Phase placement: P03 (when FR-8 fires).
- **#Q-A RESOLVED at finalize-2026-05-03 — Friendly-tester pass impact on M032 close** (mirrored from M032 #Q-A): M033's SC-15 exercises M032's `--with-wiki` surface; if the friendly-tester surfaces an M032-rooted blocker, M032 reopens for the targeted fix. Cross-milestone routing decisions are logged in BOTH milestones' execution logs (FR-22 + spec 035 FR-9 audit-trail).
- **#Q-B RESOLVED at finalize-2026-05-03 — Paired-integration test script ownership** (mirrored from M032 #Q-B): M032 lands all three seam-test scripts at `tests/paired-m032-m033/seam-{A,B,C}.sh` alongside M032/P02 (`wiki-init` shipping phase); both milestones' CI block on their failure.
- **#Q-C RESOLVED at finalize-2026-05-03 — M032/P02-vs-M033/P05 ordering** (mirrored from M032 #Q-C): M032/P02 closure is a hard pre-condition for M033/P05 START (not just close); M032/P02 must close at least 1 week before M033/P05 starts to absorb integration-bug discovery. This binds M032/P02's ship-date to M033/P05's start-date.
