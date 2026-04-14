---
schema_version: "1.0"
type: intensity-metadata
intensity: "{{intensity}}"
scope: "{{scope}}"
risk_level: "{{risk_level}}"
complexity: "{{complexity}}"
confidence: "{{confidence}}"
reasoning: "{{reasoning}}"
overridden_by: "{{overridden_by}}"
original_intensity: "{{original_intensity}}"
capabilities_used:
  - "{{capability}}"
evaluated_at: "{{evaluated_at}}"
---

## Intensity Metadata

**Recommended intensity**: {{intensity}}
**Confidence**: {{confidence}}

### Analysis

- **Scope**: {{scope}} -- {{scope_explanation}}
- **Risk**: {{risk_level}} -- {{risk_explanation}}
- **Complexity**: {{complexity}} -- {{complexity_explanation}}

### Risk Signals

{{risk_signals_list}}

### Capabilities Used

{{capabilities_list}}

### Override History

{{override_history}}
