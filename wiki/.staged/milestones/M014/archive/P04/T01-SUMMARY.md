---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M014"
provides:
  - "Pinned specify.complexity_thresholds values (fr_count=15, user_story_count=5, raw_token_count=8000, todo_density=0.5, contradiction_signal_count=1); new top-level keys contradiction_signal_criterion=cc-llm-or-zero and hardening_spec_exception=true; tests/fixtures/m014-p04/corpus-labels.tsv (header + 6 data rows); CALIBRATION-MEMO.md (Retrospective Corpus / Cutoffs / Hardening-Spec Exception); scripts/verify/m014-p04-calibration-thresholds.sh gate verifier"
requires:
  - "from:P01 what:.orchestrator/config.yml specify: section with all-zero complexity_thresholds stub; from:disk what:six retrospective specs (011,016,021,022,023,024); from:disk what:scripts/verify/anti-pattern-lint.sh"
affects:
  - "T02 spec-complexity-probe-full body (consumes pinned thresholds and hardening exception via config.yml); T04 commands/specify.md three-way prompt (invoked when probe fires above-threshold); downstream P04 gates that assert config values"
key_files:
  - ".orchestrator/config.yml,tests/fixtures/m014-p04/corpus-labels.tsv,.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md,scripts/verify/m014-p04-calibration-thresholds.sh"
key_decisions:
  - "Hardening-spec exception triggered by fr_count==0 (not user_story_count threshold relaxation) — more precise, targets shape not size; token-count cutoff at 8000 deliberately placed between M013 (7851) and M022 (3613) even though M013 measured just below cutoff (OR-semantics across other axes still classify M013 correctly); TODO-density computed as todo_count/(todo_count+section_count); thresholds declared planning-pinned defaults not empirically optimal (CON-9 covers retuning)"
patterns_established:
  - "calibration-memo-with-measurement-delta-table (planner approximations vs re-measured values documented side-by-side; no threshold re-tuning unless a label flips); OR-semantics-threshold-with-boolean-override (hardening_spec_exception overrides above-threshold when fr_count==0); config-surface-for-exception-flags (top-level boolean key documents exception rather than burying in probe body)"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md,.orchestrator/milestones/M014/phases/P04/tasks/T01-PAYLOAD.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-04-23T00:31:43Z"
---

T01 pinned the FR-5 complexity-probe thresholds via a retrospective corpus of six specs and a design memo. Re-measured all six corpus specs; actual token counts trended 13-59% lower than the planner approximations but no label flipped — thresholds remain as planned (fr_count=15, user_story_count=5, raw_token_count=8000, todo_density=0.5, contradiction_signal_count=1). Added top-level contradiction_signal_criterion=cc-llm-or-zero and hardening_spec_exception=true keys. [M013](../../../../milestones/M013/index.md) classification deserves noting: its measured token count (7851) falls just under the 8000 cutoff, but it still fires above-threshold via fr_count (18>=15) and user_story_count (6>=5) — OR-semantics across axes. [M024](../../../../milestones/M024/index.md) showed 14 TODO placeholders (planner snapshot saw 0) — this is an in-flight authoring state; todo_density (14/(14+12)=0.538) would trip the gate even without the FR/US axes. Hardening-spec exception rationalized via shape-signal (zero-FR-list is diagnostic of behavioral-fix milestones) rather than size-signal (story count); rejects the alternative of raising user_story_count to 6 because [M011](../../../../milestones/M011/index.md) at 5 stories legitimately needed pressure-testing. Gate verifier and anti-pattern lint both exit 0.
