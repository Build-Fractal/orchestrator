---
schema_version: "1.0"
type: roadmap
milestone: "{{milestone_id}}"
feature_ref: "{{feature_ref}}"
feature_spec: "{{feature_spec}}"
vision: "{{vision}}"
tier: "{{tier}}"
created_at: "{{created_at}}"
updated_at: "{{updated_at}}"
---

## Phases

- [ ] **{{phase_id}}**: {{phase_title}} — "{{demo_sentence}}"
  - Risk: {{risk}}
  - Depends: {{depends}}
  - Boundary Map:
    - Produces: {{produces}}
    - Consumes: {{consumes}}

<!-- Repeat the phase block above for each phase in the milestone.
     Mark completed phases with [x] instead of [ ].
     Phases are ordered by dependency + risk (high-risk first among satisfied deps).
     Never modify completed phase entries — append new phases at the bottom. -->
