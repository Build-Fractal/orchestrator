---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M002"
name: "Audit, Harden, Register, and Document Routing Scripts"
depends_on: ["T01"]
---

## Prerequisites

T01 is complete. All 9 verification scripts exist under `scripts/verify/m002-p06-*.sh`. The routing scripts exist on disk from prior milestones and need validation against FR-116/FR-117, registration in extension.yml, and format documentation in references/file-formats.md.

## Description

Audit `classify-complexity.sh` and `select-model.sh` against the FR-116 and FR-117 requirements from the feature spec. Validate `templates/routing.yaml` format against the spec's routing configuration format. Register both scripts in `extension.yml`. Document the `routing.yaml` format in `references/file-formats.md`.

## Steps

### Step 1: Audit classify-complexity.sh against FR-117

Read `scripts/dispatch/classify-complexity.sh` and verify:

1. **Explicit override** (FR-117): reads YAML frontmatter between `---` markers and extracts `complexity:` field. If the value is one of `heavy`, `standard`, or `light`, outputs it and exits immediately. This is already implemented -- verify it works correctly.

2. **Custom classification keywords**: when `--routing-config <file>` is provided, the script should read classification patterns from the routing config's `classification.<tier>.patterns` field. Currently the script accepts the flag but does NOT read custom keywords from the config. Add this capability:

   After the explicit override check, if `$ROUTING_CONFIG` is set and the file exists, read patterns for each tier using the recipe-parser or direct grep/sed:
   ```
   # Source recipe-parser for read_recipe_field
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   . "$PROJECT_ROOT/scripts/lib/recipe-parser.sh"
   ```

   For each tier (heavy, standard, light), read the `classification.<tier>.patterns` field, split on comma, and count matches in the task plan content. This replaces (or supplements) the built-in keyword arrays.

3. **Default fallback**: when no routing config is provided, the built-in keyword arrays serve as defaults. This is already implemented -- verify it is correct.

4. **Bash 3.2 compatibility**: no associative arrays, no readarray, no mapfile.

The script must remain standalone-capable (no hard dependency on recipe-parser when `--routing-config` is not used).

### Step 2: Audit select-model.sh against FR-116

Read `scripts/dispatch/select-model.sh` and verify:

1. **Default mode**: given a tier, outputs `<model-id> <context-budget>`. Already implemented.
2. **Routing config override**: when `--routing-config <file>` is provided, reads model ID and context budget from `models.<tier>.id` and `models.<tier>.context_budget`. Already implemented via `read_recipe_field`.
3. **Fallback chain**: `--list-fallback` and `--next-fallback` modes. Already implemented.
4. **Built-in defaults**: heavy=claude-opus-4-6/200000, standard=claude-sonnet-4-6/150000, light=claude-haiku-4-5/80000. Already implemented.
5. **Error handling**: invalid tier exits with error. Already implemented.

The script has a known SIGPIPE workaround for `init_run_context` (P06-deferred bug comment at line 124). Verify this workaround is correct and does not mask other errors.

No code changes expected unless audit finds gaps.

### Step 3: Validate templates/routing.yaml

Read `templates/routing.yaml` and verify it matches the spec's routing configuration format (spec.md US7):

Required fields per FR-116:
- `models:` section with `heavy:`, `standard:`, `light:` sub-sections
- Each model tier has: `id` (model identifier string), `context_budget` (integer), `fallback` (comma-separated model IDs or empty string)
- `classification:` section with `heavy:`, `standard:`, `light:` sub-sections
- Each classification tier has: `patterns` (comma-separated keywords), `confidence` (float)
- `history_weight:` (float, 0.0-1.0) -- weight given to historical data in routing decisions
- `budget_ceiling_usd:` (float) -- maximum spend ceiling

Verify the template is parseable by `scripts/lib/recipe-parser.sh`:
```bash
# These should all return values:
bash -c '. scripts/lib/recipe-parser.sh && read_recipe_field templates/routing.yaml "models.heavy.id"'
bash -c '. scripts/lib/recipe-parser.sh && read_recipe_field templates/routing.yaml "models.standard.context_budget"'
bash -c '. scripts/lib/recipe-parser.sh && read_recipe_field templates/routing.yaml "history_weight"'
```

Fix any parsing issues. The template must be parseable by grep/sed/awk -- no jq required (NFR-106).

### Step 4: Register scripts in extension.yml

Add both routing scripts to the `provides.scripts` section of `extension.yml`, placed after the existing dispatch scripts (`detect-capabilities.sh`):

```yaml
    - file: scripts/dispatch/classify-complexity.sh
      executable: true
    - file: scripts/dispatch/select-model.sh
      executable: true
```

Insert these two entries after the `scripts/dispatch/detect-capabilities.sh` entry (approximately line 89) to maintain the dispatch script grouping.

### Step 5: Document routing.yaml format in references/file-formats.md

Add a new section to `references/file-formats.md` documenting the routing.yaml format. Insert it after the Configuration section (after the `orchestrator-config.yml` documentation, before any existing trailing content). The section should follow the same documentation pattern as other file formats in the document:

```markdown
---

## Routing Configuration (`routing.yaml`)

**Location**: `.specify/orchestrator/routing.yaml` or `templates/routing.yaml` (default)
**Format**: YAML (max 2 levels nesting, parseable by grep/sed/awk)
**Mutability**: Edited by the developer. Optional -- if absent, built-in defaults are used.

### Schema

```yaml
models:
  heavy:
    id: "claude-opus-4-6"           # Model identifier for complex tasks
    context_budget: 200000           # Max context tokens for this tier
    fallback: "claude-sonnet-4-6"    # Comma-separated fallback chain (or empty)
  standard:
    id: "claude-sonnet-4-6"         # Model identifier for typical tasks
    context_budget: 150000
    fallback: "claude-haiku-4-5"
  light:
    id: "claude-haiku-4-5"          # Model identifier for simple tasks
    context_budget: 80000
    fallback: ""

classification:
  heavy:
    patterns: "new subsystem,>5 files,architectural decision,first phase"
    confidence: 0.8
  standard:
    patterns: "feature implementation,2-5 files,follows established pattern"
    confidence: 0.6
  light:
    patterns: "config change,test addition,single-file edit,documentation"
    confidence: 0.4

fallback_config:
  recoverable_errors: "rate_limit,timeout,overloaded"
  max_retries: 2
  retry_delay_seconds: 5

history_weight: 0.3                  # Weight for historical data in routing (0.0-1.0)
budget_ceiling_usd: 50.00           # Maximum spend ceiling in USD
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `models.<tier>.id` | string | Model identifier for the tier |
| `models.<tier>.context_budget` | integer | Maximum context tokens for dispatches in this tier |
| `models.<tier>.fallback` | string | Comma-separated fallback model IDs for retry on recoverable error |
| `classification.<tier>.patterns` | string | Comma-separated keywords that signal this complexity tier |
| `classification.<tier>.confidence` | float | Minimum confidence threshold for tier assignment |
| `fallback_config.recoverable_errors` | string | Comma-separated error types that trigger fallback |
| `fallback_config.max_retries` | integer | Maximum retry attempts per dispatch |
| `fallback_config.retry_delay_seconds` | integer | Delay between retry attempts |
| `history_weight` | float | Weight (0.0-1.0) given to historical telemetry data in routing |
| `budget_ceiling_usd` | float | Maximum USD spend ceiling for the project |

### Parsing Rules

- Max 2 levels of YAML nesting. Parseable by `scripts/lib/recipe-parser.sh` using grep/sed/awk.
- `read_recipe_field routing.yaml "models.heavy.id"` returns the model ID.
- `parse_recipe_fallback routing.yaml "heavy"` returns the comma-separated fallback chain.
- When the routing config file is absent, `classify-complexity.sh` uses built-in keyword arrays and `select-model.sh` uses built-in model defaults.

### Resolution Order

When `select-model.sh` or `classify-complexity.sh` receive a `--routing-config` path:
1. If the file exists, read configuration from it.
2. If the file does not exist or the field is missing, fall back to built-in defaults.

The orchestrator looks for `routing.yaml` at `.specify/orchestrator/routing.yaml`. If not found, `templates/routing.yaml` provides a copyable starting point.
```

### Step 6: Run verification scripts

After all changes, run all 9 verification scripts:

```bash
bash scripts/verify/m002-p06-classify-outputs-tier.sh
bash scripts/verify/m002-p06-classify-explicit-override.sh
bash scripts/verify/m002-p06-classify-routing-config.sh
bash scripts/verify/m002-p06-select-model-output.sh
bash scripts/verify/m002-p06-select-model-fallback.sh
bash scripts/verify/m002-p06-routing-template-format.sh
bash scripts/verify/m002-p06-fileformats-routing-section.sh
bash scripts/verify/m002-p06-extension-registration.sh
bash scripts/verify/m002-p06-bash32-compat.sh
```

All should output `PASS: <description>` and exit 0.

## Must-Haves

This task addresses all 9 phase must-haves:
- classify-complexity.sh outputs correct tier (audit)
- classify-complexity.sh respects explicit override (audit)
- classify-complexity.sh accepts --routing-config (audit + potential enhancement)
- select-model.sh maps tier to model ID + budget (audit)
- select-model.sh supports fallback chain (audit)
- templates/routing.yaml defines complete format (validation)
- references/file-formats.md documents routing.yaml (new documentation)
- extension.yml registers both scripts (new registration)
- Bash 3.2 compatibility (audit)

## Verification

```
bash scripts/verify/m002-p06-classify-outputs-tier.sh
bash scripts/verify/m002-p06-classify-explicit-override.sh
bash scripts/verify/m002-p06-classify-routing-config.sh
bash scripts/verify/m002-p06-select-model-output.sh
bash scripts/verify/m002-p06-select-model-fallback.sh
bash scripts/verify/m002-p06-routing-template-format.sh
bash scripts/verify/m002-p06-fileformats-routing-section.sh
bash scripts/verify/m002-p06-extension-registration.sh
bash scripts/verify/m002-p06-bash32-compat.sh
```

Expected output for each: `PASS: <description>`

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p06-*.sh` (from T01) -- 9 verification scripts. Each is a standalone bash script that greps source files for required patterns and prints PASS/FAIL. No API surface -- just `bash scripts/verify/m002-p06-<name>.sh` invocation returning exit 0 (pass) or 1 (fail).

### From Disk (Pre-existing)

- `scripts/dispatch/classify-complexity.sh` -- 81 lines. Accepts `<task-plan-file> [--routing-config <file>]`. Reads YAML frontmatter for explicit `complexity:` override, then counts keyword signals across three tiers using built-in arrays. Outputs one of `heavy`, `standard`, `light` to stdout. The `--routing-config` flag is parsed but custom keywords from the config are NOT currently used (gap to close).
- `scripts/dispatch/select-model.sh` -- 241 lines. Accepts `<tier> [--routing-config <file>] [--list-fallback | --next-fallback <model-id>]`. Default mode: `<model-id> <context-budget>` to stdout. Sources `scripts/lib/recipe-parser.sh` for `read_recipe_field()` and `parse_recipe_fallback()`. Built-in defaults when no config: heavy=claude-opus-4-6/200000, standard=claude-sonnet-4-6/150000, light=claude-haiku-4-5/80000.
- `scripts/lib/recipe-parser.sh` -- 482 lines. Provides `read_recipe_field(file, dotted.path)` for 1-3 level YAML field access, `parse_recipe_fallback(file, tier)` for fallback chain reading. All grep/sed/awk, no jq.
- `templates/routing.yaml` -- 43 lines. Default routing config with models (heavy/standard/light with id, context_budget, fallback), classification (patterns, confidence per tier), fallback_config, history_weight, budget_ceiling_usd.
- `extension.yml` -- extension manifest. Routing scripts are NOT registered. Dispatch scripts section ends with `detect-capabilities.sh` at approximately line 89.
- `references/file-formats.md` -- format reference (693 lines). Documents all state file formats. No routing.yaml section exists. The Configuration section for `orchestrator-config.yml` ends at approximately line 693.

## Constraints

- Do not change the public API of classify-complexity.sh or select-model.sh (same args, same output contract)
- Bash 3.2 compatibility: no associative arrays, no readarray, no mapfile (NFR-105)
- No new hard dependencies: jq optional, no python3 required (NFR-106)
- classify-complexity.sh must remain standalone-capable when --routing-config is not provided
- templates/routing.yaml must remain parseable by recipe-parser.sh (max 2 levels YAML nesting)

## Expected Output

Modified files:
- `scripts/dispatch/classify-complexity.sh` -- potentially enhanced to read custom keywords from routing config
- `extension.yml` -- 2 new script entries under provides.scripts
- `references/file-formats.md` -- new Routing Configuration section appended

Unchanged files (verified correct):
- `scripts/dispatch/select-model.sh` -- expected to pass audit without changes
- `templates/routing.yaml` -- expected to pass validation without changes
