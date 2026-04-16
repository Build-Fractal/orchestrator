# Phase 2 Handoff Prompt — Capability Detection + Claude Code Appendix

## What Was Done in Phase 1

Phase 1 completed successfully. All 7 test suites pass (345 assertions, 0 failures).

### Artifacts Created/Modified in Phase 1:
- **`scripts/state/derive-phase.sh`** — Added `verifying` state at priority 6. Now 10 states: pre-planning, discussing, planning, replanning, executing, **verifying**, summarizing, validating, completing, complete. The verifying state fires when all tasks have T##-SUMMARY.md but no P##-VERIFICATION.md exists.
- **`scripts/lifecycle/record-result.sh`** (NEW) — Validates fields and appends JSONL to execution log. Interface: `record-result.sh <log> --milestone=M### --phase=P## --task=T## --outcome=<success|failure|retry|blocked|timeout|stuck> [--tier=C] [--dispatch_method=<subagent|sequential>] [--verification_result=<pass|fail|skipped>] [--attempt=N] [--duration_s=N]`. Output: `RECORD:APPENDED <log-file>`.
- **`scripts/lifecycle/sync-roadmap.sh`** (NEW) — Compares roadmap checkboxes with P##-SUMMARY.md existence. Interface: `sync-roadmap.sh <roadmap-file> <milestone-dir> [--fix]`. Output: `SYNC:OK` or `SYNC:MISMATCH phase=P## roadmap=<state> disk=<state>`.
- **`extension.yml`** — Version bumped to 0.2.0, provides.scripts now has 25 entries (was 23).
- **`references/state-machine.md`** — Updated to 10 states with new diagram and tables.
- **`references/file-formats.md`** — Expanded execution-log.jsonl format, added P##-VERIFICATION.md to directory tree.
- **`tests/fixtures/state-verifying/`** (NEW) — Fixture for verifying state (all tasks done, no VERIFICATION.md).
- **`tests/fixtures/state-summarizing/`** — Added P02-VERIFICATION.md so it still derives as `summarizing`.
- **`tests/test-s01-structure.sh`** — Script count assertion updated to 25.
- **`tests/test-s02-state-machine.sh`** — Added `verifying` to STATE_NAMES/STATE_DIRS arrays (now 10 states).
- **`tests/test-s05-autonomous-mode.sh`** — Added Section 6 (record-result.sh: 6 tests) and Section 7 (sync-roadmap.sh: 4 tests).

---

## Phase 2 Task: Capability Detection + Claude Code Appendix

**Addresses**: FC2 (no fresh context isolation), environmental recommendation (permissions template)

### READ THESE FILES FIRST:
- `scripts/dispatch/detect-capabilities.sh` (86 lines — you will add CLAUDE_CODE env var detection and `agent_tool_available` capability)
- `commands/dispatch.md` (127 lines — add Claude Code appendix reference section)
- `extension.yml` (now ~190 lines — no script additions needed, but add template references if the manifest tracks templates)
- `tests/test-s04-core-commands.sh` (~70 assertions — add detect-capabilities Claude Code tests)
- `tests/test-s01-structure.sh` (20 assertions — may need template count update if tracked)
- `scripts/knowledge/write-summary.sh` (understand its interface for the appendix — 15 required fields for task, 16 for phase/milestone)
- `scripts/lifecycle/record-result.sh` (understand its interface for the appendix)

### CREATE:

1. **`templates/claude-code-appendix.md`** (~60 lines)
   Claude Code-specific dispatch instructions included via reference in auto.md and dispatch.md.
   Content should include:
   - **Agent Tool Invocation**: Explicit instruction to use the Agent tool for dispatch. Pattern: `Agent(prompt=<assembled dispatch payload>, subagent_type="general-purpose")`
   - **Summary Generation**: Explicit instruction to use `write-summary.sh` with ALL 15 fields (task) or 16 fields (phase/milestone). List every field name. Include the exact bash command template.
   - **Result Recording**: Explicit instruction to use `record-result.sh` after each task. Include the exact bash command template.
   - **Key Rules**:
     - "Do NOT write summaries freeform. Always use write-summary.sh."
     - "Do NOT skip verification. The state machine requires P##-VERIFICATION.md before summarizing."
     - "Do NOT use inline echo to log results. Always use record-result.sh."
   - **Permissions**: Reference `templates/claude-settings.json`.
   - Add `schema_version: "1.0"` frontmatter to match template conventions.

2. **`templates/claude-settings.json`** (~20 lines)
   Recommended `.claude/settings.json` for projects using orchestrator auto mode:
   ```json
   {
     "permissions": {
       "allow": [
         "Read",
         "Glob",
         "Grep",
         "Write",
         "Edit",
         "Bash(bash scripts/*)",
         "Bash(git *)",
         "Bash(rm -f .specify/orchestrator/pause-requested)",
         "Bash(rm -f .specify/orchestrator/continue.md)",
         "Bash(mkdir *)",
         "Bash(ls *)",
         "Bash(find *)",
         "Bash(wc *)",
         "Bash(date *)",
         "Agent"
       ]
     }
   }
   ```

### MODIFY:

1. **`scripts/dispatch/detect-capabilities.sh`**
   After the existing `command -v claude` check (around line 30-36), add detection for Claude Code and Cursor environments:
   ```bash
   # agent_tool_available: detect in-process agent tool via environment
   agent_tool_available=false
   if [[ -n "${CLAUDE_CODE:-}" ]]; then
     agent_tool_available=true
     subagent_dispatch=true
   elif [[ -n "${CURSOR_AGENT:-}" ]]; then
     agent_tool_available=true
     subagent_dispatch=true
   fi
   ```
   Add `agent_tool_available` to BOTH output formats:
   - Text: `echo "agent_tool_available=$agent_tool_available"` (add after existing echo lines)
   - JSON: add `"agent_tool_available": $agent_tool_available,` field

2. **`commands/dispatch.md`**
   Add a new section at the end (before Gotchas if it exists) titled "## Claude Code Appendix". Content:
   ```
   When running in Claude Code (detected via `CLAUDE_CODE` environment variable),
   see `templates/claude-code-appendix.md` for platform-specific dispatch instructions
   including Agent tool invocation, summary generation, and result recording.
   ```

3. **`tests/test-s04-core-commands.sh`**
   In the "--- Dispatch Scripts ---" section, after the existing `detect-capabilities.sh` test, add 3 tests:
   - `CLAUDE_CODE=1 bash detect-capabilities.sh` → output contains `agent_tool_available=true`
   - Without env var → output contains `agent_tool_available=false`
   - `detect-capabilities.sh --format json` output contains `"agent_tool_available"` key

4. **`tests/test-s01-structure.sh`**
   Check if there's a template count assertion. If not, no change needed. The current test checks script count (now 25), command count (10), hook count (5), config keys (7), etc. Templates are tested in test-s03. So S01 likely needs NO change for this phase.

### IMPORTANT NOTES:
- extension.yml does NOT track templates in provides (only scripts and config). Templates are validated by test-s03 which checks file existence. So you may need to add the two new templates to test-s03 IF it has a template count assertion. Check test-s03 for `template` count checks.
- The detect-capabilities.sh output currently has 6 keys. After adding `agent_tool_available`, it will have 7 keys. test-s07-integration.sh checks "JSON output contains all 6 expected capability keys" — this needs updating to 7.
- All scripts must use `#!/usr/bin/env bash` and `set -euo pipefail`.
- Templates must have YAML frontmatter with `schema_version: "1.0"`.

### VERIFICATION:
Run all 7 test suites. Expected: 348+ assertions, 0 failures.
```bash
for f in tests/test-s*.sh; do echo "=== $f ==="; bash "$f"; echo; done
```

Key checks:
1. `CLAUDE_CODE=1 bash scripts/dispatch/detect-capabilities.sh` outputs `agent_tool_available=true`
2. `bash scripts/dispatch/detect-capabilities.sh` (no env) outputs `agent_tool_available=false`
3. `templates/claude-code-appendix.md` exists, has frontmatter, references write-summary.sh
4. `templates/claude-settings.json` exists and is valid JSON
5. All 7 test suites pass
