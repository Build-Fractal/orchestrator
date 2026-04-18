---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P00"
milestone: "M019"
name: "L3 thinking_budget sweep + L5 positive-examples rewrite across templates/ and scripts/engine/intensity-gate.sh — adaptation pass for Opus 4.7 defaults. Produces the negative-guidance exception whitelist file that payload-shape gate Gate 5 consults."
depends_on: ["T01"]
---

## Prerequisites

T01 has completed:

- `scripts/dispatch/build-context.sh` emits L1/L2/L4 markers (adds `## First-Turn Completeness`, `<dispatch-volatile>`, `## Parallel Fan-Out`).
- `templates/dispatch-prompt.md` carries T01's new shape-declaration blocks.
- `scripts/verify/m019-p00-payload-shape.sh` exists and is executable.

Repository pre-existing state:

- `templates/` — 28 template files (checked via `ls templates/`). No current file contains `thinking_budget` (verified by grep sweep at planning time — L3 is a confirm-and-whitelist pass rather than a remove pass). Present files include `dispatch-prompt.md`, `phase-plan.md`, `task-plan.md`, `roadmap.md`, `verification-report.md`, `task-summary.md`, `phase-summary.md`, `milestone-summary.md`, `context-draft.md`, `continue-file.md`, `recovery-briefing.md`, `project-instruction.md`, `instruction-schema.md`, `intensity-metadata.md`, `evaluation.md`, `dispatch-error.md`, `dispatch-result.md`, `gate-result.md`, `spec-compliance-review.md`, `spec-normalizer-prompt.md`, `claude-code-appendix.md`, and several YAML / JSON config files.
- `scripts/engine/intensity-gate.sh` — hardcoded stage × intensity matrix. No current `thinking_budget` reference (verified by grep at planning time). L3's requirement is sweep-confirm + defensive documentation comment, not a removal.
- `.orchestrator/scratch/articles-synthesis-2026-04-17.md` — L5 source material.

## Description

Do a focused sweep for Opus 4.7 alignment:

1. **L3 (adaptive thinking, no fixed budgets).** Grep-sweep `templates/` + `scripts/engine/intensity-gate.sh` for `thinking_budget`, `thinking budget`, `fixed_thinking`, `think_effort`, and any other fixed-budget syntax. If any matches are found, remove them or replace with adaptive prompt nudges ("think carefully; this is harder than it looks" for hard-effort steps; "prioritize responding quickly" for easy-effort steps). Add a documenting comment to `scripts/engine/intensity-gate.sh` stating that thinking effort is adaptive per Opus 4.7 and no fixed budget is set by the orchestrator.
2. **L5 (positive examples).** Rewrite expressive negative guidance in `templates/dispatch-prompt.md` to positive-example form. Constitution XV anti-pattern prohibitions stay negative — each retained negative must be documented in the whitelist file `templates/.p00-negative-guidance-retained.txt` with rationale.

The sweep is narrow by design: only `templates/dispatch-prompt.md` is in scope for L5 rewrites (this is the dispatch-facing template that renders into every payload). Other templates (`task-plan.md`, `phase-plan.md`, etc.) are used by planning-phase command documents, not dispatched payloads, and are out of P00 scope per the Boundary Assertion.

## Steps

### Step 1: L3 thinking_budget sweep

**Action 1a.** Run a targeted grep across `templates/` and `scripts/engine/intensity-gate.sh`:

```bash
bash -c 'grep -rlnE "thinking_budget|thinking budget|fixed_thinking|think_effort" templates/ scripts/engine/intensity-gate.sh 2>/dev/null || echo NONE'
```

**Action 1b.** If output is `NONE` (the current expected state per planning-time verification), no removal work is needed — proceed to Action 1c.

**Action 1c.** Add a documenting comment block to `scripts/engine/intensity-gate.sh` near the existing `# --- Hardcoded stage x intensity matrix ---` comment (around line 65). Insert:

```bash
# --- P00/L3 Adaptive Thinking Contract (Opus 4.7) ---
# The intensity gate does NOT set a fixed thinking budget. Opus 4.7 uses
# adaptive thinking — the model decides per step how much reasoning to apply.
# Prompt-level nudges are the only lever: "think carefully; this is harder
# than it looks" for hard-effort tasks vs. "prioritize responding quickly"
# for easy-effort tasks. Intensity level (Quick/Standard/Full) affects which
# substeps execute, not how much thinking budget is allocated per substep.
```

This comment is the documented evidence that the sweep was run and the contract is intentional. Do not add `thinking_budget` anywhere else.

### Step 2: L5 positive-examples rewrite of `templates/dispatch-prompt.md`

**File:** `templates/dispatch-prompt.md`

**Action 2a.** Enumerate expressive negative guidance. Run:

```bash
grep -nE "^[[:space:]]*-?[[:space:]]*(Don't|Do not|Never|Avoid)[[:space:]]" templates/dispatch-prompt.md
```

**Action 2b.** For each hit, decide classification:

- **Constitutional anti-pattern (retain negative).** If the surrounding section (within 5 lines above/below) contains the literal string `Constitution XV` or `anti-pattern`, the prohibition is load-bearing safety content — leave it negative and add an entry to the whitelist (Action 2d below).
- **Expressive guidance (rewrite positive).** Otherwise, rewrite the line to positive-example form. Examples:
  - `- Never truncate the task plan or must-haves` → `- Always preserve the task plan and must-haves in full.`
  - `- Drop knowledge and decision entries first (they inform but don't constrain)` → `- Drop knowledge and decision entries first (they inform but do not constrain the task).` (minimal rewrite — "don't" is not an expressive-guidance negation here, it's grammatical; apply judgment.)

The existing `## Payload Size Guidance > Truncation strategy` section currently contains the line `- Never truncate the task plan or must-haves` which is dispatch-facing expressive guidance. Rewrite to: `- Always include the task plan and must-haves in full; truncate lower-priority sections instead.`

**Action 2c.** Apply the rewrites via `Edit` tool on `templates/dispatch-prompt.md`. Preserve frontmatter, section headers, and structural markers (T01's `## First-Turn Completeness` and `## Parallel Fan-Out` blocks).

**Action 2d.** Create the exception whitelist file `templates/.p00-negative-guidance-retained.txt` listing any retained negatives. Format: one line per exception, shape `<relative-path>:<line_number> <human rationale>`. For this P00 adaptation, the expected contents — assuming no constitutional anti-pattern section is present in `dispatch-prompt.md` (currently none is, per planning-time inspection) — is an empty "header-only" file that still passes the Gate 5 "whitelist exists" check:

```
# P00/L5 Retained-Negative Guidance Whitelist
# Each entry: <relative-path>:<line_number> <rationale>
# Retained negatives must be either (a) Constitution XV anti-pattern
# prohibitions or (b) safety-rail text where a positive rewrite would be
# semantically incorrect. Payload-shape gate Gate 5 consults this file.
#
# (No entries required for P00 — dispatch-prompt.md contains no
# constitutional-anti-pattern section as of 2026-04-17.)
```

If during Action 2b any line was classified as constitutional-anti-pattern (meaning a `Constitution XV` or `anti-pattern` marker appears within 5 lines), add that line to the whitelist with shape `dispatch-prompt.md:<lineno> retained: constitutional anti-pattern section "<section-name>"`.

### Step 3: Run payload-shape gate to confirm L3/L5 checks pass

**Action 3.** Run:

```bash
bash scripts/verify/m019-p00-payload-shape.sh
```

After T02 completes, Gates 3 (L3 no thinking_budget) and 5 (L5 no unwhitelisted negatives in dispatch-prompt.md) should report `PASS:`. Gate 6 (pricing.yml) still reports `FAIL:` until T04 runs; that is expected.

## Must-Haves

- `templates/` and `scripts/engine/intensity-gate.sh` together contain zero matches for `thinking_budget` or `thinking budget`. Verified by payload-shape Gate 3.
- `scripts/engine/intensity-gate.sh` contains the literal string `adaptive` in a comment documenting the L3 contract. Verified by grep.
- `templates/dispatch-prompt.md` contains no line matching `^[[:space:]]*-?[[:space:]]*(Don't|Do not|Never|Avoid)[[:space:]]` outside of (a) lines covered by a constitutional-anti-pattern section within 5 lines OR (b) lines listed in `templates/.p00-negative-guidance-retained.txt`. Verified by payload-shape Gate 5.
- `templates/.p00-negative-guidance-retained.txt` exists and is readable (may be header-only comments if no exceptions are needed).
- All pre-existing test suites still pass (SC-13 regression guard). T05's no-regression gate verifies this post-T02.

## Verification

Run:

```
bash scripts/verify/m019-p00-payload-shape.sh
```

Expected: Gate 3 (L3) and Gate 5 (L5) + subchecks report `PASS:`. Gate 6 (pricing.yml) reports `FAIL:` (pending T04).

Also run a localized template grep to confirm Action 1a returned NONE (or that any matches were removed):

```
grep -rlE 'thinking_budget|thinking budget|fixed_thinking|think_effort' templates/ scripts/engine/intensity-gate.sh
```

Expected: exit status 1 (grep: no matches found), empty stdout.

## Inputs

### From Previous Tasks

- `templates/dispatch-prompt.md` (from T01)
  - T01 added `## First-Turn Completeness` and `## Parallel Fan-Out` blocks with documenting comments. T02 must preserve those additions byte-identical.
- `scripts/verify/m019-p00-payload-shape.sh` (from T01)
  - Key API: Gate 3 greps for `thinking_budget|thinking budget`. Gate 5 enumerates `Don't|Do not|Never|Avoid` lines and consults `templates/.p00-negative-guidance-retained.txt` whitelist (single-file format: `<path>:<lineno> <rationale>`, skipping header comment lines beginning `#`).

### From Disk (Pre-existing)

- `templates/dispatch-prompt.md` — file to modify (L5 rewrites of any expressive negative guidance).
- `scripts/engine/intensity-gate.sh` — file to annotate (L3 contract comment).
- `.orchestrator/scratch/articles-synthesis-2026-04-17.md` — reference for L3 / L5 rationale.

## Constraints

- **No other template modified.** L5 rewrites are scoped to `templates/dispatch-prompt.md` only. `task-plan.md`, `phase-plan.md`, and the rest are planning-facing and out of P00 scope (Boundary Assertion).
- **No constitutional anti-pattern edits.** Constitution XV prohibitions stay negative by design. Only expressive guidance flips to positive form.
- **No new prose added** beyond the L3 documenting comment and positive-form rewrites. This is a surgical sweep, not a template modernization.
- **Bash 3.2 compat** (any helper glue).
- **Whitelist path is tracked.** `templates/.p00-negative-guidance-retained.txt` starts with `.` — hidden file in templates dir. Consumers glob/ls skipping dotfiles will not see it, which is intentional (it is a verify-gate side-table, not a user-facing template).

## Expected Output

After T02:

- `grep -rlE 'thinking_budget|thinking budget|fixed_thinking|think_effort' templates/ scripts/engine/intensity-gate.sh` exits 1 (no matches).
- `scripts/engine/intensity-gate.sh` contains the L3 adaptive-thinking contract comment block.
- `templates/dispatch-prompt.md` Truncation strategy reads in positive form (`Always include ...` instead of `Never truncate ...`).
- `templates/.p00-negative-guidance-retained.txt` exists with header comments and any retained-negative exceptions (expected: zero entries for P00).
- `bash scripts/verify/m019-p00-payload-shape.sh` Gate 3 and Gate 5 pass.
- All existing test suites pass unchanged (verified by T05's no-regression gate).
