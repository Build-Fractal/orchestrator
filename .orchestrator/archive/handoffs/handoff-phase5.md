# Phase 5 Handoff Prompt — Final Hardening: Consistency Gaps + Test Coverage

You are executing Phase 5 of a 5-phase hardening plan for the spec-kit-orchestrator extension (v0.2.0). This is the final phase. Read this document fully, then execute it.

## Project Context

spec-kit-orchestrator is a spec-kit extension (markdown commands + shell scripts) that provides autonomous multi-phase orchestration. It was field-tested and a post-mortem identified 8 failure categories. Phases 1-4 systematically fixed FC2-FC7. Phase 5 addresses the remaining consistency gaps and test coverage holes discovered via a full gap analysis of the codebase after Phases 1-4.

## What Was Done in Phases 1-4 (COMPLETE — 366 assertions, 0 failures)

### Phase 1 (State Machine + Recording Scripts)

- `scripts/state/derive-phase.sh` — Added `verifying` state at priority 6. Now 10 states: pre-planning, discussing, planning, replanning, executing, verifying, summarizing, validating, completing, complete.
- `scripts/lifecycle/record-result.sh` (NEW) — Validates fields and appends JSONL to execution log. Interface: `record-result.sh <log> --milestone=M### --phase=P## --task=T## --outcome=<success|failure|retry|blocked|timeout|stuck> [--tier=C] [--dispatch_method=<subagent|sequential>] [--verification_result=<pass|fail|skipped>] [--attempt=N] [--duration_s=N]`. Output: `RECORD:APPENDED <log-file>`.
- `scripts/lifecycle/sync-roadmap.sh` (NEW) — Compares roadmap checkboxes with P##-SUMMARY.md existence. Interface: `sync-roadmap.sh <roadmap-file> <milestone-dir> [--fix]`. Output: `SYNC:OK` or `SYNC:MISMATCH phase=P## roadmap=<state> disk=<state>`.
- `extension.yml` — Version bumped to 0.2.0, provides.scripts now has 26 entries.
- `references/state-machine.md` — Updated to 10 states with new diagram and tables.
- `references/file-formats.md` — Expanded execution-log.jsonl format, added P##-VERIFICATION.md to directory tree.
- Test fixtures and assertions updated across s01, s02, s05.

### Phase 2 (Capability Detection + Claude Code Appendix)

- `scripts/dispatch/detect-capabilities.sh` — Added `agent_tool_available` capability. Detects `CLAUDE_CODE` and `CURSOR_AGENT` environment variables. Now outputs 7 capabilities (was 6).
- `templates/claude-code-appendix.md` (NEW) — Platform-specific dispatch instructions for Claude Code: Agent tool invocation, mandatory write-summary.sh usage, mandatory record-result.sh usage, key rules.
- `templates/claude-settings.json` (NEW) — Recommended `.claude/settings.json` permissions for autonomous mode.
- `commands/dispatch.md` — Added "## Claude Code Appendix" section referencing the appendix template.
- Test updates: s03 (13 templates, 10 states), s04 (+3 Claude Code tests), s07 (7 capability keys).

### Phase 3 (Auto-Loop Driver + Auto.md Rewrite)

- `scripts/lifecycle/auto-loop.sh` (NEW, ~330 lines) — Single-step mechanical loop driver with two-phase execution model. Pre-dispatch (Steps A→D): derives state, checks budget/stuck, builds context payload. Post-dispatch (Steps G→I): records result via record-result.sh, updates lock, checks for more tasks, syncs roadmap. Exit codes: 0 (success), 1 (error), 2 (budget), 3 (stuck), 10 (complete), 11 (pause), 12 (unexpected state).
- `commands/auto.md` rewritten from 410 lines to 277 lines. Separates mechanical steps (auto-loop.sh) from agent judgment (dispatch, verification, phase transitions). Three-stage iteration pattern: Stage 1 (pre-dispatch, mechanical), Stage 2 (dispatch + verify, agent judgment), Stage 3 (post-dispatch, mechanical).
- `tests/fixtures/auto-loop/` — Minimal milestone fixture for auto-loop.sh testing.
- `tests/test-s05-autonomous-mode.sh` — Added Section 8 with 12 auto-loop.sh tests.

### Phase 4 (Verification Report Consumption + write-summary.sh Enforcement)

- `commands/auto.md` — Three targeted changes (now 324 lines, up from 277):
  - **Stage 2b (Verify)**: Expanded retry instructions to specify HOW to capture and inject the verification report. Retry payload includes a `## Verification Failure Context` section with specific failed checks, failure messages, and task summary. Second failure records via `auto-loop.sh --step=G --outcome=failure --verification_result=fail --attempt=2`.
  - **Phase Transition Stage 2**: Replaced freeform summary instruction with explicit `write-summary.sh phase` invocation showing all 16 required frontmatter fields. Added "Do NOT write phase summaries freeform" enforcement.
  - **Completion `completing`**: Replaced freeform milestone summary with explicit `write-summary.sh milestone` invocation showing all 16 required frontmatter fields. Added "Do NOT write milestone summaries freeform" enforcement.
  - Added `scripts/knowledge/write-summary.sh` to Referenced Scripts section.
- `tests/test-s05-autonomous-mode.sh` — Added 3 assertions (2.12-2.14): write-summary.sh reference, freeform enforcement, verification failure payload construction.

---

## Phase 5 Task: Final Hardening — Consistency Gaps + Test Coverage

Phase 5 addresses 7 specific issues discovered via full gap analysis. Each is described with exact file, line numbers, what to change, and why.

### READ THESE FILES FIRST:

- `commands/dispatch.md` (136 lines — you will replace inline echo with record-result.sh invocation)
- `commands/auto.md` (324 lines — you will add append-knowledge.sh and append-decision.sh invocations)
- `commands/status.md` (141 lines — you will fix line 106 incorrect reference)
- `templates/claude-code-appendix.md` (79 lines — you will add auto-loop.sh and sync-roadmap.sh references)
- `references/file-formats.md` (~450 lines — you will add P##-VERIFICATION.md format section)
- `scripts/verify/check-external-mods.sh` (123 lines — you will replace duplicated json_field with source)
- `scripts/util/json-field.sh` (20 lines — understand what gets sourced)
- `scripts/knowledge/append-knowledge.sh` (65 lines — understand interface for auto.md reference)
- `scripts/knowledge/append-decision.sh` (77 lines — understand interface for auto.md reference)
- `tests/test-s02-state-machine.sh` (line 31 — stale comment to fix)
- `tests/test-s03-design-artifacts.sh` (201 lines — you will add claude-settings.json test)
- `tests/test-s04-core-commands.sh` (877 lines — you will add dispatch.md record-result.sh assertion)
- `tests/test-s05-autonomous-mode.sh` (1224 lines — you will add auto.md knowledge script assertions)
- `templates/verification-report.md` (understand the format for file-formats.md documentation)

---

### CHANGE 1 — dispatch.md: Replace inline echo with record-result.sh

**File:** `commands/dispatch.md`
**Problem:** Lines 78-83 show manual `echo '{"timestamp":...}' >>` to execution-log.jsonl. This is exactly the pattern FC3 fixed in auto.md — but dispatch.md was never updated. Lines 91-93 also say "Record result: Update the execution log entry" without specifying record-result.sh.

**Find** (lines 76-93):
```markdown
## Execution Recording

After dispatching, record the execution in the append-only log:

```bash
# Append to execution-log.jsonl
echo '{"timestamp":"<ISO-8601>","milestone":"<M###>","phase":"<P##>","task":"<T##>","tier":"<tier>","dispatch_method":"<subagent|sequential>","payload_bytes":<N>,"budget_pct":<N>}' >> <milestone-dir>/execution-log.jsonl
```

The execution log is append-only (JSONL format) and provides the audit trail for dispatch history.

## Post-Dispatch

After the dispatched task completes:

1. **Run verification**: Invoke `speckit.orchestrator.verify` on the completed task to confirm must-haves are met.
2. **Record result**: Update the execution log entry with the verification result and duration.
3. **State transition**: If verification passes, the task is marked complete. The orchestrator state may transition based on remaining incomplete tasks.
```

**Replace with:**
```markdown
## Execution Recording

After dispatching, record the execution using `record-result.sh`. Do NOT use inline echo to append to the execution log.

```bash
bash scripts/lifecycle/record-result.sh <milestone-dir>/execution-log.jsonl \
  --milestone=M### \
  --phase=P## \
  --task=T## \
  --outcome=success \
  --tier=<tier> \
  --dispatch_method=<subagent|sequential> \
  --attempt=1 \
  --duration_s=<elapsed-seconds>
```

The execution log is append-only (JSONL format) and provides the audit trail for dispatch history.

## Post-Dispatch

After the dispatched task completes:

1. **Run verification**: Invoke `speckit.orchestrator.verify` on the completed task to confirm must-haves are met.
2. **Record result**: Record the verification outcome using `record-result.sh` with `--verification_result=<pass|fail|skipped>` and `--outcome=<success|failure>`.
3. **State transition**: If verification passes, the task is marked complete. The orchestrator state may transition based on remaining incomplete tasks.
```

**Also update Referenced Scripts** (line 124-132). Add after the last entry:
```markdown
- `scripts/lifecycle/record-result.sh` — execution log recording (append-only JSONL)
```

---

### CHANGE 2 — auto.md: Add append-knowledge.sh and append-decision.sh invocations

**File:** `commands/auto.md`

**Problem A — Line 239:** Says "compress knowledge into milestone-scoped KNOWLEDGE.md entries" but doesn't invoke `append-knowledge.sh`. The script exists at `scripts/knowledge/append-knowledge.sh` with interface: `append-knowledge.sh <knowledge-file> <entry-text> <scope>`. Output: `KNOWLEDGE: entry appended with scope [<scope>]`.

**Find** (line 239):
```markdown
Do NOT write milestone summaries freeform. After writing, compress knowledge into milestone-scoped KNOWLEDGE.md entries. State transitions to `complete`.
```

**Replace with:**
```markdown
Do NOT write milestone summaries freeform. After writing, compress knowledge into milestone-scoped KNOWLEDGE.md entries using `append-knowledge.sh`. For each key pattern or lesson from the milestone, run:

```bash
bash scripts/knowledge/append-knowledge.sh <orchestrator-root>/KNOWLEDGE.md \
  "<knowledge entry text>" \
  "milestone:M###"
```

Do NOT append to KNOWLEDGE.md freeform. State transitions to `complete`.
```

**Problem B — Lines 186-192:** Roadmap reassessment says "record in decisions register" without invoking `append-decision.sh`. The script exists at `scripts/knowledge/append-decision.sh` with interface: `append-decision.sh <decisions-file> <when> <scope> <decision> <choice> <rationale> [revisable]`. Output: `DECISION: D### appended`.

**Find** (lines 190-191):
```markdown
   - If no changes needed: log and proceed
   - If downstream phases affected: mark as stale (triggers `replanning`), record in decisions register
```

**Replace with:**
```markdown
   - If no changes needed: log and proceed
   - If downstream phases affected: mark as stale (triggers `replanning`), record the reassessment in the decisions register using `append-decision.sh`:

     ```bash
     bash scripts/knowledge/append-decision.sh <orchestrator-root>/DECISIONS.md \
       "M###/P##" "scope" "Roadmap reassessment after P## completion" \
       "<what changed>" "<why it changed>" "No"
     ```

     Do NOT append to DECISIONS.md freeform.
```

**Also update Referenced Scripts** (lines 300-317). Add after the `write-summary.sh` entry (line 314):
```markdown
- `scripts/knowledge/append-knowledge.sh` — scoped knowledge entry appending (append-only)
- `scripts/knowledge/append-decision.sh` — decision register row appending (append-only)
```

---

### CHANGE 3 — status.md: Fix incorrect completing guidance

**File:** `commands/status.md`

**Problem:** Line 106 says "Write the milestone summary via `speckit.orchestrator.consolidate`" — this is incorrect. The consolidate command archives artifacts and compresses knowledge; it does NOT write the milestone summary. The milestone summary is written via `write-summary.sh` as enforced in auto.md.

**Find** (line 106):
```markdown
| `completing` | Write the milestone summary via `speckit.orchestrator.consolidate`. |
```

**Replace with:**
```markdown
| `completing` | Write the milestone summary using `write-summary.sh`, then compress knowledge. |
```

---

### CHANGE 4 — claude-code-appendix.md: Add auto-loop.sh and sync-roadmap.sh

**File:** `templates/claude-code-appendix.md`

**Problem:** Phase 3 added `auto-loop.sh` and Phase 1 added `sync-roadmap.sh`, but the Claude Code appendix was never updated to reference them. Agents dispatched in Claude Code need to know about these scripts.

**Add a new section BEFORE the "## Key Rules" section (before line 70).** Insert:

```markdown
## Autonomous Loop Mechanics

When running in autonomous mode (`speckit.orchestrator.auto`), the mechanical loop driver handles pre-dispatch and post-dispatch steps:

### Pre-Dispatch (Stage 1)

```bash
output=$(bash scripts/lifecycle/auto-loop.sh <milestone-dir>)
```

Outputs `AUTO:READY milestone=M### phase=P## task=T## payload_bytes=N` on success. Exit codes: 0 (ready), 2 (budget exceeded), 3 (stuck), 10 (milestone complete), 11 (pause requested), 12 (unexpected state).

### Post-Dispatch (Stage 3)

```bash
bash scripts/lifecycle/auto-loop.sh <milestone-dir> --step=G \
  --task=T## --outcome=success --verification_result=pass --duration_s=N
```

Outputs `AUTO:RECORDED` followed by `AUTO:ADVANCE next_task=T##`, `AUTO:PHASE_COMPLETE phase=P##`, `AUTO:MILESTONE_VALIDATING`, or `AUTO:MILESTONE_COMPLETE`.

Do NOT call `record-result.sh` or `sync-roadmap.sh` directly during autonomous mode — `auto-loop.sh` wraps both.

## Roadmap Synchronization

After phase transitions, the roadmap is synchronized to disk state:

```bash
bash scripts/lifecycle/sync-roadmap.sh <roadmap-file> <milestone-dir> [--fix]
```

Outputs `SYNC:OK` when roadmap matches disk, or `SYNC:MISMATCH phase=P## roadmap=<state> disk=<state>`. Use `--fix` to auto-correct mismatches.

```

---

### CHANGE 5 — file-formats.md: Add P##-VERIFICATION.md format section

**File:** `references/file-formats.md`

**Problem:** The P##-VERIFICATION.md file is shown in the directory structure (line 32) but has no dedicated format section. All other file types have one.

**Add a new section AFTER the Task Plan section and BEFORE the Summaries section.** The Task Plan section ends around line 180 with a `---` separator. Insert the following new section between the Task Plan `---` and the `## Summaries` heading:

```markdown
## Phase Verification Report (`P##-VERIFICATION.md`)

**Location**: `.specify/orchestrator/milestones/{M###}/phases/{P##}/P##-VERIFICATION.md`
**Format**: YAML frontmatter + markdown body
**Mutability**: Written once at phase verification. Never edited after creation.

### Frontmatter Fields

```yaml
---
schema_version: "1.0"
type: verification-report
phase: P01
milestone: M001
overall_result: pass             # pass | fail
verified_at: "2026-03-20T15:00:00Z"
---
```

### Body Sections

```markdown
# P01 Verification Report

## Tier 1 — Static Checks
[Must-have verification results from check-must-haves.sh]

## Tier 2 — Command Execution
[Test/lint results from run-commands.sh]

## Tier 3 — Behavioral Review
[Agent-driven truth evaluation results]

## Tier 4 — Human/UAT Review
[Human review items and their status]

## Summary
[Overall assessment: pass/fail with specific failures listed]
```

### State Machine Role

The presence of `P##-VERIFICATION.md` is what transitions the state from `verifying` → `summarizing`. Without this file, `derive-phase.sh` returns `verifying` when all tasks have summaries.

---

```

---

### CHANGE 6 — check-external-mods.sh: Source json-field.sh instead of duplicating

**File:** `scripts/verify/check-external-mods.sh`

**Problem:** Lines 48-59 define a local `json_field()` function that is identical to `scripts/util/json-field.sh`. The shared utility was created during audit remediation (see KNOWLEDGE.md "Shared JSON Utility" pattern). `lock-manager.sh` and `recovery-briefing.sh` already source it.

**Find** (lines 48-59):
```bash
# --- Helper: Read a JSON field value (simple grep-based, no jq required) ---
json_field() {
  local file="$1"
  local key="$2"
  grep "\"${key}\"" "$file" 2>/dev/null \
    | head -1 \
    | sed 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*//' \
    | sed 's/^"//' \
    | sed 's/"[[:space:]]*,*[[:space:]]*$//' \
    | sed 's/,*[[:space:]]*$//' \
    | sed 's/[[:space:]]*$//'
}
```

**Replace with:**
```bash
# --- Helper: Read a JSON field value (shared utility) ---
SCRIPT_DIR_EM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR_EM}/../util/json-field.sh"
```

**Note:** The variable name `SCRIPT_DIR_EM` avoids collision with any existing `SCRIPT_DIR` variable. Check the file for existing SCRIPT_DIR usage and adjust the variable name if needed. The relative path `../util/json-field.sh` is correct because `check-external-mods.sh` is in `scripts/verify/` and `json-field.sh` is in `scripts/util/`.

---

### CHANGE 7 — Test coverage gaps

**File:** `tests/test-s02-state-machine.sh`

**Fix stale comment.** Find line 31:
```bash
# 1. State derivation tests (9 states)
```

Replace with:
```bash
# 1. State derivation tests (10 states)
```

---

**File:** `tests/test-s03-design-artifacts.sh`

**Add claude-settings.json existence and JSON validity test.** After the TEMPLATE_FILES array and existence loop (after line 56), add a new section:

```bash
# --------------------------------------------------------------------------
# 1b. claude-settings.json exists and is valid JSON
# --------------------------------------------------------------------------
SETTINGS_JSON="$PROJECT_ROOT/templates/claude-settings.json"
if [ -f "$SETTINGS_JSON" ]; then
  pass "templates/claude-settings.json exists"
  # Validate it's parseable JSON (basic check: starts with { and ends with })
  first_char=$(head -c 1 "$SETTINGS_JSON")
  if [ "$first_char" = "{" ]; then
    pass "templates/claude-settings.json is valid JSON (starts with {)"
  else
    fail "templates/claude-settings.json is valid JSON (first char: '$first_char')"
  fi
else
  fail "templates/claude-settings.json exists"
  fail "templates/claude-settings.json is valid JSON (file not found)"
fi
```

This adds 2 assertions (65 total for s03, up from 63).

---

**File:** `tests/test-s04-core-commands.sh`

**Add dispatch.md record-result.sh cross-reference assertion.** After the dispatch.md/build-context cross-reference test (after line 765), add:

```bash
# dispatch.md references record-result.sh
if grep -q "record-result" "$PROJECT_ROOT/commands/dispatch.md"; then
  pass "dispatch.md references record-result"
else
  fail "dispatch.md references record-result"
fi
```

This adds 1 assertion (74 total for s04, up from 73).

---

**File:** `tests/test-s05-autonomous-mode.sh`

**Add auto.md knowledge script assertions.** After the existing test 2.14 (verification failure payload construction) and before the Section 3 header, add:

```bash
# --------------------------------------------------------------------------
# 2.15 auto.md references scripts/knowledge/append-knowledge.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/knowledge/append-knowledge.sh' "$AUTO_CMD"; then
  pass "auto.md references scripts/knowledge/append-knowledge.sh"
else
  fail "auto.md references scripts/knowledge/append-knowledge.sh"
fi

# --------------------------------------------------------------------------
# 2.16 auto.md references scripts/knowledge/append-decision.sh
# --------------------------------------------------------------------------
if grep -q 'scripts/knowledge/append-decision.sh' "$AUTO_CMD"; then
  pass "auto.md references scripts/knowledge/append-decision.sh"
else
  fail "auto.md references scripts/knowledge/append-decision.sh"
fi

# --------------------------------------------------------------------------
# 2.17 auto.md enforces no freeform knowledge appending
# --------------------------------------------------------------------------
if grep -q 'Do NOT append to KNOWLEDGE.md freeform' "$AUTO_CMD"; then
  pass "auto.md enforces no freeform knowledge appending"
else
  fail "auto.md enforces no freeform knowledge appending"
fi

# --------------------------------------------------------------------------
# 2.18 auto.md enforces no freeform decision appending
# --------------------------------------------------------------------------
if grep -q 'Do NOT append to DECISIONS.md freeform' "$AUTO_CMD"; then
  pass "auto.md enforces no freeform decision appending"
else
  fail "auto.md enforces no freeform decision appending"
fi
```

This adds 4 assertions (100 total for s05, up from 96).

---

### FILES TO NOT MODIFY:

- No new scripts needed — all referenced scripts already exist
- No extension.yml changes needed (script count stays at 26, version stays at 0.2.0)
- No test fixture changes needed
- No changes to test-s06 or test-s07

### CONVENTIONS (same as all prior phases):

- All bash scripts: `#!/usr/bin/env bash` + `set -euo pipefail`
- All markdown templates: YAML frontmatter with `schema_version: "1.0"`
- Test assertions use `pass "description"` / `fail "description"` pattern
- Structured output prefixes: `AUTO:`, `RECORD:`, `SYNC:`, `SUMMARY:`, `KNOWLEDGE:`, `DECISION:`, etc.
- Bash 3.2 compatible (no `declare -A`)

### VERIFICATION:

After all changes, run:
```bash
for f in tests/test-s*.sh; do echo "=== $f ==="; bash "$f"; echo; done
```
Expected: 373+ assertions total (366 + 2 s03 + 1 s04 + 4 s05), 0 failures across all 7 suites.

### KEY MANUAL CHECKS:

1. `grep 'record-result' commands/dispatch.md` → finds `record-result.sh` invocation (not inline echo)
2. `grep 'inline echo' commands/dispatch.md` → no matches (old pattern removed)
3. `grep 'append-knowledge.sh' commands/auto.md` → finds invocation
4. `grep 'append-decision.sh' commands/auto.md` → finds invocation
5. `grep 'Do NOT append to KNOWLEDGE.md freeform' commands/auto.md` → finds enforcement
6. `grep 'Do NOT append to DECISIONS.md freeform' commands/auto.md` → finds enforcement
7. `grep 'write-summary.sh' commands/status.md` → line 106 updated
8. `grep 'consolidate' commands/status.md` → should NOT appear on line 106 for completing state
9. `grep 'auto-loop.sh' templates/claude-code-appendix.md` → finds documentation
10. `grep 'sync-roadmap.sh' templates/claude-code-appendix.md` → finds documentation
11. `grep 'VERIFICATION.md' references/file-formats.md` → finds dedicated format section (not just directory tree)
12. `grep 'json_field' scripts/verify/check-external-mods.sh` → should find `source` line, NOT function definition
13. `grep '10 states' tests/test-s02-state-machine.sh` → updated comment
14. All 7 test suites pass with 373+ assertions, 0 failures

### EXPECTED ASSERTION TOTALS AFTER PHASE 5:

| Suite | Before | After | Delta |
|-------|--------|-------|-------|
| test-s01-structure.sh | 20 | 20 | +0 |
| test-s02-state-machine.sh | 29 | 29 | +0 (comment fix only) |
| test-s03-design-artifacts.sh | 63 | 65 | +2 |
| test-s04-core-commands.sh | 73 | 74 | +1 |
| test-s05-autonomous-mode.sh | 96 | 100 | +4 |
| test-s06-knowledge-lifecycle.sh | 57 | 57 | +0 |
| test-s07-integration.sh | 28 | 28 | +0 |
| **Total** | **366** | **373** | **+7** |

### CHANGE SUMMARY:

| # | File | Change | Addresses |
|---|------|--------|-----------|
| 1 | commands/dispatch.md | Replace inline echo with record-result.sh invocation | FC3 consistency gap |
| 2 | commands/auto.md | Add append-knowledge.sh + append-decision.sh invocations | Freeform knowledge/decision ops |
| 3 | commands/status.md | Fix completing state guidance (consolidate → write-summary.sh) | Incorrect cross-reference |
| 4 | templates/claude-code-appendix.md | Add auto-loop.sh + sync-roadmap.sh documentation | Phase 3 additions not reflected |
| 5 | references/file-formats.md | Add P##-VERIFICATION.md format section | Phase 1 addition not documented |
| 6 | scripts/verify/check-external-mods.sh | Source json-field.sh instead of duplicating | Code duplication (audit pattern) |
| 7a | tests/test-s02-state-machine.sh | Fix stale "9 states" → "10 states" comment | Stale documentation |
| 7b | tests/test-s03-design-artifacts.sh | Add claude-settings.json existence + validity tests | Zero test coverage |
| 7c | tests/test-s04-core-commands.sh | Add dispatch.md record-result.sh cross-reference test | Missing cross-reference assertion |
| 7d | tests/test-s05-autonomous-mode.sh | Add 4 auto.md knowledge script assertions | Missing coverage for Change 2 |
