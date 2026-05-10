---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P06"
milestone: "M011"
provides:
  - "P06 dogfood evidence transcripts (ingest-transcript.txt, spec-metrics.txt, story-ids.txt, timing.txt); m011-p06-evidence-present.sh token gate; m011-p06-bash32-compat.sh scan across all 8 other P06 verify scripts; m011-p06-commands-preserve-references.sh regression guarding prior Reference File bullets"
requires:
  - "T01 commands/ingest.md + commands/evaluate.md edit; T02 m011-p06-e2e-pipeline.sh + m011-p06-e2e-pipeline-timing.sh; P03 ingest-spec.sh; P05 spec-metrics.sh; P04 scope-filter.sh; an in-repo real spec for the dogfood run"
affects:
  - "P06 phase verification closes with all 9 m011-p06-*.sh PASS plus P05 regression still PASS; M011 ready to close at milestone level"
key_files:
  - ".orchestrator/milestones/M011/phases/P06/evidence/ingest-transcript.txt, .orchestrator/milestones/M011/phases/P06/evidence/spec-metrics.txt, .orchestrator/milestones/M011/phases/P06/evidence/story-ids.txt, .orchestrator/milestones/M011/phases/P06/evidence/timing.txt, scripts/verify/m011-p06-evidence-present.sh, scripts/verify/m011-p06-bash32-compat.sh, scripts/verify/m011-p06-commands-preserve-references.sh"
key_decisions:
  - "Dogfood invocation uses --scope-tags [project] so chunks surface to scope-filter with M011/P06 scope context"
patterns_established:
  - "Evidence-present token gate pattern (file-exists + token-contains) as standard dogfood verification shape; regression guard for doc-preserved Reference File bullets extended from P05 to P06"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P06/tasks/T03-PAYLOAD.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-17T11:22:18Z"
---

T03 dogfoods the full orchestrator:ingest -> orchestrator:evaluate -> orchestrator:roadmap pipeline against specs/016-autonomous-hardening/spec.md, captures four evidence transcripts (ingest output with 20 CREATED lines, spec-metrics with spec_chunks_present=true, 3 SPEC-US- story IDs, elapsed_seconds=7), and lands three regression guards: evidence-present token gate, Bash 3.2 compat scan across all 8 other P06 verify scripts, and command-reference-preservation for evaluate.md + roadmap.md. All 9 P06 verify scripts pass collectively; P05 regression suite still PASS. Dogfood ingest used --scope-tags [project] so chunks surface to scope-filter under the M011/P06 scope context. No production code changes.
