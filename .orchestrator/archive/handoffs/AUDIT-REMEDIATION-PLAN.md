# Audit Remediation Plan — v0.1.0

Created: 2026-03-20
Status: Complete
Phases: 4 (execute sequentially with context resets between each)

## Overview

Addresses all findings from the comprehensive v0.1.0 audit: documentation accuracy fixes, FR-030 gotchas sections, test coverage gaps, and spec clarifications. Each phase is self-contained and ends with a handoff prompt for the next context.

---

## Phase 1 of 4: Documentation Accuracy + Spec Clarifications

**Goal**: Fix all documentation inaccuracies and add spec clarifications. No behavioral changes.

### Tasks

1. **Fix "14-field" frontmatter references**
   - `templates/README.md` line 14: Change `(14-field frontmatter)` to `(15-field frontmatter)`
   - `.specify/orchestrator/KNOWLEDGE.md` line 38: Change `14-field schema` to accurate count (15 fields for task, 16 for phase/milestone including observability_surfaces)

2. **Fix verify.md trigger phrasing (FR-029)**
   - `commands/verify.md` line 2: Change description from `"Run mechanical verification..."` to `"Use when running mechanical verification for a completed task or phase..."`

3. **Standardize test summary output format**
   - All 7 test files should use the same format: `$PASS_COUNT/$TOTAL checks passed`
   - Fix `test-s03-design-artifacts.sh`: Change `"$PASS_COUNT of $TOTAL assertions passed"` to `"$PASS_COUNT/$TOTAL checks passed"`
   - Fix `test-s05-autonomous-mode.sh`: Remove `echo "--- Overall Results ---"` prefix line
   - Fix `test-s06-knowledge-lifecycle.sh`: Change `echo "--- Summary ---"` + `"Total: $TOTAL  Passed: $PASS_COUNT  Failed: $FAIL_COUNT"` to just `"$PASS_COUNT/$TOTAL checks passed"`
   - Fix `test-s07-integration.sh`: Same as S06
   - Keep the `$FAIL_COUNT checks FAILED` line in S04 and S05 (useful diagnostic on failure)

4. **Add Lock File CI liveness note**
   - `references/file-formats.md`: Add a note in the Lock File section that CI runtime liveness checks (GitHub API `run_id` lookup) are deferred to US7. Local PID checking via `kill -0` is the only implemented strategy in v0.1.0.

5. **Add explicit DONE_WITH_CONCERNS documentation**
   - `commands/auto.md`: In the post-dispatch/verify section, add explicit documentation for how DONE_WITH_CONCERNS is evaluated: concerns affecting correctness/scope → block and address; observational concerns → note in task summary and proceed. Reference US3 AS6.

6. **Run all tests to confirm no regressions**

### Verification
- All 307 tests pass (format changes don't affect assertion counts)
- `grep -c "14-field"` returns 0 across templates/README.md and KNOWLEDGE.md
- `grep "Use when" commands/verify.md` matches trigger phrasing

---

## Phase 2 of 4: FR-030 Gotchas Sections

**Goal**: Add dedicated "Gotchas" sections to the 6 commands that lack them. Extract from existing error handling — content is present, just needs reorganization under the required section header.

### Commands needing Gotchas sections

1. **evaluate.md** — Gotchas:
   - Tier A produces zero orchestrator state — promotion requires fresh evaluate with override
   - Re-evaluation with --force overwrites tier metadata; existing roadmap becomes inconsistent
   - read-config.sh failure is non-fatal (falls back to auto-classification), but missing config means no default_tier override

2. **discuss.md** — Gotchas:
   - Running discuss on a Tier B project is allowed but optional; running it on Tier A is a no-op
   - Finalizing an empty context draft is allowed but produces a vacuous planning gate
   - Context draft malformed frontmatter → warn and attempt repair, but if status field is missing, state machine cannot transition

3. **roadmap.md** — Gotchas:
   - Generating a roadmap when one exists requires confirmation — silent overwrite is prevented
   - Tier C without finalized context draft → blocked at state check, not at roadmap generation
   - Boundary map conflicts (two phases producing same artifact) should be caught during validation but are agent-evaluated, not mechanically enforced

4. **plan-phase.md** — Gotchas:
   - Truths without `Check:` sub-items are Tier 3 (behavioral) — not mechanically verifiable
   - Task plans that reference files not yet created by upstream tasks will fail verification if upstream hasn't run
   - Phase plan overwrite requires confirmation; partial overwrite is not supported (all-or-nothing)

5. **dispatch.md** — Gotchas:
   - Context budget exceeded is a warning unless budget_enforcement is "enforced"
   - Dispatch to a task with existing T##-SUMMARY.md is a no-op (idempotency), not an error
   - If detect-capabilities.sh reports no subagent support, dispatch falls back to sequential in-session execution with explicit context separation instructions — the dispatched task still runs, just not in isolation

6. **verify.md** — Gotchas:
   - Tier 1 failures don't short-circuit other tiers; full report is always produced
   - Behavioral truths without `Check:` commands are Tier 3 (agent judgment) — they cannot fail mechanically
   - External modification detection is informational only (warnings, not failures)
   - Re-verify with --force rechecks everything; without it, cached results are returned if no files changed

### Format
Each Gotchas section follows this pattern (placed after Error Handling, before Referenced Scripts):
```markdown
## Gotchas

- **<issue>**: <explanation with consequence>
- **<issue>**: <explanation with consequence>
```

### Verification
- All 307 tests still pass (gotchas are documentation-only, no behavioral change)
- `grep -l "## Gotchas" commands/*.md` returns all 10 command files
- Content is accurate to existing error handling and spec requirements

---

## Phase 3 of 4: Test Coverage — Structural Tests

**Goal**: Add test fixtures and assertions for Tier A zero-artifacts, boundary map enforcement, external modification detection, and payload ratio verification.

### Task 1: Tier A zero-artifacts test (FR-001, FR-003)

Add to `test-s02-state-machine.sh`:

- Create fixture `tests/fixtures/state-tier-a/` — empty directory (no M###-* files, no orchestrator state)
- Assert: derive-phase.sh on an empty directory returns `pre-planning` (or errors gracefully)
- Assert: no `.specify/orchestrator/milestones/` directory would be created for Tier A

Add to `test-s04-core-commands.sh`:
- Assert: evaluate.md contains "Tier A" routing to standard spec-kit
- Assert: evaluate.md contains "zero additional files" or "no orchestrator" language

### Task 2: check-boundary-map.sh contract violation test (FR-008)

Add to `test-s04-core-commands.sh`:

- Create fixture `tests/fixtures/verify-boundary-fail/` with:
  - A roadmap declaring P01 produces `src/api.ts:createUser()`
  - A phase directory where `src/api.ts` exists but does NOT contain `createUser`
- Assert: `check-boundary-map.sh` outputs `FAIL:` for the missing contract
- Assert: exit code is 1

### Task 3: check-external-mods.sh test (FR-064)

Add to `test-s04-core-commands.sh` or `test-s05-autonomous-mode.sh`:

- Create a temporary git repo fixture in test setup
- Create a lock file with `phase_start_tree` pointing to initial commit
- Make a modification to a file after the tree hash
- Assert: `check-external-mods.sh` detects the modification and outputs `WARN:`
- Assert: exit code is 2
- Clean up temp git repo in teardown

### Task 4: build-context.sh payload ratio test (SC-002)

Add to `test-s04-core-commands.sh`:

- Use existing `tests/fixtures/dispatch-state/` fixture (or extend it)
- Run `build-context.sh` and capture stderr
- Assert: stderr output contains a percentage
- Assert: the percentage is less than 100% (payload is subset of total)

### Verification
- All existing 307 tests still pass
- New assertions bring total to ~320+
- `bash tests/test-s02-state-machine.sh` and `bash tests/test-s04-core-commands.sh` pass with new assertions

---

## Phase 4 of 4: Test Coverage — Behavioral Tests

**Goal**: Add pause/resume round-trip test and idempotency tests for roadmap, verify, and dispatch commands.

### Task 1: Pause → continue file → resume round-trip (FR-047, FR-048, FR-049)

Add to `test-s05-autonomous-mode.sh`:

- Create fixture `tests/fixtures/auto-pause/` with:
  - A valid milestone directory in executing state
  - A `continue.md` file with proper frontmatter (milestone, phase, task, step, saved_at)
  - Body sections: Completed Work, Remaining Work, Decisions Made, Context, Next Action
- Assert: resume.md references continue-file.md template
- Assert: continue file fixture has required frontmatter fields (milestone, phase, task, step, saved_at)
- Assert: continue file fixture has required body sections (Completed Work, Remaining Work, Next Action)
- Assert: resume.md documents that continue file is consumed (deleted) on resume

### Task 2: Idempotency tests (FR-066)

Add to `test-s04-core-commands.sh` or new section in `test-s07-integration.sh`:

**Roadmap idempotency**:
- Assert: roadmap.md contains "existing roadmap" or "already exists" and "confirmation" language (overwrite protection)

**Verify idempotency**:
- Assert: verify.md contains "cached result" or "already verified" language
- Assert: verify.md documents --force flag for re-verification

**Dispatch idempotency**:
- Assert: dispatch.md contains "T##-SUMMARY.md" and "skip" or "no-op" language (already-completed task detection)

**Scaffold idempotency** (already tested in S02, extend):
- Run scaffold.sh twice on same directory, capture md5 of all files
- Assert: md5 sums are identical between runs

### Task 3: Scope filtering with multiple milestones (FR-062)

Add to `test-s04-core-commands.sh`:

- Create fixture `tests/fixtures/dispatch-multi-scope/` with KNOWLEDGE.md containing:
  - 3 entries scoped `[project]`
  - 3 entries scoped `[milestone:M001]`
  - 3 entries scoped `[milestone:M002]`
  - 3 entries scoped `[phase:M001/P03]`
- Run scope-filter.sh with `--milestone M001 --phase P01`
- Assert: output includes all `[project]` entries
- Assert: output includes `[milestone:M001]` entries
- Assert: output excludes `[milestone:M002]` entries
- Assert: output excludes `[phase:M001/P03]` entries (P03 not current phase or upstream)

### Verification
- All tests pass (old + new)
- Total assertion count updated in CLAUDE.md
- Run full suite: `for t in tests/test-*.sh; do bash "$t"; done`

---

## Handoff Prompts

### Start Phase 1
```
I'm working through the audit remediation plan at .specify/orchestrator/AUDIT-REMEDIATION-PLAN.md.

Execute Phase 1 of 4: Documentation Accuracy + Spec Clarifications.

Read the plan file first, then implement all 6 tasks in Phase 1. Run all tests after changes to confirm no regressions. When done, commit the changes with a descriptive message and output the Phase 2 handoff prompt.
```

### Start Phase 2
```
I'm working through the audit remediation plan at .specify/orchestrator/AUDIT-REMEDIATION-PLAN.md.

Execute Phase 2 of 4: FR-030 Gotchas Sections.

Read the plan file first, then add Gotchas sections to all 6 commands listed. Extract content from existing error handling — the failure modes are already documented, they just need reorganization under a dedicated "## Gotchas" header. Run all tests after changes to confirm no regressions. When done, commit the changes and output the Phase 3 handoff prompt.
```

### Start Phase 3
```
I'm working through the audit remediation plan at .specify/orchestrator/AUDIT-REMEDIATION-PLAN.md.

Execute Phase 3 of 4: Test Coverage — Structural Tests.

Read the plan file first, then implement all 4 test tasks. Create fixtures, add assertions to existing test files. The test convention is: pass()/fail() functions, structured PASS:/FAIL: output, bash 3.2 compatible (no declare -A), summary line format "$PASS_COUNT/$TOTAL checks passed". Run all tests after changes to confirm everything passes. When done, commit the changes and output the Phase 4 handoff prompt.
```

### Start Phase 4
```
I'm working through the audit remediation plan at .specify/orchestrator/AUDIT-REMEDIATION-PLAN.md.

Execute Phase 4 of 4: Test Coverage — Behavioral Tests.

Read the plan file first, then implement all 3 test tasks. Create fixtures, add assertions to existing test files. Follow the same test conventions as Phase 3. Run the full test suite. Update the assertion count in CLAUDE.md to match the new total. When done, commit the changes, mark the plan as complete, and provide a final summary of all changes made across all 4 phases.
```
