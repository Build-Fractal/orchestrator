---
schema_version: "1.0"
type: evaluation
milestone: "{{milestone_id}}"
feature_ref: "{{feature_ref}}"
feature_spec: "{{feature_spec_path}}"
tier: "{{tier}}"
tier_source: "{{tier_source}}"
created_at: "{{created_at}}"
---

# {{milestone_id}} Evaluation

## Classification

- **Tier**: {{tier}}
- **Source**: {{tier_source}}
- **Next command**: {{next_command}}

## Metrics

| Metric | Count |
|--------|-------|
| User stories | {{user_story_count}} |
| Acceptance scenarios | {{acceptance_scenario_count}} |
| Functional requirements | {{functional_requirement_count}} |
| Estimated SDD flows | {{sdd_flow_count}} |

## Reasoning

{{reasoning}}

## Complexity Factors

{{complexity_factors}}
