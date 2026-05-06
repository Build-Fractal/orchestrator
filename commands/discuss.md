---
description: "Use when conducting a pre-planning discussion to capture architectural decisions, scope boundaries, and design constraints before roadmap generation. Creates, updates, or finalizes a context draft that gates the transition from discussing to planning state."
---

# orchestrator:discuss

Facilitate a pre-planning discussion to capture architectural context before roadmap generation. This command manages the context draft lifecycle — create, update, and finalize — which controls the `discussing` → `planning` state transition (FR-056).

## Intensity Behavior

This command is an intensity-aware stage. At entry, call:

```bash
bash scripts/engine/intensity-gate.sh --stage discuss --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps | Behavior |
|-----------|------------------|----------|
| Quick     | none             | Skip discussion entirely. Do not create a context draft. Report "Discussion skipped at Quick intensity" and exit. |
| Standard  | optional         | Discussion is optional. If `M###-EVALUATION.md` lists `discuss_required: true`, proceed. Otherwise, prompt the developer: "Discussion is optional at Standard intensity. Proceed or skip?" |
| Full      | required         | Discussion is a hard gate. Proceed with the full question generation and context-draft workflow described below. |

If the gate is missing or returns an unknown value, default to Full (fail-safe: when in doubt, discuss more not less).

## Prerequisites

### 1. Derive Current State

```bash
bash scripts/state/derive-phase.sh <milestone-dir>
```

Discussion is valid when the state is:
- `pre-planning` — no context draft exists yet; creates one to enter the `discussing` state
- `discussing` — a context draft exists with `status: draft`; update or finalize it

If the state is anything else, report: "Discussion is not available in the current state (`{state}`). Suggested command: `{appropriate_command}`." Use this mapping:
- `planning` or `executing` → suggest `/orchestrator-status` or `/orchestrator-dispatch`
- `complete` → suggest `/orchestrator-status`

### 2. Read the Tier

Read the tier classification from the evaluation file in the milestone directory:

```
<milestone-dir>/M###-EVALUATION.md
```

Extract the `tier` field from the YAML frontmatter. If the evaluation file doesn't exist, warn: "No evaluation found. Run `/orchestrator-evaluate` first to classify the project tier." and exit.

Report the tier to inform behavior:

- **Tier A** — Discussion is not applicable. Tier A bypasses the orchestrator entirely. Report: "Tier A project — discussion is not applicable. Proceed with your host runtime's native single-context workflow."
- **Tier B** — Discussion is optional and skippable. Report: "Tier B project — discussion is optional. You can skip this and proceed directly to `/orchestrator-roadmap`." Then proceed if the developer wants to continue.
- **Tier C** — Discussion is a required gate before roadmap generation (FR-056). Report: "Tier C project — discussion is required before roadmap generation. The roadmap command will not proceed until the context draft is finalized." Then proceed.

### 3. Read the Feature Spec

Read the feature spec path from the evaluation file's `feature_spec` frontmatter field. Read the spec content — it is needed for question generation (see below). If the spec path is missing or the file doesn't exist, warn and proceed without spec-driven questions.

## Question Generation

Before creating or updating the context draft, analyze the feature spec to generate targeted discussion questions for the developer. This helps the developer think through decisions that will affect planning.

### Heuristic: Spec-Driven Questions

For each area, scan the spec and identify gaps or ambiguity:

1. **Technology choices not specified**: For each functional requirement, check if the spec leaves implementation technology open. Example: "The spec requires a game loop — what rendering approach? Canvas 2D, WebGL, or DOM-based?"
2. **Integration boundaries**: Where does this feature connect to existing systems? What APIs, databases, or services does it touch? Are there compatibility constraints?
3. **Performance and scale**: Does the spec mention performance targets? If not, ask: "Are there performance constraints (frame rate, response time, data volume)?"
4. **Data model ambiguity**: Are data structures and storage mechanisms specified? If not, ask about persistence, state management, and data flow.
5. **Scope edges**: Identify requirements that could expand in scope. Ask about explicit boundaries: "The spec mentions X — does that include Y, or is Y out of scope?"
6. **Deployment and environment**: Where will this run? Are there browser/platform/environment constraints?
7. **Testing strategy**: Does the spec specify how to verify? If not, ask about test approach preferences.

Present the generated questions organized by the context draft sections (Architectural Decisions, Scope Boundaries, Design Constraints, Open Questions). The developer's answers populate the draft.

### If No Spec Available

If the spec cannot be read, fall back to general discussion prompts:
- "What are the key architectural decisions for this milestone?"
- "What is explicitly in scope and out of scope?"
- "Are there technical, resource, or timeline constraints?"
- "What open questions need resolution before planning?"

## Core Workflow

### Create Context Draft

If no context draft exists at `<milestone-dir>/<M###>-CONTEXT.md`:

1. Copy the template from `templates/context-draft.md`
2. Fill in the frontmatter fields:
   - `milestone`: set to the current milestone ID (e.g., `M001`)
   - `status`: set to `draft`
   - `created_at`: set to the current ISO-8601 timestamp
   - `finalized_at`: leave as `null`
3. Replace the placeholder text in each section with initial content from the developer's input (informed by the question generation above):
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

After finalizing, suggest: "Context finalized. Run `/orchestrator-roadmap` to generate the execution roadmap."

## Idempotency (FR-066)

- **Creating a draft when one already exists**: Do NOT overwrite the existing draft. Report: "Context draft already exists at `<M###>-CONTEXT.md` with status: {status}." Then:
  - If `status: draft` → offer to update or finalize: "Would you like to update the draft with additional context, or finalize it to proceed to planning?"
  - If `status: finalized` → report: "Context already finalized. Proceed to `/orchestrator-roadmap`."
- **Finalizing an already-finalized context**: Report "Context already finalized at {finalized_at}. Proceed to `/orchestrator-roadmap`." Do not modify the file.
- **Running discuss twice with no changes**: Safe — the file is re-read and presented without modification.

## Error Handling

- **State is not `pre-planning` or `discussing`**: Report current state and suggest the appropriate command (see Prerequisites section above).
- **Evaluation file missing**: Report "No evaluation found at `<M###>-EVALUATION.md`. Run `/orchestrator-evaluate` first." and exit.
- **Context file has malformed frontmatter** (missing `---` delimiters or missing `status` field): Warn "Context file has malformed frontmatter. Attempting to repair." Re-add the frontmatter block with `status: draft`, preserving the existing body content. If repair fails, report the error and suggest manual inspection.
- **Template file missing** (`templates/context-draft.md` not found): Report "Context draft template not found at `templates/context-draft.md`. Cannot create context draft." and exit 1.
- **Developer provides empty content**: Warn "No content provided. The context draft sections are empty." Allow the draft to be created (it can be updated later), but warn that finalizing an empty draft provides no value for planning.

## Gotchas

- **Running discuss on a Tier B project is allowed but optional**: It will create a context draft that is not required for roadmap generation. Running it on Tier A is a no-op — Tier A bypasses the orchestrator entirely.
- **Finalizing an empty context draft is allowed**: The command warns but does not block. The result is a vacuous planning gate that adds no value to roadmap generation.
- **Context draft malformed frontmatter**: The command attempts repair (re-adding `---` delimiters), but if the `status` field is missing after repair, the state machine cannot transition — `derive-phase.sh` will not recognize the file as a valid context draft.
- **The tier is read from EVALUATION.md, not config**: The evaluated tier may differ from `default_tier` in config if auto-classification or `--tier` override was used. Always read from `M###-EVALUATION.md`.
- **Question generation is guidance, not enforcement**: The spec-driven questions are suggestions to help the developer think through decisions. The developer may skip questions, answer partially, or raise entirely different concerns. The goal is to surface non-obvious decisions, not to follow a rigid questionnaire.

## Referenced Scripts

- `scripts/state/derive-phase.sh` — derives current orchestrator state to validate that discussion is allowed

## Referenced Templates

- `templates/context-draft.md` — template for the context draft file structure

## Referenced Files

- `<milestone-dir>/M###-EVALUATION.md` — source of tier classification and feature spec path
