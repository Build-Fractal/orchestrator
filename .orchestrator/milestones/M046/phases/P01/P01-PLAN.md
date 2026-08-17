---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M046"
goal: "Resolve #Q-1 (default-DENY PreToolUse hook installable via the M028 path + shape-guard coexistent) and #Q-4 (cost-read cadence for pre-spawn lease reads) with real, non-stubbed evidence — the CON-6 decision gate P04 and P05 build on."
demo_sentence: "Two evidence docs on disk carry firm verdicts: a default-DENY PreToolUse hook installed via the M028 consumer path denies a live out-of-scope call (and coexists with the M021 shape-guard), and the cost source's per-segment read cadence is measured — #Q-1 and #Q-4 are answered before any envelope code exists."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- The viability evidence artifact records a definite verdict for BOTH #Q-1 and #Q-4 (PASS / NEGATIVE / PARTIAL each, with the decision-gate routing consequence stated).
  - Check: `bash tools/verify/m046-p01-viability-evidence.sh`
- The hook probe demonstrates live default-DENY semantics: an out-of-scope write, an out-of-scope Bash call (`git push`), and an MCP tool call are denied (exit 2 + reason) while an allowlisted call passes (exit 0), driven through the real hook binary.
  - Check: `bash tools/verify/m046-p01-hook-deny-proof.sh`
- The install-shape matrix shows the probe hook staged AND its PreToolUse fragment merged (managed-tagged, idempotent on re-run) on both install shapes (packaged-bundle and symlink/source), alongside the existing shape-guard entry.
  - Check: `bash tools/verify/m046-p01-install-matrix.sh`
- The cost-cadence log captures per-record wall-clock timestamps proving cost-bearing records appear at unit grain during a loop run (not only at loop exit), and the evidence states the resulting FR-7/FR-8 cost-source decision.
  - Check: `bash tools/verify/m046-p01-cadence-log.sh`

### Artifacts

- .orchestrator/milestones/M046/phases/P01/P01-VIABILITY-EVIDENCE.md (min 60 lines, contains "VERDICT:")
- .orchestrator/milestones/M046/phases/P01/spike/hook/unattended-deny-probe.sh (min 40 lines, contains "exit 2")
- .orchestrator/milestones/M046/phases/P01/spike/hook/install-matrix.log (min 4 lines, contains "shape=")
- .orchestrator/milestones/M046/phases/P01/spike/hook/deny-drive.log (min 4 lines, contains "case=")
- .orchestrator/milestones/M046/phases/P01/spike/cost/cadence.jsonl (min 3 lines, contains "unit_close")
- tools/verify/m046-p01-phase-suite.sh (min 15 lines, contains "m046-p01")

### Key Links

- .orchestrator/milestones/M046/phases/P01/P01-VIABILITY-EVIDENCE.md → .orchestrator/milestones/M046/phases/P01/spike/hook/deny-drive.log (verdict cites the deny-drive evidence)
- .orchestrator/milestones/M046/phases/P01/P01-VIABILITY-EVIDENCE.md → .orchestrator/milestones/M046/phases/P01/spike/cost/cadence.jsonl (verdict cites the cadence measurement)

## Tasks

### T01: Hook-install portability spike (#Q-1)

Author a minimal default-DENY PreToolUse probe hook; direct-drive it through the real hook stdin/exit-code contract (deny out-of-scope write / `git push` / MCP call; pass allowlisted call); stage + register it via the M028 conventions into an ISOLATED $HOME on both install shapes; assert coexistence with `pre-bash-shape-guard.sh`. See `tasks/T01-hook-portability-spike-PLAN.md`.

### T02: Cost-read cadence probe (#Q-4)

Drive `auto-loop.sh` with the dispatch stub against a throwaway fixture milestone in a scratch state root; timestamp-watch `execution-log.jsonl` to measure WHEN cost-bearing records (`unit_close` / `dispatch_usage`) become readable relative to unit and loop boundaries; bank the P00 spike's `claude -p --output-format json` `total_cost_usd` evidence (cite, do not re-spend). See `tasks/T02-cost-cadence-probe-PLAN.md`.

### T03: Evidence consolidation + verdicts + phase verifiers

Analyze T01+T02 outputs; author `P01-VIABILITY-EVIDENCE.md` with a VERDICT line per question and the decision-gate routing (FR-9 mechanism confirmed vs rerouted-by-Decision-row; FR-7/FR-8 cost source fixed); author the five `tools/verify/m046-p01-*.sh` verifiers including the phase-suite aggregator. See `tasks/T03-evidence-verdicts-PLAN.md`.

## Task Dependencies

```
T01 → T03
T02 → T03   (T01 and T02 are independent — parallelizable)
```

## Files Likely Touched

- .orchestrator/milestones/M046/phases/P01/spike/hook/unattended-deny-probe.sh (create — T01)
- .orchestrator/milestones/M046/phases/P01/spike/hook/drive-hook-case.sh (create — T01)
- .orchestrator/milestones/M046/phases/P01/spike/hook/run-install-matrix.sh (create — T01)
- .orchestrator/milestones/M046/phases/P01/spike/hook/deny-drive.log (create — populated by T01)
- .orchestrator/milestones/M046/phases/P01/spike/hook/install-matrix.log (create — populated by T01)
- .orchestrator/milestones/M046/phases/P01/spike/cost/fixture/ (create — T02 synthetic milestone tree)
- .orchestrator/milestones/M046/phases/P01/spike/cost/run-cadence-probe.sh (create — T02)
- .orchestrator/milestones/M046/phases/P01/spike/cost/cadence.jsonl (create — populated by T02)
- .orchestrator/milestones/M046/phases/P01/P01-VIABILITY-EVIDENCE.md (create — T03)
- tools/verify/m046-p01-viability-evidence.sh (create — T03)
- tools/verify/m046-p01-hook-deny-proof.sh (create — T03)
- tools/verify/m046-p01-install-matrix.sh (create — T03)
- tools/verify/m046-p01-cadence-log.sh (create — T03)
- tools/verify/m046-p01-phase-suite.sh (create — T03)
