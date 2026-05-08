# M033 Friendly-Tester Pass Protocol

<!--
  Authoritative reference: M033 spec FR-19 / US-8 / SC-15 / CON-2.
  This protocol document is markdown-only — it does not run commands.
  It instructs a human (the "friendly tester") on how to walk each of
  the four `orchestrator:start` init branches in 30 minutes and capture
  friction observations into a structured report.

  Mechanical gate: the filled-out report is fed to `validate-report.sh`
  in this same directory. SC-15 closes only when:
    - friction_blockers: 0
    - eligible_testers >= 1 (per `not_familiar_with_orchestrator: yes`)
-->

## Purpose

The friendly-tester pass is the load-bearing gate (FR-19 / US-8 / SC-15)
that prevents M033 from shipping a cold-start UX that maintainers think
works but outsiders bounce off of. Maintainer self-testing is weak
signal: maintainers know the four init branches by name, know the spec
language, and recognize the warm-conversational front door from the
inside. Synthetic fixtures alone (the `tester-eligibility` checklist's
counterpart in `tests/fixtures/m033-pbj-materials-fixture/`) test
mechanical correctness, not first-impression UX. Only warm-body
walkthroughs surface the friction taxonomy CON-2 names — where outsiders
get stuck, where they re-read, where they bounce.

This protocol is the recruitment and walkthrough script. The companion
`report-template.md` is the structured capture form. The companion
`validate-report.sh` is the mechanical gate that confirms the report
shape passes SC-15 thresholds.

## Tester Eligibility

A tester is "eligible" for the M033 friendly-tester pass iff they
self-attest to ALL THREE of the following on the report's
`tester_attestations:` block (`not_familiar_with_orchestrator: yes`):

- (a) has not contributed to orchestrator (no commits, no PR
  reviews, no proposal authorship under `.orchestrator/proposals/`).
- (b) has not read the M033 spec at `specs/030-project-onboarding-experience/`.
- (c) has not been briefed on the four init branches
  (`greenfield-empty | greenfield-with-materials | existing-codebase | migrating`)
  by a maintainer.

Orchestrator maintainers and contributors are explicitly excluded
(per Edge Case `Friendly-tester pass run by a tester who is too close`).
The validator counts only tester attestations whose
`not_familiar_with_orchestrator` field equals `yes`. Any tester who
fails one of the three exclusion criteria sets that field to `no` and
their report contributions are advisory only — they do not count toward
the SC-15 `eligible_testers >= 1` threshold.

Recruitment guidance: developers from adjacent teams, friends in
software, designers, technical writers, or PMs who have shipped code
but never seen this repo. Five-to-fifteen-year career range is ideal.
Avoid recruiting anyone who has read the launch sequencing amendment
or the M033 onboarding brief.

## Pre-Conditions (Per Branch)

The tester walks each of the four branches against a representative
fixture project. Maintainers prepare the fixture matrix in advance.

### Branch: greenfield-empty

- **Fixture shape**: an empty directory. `mkdir
  /tmp/m033-tester-greenfield-empty` is the entire setup.
- **Tester reads**: nothing — they should arrive with no priors about
  what the orchestrator does.
- **Expected detection**: rule 4 (default) fires;
  `branch: greenfield-empty` printed before sub-flow dispatch.

### Branch: greenfield-with-materials

- **Fixture shape**: a project directory containing 3+ markdown files
  matching `*BRIEF*.md|*PLAN*.md|*DECISIONS*.md|*HANDOFF*.md|*AUDIT*.md`
  AND no `src/` directory. The tester ideally provides their own drafts
  (a pitch deck-in-Markdown, a one-pager, a design doc); the synthetic
  PBJ fixture at `tests/fixtures/m033-pbj-materials-fixture/` is the
  fallback when no candidate is at hand.
- **Tester reads**: nothing about the orchestrator.
- **Expected detection**: rule 2 fires;
  `branch: greenfield-with-materials` printed.

### Branch: existing-codebase

- **Fixture shape**: any real codebase the tester has on disk — their
  own side-project, a recent client repo, a forked OSS package. Must
  satisfy rule 3 (one of: `src/` directory present; ≥10 source files at
  project root in the canonical extension set; `.git/` with ≥1 commit).
- **Tester reads**: nothing.
- **Expected detection**: rule 3 fires; `branch: existing-codebase`
  printed.

### Branch: migrating

- **Fixture shape**: a project containing one of `.gsd/`, `.gsd2/`, or
  `.specify/` (any non-empty marker — even an empty file at the path is
  sufficient for rule 1). If no candidate is available, the tester
  walks against a synthetic fixture: `mkdir -p
  /tmp/m033-tester-migrating/.specify` is the minimal trigger.
- **Tester reads**: nothing.
- **Expected detection**: rule 1 fires (winner over rule 3 even if
  source files present); `branch: migrating` printed.

## 30-Minute Walkthrough Script (Per Branch)

Each branch sub-section is a literal step list. The tester runs the
listed lines verbatim and captures observations against the
`report-template.md` Friction sections. Total budget: 30 minutes across
all four branches (~7 min/branch + 2 min slack).

### Walkthrough: greenfield-empty

1. `mkdir /tmp/m033-tester-ge`
2. `cd /tmp/m033-tester-ge`
3. `bash scripts/lifecycle/start.sh --project-dir /tmp/m033-tester-ge`
4. **Expected stdout**: `branch: greenfield-empty` then a sub-flow stub
   message (P01 ships stubs only).
5. **Capture**: did the tester understand which branch they were in
   without reading internal docs? Did the welcome language feel warm or
   bureaucratic? Did the next-step instruction feel like a hand-off or
   a wall?

### Walkthrough: greenfield-with-materials

1. Tester provides 3+ markdown drafts OR uses
   `cp -R tests/fixtures/m033-pbj-materials-fixture
   /tmp/m033-tester-gwm`.
2. `bash scripts/lifecycle/start.sh --project-dir /tmp/m033-tester-gwm`
3. **Expected stdout**: `branch: greenfield-with-materials` then sub-flow
   stub.
4. **Capture**: did the tester recognize their own materials as the
   trigger? Was the scan-and-summarize promise legible without prior
   context?

### Walkthrough: existing-codebase

1. Tester points at their own real codebase: `bash
   scripts/lifecycle/start.sh --project-dir ~/path/to/their/repo`
2. **Expected stdout**: `branch: existing-codebase` then sub-flow stub.
3. **Capture**: did the tester worry the tool would mutate their
   repo? Did `--dry-run` feel discoverable in the help text?

### Walkthrough: migrating

1. `mkdir -p /tmp/m033-tester-mig/.specify` (or use a real `.gsd/`
   project the tester has).
2. `bash scripts/lifecycle/start.sh --project-dir /tmp/m033-tester-mig`
3. **Expected stdout**: `branch: migrating` (NOT `existing-codebase`,
   even if the directory also satisfies rule 3 — rule 1 wins).
4. **Capture**: did the tester understand "migrating" as the right
   label for the spec-kit-shaped repo, or did the term feel jargony?

## Friction Capture Template

For each branch, the tester captures friction in three categories:

- **Where they got stuck**: the step where the tester could not
  proceed without consulting documentation, asking a maintainer, or
  reading source code.
- **Where they re-read**: any line of stdout, help text, or
  documentation the tester read more than once because the first read
  did not land.
- **Where they bounced**: any moment the tester closed the terminal,
  asked "is this for me?", or expressed frustration audibly.

Classify each captured friction as either `blocker` or `warning`:

- **blocker**: the tester cannot proceed without external help.
  Examples: a flag that produces no output, an error message that does
  not name the problem, a help-text section that contradicts the actual
  behavior. `friction_blockers > 0` BLOCKS milestone close (SC-15).
- **warning**: annoying but recoverable. Examples: a five-second pause
  before they found the right flag, a label that felt jargony but was
  clear in context, a sub-flow stub message that under-promised. The
  `friction_warnings` count is informational only — it does not block
  milestone close, but is captured for follow-up triage.

A "blocker" demotes to "warning" only after a maintainer has fixed the
underlying issue and a fresh tester has confirmed the fix on a clean
walkthrough.

## Reporting

The tester (or a maintainer recording the tester's session) fills out
`report-template.md` in this same directory. The report goes to
`tests/m033-acceptance/friendly-tester-pass/reports/<DATE>.md`
(maintainers create the `reports/` subdirectory at first use).

The mechanical gate: `bash
tests/m033-acceptance/friendly-tester-pass/validate-report.sh
<report-path>` exits 0 iff `friction_blockers: 0` AND eligible
attestations >= 1. Exit non-zero blocks milestone close. The error
message on a missing report contains the literal string `friendly-tester
pass not run — milestone close blocked` (per US-8 AS-5).

`friction_warnings > 0` is acceptable for milestone close — these
become deferred follow-ups, not gates. Only `friction_blockers > 0`
blocks SC-15.

The escalation path (the `M033_SKIP_FRIENDLY_TESTER_PASS=1`
signed-attestation override) is enforced at milestone close by
`validate-milestone.sh`, NOT by `validate-report.sh`. This separation
keeps the per-report shape verifier purely mechanical.
