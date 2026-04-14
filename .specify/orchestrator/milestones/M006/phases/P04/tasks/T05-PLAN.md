---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M006"
name: "Verification scripts and cross-link validation for P04"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 completed: `docs/getting-started.md` exists.
- T02 completed: `docs/recipe-authoring.md` exists.
- T03 completed: `docs/hook-development.md` exists.
- T04 completed: `docs/knowledge-management.md` exists.

## Description

Create all 12 verification scripts referenced in the P04-PLAN.md Truths
section. Each script is a standalone single-file invocation (AD-19
compliant) that checks one specific property of the P04 documentation
artifacts. After creating the scripts, run the full verification suite
to confirm all checks pass.

All scripts follow the pattern established in P01, P02, and P03:
- Shebang: `#!/usr/bin/env bash`
- `set -eu`
- File existence check with descriptive failure
- Content pattern checks with descriptive failure
- Final `echo "PASS: <description>"` on success

## Steps

### Step 1 — Create getting-started.md verification scripts

Create four scripts:

**`scripts/verify/m006-p04-gs-header.sh`**
Checks that `docs/getting-started.md`:
- Exists
- Has a title line starting with `#`
- Contains progressive disclosure statement ("self-contained" or "progressive disclosure" or "user guide")
- Contains "Audience: users" label (DC-2)
- Contains `## Overview` section (DC-1)

**`scripts/verify/m006-p04-gs-install.sh`**
Checks that `docs/getting-started.md` contains:
- Installation section (mentions "install")
- Cross-link to `installation.md`
- Mentions spec-kit prerequisite

**`scripts/verify/m006-p04-gs-workflow.sh`**
Checks that `docs/getting-started.md` contains:
- `evaluate` command mention
- `discuss` command mention
- `roadmap` command mention
- `plan-phase` command mention
- `dispatch` or `auto` command mention
- `verify` command mention
- `status` command mention

**`scripts/verify/m006-p04-gs-engine.sh`**
Checks that `docs/getting-started.md` contains:
- Event output documentation (mentions "EVENT:" or "event")
- Result output documentation (mentions "RESULT:" or "result")
- State transition documentation (mentions "state" and either "transition" or "machine")
- Cross-link to `events.md`
- Cross-link to `engine.md`

### Step 2 — Create recipe-authoring.md verification scripts

Create two scripts:

**`scripts/verify/m006-p04-recipe-header.sh`**
Checks that `docs/recipe-authoring.md`:
- Exists
- Has a title line starting with `#`
- Contains progressive disclosure statement
- Contains "Audience: users" label (DC-2)
- Contains `## Overview` section (DC-1)

**`scripts/verify/m006-p04-recipe-content.sh`**
Checks that `docs/recipe-authoring.md` contains:
- `source` field documentation
- `compression` documentation
- `override` or "per-phase" documentation
- Resolution order (mentions "task", "phase", "milestone", "default")
- Cross-link to `recipes.md`
- Troubleshooting section

### Step 3 — Create hook-development.md verification scripts

Create two scripts:

**`scripts/verify/m006-p04-hook-header.sh`**
Checks that `docs/hook-development.md`:
- Exists
- Has a title line starting with `#`
- Contains progressive disclosure statement
- Contains "Audience: users" label (DC-2)
- Contains `## Overview` section (DC-1)

**`scripts/verify/m006-p04-hook-content.sh`**
Checks that `docs/hook-development.md` contains:
- All 4 lifecycle points: PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE
- All 4 verdict types: PASS, BLOCK, WARN, NEEDS_REVIEW
- Budget gate hook example (mentions "budget" and "gate")
- Quality check hook example (mentions "quality" and "check")
- Testing section
- Debugging section
- Cross-link to `hooks.md`

### Step 4 — Create knowledge-management.md verification scripts

Create two scripts:

**`scripts/verify/m006-p04-km-header.sh`**
Checks that `docs/knowledge-management.md`:
- Exists
- Has a title line starting with `#`
- Contains progressive disclosure statement
- Contains "Audience: users" label (DC-2)
- Contains `## Overview` section (DC-1)

**`scripts/verify/m006-p04-km-content.sh`**
Checks that `docs/knowledge-management.md` contains:
- Entry creation documentation (mentions "create-entry" or "create entry")
- Staleness documentation
- Graph relationship documentation (mentions "graph" or "relationship")
- Scope filtering documentation
- Consolidation documentation (mentions "consolidat")
- Entry lifecycle operations (mentions "update", "promote", "archive", "supersede")
- Cross-link to `file-formats.md`

### Step 5 — Create cross-link validation script

**`scripts/verify/m006-p04-crosslinks.sh`**
Checks cross-links between all four P04 docs and to reference docs:

For `docs/getting-started.md`:
- Links to `installation.md`, `architecture.md`, `engine.md`, `events.md`, `state-machine.md`
- Links to sibling docs: `recipe-authoring.md`, `hook-development.md`, `knowledge-management.md`

For `docs/recipe-authoring.md`:
- Links to `recipes.md`, `routing.md`

For `docs/hook-development.md`:
- Links to `hooks.md`, `events.md`

For `docs/knowledge-management.md`:
- Links to `file-formats.md`, `architecture.md`

All links must use relative paths (no absolute paths, no URLs for internal refs).

### Step 6 — Create command-name validation script

**`scripts/verify/m006-p04-commands-match.sh`**
Extracts all `speckit.orchestrator.*` command names from `docs/getting-started.md`
and verifies each one appears in `extension.yml` under `provides.commands[].name`.
Also verifies that no non-existent orchestrator command names are mentioned.

### Step 7 — Run the full verification suite

Execute all 12 scripts and confirm each exits 0. If any fail, investigate
whether the issue is in the verification script or in the documentation
artifact, and fix accordingly.

## Must-Haves

- [ ] All 12 verification scripts exist and are executable
- [ ] Each script follows the AD-19 single-script-file pattern (no compound bash)
- [ ] Each script prints "PASS:" on success, "FAIL:" on failure
- [ ] All 12 scripts pass when run against the P04 documentation artifacts
- [ ] `scripts/verify/m006-p04-crosslinks.sh` validates relative-path cross-links
- [ ] `scripts/verify/m006-p04-commands-match.sh` validates command names against extension.yml

## Verification

Run all scripts in sequence:

```
bash scripts/verify/m006-p04-gs-header.sh
bash scripts/verify/m006-p04-gs-install.sh
bash scripts/verify/m006-p04-gs-workflow.sh
bash scripts/verify/m006-p04-gs-engine.sh
bash scripts/verify/m006-p04-recipe-header.sh
bash scripts/verify/m006-p04-recipe-content.sh
bash scripts/verify/m006-p04-hook-header.sh
bash scripts/verify/m006-p04-hook-content.sh
bash scripts/verify/m006-p04-km-header.sh
bash scripts/verify/m006-p04-km-content.sh
bash scripts/verify/m006-p04-crosslinks.sh
bash scripts/verify/m006-p04-commands-match.sh
```

All must exit 0.

## Inputs

### From Previous Tasks

- T01: `docs/getting-started.md` — validation target
- T02: `docs/recipe-authoring.md` — validation target
- T03: `docs/hook-development.md` — validation target
- T04: `docs/knowledge-management.md` — validation target

### From Disk (Pre-existing)

- `scripts/verify/m006-p01-arch-header.sh` — pattern reference for script format
- `scripts/verify/m006-p03-crosslinks.sh` — pattern reference for cross-link validation
- `extension.yml` — command list for command-name validation
- `references/*.md` — cross-link targets (all exist from P01-P03)

## Constraints

- **AD-19**: Each verification check is a single script file invocation.
  No inline compound bash (for-loops, if-chains) in Truth check commands.
- Scripts must be Bash 3.2 compatible (DC-6).
- Each script must produce clear PASS/FAIL output.

## Expected Output

After completing this task:

1. All 12 verification scripts exist under `scripts/verify/m006-p04-*.sh`.
2. All scripts pass against the P04 documentation artifacts.
3. Cross-link validation confirms all docs reference each other and
   reference docs correctly.
4. Command-name validation confirms all mentioned commands exist in `extension.yml`.
5. If any documentation artifacts need fixing to pass verification,
   those fixes are applied as part of this task.
