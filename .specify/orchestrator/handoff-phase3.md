# Phase 3 Handoff Prompt — Auto-Loop Driver + Auto.md Rewrite

You are executing Phase 3 of a 5-phase hardening plan for the spec-kit-orchestrator extension (v0.2.0). This is an active implementation task — you should write code, not just plan.

## Project Context

spec-kit-orchestrator is a spec-kit extension (markdown commands + shell scripts) that provides autonomous multi-phase orchestration. It was field-tested and a post-mortem identified 8 failure categories. We are systematically fixing all of them across 5 phases.

## What Was Done in Phases 1-2 (COMPLETE — 351 assertions, 0 failures)

### Phase 1 (State Machine + Recording Scripts)
- `scripts/state/derive-phase.sh` — Added `verifying` state at priority 6. Now 10 states: pre-planning, discussing, planning, replanning, executing, verifying, summarizing, validating, completing, complete.
- `scripts/lifecycle/record-result.sh` (NEW) — Validates fields and appends JSONL to execution log. Interface: `record-result.sh <log> --milestone=M### --phase=P## --task=T## --outcome=<success|failure|retry|blocked|timeout|stuck> [--tier=C] [--dispatch_method=<subagent|sequential>] [--verification_result=<pass|fail|skipped>] [--attempt=N] [--duration_s=N]`. Output: `RECORD:APPENDED <log-file>`.
- `scripts/lifecycle/sync-roadmap.sh` (NEW) — Compares roadmap checkboxes with P##-SUMMARY.md existence. Interface: `sync-roadmap.sh <roadmap-file> <milestone-dir> [--fix]`. Output: `SYNC:OK` or `SYNC:MISMATCH phase=P## roadmap=<state> disk=<state>`.
- `extension.yml` — Version bumped to 0.2.0, provides.scripts now has 25 entries.
- `references/state-machine.md` — Updated to 10 states with new diagram and tables.
- `references/file-formats.md` — Expanded execution-log.jsonl format, added P##-VERIFICATION.md.
- Test fixtures and assertions updated across s01, s02, s05.

### Phase 2 (Capability Detection + Claude Code Appendix)
- `scripts/dispatch/detect-capabilities.sh` — Added `agent_tool_available` capability. Detects `CLAUDE_CODE` and `CURSOR_AGENT` environment variables. Now outputs 7 capabilities (was 6).
- `templates/claude-code-appendix.md` (NEW) — Platform-specific dispatch instructions for Claude Code: Agent tool invocation, mandatory write-summary.sh usage, mandatory record-result.sh usage, key rules.
- `templates/claude-settings.json` (NEW) — Recommended `.claude/settings.json` permissions for autonomous mode.
- `commands/dispatch.md` — Added "## Claude Code Appendix" section referencing the appendix template.
- Test updates: s03 (13 templates, 10 states), s04 (+3 Claude Code tests), s07 (7 capability keys).

---

## Phase 3 Task: Auto-Loop Driver Script + Auto.md Rewrite

**Addresses**: FC3 (inline echo instead of record-result.sh in Step G), FC4 (no mechanical loop — agent re-reads 410 lines of prose each iteration), FC5 (auto.md mixes mechanical steps with judgment calls, making it hard for the agent to know which actions are scripted vs. which require reasoning).

This is the largest phase. It has two deliverables:

### READ THESE FILES FIRST:
- `commands/auto.md` (410 lines — the current prose-heavy auto mode command, to be rewritten)
- `scripts/lifecycle/record-result.sh` (understand interface — auto-loop.sh will call this)
- `scripts/lifecycle/sync-roadmap.sh` (understand interface — auto-loop.sh will call this)
- `scripts/lifecycle/lock-manager.sh` (understand interface — auto-loop.sh will call this)
- `scripts/lifecycle/stuck-detector.sh` (understand interface — auto-loop.sh will call this)
- `scripts/lifecycle/budget-checker.sh` (understand interface — auto-loop.sh will call this)
- `scripts/state/derive-phase.sh` (understand interface — auto-loop.sh will call this)
- `scripts/state/read-roadmap.sh` (understand interface — auto-loop.sh will call this)
- `scripts/state/read-config.sh` (understand interface — auto-loop.sh will call this)
- `scripts/dispatch/detect-capabilities.sh` (understand interface — auto-loop.sh will call this)
- `scripts/dispatch/build-context.sh` (understand interface — auto-loop.sh will call this)
- `templates/claude-code-appendix.md` (referenced by the new auto.md)
- `extension.yml` (will need provides.scripts update to 26)
- `tests/test-s01-structure.sh` (script count assertion → 26)
- `tests/test-s05-autonomous-mode.sh` (add auto-loop.sh tests)

### CREATE:

1. **`scripts/lifecycle/auto-loop.sh`** (~200 lines)
   A single-step mechanical loop driver. This script executes ONE iteration of the auto loop's mechanical steps, then exits with a structured status code and output. The agent (via auto.md) calls this script repeatedly.

   **Interface:**
   ```
   auto-loop.sh <milestone-dir> [--step=<A|B|C|D|E|G|H|I>]
   ```

   If `--step` is omitted, the script runs the full mechanical sequence (A→B→C→D→E is context build, G→H→I is post-dispatch). Steps E and F are NOT mechanical — they require agent judgment (dispatch execution + verification), so the script stops before E and resumes at G.

   **Two-phase execution model:**
   - **Phase 1 (pre-dispatch):** `auto-loop.sh <dir>` — runs Steps A→D:
     - A: derive state, identify next task
     - B: check budget
     - C: check stuck
     - D: build context payload
     - Outputs the payload to stdout and exits with status indicating "ready to dispatch"
   - **Phase 2 (post-dispatch):** `auto-loop.sh <dir> --step=G --task=T## --outcome=<success|failure> [--verification_result=<pass|fail|skipped>] [--duration_s=N]` — runs Steps G→I:
     - G: record result via `record-result.sh`
     - H: update lock via `lock-manager.sh`
     - I: check if more tasks remain, sync roadmap

   **Structured output (stdout):**
   ```
   AUTO:READY milestone=M### phase=P## task=T## payload_bytes=N
   ```
   or
   ```
   AUTO:RECORDED milestone=M### phase=P## task=T##
   AUTO:ADVANCE next_task=T## | AUTO:PHASE_COMPLETE phase=P## | AUTO:MILESTONE_VALIDATING | AUTO:MILESTONE_COMPLETE
   ```

   **Exit codes:**
   - 0: success (check stdout for action type)
   - 1: error (missing args, missing scripts)
   - 2: budget exceeded (wrote continue file, released lock)
   - 3: stuck detected (wrote continue file, released lock)
   - 10: milestone already complete
   - 11: pause requested (wrote continue file, released lock)
   - 12: unexpected state (released lock)

   **Key behaviors:**
   - Checks for pause-requested file at the top of pre-dispatch phase
   - Reads budget/duration config via `read-config.sh`
   - Identifies next task: scans `phases/<P##>/tasks/` for first T##-PLAN.md without T##-SUMMARY.md
   - Builds context via `build-context.sh` and captures payload
   - Records results via `record-result.sh` (replaces inline echo from FC3)
   - Syncs roadmap via `sync-roadmap.sh` after recording
   - Updates lock via `lock-manager.sh update`
   - Does NOT perform dispatch (that's the agent's job)
   - Does NOT perform verification (that's the agent's job)
   - Does NOT handle phase transitions (summarizing/completing — that's the agent's job per auto.md)
   - Must be `#!/usr/bin/env bash` with `set -euo pipefail`

2. **`tests/fixtures/auto-loop/`** — Fixture directory for auto-loop.sh tests
   Create a minimal milestone fixture with:
   - `milestones/M001/roadmap.md` — 2 phases (P01 complete, P02 with 2 tasks)
   - `milestones/M001/phases/P01/P01-SUMMARY.md` — completed phase
   - `milestones/M001/phases/P02/tasks/T01-PLAN.md` — task plan
   - `milestones/M001/phases/P02/tasks/T02-PLAN.md` — task plan
   - `milestones/M001/execution-log.jsonl` — empty file
   - `orchestrator.lock` should NOT exist (clean start)
   - `KNOWLEDGE.md` and `DECISIONS.md` — minimal content
   - A config file if needed by `read-config.sh`

### MODIFY:

1. **`commands/auto.md`** — Rewrite from ~410 lines to ~280 lines
   The new structure separates mechanical steps (scripted by auto-loop.sh) from judgment calls (performed by the agent). Key changes:

   **Keep:**
   - Prerequisites section (derive state, check lock, verify Tier C, worktree isolation)
   - Lock acquisition section
   - Pause handling section
   - Phase transition section (two-stage review, roadmap reassessment)
   - Completion section
   - Idempotency section
   - Error handling section
   - Gotchas section
   - Referenced scripts/templates sections

   **Replace the autonomous loop (Steps A-I) with:**
   ```markdown
   ## Autonomous Loop

   The loop uses `auto-loop.sh` to handle mechanical steps, with the agent performing
   dispatch and verification between calls.

   ### Iteration Pattern

   Each iteration has three stages:

   #### Stage 1 — Pre-Dispatch (mechanical)

   ```bash
   output=$(bash scripts/lifecycle/auto-loop.sh <milestone-dir>)
   ```

   Parse the output to get milestone, phase, task, and payload. The payload is written
   to stdout. Handle exit codes:
   - 0 + `AUTO:READY` → proceed to Stage 2
   - 2 → budget exceeded, loop ends
   - 3 → stuck detected, loop ends
   - 10 → milestone complete, loop ends
   - 11 → pause requested, loop ends
   - 12 → unexpected state, loop ends

   #### Stage 2 — Dispatch + Verify (agent judgment)

   1. **Dispatch**: Use the assembled payload to execute the task.
      - If `agent_tool_available=true` (from `detect-capabilities.sh`): Use the Agent tool
        with the payload as prompt. See `templates/claude-code-appendix.md`.
      - If `subagent_dispatch=true` but no agent tool: Use CLI subagent dispatch.
      - If `subagent_dispatch=false`: Execute sequentially in current context.

   2. **Verify**: Run `speckit.orchestrator.verify` on the completed task.
      - Pass → proceed to Stage 3 with outcome=success, verification_result=pass
      - Fail (first attempt) → retry dispatch with diagnostic context appended
      - Fail (second attempt) → record failure, write continue file, release lock, exit
      - Pass with concerns → evaluate: correctness concerns block, observational proceed

   #### Stage 3 — Post-Dispatch (mechanical)

   ```bash
   bash scripts/lifecycle/auto-loop.sh <milestone-dir> --step=G \
     --task=T## --outcome=success --verification_result=pass --duration_s=N
   ```

   Parse the output:
   - `AUTO:ADVANCE next_task=T##` → loop back to Stage 1
   - `AUTO:PHASE_COMPLETE phase=P##` → handle phase transition (see below)
   - `AUTO:MILESTONE_VALIDATING` → handle milestone validation (see below)
   - `AUTO:MILESTONE_COMPLETE` → release lock, report completion
   ```

   **Add to Referenced Scripts:**
   - `scripts/lifecycle/auto-loop.sh` — mechanical loop driver (pre-dispatch + post-dispatch)
   - `scripts/lifecycle/record-result.sh` — execution log recording
   - `scripts/lifecycle/sync-roadmap.sh` — roadmap-to-disk state synchronization

   **Add to Referenced Templates:**
   - `templates/claude-code-appendix.md` — Claude Code-specific dispatch instructions
   - `templates/claude-settings.json` — recommended project permissions

   **Remove from Step G:**
   The old inline `echo '{"timestamp":...}' >> execution-log.jsonl` pattern. This is now handled by `auto-loop.sh` calling `record-result.sh`.

2. **`extension.yml`** — Add `auto-loop.sh` to provides.scripts (now 26 entries)
   Add under the lifecycle scripts section:
   ```yaml
   - file: scripts/lifecycle/auto-loop.sh
   ```

3. **`tests/test-s01-structure.sh`** — Update script count assertion from 25 to 26

4. **`tests/test-s05-autonomous-mode.sh`** — Add Section 8: auto-loop.sh tests (~10-12 assertions)
   Test the mechanical behaviors:
   - `auto-loop.sh` no args → exit 1 with usage
   - `auto-loop.sh` with fixture → exit 0 + `AUTO:READY` output with task/phase/milestone
   - `auto-loop.sh` with all tasks complete → appropriate exit (phase complete or milestone state)
   - `auto-loop.sh --step=G` with required args → `AUTO:RECORDED` + `AUTO:ADVANCE` or `AUTO:PHASE_COMPLETE`
   - `auto-loop.sh` with pause-requested file → exit 11
   - `auto-loop.sh` with budget exceeded fixture → exit 2
   - Verify `auto-loop.sh` calls `record-result.sh` (check execution log has entry after --step=G)
   - Verify `auto-loop.sh` calls `sync-roadmap.sh` (or at least doesn't fail when roadmap exists)

5. **`tests/test-s07-integration.sh`** — The script count check (Section 4b) reads from disk and manifest dynamically, so it should auto-pass with the new script. No manual change needed unless it hardcodes "25". Check and update if necessary.

### CONVENTIONS:

- All bash scripts: `#!/usr/bin/env bash` + `set -euo pipefail`
- All markdown templates: YAML frontmatter with `schema_version: "1.0"`
- Test assertions use `pass "description"` / `fail "description"` pattern
- Structured output prefixes: `AUTO:`, `RECORD:`, `SYNC:`, etc.
- Exit codes are documented and tested
- Scripts do NOT perform agent-judgment actions (dispatch, verification, phase transition reasoning)

### VERIFICATION:

After all changes, run:
```bash
for f in tests/test-s*.sh; do echo "=== $f ==="; bash "$f"; echo; done
```
Expected: 363+ assertions total, 0 failures across all 7 suites.

Key manual checks:
1. `bash scripts/lifecycle/auto-loop.sh` (no args) → exit 1 with usage
2. `auto-loop.sh` with fixture → `AUTO:READY` output
3. `commands/auto.md` line count is ~280 (down from 410)
4. `commands/auto.md` references `auto-loop.sh` and `record-result.sh`
5. `extension.yml` provides.scripts has 26 entries
6. All 7 test suites pass

### AFTER COMPLETION:

When Phase 3 is done and all tests pass, write a handoff file at `.specify/orchestrator/handoff-phase4.md`. Phase 4 addresses FC6 (verification report not consumed by auto loop) and FC7 (phase summary written freeform instead of using write-summary.sh). It modifies `commands/auto.md` Phase Transition section to enforce `write-summary.sh` for phase summaries and ensures the verification report output is fed back into the dispatch retry payload. See the full plan for details.

Output the complete handoff-phase4.md content to the user so they can paste it into the next context window.
