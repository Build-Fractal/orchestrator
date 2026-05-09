---
schema_version: "1.0"
type: friendly-tester-report
report_date: "2026-05-09"
eligible_testers: 0
friction_blockers: 0
friction_warnings: 2
tester_attestations:
  - tester_id: "M1"
    not_familiar_with_orchestrator: "no"
tested_branches:
  - greenfield-empty
  - greenfield-with-materials
  - existing-codebase
  - migrating
---

# M033 Friendly-Tester Report — Maintainer Advisory (2026-05-09)

<!--
  ADVISORY REPORT. The walkthrough was performed by the orchestrator project
  author and maintainer. They are INELIGIBLE per protocol.md §Tester Eligibility
  prongs (a), (b), and (c): they have contributed to the orchestrator, have
  read the M033 spec, and have been briefed on the four init branches. The
  attestation block below sets `not_familiar_with_orchestrator: no` to keep
  validate-report.sh's eligible-attestation count at 0.

  This report does NOT clear the SC-15 gate. The gate clears via the
  M033_SKIP_FRIENDLY_TESTER_PASS=1 signed-attestation block already in place
  per the M033 close on 2026-05-04. This report supplements that attestation
  with friction-taxonomy evidence + remediation traceability so the deferred
  real-outside-tester pass (≤ 2026-05-12 per launch-sequencing-amendment Q-1)
  has a documented baseline.

  Frontmatter counters reflect POST-PATCH state. All four pre-patch blockers
  (F2, F8, F9, F10) were fixed in commit 852416b4 the same session; per
  protocol.md §Reporting they technically remain "blockers, fixed but
  unconfirmed by an eligible tester" until the deferred fresh-tester pass
  walks the patched UX. The post-patch counter is reported as 0 because the
  fixes shipped; the unconfirmed-by-outsider status is captured by the
  ineligible-tester attestation + maintainer sign-off below.
-->

## Tester(s)
- M1 — orchestrator project author + maintainer (brett@fivestar.studio).
  Ineligible per protocol §Tester Eligibility: prong (a) authored the
  orchestrator, prong (b) authored the M033 spec, prong (c) wrote the
  branch-routing logic. Attestation `not_familiar_with_orchestrator: no`
  set deliberately so validate-report.sh's mechanical count reflects the
  ineligible status. Report is **advisory**.

## Branch: greenfield-empty
### Friction (Blockers)
- F2: `next_step=run_orchestrator_evaluate` is a slug, not an instruction —
  a stranger cannot act on it without being told to convert the slug into a
  command invocation.
  → FIXED in 852416b4 (Patch A: warm-welcome footer now prints the literal
  next-action sentence after the machine token).
  → STATUS: shipped, not yet confirmed by an eligible tester (deferred to
  ≤ 2026-05-12 per launch-sequencing-amendment Q-1).

### Friction (Warnings)
- F1: SUMMARY line is `key=value` machine-format jargon (`cap_score=...`,
  `dual_writes=...`, `recommended_intensity=...`) — illegible to strangers
  on first impression.
  → POST-PATCH: machine tokens preserved verbatim; warm-welcome footer that
  follows overshadows the SUMMARY line for the first-impression UX. Judged
  acceptable.
- F3: `--help` / `-h` errored with `unknown flag` — no usage path for a
  curious stranger.
  → FIXED in 852416b4 (Patch B: `--help` / `-h` now print usage and exit 0).
- F4: `branch: <name>` line lacked framing — no sentence around what the
  branch label means.
  → FIXED in 852416b4 (Patch A: warm-welcome footer frames the branch).
- F5: `would-execute: <stub>` reveals the implementation isn't fully built —
  unsettling for a first-impression user.
  → POST-PATCH: stub line preserved (real-tester audit trail), but warm-welcome
  footer takes the lead role. Judged acceptable.
- F6: `project_type=generic` doesn't reflect branch detection — feels like
  the orchestrator failed to introspect the project.
  → POST-PATCH: token preserved; warm-welcome footer overshadows. Judged
  acceptable.

### Notes
- Greenfield-empty is the lowest-friction branch — no destination-mutation
  concerns, no materials to detect, no existing tools to migrate from.
- Time on branch: ~5 min walkthrough.

## Branch: greenfield-with-materials
### Friction (Blockers)
- F2 (re-observed, same root cause): same `next_step=` slug behavior.
  → FIXED in 852416b4 (Patch A applies to all four branches).

### Friction (Warnings)
- F1, F3, F4, F5, F6 (re-observed, same root cause and same disposition as
  greenfield-empty).
- F7: Materials detection gives no signal that the orchestrator saw the
  markdown files dropped into the project root — stranger can't tell whether
  the brief / decision-register / MVP-plan they prepared is being ingested
  or ignored.
  → FIXED in 852416b4 (Patch A footer now lists detected materials by
  filename).

### Notes
- F7 fix is the highest-value warning fix on this branch — the whole point
  of greenfield-with-materials is that the user did pre-work; without an
  acknowledgment line the pre-work feels lost.
- Time on branch: ~7 min walkthrough.

## Branch: existing-codebase
### Friction (Blockers)
- F8: Silently mutates the target directory with 9 root-level items, no
  warning, no `--dry-run` mention, no confirmation. A stranger pointing
  this at a repo they care about would feel ambushed.
  → FIXED in 852416b4 (Patch C: existing-codebase now prints a pre-flight
  enumeration of every path it would create, then prompts for confirmation
  unless `--yes` is supplied; `--dry-run` documented in `--help`).
- F9: Potential collision risk with pre-existing `commands/`, `scripts/`,
  `templates/`, `wiki/` directories — silent overlay would clobber prior
  work.
  → FIXED in 852416b4 (Patch C: pre-flight refuses to proceed if any of the
  staged paths already exist; emits explicit collision report and exits
  non-zero).

### Friction (Warnings)
- F1, F3, F4, F5, F6 (re-observed, same disposition).

### Notes
- Even after the pre-flight warning + confirmation prompt landed in 852416b4,
  the **9 root-level items** still feels invasive — the patch defends against
  accidental clobber but doesn't change the fact that orchestrator state
  lives at the project root in 9 separate directories.
- Out-of-tree runtime-footprint refactor proposed at
  `.orchestrator/proposals/M0xx-out-of-tree-runtime-footprint.md` for
  post-launch sequencing — addresses the **felt-friction root cause** of
  F8/F9 (footprint visibility) rather than just the collision-mechanics
  symptom (which 852416b4 handled).
- Time on branch: ~10 min walkthrough (longest of the four — pre-flight
  enumeration is dense).

## Branch: migrating
### Friction (Blockers)
- F10: Migrate dead-end — message reads
  `no orchestrator:migrate adapter for this tooling -- please file a request`
  with no link, no fallback path, no instruction for what "file a request"
  means. Stranger has nowhere to go.
  → FIXED in 852416b4 (Patch D: dead-end now prints the concrete adapter-
  request issue-template URL, the branch-override flag for users who want
  to skip migration and start fresh, and a one-line summary of which
  source tools are currently supported).

### Friction (Warnings)
- F1, F3, F4, F5, F6 (re-observed, same disposition).
- F11: "migrating" label printed without context — no `from <tool> to
  orchestrator` framing. Stranger has to infer what's migrating.
  → FIXED in 852416b4 (Patch A footer for migrating branch now prints
  `migrating from <detected-tool> to orchestrator`).

### Notes
- F10 fix is the most important blocker resolution of the four — the
  pre-patch dead-end actively turns away users who would otherwise be
  candidates.
- Time on branch: ~8 min walkthrough.

## Aggregate
- Eligible testers: 0 (matches frontmatter — maintainer ineligible per
  protocol's three-prong test, attestation `not_familiar_with_orchestrator: no`).
- Total friction blockers: 0 (post-patch — all 4 walkthrough blockers fixed
  in commit 852416b4; technically "blockers, fixed but unconfirmed by an
  eligible tester" per protocol §Reporting until the deferred fresh-tester
  pass walks the patched UX).
- Total friction warnings: 2 (post-patch — F1 SUMMARY jargon and F5
  would-execute reveal still print machine tokens, but the warm-welcome
  footer that follows them carries the first-impression UX. Both judged
  irrelevant alongside the footer.)

## Maintainer Sign-Off
- Recorded by: brett (orchestrator maintainer, brett@fivestar.studio)
- Walkthrough date: 2026-05-09
- Time spent: ~90 min total (≈30 min branch walkthrough + ≈60 min UX-patch
  design / implementation review for commit 852416b4)
- Follow-ups created:
  - commit `852416b4` — M033 friendly-tester UX patch (Patches A/B/C/D
    addressing F2, F3, F4, F7, F8, F9, F10, F11).
  - `.orchestrator/proposals/M0xx-out-of-tree-runtime-footprint.md` —
    post-launch proposal for the deeper fix to F8/F9 felt-friction
    (invasive in-tree footprint root cause).
  - Real-outside friendly-tester pass against the patched UX deferred to
    ≤ 2026-05-12 per launch-sequencing-amendment Q-1. Protocol at
    `tests/m033-acceptance/friendly-tester-pass/protocol.md`.
- Eligibility note: this report is **ADVISORY**. It does NOT clear SC-15.
  SC-15 continues to clear via the `M033_SKIP_FRIENDLY_TESTER_PASS=1`
  signed-attestation block in `scripts/verify/validate-milestone.sh`,
  which has been in place since the M033 close on 2026-05-04. This report
  supplements the signed-attestation override with friction-taxonomy
  evidence + remediation traceability so the deferred real-tester pass
  has a documented pre-patch / post-patch baseline.
