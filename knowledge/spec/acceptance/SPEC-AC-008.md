---
id: SPEC-AC-008
scope_tags: "[project]"
category: spec/acceptance
confidence: 0.90
created_at: 2026-04-17
last_verified: 2026-04-17
hit_count: 0
source_unit: "/Users/brettkellgren/Sites/lakeledger/orchestrator/specs/016-autonomous-hardening/spec.md#AC-8"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
content_hash: "sha256:a9e9e5df706bce761e4af45680a4ba6c905fec37eb8d89954d3fdf64f3ff0c3f"
relates_to: [SPEC-US-003]
---

# SPEC-AC-008: Given a phase directory containing ≥3 `*.sh` gate scripts, When the developer ru

1. **Given** a phase directory containing ≥3 `*.sh` gate scripts, **When** the developer runs `scripts/verify/run-suite.sh <phase-path>`, **Then** all scripts execute and the wrapper prints `PASS: N / FAIL: M` plus per-script status.
