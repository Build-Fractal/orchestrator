---
id: SPEC-AC-001
scope_tags: "[project]"
category: spec/acceptance
confidence: 0.90
created_at: 2026-04-17
last_verified: 2026-04-17
hit_count: 0
source_unit: "/Users/brettkellgren/Sites/lakeledger/orchestrator/specs/016-autonomous-hardening/spec.md#AC-1"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
content_hash: "sha256:c7b1aa8b1efef73ab46b67c83c1101b881025d5e1fae4fb09977a36118ac3c57"
relates_to: [SPEC-US-001]
---

# SPEC-AC-001: Given a planned phase with ≥4 tasks, When `orchestrator:auto` runs to completion

1. **Given** a planned phase with ≥4 tasks, **When** `orchestrator:auto` runs to completion, **Then** no Claude Code approval prompt is surfaced to the user across the full loop.
