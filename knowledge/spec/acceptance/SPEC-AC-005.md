---
id: SPEC-AC-005
scope_tags: "[project]"
category: spec/acceptance
confidence: 0.90
created_at: 2026-04-17
last_verified: 2026-04-17
hit_count: 0
source_unit: "/Users/brettkellgren/Sites/lakeledger/orchestrator/specs/016-autonomous-hardening/spec.md#AC-5"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
content_hash: "sha256:cc48944c05a5f6ee1f973798bd0e3e3ddead84c59186ee6106006b3d6d3cf0d1"
relates_to: [SPEC-US-002]
---

# SPEC-AC-005: Given a script or template file containing `$(…)`, backticks, or `{…,…}` brace e

1. **Given** a script or template file containing `$(…)`, backticks, or `{…,…}` brace expansion in a bash invocation, **When** the anti-pattern linter runs, **Then** it exits non-zero and names the offender with a remediation hint.
