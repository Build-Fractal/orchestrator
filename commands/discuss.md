---
description: "Use when conducting a pre-planning discussion to capture architectural decisions, scope boundaries, and design constraints before roadmap generation. Creates, updates, or finalizes a context draft that gates the transition from discussing to planning state."
---

# speckit.orchestrator.discuss

Facilitate a pre-planning discussion to capture architectural context before roadmap generation. This command manages the context draft lifecycle — create, update, and finalize — which controls the `discussing` → `planning` state transition (FR-056).

## Prerequisites

### 1. Derive Current State

```bash
bash scripts/state/derive-phase.sh <milestone-dir>
```

Discussion is valid when the state is:
- `pre-planning` — no context draft exists yet; creates one to enter the `discussing` state
- `discussing` — a context draft exists with `status: draft`; update or finalize it

If the state is anything else, report: "Discussion is not available in the current state (`{state}`). Suggested command: `{appropriate_command}`." Use this mapping:
- `planning` or `executing` → suggest `speckit.orchestrator.status` or `speckit.orchestrator.dispatch`
- `complete` → suggest `speckit.orchestrator.status`

### 2. Tier Behavior

The discussion phase has different requirements depending on the orchestration tier:
- **Tier B** — Discussion is optional and skippable. The user can proceed directly to `speckit.orchestrator.roadmap` without creating a context draft. If skipped, no context draft file is created and the state transitions directly from `pre-planning` to `planning` when the roadmap command is invoked.
- **Tier C** — Discussion is a required gate before roadmap generation (FR-056). The roadmap command should refuse to run until the context draft is finalized (`status: finalized`).

## Core Workflow

### Create Context Draft

If no context draft exists at `<milestone-dir>/<M###>-CONTEXT.md`:

1. Copy the template from `templates/context-draft.md`
2. Fill in the frontmatter fields:
   - `milestone`: set to the current milestone ID (e.g., `M001`)
   - `status`: set to `draft`
   - `created_at`: set to the current ISO-8601 timestamp
   - `finalized_at`: leave as `null`
3. Replace the placeholder text in each section with initial content from the developer's input:
   - `## Architectural Decisions` — key architectural choices
   - `## Scope Boundaries` — what is in scope and out of scope
   - `## Design Constraints` — technical, resource, or process constraints
   - `## Open Questions` — unresolved questions that need answers
4. Write the populated template to `<milestone-dir>/<M###>-CONTEXT.md`

The context file's presence with `status: draft` transitions the state machine from `pre-planning` to `discussing` (derive-phase.sh detects the draft context file).

### Update Context Draft

If the context file exists at `<milestone-dir>/<M###>-CONTEXT.md` with `status: draft` in the frontmatter:

1. Read the existing context draft
2. Present the current content to the developer for review
3. Append new content provided by the developer to the appropriate sections:
   - Additional architectural decisions → append to `## Architectural Decisions`
   - New scope items → append to `## Scope Boundaries`
   - New constraints → append to `## Design Constraints`
   - New questions → append to `## Open Questions`
4. Write the updated content back to the same file
5. Do NOT change the `status` field — it remains `draft`

The developer can update the context draft as many times as needed before finalizing.

### Finalize Context

When the developer indicates the context is complete:

1. Read the context draft from `<milestone-dir>/<M###>-CONTEXT.md`
2. Verify that at least one section has non-placeholder content (the developer should have provided some input)
3. Update the frontmatter:
   - Change `status: draft` → `status: finalized`
   - Set `finalized_at` to the current ISO-8601 timestamp
4. Write the updated file

This transitions the state machine from `discussing` to `planning` — `derive-phase.sh` will no longer match the discussing rule (rule 2) because the context file now has `status: finalized`.

After finalizing, suggest: "Context finalized. Run `speckit.orchestrator.roadmap` to generate the execution roadmap."

## Idempotency (FR-066)

- **Creating a draft when one already exists**: Do NOT overwrite the existing draft. Report: "Context draft already exists at `<M###>-CONTEXT.md` with status: {status}." Then:
  - If `status: draft` → offer to update or finalize: "Would you like to update the draft with additional context, or finalize it to proceed to planning?"
  - If `status: finalized` → report: "Context already finalized. Proceed to `speckit.orchestrator.roadmap`."
- **Finalizing an already-finalized context**: Report "Context already finalized at {finalized_at}. Proceed to `speckit.orchestrator.roadmap`." Do not modify the file.
- **Running discuss twice with no changes**: Safe — the file is re-read and presented without modification.

## Error Handling

- **State is not `pre-planning` or `discussing`**: Report current state and suggest the appropriate command (see Prerequisites section above).
- **Context file has malformed frontmatter** (missing `---` delimiters or missing `status` field): Warn "Context file has malformed frontmatter. Attempting to repair." Re-add the frontmatter block with `status: draft`, preserving the existing body content. If repair fails, report the error and suggest manual inspection.
- **Template file missing** (`templates/context-draft.md` not found): Report "Context draft template not found at `templates/context-draft.md`. Cannot create context draft." and exit 1.
- **Developer provides empty content**: Warn "No content provided. The context draft sections are empty." Allow the draft to be created (it can be updated later), but warn that finalizing an empty draft provides no value for planning.

## Gotchas

- **Running discuss on a Tier B project is allowed but optional**: It will create a context draft that is not required for roadmap generation. Running it on Tier A is a no-op — Tier A bypasses the orchestrator entirely.
- **Finalizing an empty context draft is allowed**: The command warns but does not block. The result is a vacuous planning gate that adds no value to roadmap generation.
- **Context draft malformed frontmatter**: The command attempts repair (re-adding `---` delimiters), but if the `status` field is missing after repair, the state machine cannot transition — `derive-phase.sh` will not recognize the file as a valid context draft.

## Referenced Scripts

- `scripts/state/derive-phase.sh` — derives current orchestrator state to validate that discussion is allowed

## Referenced Templates

- `templates/context-draft.md` — template for the context draft file structure
