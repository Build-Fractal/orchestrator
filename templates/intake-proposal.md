---
schema_version: "1.0"
type: intake-proposal
feature_slug: "{{feature_slug}}"
intake_id: "{{intake_id}}"
milestone: "{{milestone}}"
status: "{{status}}"
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
pending_design_authored_manually: {{pending_design_authored_manually}}
qa_short_circuited: {{qa_short_circuited}}
low_confidence: {{low_confidence}}
---

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