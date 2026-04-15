---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M006"
name: "Verification scripts and cross-link validation for P03"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 completed: `references/recipes.md` exists.
- T02 completed: `references/routing.md` exists.

## Description

Create all 8 verification scripts referenced in the P03-PLAN.md Truths
section. Each script is a standalone single-file invocation (AD-19
compliant) that checks one specific property of the P03 documentation
artifacts. After creating the scripts, run the full verification suite
to confirm all checks pass.

All scripts follow the pattern established in P01 and P02:
- Shebang: `#!/usr/bin/env bash`
- `set -eu`
- File existence check with descriptive failure
- Content pattern checks with descriptive failure
- Final `echo "PASS: <description>"` on success

## Steps

### Step 1 — Create recipes.md verification scripts

Create four scripts:

**`scripts/verify/m006-p03-recipes-header.sh`**
Checks that `references/recipes.md`:
- Exists
- Has a title line starting with `#`
- Contains progressive disclosure statement
- Contains "Audience:" label (DC-2)
- Contains `## Overview` section (DC-1)

**`scripts/verify/m006-p03-recipes-sections.sh`**
Checks that `references/recipes.md` contains:
- `source` field documentation
- `priority` field documentation (required, compressible, optional)
- `order` field documentation
- `filter` field documentation (none, scope, staleness, confidence)
- `cache_hint` field documentation (static, semi-static, dynamic)
- All 6 source types: `computed`, `phase_summaries`, `phase_plan`, `task_plan`, `template`, and either `file` or `index`

**`scripts/verify/m006-p03-recipes-compression.sh`**
Checks that `references/recipes.md` contains:
- `compression` section
- All 3 step types: `drop_optional`, `summarize`, `drop_lowest_confidence`
- `protected_sections` documentation
- `max_words` parameter
- `min_confidence` parameter

**`scripts/verify/m006-p03-recipes-resolution.sh`**
Checks that `references/recipes.md` contains:
- Resolution order documentation (mentions task, phase, milestone, default)
- `manifest` section documentation
- `include_token_count` or `token_count`
- `include_section_list` or `section_list`

### Step 2 — Create routing.md verification scripts

Create three scripts:

**`scripts/verify/m006-p03-routing-header.sh`**
Checks that `references/routing.md`:
- Exists
- Has a title line starting with `#`
- Contains progressive disclosure statement
- Contains "Audience:" label (DC-2)
- Contains `## Overview` section (DC-1)

**`scripts/verify/m006-p03-routing-models.sh`**
Checks that `references/routing.md` contains:
- All 3 model tiers: `heavy`, `standard`, `light`
- `context_budget` documentation
- `fallback` chain documentation
- `classification` rules documentation
- Built-in keyword mentions (at least "subsystem" from heavy, "implement" from standard, "config" from light)

**`scripts/verify/m006-p03-routing-config.sh`**
Checks that `references/routing.md` contains:
- `budget_ceiling` documentation
- `history_weight` documentation
- `recoverable_errors` documentation
- `max_retries` documentation
- `retry_delay` documentation

### Step 3 — Create cross-link validation script

**`scripts/verify/m006-p03-crosslinks.sh`**
Checks that each P03 doc cross-links to its expected targets:
- `references/recipes.md` links to: routing.md, file-formats.md, architecture.md, engine.md
- `references/routing.md` links to: recipes.md, file-formats.md, architecture.md, engine.md

All links must use relative paths (no absolute paths, no URLs for internal refs).

### Step 4 — Run the full verification suite

Execute all 8 scripts and confirm each exits 0. If any fail, investigate
whether the issue is in the verification script or in the documentation
artifact, and fix accordingly.

## Must-Haves

- [ ] All 8 verification scripts exist and are executable
- [ ] Each script follows the AD-19 single-script-file pattern (no compound bash)
- [ ] Each script prints "PASS:" on success, "FAIL:" on failure
- [ ] All 8 scripts pass when run against the P03 documentation artifacts
- [ ] `scripts/verify/m006-p03-crosslinks.sh` validates relative-path cross-links

## Verification

Run all scripts in sequence:

```
bash scripts/verify/m006-p03-recipes-header.sh
bash scripts/verify/m006-p03-recipes-sections.sh
bash scripts/verify/m006-p03-recipes-compression.sh
bash scripts/verify/m006-p03-recipes-resolution.sh
bash scripts/verify/m006-p03-routing-header.sh
bash scripts/verify/m006-p03-routing-models.sh
bash scripts/verify/m006-p03-routing-config.sh
bash scripts/verify/m006-p03-crosslinks.sh
```

All must exit 0.

## Inputs

### From Previous Tasks

- T01: `references/recipes.md` — validation target
- T02: `references/routing.md` — validation target

### From Disk (Pre-existing)

- `scripts/verify/m006-p01-arch-header.sh` — pattern reference for script format
- `scripts/verify/m006-p02-crosslinks.sh` — pattern reference for cross-link validation
- `references/architecture.md` — cross-link target (already exists)
- `references/engine.md` — cross-link target (already exists)
- `references/file-formats.md` — cross-link target (already exists)

## Constraints

- **AD-19**: Each verification check is a single script file invocation.
  No inline compound bash (for-loops, if-chains) in Truth check commands.
- Scripts must be Bash 3.2 compatible (DC-6).
- Each script must produce clear PASS/FAIL output.

## Expected Output

After completing this task:

1. All 8 verification scripts exist under `scripts/verify/m006-p03-*.sh`.
2. All scripts pass against the P03 documentation artifacts.
3. Cross-link validation confirms both docs reference each other and
   existing reference docs correctly.
4. If any documentation artifacts need fixing to pass verification,
   those fixes are applied as part of this task.
