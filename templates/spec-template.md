---
schema_version: "1.0"
type: feature-spec
feature_slug: "{{feature_slug}}"
created_at: "{{created_at}}"
status: "Draft"
milestone: "{{milestone}}"
---

# Feature Specification: {{feature_title}}

**Feature Branch**: `{{feature_slug}}`
**Created**: {{created_at}}
**Status**: Draft
**Milestone**: {{milestone}}
**Input**: User description: "{{description}}"

## Problem Statement

<TODO: Describe the problem this feature solves in 2-4 paragraphs. Include: (a) the current-state gap in one sentence; (b) three concrete pain-points that follow from the gap; (c) the minimum surface that fixes all three; (d) what this feature explicitly does not attempt (scope discipline).>

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

<TODO: Name the smallest coherent subset of user stories whose shipment closes the dogfood loop. Every subsequent phase's scope is defended on top of this slice. See M014/spec.md:27-36 for a worked example.>

### User Story 1 — <TODO: short-title> (Priority: P1)

<TODO: One-paragraph user-facing scenario: who, what action, what outcome, why it matters.>

**Why this priority**: <TODO: Defend the priority ranking relative to the other user stories in this spec.>

**Independent Test**: <TODO: Describe the minimum test harness that verifies this story end-to-end without depending on any other story in this spec.>

**Acceptance Scenarios**:

1. **Given** <TODO: pre-condition>, **When** <TODO: action>, **Then** <TODO: observable outcome>.

---

## Edge Cases

- <TODO: Edge case 1 — describe an off-happy-path scenario and the defined behavior.>

---

## Functional Requirements

- **FR-1 (<TODO: short-name>)**: <TODO: Requirement prose. Cite the user story or success criterion it satisfies.>

## Success Criteria

- **SC-1**: <TODO: Mechanically-verifiable criterion — name the command, the expected exit code, and the observable artifact.>

## Non-Goals

- <TODO: Non-goal 1 — explicit scope boundary with one-sentence rationale.>

## Constraints

- **CON-1 (<TODO: short-name>)**: <TODO: Constraint prose.>

### Knowledge-Layer Boundary (<TODO: this-milestone> vs. <TODO: owning-knowledge-milestone>)

<TODO: Name the milestones on both sides of the boundary and the exact knowledge-tree write-sites this milestone claims vs. delegates.>

## Assumptions

- <TODO: Assumption 1 — a pre-condition that holds outside this milestone's scope.>

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle <TODO: roman-numeral>**: <TODO: How this spec honors the principle.>

## Open Questions (defer to planning)

- **#Q-1 <TODO: question-short-name>**: <TODO: Open question body + who answers it at plan-phase time.>

## Dependencies

- <TODO: Upstream dependency 1 — milestone or external tool the spec consumes.>

## Downstream Consumers (informational, not binding)

- <TODO: Downstream consumer 1 — future milestone or surface that consumes this spec's output.>
