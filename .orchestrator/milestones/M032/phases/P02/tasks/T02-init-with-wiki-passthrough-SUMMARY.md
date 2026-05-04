---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M032"
provides:
  - "commands/init.md --with-wiki documentation block; init-project.sh recognizes --with-wiki/--with-giscus/--deploy with composition validation; sequential-atomicity dispatch of wiki-init.sh per FR-11/MIT-011; M032_WIKI_INIT_FORCE_EXIT test-only escape hatch in wiki-init.sh; tools/verify/m032-p02-init-with-wiki-passthrough.sh four-scenario verifier"
requires:
  - "from:P02/T01 what:scripts/lifecycle/wiki-init.sh; from:P01 what:tests/fixtures/m032-fresh-project-fixture/"
affects:
  - "P02/T05 (Seam-B failure-injection consumer); M033/P05 (init --with-wiki integration contract per CON-3)"
key_files:
  - "commands/init.md,scripts/lifecycle/init-project.sh,scripts/lifecycle/wiki-init.sh,tools/verify/m032-p02-init-with-wiki-passthrough.sh"
key_decisions:
  - "FR-11,MIT-011,CON-3,AP-009,AD-19,MEM001,MEM012,MEM030"
patterns_established:
  - "sequential-atomicity dispatch (init-project.sh writes outputs first; wiki-init.sh runs second; wiki-init.sh failure preserves init outputs and propagates literal exit code with init-complete-wiki-pending diagnostic); M032_WIKI_INIT_FORCE_EXIT env-var-only test-only failure-injection seam; pre-stage no-op short-circuit (wiki-init.sh skips bundle-staging when wiki/mkdocs.yml already exists from prior installer project_assets loop, avoiding FR-22 collision-check operator-owned trip)"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P02/tasks/T02-init-with-wiki-passthrough-PAYLOAD.md,.orchestrator/milestones/M032/phases/P02/P02-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-04T18:48:39Z"
---

# T02 — init --with-wiki passthrough (FR-11 / MIT-011)

## What Shipped

T02 lands the M033/P05 integration contract per CON-3 — the
`orchestrator:init --with-wiki [--with-giscus] [--deploy]` flag chain — as
three coupled changes plus a four-scenario verifier:

1. **`commands/init.md`** — additive amendment to the Workflow section: a
   verbatim block documenting the FR-11 / MIT-011 sequential-atomicity
   contract (init-project.sh writes outputs first; wiki-init.sh runs
   second; wiki-init failure preserves init outputs and propagates the
   literal exit code with `init-complete, wiki-pending` diagnostic on
   stderr; M033/P05 callers may re-run wiki-init independently to complete
   initialization). Plus pass-through documentation for `--with-giscus`
   and `--deploy` (P03 deliverables, P02 rejects with exit 5 inside
   wiki-init.sh). Plus a Referenced Scripts entry for
   `scripts/lifecycle/wiki-init.sh`. No pre-M032 sections were removed.

2. **`scripts/lifecycle/init-project.sh`** — three new flag vars
   (`WITH_WIKI`, `WITH_GISCUS`, `WITH_DEPLOY`) wired into the existing
   case-statement argument-parsing loop. Composition validation rejects
   `--with-giscus` or `--deploy` without `--with-wiki` with exit 2 and
   `requires --with-wiki` diagnostic. A new section 16 at the end of the
   script — AFTER the SUMMARY: line (init outputs guaranteed on disk by
   that point) and BEFORE the final `exit 0` — dispatches
   `wiki-init.sh` as a second sequential step ONLY when `--with-wiki` is
   set. On `wiki-init.sh` non-zero exit: emit the
   `init-complete, wiki-pending` diagnostic on stderr, point the operator
   at the re-run command, and propagate the literal wiki-init exit code.
   Pre-M032 invocations without `--with-` flags traverse the same script
   bytes but the new section 16 is a no-op (gated by `WITH_WIKI=1`).

3. **`scripts/lifecycle/wiki-init.sh`** — minimal additive amendment:
   the `M032_WIKI_INIT_FORCE_EXIT` env-var-only test-only escape hatch
   inserted after argument parsing and before the toolchain probe. Per
   the M026/MEM030 `<TOOL>_EDITION=<value>` env-var convention, the
   hatch is NOT exposed as a flag or positional arg — env-var-only access
   keeps it out of the operator-facing surface. The hatch is consumed by
   T05's Seam-B failure-injection scaffold and by T02's own verifier
   (test scenario 2: failure-propagation).

   PLUS one load-bearing fix flagged during T02 verification: replaced
   the over-strict PRE_STAGE_NO_OP short-circuit (which required all four
   site-identity fields to match exactly) with a simpler check
   (`wiki/mkdocs.yml` exists AND not `--force`). The original logic was
   correct for repeat `wiki-init` invocations but failed under the
   `init --with-wiki` flow: the installer's project_assets loop in
   `install-claude-code.sh` stages `wiki/` BEFORE `wiki-init.sh` runs,
   leaving `wiki/mkdocs.yml` on disk with bundle-template values that do
   NOT match the to-be-applied identity values. The original short-circuit
   then fell through to the bundle-staging step, which tripped the FR-22
   collision-check operator-owned oracle (target exists, not in tracking
   file, not gitignored). The fix: skip bundle-staging unconditionally
   when `wiki/mkdocs.yml` already exists; the downstream sed-substitution
   step handles re-templating in both the dogfood-second-run case AND the
   `init --with-wiki` first-run case.

4. **`tools/verify/m032-p02-init-with-wiki-passthrough.sh`** — four
   independent scenarios:
   - **Test 1 (default-passthrough success)**: stage fresh fixture, run
     `init-project.sh --runtime claude-code --with-wiki`, assert exit 0,
     assert `.orchestrator/` exists, assert `wiki/mkdocs.yml` exists.
   - **Test 2 (failure-propagation)**: stage fresh fixture, run with
     `M032_WIKI_INIT_FORCE_EXIT=7`, assert literal exit 7, assert
     `.orchestrator/` preserved, assert `init-complete, wiki-pending`
     and `M032_WIKI_INIT_FORCE_EXIT=7` diagnostics on stderr, assert
     `wiki-init: done` success message ABSENT from stdout (the correct
     signal that wiki-init.sh aborted before completing — the
     `wiki/mkdocs.yml` file IS still on disk because the installer's
     project_assets loop stages it BEFORE wiki-init dispatches).
   - **Test 3 (composition-error)**: run `--with-giscus` without
     `--with-wiki`, assert exit 2, assert `requires --with-wiki`
     diagnostic on stderr.
   - **Test 4 (pre-M032 byte-identical)**: run with NO `--with-` flags,
     assert exit 0, assert no `wiki-init:` diagnostic in either stream
     (wiki-init.sh was NOT invoked). The `wiki/` directory IS present
     after this scenario — the installer always stages it via the
     project_assets manifest loop — so the correct signal is the
     ABSENCE of wiki-init's diagnostics, not the absence of `wiki/`.

## Verification Results

`bash tools/verify/m032-p02-init-with-wiki-passthrough.sh` → exit 0,
`PASS: m032-p02-init-with-wiki-passthrough`. All four scenarios green.

Adjacent verifiers re-run after this task's changes:
- `m032-p02-wiki-init-default-scope.sh` → pass=19 fail=0.
- `m032-p02-wiki-init-command-shape.sh` → pass=15 fail=0.
- `m032-p02-mkdocs-templating-and-self-application.sh` → pass=15 fail=0.

## Two Verifier-Assertion Adjustments

The task plan's step 6 specified two assertions that turned out
semantically incorrect under the actual M032 design. Both adjustments
preserve the spirit of the test (\"wiki-init aborted\" / \"wiki-init not
invoked\") while matching reality:

- **Test 2** original: `assert wiki/mkdocs.yml does NOT exist`. Reality:
  the installer's project_assets loop stages `wiki/mkdocs.yml` BEFORE
  `wiki-init.sh` dispatches — so the file IS on disk regardless of
  whether wiki-init aborts. Adjusted assertion: stderr names
  `M032_WIKI_INIT_FORCE_EXIT=7`, AND stdout does NOT contain the
  `wiki-init: done` success message. Both signals confirm wiki-init.sh
  exited via the escape hatch before completing the templating step.

- **Test 4** original: `assert wiki/ directory does NOT exist`. Reality:
  the installer's project_assets loop stages `wiki/` unconditionally
  (independent of `--with-wiki`). Adjusted assertion: no `wiki-init:`
  diagnostic in stdout, no `wiki-init` reference in stderr. Both signals
  confirm `wiki-init.sh` was NOT dispatched as a sequential step.

Both adjustments are documented inline in the verifier with comments
explaining the design context. The semantic intent (\"wiki-init aborted\"
in test 2, \"wiki-init not invoked\" in test 4) is preserved.

## Pre-Existing Failures Out Of T02 Scope

`tools/verify/m032-p01-phase-suite.sh` reports `pass=6 fail=5` — but
all five sub-gate failures pre-date T02 and are caused by T01 adding the
5th `wiki/` entry to `project_assets:` in `packaging/bundle/manifest.yml`.
The P01 verifiers hardcode the expected count at 4
(`m032-p01-manifest-schema-shape.sh`, `m032-p01-reader-emits-tuples.sh`,
`m032-p01-install-cc-byte-identical.sh`, `m032-p01-installers-parity.sh`,
`m032-p01-acceptance-shape-sc1.sh`). These verifiers need
post-T01-aware updates as part of P02 closure work, but are not under
T02's scope per the task plan's Files To Touch list.

## Key Decisions / Patterns

- **Sequential-atomicity (FR-11 / MIT-011)**: init-project.sh writes
  outputs first (durable on disk regardless of wiki-init outcome);
  wiki-init.sh runs as a second sequential step ONLY under
  `--with-wiki`; wiki-init.sh failure preserves init outputs and
  propagates the literal exit code with `init-complete, wiki-pending`
  diagnostic. Re-running `init-project.sh` against an already-init'd
  project is the more dangerous shape (forgetting flags, overwriting
  custom configs); leaving the project in `init-complete, wiki-pending`
  and letting the operator re-run `wiki-init.sh` directly is safer.

- **`M032_WIKI_INIT_FORCE_EXIT` test-only seam (Seam-B groundwork)**:
  env-var-only access per M026/MEM030 `<TOOL>_EDITION=<value>` convention;
  not exposed as flag or positional arg; consumed by both T02's verifier
  (test 2) and T05's Seam-B failure-injection scaffold.

- **Pre-stage no-op short-circuit (collision-trip avoidance)**: when
  `wiki/mkdocs.yml` already exists at the target, skip the bundle-staging
  step. Two cases hit this branch: (a) repeat `wiki-init` invocations,
  (b) `init --with-wiki` flow where the installer's project_assets loop
  has already staged `wiki/` before `wiki-init.sh` dispatches. The
  downstream sed-substitution step handles re-templating in both cases.

## Affects Downstream

- **T05 (Seam-B failure injection)**: imports the
  `M032_WIKI_INIT_FORCE_EXIT` seam established here; T02's verifier is a
  tighter unit-test of the same surface T05 exercises end-to-end.
- **M033/P05**: has the stable `--with-wiki` surface to plan against per
  CON-3.
