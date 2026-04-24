# Handoff — orchestrator batch 3 fixes, impact on bbt-companion integration

Date: 2026-04-24
Branch: `orchestrator-batch-3-fixes` (8 commits ahead of `main`)

This batch closes 8 issues surfaced during the M026/P02 dogfood run plus
the leftover Bugs F + H from the previous bbt-companion dogfood batch.
The summary below describes what changes for any project consuming this
orchestrator (bbt-companion in particular). Most changes are
internal-only; three are behavioral and worth knowing about before the
next bbt-companion auto run.

## TL;DR for bbt-companion

Three changes that could surprise a running auto loop:

1. **`auto-loop.sh` now hard-fails on roadmap↔disk drift** before
   derive-phase. If bbt-companion's `M001/M001-ROADMAP.md` checkboxes
   disagree with `phases/P##/P##-SUMMARY.md` existence, the loop will
   exit 12 with the recovery command in stderr. Run
   `bash scripts/lifecycle/sync-roadmap.sh <roadmap> <milestone-dir> --fix`
   to reconcile, then resume.
2. **`auto-loop.sh --step=V` now hard-fails on zero extracted checks**
   when the Verification section has content. Task plans whose
   Verification section uses prose only (no inline backticks, no fenced
   code block) will exit 1 with `AUTO:VERIFY_NO_CHECKS`. Plans that
   either have no Verification section *or* use inline backticks /
   fenced ` ```bash ` blocks are unaffected.
3. **Dispatched subagents see a new Branch Discipline rule in the
   Constraints section.** Subagents must commit on the inherited
   branch; `git checkout` / `switch` / `branch` / `merge` / `rebase`
   are forbidden unless the task plan explicitly requires them. This
   is the rule that fired on the M026/P02 T03/T04 hotfix-branch
   incident.

Everything else is either internal-only (parser fixes, fail-loud
hardening) or pure additions (new flags). Existing bbt-companion
artifacts on disk should not need rewriting.

## Per-change detail

### Bug F — phase-summary dedup + roadmap-derived requires/affects

`scripts/lifecycle/phase-transition.sh` (commit `d702a92`)

- `provides`, `key_files`, `key_decisions`, `patterns_established`
  fields in `P##-SUMMARY.md` frontmatter are now deduped.
- `requires` and `affects` are now derived from the roadmap (graph
  position) rather than concatenated from task summaries (internal task
  IDs). New `affects <P##>` query in `scripts/state/read-roadmap.sh`
  returns the reverse-Depends list.

**Surface impact:** anything in bbt-companion that reads
`P##-SUMMARY.md` frontmatter `requires` / `affects` fields will see
phase IDs (`P00,P01`) instead of task IDs (`T01,T02,T03`). If
bbt-companion does not consume those fields directly, no action needed.
Existing on-disk summaries are not rewritten — only future
phase-transitions emit the new shape.

### Bug H — task plan slug filename convention + github-init canonicalization

`commands/plan-phase.md`, `scripts/integrations/github-init.sh`
(commit `d5e6731`)

- `commands/plan-phase.md` now documents `T##-<slug>-PLAN.md` as the
  canonical filename (e.g. `T01-conversus-resolver-PLAN.md`). Old
  `T##-PLAN.md` form remains accepted by every glob.
- `scripts/integrations/github-init.sh` task-ID extraction now strips
  the slug via `${task_id%%-*}`, so slug-form task plans are no longer
  silently skipped during GitHub Issue projection.

**Surface impact:** bbt-companion's planner already organically emits
slug form (verified against
`bbt-companion/.orchestrator/milestones/M001/phases/P00/tasks/`).
**This is now the documented convention rather than an undocumented
divergence.** No bbt-companion file rename is needed — historical
files remain valid.

### Issue #1 — boundary-map parser filters prose fragments

`scripts/verify/check-boundary-map.sh` (commit `be2bcd3`)

- Strips parenthetical commentary before splitting `Produces:` on
  comma.
- Skips fragments that aren't path-shaped (`[A-Za-z0-9._/*-]` only,
  no whitespace).

**Surface impact:** bbt-companion verification reports will stop
showing the spurious "7 FAILs nobody is expected to act on" pattern
that polluted every M026 phase. No bbt-companion artifact change.

### Issue #2 — find-active-milestone --milestone target

`scripts/state/find-active-milestone.sh`, `commands/auto.md`
(commit `3c9df9b`)

- New `--milestone M###` flag (also `--milestone=M###`) targets a
  specific milestone, validates existence + tier C + auto-eligible
  state, and fails loud with a specific reason if any condition isn't
  met.
- Default behavior (no flag) is unchanged: returns numerically-first
  Tier C milestone.

**Surface impact:** when bbt-companion invokes `orchestrator:auto`
with a specific milestone (e.g. `orchestrator:auto milestone=M001`),
the skill now passes `--milestone M001` to the finder, so the auto
loop binds to the named milestone instead of silently picking the
numerically-first planning milestone. Pure addition; behavior of the
default path is unchanged.

### Issue #3 — auto-loop refuses to advance on roadmap↔disk drift

`scripts/lifecycle/auto-loop.sh` (commit `790e8e7`)

- At the top of pre-dispatch, runs `sync-roadmap` in read-only mode.
- On `SYNC:MISMATCH`, emits `AUTO:ROADMAP_DRIFT`, prints details and
  the `--fix` recovery command to stderr, exits 12.

**Surface impact (BEHAVIORAL):** if bbt-companion's roadmap and
on-disk phase summaries are out of sync (which can happen if a phase
summary was written but the roadmap checkbox wasn't updated, or vice
versa), the next `orchestrator:auto` invocation will exit 12 instead
of advancing. Recovery: run the suggested
`bash scripts/lifecycle/sync-roadmap.sh <roadmap> <milestone-dir> --fix`
and re-invoke auto.

Recommendation: before the next bbt-companion auto run, do a one-time
read-only `sync-roadmap` check against `M001/M001-ROADMAP.md` to
confirm clean state.

### Issue #4 — dispatch payload Branch Discipline rule

`scripts/dispatch/lib/section-handlers.sh`,
`templates/dispatch-prompt.md` (commit `a2cf389`)

- Constraints section emitter now appends a `### Branch Discipline`
  subsection that forbids `git checkout` / `switch` / `branch` /
  `merge` / `rebase` inside a dispatched task and tells the agent to
  STOP and report when a side-branch is genuinely required.

**Surface impact (BEHAVIORAL):** every bbt-companion dispatched task
now sees this rule in its payload Constraints section. Subagents that
were creating side-branches as a side-effect of "isolating" their
work will now read a clear prohibition. This is the fix for the
M026/P02 T03/T04 incident where a subagent silently checked out
`dogfood-hotfix-efgh`. No bbt-companion code change needed.

### Issue #5 — auto-loop --step=V fail loud on zero extracted checks

`scripts/lifecycle/auto-loop.sh` (commit `8763d82`)

- Verification command extractor now also pulls commands from fenced
  ` ``` ... ``` ` blocks (one command per non-empty line). Language
  hints like ` ```bash ` are recognized.
- If the Verification section has content but the parser extracts
  zero commands, emits `AUTO:VERIFY_NO_CHECKS`, names the canonical
  shapes in stderr, exits 1.
- Tasks with no Verification section at all are still a legitimate
  skip (`AUTO:VERIFY_PASS checks_passed=0`, exit 0).

**Surface impact (BEHAVIORAL):** bbt-companion task plans that have
a Verification section in some non-canonical shape (e.g. plain prose
description with no executable command line) will now hard-fail the
verify step. Plans using inline backticks or fenced code blocks are
unaffected. If bbt-companion has any non-conforming plans, they will
need to be reshaped to use one of the two supported forms before the
next auto run.

Quick check:

```bash
grep -lP '^## Verification' bbt-companion/.orchestrator/milestones/M001/phases/*/tasks/*-PLAN.md \
  | while read f; do
      if ! grep -qP '`[^`]+`|^[[:space:]]*```' "$f"; then
        echo "POSSIBLE-NOOP: $f"
      fi
    done
```

(The grep above is illustrative — adapt the path glob to bbt-companion's
actual plan locations.)

### Issue #6 — dual-write-runtime-md --append-entry mode

`scripts/util/dual-write-runtime-md.sh` (commit `fd2cf64`)

- New `--append-entry "<text>"` flag prepends a single line to the
  existing region body (reverse-chronological), without forcing the
  caller to reconstruct the whole region.
- Existing `--content <path>` (replace-region) mode is unchanged.
- The two are mutually exclusive.

**Surface impact:** pure addition. Existing bbt-companion calls using
`--content` continue to work. Future calls can opt into the simpler
`--append-entry` form to eliminate the "rebuild the whole region"
footgun that bit T05's first dual-write attempt.

## Pre-merge checklist

Before merging this branch to `main`:

- [x] All 8 fix-specific tests green
- [x] Existing regression suites green:
  `tests/test-s02-state-machine.sh` (29 checks),
  `tests/test-s04-core-commands.sh` (74 checks),
  `tests/test-s05-autonomous-mode.sh` (100 checks),
  `tests/test-s07-integration.sh` (17 checks),
  `tests/test-s08-auto-safety.sh` (35 checks),
  `tests/test-roadmap-dep-safety.sh` (5 checks),
  `tests/test-auto-loop-verify-extraction.sh` (2 checks),
  `tests/test-dual-write-outside-invariant.sh` (1 check)
- [ ] Run a one-time read-only `sync-roadmap` against
  `bbt-companion/.orchestrator/milestones/M001/M001-ROADMAP.md` to
  confirm no pre-existing drift would block their next auto run.
- [ ] Optional: scan bbt-companion task plans for non-canonical
  Verification sections (script above) so any reshape happens before
  the next auto invocation.

## Branch posture

`orchestrator-batch-3-fixes` — 8 commits, each a single logical fix
with its own test. Every commit is independently revertable. Squash
or retain per merge convention.
