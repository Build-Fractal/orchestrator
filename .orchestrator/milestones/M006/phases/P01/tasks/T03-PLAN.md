---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M006"
name: "Verification scripts for P01 must-haves"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 completed: `references/architecture.md` exists.
- T02 completed: `references/file-formats.md` updated with new sections.

## Description

Create 12 standalone verification scripts referenced by the P01 phase plan's
Truth `Check:` commands. Each script is a single-file invocation (AD-19
compliant) that checks one specific property of the P01 documentation
artifacts. After creating all scripts, run the full verification suite to
confirm all checks pass.

Per AD-19, every Truth `Check:` in the phase plan uses the shape
`bash scripts/verify/m006-p01-<name>.sh` — no inline compound bash, no
subshells, no pipes in the command itself.

## Steps

### Step 1 — Create architecture.md verification scripts (6 scripts)

Create each script at `scripts/verify/m006-p01-<name>.sh`. Each must:
- Use `#!/usr/bin/env bash` shebang
- Set `set -eu`
- Check for the target file's existence
- Grep for required patterns
- Print PASS/FAIL with descriptive message
- Exit 0 on pass, 1 on fail

**`scripts/verify/m006-p01-arch-header.sh`**
```bash
#!/usr/bin/env bash
# Verify references/architecture.md has progressive disclosure header + audience label.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "^# Architecture Reference" "$f" || { echo "FAIL: missing title"; exit 1; }
grep -q "Progressive disclosure" "$f" || { echo "FAIL: missing progressive disclosure statement"; exit 1; }
grep -qi "Audience:" "$f" || { echo "FAIL: missing audience label (DC-2)"; exit 1; }
grep -q "## Overview" "$f" || { echo "FAIL: missing ## Overview section (DC-1)"; exit 1; }
echo "PASS: architecture.md header and audience label"
```

**`scripts/verify/m006-p01-arch-pipeline.sh`**
```bash
#!/usr/bin/env bash
# Verify references/architecture.md contains ASCII engine pipeline diagram with 7 stages.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "## Engine Pipeline" "$f" || { echo "FAIL: missing Engine Pipeline section"; exit 1; }
grep -q "Init" "$f" || { echo "FAIL: missing Init stage"; exit 1; }
grep -q "Build" "$f" || { echo "FAIL: missing Build stage"; exit 1; }
grep -q "Compress" "$f" || { echo "FAIL: missing Compress stage"; exit 1; }
grep -q "Dispatch" "$f" || { echo "FAIL: missing Dispatch stage"; exit 1; }
grep -q "Verify" "$f" || { echo "FAIL: missing Verify stage"; exit 1; }
grep -q "Record" "$f" || { echo "FAIL: missing Record stage"; exit 1; }
echo "PASS: architecture.md engine pipeline diagram"
```

**`scripts/verify/m006-p01-arch-dataflow.sh`**
```bash
#!/usr/bin/env bash
# Verify references/architecture.md documents the data flow stages.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "## Data Flow" "$f" || { echo "FAIL: missing Data Flow section"; exit 1; }
grep -q "recipe" "$f" || { echo "FAIL: missing recipe reference in data flow"; exit 1; }
grep -q "build-context" "$f" || { echo "FAIL: missing build-context reference"; exit 1; }
grep -q "compress" "$f" || { echo "FAIL: missing compress reference"; exit 1; }
grep -q "dispatch" "$f" || { echo "FAIL: missing dispatch reference"; exit 1; }
grep -q "record-result" "$f" || { echo "FAIL: missing record-result reference"; exit 1; }
echo "PASS: architecture.md data flow"
```

**`scripts/verify/m006-p01-arch-layout.sh`**
```bash
#!/usr/bin/env bash
# Verify references/architecture.md includes a file layout tree.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "## File Layout" "$f" || { echo "FAIL: missing File Layout section"; exit 1; }
grep -q "scripts/" "$f" || { echo "FAIL: missing scripts/ in layout"; exit 1; }
grep -q "commands/" "$f" || { echo "FAIL: missing commands/ in layout"; exit 1; }
grep -q "templates/" "$f" || { echo "FAIL: missing templates/ in layout"; exit 1; }
grep -q "references/" "$f" || { echo "FAIL: missing references/ in layout"; exit 1; }
grep -q ".specify/orchestrator/" "$f" || { echo "FAIL: missing .specify/orchestrator/ in layout"; exit 1; }
echo "PASS: architecture.md file layout tree"
```

**`scripts/verify/m006-p01-arch-subsystems.sh`**
```bash
#!/usr/bin/env bash
# Verify references/architecture.md includes subsystem relationship map.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "M001" "$f" || { echo "FAIL: missing M001 subsystem"; exit 1; }
grep -q "M002" "$f" || { echo "FAIL: missing M002 subsystem"; exit 1; }
grep -q "M003" "$f" || { echo "FAIL: missing M003 subsystem"; exit 1; }
grep -q "M004" "$f" || { echo "FAIL: missing M004 subsystem"; exit 1; }
grep -q "M005" "$f" || { echo "FAIL: missing M005 subsystem"; exit 1; }
echo "PASS: architecture.md subsystem map"
```

**`scripts/verify/m006-p01-arch-crosslinks.sh`**
```bash
#!/usr/bin/env bash
# Verify references/architecture.md cross-links to other reference docs via relative paths.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "state-machine.md" "$f" || { echo "FAIL: missing cross-link to state-machine.md"; exit 1; }
grep -q "file-formats.md" "$f" || { echo "FAIL: missing cross-link to file-formats.md"; exit 1; }
grep -q "verification-ladder.md" "$f" || { echo "FAIL: missing cross-link to verification-ladder.md"; exit 1; }
grep -q "tier-definitions.md" "$f" || { echo "FAIL: missing cross-link to tier-definitions.md"; exit 1; }
# Verify links are relative (no absolute paths)
grep -qE "\(/.*references/" "$f" && { echo "FAIL: absolute path found in cross-links (DC-3 violation)"; exit 1; }
echo "PASS: architecture.md cross-links"
```

### Step 2 — Create file-formats.md verification scripts (5 scripts)

**`scripts/verify/m006-p01-formats-recipe.sh`**
```bash
#!/usr/bin/env bash
# Verify references/file-formats.md documents context-recipe.yaml format.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "context-recipe.yaml" "$f" || { echo "FAIL: missing context-recipe.yaml documentation"; exit 1; }
grep -q "sections:" "$f" || { echo "FAIL: missing sections block documentation"; exit 1; }
grep -q "compression:" "$f" || { echo "FAIL: missing compression block documentation"; exit 1; }
grep -q "priority" "$f" || { echo "FAIL: missing priority field documentation"; exit 1; }
echo "PASS: file-formats.md documents context-recipe.yaml"
```

**`scripts/verify/m006-p01-formats-hooks.sh`**
```bash
#!/usr/bin/env bash
# Verify references/file-formats.md documents hooks.yaml format.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "hooks.yaml" "$f" || { echo "FAIL: missing hooks.yaml documentation"; exit 1; }
grep -q "PRE_DISPATCH" "$f" || { echo "FAIL: missing PRE_DISPATCH lifecycle point"; exit 1; }
grep -q "POST_DISPATCH" "$f" || { echo "FAIL: missing POST_DISPATCH lifecycle point"; exit 1; }
grep -q "POST_VERIFY" "$f" || { echo "FAIL: missing POST_VERIFY lifecycle point"; exit 1; }
grep -q "PRE_ADVANCE" "$f" || { echo "FAIL: missing PRE_ADVANCE lifecycle point"; exit 1; }
grep -q "block_on_fail" "$f" || { echo "FAIL: missing block_on_fail field"; exit 1; }
echo "PASS: file-formats.md documents hooks.yaml"
```

**`scripts/verify/m006-p01-formats-routing.sh`**
```bash
#!/usr/bin/env bash
# Verify references/file-formats.md documents routing.yaml format.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "routing.yaml" "$f" || { echo "FAIL: missing routing.yaml documentation"; exit 1; }
grep -q "models:" "$f" || { echo "FAIL: missing models block documentation"; exit 1; }
grep -q "classification:" "$f" || { echo "FAIL: missing classification block documentation"; exit 1; }
grep -q "fallback" "$f" || { echo "FAIL: missing fallback documentation"; exit 1; }
grep -q "history_weight" "$f" || { echo "FAIL: missing history_weight documentation"; exit 1; }
grep -q "budget_ceiling_usd" "$f" || { echo "FAIL: missing budget_ceiling_usd documentation"; exit 1; }
echo "PASS: file-formats.md documents routing.yaml"
```

**`scripts/verify/m006-p01-formats-checkpoint.sh`**
```bash
#!/usr/bin/env bash
# Verify references/file-formats.md documents engine-checkpoint.json format.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "checkpoint" "$f" || { echo "FAIL: missing checkpoint documentation"; exit 1; }
grep -q "engine-checkpoint.json" "$f" || { echo "FAIL: missing engine-checkpoint.json reference"; exit 1; }
grep -q "run_id" "$f" || { echo "FAIL: missing run_id field"; exit 1; }
grep -q "last_task" "$f" || { echo "FAIL: missing last_task field"; exit 1; }
grep -q "checkpoint_write" "$f" || { echo "FAIL: missing checkpoint_write reference"; exit 1; }
echo "PASS: file-formats.md documents engine-checkpoint.json"
```

**`scripts/verify/m006-p01-formats-doctor.sh`**
```bash
#!/usr/bin/env bash
# Verify references/file-formats.md documents doctor-history.jsonl format.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "doctor-history.jsonl" "$f" || { echo "FAIL: missing doctor-history.jsonl documentation"; exit 1; }
grep -q "checks_passed" "$f" || { echo "FAIL: missing checks_passed field"; exit 1; }
grep -q "checks_total" "$f" || { echo "FAIL: missing checks_total field"; exit 1; }
grep -q "advisory_warnings" "$f" || { echo "FAIL: missing advisory_warnings field"; exit 1; }
echo "PASS: file-formats.md documents doctor-history.jsonl"
```

### Step 3 — Create the path existence verification script

**`scripts/verify/m006-p01-paths-exist.sh`**
```bash
#!/usr/bin/env bash
# Verify every file/directory path mentioned in references/architecture.md exists.
# Extracts paths matching scripts/, commands/, templates/, references/ patterns
# and checks each one exists on disk.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

failures=0
# Extract paths that look like project file/directory references
# Match patterns like scripts/engine/run.sh, commands/auto.md, etc.
paths=$(grep -oE '(scripts|commands|templates|references)/[a-zA-Z0-9_./-]+\.(sh|md|yml|yaml|json|jsonl)' "$f" | sort -u)

for path in $paths; do
  if [ ! -e "$path" ]; then
    echo "FAIL: path mentioned in architecture.md does not exist: $path"
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "FAIL: $failures path(s) referenced in architecture.md do not exist"
  exit 1
fi
echo "PASS: all file paths in architecture.md exist on disk"
```

### Step 4 — Make all scripts executable

Run `chmod +x scripts/verify/m006-p01-*.sh` on all 12 scripts.

### Step 5 — Run full verification

Execute every verification script. All must exit 0:

```bash
bash scripts/verify/m006-p01-arch-header.sh
bash scripts/verify/m006-p01-arch-pipeline.sh
bash scripts/verify/m006-p01-arch-dataflow.sh
bash scripts/verify/m006-p01-arch-layout.sh
bash scripts/verify/m006-p01-arch-subsystems.sh
bash scripts/verify/m006-p01-arch-crosslinks.sh
bash scripts/verify/m006-p01-formats-recipe.sh
bash scripts/verify/m006-p01-formats-hooks.sh
bash scripts/verify/m006-p01-formats-routing.sh
bash scripts/verify/m006-p01-formats-checkpoint.sh
bash scripts/verify/m006-p01-formats-doctor.sh
bash scripts/verify/m006-p01-paths-exist.sh
```

If any fail, investigate whether the issue is in the verification script
or the documentation artifact, and fix accordingly.

### Step 6 — Run phase-level verification

Run the phase-level must-haves check:

```bash
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M006/phases/P01
```

All Truth and Artifact checks should pass.

## Must-Haves

- [ ] All 12 verification scripts exist at `scripts/verify/m006-p01-*.sh`
- [ ] All scripts are executable (`chmod +x`)
- [ ] All scripts exit 0 when run against the completed T01/T02 artifacts
- [ ] `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M006/phases/P01` passes all checks

## Verification

Run each script individually and confirm exit 0 with PASS output. Then run
`check-must-haves.sh` against the phase directory.

## Inputs

### From Previous Tasks

- T01: `references/architecture.md` (the file this task's first 6 scripts verify)
- T02: Updated `references/file-formats.md` (the file this task's last 5 scripts verify)

### From Disk (Pre-existing)

- `scripts/verify/check-must-haves.sh` — phase-level verification runner
- P01-PLAN.md Truths section — defines which patterns each script must check

## Constraints

- **AD-19**: Each verification script must be a single-file invocation. No
  inline compound bash, no subshells, no pipes in the `Check:` command.
- **DC-6**: Bash 3.2 / POSIX compatibility. Use `[ ]` or `[[ ]]` (both
  available in Bash 3.2). No `declare -A`, no `${var,,}`.
- Scripts must be idempotent — running them multiple times produces the
  same result.

## Expected Output

After completing this task:

1. 12 verification scripts exist at `scripts/verify/m006-p01-*.sh`.
2. All are executable.
3. All exit 0 when the T01 and T02 artifacts are in place.
4. `check-must-haves.sh` against P01 shows all PASS results.
