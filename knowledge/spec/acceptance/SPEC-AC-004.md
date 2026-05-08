---
id: SPEC-AC-004
scope_tags: "[project]"
category: spec/acceptance
confidence: 0.90
created_at: 2026-04-17
last_verified: 2026-04-17
hit_count: 0
source_unit: "/Users/brettkellgren/Sites/lakeledger/orchestrator/specs/016-autonomous-hardening/spec.md#AC-4"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
content_hash: "sha256:781d5302cbc7c30f9b7810e6dc61aab6cc4cb007b50c7ca9d887977364b0bc91"
relates_to: [SPEC-US-001]
---

# SPEC-AC-004: Given a project cloned fresh into a new workspace, When the developer runs `orch

4. **Given** a project cloned fresh into a new workspace, **When** the developer runs `orchestrator:auto` with only the checked-in `settings.json` (no `settings.local.json` entries), **Then** no prompt fires that requires an allow-list entry the project didn't provide.

---

