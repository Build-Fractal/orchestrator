---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M024"
name: "Author the 6-axis proposal template"
depends_on: []
---

## Prerequisites

None. This is the first task in P01 and depends only on a clean checkout of `orchestrator` at the project root. Working directory is the project root (`/Users/brettkellgren/Sites/orchestrator` or whatever the current checkout is — never hardcode the path).

The project's existing template directory is `templates/`. List it with `ls templates/` to confirm conventions before writing — frontmatter blocks open `---` on line 1, `schema_version: "1.0"` is the canonical first key.

## Description

Author `templates/intake-proposal.md` — a markdown template defining the 6-axis proposal artifact's exact frontmatter contract and body skeleton. This template is the forward-binding schema source for every other M024 phase (P02–P07 all conform to it; P01/T04's emitter renders it).

The template uses `{{placeholder}}` syntax for runtime-substituted values. It has no shell logic of its own — it is a static artifact rendered by `scripts/intake/proposal-emit.sh` (T04) via simple `sed` substitution.

The frontmatter key set is the FR-15 / DC-5 strict-superset seed: every key in the [M014](../../../../milestones/M014/index.md) interim manifest must appear here, plus the six routing axes. The exact key list is pinned by this task and must not be reordered, renamed, or added-to in later phases without a Decision row.

## Steps

1. **Create the file** at `templates/intake-proposal.md`.

2. **Write the frontmatter block** with exactly these keys, in this order:

```yaml
---
schema_version: "1.0"
type: intake-proposal
intake_id: "{{intake_id}}"
created_at: "{{created_at}}"
input_shape: "{{input_shape}}"
input_hash: "{{input_hash}}"
shape_classification: "{{shape_classification}}"
supplemental_input: {{supplemental_input}}
scope_tier: "{{scope_tier}}"
decomposition: "{{decomposition}}"
design_gate: "{{design_gate}}"
conversus_gate: "{{conversus_gate}}"
intensity: "{{intensity}}"
recommended_command: "{{recommended_command}}"
auto_proceeded: {{auto_proceeded}}
proceeded_at: {{proceeded_at}}
approved_at: {{approved_at}}
cancelled_at: {{cancelled_at}}
pending_approval: {{pending_approval}}
design_skipped: {{design_skipped}}
design_authored_manually: {{design_authored_manually}}
qa_short_circuited: {{qa_short_circuited}}
low_confidence: {{low_confidence}}
---
```

3. **Write the body skeleton** with these section headings, in this order:

```markdown
# Intake Proposal: {{intake_id}}

**Input shape**: {{input_shape}} (confidence: {{shape_classification}})

## Original Input

{{input_body}}

## Routing Axes

### Axis 1 — Input Shape

**Value**: `{{input_shape}}`

**Rationale**: {{rationale_input_shape}}

**Evidence**: {{evidence_input_shape}}

### Axis 2 — Scope Tier

**Value**: `{{scope_tier}}`

**Rationale**: {{rationale_scope_tier}}

**Evidence**: {{evidence_scope_tier}}

### Axis 3 — Decomposition

**Value**: `{{decomposition}}` → `{{recommended_command}}`

**Rationale**: {{rationale_decomposition}}

**Evidence**: {{evidence_decomposition}}

### Axis 4 — Design Gate

**Value**: `{{design_gate}}`

**Rationale**: {{rationale_design_gate}}

**Evidence**: {{evidence_design_gate}}

### Axis 5 — Conversus Gate

**Value**: `{{conversus_gate}}`

**Rationale**: {{rationale_conversus_gate}}

**Evidence**: {{evidence_conversus_gate}}

### Axis 6 — Intensity

**Value**: `{{intensity}}`

**Rationale**: {{rationale_intensity}}

**Evidence**: {{evidence_intensity}}

## Approval

- `approve` — proceed with `{{recommended_command}}`
- `revise <axis>=<value>` — override an axis and re-emit
- `cancel` — record cancellation; no further state changes

{{approval_status}}
```

4. **Save the file**. Do not add a trailing blank line — the template is rendered verbatim by T04.

5. **Verify** by writing the verify script `scripts/verify/m024-p01-template-frontmatter.sh` (single-script-file shape per AD-19):

```bash
#!/usr/bin/env bash
# scripts/verify/m024-p01-template-frontmatter.sh
# Asserts templates/intake-proposal.md exists and contains every required frontmatter key + axis section heading.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$ROOT/templates/intake-proposal.md"

if [ ! -f "$TEMPLATE" ]; then
  echo "FAIL: $TEMPLATE not found"
  exit 1
fi

REQUIRED_KEYS="schema_version type intake_id created_at input_shape input_hash shape_classification supplemental_input scope_tier decomposition design_gate conversus_gate intensity recommended_command auto_proceeded proceeded_at approved_at cancelled_at pending_approval design_skipped design_authored_manually qa_short_circuited low_confidence"

missing=""
for key in $REQUIRED_KEYS; do
  if ! grep -q "^${key}:" "$TEMPLATE"; then
    missing="$missing $key"
  fi
done

REQUIRED_HEADINGS="Axis_1_—_Input_Shape Axis_2_—_Scope_Tier Axis_3_—_Decomposition Axis_4_—_Design_Gate Axis_5_—_Conversus_Gate Axis_6_—_Intensity"

for h in $REQUIRED_HEADINGS; do
  pretty=$(echo "$h" | tr '_' ' ')
  if ! grep -qF "$pretty" "$TEMPLATE"; then
    missing="$missing heading:$h"
  fi
done

if [ -n "$missing" ]; then
  echo "FAIL: missing in $TEMPLATE —$missing"
  exit 1
fi

echo "PASS: templates/intake-proposal.md frontmatter + axis sections complete"
exit 0
```

## Must-Haves

- Template file exists at `templates/intake-proposal.md`.
- Frontmatter contains every key in the order pinned in step 2.
- Body contains six `### Axis N — <name>` headings in the order pinned in step 3.
- `schema_version: "1.0"` — quoted string, AD-3 pin.
- Verify script `scripts/verify/m024-p01-template-frontmatter.sh` exits 0 against the file.

## Verification

```
bash scripts/verify/m024-p01-template-frontmatter.sh
```

Expected output (exit 0): `PASS: templates/intake-proposal.md frontmatter + axis sections complete`

## Inputs

### From Previous Tasks

None — T01 is the schema source.

### From Disk (Pre-existing)

- `templates/spec-template.md` — read-only reference for frontmatter style conventions (block opens with `---` on line 1, `schema_version: "1.0"` is canonical first key, key ordering convention).
- `templates/phase-plan.md` — another reference for `{{placeholder}}` substitution syntax.

## Constraints

- POSIX-only operations (file write, no shell logic in the template itself).
- The frontmatter key list is forward-binding for P02–P07. Any later phase that wants to add a key must ship a Decision row first; this task does not over-build.
- No `<TODO:` markers in the template (DC-3 / D019 universal TODO pre-flight). Placeholder syntax is `{{name}}`, not `<TODO: name>`.
- The body has no inline conversus invocations or knowledge writes (SB-3).
- ASCII-only except for the `—` em dash already used in axis headings (matches `commands/specify.md` and other docs).

## Expected Output

A single file at `templates/intake-proposal.md` containing 80+ lines, with the exact frontmatter from step 2 and the body skeleton from step 3.

`bash scripts/verify/m024-p01-template-frontmatter.sh` exits 0 with `PASS:` line.
