---
id: SPEC-AC-002
scope_tags: "[project]"
category: spec/acceptance
confidence: 0.90
created_at: 2026-04-17
last_verified: 2026-04-17
hit_count: 0
source_unit: "/Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator/specs/016-autonomous-hardening/spec.md#AC-2"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
content_hash: "sha256:a142cb5c5aa6965ade6d8d75529dd997e437ebd0cafb86b65f83b83c4f93eb17"
relates_to: [SPEC-US-001]
---

# SPEC-AC-002: Given a dispatched subagent writes a task summary, When it calls `write-summary.

2. **Given** a dispatched subagent writes a task summary, **When** it calls `write-summary.sh`, **Then** the call contains no `$(...)` command substitution, no backticks, no brace expansion.
