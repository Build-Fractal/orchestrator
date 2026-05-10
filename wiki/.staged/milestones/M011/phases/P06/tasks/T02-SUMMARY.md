---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P06"
milestone: "M011"
provides:
  - "m011-p06-e2e-pipeline.sh end-to-end gate script (ingest -> metrics -> scope-filter sandbox), m011-p06-e2e-pipeline-timing.sh 60s threshold harness"
requires:
  - "P03 ingest-spec.sh, P04 scope-filter.sh --category spec/story --graph, P05 spec-metrics.sh, rebuild-index.sh"
affects:
  - "T03 evidence-capture reuses the same pipeline shape against a real in-repo spec, P06 phase verification gates on these two scripts passing, milestone-level validation of chunks-first dispatch path"
key_files:
  - "scripts/verify/m011-p06-e2e-pipeline.sh, scripts/verify/m011-p06-e2e-pipeline-timing.sh"
key_decisions:
  - "Use --scope-tags [project] during ingest so chunks match scope-filter's scope WHERE-clause; pass placeholder positional args to scope-filter.sh in --graph mode (positional args still required despite unused FILE_PATH)"
patterns_established:
  - "sandbox PROJECT_ROOT=mktemp -d with EXIT-trap cleanup for full ingest pipeline tests; integer-only timing gate with date +%s bookends"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P06/tasks/T02-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-17T11:15:40Z"
---

T02 delivers two Bash 3.2 compatible verify scripts: an end-to-end pipeline gate that builds a synthetic markdown fixture spec, exercises ingest -> spec-metrics -> scope-filter, and asserts each stage produces the expected output; plus a timing harness that captures elapsed seconds with date +%s bookends and enforces the 60-second P06 success criterion. Both scripts sandbox under mktemp -d with EXIT-trap cleanup. No production code changes. Deviation from plan: ingest invocation adds --scope-tags [project] and scope-filter invocation supplies placeholder positional args (KNOWLEDGE-INDEX.md, M011/P06) because scope-filter.sh requires positional FILE_PATH/SCOPE_CONTEXT even in --graph mode and its scope WHERE-clause only matches [project]/[milestone]/[phase] tags (not the default [spec:<slug>] tag emitted by ingest). Running verify: m011-p06-e2e-pipeline.sh PASS, m011-p06-e2e-pipeline-timing.sh PASS (elapsed_seconds=2, under 60).
