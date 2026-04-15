---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M002"
name: "Verification Scripts for All Must-Haves"
depends_on: []
---

## Prerequisites

P06 has no task-level upstream dependencies. The following scripts already exist on disk from prior milestones:

- `scripts/dispatch/classify-complexity.sh` (81 lines) -- classifies task complexity from keyword signals
- `scripts/dispatch/select-model.sh` (241 lines) -- maps complexity tier to model ID + context budget with fallback support
- `templates/routing.yaml` (43 lines) -- default routing configuration template
- `scripts/lib/recipe-parser.sh` (482 lines) -- YAML parser used by select-model.sh
- `extension.yml` -- extension manifest; currently does NOT register classify-complexity.sh or select-model.sh
- `references/file-formats.md` -- format reference; currently does NOT document routing.yaml

## Description

Create 9 verification scripts under `scripts/verify/m002-p06-*.sh` that mechanically check all P06 must-haves. Each script is a single-file invocation (per AD-19) that prints `PASS: <message>` on success or `FAIL: <message>` on failure, exiting 0 on pass and 1 on fail.

## Steps

### Step 1: Create `scripts/verify/m002-p06-classify-outputs-tier.sh`

Verifies that `classify-complexity.sh` outputs one of heavy, standard, or light based on keyword matching.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/dispatch/classify-complexity.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
# Check that the script contains all three tier keywords as output values
grep -q '"heavy"\|echo.*heavy' "$f" || { echo "FAIL: does not output heavy tier"; exit 1; }
grep -q '"standard"\|echo.*standard' "$f" || { echo "FAIL: does not output standard tier"; exit 1; }
grep -q '"light"\|echo.*light' "$f" || { echo "FAIL: does not output light tier"; exit 1; }
# Check that it reads a task plan file as input
grep -q 'TASK_PLAN\|task.plan\|task-plan' "$f" || { echo "FAIL: does not accept task plan file"; exit 1; }
# Check keyword signal matching
grep -q 'keyword\|signal\|pattern' "$f" || { echo "FAIL: no keyword signal matching logic"; exit 1; }
echo "PASS: classify-complexity.sh outputs heavy/standard/light from keyword signals"
```

### Step 2: Create `scripts/verify/m002-p06-classify-explicit-override.sh`

Verifies that `classify-complexity.sh` respects explicit `complexity:` in YAML frontmatter.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/dispatch/classify-complexity.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'complexity:' "$f" || { echo "FAIL: does not check for complexity: frontmatter"; exit 1; }
grep -q 'frontmatter\|^---' "$f" || grep -q 'sed.*---' "$f" || { echo "FAIL: does not parse YAML frontmatter for override"; exit 1; }
grep -qE 'explicit|override' "$f" || grep -q 'complexity.*heavy\|complexity.*standard\|complexity.*light' "$f" || { echo "FAIL: no explicit override logic"; exit 1; }
echo "PASS: classify-complexity.sh respects explicit complexity: frontmatter override"
```

### Step 3: Create `scripts/verify/m002-p06-classify-routing-config.sh`

Verifies that `classify-complexity.sh` accepts optional `--routing-config` flag.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/dispatch/classify-complexity.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-routing-config' "$f" || { echo "FAIL: does not accept --routing-config flag"; exit 1; }
grep -q 'ROUTING_CONFIG' "$f" || { echo "FAIL: no ROUTING_CONFIG variable handling"; exit 1; }
echo "PASS: classify-complexity.sh accepts --routing-config flag"
```

### Step 4: Create `scripts/verify/m002-p06-select-model-output.sh`

Verifies that `select-model.sh` maps a tier to model ID + context budget with built-in defaults.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/dispatch/select-model.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
# Check it accepts tier as argument
grep -q 'heavy\|standard\|light' "$f" || { echo "FAIL: does not handle complexity tiers"; exit 1; }
# Check built-in defaults
grep -q 'claude-opus' "$f" || { echo "FAIL: missing heavy tier default model"; exit 1; }
grep -q 'claude-sonnet' "$f" || { echo "FAIL: missing standard tier default model"; exit 1; }
grep -q 'claude-haiku' "$f" || { echo "FAIL: missing light tier default model"; exit 1; }
# Check context budget defaults
grep -q '200000\|150000\|80000' "$f" || { echo "FAIL: missing context budget defaults"; exit 1; }
# Check routing config support
grep -q 'routing.config\|ROUTING_CONFIG\|routing-config' "$f" || { echo "FAIL: does not accept routing config"; exit 1; }
echo "PASS: select-model.sh maps tier to model ID + context budget with defaults"
```

### Step 5: Create `scripts/verify/m002-p06-select-model-fallback.sh`

Verifies that `select-model.sh` supports fallback chain modes.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/dispatch/select-model.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-list-fallback' "$f" || { echo "FAIL: missing --list-fallback mode"; exit 1; }
grep -q '\-\-next-fallback' "$f" || { echo "FAIL: missing --next-fallback mode"; exit 1; }
grep -q 'fallback' "$f" || { echo "FAIL: no fallback chain logic"; exit 1; }
echo "PASS: select-model.sh supports --list-fallback and --next-fallback modes"
```

### Step 6: Create `scripts/verify/m002-p06-routing-template-format.sh`

Verifies that `templates/routing.yaml` defines the required format.

```bash
#!/usr/bin/env bash
set -eu
f="templates/routing.yaml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'models:' "$f" || { echo "FAIL: missing models: section"; exit 1; }
grep -q 'heavy:' "$f" || { echo "FAIL: missing heavy tier"; exit 1; }
grep -q 'standard:' "$f" || { echo "FAIL: missing standard tier"; exit 1; }
grep -q 'light:' "$f" || { echo "FAIL: missing light tier"; exit 1; }
grep -q 'id:' "$f" || { echo "FAIL: missing id field in model tiers"; exit 1; }
grep -q 'context_budget:' "$f" || { echo "FAIL: missing context_budget field"; exit 1; }
grep -q 'classification:' "$f" || { echo "FAIL: missing classification section"; exit 1; }
grep -q 'history_weight:' "$f" || { echo "FAIL: missing history_weight field"; exit 1; }
grep -q 'budget_ceiling_usd:' "$f" || { echo "FAIL: missing budget_ceiling_usd field"; exit 1; }
echo "PASS: templates/routing.yaml defines complete routing format"
```

### Step 7: Create `scripts/verify/m002-p06-fileformats-routing-section.sh`

Verifies that `references/file-formats.md` documents routing.yaml format.

```bash
#!/usr/bin/env bash
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi 'routing' "$f" || { echo "FAIL: file-formats.md does not mention routing"; exit 1; }
grep -q 'routing.yaml' "$f" || { echo "FAIL: file-formats.md does not document routing.yaml"; exit 1; }
grep -q 'models' "$f" || { echo "FAIL: file-formats.md routing section missing models description"; exit 1; }
grep -q 'classification' "$f" || { echo "FAIL: file-formats.md routing section missing classification description"; exit 1; }
grep -q 'history_weight\|budget_ceiling' "$f" || { echo "FAIL: file-formats.md routing section missing top-level config fields"; exit 1; }
echo "PASS: references/file-formats.md documents routing.yaml format"
```

### Step 8: Create `scripts/verify/m002-p06-extension-registration.sh`

Verifies that `extension.yml` registers both routing scripts.

```bash
#!/usr/bin/env bash
set -eu
f="extension.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'scripts/dispatch/classify-complexity.sh' "$f" || { echo "FAIL: classify-complexity.sh not registered in extension.yml"; exit 1; }
grep -q 'scripts/dispatch/select-model.sh' "$f" || { echo "FAIL: select-model.sh not registered in extension.yml"; exit 1; }
echo "PASS: extension.yml registers both routing scripts"
```

### Step 9: Create `scripts/verify/m002-p06-bash32-compat.sh`

Verifies that routing scripts do not use Bash 3.2-incompatible features.

```bash
#!/usr/bin/env bash
set -eu
files="scripts/dispatch/classify-complexity.sh scripts/dispatch/select-model.sh"
for f in $files; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
grep -rlE 'declare -A|readarray|mapfile' $files && { echo "FAIL: Bash 3.2 incompatible constructs found"; exit 1; }
echo "PASS: all routing scripts are Bash 3.2 compatible"
```

### Step 10: Make all scripts executable

```bash
chmod +x scripts/verify/m002-p06-*.sh
```

## Must-Haves

This task delivers all 9 verification scripts required by the phase plan. Every other task in this phase uses these scripts for mechanical verification.

## Verification

Run each verification script. Since T02 has not yet executed, some checks will fail. The following should pass immediately because the scripts already exist:

```
bash scripts/verify/m002-p06-classify-outputs-tier.sh
bash scripts/verify/m002-p06-classify-explicit-override.sh
bash scripts/verify/m002-p06-classify-routing-config.sh
bash scripts/verify/m002-p06-select-model-output.sh
bash scripts/verify/m002-p06-select-model-fallback.sh
bash scripts/verify/m002-p06-routing-template-format.sh
bash scripts/verify/m002-p06-bash32-compat.sh
```

Expected output for each: `PASS: <description>`

The following will fail until T02 completes:
```
bash scripts/verify/m002-p06-extension-registration.sh
bash scripts/verify/m002-p06-fileformats-routing-section.sh
```

## Inputs

### From Previous Tasks

None -- this is the first task in the phase.

### From Disk (Pre-existing)

- `scripts/dispatch/classify-complexity.sh` -- classifies task complexity. Accepts a task plan file path as first positional arg and optional `--routing-config <file>` flag. Reads YAML frontmatter for explicit `complexity:` override, then falls back to keyword signal matching across three tiers (heavy, standard, light). Outputs one tier string to stdout.
- `scripts/dispatch/select-model.sh` -- maps complexity tier to model. Accepts tier (heavy/standard/light) as first positional arg, optional `--routing-config <file>`, and optional `--list-fallback` or `--next-fallback <model-id>` modes. Default mode outputs `<model-id> <context-budget>` to stdout. Fallback modes walk the fallback chain. Built-in defaults: heavy=claude-opus-4-6/200000, standard=claude-sonnet-4-6/150000, light=claude-haiku-4-5/80000.
- `templates/routing.yaml` -- default routing configuration. Contains `models:` (heavy/standard/light with id, context_budget, fallback), `classification:` (patterns and confidence per tier), `fallback_config:` (recoverable_errors, max_retries, retry_delay_seconds), `history_weight`, `budget_ceiling_usd`.
- `extension.yml` -- extension manifest. Does NOT currently register classify-complexity.sh or select-model.sh.
- `references/file-formats.md` -- format reference. Does NOT currently document routing.yaml.

## Constraints

- All verification scripts must use single-script-file invocation shape per AD-19
- No compound bash, no subshells, no pipes inside $(), no inline for/if/while in Check: commands
- Each script must be independently executable: `bash scripts/verify/m002-p06-<name>.sh`
- Scripts must print PASS/FAIL and exit 0/1 respectively

## Expected Output

9 new files under `scripts/verify/`:
- `m002-p06-classify-outputs-tier.sh`
- `m002-p06-classify-explicit-override.sh`
- `m002-p06-classify-routing-config.sh`
- `m002-p06-select-model-output.sh`
- `m002-p06-select-model-fallback.sh`
- `m002-p06-routing-template-format.sh`
- `m002-p06-fileformats-routing-section.sh`
- `m002-p06-extension-registration.sh`
- `m002-p06-bash32-compat.sh`

All scripts are executable and follow the single-script-file shape convention.
