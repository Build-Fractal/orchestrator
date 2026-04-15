---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M006"
name: "Create docs/hook-development.md — writing hooks, verdict protocol, examples"
depends_on: ["T01"]
---

## Prerequisites

- `docs/` directory exists (created by T01).
- P02 reference docs exist: `references/hooks.md`, `references/events.md`,
  `references/errors.md`.

## Description

Create a user guide at `docs/hook-development.md` that teaches a user how to
write, test, and debug custom hooks for the orchestrator. Unlike
`references/hooks.md` which is the complete hook reference, this guide is
task-oriented — it walks through building real hooks with explained code.
The audience is "users" (DC-2).

The guide follows progressive disclosure (DC-1): start with what hooks are
and when to use them, then build through the verdict protocol, testing, and
two full worked examples. All cross-links use relative paths (DC-3).

The document covers:

1. **Overview** — what hooks are, when to use them, the four lifecycle
   points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE), and
   how hooks integrate with the engine pipeline (2-3 paragraphs).
   Cross-links to `references/hooks.md`.

2. **Hook Basics** — the minimum viable hook:
   - Where hooks live (`hooks.yaml` configuration)
   - Hook script structure (shebang, arguments, stdout protocol)
   - The frozen snapshot: what data the hook receives
   - How the engine invokes hooks and processes their output

3. **Verdict Protocol** — the four verdict types and what each means:
   - `PASS` — hook approves, execution continues
   - `BLOCK` — hook rejects, execution stops with HOOK_BLOCKED event
   - `WARN` — hook flags concern but allows execution to continue
   - `NEEDS_REVIEW` — hook flags for human review, may pause execution
   How to emit verdicts from a hook script. Cross-links to
   `references/hooks.md` for full protocol details.

4. **Testing Hooks** — how to test a hook before deploying it:
   - Creating a test fixture directory
   - Running a hook manually against a frozen snapshot
   - Verifying verdict output
   - Using dry-run mode to test hook integration

5. **Debugging Hook Failures** — common issues and how to diagnose them:
   - Hook script not found (path issues)
   - Hook exits non-zero without emitting a verdict
   - Timeout behavior (hook runs too long)
   - Frozen snapshot missing expected data
   - HOOK_BLOCKED events in execution log

6. **Example: Budget Gate Hook** — a complete worked example:
   - Goal: block dispatch if budget is within 10% of ceiling
   - Reading budget data from the frozen snapshot
   - Emitting BLOCK with a descriptive message
   - Testing the hook with a fixture
   - Deploying to `hooks.yaml`

7. **Example: Quality Check Hook** — a complete worked example:
   - Goal: WARN if a task summary is below minimum quality threshold
   - Reading task summary from the frozen snapshot
   - Checking word count, required sections, completeness markers
   - Emitting WARN with specific feedback
   - Deploying to `hooks.yaml`

## Steps

### Step 1 — Read source materials for accuracy

- `references/hooks.md` — full hook reference (361 lines)
- `references/events.md` — HOOK_BLOCKED, HOOK_WARNING events (617 lines)
- `references/errors.md` — error taxonomy for hook failures (316 lines)
- `scripts/lib/hooks.sh` — hook execution engine (how hooks are invoked)
- `scripts/lib/verdicts.sh` — verdict protocol implementation
- `templates/hooks.yaml` — hooks configuration template (if it exists)
- `references/engine.md` — how hooks fit in the engine pipeline (245 lines)

### Step 2 — Write docs/hook-development.md

Create the file following the structure in the Description section.
Ensure all code examples are Bash 3.2 compatible (DC-6). The two worked
examples should be complete, runnable scripts — not pseudocode.

### Step 3 — Verify-as-you-write (DC-4)

For every claim about hook behavior:
- Confirm by reading `scripts/lib/hooks.sh` and `scripts/lib/verdicts.sh`.

For the verdict protocol:
- Confirm the four verdict types match what `scripts/lib/verdicts.sh` accepts.

For the frozen snapshot structure:
- Confirm the snapshot fields match what `scripts/lib/hooks.sh` assembles.

For the two worked examples:
- Confirm the hook script structure matches what the engine expects.
- Confirm the `hooks.yaml` configuration matches the expected format.

## Must-Haves

- [ ] `docs/hook-development.md` exists and is 150+ lines
- [ ] File opens with progressive disclosure statement and audience label "users"
- [ ] Contains `## Overview` section
- [ ] Documents all 4 lifecycle points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE)
- [ ] Documents verdict protocol with all 4 types (PASS, BLOCK, WARN, NEEDS_REVIEW)
- [ ] Includes a testing section
- [ ] Includes a debugging section
- [ ] Includes a budget gate hook worked example
- [ ] Includes a quality check hook worked example
- [ ] Both examples show complete, runnable hook scripts
- [ ] Cross-links to `references/hooks.md`, `references/events.md`, `references/errors.md`
- [ ] All cross-links use relative paths and resolve to existing files

## Verification

After writing the file, run:

```
bash scripts/verify/m006-p04-hook-header.sh
bash scripts/verify/m006-p04-hook-content.sh
```

All must exit 0. If any verification script does not yet exist (because T05
has not run), verify manually by grepping the file for required patterns.

## Inputs

### From Previous Tasks

- T01: `docs/` directory exists.

### From Disk (Pre-existing)

- `references/hooks.md` — full hook lifecycle reference (361 lines)
- `references/events.md` — HOOK_BLOCKED, HOOK_WARNING events (617 lines)
- `references/errors.md` — error taxonomy for hook failures (316 lines)
- `references/engine.md` — engine pipeline with hook stages (245 lines)
- `scripts/lib/hooks.sh` — hook execution engine
- `scripts/lib/verdicts.sh` — verdict protocol implementation
- `references/architecture.md` — engine pipeline context (378 lines)

## Constraints

- **DC-1**: Progressive disclosure format — `## Overview` immediately after title,
  `##`/`###` structure, ASCII diagrams OK, no inline HTML.
- **DC-2**: Audience label: `users`.
- **DC-3**: All cross-links use relative paths from `docs/` directory.
- **DC-4**: Verify-as-you-write — every hook behavior claim, verdict type, and
  lifecycle point confirmed against actual hook execution code.
- **DC-5**: Any bug fix commit messages reference `docs/hook-development.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for all code examples and any fixes.

## Expected Output

After completing this task:

1. `docs/hook-development.md` exists with 150+ lines.
2. A user can follow the guide to write, test, and debug custom hooks.
3. Both worked examples are complete, runnable scripts.
4. All verdict types and lifecycle points match the actual implementation.
5. All cross-links resolve to existing files.
6. If any code bugs were found and fixed, each fix is committed with a message
   referencing `(found via docs/hook-development.md)`.
