---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M006"
name: "Verification scripts and cross-link validation for P02"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 completed: `references/engine.md` exists.
- T02 completed: `references/events.md` exists.
- T03 completed: `references/errors.md` exists.
- T04 completed: `references/hooks.md` exists.

## Description

Create all 13 verification scripts referenced in the P02-PLAN.md Truths
section. Each script is a standalone single-file invocation (AD-19
compliant) that checks one specific property of the P02 documentation
artifacts. After creating the scripts, run the full verification suite
to confirm all checks pass.

All scripts follow the pattern established in P01:
- Shebang: `#!/usr/bin/env bash`
- `set -eu`
- File existence check with descriptive failure
- Content pattern checks with descriptive failure
- Final `echo "PASS: <description>"` on success

## Steps

### Step 1 — Create engine.md verification scripts

Create three scripts:

**`scripts/verify/m006-p02-engine-header.sh`**
Checks that `references/engine.md`:
- Exists
- Has a title line starting with `#`
- Contains "Progressive disclosure" or similar progressive-disclosure statement
- Contains "Audience:" label (DC-2)
- Contains `## Overview` section (DC-1)

**`scripts/verify/m006-p02-engine-args.sh`**
Checks that `references/engine.md` contains:
- `--dry-run`
- `--force`
- `ORCH_RUN_SEED`
- `ORCH_DRY_RUN`
- `ORCH_FORCE`
- `ORCH_ENGINE_STOP_AFTER_TASK`

**`scripts/verify/m006-p02-engine-lifecycle.sh`**
Checks that `references/engine.md` contains:
- Documentation of lifecycle stages (grep for "Init" and "Dispatch" and "Verify" and "Record")
- `checkpoint` mention
- `crash recovery` or `crash-recovery` mention

### Step 2 — Create events.md verification scripts

Create three scripts:

**`scripts/verify/m006-p02-events-header.sh`**
Checks that `references/events.md`:
- Exists
- Contains progressive disclosure statement
- Contains "Audience:" label
- Contains `## Overview` section

**`scripts/verify/m006-p02-events-types.sh`**
Checks that `references/events.md` contains all 18 canonical event types:
SESSION_START, SESSION_END, PHASE_START, PHASE_COMPLETE,
TASK_START, TASK_COMPLETE, DISPATCH_START, DISPATCH_FALLBACK,
VERIFY_START, VERIFY_COMPLETE, GUARD_BLOCKED, GUARD_WARNING,
SAFETY_WARNING, HOOK_START, HOOK_COMPLETE, HOOK_BLOCKED,
HOOK_VIOLATION, CHECKPOINT_WRITE, CHECKPOINT_RESUME

**`scripts/verify/m006-p02-events-format.sh`**
Checks that `references/events.md` contains:
- `EVENT:` format documentation
- `timestamp` field mention
- `run_id` field mention

### Step 3 — Create errors.md verification scripts

Create three scripts:

**`scripts/verify/m006-p02-errors-header.sh`**
Checks that `references/errors.md`:
- Exists
- Contains progressive disclosure statement
- Contains "Audience:" label
- Contains `## Overview` section

**`scripts/verify/m006-p02-errors-kinds.sh`**
Checks that `references/errors.md` contains all 6 error kinds:
CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO

**`scripts/verify/m006-p02-errors-protocol.sh`**
Checks that `references/errors.md` contains:
- `RESULT:` format documentation
- `emit_result` function reference
- `status` field mention
- `error_kind` field mention

### Step 4 — Create hooks.md verification scripts

Create three scripts:

**`scripts/verify/m006-p02-hooks-header.sh`**
Checks that `references/hooks.md`:
- Exists
- Contains progressive disclosure statement
- Contains "Audience:" label
- Contains `## Overview` section

**`scripts/verify/m006-p02-hooks-lifecycle.sh`**
Checks that `references/hooks.md` contains all 4 lifecycle points:
PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE

**`scripts/verify/m006-p02-hooks-verdicts.sh`**
Checks that `references/hooks.md` contains:
- Verdict protocol mentions: PASS, BLOCK, WARN, NEEDS_REVIEW
- `snapshot` isolation mention
- `HOOK_VIOLATION` mention

### Step 5 — Create cross-link validation script

**`scripts/verify/m006-p02-crosslinks.sh`**
Checks that each P02 doc cross-links to its expected targets:
- `references/engine.md` links to: events.md, errors.md, hooks.md, architecture.md
- `references/events.md` links to: engine.md, errors.md
- `references/errors.md` links to: events.md, engine.md
- `references/hooks.md` links to: engine.md, events.md, file-formats.md

All links must use relative paths (no absolute paths, no URLs for internal refs).

### Step 6 — Run the full verification suite

Execute all 13 scripts and confirm each exits 0. If any fail, investigate
whether the issue is in the verification script or in the documentation
artifact, and fix accordingly.

## Must-Haves

- [ ] All 13 verification scripts exist and are executable
- [ ] Each script follows the AD-19 single-script-file pattern (no compound bash)
- [ ] Each script prints "PASS:" on success, "FAIL:" on failure
- [ ] All 13 scripts pass when run against the P02 documentation artifacts
- [ ] `scripts/verify/m006-p02-crosslinks.sh` validates relative-path cross-links

## Verification

Run all scripts in sequence:

```
bash scripts/verify/m006-p02-engine-header.sh
bash scripts/verify/m006-p02-engine-args.sh
bash scripts/verify/m006-p02-engine-lifecycle.sh
bash scripts/verify/m006-p02-events-header.sh
bash scripts/verify/m006-p02-events-types.sh
bash scripts/verify/m006-p02-events-format.sh
bash scripts/verify/m006-p02-errors-header.sh
bash scripts/verify/m006-p02-errors-kinds.sh
bash scripts/verify/m006-p02-errors-protocol.sh
bash scripts/verify/m006-p02-hooks-header.sh
bash scripts/verify/m006-p02-hooks-lifecycle.sh
bash scripts/verify/m006-p02-hooks-verdicts.sh
bash scripts/verify/m006-p02-crosslinks.sh
```

All must exit 0.

## Inputs

### From Previous Tasks

- T01: `references/engine.md` — validation target
- T02: `references/events.md` — validation target
- T03: `references/errors.md` — validation target
- T04: `references/hooks.md` — validation target

### From Disk (Pre-existing)

- `scripts/verify/m006-p01-arch-header.sh` — pattern reference for script format
- `references/architecture.md` — cross-link target (already exists)
- `references/file-formats.md` — cross-link target (already exists)

## Constraints

- **AD-19**: Each verification check is a single script file invocation.
  No inline compound bash (for-loops, if-chains) in Truth check commands.
- Scripts must be Bash 3.2 compatible (DC-6).
- Each script must produce clear PASS/FAIL output.

## Expected Output

After completing this task:

1. All 13 verification scripts exist under `scripts/verify/m006-p02-*.sh`.
2. All scripts pass against the P02 documentation artifacts.
3. Cross-link validation confirms all docs reference each other correctly.
4. If any documentation artifacts need fixing to pass verification,
   those fixes are applied as part of this task.
