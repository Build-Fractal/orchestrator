---
schema_version: "1.0"
type: gate-result
preset: "{{preset}}"
artifact: "{{artifact_path}}"
verdict: "{{PASS|BLOCK}}"
timestamp: "{{iso_8601}}"
source_hash: "{{hash}}"
---

# Gate Result: {{preset}}

## Verdict

{{verdict}}

## Disputes

{{#disputes}}
- **{{agent}}**: {{dispute_text}}
{{/disputes}}

## Rationale

{{rationale}}
