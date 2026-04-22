---
description: "Use when starting a new project to classify scope as Tier A, B, or C. Analyzes the feature spec to determine how many SDD flows are needed and activates the corresponding workflow."
---

# orchestrator:evaluate

Classify a feature's scope into Tier A, B, or C and activate the corresponding orchestrator workflow. This is typically the first orchestrator command run for a new feature.

## Prerequisites

### 1. Extension Availability Check

Before invoking any orchestrator scripts, verify that the extension files are available in the current project. Do NOT use inline `if/then` blocks — use a single test command:

```bash
test -f scripts/lifecycle/scaffold.sh
```

If the exit code is non-zero (file doesn't exist), stop with a clear error: **"spec-kit-orchestrator extension not installed in this project. Copy the extension's commands/, scripts/, templates/, and references/ directories into your project root before running evaluate. See `references/installation.md` for details."**

Do NOT attempt to manually create the directory structure that `scaffold.sh` would produce — the scaffold script is the authoritative source for the orchestrator's directory layout.

### 2. Spec Discovery

A feature spec must exist at `specs/{NNN}-{name}/spec.md`. Since the project may have multiple spec directories (or the correct one may not be obvious), discover and confirm the spec before proceeding:

1. **List available specs**: Scan `specs/` for directories matching the `{NNN}-{name}` pattern. For each, check if `spec.md` exists inside it.
2. **If exactly one spec exists**: Use it, but confirm with the user: "Found spec at `specs/{NNN}-{name}/spec.md`. Proceeding with this spec."
3. **If multiple specs exist**: Present them as a numbered list and ask the user to select: "Multiple specs found:\n  1. specs/001-feature-a/spec.md\n  2. specs/002-feature-b/spec.md\nWhich spec should be evaluated?"
4. **If no specs exist**: Exit with error: "No feature specs found in `specs/`. Run `speckit.specify` first to create a feature spec."
5. **If a spec path was provided as an argument**: Use it directly after verifying the file exists.

Record the confirmed spec path — it will be written to the evaluation output and used by all downstream commands.

## Scope Analysis

Analyze the feature spec to determine the scope of work:

1. **Read the feature spec** at the confirmed path.
2. **Count structural elements**. Prefer ingested spec chunks over regex; fall back to regex if no chunks exist:

   **Chunks-first path** (when a spec has been ingested via `orchestrator:ingest`):

   ```bash
   bash scripts/state/spec-metrics.sh <orch-root>
   ```

   Parse the `key=value` lines from stdout. If `spec_chunks_present=true`, use `story_count`, `requirement_count`, and `acceptance_count` directly and record `metrics_source: spec_chunks` in the evaluation output. Non-goals are counted (`non_goal_count`) but do NOT contribute to tier classification.

   **Raw-spec fallback** (when `spec_chunks_present=false`):

   - Number of user stories (sections with "As a…" or "US-" prefixed items)
   - Number of acceptance scenarios (AC items, "Given/When/Then" blocks)
   - Number of functional requirements (FR-### items or numbered requirements)

   Record `metrics_source: raw_spec` in the evaluation output.
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
bash scripts/state/read-config.sh default_tier
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
bash scripts/lifecycle/scaffold.sh <orchestrator-root> <milestone-id>
```

Where `<orchestrator-root>` is `.orchestrator` and `<milestone-id>` is the milestone ID (e.g., `M001`). This creates the `.orchestrator/milestones/{M###}/` directory tree and global state files.

2. **Write the evaluation file** to the milestone directory using the `templates/evaluation.md` template:

Write to `<milestone-dir>/M###-EVALUATION.md` with:
- `milestone`: the milestone ID (e.g., `M001`)
- `feature_ref`: the feature reference from the spec directory name (e.g., `001-galaga-clone`)
- `feature_spec`: the full path to the spec file (e.g., `specs/001-galaga-clone/spec.md`)
- `tier`: the classified tier (B or C)
- `tier_source`: how the tier was determined — `auto` (analysis), `config` (default_tier override), or `override` (--tier flag)
- `created_at`: ISO-8601 timestamp
- Metrics section: user story count, acceptance scenario count, functional requirement count, estimated SDD flows
- Reasoning section: narrative explanation of why this tier was chosen
- Complexity factors: key factors that influenced the classification
- `metrics_source`: `spec_chunks` (counts came from ingested chunks) or `raw_spec` (counts came from regex on the raw spec)

This file is the authoritative source of the tier classification and spec path for all downstream commands (`discuss`, `roadmap`, `plan-phase`, etc.).

3. **Generate autonomy permissions** (FR-7):

Run the evaluate pre-flight script, which handles extension checks, config overrides, and permission generation in a single invocation. Do NOT use inline `if/then` blocks, command substitution, or `/tmp` writes — these trigger the harness safety heuristic (AD-19):

```bash
bash scripts/lifecycle/evaluate-preflight.sh . <TIER>
```

This outputs `PREFLIGHT:OK extension=true config_tier=<auto|A|B|C> permissions=<generated|skipped|merged|error>`. The script:
- Checks `autonomy.generate_on_init` config value
- If enabled and tier is B/C, runs the generator → writer pipeline using project-local temp files (not `/tmp`)
- User-authored `.claude/settings.json` files are merged additively (AD-13) — never overwritten

Report the `permissions` field value: "generated" means fresh permissions were written, "merged" means patterns were added to existing user settings, "skipped" means generation was disabled.

This step is idempotent: running `evaluate` again with an existing
`.claude/settings.json` that has the `_generated_by` marker overwrites
it with a fresh generation (reflecting any orchestrator config or
toolchain changes since the last run).

4. **Report to the user**:
   - Tier classification (A, B, or C) with reasoning
   - Next recommended command: `speckit.orchestrator.roadmap` (Tier B) or `speckit.orchestrator.discuss` (Tier C)

## Override Support

Accept `--tier A|B|C` to explicitly override auto-classification (FR-002):

- **Override to a higher tier** (e.g., B → C): Preserve all existing artifacts. Activate additional orchestrator machinery (autonomous mode, crash recovery, discussion). No data migration needed — the orchestrator reads the same files regardless of tier.
- **Override to a lower tier** (e.g., C → B): Not recommended. If the project truly needs less orchestration, report this and suggest starting a new milestone at the lower tier instead.
- **Override to Tier A**: Report that Tier A bypasses the orchestrator entirely. If orchestrator artifacts already exist, warn that they will be unused but not deleted.

When overriding, set `tier_source: override` in the evaluation file. Note that tier overrides re-trigger the permission generator when `autonomy.generate_on_init` is true — a tier change refreshes the autonomy mode (e.g., B→C upgrades `minimal` → `full`).

## Idempotency

If an evaluation has already been performed (an `M###-EVALUATION.md` file exists in the milestone directory):

1. **Report the existing tier** without re-evaluating: "Milestone {M###} already classified as Tier {X}."
2. **Do not re-scaffold or overwrite** existing artifacts.
3. **Require `--force`** or explicit confirmation to re-evaluate. If `--force` is provided, re-run the analysis and update the classification. If the tier changes, report what changed and why.

This satisfies R012 (idempotent commands) — running `evaluate` twice with no intervening changes produces identical disk state.

## Error Handling

- If no feature spec is found at the expected path, exit with error: "Feature spec not found. Run speckit.specify first."
- If extension scripts are not installed (see Extension Availability Check above), exit with the installation error message. Do NOT attempt to manually create scaffold directories.
- If `scripts/lifecycle/scaffold.sh` fails, report the error and do not write partial state.
- If `scripts/state/read-config.sh` is unavailable, proceed with auto-classification (no config override).

## Gotchas

- **Tier A produces zero orchestrator state**: Promotion to Tier B/C requires a fresh evaluate with `--tier` override — there is no upgrade path from existing Tier A artifacts because none exist.
- **Re-evaluation with --force overwrites tier metadata**: If a roadmap already exists, the tier classification changes but the roadmap becomes inconsistent with the new tier's expectations. Re-run `speckit.orchestrator.roadmap` after a tier change.
- **read-config.sh failure is non-fatal**: Falls back to auto-classification silently. If the config file has a `default_tier` override, that override will be missed — the tier may differ from what the developer expected.
- **The state machine (derive-phase.sh) is not tier-aware**: After evaluation, `derive-phase.sh` returns `planning` regardless of tier. For Tier C, the discussion gate is enforced by the `roadmap` command (which reads the tier from `M###-EVALUATION.md` and refuses to proceed without a finalized context draft), not by the state machine. This is intentional — the state machine derives state from file presence, and the tier is a policy overlay applied by commands.
- **The EVALUATION.md file is the tier authority**: All downstream commands (`discuss`, `roadmap`, `plan-phase`, etc.) should read the tier from `M###-EVALUATION.md` in the milestone directory. Do not rely on config alone — the evaluated tier may differ from the default_tier config if auto-classification or --tier override was used.

## Reference Files

- `templates/evaluation.md` — output template for the evaluation file
- `scripts/state/read-config.sh` — resolves configuration values including `default_tier`
- `scripts/state/spec-metrics.sh` — counts ingested spec chunks by category; used when a spec has been ingested via `orchestrator:ingest`
- `scripts/lifecycle/scaffold.sh` — creates orchestrator directory structure
- `references/tier-definitions.md` — detailed tier classification criteria and decision table
- `references/installation.md` — how to install the extension in a consumer project
