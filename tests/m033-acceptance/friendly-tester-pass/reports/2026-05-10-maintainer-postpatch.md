---
schema_version: "1.0"
type: friendly-tester-report
report_date: "2026-05-10"
eligible_testers: 0
friction_blockers: 0
friction_warnings: 3
tester_attestations:
  - tester_id: "M2"
    not_familiar_with_orchestrator: "no"
tested_branches:
  - greenfield-empty
  - greenfield-with-materials
  - existing-codebase
  - migrating
---

# M033 Friendly-Tester Report — Maintainer Post-Patch Verification (2026-05-10)

<!--
  ADVISORY POST-PATCH VERIFICATION REPORT. Walkthrough performed by Claude
  acting as maintainer's hands. INELIGIBLE per protocol.md §Tester Eligibility
  prongs (a), (b), and (c). Attestation `not_familiar_with_orchestrator: no`
  preserves validate-report.sh's eligible-attestation count at 0.

  This report does NOT clear SC-15. Its purpose is to confirm that the
  patches A/B/C/D shipped in commit 852416b4 (per the 2026-05-09 maintainer
  advisory) still hold against current main (HEAD = b1eb33d1) after M035
  P02-P06 publishing-pipeline work + the Build-Fractal/orchestrator rename
  audit + WS3 follow-up landed.

  Companion to: 2026-05-09-maintainer-advisory.md (pre-patch baseline +
  remediation traceability). The deferred fresh-tester pass against the
  patched UX (≤ 2026-05-12 deadline per launch-sequencing-amendment Q-1)
  remains outstanding and is the sole gate that converts F2/F8/F9/F10
  blocker-fixes from "shipped, unconfirmed" to "shipped, confirmed".
-->

## Tester(s)
- M2 — Claude acting as maintainer's hands (under brett@fivestar.studio
  direction). Same eligibility status as M1 in 2026-05-09 advisory:
  ineligible per all three prongs (full M033 spec context loaded; primary
  contributor to current session work; explicitly briefed on the four
  init branches by the user).

## Branch: greenfield-empty
### Friction (Blockers)
(none)
### Friction (Warnings)
- W1: SUMMARY line `next_step=run_orchestrator_evaluate` is a slug, not the
  command the warm footer recommends. The footer correctly directs the
  operator to `/orchestrator-evaluate`; the machine token says
  `run_orchestrator_evaluate`. F1-class disposition (machine token
  preserved, footer overshadows) — same call as 2026-05-09 advisory.
### Notes
- Verified post-patch path: SUMMARY → `branch: greenfield-empty` →
  `would-execute: ideation-stub` → warm welcome footer with
  `[OK] Setup complete`, "We detected: an empty project (no code, no docs)",
  next-step `/orchestrator-evaluate`, and force-branch instructions for
  the other three branches.
- Patches A held: warm framing + concrete skill name + course-correction
  guidance all present.
- F2 fix held (warm-footer next-step sentence); F4 fix held (branch label
  framed by "We detected ..." sentence).

## Branch: greenfield-with-materials
### Friction (Blockers)
(none)
### Friction (Warnings)
- W1 (re-observed): same `next_step=run_orchestrator_evaluate` slug
  inconsistency in the SUMMARY line. The warm footer correctly recommends
  `/orchestrator-materials-intake`. **This is a worse mismatch than the
  greenfield-empty case** — for greenfield-empty the slug at least names
  the same downstream skill; here, the SUMMARY says `run_orchestrator_evaluate`
  but the footer says `/orchestrator-materials-intake` (different skills).
  A confused first-impression operator who reads the SUMMARY before the
  footer would guess wrong. Still warning-class because the warm footer
  follows immediately and is more visually prominent (box-drawn frame,
  explicit `NEXT STEP --` callout); operator UX recovers within one
  vertical scroll. Worth a follow-up to make the SUMMARY slug
  branch-aware.
### Notes
- Verified F7 fix held: footer prints "We detected: a project with 3
  markdown brief documents (no source code)" — operator can confirm
  their pre-work was seen by the orchestrator.
- Patches A held end-to-end on this branch.

## Branch: existing-codebase
### Friction (Blockers)
(none)
### Friction (Warnings)
- W1 (re-observed): SUMMARY `next_step=run_orchestrator_evaluate` again
  mismatches footer's `/orchestrator-ingest-codebase`. Same disposition
  as greenfield-with-materials.
- W2: Under `--dry-run`, the pre-flight tip prints `Tip: re-run with
  --dry-run to preview without writing.` This is a no-op suggestion in
  context (operator is already in dry-run). Should either suppress the
  tip when DRY_RUN=1 or rephrase to suggest `--yes` to proceed for real.
  Located in start.sh:1087.
- W3: Collision-detection diagnostic line reads "will be modified or
  refused -- review first" but the actual control flow (start.sh
  lines 1177-1180) **always exits 2 on any collision**. The text
  promises a possibility ("modified") that the code does not deliver.
  Should read "refused -- resolve manually first". Same line affects all
  collision rows.
### Notes
- Verified F8 fix held: pre-flight enumerates 9 root-level items by name
  + description BEFORE invoke_init runs. Operator sees what they are
  about to accept.
- Verified F9 fix held: collision detection fires (tested against fixture
  with pre-existing `commands/`); diagnostic naming the colliding
  item printed; exit code 2.
- Verified Patch C dry-run gate: `--dry-run` exits 0 cleanly with no
  side-effect to the target dir.
- Cross-test against `/tmp/m033-postpatch-ec` (dry-run + clean fixture)
  passed: zero collisions reported, "DRY-RUN: no changes made" printed,
  exit 0.
- The deeper "felt-friction" concern noted in the 2026-05-09 advisory
  (`.orchestrator/proposals/M0xx-out-of-tree-runtime-footprint.md`)
  remains valid — patches defended against accidental clobber but did
  not move the 9-item footprint out of the project root. Post-launch
  proposal still applicable.

## Branch: migrating
### Friction (Blockers)
(none)
### Friction (Warnings)
- W1 (re-observed): SUMMARY `next_step=run_orchestrator_evaluate` mismatches
  footer's `/orchestrator-migrate`. Same disposition.
- W4: Patch D dead-end footer's "Request adapter support" path still
  contains a placeholder line: `(No public issue tracker yet -- for now,
  attach project tree + email.)` (start.sh:1122). Tied to TODO at
  start.sh:1120-1121: "post-launch -- replace with GitHub Issues URL once
  M035 P06 closure publishes the public repo." M035 P06 closed
  2026-05-10 but the repo (`Build-Fractal/orchestrator`) is still
  PRIVATE per `gh repo view`, so the public Issues URL is not yet
  populatable. Not a blocker — the launch tag will trigger repo-public
  flip and the placeholder can be replaced as part of launch-day
  housekeeping or as the first post-launch paper-cut.
### Notes
- Verified Patch D held end-to-end on both supported and unsupported
  paths:
  - **Supported tooling** (`/tmp/m033-postpatch-mig-ok` with
    `.specify/specs/`): branch detected as `migrating` with
    `DETECTED_FROM=spec-kit`; tokens `migrate-routed: from=spec-kit` +
    `proposed: orchestrator:migrate --from spec-kit --project-dir ...`
    emitted; warm welcome footer prints "We detected: a project from
    spec-kit" with `/orchestrator-migrate` next-step. F11 fix held
    (migration framing).
  - **Unsupported tooling** (`/tmp/m033-postpatch-mig-bad` with empty
    `.specify/`): legacy "no orchestrator:migrate adapter" line preserved
    on stderr (load-bearing token); dead-end footer prints supported
    sources list + two course-correction options (force a different
    branch / request adapter). F10 fix held.

## Aggregate
- Eligible testers: 0 (matches frontmatter — Claude as maintainer's hands
  is ineligible per protocol's three-prong test, attestation
  `not_familiar_with_orchestrator: no`).
- Total friction blockers: 0 post-patch — all four patches A/B/C/D from
  commit 852416b4 verified to hold against current main (HEAD b1eb33d1).
  Per protocol §Reporting, blockers F2/F8/F9/F10 technically remain
  "blockers, fixed but unconfirmed by an eligible tester" until the
  deferred fresh-tester pass walks the patched UX.
- Total friction warnings: 3 net-new (W2 dry-run-tip redundancy, W3
  collision-line wording, W4 placeholder issue-tracker line). Plus
  re-observation of the 2026-05-09 W1-class machine-token slug
  inconsistency, which is now arguably *worse* on three of the four
  branches than the 2026-05-09 read suggested (because the slug names
  the wrong downstream skill, not just generic jargon).

## Maintainer Sign-Off
- Recorded by: Claude (under brett@fivestar.studio direction)
- Walkthrough date: 2026-05-10
- Time spent: ~25 min (post-patch verification only — no remediation work)
- Follow-ups created (none merged this session — paper-cut candidates only):
  - PC-A: SUMMARY-line `next_step` slug should be branch-aware (one-line
    fix in scripts/lifecycle/init-project.sh — emit
    `next_step=run_orchestrator_<intake|ingest_codebase|migrate|evaluate>`
    keyed off the branch about to fire). Cleans up W1 across all four
    branches.
  - PC-B: Suppress the `Tip: re-run with --dry-run ...` line at
    start.sh:1087 when DRY_RUN=1, or rephrase to suggest `--yes` to
    proceed.
  - PC-C: Rephrase collision diagnostic at start.sh:1081 from "will be
    modified or refused -- review first" to "refused -- resolve manually
    first" to match actual control flow.
  - PC-D: Replace the placeholder line at start.sh:1122 with the public
    Issues URL once `Build-Fractal/orchestrator` flips to public visibility
    (M035 launch-day housekeeping).
- Eligibility note: this report is **ADVISORY**. It does NOT clear SC-15.
  SC-15 continues to clear via the `M033_SKIP_FRIENDLY_TESTER_PASS=1`
  signed-attestation block established at the M033 close on 2026-05-04.
  This report supplements the 2026-05-09 advisory with post-patch
  verification evidence so the deferred fresh-tester pass against the
  patched UX (≤ 2026-05-12 deadline per launch-sequencing-amendment
  Q-1) has both pre-patch and post-patch baselines documented.
- Real-tester recruitment status as of this session: not yet attempted.
  Recommend recruiting an adjacent-team developer / designer / PM (per
  protocol §Tester Eligibility) before 2026-05-12 deadline. Without that,
  signed-attestation fallback remains the close mechanism.
