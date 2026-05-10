---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M005"
name: "Update dispatch-prompt.md and task-plan.md to conform to schema"
depends_on: ["T01"]
---

## Description

Update two existing templates — `templates/dispatch-prompt.md` and
`templates/task-plan.md` — to conform to the instruction schema defined in
`templates/instruction-schema.md`. This is the progressive migration start
required by the P04 boundary map.

The migration is structural, not content-destructive. Existing section
headings that already match a required section alias are left in place.
Missing required section headings are added as empty sections or comment
placeholders. The goal is to bring each template to a state where
`check-instructions.sh --target <file>` reports `status=ok` (all required
section groups satisfied).

### Migration Strategy

Both templates already have substantial content. The migration adds or
renames headings to satisfy the schema, without removing existing content.

**`templates/dispatch-prompt.md`** current headings:
- `## State Context` (satisfies Context group)
- `## Scope` (satisfies Task group)
- `## Upstream Context`
- `## Knowledge`
- `## Decisions`
- `## Task Plan`
- `## Constraints` (satisfies Constraints group)
- `## Payload Size Guidance`

Missing required groups:
- **Verification** — add `## Verification` section with a placeholder
  noting that verification criteria are embedded in the task plan and
  phase must-haves.
- **Output Format** — the `## Payload Size Guidance` heading satisfies
  the Output Format group alias, so this is already covered. But to be
  explicit, add `## Output Format` as a comment alias note near the
  Payload Size Guidance section.

**`templates/task-plan.md`** current headings:
- `## Description` (partial Task group match — need to add alias)
- `## Steps`
- `## Must-Haves` (satisfies Verification group)
- `## Verification` (satisfies Verification group)
- `## Inputs`
- `## Expected Output` (satisfies Output Format group)

Missing required groups:
- **Context** — the `## Inputs` section serves as context but is not a
  recognized alias. Add a `## Context` comment-alias note at the top of
  the Inputs section, or rename/add `## Context` as a visible section.
- **Constraints** — add `## Constraints` section with a placeholder for
  task-specific constraints and a reference to AD-19.

## Steps

### Step 1 — Update `templates/dispatch-prompt.md`

Add a `## Verification` section after the `## Constraints` section and
before `## Payload Size Guidance`. Content:

```markdown
## Verification

<!-- Verification criteria are embedded in the Task Plan section above
     and in the phase plan's Must-Haves. The dispatched agent should
     run all Check: commands from the task plan after completing work. -->

{{verification_criteria}}
```

This ensures the dispatch-prompt.md satisfies all 5 required section groups:
- Context -> `## State Context`
- Task -> `## Scope` and `## Task Plan`
- Constraints -> `## Constraints`
- Verification -> `## Verification` (new)
- Output Format -> `## Payload Size Guidance`

### Step 2 — Update `templates/task-plan.md`

Make two additions:

**Add `## Context` section** — Insert a `## Context` section before the
existing `## Description` section. This consolidates the context information
that the agent needs before reading the task steps.

```markdown
## Context

<!-- Phase goal, architectural constraints, and state prerequisites.
     This section is filled by the phase planner to give the executing
     agent orientation before reading the task steps. -->

{{context}}
```

**Add `## Constraints` section** — Insert a `## Constraints` section
after `## Must-Haves` and before `## Verification`. Content:

```markdown
## Constraints

<!-- Task-specific constraints beyond the phase-level must-haves.
     Includes AD-19 verification shape requirements, Bash 3.2
     compatibility, and any scope boundaries. -->

{{constraints}}
```

After these additions, task-plan.md satisfies all 5 required groups:
- Context -> `## Context` (new)
- Task -> `## Description` and `## Steps`
- Constraints -> `## Constraints` (new)
- Verification -> `## Verification` and `## Must-Haves`
- Output Format -> `## Expected Output`

### Step 3 — Smoke test conformance

Run the conformance check against both updated templates:

```bash
bash scripts/diagnostics/check-instructions.sh --root . --target templates/dispatch-prompt.md
bash scripts/diagnostics/check-instructions.sh --root . --target templates/task-plan.md
```

Both should report `status=ok` (or at worst `status=warn` with 0 missing
required sections).

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "At least 2 existing templates in `templates/` are updated to
  include conforming section headings as documented in the schema."
- **Artifacts**: `templates/dispatch-prompt.md` (modify, progressive migration),
  `templates/task-plan.md` (modify, progressive migration).

## Verification

Run the verification script:

```bash
bash scripts/verify/p04-template-migration.sh
```

Should print PASS. This script checks that both templates contain at least
3 required section heading aliases each.

### Files Touched By This Task

- `templates/dispatch-prompt.md` (modify)
- `templates/task-plan.md` (modify)

## Inputs

### From Previous Tasks

- T01: `templates/instruction-schema.md` must exist. Defines the required
  section headings and their aliases that the migration targets.
- T01: `scripts/diagnostics/check-instructions.sh` must exist. Used for
  smoke testing the migration.

### From Disk (Pre-existing)

- `templates/dispatch-prompt.md` — current dispatch prompt template. Has
  YAML frontmatter + 7 sections. Key sections relevant to migration:
  - `## State Context` (line 7) — satisfies Context group
  - `## Scope` (line 15) — satisfies Task group
  - `## Task Plan` (line 39) — additional Task group alias
  - `## Constraints` (line 47) — satisfies Constraints group
  - `## Payload Size Guidance` (line 53) — satisfies Output Format group
  - Missing: Verification group (no `## Verification` heading)

- `templates/task-plan.md` — current task plan template. Has YAML
  frontmatter + 6 sections. Key sections relevant to migration:
  - `## Description` (line 12) — partial Task match
  - `## Steps` (line 16) — partial Task match
  - `## Must-Haves` (line 20) — satisfies Verification group
  - `## Verification` (line 22) — satisfies Verification group
  - `## Expected Output` (line 58) — satisfies Output Format group
  - Missing: Context group (no `## Context` heading), Constraints group
    (no `## Constraints` heading)

## Expected Output

After completing this task:

1. `templates/dispatch-prompt.md` has a new `## Verification` section.
   All 5 required section groups have at least one alias present.
2. `templates/task-plan.md` has new `## Context` and `## Constraints`
   sections. All 5 required section groups have at least one alias present.
3. `bash scripts/verify/p04-template-migration.sh` prints PASS.
4. `bash scripts/diagnostics/check-instructions.sh --root . --target templates/dispatch-prompt.md`
   reports `status=ok`.
5. `bash scripts/diagnostics/check-instructions.sh --root . --target templates/task-plan.md`
   reports `status=ok`.
6. No existing content in either template is removed or rewritten.
7. `git status` shows 2 modified files. Nothing else touched.
