---
schema_version: "1.0"
type: task-plan
id: "T-no-scope"
parent: "P-fixture"
milestone: "M-fixture"
scope_tags: [project]
---

# T-no-scope — synthetic SC-7 baseline fixture task plan

## Goal

Trigger the CON-1 / SC-7 byte-identical pre-feature payload path. This
plan declares NO topic_tags and NO applies_to_field, so handle_reference
returns empty stdout, the omit-empty-section gate drops the section, and
the payload should be byte-identical to the pre-feature baseline.

## Verification

`bash scripts/dispatch/build-context.sh` (driven by SC-7 golden harness).
