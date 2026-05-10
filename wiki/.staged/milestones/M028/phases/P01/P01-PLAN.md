---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M028"
goal: "Empirical baseline + collapse-decision evidence — replay every M028 source event through the existing M021 classifier, capture the operator's M018-close settings.json snapshot as a permanent P01 fixture, and write the per-screenshot causal trace + collapse-decision recommendation that gates whether M028 ships full-shape (P02–P05) or collapses to 2 PRs."
demo_sentence: "A developer runs the M028 baseline harness against the source events from the M028 spec; the run records, per-event, the existing-classifier verdict and a root-cause attribution (Finding A hook-portability, Finding B/G classifier-shape, Finding D/E missing-wrapper, or Finding F adapter+installer); the collapse-decision evidence file lands at `phases/P01/P01-VERIFICATION.md` and the operator's M018-close settings.json snapshot lands at `tests/fixtures/m028-pre-repair-snapshot.json`."
risk: "low"
depends_on: []
---

## Must-Haves

### Truths

- The classifier-replay audit covers every source event from the M028 spec (every `screenshot` reference under `Findings A` through `Findings G` plus the operator-reported Stop-hook failure).
  - Check: `bash scripts/verify/m028/p01-replay-coverage.sh`

- The pre-repair fixture is byte-stable on disk and contains no user-specific path or token strings (the operator's local username, home directory absolute paths, or any secrets that may have been present in the original `~/.claude/settings.json`).
  - Check: `bash scripts/verify/m028/p01-fixture-sanitized.sh`

- The collapse-decision evidence file records, for every source event, both the existing-classifier verdict and a root-cause attribution mapping to one or more findings (A, B, C, D, E, F, G); and records an explicit collapse-decision recommendation (`full-5-phase` or `collapse-to-2-PRs`) with cited per-event evidence.
  - Check: `bash scripts/verify/m028/p01-collapse-decision-recorded.sh`

### Artifacts

- [`.orchestrator/milestones/M028/phases/P01/classifier-audit.md`](../../../../milestones/M028/phases/P01/classifier-audit.md) (min 30 lines, contains "AP-009")
- `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md` (min 80 lines, contains "Collapse Decision")
- `tests/fixtures/m028-pre-repair-snapshot.json` (min 30 lines, contains "_orchestrator_managed")
- `scripts/verify/m028/p01-replay-coverage.sh` (min 10 lines, contains "classifier-audit.md")
- `scripts/verify/m028/p01-fixture-sanitized.sh` (min 10 lines, contains "m028-pre-repair-snapshot.json")
- `scripts/verify/m028/p01-collapse-decision-recorded.sh` (min 10 lines, contains "Collapse Decision")

### Key Links

- `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md` → [`.orchestrator/milestones/M028/phases/P01/classifier-audit.md`](../../../../milestones/M028/phases/P01/classifier-audit.md) (verification document cites the audit)
- `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md` → `tests/fixtures/m028-pre-repair-snapshot.json` (verification document references the captured fixture for downstream P02 `--repair` consumption)

## Tasks

### T01: Classifier Replay Audit Of All M028 Source Events

See `tasks/T01-classifier-replay-audit-PLAN.md`.

### T02: Capture Operator M018-Close Settings.json Snapshot

See `tasks/T02-fixture-snapshot-PLAN.md`.

### T03: Collapse-Decision Evidence + Per-Screenshot Causal Trace

See `tasks/T03-collapse-decision-evidence-PLAN.md`.

## Task Dependencies

```
T01 ─→ T03
T02            (independent of T01; T03 references T02's path but does not read T02's content)
```

T01 must complete before T03 (T03 reads `classifier-audit.md`). T02 can run any time — it captures a pre-existing on-disk file and is independent of T01's classifier work; T03 references the resulting fixture path but does not consume the file content.

## Files Likely Touched

- [`.orchestrator/milestones/M028/phases/P01/classifier-audit.md`](../../../../milestones/M028/phases/P01/classifier-audit.md) (create)
- `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md` (create)
- `tests/fixtures/m028-pre-repair-snapshot.json` (create)
- `scripts/verify/m028/p01-replay-coverage.sh` (create)
- `scripts/verify/m028/p01-fixture-sanitized.sh` (create)
- `scripts/verify/m028/p01-collapse-decision-recorded.sh` (create)
