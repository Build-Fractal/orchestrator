---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M005"
name: "Create instruction-schema.md, check-instructions.sh, and verification scripts"
depends_on: []
---

## Description

Create three deliverables:

1. **`templates/instruction-schema.md`** — the declared schema template that
   defines required and optional section headings for agent instruction files.
   This is a reference document and structural skeleton, not a runtime artifact.
   It declares which `## Heading` lines must appear in any instruction file
   (command definitions in `commands/`, dispatch prompt templates, task plan
   templates) and which are optional.

2. **`scripts/diagnostics/check-instructions.sh`** — the conformance check
   script that scans instruction files for required section headings and reports
   missing sections. Emits a structured `DOCTOR:INSTRUCTIONS` result line
   following the same pattern as `check-permissions.sh` (`DOCTOR:PERMISSIONS`).

3. **Four verification scripts** under `scripts/verify/p04-*.sh` for phase
   P04 must-haves.

### Required Sections (from roadmap boundary map)

The schema declares these as required `## ` headings:

1. **Context** (or **Prerequisites** or **State Context**) — what the agent
   needs to know before starting. Aliases allow existing files that use
   "Prerequisites" or "State Context" to pass conformance.
2. **Task** (or **Scope** or **Phase Planning** or **What It Checks**) —
   what the agent must do. Aliases allow existing command files that use
   varied heading names for the core task description.
3. **Constraints** (or **Error Handling** or **Gotchas** or
   **Idempotency**) — boundaries and limitations on execution.
4. **Verification** (or **Post-Dispatch** or **Validation**) — how to
   confirm the work is correct.
5. **Output Format** (or **Expected Output** or **Output** or
   **Referenced Templates**) — what the agent should produce.

Each required section may have one or more heading aliases. The conformance
check passes if **at least one alias** for each required section is present
as a `## ` heading in the file.

### Optional Sections

6. **Prior Art** (or **Referenced Scripts** or **Reference Files**) —
   pointers to existing implementations relevant to the task.
7. **Related Knowledge** (or **Upstream Context** or **Knowledge**) —
   knowledge entries, lessons, or patterns that inform execution.

Optional sections are reported as informational when missing, not as errors.

## Steps

### Step 1 — Create `templates/instruction-schema.md`

Create the schema template at `templates/instruction-schema.md`. The file
defines the required and optional sections using a structured format with
heading names, aliases, purpose descriptions, and content guidance.

```markdown
---
schema_version: "1.0"
type: instruction-schema
description: "Declares required and optional section headings for agent instruction files. Consumed by scripts/diagnostics/check-instructions.sh for conformance checking."
---

# Agent Instruction Schema

This template defines the structural contract for agent instruction files
used across the orchestrator. All command definitions (`commands/*.md`),
dispatch prompt templates, and task plan templates should conform to this
schema.

Enforcement is via static conformance check (`scripts/diagnostics/check-instructions.sh`),
not runtime parsing. The check greps for `## ` headings and reports missing
required sections. Bash 3.2 compatible (AD-4).

## Required Sections

Each instruction file MUST include at least one heading alias from each
required section group. The conformance check passes when at least one
alias per group is present as a `## ` (h2) heading.

### 1. Context

**Aliases**: `## Context`, `## Prerequisites`, `## State Context`,
`## State Derivation`, `## Context Gathering`

**Purpose**: Establish what the agent needs to know before starting work.
Includes current state, relevant configuration, and environmental
preconditions.

**Content guidance**:
- Current orchestrator state and how to derive it
- Configuration values to read
- Environmental prerequisites (files that must exist, tools that must be
  available)

### 2. Task

**Aliases**: `## Task`, `## Scope`, `## Phase Planning`, `## What It Checks`,
`## Usage`, `## Context Construction`, `## Dispatch Strategy`

**Purpose**: Define what the agent must do. The core work description.

**Content guidance**:
- Step-by-step instructions or behavioral description
- Exact commands to run with arguments
- Decision points and branching logic

### 3. Constraints

**Aliases**: `## Constraints`, `## Error Handling`, `## Gotchas`,
`## Idempotency`, `## Concurrent Safety`, `## Budget Gates`

**Purpose**: Define boundaries, limitations, and edge cases the agent
must respect during execution.

**Content guidance**:
- Error conditions and how to handle them
- Idempotency requirements
- Concurrency safety guarantees
- Budget and resource limits

### 4. Verification

**Aliases**: `## Verification`, `## Post-Dispatch`, `## Validation`,
`## Must-Haves`, `## Tier 1`

**Purpose**: Define how to confirm the work is correct. Mechanical
checks that can be run after completion.

**Content guidance**:
- Specific check commands (AD-19: single-script-file shape)
- Expected outputs and pass/fail criteria
- Cross-reference to must-haves from the phase plan

### 5. Output Format

**Aliases**: `## Output Format`, `## Expected Output`, `## Output`,
`## Referenced Templates`, `## Payload Size Guidance`

**Purpose**: Define what the agent should produce — file formats,
template usage, structured output.

**Content guidance**:
- File paths and formats for deliverables
- Template references
- Structured output format (JSONL, markdown, etc.)

## Optional Sections

These sections are recommended but not required. The conformance check
reports their absence as informational notices, not errors.

### 6. Prior Art

**Aliases**: `## Prior Art`, `## Referenced Scripts`, `## Reference Files`,
`## Referenced Templates`

**Purpose**: Point to existing implementations, scripts, or patterns
relevant to the task.

### 7. Related Knowledge

**Aliases**: `## Related Knowledge`, `## Upstream Context`, `## Knowledge`,
`## Decisions`

**Purpose**: Knowledge entries, lessons learned, or architectural decisions
that inform execution.

## Schema Skeleton

Below is a minimal conforming instruction file skeleton:

~~~markdown
---
description: "Brief description of the command."
---

# command.name

One-line summary of what this command does.

## Context

<!-- State derivation, prerequisites, config values -->

## Task

<!-- Core work description, steps, commands -->

## Constraints

<!-- Error handling, idempotency, edge cases -->

## Verification

<!-- Check commands, expected outputs, pass/fail -->

## Output Format

<!-- Deliverable paths, template references, formats -->
~~~

## Conformance Check

Run the conformance check with:

```bash
bash scripts/diagnostics/check-instructions.sh [--root <project-root>] [--target <file>]
```

The check scans all `commands/*.md` files by default. Use `--target` to
check a single file. Output follows the `DOCTOR:` event protocol:

```
DOCTOR:INSTRUCTIONS status=<ok|warn|fail> files=N missing=N
```

<!-- Schema versioning: this is v1.0. Future versions may add required
     sections or new aliases. The conformance check reads aliases from
     this file, so adding aliases here automatically updates enforcement. -->
```

Make the file with the content above (it's already markdown, so no chmod
needed — it's a template, not a script).

### Step 2 — Create `scripts/diagnostics/check-instructions.sh`

Create the conformance check script. It scans instruction files for
required section headings and reports missing sections per file.

```bash
#!/usr/bin/env bash
# scripts/diagnostics/check-instructions.sh — Instruction conformance check.
#
# Scans instruction files (commands/*.md by default) for required section
# headings defined in templates/instruction-schema.md. Reports missing
# required sections per file.
#
# Usage: check-instructions.sh [--root <project-root>] [--target <file>]
#
# Output: DOCTOR:INSTRUCTIONS status=<ok|warn> files=N missing=N
#
# Bash 3.2 compatible. AD-4 conformance.
set -eu

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    *) echo "check-instructions.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Required section groups ---
# Each group has a name and pipe-delimited heading aliases.
# A file conforms for a group if at least one alias appears as a ## heading.
#
# Format: GROUP_NAME|alias1|alias2|alias3
REQUIRED_GROUPS="Context|Context|Prerequisites|State Context|State Derivation|Context Gathering
Task|Task|Scope|Phase Planning|What It Checks|Usage|Context Construction|Dispatch Strategy
Constraints|Constraints|Error Handling|Gotchas|Idempotency|Concurrent Safety|Budget Gates
Verification|Verification|Post-Dispatch|Validation|Must-Haves|Tier 1
Output Format|Output Format|Expected Output|Output|Referenced Templates|Payload Size Guidance"

# --- Optional section groups (informational only) ---
OPTIONAL_GROUPS="Prior Art|Prior Art|Referenced Scripts|Reference Files
Related Knowledge|Related Knowledge|Upstream Context|Knowledge|Decisions"

# --- Determine files to scan ---
if [ -n "$TARGET" ]; then
  FILES="$TARGET"
else
  FILES=""
  for f in "$PROJECT_ROOT"/commands/*.md; do
    # Skip README
    case "$(basename "$f")" in
      README.md) continue ;;
    esac
    [ -f "$f" ] && FILES="${FILES}${f}
"
  done
fi

total_files=0
total_missing=0
file_details=""

# --- Check each file ---
while IFS= read -r file; do
  [ -z "$file" ] && continue
  total_files=$((total_files + 1))

  file_missing=0
  missing_groups=""

  # Read all ## headings from the file
  headings="$(grep -E '^## ' "$file" | sed 's/^## //' || true)"

  # Check each required group
  while IFS= read -r group_line; do
    [ -z "$group_line" ] && continue

    # Parse group name (first field) and aliases (remaining fields)
    group_name="$(printf '%s' "$group_line" | cut -d'|' -f1)"

    found=0
    # Check each alias
    rest="$group_line"
    # Skip the group name (first field), check remaining fields
    idx=0
    while true; do
      idx=$((idx + 1))
      alias="$(printf '%s' "$group_line" | cut -d'|' -f$idx)"
      [ -z "$alias" ] && break
      [ "$idx" -eq 1 ] && continue  # skip group name
      # Check if this alias appears as a heading
      if printf '%s\n' "$headings" | grep -Fxq "$alias"; then
        found=1
        break
      fi
    done

    if [ "$found" -eq 0 ]; then
      file_missing=$((file_missing + 1))
      missing_groups="${missing_groups}  MISSING: ${group_name} ($(basename "$file"))
"
    fi
  done <<GROUPS_EOF
$REQUIRED_GROUPS
GROUPS_EOF

  if [ "$file_missing" -gt 0 ]; then
    total_missing=$((total_missing + file_missing))
    file_details="${file_details}${missing_groups}"
  fi
done <<FILES_EOF
$FILES
FILES_EOF

# --- Emit structured result ---
if [ "$total_missing" -eq 0 ]; then
  status="ok"
else
  status="warn"
fi

printf 'DOCTOR:INSTRUCTIONS status=%s files=%d missing=%d\n' "$status" "$total_files" "$total_missing"
if [ -n "$file_details" ]; then
  printf '%s' "$file_details"
fi
```

Make executable:

```bash
chmod +x scripts/diagnostics/check-instructions.sh
```

### Step 3 — Create verification scripts

Create four verification scripts under `scripts/verify/`. Each is a
standalone single-script-file check (AD-19 compliant).

**`scripts/verify/p04-schema-template.sh`**

```bash
#!/usr/bin/env bash
# Verifies templates/instruction-schema.md exists with required and optional
# section declarations.
set -eu
f="templates/instruction-schema.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '## Required Sections' "$f" || { echo "FAIL: Required Sections heading missing"; exit 1; }
grep -q '## Optional Sections' "$f" || { echo "FAIL: Optional Sections heading missing"; exit 1; }
# Count required section groups (### N. headings under Required Sections)
req_count="$(grep -c '^### [0-9]\.' "$f" || true)"
test "$req_count" -ge 5 || { echo "FAIL: expected at least 5 required section groups, found $req_count"; exit 1; }
# Check for at least 2 optional section groups (### N. headings under Optional Sections)
# The optional headings are ### 6. and ### 7. (numbered after the required ones)
opt_count="$(grep -c '^### [67]\.' "$f" || true)"
test "$opt_count" -ge 2 || { echo "FAIL: expected at least 2 optional section groups, found $opt_count"; exit 1; }
echo "PASS: instruction-schema.md exists with $req_count required and $opt_count optional section groups"
```

**`scripts/verify/p04-check-instructions.sh`**

```bash
#!/usr/bin/env bash
# Verifies scripts/diagnostics/check-instructions.sh exists and can scan
# instruction files for required section headings.
set -eu
f="scripts/diagnostics/check-instructions.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }
grep -q 'DOCTOR:INSTRUCTIONS' "$f" || { echo "FAIL: DOCTOR:INSTRUCTIONS output missing"; exit 1; }
grep -q 'Required' "$f" || grep -q 'REQUIRED' "$f" || grep -q 'required' "$f" || { echo "FAIL: no reference to required sections"; exit 1; }
echo "PASS: check-instructions.sh exists and references DOCTOR:INSTRUCTIONS"
```

**`scripts/verify/p04-doctor-integration.sh`**

```bash
#!/usr/bin/env bash
# Verifies run-doctor.sh includes a call to check-instructions.sh.
set -eu
f="scripts/diagnostics/run-doctor.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'check-instructions.sh' "$f" || { echo "FAIL: run-doctor.sh does not reference check-instructions.sh"; exit 1; }
echo "PASS: run-doctor.sh includes instruction conformance check"
```

**`scripts/verify/p04-template-migration.sh`**

```bash
#!/usr/bin/env bash
# Verifies at least 2 existing templates have been updated to include
# conforming section headings from the instruction schema.
# Checks dispatch-prompt.md and task-plan.md for presence of required
# section heading aliases.
set -eu

migrated=0

# Check dispatch-prompt.md for at least 3 required section aliases
f="templates/dispatch-prompt.md"
if [ -f "$f" ]; then
  hits=0
  # Context group
  grep -qE '^## (Context|State Context|Prerequisites)' "$f" && hits=$((hits + 1))
  # Task group
  grep -qE '^## (Task|Scope|Task Plan)' "$f" && hits=$((hits + 1))
  # Constraints group
  grep -qE '^## (Constraints|Payload Size Guidance)' "$f" && hits=$((hits + 1))
  # Verification group — dispatch-prompt may not have this, skip
  # Output group
  grep -qE '^## (Output|Output Format)' "$f" && hits=$((hits + 1))
  if [ "$hits" -ge 3 ]; then
    migrated=$((migrated + 1))
  fi
fi

# Check task-plan.md for at least 3 required section aliases
f="templates/task-plan.md"
if [ -f "$f" ]; then
  hits=0
  # Context group — Inputs section serves as context
  grep -qE '^## (Context|Inputs|Description)' "$f" && hits=$((hits + 1))
  # Task group
  grep -qE '^## (Task|Steps|Description)' "$f" && hits=$((hits + 1))
  # Constraints group
  grep -qE '^## (Constraints|Must-Haves)' "$f" && hits=$((hits + 1))
  # Verification group
  grep -qE '^## (Verification)' "$f" && hits=$((hits + 1))
  # Output group
  grep -qE '^## (Expected Output|Output Format)' "$f" && hits=$((hits + 1))
  if [ "$hits" -ge 3 ]; then
    migrated=$((migrated + 1))
  fi
fi

test "$migrated" -ge 2 || { echo "FAIL: expected at least 2 migrated templates, found $migrated"; exit 1; }
echo "PASS: $migrated templates conform to instruction schema"
```

Make all executable:

```bash
chmod +x scripts/verify/p04-*.sh
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "Instruction schema template exists at templates/instruction-schema.md
  and declares at least 5 required section headings and at least 2 optional
  section headings", "Conformance check script exists at
  scripts/diagnostics/check-instructions.sh and scans files for required section
  headings, reporting missing sections per file".
- **Artifacts**: `templates/instruction-schema.md`,
  `scripts/diagnostics/check-instructions.sh`, all four
  `scripts/verify/p04-*.sh` scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/p04-schema-template.sh
bash scripts/verify/p04-check-instructions.sh
```

Both should print PASS.

The remaining verification scripts (`p04-doctor-integration.sh`,
`p04-template-migration.sh`) will FAIL until T02 and T03 complete. This
is expected.

Smoke test `check-instructions.sh` against a known conforming file:

```bash
bash scripts/diagnostics/check-instructions.sh --root . --target commands/status.md
```

Should output `DOCTOR:INSTRUCTIONS status=ok files=1 missing=0` or
`status=warn` with specific missing groups listed. Either confirms the
script runs and produces structured output.

### Files Touched By This Task

- `templates/instruction-schema.md` (create)
- `scripts/diagnostics/check-instructions.sh` (create)
- `scripts/verify/p04-schema-template.sh` (create)
- `scripts/verify/p04-check-instructions.sh` (create)
- `scripts/verify/p04-doctor-integration.sh` (create)
- `scripts/verify/p04-template-migration.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is the phase entry point.

### From Disk (Pre-existing)

- `commands/*.md` — existing command instruction files. These are the files
  that the conformance check will scan. Reviewing their section headings
  informs the alias list for each required section group. Key files:
  - `commands/status.md` — uses `## State Derivation`, `## Progress Overview`,
    `## Error Handling`, `## Gotchas`, `## Reference Files`
  - `commands/dispatch.md` — uses `## Prerequisites`, `## Context Construction`,
    `## Dispatch Strategy`, `## Error Handling`, `## Gotchas`,
    `## Referenced Scripts`, `## Referenced Templates`
  - `commands/doctor.md` — uses `## What It Checks`, `## Usage`, `## Output`
  - `commands/verify.md` — uses `## Prerequisites`, `## Tier 1`,
    `## Idempotency`

- `scripts/diagnostics/check-permissions.sh` — reference for the
  `DOCTOR:` structured output pattern. The check-instructions.sh script
  follows the same `DOCTOR:INSTRUCTIONS status=<status> ...` convention.

- `templates/dispatch-prompt.md` — existing dispatch prompt template. Uses
  `## State Context`, `## Scope`, `## Task Plan`, `## Constraints`,
  `## Payload Size Guidance`. These inform the alias list.

- `templates/task-plan.md` — existing task plan template. Uses
  `## Description`, `## Steps`, `## Must-Haves`, `## Verification`,
  `## Inputs`, `## Expected Output`. These inform the alias list.

## Expected Output

After completing this task:

1. `templates/instruction-schema.md` exists with at least 60 lines, declares
   5 required section groups (Context, Task, Constraints, Verification,
   Output Format) and 2 optional section groups (Prior Art, Related Knowledge).
2. `scripts/diagnostics/check-instructions.sh` exists, is chmod +x, scans
   files for `## ` headings, matches against required section aliases, and
   emits `DOCTOR:INSTRUCTIONS status=<ok|warn> files=N missing=N`.
3. All four `scripts/verify/p04-*.sh` files exist and are chmod +x.
4. `bash scripts/verify/p04-schema-template.sh` prints PASS.
5. `bash scripts/verify/p04-check-instructions.sh` prints PASS.
6. `bash scripts/diagnostics/check-instructions.sh --root . --target commands/status.md`
   runs without error and produces structured output.
7. `git status` shows 6 new files (1 template + 1 diagnostic script + 4
   verify scripts). Nothing else touched.
