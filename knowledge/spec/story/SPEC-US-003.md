---
id: SPEC-US-003
scope_tags: "[project]"
category: spec/story
confidence: 0.90
created_at: 2026-04-17
last_verified: 2026-04-17
hit_count: 0
source_unit: "/Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator/specs/016-autonomous-hardening/spec.md#US-3"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
content_hash: "sha256:3332560187f64544031c9ceef537282b8dc7fd415bc117297257d0eb61842e35"
relates_to: []
---

# SPEC-US-003: Verify Suites Run Via A Single Wrapper

When a task's plan calls for running multiple verify scripts and tallying PASS/FAIL counts, the dispatched subagent invokes a single wrapper script that does the discovery, execution, and tallying. No chained `&&` pipelines, no inline `awk '{print $1}' | sort | uniq -c`.

**Why this priority**: Verify-suite chains are the second-most-frequent prompt source (observed in M015 P02 verification, M003 P08, and several audits). One wrapper replaces dozens of task-plan snippets.

**Independent Test**: Run the wrapper against a phase directory with mixed PASS/FAIL scripts. It must exit with the correct aggregate status and print a summary machine-parseable by downstream verification.

