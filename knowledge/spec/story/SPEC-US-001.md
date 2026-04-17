---
id: SPEC-US-001
scope_tags: "[project]"
category: spec/story
confidence: 0.90
created_at: 2026-04-17
last_verified: 2026-04-17
hit_count: 0
source_unit: "/Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator/specs/016-autonomous-hardening/spec.md#US-1"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
content_hash: "sha256:53cffbfdb187a237193f9ae8b82265b44830cf6880bc20c89ed67437b925961c"
relates_to: []
---

# SPEC-US-001: Full Phase Runs To Completion Without Prompts

A developer runs `orchestrator:auto` on a freshly-planned phase in Claude Code with default settings. The loop derives state, dispatches every task in fresh subagent contexts, verifies each one, and advances until the phase completes — with zero approval prompts surfaced to the user.

**Why this priority**: This is the definition of "truly autonomous." If even one prompt surfaces per phase, the user must stay at the keyboard, and the autonomous-execution value proposition collapses.

**Independent Test**: Pick a representative phase (e.g. a 4–6 task phase touching scripts, templates, and verify suites). Execute `orchestrator:auto` end-to-end from a fresh Claude Code session with project-default permissions. Capture the subagent transcripts and grep for "Do you want to proceed" prompts — the count must be zero.

