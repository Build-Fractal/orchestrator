---
id: SPEC-AC-003
scope_tags: "[project]"
category: spec/acceptance
confidence: 0.90
created_at: 2026-04-17
last_verified: 2026-04-17
hit_count: 0
source_unit: "/Users/brettkellgren/Sites/lakeledger/orchestrator/specs/016-autonomous-hardening/spec.md#AC-3"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
content_hash: "sha256:5ebf48cf3236fb6364bf1226c1f811cb7b7bf0219bb2aa15148508c049013b87"
relates_to: [SPEC-US-001]
---

# SPEC-AC-003: Given a dispatched subagent runs a phase's verify suite, When it tallies results

3. **Given** a dispatched subagent runs a phase's verify suite, **When** it tallies results, **Then** it invokes a single wrapper script (not a chained `bash … && bash … | awk | sort | uniq` pipeline).
