---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M045"
goal: "Determine, with real (non-stubbed) evidence, whether in-session ScheduleWakeup re-entry gives bounded context relief across ≥2 rotation boundaries — the SC-6 / #Q-1 decision gate."
demo_sentence: "A real multi-rotation run under a self-continue prototype shows measured, bounded (non-compounding) context growth across ≥2 rotation boundaries and correct disk-state resume at each — recorded in P01-VIABILITY-EVIDENCE.md with a VERDICT line — or a negative result that triggers the CON-5 route to M-auto-v2b."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- The viability evidence artifact records a definite verdict (PASS or NEGATIVE) backed by measurements from ≥2 real rotation boundaries.
  - Check: `bash tools/verify/m045-p01-viability-evidence.sh`
- The spike measurement log captured at least three segments (≥2 rotation boundaries crossed).
  - Check: `bash tools/verify/m045-p01-segments-present.sh`

### Artifacts

- .orchestrator/milestones/M045/phases/P01/P01-VIABILITY-EVIDENCE.md (min 40 lines, contains "VERDICT:")
- .orchestrator/milestones/M045/phases/P01/spike/segments.jsonl (min 3 lines, contains "segment")
- .orchestrator/milestones/M045/phases/P01/spike/self-continue-drive.sh (min 20 lines, contains "CONTEXT:ROTATE")
- tools/verify/m045-p01-viability-evidence.sh (min 10 lines, contains "VERDICT:")

### Key Links

- .orchestrator/milestones/M045/phases/P01/P01-VIABILITY-EVIDENCE.md → .orchestrator/milestones/M045/phases/P01/spike/segments.jsonl (evidence cites the measurement log)

## Tasks

### T01: Build the throwaway spike fixture + self-continue driver + capture helper

Deterministic build task (normal executor). See `tasks/T01-spike-harness-PLAN.md`.

### T02: Execute the live multi-rotation self-continue run and capture measurements

Live run in the ORCHESTRATING SESSION under `/loop` (NOT a fresh subagent — `ScheduleWakeup` is a main-loop primitive). See `tasks/T02-live-run-PLAN.md`.

### T03: Analyze measurements, author the viability evidence + verifiers, resolve #Q-1 / recommend #Q-2

Analysis + authoring task (normal executor). See `tasks/T03-analyze-evidence-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T03
```

## Files Likely Touched

- .orchestrator/milestones/M045/phases/P01/spike/fixture/ (create — synthetic Tier C fixture milestone tree)
- .orchestrator/milestones/M045/phases/P01/spike/self-continue-drive.sh (create)
- .orchestrator/milestones/M045/phases/P01/spike/capture-segment.sh (create)
- .orchestrator/milestones/M045/phases/P01/spike/segments.jsonl (create — populated by T02)
- .orchestrator/milestones/M045/phases/P01/P01-VIABILITY-EVIDENCE.md (create — T03)
- tools/verify/m045-p01-viability-evidence.sh (create — T03)
- tools/verify/m045-p01-segments-present.sh (create — T03)

## Notes

- **Why P01 is a decision gate, not just a build**: the conversus deliberation (`specs/046-self-continuing-auto/conversus/summary/final.md`, RISK-1/MIT-1) established that SC-1's stub cannot test the mechanism's load-bearing premise. P01 exists to test it for real. A NEGATIVE verdict is a legitimate, valuable outcome — it halts M045 at whatever US1 slice is viable and routes the process-fresh remainder to M-auto-v2b per spec CON-5, rather than expanding scope here.
- **Measurement honesty**: the true unknown is whether the harness's automatic context summarization/compaction relieves the orchestrating session's context after an in-session `ScheduleWakeup` re-entry (state-on-disk already guarantees *correctness* per CON-2; the open question is *boundedness*). The spike captures the strongest feasible proxies (harness-reported context/token usage if exposed, transcript message count, and `context-monitor.sh` session weight) per segment; the analysis judges bounded-vs-compounding from their trend across boundaries.
- **Throwaway**: everything under `spike/` is spike-grade and disposable — it informs the P02–P04 production design but is not itself production code (spec CON-3 keeps production scope to the rotation-exit branch).
