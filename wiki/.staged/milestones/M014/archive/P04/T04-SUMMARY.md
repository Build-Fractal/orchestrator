---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P04"
milestone: "M014"
provides:
  - "scripts/specify/specify.sh probe-capture + three-way prompt wiring; conversus_gate_invocation JSONL shape; extended unit_close with conversus_invocations+adapter_verdicts; commands/specify.md Workflow 8-11 + Subcommand rewrite; FR-19 invoke-conversus-gate dry-run manifest; scripts/verify/m014-p04-specify-command-wiring.sh + m014-p04-three-way-prompt.sh gate verifiers"
requires:
  - "from:T02 what:scripts/knowledge/spec-complexity-probe.sh full body; from:T03 what:templates/conversus-presets/spec-pressure-test.yml preset; from:P01 what:scripts/specify/specify.sh P01 scaffold body; from:disk what:scripts/dispatch/adapters/tool/conversus.sh adapter with CONVERSUS_STUB support + gate-result fixtures"
affects:
  - "T07 phase-suite consumes both P04 gate verifiers; M014 dogfood loop first y-path invocation target; downstream above-threshold specs route through conversus review"
key_files:
  - "scripts/specify/specify.sh,commands/specify.md,scripts/verify/m014-p04-specify-command-wiring.sh,scripts/verify/m014-p04-three-way-prompt.sh"
key_decisions:
  - "dry-run probe runs against temp-staged scaffold so invoke-conversus-gate surfaces without live disk writes; hermetic gate verifier copies specify.sh + deps into mktemp scratch so PROJECT_ROOT self-resolves; adapter invocation uses --strict always; CONVERSUS_STUB=1 + CONVERSUS_STUB_VERDICT=PASS|BLOCK is the hermetic y-path mechanism"
patterns_established:
  - "dry-run probe-on-temp-staged-scaffold; hermetic-gate-copies-toolchain-into-scratch (T06 precedent); awk-first-occurrence-patch BSD-sed-safe edits"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P04/tasks/T04-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-23T00:54:32Z"
---

## What Was Built

T04 wires `scripts/specify/specify.sh` into the three-way (y/n/d) prompt flow on above-threshold probe verdicts and extends observability to emit `conversus_gate_invocation` JSONL records plus extended `unit_close` fields.

### specify.sh changes

1. **Probe-capture**: the step-8 fire-and-forget stub was replaced with a capturing invocation. The probe verdict (`probe=above-threshold reason=<criterion>` or `probe=below-threshold`) is parsed; above-threshold extracts `PROBE_REASON` from the verdict line.
2. **Three-way prompt block** inserted between probe and observability:
   - `--dry-run` emits a FR-19 `invoke-conversus-gate` manifest record and exits clean.
   - `--yes` silently defaults to `n` (SC-7 baseline).
   - No-TTY interactive falls through to default `n`.
   - Interactive with `[ -t 0 ] && [ -t 2 ]` prints `conversus pressure-test recommended (<reason>). [y/n/d] ` to stderr and reads one char, defaulting to `n` on EOF.
3. **y-path** invokes `scripts/dispatch/adapters/tool/conversus.sh gate --strict spec-pressure-test <spec> <spec-dir>/conversus/summary/final.md`. Exit codes map: `0 PASS`, `0 SKIPPED` (warn), `2 BLOCK` (surface), `1 ERROR` (halt with exit 1). Emits `conversus_gate_invocation` JSONL record `{gate_id, spec_path, verdict, adapter_version, llm_calls, elapsed_ms, estimated_cost_usd, source}`.
4. **d-path** invokes `bash "$0" split <spec-path>` and propagates non-zero exit codes.
5. **unit_close extension**: record now includes `conversus_invocations` (0|1) and `adapter_verdicts` (empty|PASS|BLOCK|SKIPPED|ERROR).
6. **Dry-run extension** (T04 deviation — see below): the pre-existing `--dry-run` block that exited before the probe was extended to stage a temp scaffolded spec, run the probe against it, and surface `invoke-conversus-gate` when above-threshold. Required because without this extension, the `--dry-run` above-threshold manifest record could never emit.

### commands/specify.md changes

- Workflow step 8 rewritten to the full FR-5 probe semantics (no more "stub" language).
- Workflow step 9 inserted as the US-3 three-way prompt, documenting `--yes`, `--dry-run`, and interactive paths plus exit-code handling.
- Steps renumbered: 10 observability, 11 lock release + stdout.
- Subcommand block replaced: `--amend` describes FR-14 three-case semantics; `split` describes LLM-assisted splitter with CC-only v1 gate and exit 3 fallback.

### Gate verifiers

- `scripts/verify/m014-p04-specify-command-wiring.sh` (35 lines): asserts Workflow + Subcommand prose updates landed and the P01 deferral language is gone.
- `scripts/verify/m014-p04-three-way-prompt.sh` (~100 lines): hermetic scratch workdir via `mktemp -d`. Copies specify.sh, probe, dual-write helper, template, adapter, preset, lock-manager, gate-result fixtures, and config.yml into the scratch so PROJECT_ROOT self-resolves inside it. Runs `--yes` against a 20-FR + contradiction-bait prose blob; asserts no `conversus/` dir created (default-n silent). Runs `--yes --dry-run` with `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS`; asserts `invoke-conversus-gate` record emits. Asserts `unit_close` has `conversus_invocations` field and at least one `spec_complexity_probe` record is in `execution-log.jsonl`.

## Smoke verification

Two out-of-band smoke harnesses exercised the adapter stub path:

- `/tmp/smoke-yes-2.sh` — confirmed SC-7 baseline: probe runs above-threshold, `--yes` silently picks `n`, no adapter invocation, unit_close shows `conversus_invocations=0`.
- `/tmp/smoke-y-path.sh` — confirmed the y-path end-to-end by awk-patching the scratch specify.sh's `--yes` branch to force `PROMPT_ANSWER="y"`, then invoking with `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS`. Result: adapter wrote `final.md` under `specs/<id>/conversus/summary/`, `conversus_gate_invocation` record emitted with correct shape (`verdict=PASS`, `gate_id=spec-pressure-test`, `adapter_version=m011-p07`), unit_close showed `conversus_invocations=1 adapter_verdicts=PASS`.

## Deviations from plan

1. **Dry-run probe extension**: The plan's probe-capture block handles `DRY_RUN=1` inline, but the pre-existing `--dry-run` early-exit (lines 159-169 of the P01 specify.sh) runs well before the probe insertion point and exits unconditionally. Without modification, the plan's dry-run `invoke-conversus-gate` record branch was unreachable and the T04 gate's `--dry-run` assertion would never pass. Resolution: extended the pre-existing dry-run block to scaffold a temp spec via `mktemp -d`, run the probe, emit the above-threshold `invoke-conversus-gate` record, then exit. No live-disk mutation (all writes inside the temp dir, cleaned up before exit). Task plan verbatim body preserved everywhere else.

2. **Gate verifier hermetic setup**: The plan's sample body uses a bare `mktemp -d` scratch and runs specify.sh from there, but specify.sh resolves PROJECT_ROOT from its own `BASH_SOURCE`, meaning running it from scratch CWD still binds to the live repo (confirmed by first-run failure: "slug already exists at .../specs/021-yn-test/"). Resolution: gate verifier copies specify.sh + all runtime dependencies into the scratch (pattern inherited from `tests/test-specify-shape.sh` T06 precedent). The adjusted verifier still matches the plan's assertion shape; only the setup was hardened.

## Blockers

None.
