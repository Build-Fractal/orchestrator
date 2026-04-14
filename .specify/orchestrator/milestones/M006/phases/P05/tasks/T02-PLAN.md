---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M006"
name: "Create references/constitution-walkthrough.md — 13 principles with codebase examples"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- P01 reference doc exists: `references/architecture.md`.
- No prior tasks required — T02 is independent.

## Description

Create a new reference document at `references/constitution-walkthrough.md`
that walks through each of the 13 constitution v2.0 principles with concrete
codebase examples, common violations, and compliance checking guidance. The
audience is "contributors" (DC-2).

This document is the companion to the constitution itself
(`.specify/memory/constitution.md`) — it makes the abstract principles
concrete by showing exactly how they manifest in real code. Where the
constitution says "what", this walkthrough says "how to check" and "what
violations look like."

The document must follow progressive disclosure (DC-1): title, disclosure
statement, audience label, `## Overview`, then one `## Principle N` section
per principle. All cross-links use relative paths (DC-3). Every example must
be verified against the actual codebase (DC-4).

## Steps

### Step 1 — Read source materials for accuracy

Read the following:

- `.specify/memory/constitution.md` — all 13 principles, constraints, quality
  gates, and governance (318 lines)
- `ANTIPATTERNS.md` — 3 antipatterns linked to specific principles
- `references/architecture.md` — subsystem map for finding exemplar files
- `scripts/lib/events.sh` — Principle II (event emission) example
- `scripts/lib/errors.sh` — Principle II (result protocol) example
- `scripts/lib/run-context.sh` — Principle IX (reproducibility) example
- `scripts/state/derive-phase.sh` — Principle VI (state on disk) and
  Principle XI (single source of truth) examples
- `scripts/lib/hooks.sh` — Principle XII (hook isolation) example
- `scripts/lib/recipe-parser.sh` — Principle X (templating over inference)
  and Principle XIII (agent instruction schema) examples
- `templates/context-recipe.yaml` — Principle X and XIII examples
- `scripts/knowledge/create-entry.sh` — Principle VII (knowledge compounds)
  example
- `scripts/diagnostics/run-doctor.sh` — Principle VIII (no dead
  infrastructure) example
- `scripts/dispatch/build-context.sh` — Principle I (context minimization)
  and Principle V (fresh context per unit) examples
- 1-2 task plan files — Principle IV (plans assume zero context) example

### Step 2 — Write `references/constitution-walkthrough.md`

Create the file with this structure:

```markdown
# Constitution v2.0 Walkthrough

> Progressive disclosure reference mapping each of the 13 speckit-orchestrator
> constitution principles to concrete codebase examples. Self-contained — read
> this document to understand what compliance looks like without reading the
> full constitution.

> Audience: contributors

## Overview

[What this document is, how to use it, relationship to the constitution.
Mention that the authoritative text is .specify/memory/constitution.md and
this walkthrough provides practical interpretation.]

---

## Principle I — Context Minimization

### What It Means
[1-2 sentences restating the principle in plain language]

### Codebase Examples
[2-3 specific file paths with brief explanation of how they exemplify the
principle. E.g., build-context.sh assembles minimal payloads per task;
scope-filter.sh prunes knowledge entries by relevance.]

### Common Violations
[What going wrong looks like: monolithic context files, inherited session
history, unscoped knowledge dumps]

### How to Check Compliance
[Concrete steps: verify payload contains only task-relevant sections, check
manifest table for section count, etc.]

---

## Principle II — Evidence Before Claims
[Same 4-subsection structure]

---

[... repeat for all 13 principles ...]

---

## Quick Reference Table

[Table mapping principle number to name and one-line compliance check]

---

## Cross-References

[Links to:
- .specify/memory/constitution.md (authoritative constitution text)
- scripts/AGENTS.md (coding conventions and compliance checklist)
- references/architecture.md (system architecture)
- ANTIPATTERNS.md (real-world violations)]
```

### Step 3 — Write each principle section

For each of the 13 principles (I through XIII), write the 4-subsection
block. Source examples from the files read in Step 1. Specific guidance:

**Principle I (Context Minimization)**:
- Examples: `scripts/dispatch/build-context.sh` (recipe-driven assembly),
  `scripts/dispatch/scope-filter.sh` (scope pruning), task plan structure
- Violations: monolithic payloads, unscoped context, session history leakage

**Principle II (Evidence Before Claims)**:
- Examples: `scripts/lib/events.sh` (emit_event), `scripts/lib/errors.sh`
  (emit_result), `scripts/verify/check-must-haves.sh` (mechanical verification)
- Violations: "should work" claims, missing RESULT lines, skipped verification

**Principle III (Design Before Code)**:
- Examples: phase plan files, task plan files, roadmap structure
- Violations: implementing without a plan, skipping design for "simple" tasks

**Principle IV (Plans Assume Zero Context)**:
- Examples: any task plan file (exact paths, complete commands, expected output)
- Violations: plans that say "figure it out" or rely on codebase familiarity

**Principle V (Fresh Context Per Unit)**:
- Examples: `scripts/dispatch/build-context.sh` (constructs per-task payload),
  task summaries as handoff artifacts
- Violations: accumulated session context, inheriting orchestrator history

**Principle VI (State On Disk Is Truth)**:
- Examples: `scripts/state/derive-phase.sh` (file-presence state machine),
  `scripts/lifecycle/lock-manager.sh` (PID-based liveness)
- Violations: in-memory state, cached variables, state not recoverable from disk

**Principle VII (Knowledge Compounds)**:
- Examples: `scripts/knowledge/create-entry.sh`, `KNOWLEDGE.md`, phase summaries
- Violations: code without documentation, missing summaries, no decision records

**Principle VIII (No Dead Infrastructure)**:
- Examples: `scripts/diagnostics/run-doctor.sh` (orphan detection),
  `scripts/diagnostics/check-orphaned.sh`
- Violations: scripts not in extension.yml, templates without consumers, "for future use" code

**Principle IX (Reproducibility Over Convenience)**:
- Examples: `scripts/lib/run-context.sh` (deterministic run ID),
  `$ORCH_STARTED_AT` timestamp, `ORCH_RUN_SEED`
- Violations: inline `date` calls, random IDs, AP-001 (platform-specific syntax)

**Principle X (Templating Over Inference)**:
- Examples: `templates/context-recipe.yaml`, `templates/routing.yaml`,
  `templates/hooks.yaml`
- Violations: runtime inference of section ordering, hardcoded model selection

**Principle XI (Single Source of Truth)**:
- Examples: `scripts/state/derive-phase.sh` (derived state, never stored),
  `orchestrator-config.yml` (specificity resolution)
- Violations: duplicated state across files, cached status fields

**Principle XII (Hook Isolation)**:
- Examples: `scripts/lib/hooks.sh` (sandbox enforcement, chmod 444 snapshots),
  `HOOK_VIOLATION` event
- Violations: hooks modifying engine state, hooks writing to orchestrator paths

**Principle XIII (Agent Instruction Schema)**:
- Examples: `templates/context-recipe.yaml` (schema declaration),
  `scripts/lib/recipe-parser.sh` (recipe-driven assembly)
- Violations: ad-hoc payload construction, unstructured instruction assembly

### Step 4 — Write the Quick Reference Table

Create a table with columns: Principle, Name, One-Line Compliance Check.
All 13 rows.

### Step 5 — Verify-as-you-write (DC-4)

For every file path cited as an example:
- Confirm it exists on disk with `test -f`.
- Confirm the cited behavior is present (grep for the relevant pattern).

For every cross-link:
- Confirm the target file exists relative to `references/`.

### Step 6 — Check for convention violations

While reviewing scripts for principle examples, note any violations found.
If violations exist:
- Fix the violation in the offending script.
- Commit the fix with a message referencing `(found via references/constitution-walkthrough.md)` per DC-5.

## Must-Haves

- [ ] `references/constitution-walkthrough.md` exists and is 300+ lines
- [ ] File opens with progressive disclosure statement and audience label "contributors"
- [ ] Contains `## Overview` section
- [ ] All 13 principles have their own section (Principle I through Principle XIII)
- [ ] Each principle section has: What It Means, Codebase Examples, Common Violations, How to Check Compliance
- [ ] Every file path cited as an example exists on disk
- [ ] Includes a Quick Reference Table
- [ ] Cross-links to `.specify/memory/constitution.md`, `scripts/AGENTS.md`, `references/architecture.md`, `ANTIPATTERNS.md`
- [ ] All cross-links use relative paths and resolve to existing files

## Verification

After writing the file, run:

```
bash scripts/verify/m006-p05-walkthrough-header.sh
bash scripts/verify/m006-p05-walkthrough-principles.sh
bash scripts/verify/m006-p05-crosslinks.sh
```

All must exit 0. If verification scripts do not yet exist (T03 has not
run), verify manually by grepping the file for required patterns.

## Inputs

### From Previous Tasks

None — T02 is independent.

### From Disk (Pre-existing)

- `.specify/memory/constitution.md` — authoritative constitution v2.0 (318 lines)
- `ANTIPATTERNS.md` — 3 registered antipatterns with principle references (83 lines)
- `references/architecture.md` — subsystem map, file layout (378 lines)
- `scripts/lib/events.sh` — event emission library
- `scripts/lib/errors.sh` — error taxonomy and result emitter
- `scripts/lib/hooks.sh` — hook lifecycle dispatcher
- `scripts/lib/run-context.sh` — run context initialization
- `scripts/lib/recipe-parser.sh` — recipe parser
- `scripts/state/derive-phase.sh` — state derivation
- `scripts/dispatch/build-context.sh` — context assembly
- `scripts/dispatch/scope-filter.sh` — scope filtering
- `scripts/knowledge/create-entry.sh` — knowledge entry creation
- `scripts/diagnostics/run-doctor.sh` — diagnostics runner
- `scripts/diagnostics/check-orphaned.sh` — orphan detection
- `scripts/lifecycle/lock-manager.sh` — session locking
- `templates/context-recipe.yaml` — default recipe
- `templates/routing.yaml` — model routing config
- `templates/hooks.yaml` — hook definitions

## Constraints

- **DC-1**: Progressive disclosure format — `## Overview` immediately after title,
  `##`/`###` structure, ASCII diagrams OK, no inline HTML.
- **DC-2**: Audience label: `contributors`.
- **DC-3**: All cross-links use relative paths from `references/` directory.
- **DC-4**: Verify-as-you-write — every file path cited must exist on disk.
- **DC-5**: Bug fix commits reference `references/constitution-walkthrough.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `references/constitution-walkthrough.md` exists with 300+ lines.
2. All 13 principles covered with codebase examples.
3. Every cited file path verified to exist.
4. All cross-links resolve to existing files.
5. If any code violations were found and fixed, each fix is committed
   with a message referencing `(found via references/constitution-walkthrough.md)`.
