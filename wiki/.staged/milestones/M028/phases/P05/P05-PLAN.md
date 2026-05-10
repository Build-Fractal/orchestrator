---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M028"
goal: "Cross-project verifier suite + downstream fixture replay — author the permanent in-tree consumer-project fixture (`tests/fixtures/downstream-project/`), the autonomous-loop replay harness (`tests/run-downstream-fixture.sh`) that replays Finding A/B/G screenshot commands plus a Stop event against the staged hooks dir and asserts zero `would_prompt: true` + zero `command not found`, and the M028 close-out regression gate that ties the install-roundtrip + corpus replay + per-finding `run-all.sh` + downstream-fixture harness into a single CI-runnable artifact."
demo_sentence: "A developer runs `bash scripts/verify/m028/run-all.sh` and `bash tests/run-downstream-fixture.sh`; both exit 0; the run-all summary line reads `M028: 7/7 findings verified (skipped: 0, failed: 0)`; the fixture autonomous-loop completes uninterrupted with zero `would_prompt: true` events and zero `command not found` diagnostics; the close-out regression gate `bash scripts/verify/m028/p05-regression-gate.sh` exits 0 and reports M028 close-out clean across all four sub-gates."
risk: "medium"
depends_on: ["P03", "P04"]
---

## Must-Haves

### Truths

- `tests/fixtures/downstream-project/` exists in-tree (CON-10 permanent fixture) with its own `.claude/settings.json` and no internal `scripts/hooks/` directory. Verified by checking the fixture path layout on disk.
  - Check: `bash scripts/verify/m028/p05-fixture-permanent.sh`

- The fixture's `.claude/settings.json` is byte-shape-compatible with the runtime adapter's current `--hook-config` emission (CON-10 noisy-fail discipline). The verifier asserts every `command` field in the fixture starts with `bash ` and ends with `.sh` (matching the adapter's contract from P02/T02), and every leaf hook object carries `_orchestrator_managed: true`. Drift between fixture and adapter shape fails the verifier loudly rather than silently passing on stale fixture bytes. Satisfies CON-10 + US-1 + FR-19.
  - Check: `bash scripts/verify/m028/p05-downstream-fixture-shape.sh`

- The autonomous-loop replay harness `tests/run-downstream-fixture.sh` exists, is executable, and exits 0 against the permanent fixture. The harness replays a verbatim Finding A 4-connector compound chain command, replays the M028 corpus IDs 21..25 + 27 (the AP-010..AP-014 evidence entries) verbatim through the staged hook, and replays a Stop event by invoking the staged `after-verify-sync.sh`. Every Bash invocation routes through the staged shape-guard; the Stop event resolves cleanly without `command not found`. Satisfies SC-3 + SC-5 + US-1 + US-5 + FR-19.
  - Check: `bash scripts/verify/m028/p05-downstream-fixture-clean.sh`

- The M028 close-out regression gate `scripts/verify/m028/p05-regression-gate.sh` exists and exits 0; it sequences the four close-out sub-gates (install-roundtrip, 27-entry corpus replay, per-finding `run-all.sh`, downstream fixture harness) and emits a single consolidated PASS/FAIL summary. This is the M028 CI-runnable close-out artifact. Satisfies SC-1 + SC-2 + SC-3 + SC-4 + SC-5 + SC-8.
  - Check: `bash scripts/verify/m028/p05-regression-gate.sh`

- `bash scripts/verify/m028/run-all.sh` reports `M028: 7/7 findings verified (skipped: 0, failed: 0)` post-P05. P04 already established this contract; P05 confirms it stays clean as the close-out gate. Satisfies SC-4 + FR-20.
  - Check: `bash scripts/verify/m028/p05-run-all-clean.sh`

- `bash tests/run-prompt-corpus-replay.sh` exits 0 with `WOULD_PROMPT=0/27` final line — the combined [M021](../../../../milestones/M021/index.md) + M028 corpus replays clean under the current classifier (strict-superset CON-7 preserved). Satisfies SC-1 + SC-8.
  - Check: `bash scripts/verify/m028/p05-corpus-replay-clean.sh`

### Artifacts

- `tests/fixtures/downstream-project/.claude/settings.json` (min 8 lines, contains "_orchestrator_managed")
- `tests/fixtures/downstream-project/README.md` (min 6 lines, contains "downstream-project")
- `tests/run-downstream-fixture.sh` (min 80 lines, contains "would_prompt")
- `scripts/verify/m028/p05-fixture-permanent.sh` (min 25 lines, contains "downstream-project")
- `scripts/verify/m028/p05-downstream-fixture-shape.sh` (min 30 lines, contains "_orchestrator_managed")
- `scripts/verify/m028/p05-downstream-fixture-clean.sh` (min 25 lines, contains "run-downstream-fixture")
- `scripts/verify/m028/p05-regression-gate.sh` (min 60 lines, contains "install-roundtrip")
- `scripts/verify/m028/p05-run-all-clean.sh` (min 25 lines, contains "7/7 findings verified")
- `scripts/verify/m028/p05-corpus-replay-clean.sh` (min 25 lines, contains "WOULD_PROMPT=0/27")

### Key Links

- `tests/run-downstream-fixture.sh` → `tests/fixtures/downstream-project` (harness consumes the permanent fixture)
- `scripts/verify/m028/p05-downstream-fixture-shape.sh` → `scripts/dispatch/adapters/runtime/claude-code.sh` (shape verifier compares fixture bytes to adapter `--hook-config` emission)
- `scripts/verify/m028/p05-downstream-fixture-clean.sh` → `tests/run-downstream-fixture.sh` (clean verifier invokes the harness)
- `scripts/verify/m028/p05-regression-gate.sh` → `scripts/verify/m028/install-roundtrip.sh` (regression gate sequences the install-roundtrip sub-gate)
- `scripts/verify/m028/p05-regression-gate.sh` → `scripts/verify/m028/run-all.sh` (regression gate sequences the run-all sub-gate)
- `scripts/verify/m028/p05-regression-gate.sh` → `tests/run-downstream-fixture.sh` (regression gate sequences the downstream fixture sub-gate)
- `scripts/verify/m028/p05-regression-gate.sh` → `tests/run-prompt-corpus-replay.sh` (regression gate sequences the corpus replay sub-gate)
- `scripts/verify/m028/p05-corpus-replay-clean.sh` → `tests/run-prompt-corpus-replay.sh` (clean verifier invokes the replay harness)
- `scripts/verify/m028/p05-run-all-clean.sh` → `scripts/verify/m028/run-all.sh` (clean verifier invokes run-all)

## Tasks

### T01: Permanent downstream-project fixture + shape verifier

See `tasks/T01-downstream-fixture-PLAN.md`.

### T02: Autonomous-loop replay harness + clean verifier

See `tasks/T02-replay-harness-PLAN.md`.

### T03: Close-out regression gate + sub-gate clean verifiers

See `tasks/T03-regression-gate-PLAN.md`.

### T04: Phase-level fixture-permanence verifier + close-out sweep

See `tasks/T04-close-out-sweep-PLAN.md`.

## Task Dependencies

```
T01 ─→ T02 ─→ T03 ─→ T04
```

T01 stages the fixture and the fixture-shape verifier. T02 authors the replay harness against the T01 fixture and the clean verifier that invokes it. T03 wires the close-out regression gate and the two remaining sub-gate clean verifiers (corpus replay, run-all) — each sub-gate clean verifier wraps an existing harness/script and surfaces the canonical pass/fail line. T04 authors the fixture-permanence verifier (cross-cutting plan-level Truth-Check) and runs the full close-out sweep including `check-must-haves.sh` against this phase plan.

## Files Likely Touched

- `tests/fixtures/downstream-project/.claude/settings.json` (create)
- `tests/fixtures/downstream-project/README.md` (create)
- `tests/run-downstream-fixture.sh` (create)
- `scripts/verify/m028/p05-fixture-permanent.sh` (create)
- `scripts/verify/m028/p05-downstream-fixture-shape.sh` (create)
- `scripts/verify/m028/p05-downstream-fixture-clean.sh` (create)
- `scripts/verify/m028/p05-regression-gate.sh` (create)
- `scripts/verify/m028/p05-run-all-clean.sh` (create)
- `scripts/verify/m028/p05-corpus-replay-clean.sh` (create)
