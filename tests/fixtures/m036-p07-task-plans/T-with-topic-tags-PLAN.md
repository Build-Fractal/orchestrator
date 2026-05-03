---
schema_version: "1.0"
type: task-plan
id: "T-with-topic-tags"
parent: "P-fixture"
milestone: "M-fixture"
topic_tags: [pbj-staffing]
reference_token_budget: 4000
---

# T-with-topic-tags — synthetic SC-3 fixture task plan

## Goal

Drive build-context.sh's reference-injection path. The matched corpus is
the M036/P04 reference fixture corpus at
`tests/fixtures/m036-p04-reference-corpus/` whose REF-* chunks carry
`topic_tags: [pbj-staffing, ...]`.

## Verification

`bash scripts/dispatch/build-context.sh` (driven by SC-3 harness).
