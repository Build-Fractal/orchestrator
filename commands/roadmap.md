---
description: "Use when breaking a spec into phases with dependency graph and boundary maps. Produces a structured roadmap file that drives all downstream orchestration."
---

# orchestrator:roadmap

Decompose a feature spec into an ordered sequence of phases with dependency declarations and boundary maps. The resulting roadmap file drives all downstream orchestration — phase planning, dispatch, and verification.

## Prerequisites

Before generating a roadmap:

1. **Derive current state** by running `bash scripts/state/derive-phase.sh <milestone-dir>`. The state must be `pre-planning` or `planning`.

2. **Read the tier and spec path from the evaluation file** at `<milestone-dir>/M###-EVALUATION.md`. Extract the `tier` and `feature_spec` fields from the YAML frontmatter. If the evaluation file doesn't exist, exit with error: "No evaluation found. Run `speckit.orchestrator.evaluate` first."

   **Note on the state machine gap**: `derive-phase.sh` returns `planning` when no roadmap exists, regardless of tier. It is intentionally not tier-aware — the state machine derives state purely from file presence. The Tier C discussion gate is enforced here in the roadmap command, not in the state machine. This means a Tier C project in `pre-planning` or `planning` state must have its discussion check performed by this command.

3. **For Tier C**: A finalized context draft (`M###-CONTEXT.md` with `status: finalized` in frontmatter) is required per FR-056. If the context draft does not exist or is still `status: draft`, block and report: "Tier C requires a finalized context draft before roadmap generation. Run `speckit.orchestrator.discuss` first to capture architectural context."

4. **For Tier B**: The context draft is optional and skippable. If no context draft exists, proceed directly with the feature spec.

5. **Verify the feature spec exists** at the path from the evaluation file's `feature_spec` field. If the path is missing from the evaluation, fall back to scanning `specs/` for the matching feature directory.

6. **Resolve roadmap intensity behavior** by running:

   ```bash
   bash scripts/engine/intensity-gate.sh --stage roadmap --intensity-metadata <path-to-metadata>
   ```

   Parse the `execute_substeps=` output. The values are one of:
   - `single-pass` (Quick) — directive: produce the roadmap in one pass, present it as "Here's your roadmap. Accept, refine, or override."
   - `basic-decomp,rationale` (Standard) — semi-directive: present phase decomposition with rationale per phase, ask the developer to accept or refine specific phases.
   - `basic-decomp,rationale,collaborative-loop` (Full) — collaborative: delegate the walk-through to the `speckit.orchestrator.discuss` Tier C pattern, iterating phase-by-phase with the developer.

## Spec Analysis

Read and analyze the source materials:

1. **Read structural elements**. Prefer ingested spec chunks over re-parsing the raw spec:

   **Chunks-first path** (when `bash scripts/state/spec-metrics.sh <orch-root>` reports `spec_chunks_present=true`):

   - Enumerate `spec/story` chunks via `bash scripts/dispatch/scope-filter.sh --category spec/story --graph` — one SPEC-US-NNN ID per line.
   - Read story-to-story dependency edges via `bash scripts/knowledge/spec-story-graph.sh <orch-root>` — one `<SPEC-US-ID>|<comma-sep deps>` line per story. Each dependency pair `US-003|US-001` means "the phase containing US-003 depends on the phase containing US-001".
   - For each story, pull its related `spec/acceptance` and `spec/constraint` chunks via `scope-filter.sh --spec-scope-tags "spec/story/SPEC-US-NNN"` (from P04) to inform phase goals and demo sentences.

   **Raw-spec fallback** (when `spec_chunks_present=false`): parse the raw spec at `specs/{NNN}-{name}/spec.md` for user stories, acceptance scenarios, functional requirements, and non-functional constraints. This is the legacy behavior preserved for un-ingested specs.
2. **Read the context draft** (if it exists and is finalized) — extract architectural decisions, scope boundaries, design constraints, and resolved questions.
3. **Identify cross-cutting concerns** — requirements that span multiple phases (e.g., error handling patterns, logging conventions, security constraints). For each concern, note which phase IDs it touches and which phase establishes the pattern that others must follow. Record these in the roadmap's `## Cross-Cutting Concerns` section so consuming phases can reference them during `plan-phase`.
4. **Reference tier-specific behavior** from `references/tier-definitions.md`:
   - Tier B: single milestone, flat phases, sequential by default, boundary maps optional
   - Tier C: complex dependency graphs, boundary maps required, risk-ordered phases

## Roadmap Generation

Decompose the feature into phases using the `templates/roadmap.md` template format:

### Intensity-Aware Interaction

The interaction style is gated by the resolved intensity substeps from the Prerequisites step:

- **single-pass (Quick)**: produce the full roadmap in one pass without intermediate confirmation; present the final roadmap with "Accept, refine, or override." No rationale walk-through.
- **basic-decomp,rationale (Standard)**: present phase decomposition with a one-sentence rationale per phase; ask the developer to accept, refine, or request a re-decomposition before writing the roadmap.
- **basic-decomp,rationale,collaborative-loop (Full)**: invoke the `speckit.orchestrator.discuss` Tier C collaborative loop to walk through each candidate phase with the developer. The output of the discussion seeds the roadmap.

### Phase Decomposition

Each phase must have:

- **ID**: Sequential identifier (P01, P02, P03…)
- **Title**: Concise name describing the phase's deliverable
- **Demo sentence**: One sentence describing what a developer can observe when the phase is complete. Demo sentences are phase-level summaries, not acceptance scenario paraphrases — they describe what is observable when the phase is done. Acceptance scenario traceability is handled at the task level during `plan-phase`, not at the roadmap level.
- **Risk classification**: `high`, `medium`, or `low` — high-risk phases should execute first when dependencies allow (FR-043)
- **Dependency declarations**: `none` or a list of phase IDs that must complete before this phase begins
- **When chunks are present**: each phase corresponds to one `spec/story` chunk (or a tightly-linked story cluster when multiple stories share a common thread). The phase `depends_on` field for each phase is populated from the `spec-story-graph.sh` output — if US-003 depends on US-001 via `relates_to`, then the phase containing US-003 has `depends_on` pointing to the phase containing US-001.

### Boundary Maps

For each phase, generate a boundary map declaring what the phase produces and consumes (FR-007/FR-008):

- **Produces**: Concrete interfaces, files, types, or APIs that this phase creates or modifies. These are the phase's deliverables that downstream phases may depend on. Use specific file paths, type names, or interface signatures — not vague descriptions. Granularity should scale with project size:
  - **< 8 phases**: File paths are fine — concrete and verifiable.
  - **8–15 phases**: Prefer interface/type names over file paths. File paths for key entry points only.
  - **> 15 phases**: Module-level boundaries (e.g., "scoring module API") with a note that `plan-phase` will refine to file level.
- **Consumes**: Items from upstream phases that this phase depends on. Each consumed item must map to a `Produces` entry in an upstream phase. If a consumed item has no matching producer, flag it as an unresolved dependency.

### Ordering Rules

1. Phases with no dependencies come first.
2. Among phases with satisfied dependencies, order by risk (high-risk first per FR-043).
3. Within the same risk level, order by dependency depth (phases that unblock others first).
4. For Tier B: phases are sequential by default — each phase depends on the previous one unless explicitly declared otherwise (FR-054). No nested milestones.

### Dependency Graph and Execution Order

After defining all phases and their dependencies:

1. **Build a dependency graph** — create an ASCII DAG visualization showing phase IDs as nodes and dependency edges. Record this in the roadmap's `## Dependency Graph` section.
2. **Derive the execution order** — produce an ordered list with rationale, explicitly marking which phases can execute concurrently once their dependencies are satisfied (e.g., "P06, P07 can execute concurrently — both depend only on P04"). Record this in the roadmap's `## Execution Order` section. For Tier C with autonomous dispatch, the dispatch system uses this to make scheduling decisions.

## Validation

Before writing the roadmap, validate its consistency. Record all results in the roadmap's `## Validation` section (PASS/FAIL with details for each check):

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
4. **Write the Cross-Cutting Concerns section**: Each concern with affected phase IDs and handling guidance.
5. **Write the Dependency Graph section**: ASCII DAG visualization of phase dependencies.
6. **Write the Execution Order section**: Ordered list with parallelization notes.
7. **Write the Validation section**: PASS/FAIL results for each consistency check.

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
- **Edge case — state is `planning` but context draft is not finalized (Tier C)**: `derive-phase.sh` returns `planning` when no roadmap exists, regardless of tier or context draft status (this is intentional — see design note in the script). If state is `planning` but the Tier C context draft exists with `status: draft` (not finalized), treat as `discussing` and block: "Tier C context draft exists but is not finalized. Run `speckit.orchestrator.discuss` to finalize before generating a roadmap."

## Gotchas

- **Generating a roadmap when one exists requires confirmation**: Silent overwrite is prevented by the idempotency check. Without `--force` or explicit confirmation, the command exits without changes.
- **Tier C without finalized context draft is blocked at state check**: The block happens before roadmap generation starts, not during — the error message references `discuss`, not `roadmap`. This gate is enforced here (not in `derive-phase.sh`) because the state machine is intentionally tier-agnostic.
- **The tier is read from EVALUATION.md, not config**: The evaluated tier may differ from `default_tier` in config if auto-classification or `--tier` override was used during `evaluate`. Always read from `M###-EVALUATION.md`.
- **Boundary map conflicts are agent-evaluated, not mechanically enforced**: Two phases producing the same artifact should be caught during validation, but the check relies on agent judgment. `check-boundary-map.sh` only verifies that declared produces exist on disk — it does not detect undeclared conflicts.

## Reference Files

- `templates/roadmap.md` — output template for the roadmap file
- `scripts/state/derive-phase.sh` — derives current orchestrator state from disk
- `scripts/state/read-config.sh` — resolves configuration values
- `scripts/lifecycle/scaffold.sh` — creates directory structure (if not already scaffolded)
- `scripts/dispatch/scope-filter.sh` — enumerates ingested `spec/story` chunks when chunks are present (via `--category spec/story --graph` mode added in P04)
- `scripts/knowledge/spec-story-graph.sh` — emits story-to-story `depends_on` edges traced from `relates_to` (P05)
- `scripts/knowledge/traverse-graph.sh` — underlying graph traversal used by `spec-story-graph.sh`
- `scripts/engine/intensity-gate.sh` — resolves Quick/Standard/Full substeps for the `roadmap` stage (P05)
- `scripts/state/spec-metrics.sh` — reports `spec_chunks_present` flag driving the chunks-first vs raw-spec-fallback switch (P05, T01)
- `references/tier-definitions.md` — tier-specific behavior and decision table
- `scripts/verify/check-boundary-map.sh` — verifies that declared produces exist on disk (invoked during `verify`, not during `roadmap` — referenced in gotchas for context)
- `references/state-machine.md` — state transition rules and conditions
