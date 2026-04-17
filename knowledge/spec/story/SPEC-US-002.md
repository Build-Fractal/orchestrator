---
id: SPEC-US-002
scope_tags: "[project]"
category: spec/story
confidence: 0.90
created_at: 2026-04-17
last_verified: 2026-04-17
hit_count: 0
source_unit: "/Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator/specs/016-autonomous-hardening/spec.md#US-2"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
content_hash: "sha256:bdd8c82d30a3b4ae52569e995f566525430f099ff11ceb351c2eb08bc50c602e"
relates_to: []
---

# SPEC-US-002: Anti-Pattern Guardrails Prevent Regression

A developer (or Claude-as-subagent) edits a plan template, script, or dispatch payload and accidentally reintroduces one of the prohibited patterns. The guardrails catch it before it reaches a user-facing `orchestrator:auto` run.

**Why this priority**: One-time elimination is insufficient — the patterns recur naturally because `$(date -u ...)` is idiomatic bash. Without mechanical enforcement, the autonomy property decays within a few milestones.

**Independent Test**: Seed a test plan file with a call like `bash scripts/knowledge/write-summary.sh task /tmp/x.md --completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ) ...`. Run the repo's anti-pattern linter. It must fail with a clear diagnostic naming the file, line, and offending pattern, and suggest the wrapper-script or sentinel alternative.

