You are executing Phase 4 of a 5-phase hardening plan for the orchestrator extension (v0.2.0). This is an active implementation task — you should write code, not just plan.

## Project Context

orchestrator is a spec-kit extension (markdown commands + shell scripts) that provides autonomous multi-phase orchestration. It was field-tested and a post-mortem identified 8 failure categories. We are systematically fixing all of them across 5 phases.

## What Was Done in Phases 1-3 (COMPLETE — 363 assertions, 0 failures)

### Phase 1 (State Machine + Recording Scripts)

- `scripts/state/derive-phase.sh` — Added `verifying` state at priority 6. Now 10 states: pre-planning, discussing, planning, replanning, executing, verifying, summarizing, validating, completing, complete.
- `scripts/lifecycle/record-result.sh` (NEW) — Validates fields and appends JSONL to execution log. Interface: `record-result.sh <log> --milestone=M### --phase=P## --task=T## --outcome=<success|failure|retry|blocked|timeout|stuck> [--tier=C] [--dispatch_method=<subagent|sequential>] [--verification_result=<pass|fail|skipped>] [--attempt=N] [--duration_s=N]`. Output: `RECORD:APPENDED <log-file>`.
- `scripts/lifecycle/sync-roadmap.sh` (NEW) — Compares roadmap checkboxes with P##-SUMMARY.md existence. Interface: `sync-roadmap.sh <roadmap-file> <milestone-dir> [--fix]`. Output: `SYNC:OK` or `SYNC:MISMATCH phase=P## roadmap=<state> disk=<state>`.
- `extension.yml` — Version bumped to 0.2.0, provides.scripts now has 26 entries.
- `references/state-machine.md` — Updated to 10 states with new diagram and tables.
- `references/file-formats.md` — Expanded execution-log.jsonl format, added P##-VERIFICATION.md.
- Test fixtures and assertions updated across s01, s02, s05.

### Phase 2 (Capability Detection + Claude Code Appendix)

- `scripts/dispatch/detect-capabilities.sh` — Added `agent_tool_available` capability. Detects `CLAUDE_CODE` and `CURSOR_AGENT` environment variables. Now outputs 7 capabilities (was 6).
- `templates/claude-code-appendix.md` (NEW) — Platform-specific dispatch instructions for Claude Code: Agent tool invocation, mandatory write-summary.sh usage, mandatory record-result.sh usage, key rules.
- `templates/claude-settings.json` (NEW) — Recommended `.claude/settings.json` permissions for autonomous mode.
- `commands/dispatch.md` — Added "## Claude Code Appendix" section referencing the appendix template.
- Test updates: s03 (13 templates, 10 states), s04 (+3 Claude Code tests), s07 (7 capability keys).

### Phase 3 (Auto-Loop Driver + Auto.md Rewrite)

- `scripts/lifecycle/auto-loop.sh` (NEW, ~200 lines) — Single-step mechanical loop driver with two-phase execution model. Pre-dispatch (Steps A→D): derives state, checks budget/stuck, builds context payload. Post-dispatch (Steps G→I): records result via record-result.sh, updates lock, checks for more tasks, syncs roadmap. Exit codes: 0 (success), 1 (error), 2 (budget), 3 (stuck), 10 (complete), 11 (pause), 12 (unexpected state).
- `commands/auto.md` rewritten from 410 lines to 277 lines. Separates mechanical steps (auto-loop.sh) from agent judgment (dispatch, verification, phase transitions). Three-stage iteration pattern: Stage 1 (pre-dispatch, mechanical), Stage 2 (dispatch + verify, agent judgment), Stage 3 (post-dispatch, mechanical).
- `tests/fixtures/auto-loop/` — Minimal milestone fixture for auto-loop.sh testing.
- `extension.yml` — provides.scripts now has 26 entries.
- `tests/test-s01-structure.sh` — Script count assertion updated to 26.
- `tests/test-s05-autonomous-mode.sh` — Added Section 8 with 12 auto-loop.sh tests.

---

## Phase 4 Task: Verification Report Consumption + write-summary.sh Enforcement

**Addresses**: FC6 (verification report not consumed by auto loop — when a task fails verification and the agent retries, the retry payload should include the verification report's specific failures, but auto.md currently says "diagnostic context" without specifying the mechanical steps) and FC7 (phase summary written freeform instead of using write-summary.sh — auto.md tells the agent to "synthesize a phase-level summary" but doesn't enforce using `scripts/knowledge/write-summary.sh`, leading to freeform summaries missing the 16 required frontmatter fields).

### READ THESE FILES FIRST:

- `commands/auto.md` (277 lines — the file you will modify; pay close attention to the "Stage 2" section at lines ~96-109, the "Phase Transition" section at lines ~137-174, and the "Completion" section at lines ~176-199)
- `scripts/knowledge/write-summary.sh` (understand its interface — required fields for phase type: id, parent, milestone, provides, requires, affects, key_files, key_decisions, patterns_established, drill_down_paths, duration, verification_result, completed_at, observability_surfaces, body)
- `templates/claude-code-appendix.md` (already enforces write-summary.sh for dispatched tasks — Phase 4 extends this enforcement to phase transitions and milestone completion in auto.md)
- `tests/test-s05-autonomous-mode.sh` (Section 2 tests auto.md references — you will add assertions here)

### MODIFY:

1. **`commands/auto.md`** — Three targeted changes within the existing 277-line file:

   **Change 1 — Stage 2b (Verify): Add verification report capture for retry payload**

   Find the current Stage 2b content (around lines 104-109):
   ```markdown
   **b. Verify**: Run `speckit.orchestrator.verify` on the completed task.

   - **Pass** → proceed to Stage 3 with `outcome=success`, `verification_result=pass`
   - **Fail (first attempt)** → retry dispatch with diagnostic context from the verification report appended to the payload
   - **Fail (second attempt)** → record failure, write continue file, release lock, exit
   - **Pass with concerns (DONE_WITH_CONCERNS)** → evaluate: correctness concerns block, observational concerns proceed (US3 AS6)
   ```

   Replace with expanded instructions that specify HOW to capture and inject the verification report:
   ```markdown
   **b. Verify**: Run `speckit.orchestrator.verify` on the completed task. Capture the verification report output.

   - **Pass** → proceed to Stage 3 with `outcome=success`, `verification_result=pass`
   - **Fail (first attempt)** → retry dispatch. Construct the retry payload by appending a verification failure section to the original dispatch payload:

     ```
     ## Verification Failure Context

     The previous attempt failed verification. Address these specific failures before proceeding:

     <captured verification report output — include specific failed checks, failure messages, and any task summary from the failed attempt>
     ```

     Dispatch again with this augmented payload. The retry uses `--attempt=2` when recording.
   - **Fail (second attempt)** → record failure via `auto-loop.sh --step=G --task=T## --outcome=failure --verification_result=fail --attempt=2`, write continue file with the failed verification details, release lock, exit
   - **Pass with concerns (DONE_WITH_CONCERNS)** → evaluate: correctness concerns block, observational concerns proceed (US3 AS6)
   ```

   **Change 2 — Phase Transition, Stage 2: Enforce write-summary.sh for phase summaries**

   Find the current Phase Transition Stage 2 content (around lines 153-156):
   ```markdown
   2. **Stage 2 — Phase Summary**: If verification passes, produce the phase summary:
      - Read all task summaries from the phase
      - Synthesize a phase-level summary capturing: what was built, key decisions, patterns established, and verification results
      - Write to `<milestone-dir>/phases/<P##>/<P##>-SUMMARY.md`
   ```

   Replace with explicit write-summary.sh usage:
   ```markdown
   2. **Stage 2 — Phase Summary**: If verification passes, produce the phase summary using `write-summary.sh`. Read all task summaries from the phase to derive field values, then run:

      ```bash
      bash scripts/knowledge/write-summary.sh phase <milestone-dir>/phases/<P##>/<P##>-SUMMARY.md \
        --id=P## \
        --parent=M### \
        --milestone=M### \
        --provides="<what this phase delivers — derive from task summaries>" \
        --requires="<upstream dependencies — derive from phase plan>" \
        --affects="<downstream phases — derive from roadmap>" \
        --key_files="<key files created/modified across all tasks>" \
        --key_decisions="<decision IDs from this phase>" \
        --patterns_established="<patterns established across tasks>" \
        --drill_down_paths="<paths to task summaries>" \
        --duration=<total phase duration from execution log> \
        --verification_result=pass \
        --completed_at=<ISO-8601 timestamp> \
        --observability_surfaces="<metrics or logs if applicable>" \
        --body="<synthesized summary: what was built, key decisions, patterns, verification results>"
      ```

      Do NOT write phase summaries freeform. The 16 frontmatter fields are required for downstream consumption by `consolidate-artifacts.sh` and knowledge compounding.
   ```

   **Change 3 — Completion, `completing`: Enforce write-summary.sh for milestone summaries**

   Find the current `completing` content (around lines 188-193):
   ```markdown
   ### `completing`

   Write the milestone summary:
   1. Synthesize from all phase summaries
   2. Compress knowledge into milestone-scoped KNOWLEDGE.md entries
   3. State transitions to `complete`
   ```

   Replace with explicit write-summary.sh usage:
   ```markdown
   ### `completing`

   Write the milestone summary using `write-summary.sh`. Read all phase summaries to derive field values, then run:

   ```bash
   bash scripts/knowledge/write-summary.sh milestone <milestone-dir>/<M###>-SUMMARY.md \
     --id=M### \
     --parent=<feature-ref> \
     --milestone=M### \
     --provides="<what this milestone delivers — derive from phase summaries>" \
     --requires="<external dependencies>" \
     --affects="<downstream milestones or systems>" \
     --key_files="<key files across all phases>" \
     --key_decisions="<arch-scoped and milestone-scoped decisions>" \
     --patterns_established="<patterns established across phases>" \
     --drill_down_paths="<paths to phase summaries>" \
     --duration=<total milestone duration from execution log> \
     --verification_result=pass \
     --completed_at=<ISO-8601 timestamp> \
     --observability_surfaces="<metrics or logs if applicable>" \
     --body="<synthesized summary: what was built across all phases, cross-cutting patterns, verification results>"
   ```

   Do NOT write milestone summaries freeform. After writing, compress knowledge into milestone-scoped KNOWLEDGE.md entries. State transitions to `complete`.
   ```

   **Also add to Referenced Scripts** (if not already present):
   - `scripts/knowledge/write-summary.sh` — structured summary generation (task, phase, milestone)

2. **`tests/test-s05-autonomous-mode.sh`** — Add 3 assertions to Section 2 (auto.md Command File)

   After the existing test 2.10 (auto.md references scripts/verify/check-must-haves.sh), add:

   ```bash
   # --------------------------------------------------------------------------
   # 2.12 auto.md references scripts/knowledge/write-summary.sh
   # --------------------------------------------------------------------------
   if grep -q 'scripts/knowledge/write-summary.sh' "$AUTO_CMD"; then
     pass "auto.md references scripts/knowledge/write-summary.sh"
   else
     fail "auto.md references scripts/knowledge/write-summary.sh"
   fi

   # --------------------------------------------------------------------------
   # 2.13 auto.md Phase Transition enforces write-summary.sh (not freeform)
   # --------------------------------------------------------------------------
   if grep -q 'Do NOT write phase summaries freeform' "$AUTO_CMD"; then
     pass "auto.md Phase Transition enforces write-summary.sh (not freeform)"
   else
     fail "auto.md Phase Transition enforces write-summary.sh (not freeform)"
   fi

   # --------------------------------------------------------------------------
   # 2.14 auto.md Stage 2b documents verification failure payload construction
   # --------------------------------------------------------------------------
   if grep -q 'Verification Failure Context' "$AUTO_CMD"; then
     pass "auto.md Stage 2b documents verification failure payload construction"
   else
     fail "auto.md Stage 2b documents verification failure payload construction"
   fi
   ```

### FILES TO NOT MODIFY:

- No new scripts needed — write-summary.sh already exists
- No test fixture changes needed
- No extension.yml changes needed (script count stays at 26)
- No changes to test-s01, test-s02, test-s03, test-s04, test-s06, test-s07

### CONVENTIONS:

- All bash scripts: `#!/usr/bin/env bash` + `set -euo pipefail`
- All markdown templates: YAML frontmatter with `schema_version: "1.0"`
- Test assertions use `pass "description"` / `fail "description"` pattern
- Structured output prefixes: `AUTO:`, `RECORD:`, `SYNC:`, `SUMMARY:`, etc.
- When referencing write-summary.sh in auto.md, show the FULL field list — the agent executing auto mode needs to see every field to know what to derive from task summaries

### VERIFICATION:

After all changes, run:
```bash
for f in tests/test-s*.sh; do echo "=== $f ==="; bash "$f"; echo; done
```
Expected: 366+ assertions total (363 + 3 new), 0 failures across all 7 suites.

Key manual checks:
1. `commands/auto.md` contains `scripts/knowledge/write-summary.sh` (grep returns matches)
2. `commands/auto.md` contains `Verification Failure Context` (grep returns match)
3. `commands/auto.md` contains `Do NOT write phase summaries freeform` (grep returns match)
4. `commands/auto.md` contains `Do NOT write milestone summaries freeform` (grep returns match)
5. `commands/auto.md` Stage 2b shows `--attempt=2` for retry recording
6. `commands/auto.md` line count is ~305-320 (slightly up from 277 due to added write-summary.sh examples)
7. All 7 test suites pass

### AFTER COMPLETION:

When Phase 4 is done and all tests pass, write a handoff file at `.specify/orchestrator/handoff-phase5.md`. Phase 5 is the final phase of the hardening plan. Check the codebase for any remaining failure categories (FC1 and FC8) that haven't been addressed in Phases 1-4. If you cannot determine what FC1 and FC8 address from the codebase, note that in the handoff and list what the previous 4 phases covered (FC2-FC7) so the user can fill in the gaps.

Output the complete handoff-phase5.md content to the user so they can paste it into the next context window.
