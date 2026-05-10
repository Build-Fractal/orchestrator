---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M006"
name: "Verification scripts, cross-link validation, and compliance review for P05"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 completed: `scripts/AGENTS.md` exists (rewritten contributor guide).
- T02 completed: `references/constitution-walkthrough.md` exists.

## Description

Create all 9 verification scripts referenced in the P05-PLAN.md Truths
section. Each script is a standalone single-file invocation (AD-19
compliant) that checks one specific property of the P05 documentation
artifacts. After creating the scripts, run the full verification suite
to confirm all checks pass.

Then, review one real [M004](../../../../../milestones/M004/index.md) or [M005](../../../../../milestones/M005/index.md) phase against the contributor guide
to validate that the guide is actionable and that the reviewed code
follows the documented conventions. Fix any convention violations found.

All scripts follow the pattern established in P01-P04:
- Shebang: `#!/usr/bin/env bash`
- `set -eu`
- File existence check with descriptive failure
- Content pattern checks with descriptive failure
- Final `echo "PASS: <description>"` on success

## Steps

### Step 1 — Create `scripts/AGENTS.md` verification scripts

Create six scripts:

**`scripts/verify/m006-p05-agents-header.sh`**
Checks that `scripts/AGENTS.md`:
- Exists
- Has a title line starting with `#`
- Contains progressive disclosure statement ("self-contained" or "progressive disclosure" or "contributor guide")
- Contains "Audience: contributors" label (DC-2)
- Contains `## Overview` section (DC-1)

**`scripts/verify/m006-p05-agents-bash32.sh`**
Checks that `scripts/AGENTS.md` contains:
- Bash 3.2 compatibility section (mentions "Bash 3.2" or "3.2")
- Mentions `declare -A` as prohibited
- Mentions process substitution ("`<(`" or "process substitution")
- References AP-001 or "platform-specific"

**`scripts/verify/m006-p05-agents-guards.sh`**
Checks that `scripts/AGENTS.md` contains:
- Double-sourcing guard section (mentions "double-sourcing" or "sourcing guard")
- Shows the guard pattern (`_SOURCED` or `_LIBNAME_SOURCED`)
- References AP-003 or "missing" guard antipattern

**`scripts/verify/m006-p05-agents-events.sh`**
Checks that `scripts/AGENTS.md` contains:
- Event emission section (mentions "emit_event")
- Result protocol section (mentions "emit_result")
- Silent failure definition (mentions "silent failure" or "RESULT line")
- References at least 3 event types (SESSION_START, TASK_COMPLETE, PHASE_COMPLETE, etc.)

**`scripts/verify/m006-p05-agents-testing.sh`**
Checks that `scripts/AGENTS.md` contains:
- Testing patterns section
- Mentions `pass()` and `fail()` functions
- Mentions "PASS:" and "FAIL:" output format
- Mentions fixtures or `tests/fixtures`

**`scripts/verify/m006-p05-agents-checklists.sh`**
Checks that `scripts/AGENTS.md` contains:
- Constitution compliance checklist section (mentions "compliance" and "checklist")
- PR review checklist section (mentions "PR" and "review" and "checklist")
- At least 10 checklist items (lines starting with `- [ ]` or `- ` or numbered items)

### Step 2 — Create `references/constitution-walkthrough.md` verification scripts

Create two scripts:

**`scripts/verify/m006-p05-walkthrough-header.sh`**
Checks that `references/constitution-walkthrough.md`:
- Exists
- Has a title line starting with `#`
- Contains progressive disclosure statement
- Contains "Audience: contributors" label (DC-2)
- Contains `## Overview` section (DC-1)

**`scripts/verify/m006-p05-walkthrough-principles.sh`**
Checks that `references/constitution-walkthrough.md` contains:
- All 13 principles by name: "Context Minimization", "Evidence Before Claims",
  "Design Before Code", "Plans Assume Zero Context", "Fresh Context Per Unit",
  "State On Disk", "Knowledge Compounds", "No Dead Infrastructure",
  "Reproducibility", "Templating Over Inference", "Single Source of Truth",
  "Hook Isolation", "Agent Instruction Schema"
- At least 13 `## Principle` headings (one per principle)
- Subsection headings: "What It Means", "Codebase Examples", "Common Violations",
  "How to Check"
- Quick Reference Table (mentions "Quick Reference" and contains a markdown table)

### Step 3 — Create cross-link validation script

**`scripts/verify/m006-p05-crosslinks.sh`**
Checks cross-links between both P05 docs and to reference docs:

For `scripts/AGENTS.md`:
- Links to `constitution-walkthrough.md`
- Links to `architecture.md`
- Links to `ANTIPATTERNS.md`

For `references/constitution-walkthrough.md`:
- Links to `constitution.md`
- Links to `AGENTS.md`
- Links to `architecture.md`
- Links to `ANTIPATTERNS.md`

All links must use relative paths (no absolute paths, no URLs for internal refs).

### Step 4 — Run the full verification suite

Execute all 9 scripts and confirm each exits 0. If any fail, investigate
whether the issue is in the verification script or in the documentation
artifact, and fix accordingly.

### Step 5 — Compliance review of one real M004/M005 phase

Using the contributor guide from T01 as the checklist, review one real
phase from M004 or M005. Suggested target: M005 P07 (auto.md pre-flight
rewrite + evaluate.md init + Known Limitations) since it was the most
recent phase. Check:

1. Do the scripts from that phase follow Bash 3.2 patterns?
2. Do library files have double-sourcing guards?
3. Do engine-managed scripts emit events and results?
4. Are atomic writes used for state changes?
5. Is there dead infrastructure?

Document findings briefly. If violations are found:
- Fix the violation.
- Commit with a message referencing the contributor guide per DC-5.

## Must-Haves

- [ ] All 9 verification scripts exist and are executable
- [ ] Each script follows the AD-19 single-script-file pattern (no compound bash)
- [ ] Each script prints "PASS:" on success, "FAIL:" on failure
- [ ] All 9 scripts pass when run against the P05 documentation artifacts
- [ ] `scripts/verify/m006-p05-crosslinks.sh` validates relative-path cross-links
- [ ] One real M004/M005 phase reviewed against the contributor guide
- [ ] Any convention violations found are fixed and committed

## Verification

Run all scripts in sequence:

```
bash scripts/verify/m006-p05-agents-header.sh
bash scripts/verify/m006-p05-agents-bash32.sh
bash scripts/verify/m006-p05-agents-guards.sh
bash scripts/verify/m006-p05-agents-events.sh
bash scripts/verify/m006-p05-agents-testing.sh
bash scripts/verify/m006-p05-agents-checklists.sh
bash scripts/verify/m006-p05-walkthrough-header.sh
bash scripts/verify/m006-p05-walkthrough-principles.sh
bash scripts/verify/m006-p05-crosslinks.sh
```

All must exit 0.

## Inputs

### From Previous Tasks

- T01: `scripts/AGENTS.md` — validation target (contributor guide)
- T02: `references/constitution-walkthrough.md` — validation target (walkthrough)

### From Disk (Pre-existing)

- `scripts/verify/m006-p01-arch-header.sh` — pattern reference for script format
- `scripts/verify/m006-p04-crosslinks.sh` — pattern reference for cross-link validation
- `references/architecture.md` — cross-link target
- `.specify/memory/constitution.md` — cross-link target
- `ANTIPATTERNS.md` — cross-link target
- Scripts from M004/M005 — compliance review targets

## Constraints

- **AD-19**: Each verification check is a single script file invocation.
  No inline compound bash (for-loops, if-chains) in Truth check commands.
- Scripts must be Bash 3.2 compatible (DC-6).
- Each script must produce clear PASS/FAIL output.

## Expected Output

After completing this task:

1. All 9 verification scripts exist under `scripts/verify/m006-p05-*.sh`.
2. All scripts pass against the P05 documentation artifacts.
3. Cross-link validation confirms both docs reference each other and
   reference docs correctly.
4. One M004/M005 phase reviewed with findings documented.
5. Any convention violations fixed and committed with DC-5 references.
