---
description: "Use when breaking a spec into phases with dependency graph and boundary maps. Produces a structured roadmap file that drives all downstream orchestration."
---

# speckit.orchestrator.roadmap

Decompose a feature spec into an ordered sequence of phases with dependency declarations and boundary maps. The resulting roadmap file drives all downstream orchestration — phase planning, dispatch, and verification.

## Prerequisites

Before generating a roadmap:

1. **Derive current state** by running `bash scripts/state/derive-phase.sh <milestone-dir>`. The state must be `pre-planning` or `planning`.
2. **For Tier C**: A finalized context draft (`M###-CONTEXT.md` with `status: finalized` in frontmatter) is required per FR-056. If the context draft is still `status: draft`, report: "Context draft not finalized. Run speckit.orchestrator.discuss first."
3. **For Tier B**: The context draft is optional and skippable. If no context draft exists, proceed directly with the feature spec.
4. **Verify the feature spec exists** at the path recorded during evaluation.

## Spec Analysis

Read and analyze the source materials:

1. **Read the feature spec** (`specs/{NNN}-{name}/spec.md`) — identify all user stories, acceptance scenarios, functional requirements, and non-functional constraints.
2. **Read the context draft** (if it exists and is finalized) — extract architectural decisions, scope boundaries, design constraints, and resolved questions.
3. **Identify cross-cutting concerns** — requirements that span multiple phases (e.g., error handling patterns, logging conventions, security constraints).
4. **Reference tier-specific behavior** from `references/tier-definitions.md`:
   - Tier B: single milestone, flat phases, sequential by default, boundary maps optional
   - Tier C: complex dependency graphs, boundary maps required, risk-ordered phases

## Roadmap Generation

Decompose the feature into phases using the `templates/roadmap.md` template format:

### Phase Decomposition

Each phase must have:

- **ID**: Sequential identifier (P01, P02, P03…)
- **Title**: Concise name describing the phase's deliverable
- **Demo sentence**: One sentence describing what a developer can observe when the phase is complete
- **Risk classification**: `high`, `medium`, or `low` — high-risk phases should execute first when dependencies allow (FR-043)
- **Dependency declarations**: `none` or a list of phase IDs that must complete before this phase begins

### Boundary Maps

For each phase, generate a boundary map declaring what the phase produces and consumes (FR-007/FR-008):

- **Produces**: Concrete interfaces, files, types, or APIs that this phase creates or modifies. These are the phase's deliverables that downstream phases may depend on. Use specific file paths, type names, or interface signatures — not vague descriptions.
- **Consumes**: Items from upstream phases that this phase depends on. Each consumed item must map to a `Produces` entry in an upstream phase. If a consumed item has no matching producer, flag it as an unresolved dependency.

### Ordering Rules

1. Phases with no dependencies come first.
2. Among phases with satisfied dependencies, order by risk (high-risk first per FR-043).
3. Within the same risk level, order by dependency depth (phases that unblock others first).
4. For Tier B: phases are sequential by default — each phase depends on the previous one unless explicitly declared otherwise (FR-054). No nested milestones.

## Validation

Before writing the roadmap, validate its consistency:

1. **No conflicting producers**: Check that no two phases produce the same artifact. If a conflict is found, report: "Conflict: {artifact} is produced by both {P##} and {P##}."
2. **All consumed items have producers**: For each phase's `Consumes` entries, verify that a corresponding `Produces` entry exists in an upstream phase. Report any unresolved dependencies.
3. **No circular dependencies**: Verify the dependency graph is a DAG (directed acyclic graph). If a cycle is detected, report the cycle path.
4. **Demo sentence coverage**: Each phase should have a concrete, testable demo sentence — not a vague description.

## Output

Write the roadmap to the milestone directory:

1. **Create the roadmap file** at `<milestone-dir>/M###-ROADMAP.md` using the `templates/roadmap.md` template.
2. **Fill in YAML frontmatter**:
   - `milestone`: the milestone ID (M###)
   - `feature_ref`: the feature reference (NNN-name)
   - `feature_spec`: path to the feature spec file
   - `vision`: one-sentence vision for the milestone
   - `tier`: the classified tier (B or C)
   - `created_at`: ISO timestamp
   - `updated_at`: ISO timestamp (same as created_at initially)
3. **Write the Phases section**: Each phase as a checklist item with ID, title, demo sentence, risk, dependencies, and boundary map — following the template format.

## Idempotency

If a roadmap file already exists at `<milestone-dir>/M###-ROADMAP.md`:

1. **Display the existing roadmap** to the developer.
2. **Require explicit confirmation** before overwriting (FR-066): "Roadmap already exists for {M###}. Overwrite? This will not delete existing phase plans."
3. If confirmed, regenerate the roadmap and update the `updated_at` timestamp.
4. If not confirmed, exit without changes.

This satisfies R012 (idempotent commands) — running `roadmap` twice without confirmation produces identical disk state.

## Error Handling

- If the milestone directory doesn't exist, exit with error: "Milestone directory not found. Run speckit.orchestrator.evaluate first."
- If state is not `pre-planning` or `planning`, report: "Cannot generate roadmap in state '{state}'. Expected pre-planning or planning."
- If Tier C context draft is not finalized, block and report as described in Prerequisites.
- If the feature spec is missing or unreadable, exit with error: "Feature spec not found at {path}."

## Reference Files

- `templates/roadmap.md` — output template for the roadmap file
- `scripts/state/derive-phase.sh` — derives current orchestrator state from disk
- `scripts/state/read-config.sh` — resolves configuration values
- `scripts/lifecycle/scaffold.sh` — creates directory structure (if not already scaffolded)
- `references/tier-definitions.md` — tier-specific behavior and decision table
- `references/state-machine.md` — state transition rules and conditions
