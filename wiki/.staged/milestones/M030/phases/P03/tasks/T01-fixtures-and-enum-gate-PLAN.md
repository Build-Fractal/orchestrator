---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M030"
name: "P03 fixture plans + overlay configs + override-source-enum gate (preflight)"
depends_on: []
---

## Prerequisites

- scripts/dispatch/dispatch-interface.sh exists in its post-P02 form: `_di_emit_dispatch_usage` body at lines ~185-392; shadow path at lines ~279-324; happy-path printf at line ~332; degradation printf at line ~364.
- scripts/dispatch/classify-task.sh exists and emits `character=<mechanical|standard|novel>` + `confidence=<high|medium|low>` to stdout (P01/T02 close).
- templates/model-routing.yml exists with `routing:` (3 characters x 3 runtimes), `resolution:` (3 tiers x 3 runtimes), `cost_rates:` (3 tiers) sections (P01/T03 close).
- tools/verify/p02-additive-schema.sh exists and exits 0 against the post-P02 dispatch-interface.sh (P02/T04 close).
- tools/verify/p02-phase-suite.sh exists and exits 0 (P02/T04 close).
- tests/fixtures/m030-p02/round-trip-stage/ exists with phases/P01/tasks/M001-T01-stage-PLAN.md + T01-stage-PAYLOAD.md + intensity-metadata.txt — provides the round-trip pattern T01 mirrors at tests/fixtures/m030-p03/round-trip-stage/.

Plan-time prerequisite-existence verification: every path above is asserted by P02 close (verified via `scripts/state/derive-phase.sh .orchestrator/milestones/M030`); the post-P02 `dispatch-interface.sh` shape was inspected during plan-authoring (head -400 reads cleanly; lines 279-324 contain the existing P02 shadow-classifier-and-resolution block; line 332 is the happy-path shadow-on printf, line 364 is the degradation shadow-on printf).

## Description

T01 ships before any work on `scripts/dispatch/dispatch-interface.sh` so the override_source enum invariant is mechanically enforced at the moment T02 amends the emitter. Three deliverable groups that ship as a single coherent change:

1. **Fixture files** under `tests/fixtures/m030-p03/`:
   - Three plan files exercising the three plan-frontmatter override shapes (override+smart, no-override mechanical, override-fast-vs-floor).
   - Four config files exercising the four overlay shapes (routing-disabled, min-tier-smart, killswitch-and-floor, baseline-no-overrides).
   - One round-trip stage directory mirroring the P02 stage shape (intensity-metadata.txt + payload.txt) — staged for T02/T03 round-trip dispatch invocations.

2. **`tools/verify/p03-override-source-enum.sh`** — gates the closed enum invariant. Runs four scenarios under `M030_SHADOW_MODE=1 CLAUDECODE=1`: (a) plain plan + baseline config -> override_source token present with value `none` (post-T02; pre-T02 the gate is vacuously satisfied because the field is absent entirely), (b) plain plan + routing-disabled config -> override_source=disabled, (c) override-smart plan + baseline config -> override_source=plan_frontmatter, (d) plain plan + min-tier-smart config -> override_source=milestone_floor. Plus one shadow-off scenario asserting zero override_source tokens. T01 ships this verifier in a "pre-amendment-tolerant" mode: when the emitted record contains no `override_source` token AT ALL (the pre-T02 reality), the enum check is satisfied (the field has not yet been added, so it cannot violate the closed enum). After T02 lands, the same verifier asserts the field is present AND its value is in the closed enum.

3. **`tools/verify/p03-additive-schema.sh`** — thin pass-through wrapper that invokes `tools/verify/p02-additive-schema.sh` and asserts exit 0. The P02 SC-11 contract continues to hold under HEAD; T01's wrapper is a phase-suite-friendly delegation so `p03-phase-suite.sh` can include the SC-11 gate inline without re-implementing the round-trip.

T01 ends green: all artifacts on disk, both verifiers pass against the pre-amendment `dispatch-interface.sh` (override-source-enum gate green via the pre-amendment-tolerant branch; additive-schema gate green via P02 pass-through).

### Pre-amendment-tolerance shape (load-bearing)

The override-source-enum verifier MUST be runnable BEFORE T02 amends `dispatch-interface.sh`. Pre-T02, the emitted JSONL record contains no `override_source` field; the verifier's enum check accepts this case as PASS (zero matches, zero violations). Post-T02, the emitted record contains exactly one `override_source` field whose value MUST be in the closed enum {`plan_frontmatter`, `milestone_floor`, `disabled`, `shadow_gate_blocked`, `none`}; non-enum values FAIL. The verifier's shape:

```bash
# Per scenario, capture the appended JSONL line.
line="$(tail -n 1 "$log_file")"

# Count override_source tokens. Zero is acceptable (pre-T02 emission); exactly
# one with an enum-valid value is acceptable (post-T02 emission); anything
# else FAILs.
token_count=$(printf '%s' "$line" | grep -o '"override_source"' | wc -l | tr -d ' ')
if [ "$token_count" = "0" ]; then
  pass_scenario "$scenario_name (pre-amendment, field absent)"
elif [ "$token_count" = "1" ]; then
  # Extract value via grep+sed; assert it is in the closed enum.
  value="$(printf '%s' "$line" | grep -oE '"override_source":"[^"]*"' | sed -E 's/.*:"([^"]*)".*/\1/')"
  case "$value" in
    plan_frontmatter|milestone_floor|disabled|shadow_gate_blocked|none)
      pass_scenario "$scenario_name (post-amendment, value=$value)" ;;
    *)
      fail_scenario "$scenario_name (override_source value '$value' not in closed enum)" ;;
  esac
else
  fail_scenario "$scenario_name (override_source token count $token_count, expected 0 or 1)"
fi
```

### Shadow-off scenario

The shadow-off scenario (CLAUDECODE unset OR M030_SHADOW_MODE unset) MUST emit ZERO override_source tokens regardless of pre/post-T02 amendment state. This is the additive-only-when-shadow-on invariant — under shadow off, the four P02 fields AND the new P03 field are all absent. The verifier asserts `token_count == 0` (strict zero, no tolerance) for the shadow-off case.

## Steps

1. **Confirm P02 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p02-additive-schema.sh
   bash tools/verify/p02-phase-suite.sh
   ```

   Expected: both exit 0. If either fails, P02 must be re-opened (out-of-scope for T01 — block T01 with a STUCK signal).

2. **Author the fixture plan files.** Create three plans under `tests/fixtures/m030-p03/plans/`:

   - `plan-with-frontmatter-override.md`: frontmatter declares `model_override: smart`; body has the mechanical-classifier signature (explicit `## Steps` section with file paths + bash verifiers; ≤3 file targets; unambiguous `## Verification` block).
   - `plan-mechanical-no-override.md`: frontmatter declares no `model_override`; body identical mechanical signature.
   - `plan-frontmatter-fast-vs-floor.md`: frontmatter declares `model_override: fast`; body identical mechanical signature.

   The frontmatter shape MUST be standard YAML (the same shape `classify-task.sh` already parses):

   ```yaml
   ---
   schema_version: "1.0"
   type: task-plan
   task: "T99"
   phase: "P99"
   milestone: "M999"
   name: "<fixture name>"
   model_override: "smart"
   ---
   ```

   The path encodes `M999/P99/T99` so `dispatch-interface.sh`'s `MILESTONE_ID` regex extraction succeeds.

3. **Author the fixture config files.** Create four configs under `tests/fixtures/m030-p03/configs/`:

   - `config-baseline.yml` — minimal config with no `model_routing:` block (the no-override-no-floor baseline).
   - `config-with-routing-disabled.yml` — `model_routing_enabled: false` at the top level (NOT under `model_routing:` — kill switch is its own root key per FR-13 and the P03 amendment shape).
   - `config-with-min-tier-smart.yml` — `model_routing:\n  min_tier: smart`.
   - `config-with-killswitch-and-floor.yml` — both knobs: `model_routing_enabled: false` at top level AND `model_routing:\n  min_tier: smart`. This is the SC-7a compound case.

   Each config file uses standard `schema_version: "1.0"` + `type: orchestrator-config` frontmatter to match the existing `.orchestrator/config.yml` shape.

4. **Stage the round-trip directory.** Create `tests/fixtures/m030-p03/round-trip-stage/` with two files:

   - `intensity-metadata.txt` — single line `intensity: standard\nmodel: <runtime-default-model-id>`. The `model:` field is the runtime-default channel `dispatch-interface.sh` reads when `${ORCH_MODEL:-}` is unset.
   - `payload.txt` — any nontrivial payload bytes (≥256 bytes; the byte count drives `chars_to_tokens_quartile` but is not load-bearing for the override-source check).

   The round-trip stage does NOT need its own task-plan files — T02/T03 use the plans authored in Step 2 as the `--task-plan` argument, and the round-trip stage provides the payload + intensity-metadata fixtures.

5. **Author `tools/verify/p03-additive-schema.sh`** — the thin pass-through wrapper:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p03-additive-schema.sh — Pass-through wrapper over P02 SC-11 gate.
   set -uo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   p02_gate="$PROJECT_ROOT/tools/verify/p02-additive-schema.sh"
   if [ ! -f "$p02_gate" ]; then
     echo "FAIL: p02-additive-schema.sh missing (P02 gate not on disk)"
     echo "SUMMARY: p03-additive-schema.sh pass=0 fail=1"
     exit 1
   fi
   bash "$p02_gate"
   rc=$?
   if [ "$rc" -eq 0 ]; then
     echo "PASS: p02-additive-schema.sh delegated check (SC-11 byte-equality)"
     echo "SUMMARY: p03-additive-schema.sh pass=1 fail=0"
     exit 0
   fi
   echo "FAIL: p02-additive-schema.sh exited $rc"
   echo "SUMMARY: p03-additive-schema.sh pass=0 fail=1"
   exit 1
   ```

6. **Author `tools/verify/p03-override-source-enum.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Per-scenario pass/fail accumulators. Five scenarios:

   - **Scenario A — shadow-on, baseline plan + baseline config, no overrides.** Stage a fresh log file, set `M030_SHADOW_MODE=1`, `CLAUDECODE=1`, `ORCHESTRATOR_ROOT=tests/fixtures/m030-p03/orch-root-baseline/` (a tmp dir whose `.orchestrator/config.yml` is the baseline fixture). Invoke `dispatch-interface.sh` with `--task-plan tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md --payload tests/fixtures/m030-p03/round-trip-stage/payload.txt --intensity-metadata tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt --backend stub`. Read the appended JSONL line. Apply the pre-amendment-tolerant enum check (pre-T02: zero tokens PASS; post-T02: exactly one with value `none` PASS).
   - **Scenario B — shadow-on, baseline plan + routing-disabled config.** Same staging with `ORCHESTRATOR_ROOT` pointing at a tmp dir whose `.orchestrator/config.yml` is `config-with-routing-disabled.yml`. Apply pre-amendment-tolerant enum check (pre-T02: zero tokens PASS; post-T02: exactly one with value `disabled` PASS).
   - **Scenario C — shadow-on, override-smart plan + baseline config.** Same staging, `--task-plan tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md`. Apply check (pre-T02: zero PASS; post-T02: value `plan_frontmatter` PASS).
   - **Scenario D — shadow-on, baseline plan + min-tier-smart config.** Same staging, config = `config-with-min-tier-smart.yml`. Apply check (pre-T02: zero PASS; post-T02: value `milestone_floor` PASS).
   - **Scenario E — shadow-off, override-smart plan + min-tier-smart config (most-overlay-rich case).** `unset M030_SHADOW_MODE; export CLAUDECODE=1`. Apply STRICT zero-tokens check (zero PASS; any tokens FAIL — the shadow-off branch must NOT emit override_source).

   Per-scenario pass/fail accumulators; final `SUMMARY: p03-override-source-enum.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

7. **Stage the per-scenario `ORCHESTRATOR_ROOT` tmp dirs.** Each scenario invocation needs an `ORCHESTRATOR_ROOT` whose `.orchestrator/config.yml` is the scenario's fixture config. The verifier creates these tmp dirs at runtime via `mkdir -p "$tmp_root/.orchestrator"` + `cp <fixture-config> "$tmp_root/.orchestrator/config.yml"`. Cleanup: `rm -rf "$tmp_root"` after each scenario. Use `mktemp -d` for the tmp dir name to avoid collisions across parallel runs.

8. **Run all T01 verifiers as a self-check:**

   ```bash
   bash tools/verify/p03-additive-schema.sh
   bash tools/verify/p03-override-source-enum.sh
   ```

   Expected: both exit 0. If `p03-override-source-enum.sh` Scenario E fails (override_source tokens leaking under shadow-off), the P02 emit branches were misordered — investigate `dispatch-interface.sh` lines 326-389 for shadow-off branches accidentally emitting the new field. Pre-T02 this should not happen because the new field has not been added; if Scenario E fails here, T01 has a bug.

9. **Stage and commit.** Stage `tests/fixtures/m030-p03/`, `tools/verify/p03-additive-schema.sh`, `tools/verify/p03-override-source-enum.sh`. Author commit message file via Write to /tmp/p03-t01-commit-msg.txt; commit with `git commit -F /tmp/p03-t01-commit-msg.txt`. Recommended subject: `M030/P03/T01: P03 fixture plans + overlay configs + override-source-enum gate (preflight)`.

## Must-Haves

This task satisfies the phase truths:

- "scripts/dispatch/dispatch-interface.sh emits an override_source field on every shadow-on dispatch_usage record drawn from the closed enum..." — gated by `tools/verify/p03-override-source-enum.sh` (pre-amendment-tolerant; T02 will tighten the gate by populating the field).
- "SC-11 byte-equality re-confirmed against P02's pre-M030 fixture..." — gated by `tools/verify/p03-additive-schema.sh` (pass-through wrapper over P02's SC-11 gate).

## Verification

```bash
bash tools/verify/p03-additive-schema.sh
bash tools/verify/p03-override-source-enum.sh
```

Each verifier uses single-script-file shape per AD-19. Both must exit 0 before T01 closes.

## Inputs

### From Previous Tasks

None directly (T01 is the first task in P03). T01 reads P02 deliverables on disk:

- tools/verify/p02-additive-schema.sh (from M030/P02/T01) — Key API: `bash <path>` exits 0 with `SUMMARY: p02-additive-schema.sh pass=N fail=0` confirming SC-11 byte-equality holds for `dispatch-interface.sh` shadow-off emit.
- tools/verify/p02-phase-suite.sh (from M030/P02/T04) — Key API: `bash <path>` exits 0 with `SUMMARY: p02-phase-suite.sh pass=9 fail=0` aggregating all P02 sub-gates.
- tests/fixtures/m030-p02/round-trip-stage/ (from M030/P02/T01) — Key API: contains `phases/P01/tasks/M001-T01-stage-PLAN.md` + `T01-stage-PAYLOAD.md` + `intensity-metadata.txt` — the P02 round-trip pattern T01 mirrors for P03.

### From Disk (Pre-existing)

- scripts/dispatch/dispatch-interface.sh — pre-T02 form. T01 invokes the emitter via round-trip dispatch under shadow-on; the emitted JSONL line is the verifier input. T01 does NOT modify this file.
  - Key API: `bash scripts/dispatch/dispatch-interface.sh --task-plan <path> --payload <path> --intensity-metadata <path> --backend stub` — runs a stub-backend dispatch and appends one `dispatch_usage` JSONL record to `${ORCH_ROOT:-.orchestrator}/milestones/<milestone-id>/execution-log.jsonl` (or `${ORCH_ROOT}/execution-log.jsonl` if `ORCH_ROOT` is itself a milestone dir). Under shadow-on (`M030_SHADOW_MODE=1` AND `CLAUDECODE=1`), the record contains the four P02 additive fields (`model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`) plus `classifier_confidence`. Under shadow-off, none of those appear.
- scripts/dispatch/classify-task.sh — P01 classifier. T01 indirectly exercises it via the shadow-on dispatch.
  - Key API: `bash scripts/dispatch/classify-task.sh <plan-path>` writes two stdout lines: `character=<mechanical|standard|novel>` and `confidence=<high|medium|low>`. Bash 3.2-safe.
- templates/model-routing.yml — P01 routing-table SSOT. T01 does not read directly; the shadow path inside `dispatch-interface.sh` consumes it.
- scripts/dispatch/adapters/backend/stub.sh — minimal adapter for round-trip harness invocations.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. T01 ships verifier scripts; the inline `Check:` commands in this task plan and the parent phase plan invoke those scripts.
- **AP-009 compound-chain-gt2 (verifier shape)**: T01 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>.txt; grep ... < /tmp/<f>.txt > /tmp/<g>.txt`. Each `Bash` tool invocation in `auto-loop` runs through the harness shape-guard; `bash <verifier>.sh` is the safe invocation shape.
- **Pre-amendment tolerance**: `p03-override-source-enum.sh` MUST exit 0 against the pre-T02 `dispatch-interface.sh` (where the field is absent). The post-T02 tightening of the gate (zero tokens FAIL the post-amendment scenarios A-D) is T02's responsibility, not T01's. T01 SHIPS the gate in pre-amendment-tolerant mode.
- **CON-2/FR-19/SC-11 (additive-only schema)**: shadow-off Scenario E MUST emit zero `override_source` tokens regardless of plan or config overlay state. Pre-T02 this is the universal case (the field doesn't exist yet); post-T02 it remains the case (shadow-off branch ignores all override-resolution logic).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The verifier uses parallel-indexed-array pattern when accumulating per-scenario state.
- **No new hardcoded model IDs**: T01's verifier reads the JSONL `model_used` value but does NOT compare it against a literal `claude-haiku-4-5` etc. Concrete model IDs flow through `templates/model-routing.yml resolution.<tier>.claude-code` exclusively (CON-3).
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T01's verifier invokes `bash tools/verify/<path>.sh` directly — `run-probe.sh` is reserved for `/tmp/`, `/var/folders/`, `<repo>/tmp/` paths.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T01 introduces no SQL — N/A.

## Expected Output

- `tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md` — fixture plan with `model_override: smart` frontmatter + mechanical body signature.
- `tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md` — fixture plan with no override + mechanical body signature.
- `tests/fixtures/m030-p03/plans/plan-frontmatter-fast-vs-floor.md` — fixture plan with `model_override: fast` frontmatter + mechanical body signature.
- `tests/fixtures/m030-p03/configs/config-baseline.yml` — baseline config (no overrides).
- `tests/fixtures/m030-p03/configs/config-with-routing-disabled.yml` — `model_routing_enabled: false` at top level.
- `tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml` — `model_routing.min_tier: smart`.
- `tests/fixtures/m030-p03/configs/config-with-killswitch-and-floor.yml` — both knobs.
- `tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt` — single-line metadata with `intensity:` + `model:` fields.
- `tests/fixtures/m030-p03/round-trip-stage/payload.txt` — nontrivial payload (≥256 bytes).
- `tools/verify/p03-additive-schema.sh` — green: pass-through delegation to P02 SC-11 gate.
- `tools/verify/p03-override-source-enum.sh` — green under pre-amendment-tolerant mode (pre-T02): all five scenarios PASS because shadow-on records have zero override_source tokens (vacuously enum-compliant) AND shadow-off Scenario E has zero tokens (strictly compliant).
- `bash tools/verify/p03-additive-schema.sh` exits 0 with `SUMMARY: p03-additive-schema.sh pass=1 fail=0`.
- `bash tools/verify/p03-override-source-enum.sh` exits 0 with `SUMMARY: p03-override-source-enum.sh pass=5 fail=0`.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p03-additive-schema.sh` -> delegation to p02-additive-schema.sh; `SUMMARY: p03-additive-schema.sh pass=1 fail=0`, exit 0.
- `bash tools/verify/p03-override-source-enum.sh` -> 5 scenarios pass; `SUMMARY: p03-override-source-enum.sh pass=5 fail=0`, exit 0.

The pre-amendment-tolerant pattern is the same graduation discipline P02/T01 used for the SC-11 byte-equality gate: ship the verifier BEFORE the deliverable that satisfies its strictest form, with a fall-through branch that accepts the pre-amendment shape as PASS. Once T02 amends the emitter, the strictest branch activates and the gate becomes a hard floor.

When T02's amendment lands, T02 will re-run `bash tools/verify/p03-override-source-enum.sh` and observe the post-amendment branch fire for Scenarios A-D (token_count=1, value enum-checked). If T02's amendment is wrong (e.g., emits `override_source=invalid_value`), the enum check FAILs and T02 must re-author the emit branch.

The fixture-config shape — `model_routing_enabled` at the top level vs. `model_routing.min_tier` nested — matches the spec's FR-13 + FR-12 declarations literally. The kill switch is a top-level boolean per FR-13's "kill switch is the operator's panic button" framing; `min_tier` is nested under `model_routing` because it is one of several routing-table-related knobs (others land in M030/P05). This shape is documented in `references/model-routing.md` § Operator Overrides (T03 deliverable).
