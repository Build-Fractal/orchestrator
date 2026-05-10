---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M016"
name: "Update agent-facing command and template files to remove Class A patterns"
depends_on: []
---

## Prerequisites

P01 delivered cleaned `commands/auto.md` (write-summary examples already free of `$(...)`) and `ANTIPATTERNS.md` with AP-004. P02 delivered `scripts/verify/run-suite.sh` (single-script wrapper replacing chained verify pipelines). This task updates the remaining agent-facing files that still contain Class A patterns.

## Description

Update four agent-facing files to eliminate remaining Class A anti-patterns (command substitution, chained commands) from their code examples. These changes ensure that subagents reading these files will not reproduce patterns that trigger Claude Code safety prompts.

The four files and their specific changes:

1. **`commands/consolidate.md`** — Replace `state=$(bash scripts/state/derive-phase.sh <milestone-dir>)` with the file-based output pattern.
2. **`commands/plan-phase.md`** — The `$(...)` references in this file are all inside documentation of forbidden patterns (the AD-19 section). These are correctly marked as "FORBIDDEN" examples. No changes needed for those. Verify no other `$(...)` exists outside the forbidden-pattern documentation section.
3. **`templates/task-plan.md`** — Replace the `result=$(bash cmd | grep -c 'RESULT')` example in the Verification comment block. The comment already labels it "Forbidden" so the linter skips it, but the example should reference `run-suite.sh` as the recommended alternative for clarity.
4. **`templates/claude-code-appendix.md`** — The `$(...)` references are in "Do NOT use" warnings, not in code examples to follow. Verify they are correctly framed as warnings and will not be reproduced by subagents.

## Steps

### Step 1: Update commands/consolidate.md

Find the line (currently around line 42):
```bash
state=$(bash scripts/state/derive-phase.sh <milestone-dir>)
```

Replace with the file-based output pattern:
```bash
bash scripts/state/derive-phase.sh <milestone-dir> > <milestone-dir>/state-result.txt
```

And update the surrounding prose to read the file:

**Before** (lines 39-45):
```markdown
### Step 1 — Check Milestone State

Run state derivation to confirm the milestone is in `completing` or `complete` state:

` ``bash
state=$(bash scripts/state/derive-phase.sh <milestone-dir>)
` ``

If the state is not `completing` or `complete`, stop and inform the developer.
```

**After**:
```markdown
### Step 1 — Check Milestone State

Run state derivation to confirm the milestone is in `completing` or `complete` state. Do NOT use command substitution `$(...)` — it triggers the harness safety prompt (AD-19):

` ``bash
bash scripts/state/derive-phase.sh <milestone-dir>
` ``

Read the stdout output directly. If the state is not `completing` or `complete`, stop and inform the developer.
```

### Step 2: Verify commands/plan-phase.md

Read `commands/plan-phase.md` and confirm that all `$(...)` instances appear only inside the AD-19 forbidden-pattern documentation section (lines 107-135). These are examples of what NOT to do and are preceded by `# FORBIDDEN` comments. The linter (T01) skips `# FORBIDDEN` lines. No changes needed if all instances are in the forbidden-pattern section.

If any `$(...)` is found outside the forbidden-pattern section in a code block, replace it following the same pattern as Step 1.

### Step 3: Update templates/task-plan.md

The verification comment block (lines 30-47) contains a `result=$(bash cmd | grep -c 'RESULT')` example labeled "Forbidden." Update the "Required form" section to also reference `run-suite.sh`:

**Before** (around line 41):
```markdown
     Required form:
       bash scripts/verify/<phase>-<task>-<name>.sh
       bash scripts/verify/check-must-haves.sh <phase-dir>
```

**After**:
```markdown
     Required form:
       bash scripts/verify/<phase>-<task>-<name>.sh
       bash scripts/verify/check-must-haves.sh <phase-dir>
       bash scripts/verify/run-suite.sh <milestone> <phase>
```

### Step 4: Verify templates/claude-code-appendix.md

Read `templates/claude-code-appendix.md` and confirm that all `$(...)` references are in "Do NOT use" warning contexts, not in code blocks that a subagent would reproduce. Currently:
- Line 44: `$(date ...)` in a "Do NOT use" warning — correct, no change needed.
- Line 81: `output=$(bash ...)` in a "Do NOT use" warning — correct, no change needed.

If any `$(...)` appears in a code example block that demonstrates the correct/recommended approach, replace it.

### Step 5: Run the anti-pattern linter (from T01) to verify

After T01 completes, run:
```
bash scripts/verify/anti-pattern-lint.sh
```

Must exit 0 (no violations in any agent-facing file).

## Must-Haves

- `commands/consolidate.md` does not contain `state=$(bash` command substitution
- `templates/task-plan.md` references `run-suite.sh` in its verification comment
- No `$(...)` in agent-facing command/template code examples (except documented forbidden-pattern examples marked with `# FORBIDDEN`)

## Verification

```
bash scripts/verify/m016-p03-consolidate-clean.sh
bash scripts/verify/m016-p03-task-template-clean.sh
bash scripts/verify/m016-p03-appendix-clean.sh
```

Each must print `PASS:` and exit 0. Note: verify scripts are created in T04.

## Inputs

### From Disk (Pre-existing)
- commands/consolidate.md — contains `state=$(bash scripts/state/derive-phase.sh <milestone-dir>)` on line 42 inside a ```bash code block. The rest of the file describes the consolidation workflow. Must replace this one command-substitution example.
- commands/plan-phase.md — contains `$(...)` references only inside the AD-19 forbidden-pattern documentation section (lines 107-135). These are labeled `# FORBIDDEN` and describe what NOT to do. Verify no other `$(...)` exists outside that section.
- templates/task-plan.md — contains `result=$(bash cmd | grep -c 'RESULT')` on line 45 inside a comment block labeled "Forbidden." The "Required form" section (lines 41-42) lists two script invocations. Add `run-suite.sh` as a third.
- templates/claude-code-appendix.md — contains `$(date ...)` and `output=$(bash ...)` in "Do NOT use" warning text, not in code examples. Verify framing is correct.

## Constraints

- Do NOT modify the `# FORBIDDEN` example sections in `commands/plan-phase.md` — they serve as educational documentation.
- Replacements must maintain the same instructional intent (the developer/agent must still understand what to do).
- No new `$(...)` introduced in any replacement.

## Expected Output

- commands/consolidate.md modified: `state=$(bash ...)` replaced with direct invocation + read pattern.
- templates/task-plan.md modified: `run-suite.sh` added to the Required form list in the verification comment.
- commands/plan-phase.md and templates/claude-code-appendix.md verified clean (no changes needed if `$(...)` is only in forbidden/warning contexts).
