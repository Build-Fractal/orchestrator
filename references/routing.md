# Routing Reference

> Progressive disclosure reference for the speckit-orchestrator model routing system.
> Self-contained — read this document to understand model tiers, fallback chains,
> classification rules, and budget controls without reading source code.

> Audience: extenders, contributors

## Overview

The routing system selects which model handles each dispatched task. It uses a three-tier model hierarchy (light, standard, heavy) with automatic fallback chains for resilience. When a task is dispatched, the engine:

1. **Classifies** the task's complexity tier (via `classify-complexity.sh`)
2. **Selects** the primary model and context budget for that tier (via `select-model.sh`)
3. **Falls back** to the next model in the chain if the primary fails with a recoverable error

All routing configuration lives in `templates/routing.yaml`. When no configuration file is present, built-in defaults are used. The routing system is designed to be parseable by grep/sed/awk with no jq dependency (NFR-200).

**Specification**: US10 (Model Routing with Fallback Chains), FR-213.

---

## Model Tiers

Three tiers map task complexity to model capability. Each tier defines a primary model, a context budget (maximum tokens for the assembled payload), and a fallback chain.

### heavy

For tasks that create new subsystems, span many files, or make architectural decisions. Reserved for the most capable model.

| Field          | Default Value                              |
|----------------|--------------------------------------------|
| id             | `claude-opus-4-6`                          |
| context_budget | `200000`                                   |
| fallback       | `claude-sonnet-4-6`, `claude-haiku-4-5`    |

The heavy tier has the deepest fallback chain (two models). If opus is unavailable, the engine retries with sonnet, then haiku.

### standard

For typical feature implementation: 2-5 files, following established patterns. This is the default tier when classification is ambiguous.

| Field          | Default Value                              |
|----------------|--------------------------------------------|
| id             | `claude-sonnet-4-6`                        |
| context_budget | `150000`                                   |
| fallback       | `claude-haiku-4-5`                         |

### light

For config changes, test additions, single-file edits, and documentation. Uses the smallest and fastest model with no fallback.

| Field          | Default Value                              |
|----------------|--------------------------------------------|
| id             | `claude-haiku-4-5`                         |
| context_budget | `80000`                                    |
| fallback       | *(none)*                                   |

The light tier has no fallback chain. If haiku fails, the task is recorded as failed with error kind `DISPATCH`.

---

## Classification

Task complexity classification follows a strict 4-level priority. The first matching level wins.

### Priority 1: Explicit Override

If the task plan file contains YAML frontmatter with a `complexity:` field, that value is used directly. Valid values: `heavy`, `standard`, `light`.

```yaml
---
complexity: heavy
---
```

This is the highest-priority mechanism and is intended for cases where the developer knows the classification should differ from what heuristics would produce.

### Priority 2: Custom Keywords from routing.yaml

If a `routing.yaml` is provided via `--routing-config` and contains a `classification:` block, the engine uses its comma-separated keyword patterns instead of the built-in keywords. Each pattern is matched against the lowercase content of the task plan.

The tier with the most keyword matches wins. Each tier also has a `confidence` field (currently informational, reserved for future weighted scoring).

**Default custom patterns:**

| Tier     | Patterns                                                  | Confidence |
|----------|-----------------------------------------------------------|------------|
| heavy    | `new subsystem`, `>5 files`, `architectural decision`, `first phase` | 0.8        |
| standard | `feature implementation`, `2-5 files`, `follows established pattern` | 0.6        |
| light    | `config change`, `test addition`, `single-file edit`, `documentation` | 0.4        |

### Priority 3: Built-in Signal Keywords

When no custom classification patterns are present in `routing.yaml`, the classifier uses hard-coded keyword lists. Each keyword is matched case-insensitively against the full task plan content.

**Built-in heavy signals**: `new subsystem`, `rewrite`, `architect`, `from scratch`, `high risk`, `complex`, `foundation`

**Built-in standard signals**: `implement`, `feature`, `modify`, `extend`, `update`, `enhance`, `integrate`

**Built-in light signals**: `config`, `test`, `document`, `single file`, `rename`, `typo`, `template`, `wrapper`, `thin`

The tier with the most matching keywords wins. In case of a tie between heavy and light, light wins. In all other ties, standard wins.

### Priority 4: Default

If no keywords match in any tier, the task is classified as `standard`.

---

## Fallback Chains

Fallback chains provide automatic model retry when a primary model fails with a recoverable error. The chain is walked in order until a model succeeds or the chain is exhausted.

### How Fallbacks Work

1. The engine dispatches to the primary model for the task's tier.
2. If the dispatch fails with a **recoverable error**, the engine calls `select-model.sh --next-fallback <current-model>` to get the next model in the chain.
3. The engine retries with the next model, up to `max_retries` attempts total.
4. If the chain is exhausted (no more fallback models), the task is recorded as failed with error kind `DISPATCH`.

### Recoverable Errors

Only specific error types trigger fallback. Non-recoverable errors (e.g., invalid input, permissions) fail immediately without walking the chain.

Default recoverable errors: `rate_limit`, `timeout`, `overloaded`

### Chain Structure

The full chain for a tier is: `primary` followed by the comma-separated `fallback` list. For example, the heavy tier's full chain is:

```
claude-opus-4-6 -> claude-sonnet-4-6 -> claude-haiku-4-5
```

If the current model is not found in the chain (e.g., a misconfigured fallback), `select-model.sh` emits a `SAFETY_WARNING` event and exits with code 1.

### select-model.sh Modes

The `select-model.sh` script supports three modes:

| Mode               | Flag                               | Output                                  |
|--------------------|------------------------------------|-----------------------------------------|
| Default            | *(none)*                           | `<model-id> <context-budget>`           |
| List fallback      | `--list-fallback`                  | Comma-separated fallback chain          |
| Next fallback      | `--next-fallback <current-model>`  | Next model ID, or exit 1 if exhausted   |

### Execution Log Recording

When a fallback occurs, the execution log records which model was actually used (AS3). This may differ from the primary model selected at classification time.

---

## Budget Controls

Two top-level fields in `routing.yaml` control cost and execution behavior.

### budget_ceiling_usd

**Default**: `50.00`

The maximum cumulative cost (in USD) for the current execution session. When the engine's cumulative cost reaches this ceiling, remaining tasks are blocked with reason `budget`. The engine tracks cost in cents internally (`_cum_cost_cents`).

Setting `budget_ceiling_usd` to `0` disables cost-based budget enforcement.

### history_weight

**Default**: `0.3`

A weighting factor (0.0-1.0) that controls how much prior task execution history influences model selection decisions. Higher values give more weight to historical patterns. This field is reserved for future adaptive routing; current routing uses it as a configuration anchor but does not dynamically adjust tier selection based on history.

### Retry Controls (fallback_config)

These fields control the mechanics of fallback retries when a model fails:

| Field                 | Default | Description                                                  |
|-----------------------|---------|--------------------------------------------------------------|
| `recoverable_errors`  | `rate_limit,timeout,overloaded` | Comma-separated error types that trigger fallback  |
| `max_retries`         | `2`     | Maximum number of fallback attempts per task                 |
| `retry_delay_seconds` | `5`     | Seconds to wait before retrying with the next fallback model |

If a task exhausts all retries across the full fallback chain, it is recorded as failed. The execution log entry includes the full chain of attempted models.

---

## Configuration (routing.yaml)

The routing configuration file is located at `templates/routing.yaml`. It uses a flat YAML structure with a maximum of 2 levels of nesting, designed to be parseable without jq.

### Full Format Reference

```yaml
# Model definitions — one block per tier
models:
  heavy:
    id: "claude-opus-4-6"           # Model identifier
    context_budget: 200000           # Max tokens for payload assembly
    fallback: "claude-sonnet-4-6,claude-haiku-4-5"  # Comma-separated chain
  standard:
    id: "claude-sonnet-4-6"
    context_budget: 150000
    fallback: "claude-haiku-4-5"
  light:
    id: "claude-haiku-4-5"
    context_budget: 80000
    fallback: ""                     # Empty string = no fallback

# Classification keywords — matched against task plan content
classification:
  heavy:
    patterns: "new subsystem,>5 files,architectural decision,first phase"
    confidence: 0.8                  # Reserved for future weighted scoring
  standard:
    patterns: "feature implementation,2-5 files,follows established pattern"
    confidence: 0.6
  light:
    patterns: "config change,test addition,single-file edit,documentation"
    confidence: 0.4

# Fallback retry mechanics
fallback_config:
  recoverable_errors: "rate_limit,timeout,overloaded"
  max_retries: 2
  retry_delay_seconds: 5

# Session-level controls
history_weight: 0.3                  # 0.0-1.0, weight for historical patterns
budget_ceiling_usd: 50.00           # Max session cost in USD (0 = disabled)
```

### Field Parsing

All fields are read by `scripts/lib/recipe-parser.sh` using the `read_recipe_field` function with dot-notation paths:

- `models.heavy.id` returns `claude-opus-4-6`
- `models.standard.context_budget` returns `150000`
- `classification.light.patterns` returns comma-separated keyword string
- `history_weight` returns `0.3`

The fallback field is read by `parse_recipe_fallback`, which delegates to `read_recipe_field` for `models.<tier>.fallback`.

### When No Config Exists

If `routing.yaml` is not present or `--routing-config` is not passed, all scripts fall back to built-in defaults hard-coded in `select-model.sh`. This makes routing configuration entirely optional — the system works out of the box.

---

## Cross-References

- [Architecture](architecture.md) — system-level view of how routing fits into the dispatch pipeline
- [State Machine](state-machine.md) — milestone lifecycle states that routing operates within
- [Tier Definitions](tier-definitions.md) — project scope tiers (A/B/C), distinct from model routing tiers
- [Engine Reference](engine.md) — the dispatch pipeline that invokes routing
- [File Formats](./file-formats.md) — execution log format that records routing decisions
- [Recipes Reference](./recipes.md) — context recipe system that routing integrates with
- `templates/routing.yaml` — default configuration file
- `scripts/dispatch/select-model.sh` — model selection and fallback chain logic
- `scripts/dispatch/classify-complexity.sh` — task complexity classification
- `scripts/lib/recipe-parser.sh` — YAML field reader used by routing scripts
