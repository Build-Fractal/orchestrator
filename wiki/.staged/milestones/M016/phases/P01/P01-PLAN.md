---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M016"
goal: "Eliminate command substitution from the task-summary write path by making --completed_at optional in write-summary.sh and updating agent-facing documentation to stop showing $(date ...) in examples"
demo_sentence: "A dispatched subagent writes a task summary via write-summary.sh with no $(…) in the Bash call — --completed_at is omitted and the script defaults to now."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- `write-summary.sh` accepts a call with no `--completed_at` flag and defaults to the current UTC timestamp
  - Check: `bash scripts/verify/m016-p01-completed-at-optional.sh`
- `write-summary.sh` accepts `--completed_at=now` and resolves it to the current UTC timestamp
  - Check: `bash scripts/verify/m016-p01-completed-at-now-sentinel.sh`
- `write-summary.sh` still accepts `--completed_at=2026-01-01T00:00:00Z` (explicit ISO value) unchanged
  - Check: `bash scripts/verify/m016-p01-completed-at-explicit.sh`
- `commands/auto.md` milestone write-summary example does not contain `$(` or backtick command substitution
  - Check: `bash scripts/verify/m016-p01-auto-md-no-subst.sh`
- `ANTIPATTERNS.md` contains an AP-004 entry documenting Class A harness prompt triggers
  - Check: `bash scripts/verify/m016-p01-antipatterns-ap004.sh`

### Artifacts

- `scripts/knowledge/write-summary.sh` (min 180 lines, contains "completed_at=now")
- `scripts/verify/m016-p01-completed-at-optional.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m016-p01-completed-at-now-sentinel.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m016-p01-completed-at-explicit.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m016-p01-auto-md-no-subst.sh` (min 5 lines, contains "PASS")
- `scripts/verify/m016-p01-antipatterns-ap004.sh` (min 5 lines, contains "PASS")
- `ANTIPATTERNS.md` (min 100 lines, contains "AP-004")

### Key Links

- `commands/auto.md` → `scripts/knowledge/write-summary.sh` (example invocation references updated API)
- `ANTIPATTERNS.md` → `scripts/knowledge/write-summary.sh` (AP-004 cites write-summary as evidence)

## Tasks

### T01: Make --completed_at optional with now sentinel in write-summary.sh

See `tasks/T01-PLAN.md`.

### T02: Update commands/auto.md examples to omit --completed_at

See `tasks/T02-PLAN.md`.

### T03: Add AP-004 to ANTIPATTERNS.md cataloging Class A prompt triggers

See `tasks/T03-PLAN.md`.

## Task Dependencies

```
T01 → T02
T01 → T03
```

T02 and T03 can run in parallel after T01 completes.

## Files Likely Touched

- `scripts/knowledge/write-summary.sh` (modify)
- `commands/auto.md` (modify)
- `ANTIPATTERNS.md` (modify)
- `scripts/verify/m016-p01-completed-at-optional.sh` (create)
- `scripts/verify/m016-p01-completed-at-now-sentinel.sh` (create)
- `scripts/verify/m016-p01-completed-at-explicit.sh` (create)
- `scripts/verify/m016-p01-auto-md-no-subst.sh` (create)
- `scripts/verify/m016-p01-antipatterns-ap004.sh` (create)
