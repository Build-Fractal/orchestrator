---
description: "Use when starting a new project to classify scope as Tier A, B, or C. Analyzes the feature spec to determine how many SDD flows are needed and activates the corresponding workflow."
---

# speckit.orchestrator.evaluate

Classify a feature's scope into Tier A, B, or C and activate the corresponding orchestrator workflow. This is typically the first orchestrator command run for a new feature.

## Prerequisites

1. A feature spec must exist at `specs/{NNN}-{name}/spec.md`.
2. Identify the feature number and name from the spec directory.

## Scope Analysis

Analyze the feature spec to determine the scope of work:

1. **Read the feature spec** at `specs/{NNN}-{name}/spec.md`.
2. **Count structural elements**:
   - Number of user stories (sections with "As a…" or "US-" prefixed items)
   - Number of acceptance scenarios (AC items, "Given/When/Then" blocks)
   - Number of functional requirements (FR-### items or numbered requirements)
3. **Estimate SDD flow count**: Determine how many complete spec-kit process flows (specify → clarify → plan → tasks → implement) the work requires:
   - **1 flow inline** = everything fits in ~1 context window
   - **1 flow, multiple contexts** = each SDD step needs its own context window, tasks dispatch separately
   - **2+ flows** = multiple distinct SDD cycles, requiring roadmap decomposition and cross-phase coordination

## Tier Classification

Apply the tier classification criteria from `references/tier-definitions.md`:

### Tier A — Single Context

- Fits in approximately one context window
- One task or a few very small tasks
- All SDD steps run inline with minimal context switching
- **Result**: No orchestrator overhead — route directly to standard spec-kit commands

### Tier B — One SDD Flow, Multiple Contexts

- One complete SDD flow where each step fits in its own context window
- Tasks dispatch to separate contexts
- 2–5 phases, sequential execution, developer-driven transitions
- **Result**: Single-milestone roadmap, task-level dispatch, per-task verification

### Tier C — Multiple SDD Flows, Full Orchestration

- Two or more complete SDD flows
- Roadmap decomposition, autonomous dispatch, cross-phase coordination
- Complex dependency graphs, boundary maps required
- **Result**: Full orchestrator with autonomous mode, crash recovery, knowledge consolidation

### Configuration Override

Check for a default tier override in the project configuration:

```bash
bash scripts/state/read-config.sh <orchestrator-root> default_tier
```

If `default_tier` is set (A, B, or C), use that value instead of auto-classification. Report that the tier was set by configuration, not by analysis.

## Output

Based on the classified tier:

### Tier A Result

- Report the classification: "Tier A — Single Context. Routing to standard spec-kit."
- Do NOT create any orchestrator directory structure (FR-003)
- Do NOT create any additional files — exit and let the developer use standard spec-kit commands directly

### Tier B or C Result

1. **Scaffold the orchestrator directory structure**:

```bash
bash scripts/lifecycle/scaffold.sh <orchestrator-root> <milestone-id> <feature-spec-path>
```

This creates the `.specify/orchestrator/milestones/{M###}/` directory tree and initializes the orchestrator config.

2. **Write evaluation result to stdout**:
   - Tier classification (A, B, or C)
   - Reasoning: number of user stories, estimated SDD flows, key complexity factors
   - Next recommended command: `speckit.orchestrator.roadmap` (Tier B) or `speckit.orchestrator.discuss` (Tier C)

3. **Write a brief evaluation summary** to the milestone directory summarizing the classification rationale.

## Override Support

Accept `--tier A|B|C` to explicitly override auto-classification (FR-002):

- **Override to a higher tier** (e.g., B → C): Preserve all existing artifacts. Activate additional orchestrator machinery (autonomous mode, crash recovery, discussion). No data migration needed — the orchestrator reads the same files regardless of tier.
- **Override to a lower tier** (e.g., C → B): Not recommended. If the project truly needs less orchestration, report this and suggest starting a new milestone at the lower tier instead.
- **Override to Tier A**: Report that Tier A bypasses the orchestrator entirely. If orchestrator artifacts already exist, warn that they will be unused but not deleted.

## Idempotency

If an evaluation has already been performed (a roadmap file or evaluation summary exists in the milestone directory):

1. **Report the existing tier** without re-evaluating: "Milestone {M###} already classified as Tier {X}."
2. **Do not re-scaffold or overwrite** existing artifacts.
3. **Require `--force`** or explicit confirmation to re-evaluate. If `--force` is provided, re-run the analysis and update the classification. If the tier changes, report what changed and why.

This satisfies R012 (idempotent commands) — running `evaluate` twice with no intervening changes produces identical disk state.

## Error Handling

- If no feature spec is found at the expected path, exit with error: "Feature spec not found at specs/{NNN}-{name}/spec.md. Run speckit.specify first."
- If `scripts/lifecycle/scaffold.sh` fails, report the error and do not write partial state.
- If `scripts/state/read-config.sh` is unavailable, proceed with auto-classification (no config override).

## Gotchas

- **Tier A produces zero orchestrator state**: Promotion to Tier B/C requires a fresh evaluate with `--tier` override — there is no upgrade path from existing Tier A artifacts because none exist.
- **Re-evaluation with --force overwrites tier metadata**: If a roadmap already exists, the tier classification changes but the roadmap becomes inconsistent with the new tier's expectations. Re-run `speckit.orchestrator.roadmap` after a tier change.
- **read-config.sh failure is non-fatal**: Falls back to auto-classification silently. If the config file has a `default_tier` override, that override will be missed — the tier may differ from what the developer expected.

## Reference Files

- `scripts/state/read-config.sh` — resolves configuration values including `default_tier`
- `scripts/lifecycle/scaffold.sh` — creates orchestrator directory structure
- `references/tier-definitions.md` — detailed tier classification criteria and decision table
