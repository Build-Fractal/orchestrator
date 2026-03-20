---
schema_version: "1.0"
type: spec-compliance-review
milestone: "{{milestone_id}}"
phase: "{{phase_id}}"
spec_path: "{{spec_path}}"
reviewed_at: "{{reviewed_at}}"
overall_compliance: "{{overall_compliance}}"
---

## Spec Requirements Reviewed

{{spec_requirements_list}}

## Compliance Assessment

### Fully Implemented

| # | Requirement | Evidence | Verified By |
|---|-------------|----------|-------------|
| {{impl_row_num}} | {{impl_requirement}} | {{impl_evidence}} | {{impl_verified_by}} |

### Partially Implemented

| # | Requirement | What's Done | What's Missing | Blocking? |
|---|-------------|-------------|----------------|-----------|
| {{partial_row_num}} | {{partial_requirement}} | {{partial_done}} | {{partial_missing}} | {{partial_blocking}} |

### Not Implemented

| # | Requirement | Reason | Planned Phase |
|---|-------------|--------|---------------|
| {{notimpl_row_num}} | {{notimpl_requirement}} | {{notimpl_reason}} | {{notimpl_planned_phase}} |

## Deviations from Spec

{{deviations_from_spec}}

## Recommendations

{{recommendations}}
