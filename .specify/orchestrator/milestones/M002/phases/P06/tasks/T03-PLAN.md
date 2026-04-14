---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M002"
name: "End-to-End Routing Verification"
depends_on: ["T02"]
---

## Prerequisites

T01 and T02 are complete. All 9 verification scripts exist. classify-complexity.sh and select-model.sh have been audited and hardened. Both scripts are registered in extension.yml. templates/routing.yaml is validated. references/file-formats.md documents the routing format.

## Description

Create synthetic task plans of varying complexity levels, run classify-complexity.sh and select-model.sh against them, and verify the full routing pipeline works end-to-end: task plan -> complexity classification -> model selection. This proves that a developer can configure routing.yaml, dispatch tasks of varying complexity, and each routes to the correct model. Run all 9 verification scripts to confirm all P06 must-haves pass.

## Steps

### Step 1: Create synthetic task plans for testing

Create three temporary task plan files to exercise all three complexity tiers:

**Heavy task plan** (`/tmp/p06-test-heavy.md`):
```markdown
---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M099"
name: "Build New Authentication Subsystem"
depends_on: []
---

## Description

Design and implement a new subsystem from scratch for authentication.
This is an architectural decision that will affect >5 files across
the project foundation. High risk, complex integration required.

## Steps

1. Architect the new subsystem structure
2. Create foundation module from scratch
3. Implement complex token validation
```

**Standard task plan** (`/tmp/p06-test-standard.md`):
```markdown
---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M099"
name: "Implement User Profile Feature"
depends_on: ["T01"]
---

## Description

Implement the user profile feature by modifying 3 files.
Follows the established pattern from the auth subsystem.
Extend the existing API to integrate profile endpoints.

## Steps

1. Implement the profile model
2. Update the API handler
3. Modify the routing table
```

**Light task plan** (`/tmp/p06-test-light.md`):
```markdown
---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M099"
name: "Add Config Template"
depends_on: []
---

## Description

Add a single file config template for the documentation.
This is a straightforward template wrapper for the test suite.

## Steps

1. Create the config template file
2. Add documentation entry
```

**Explicit override task plan** (`/tmp/p06-test-override.md`):
```markdown
---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M099"
name: "Simple Rename Task"
complexity: heavy
depends_on: []
---

## Description

Rename a single config file. Despite being a trivial task, this is
marked as heavy via explicit complexity frontmatter override.

## Steps

1. Rename the config file
2. Update references
```

### Step 2: Test classify-complexity.sh with each task plan

Run the classifier against each synthetic plan and verify output:

```bash
# Should output "heavy" (keyword signals: "new subsystem", "from scratch", "architect", "complex", "foundation")
result=$(bash scripts/dispatch/classify-complexity.sh /tmp/p06-test-heavy.md)
test "$result" = "heavy" || echo "FAIL: expected heavy, got $result"

# Should output "standard" (keyword signals: "implement", "feature", "modify", "extend", "integrate")
result=$(bash scripts/dispatch/classify-complexity.sh /tmp/p06-test-standard.md)
test "$result" = "standard" || echo "FAIL: expected standard, got $result"

# Should output "light" (keyword signals: "config", "template", "single file", "wrapper", "test")
result=$(bash scripts/dispatch/classify-complexity.sh /tmp/p06-test-light.md)
test "$result" = "light" || echo "FAIL: expected light, got $result"

# Should output "heavy" (explicit override takes precedence over keyword signals)
result=$(bash scripts/dispatch/classify-complexity.sh /tmp/p06-test-override.md)
test "$result" = "heavy" || echo "FAIL: expected heavy (override), got $result"
```

### Step 3: Test select-model.sh with each tier

Run the model selector for each tier and verify output:

```bash
# Default mode (no routing config)
result=$(bash scripts/dispatch/select-model.sh heavy 2>/dev/null)
echo "$result"  # Expected: claude-opus-4-6 200000

result=$(bash scripts/dispatch/select-model.sh standard 2>/dev/null)
echo "$result"  # Expected: claude-sonnet-4-6 150000

result=$(bash scripts/dispatch/select-model.sh light 2>/dev/null)
echo "$result"  # Expected: claude-haiku-4-5 80000
```

### Step 4: Test select-model.sh with routing config

```bash
# With routing config
result=$(bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml 2>/dev/null)
echo "$result"  # Expected: claude-opus-4-6 200000

# List fallback chain
result=$(bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml --list-fallback 2>/dev/null)
echo "$result"  # Expected: claude-sonnet-4-6,claude-haiku-4-5

# Next fallback
result=$(bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml --next-fallback claude-opus-4-6 2>/dev/null)
echo "$result"  # Expected: claude-sonnet-4-6
```

### Step 5: Test full pipeline -- classify then select

Prove the end-to-end routing pipeline by chaining classification and selection:

```bash
# Classify the heavy task plan, then select the model for that tier
tier=$(bash scripts/dispatch/classify-complexity.sh /tmp/p06-test-heavy.md)
model_line=$(bash scripts/dispatch/select-model.sh "$tier" --routing-config templates/routing.yaml 2>/dev/null)
echo "Heavy task: tier=$tier model=$model_line"
# Expected: Heavy task: tier=heavy model=claude-opus-4-6 200000

# Classify the light task plan, then select the model
tier=$(bash scripts/dispatch/classify-complexity.sh /tmp/p06-test-light.md)
model_line=$(bash scripts/dispatch/select-model.sh "$tier" --routing-config templates/routing.yaml 2>/dev/null)
echo "Light task: tier=$tier model=$model_line"
# Expected: Light task: tier=light model=claude-haiku-4-5 80000

# Classify the override task plan, then select the model
tier=$(bash scripts/dispatch/classify-complexity.sh /tmp/p06-test-override.md)
model_line=$(bash scripts/dispatch/select-model.sh "$tier" --routing-config templates/routing.yaml 2>/dev/null)
echo "Override task: tier=$tier model=$model_line"
# Expected: Override task: tier=heavy model=claude-opus-4-6 200000
```

### Step 6: Run all 9 verification scripts

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

All 9 should output `PASS: <description>` and exit 0.

### Step 7: Clean up synthetic test files

```bash
rm -f /tmp/p06-test-heavy.md /tmp/p06-test-standard.md /tmp/p06-test-light.md /tmp/p06-test-override.md
```

## Must-Haves

This task provides end-to-end validation for all P06 must-haves:
- classify-complexity.sh outputs correct tier for each complexity level
- Explicit complexity: override takes precedence
- --routing-config flag works for both classify and select
- select-model.sh returns correct model + budget for each tier
- Fallback chain modes work correctly
- routing.yaml template is complete and parseable
- file-formats.md documents routing
- extension.yml registers both scripts
- Bash 3.2 compatibility confirmed

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

Expected output: 9 lines of `PASS: <description>`, all exit 0.

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p06-*.sh` (from T01) -- 9 verification scripts. Each is `bash scripts/verify/m002-p06-<name>.sh` returning exit 0 (PASS) or 1 (FAIL). No API surface beyond invocation.
- `scripts/dispatch/classify-complexity.sh` (audited by T02) -- accepts `<task-plan-file> [--routing-config <file>]`. Reads YAML frontmatter for `complexity:` override (priority 1), then custom keywords from routing config (priority 2, if --routing-config provided), then built-in keyword arrays (priority 3). Outputs one of `heavy`, `standard`, `light` to stdout.
- `scripts/dispatch/select-model.sh` (audited by T02) -- accepts `<tier> [--routing-config <file>] [--list-fallback | --next-fallback <model-id>]`. Default mode outputs `<model-id> <context-budget>`. Uses `scripts/lib/recipe-parser.sh` for YAML parsing. Built-in defaults: heavy=claude-opus-4-6/200000, standard=claude-sonnet-4-6/150000, light=claude-haiku-4-5/80000.
- `extension.yml` (modified by T02) -- now registers `scripts/dispatch/classify-complexity.sh` and `scripts/dispatch/select-model.sh` under `provides.scripts`.
- `references/file-formats.md` (modified by T02) -- now includes a Routing Configuration section documenting `routing.yaml` format, fields, and parsing rules.

### From Disk (Pre-existing)

- `templates/routing.yaml` -- default routing configuration. Contains models (heavy/standard/light), classification patterns, fallback_config, history_weight, budget_ceiling_usd.

## Constraints

- Synthetic test files must be created in `/tmp/` to avoid polluting the project directory
- All test files must be cleaned up after verification
- This is a verification-only task -- no permanent file changes expected
- All verification scripts must pass for the phase to be considered complete

## Expected Output

No new permanent files. The task produces:
- Synthetic test plans in `/tmp/` (created and cleaned up within the task)
- Verification that all 9 `scripts/verify/m002-p06-*.sh` scripts pass
- Confirmation that the end-to-end routing pipeline works: task plan -> classify-complexity.sh -> select-model.sh -> correct model selection
