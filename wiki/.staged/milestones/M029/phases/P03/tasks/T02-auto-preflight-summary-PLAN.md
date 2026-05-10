---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M029"
name: "orchestrator:auto preflight summary + AD-3 non-interactive policy + AD-4 oracle integration"
depends_on: ["T01"]
---

## Prerequisites

- `commands/auto.md` is on disk. `[ -f commands/auto.md ]` PASS at plan-authoring time.
- `scripts/dispatch/predictive-surface.sh` is on disk and exposes the M027-shipped surface `--description <text> --intensity quick|standard|full [--no-predict] [--yes] [--config-defaults <path>]`. `[ -f scripts/dispatch/predictive-surface.sh ]` PASS; verified at discuss-time per AD-4.
- `scripts/diagnostics/summarize-milestone.sh` is on disk from P02/T02 emitting the fixed-order key=value block via `--milestone <M###> --format=keys`. `[ -f scripts/diagnostics/summarize-milestone.sh ]` PASS.
- `scripts/state/detect-invocation-context.sh` is on disk from P01/T02 emitting the AD-1 env block. `[ -f scripts/state/detect-invocation-context.sh ]` PASS.
- T01 (`--live` + savings marker + config knob) has completed because the FR-8 threshold knob is documented as part of the same `display_thresholds:` family the preflight docstring cross-references.
- No path-collision: `tools/verify/m029-p03-auto-preflight-shape.sh` does not exist on disk. `[ ! -f tools/verify/m029-p03-auto-preflight-shape.sh ]` PASS.

## Description

T02 ships the FR-9 preflight surface in `commands/auto.md` plus its shape verifier:

1. **`commands/auto.md` `## Preflight Summary` section** (additive modification): a new H2 section prepended above the existing first H2 (or at a documented position near the top after the YAML frontmatter + H1 title), documenting the FR-9 + AD-3 + AD-4 contract:
   - **When the preflight fires**: at Standard or Full intensity (read from the EVALUATION frontmatter via the existing intensity-read code path); suppressed entirely at Quick intensity.
   - **What the preflight emits**: a block on stderr containing exactly four labeled lines — `Preflight Summary` header, `phase_count: N`, `dispatch_count_estimate: M`, `predicted_cost: est. ~$X.YY ± $Z.ZZ` (#Q-2 range form derived from `predictive-surface.sh`'s confidence interval).
   - **AD-3 non-interactive policy** (priority order):
     1. `--yes` flag present → emit preflight on stderr, do not prompt, proceed.
     2. `auto_proceed: true` in config ([M031](../../../../../milestones/M031/index.md) default) → emit preflight on stderr, do not prompt, proceed.
     3. Non-TTY stdin (CI, piped) with neither flag/config → emit preflight on stderr, then exit non-zero with byte-stable `M029_PREFLIGHT_NEEDS_CONFIRMATION` on stderr. CI consumers must opt in via `--yes` or `auto_proceed: true`. **No silent CI auto-accept.**
     4. TTY + neither flag/config → emit preflight, prompt, block on prompt.
   - **AD-4 oracle wrapper** documented verbatim in the docstring so future readers can reproduce the cost line by hand:
     ```
     bash scripts/dispatch/predictive-surface.sh \
       --description "$(bash scripts/diagnostics/summarize-milestone.sh M### --format=keys)" \
       --intensity standard
     ```
     The `predicted_cost` field is byte-identical to the `cost_standard_usd=` line emitted by this oracle (extracted via `grep -F 'cost_standard_usd=' | cut -d= -f2`).
   - **Why `--no-predict` is NOT in the oracle invocation**: `predictive-surface.sh` suppresses ALL stdout when `--no-predict` is set (see `scripts/dispatch/predictive-surface.sh:124` — `NO_PREDICT=1 → SUPPRESS=1`). The byte-identity contract operates on the un-suppressed cost block; the SC-8 oracle invocation deliberately omits `--no-predict`. This rationale is captured here AND in the spec amendment record entry per AD-4 (T05 deliverable).

2. **Shape verifier `tools/verify/m029-p03-auto-preflight-shape.sh`** (≥35 lines, AD-19 single-script-file):
   - Asserts `[ -f commands/auto.md ]`.
   - Asserts the file contains the H2 `## Preflight Summary` (or H2 with that title token).
   - Asserts the file contains literal `FR-9`, `AD-3`, `AD-4`, `M029_PREFLIGHT_NEEDS_CONFIRMATION`, `predictive-surface.sh`, `summarize-milestone.sh`, `auto_proceed`, `--yes`, `Quick intensity suppresses`, `cost_standard_usd`.
   - Asserts the file documents the four-priority AD-3 policy (the literal tokens `--yes`, `auto_proceed: true`, `M029_PREFLIGHT_NEEDS_CONFIRMATION`, and `TTY` all appear within ~20 lines of each other to confirm they're discussed together).
   - Asserts the file does NOT introduce any token suggesting the preflight writes to `.orchestrator/` (CON-1 read-only — search for forbidden literals like `>> .orchestrator`, `> .orchestrator`, `mkdir -p .orchestrator`).
   - Emits `PASS:`/`FAIL:` per assertion + `SUMMARY:` line. Exit 0 iff `fail=0`.

## Steps

1. **Read `commands/auto.md`** to identify the canonical insertion point. Per the existing skill-document convention (zoom-out, status, where), the `## Preflight Summary` section should land immediately after the YAML frontmatter + H1 title and the existing intro paragraph, before the first existing H2.

2. **Modify `commands/auto.md`** — prepend the `## Preflight Summary` section. The section MUST contain (in order):

   ```markdown
   ## Preflight Summary

   <!-- M029 / FR-9 / AD-3 / AD-4 — preflight summary block. -->

   At **Standard** or **Full** intensity, before entering the auto-loop, emit
   a four-line preflight block on **stderr**:

   ```
   Preflight Summary
   phase_count: <N>
   dispatch_count_estimate: <M>
   predicted_cost: est. ~$X.YY ± $Z.ZZ
   ```

   At **Quick** intensity, the preflight is suppressed entirely — `Preflight
   Summary` does NOT appear on stderr before `AUTO:READY` (SC-9 byte-stable
   invariant).

   ### Non-interactive policy (AD-3, #Q-G1)

   In priority order:

   1. **`--yes` flag present** → emit preflight on stderr, do not prompt,
      proceed.
   2. **`auto_proceed: true` in `.orchestrator/config.yml`** (M031 default) →
      emit preflight on stderr, do not prompt, proceed. The compound-change
      banner (`run-doctor.sh`) already informs the operator that auto-proceed
      is active.
   3. **Non-TTY stdin** (CI, piped) with neither flag nor config → emit
      preflight on stderr, then exit non-zero with the byte-stable string
      `M029_PREFLIGHT_NEEDS_CONFIRMATION` on stderr. CI consumers MUST opt
      in via `--yes` or `auto_proceed: true`. **No silent CI auto-accept.**
   4. **TTY + neither flag nor config** → emit preflight, prompt for
      confirmation, block on the prompt.

   The TTY / non-TTY discrimination reads `scripts/state/detect-invocation-context.sh`'s
   `renderer` field per AD-1 single-resolve.

   ### Oracle wrapper (AD-4 — SC-8 byte-identity contract)

   The `predicted_cost` field is byte-identical to the `cost_standard_usd=`
   line emitted by:

   ```bash
   bash scripts/dispatch/predictive-surface.sh \
     --description "$(bash scripts/diagnostics/summarize-milestone.sh M### --format=keys)" \
     --intensity standard
   ```

   Extract via:

   ```bash
   ORACLE=$(bash scripts/dispatch/predictive-surface.sh \
     --description "$(bash scripts/diagnostics/summarize-milestone.sh M### --format=keys)" \
     --intensity standard)
   COST=$(printf '%s\n' "$ORACLE" | grep -F 'cost_standard_usd=' | cut -d= -f2)
   ```

   Why **`--no-predict` is NOT in the oracle invocation**:
   `scripts/dispatch/predictive-surface.sh:124` suppresses ALL stdout when
   `--no-predict` is set (`NO_PREDICT=1 → SUPPRESS=1`). The byte-identity
   contract operates on the un-suppressed cost block. The spec amendment
   record entry per AD-4 (P03/T05) captures this clarification.

   ### Cost format (#Q-2)

   `predicted_cost: est. ~$X.YY ± $Z.ZZ` — range form derived from
   `predictive-surface.sh`'s confidence interval. The center value `$X.YY`
   is the `cost_standard_usd=` scalar; the spread `± $Z.ZZ` is computed
   from the difference between `cost_standard_usd` and the spread bounds
   the oracle's `cost_*_in_tokens` / `cost_*_out_tokens` rows imply.
   ```

   - The exact section text above is illustrative; the implementer can refine prose so long as every required literal token (`FR-9`, `AD-3`, `AD-4`, `M029_PREFLIGHT_NEEDS_CONFIRMATION`, `predictive-surface.sh`, `summarize-milestone.sh`, `auto_proceed`, `--yes`, `Quick intensity suppresses`, `cost_standard_usd`) appears in the file body and the four AD-3 priorities are documented in order.

3. **Author `tools/verify/m029-p03-auto-preflight-shape.sh`** (≥35 lines, executable, AD-19 single-script-file shape, bash 3.2):

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m029-p03-auto-preflight-shape.sh -- M029 P03 / T02 shape verifier
   # for the FR-9 + AD-3 + AD-4 Preflight Summary section in commands/auto.md.
   #
   # Bash 3.2 (MEM001). AD-19 straight-line bash. Negative-assertion discipline
   # for forbidden write-tokens (CON-1 read-only).

   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"

   FILE="commands/auto.md"
   pass=0
   fail=0

   _assert_present() {
     local needle="$1"
     local label="$2"
     if grep -F -q "$needle" "$FILE"; then
       pass=$(( pass + 1 ))
       printf 'PASS: %s\n' "$label"
     else
       fail=$(( fail + 1 ))
       printf 'FAIL: %s\n' "$label"
     fi
   }

   _assert_absent() {
     local needle="$1"
     local label="$2"
     if grep -F -q "$needle" "$FILE"; then
       fail=$(( fail + 1 ))
       printf 'FAIL: %s\n' "$label"
     else
       pass=$(( pass + 1 ))
       printf 'PASS: %s\n' "$label"
     fi
   }

   if [ ! -f "$FILE" ]; then
     printf 'FAIL: commands/auto.md missing\n'
     exit 1
   fi

   _assert_present 'Preflight Summary' 'preflight summary header present'
   _assert_present 'FR-9' 'FR-9 reference present'
   _assert_present 'AD-3' 'AD-3 reference present'
   _assert_present 'AD-4' 'AD-4 reference present'
   _assert_present 'M029_PREFLIGHT_NEEDS_CONFIRMATION' 'byte-stable confirmation token present'
   _assert_present 'predictive-surface.sh' 'oracle script reference present'
   _assert_present 'summarize-milestone.sh' 'oracle wrapper reference present'
   _assert_present 'auto_proceed' 'auto_proceed config reference present'
   _assert_present '--yes' '--yes flag reference present'
   _assert_present 'Quick intensity suppresses' 'quick-intensity suppression invariant present'
   _assert_present 'cost_standard_usd' 'cost_standard_usd byte-identity field present'
   _assert_present 'detect-invocation-context.sh' 'AD-1 single-resolve reference present'

   _assert_absent '>> .orchestrator' 'no append-write to .orchestrator/'
   _assert_absent 'mkdir -p .orchestrator' 'no .orchestrator/ creation in preflight surface'

   printf 'SUMMARY: m029-p03-auto-preflight-shape.sh pass=%d fail=%d\n' "$pass" "$fail"

   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   `chmod +x`.

4. **Hand-verification**: invoke `bash tools/verify/m029-p03-auto-preflight-shape.sh` and confirm exit 0 + `SUMMARY: ... pass=14 fail=0` (count adjusts based on actual assertion total).

## Must-Haves

This task addresses these P03 phase truths:
- `commands/auto.md` carries the `## Preflight Summary` section documenting FR-9 + AD-3 + AD-4 (Quick suppression, four-priority non-interactive policy, byte-identity cost contract via the documented oracle wrapper).

This task creates this P03 phase artifact:
- `tools/verify/m029-p03-auto-preflight-shape.sh`

## Verification

```bash
bash tools/verify/m029-p03-auto-preflight-shape.sh
```

## Inputs

### From Previous Tasks (P03/T01)

- `display_thresholds.compression_savings_pct` config knob — referenced from the preflight docstring as adjacent operator-knob context, NOT consumed at preflight render time.

### From Disk (Pre-existing — closed milestones)

- `scripts/dispatch/predictive-surface.sh` (M027/P02/T03)
  - Key API: `--description <text> --intensity quick|standard|full [--no-predict] [--yes] [--config-defaults <path>]`
  - Behavioral contract: emits a multi-line cost block to stdout when not suppressed; suppressed (zero stdout) when `--no-predict` OR `--yes` OR `ORCHESTRATOR_AUTO=1` OR `predictive_cost_surface=false` config OR `intensity=quick`.
  - Output shape: `predictive_cost_surface (M027/P02)` header + `recommended: <intensity>` + `# cost estimates (M027/P01)` + per-tier `cost_<tier>_usd=...` / `cost_<tier>_in_tokens=...` / `cost_<tier>_out_tokens=...` / `cost_<tier>_quality=...` lines + `override:` prompt line.
- `scripts/diagnostics/summarize-milestone.sh` (M029/P02/T02)
  - Key API: `--milestone <M###> --format=keys|text` emits a fixed-order key=value block: `phase_count=...`, `phases_complete=...`, `tasks_remaining=...`, `intensity=...`.
- `scripts/state/detect-invocation-context.sh` (M029/P01/T02)
  - Key API: emits `renderer=<tui|json|plain> exit_code_scheme=<interactive|governance> default_provider=<id>` env block on stdout per AD-1.

### From Disk (Pre-existing — modify-in-place)

- `commands/auto.md` — top-of-file additive modification only.

## Constraints

- **AD-19 straight-line bash for the verifier**: `_assert_present` and `_assert_absent` are top-of-script function bodies; `Check:` invocation is `bash <abs-path>` per AD-19 single-script-file discipline. The function-body MEM004 carve-out applies.
- **Bash 3.2 (MEM001)**: parallel scalars, no `declare -A`, no `<<<` herestring.
- **CON-1 / FR-14 read-only**: `commands/auto.md` is documentation; no executable surface in this task. Negative-assertion verifier guards against accidental write-token introduction.
- **CON-7 / AD-8 knowledge-layer-boundary**: T02 introduces NO new JSONL events, NO [M020](../../../../../milestones/M020/index.md) changes, NO [M027](../../../../../milestones/M027/index.md) surface changes. The skill doc cross-references existing M027 surfaces; it does NOT extend them.
- **AD-3 priority order is byte-stable**: the four-tier policy (`--yes` → `auto_proceed: true` → non-TTY refusal → TTY prompt) appears in that order in the docstring. Re-ordering breaks SC-8 / SC-9 acceptance reasoning.
- **AD-4 oracle invariant**: the documented oracle invocation MUST omit `--no-predict` (otherwise the byte-identity contract on `cost_standard_usd=` is unsatisfiable because output is suppressed). This is a load-bearing departure from the pre-discuss-time roadmap text — captured in the spec amendment record (T05).
- **Path-collision rule 6**: `tools/verify/m029-p03-auto-preflight-shape.sh` does not exist on disk at plan-authoring time.

## Expected Output

After T02 completes:
- `commands/auto.md` — `## Preflight Summary` section landed; existing surfaces unchanged.
- `tools/verify/m029-p03-auto-preflight-shape.sh` — exists, executable, exits 0.
- A summary file at [`.orchestrator/milestones/M029/phases/P03/tasks/T02-auto-preflight-summary-SUMMARY.md`](../../../../../milestones/M029/phases/P03/tasks/T02-auto-preflight-summary-SUMMARY.md) documents the deliverables.

## Notes

Expected verifier output:
```
PASS: preflight summary header present
PASS: FR-9 reference present
PASS: AD-3 reference present
PASS: AD-4 reference present
PASS: byte-stable confirmation token present
PASS: oracle script reference present
PASS: oracle wrapper reference present
PASS: auto_proceed config reference present
PASS: --yes flag reference present
PASS: quick-intensity suppression invariant present
PASS: cost_standard_usd byte-identity field present
PASS: AD-1 single-resolve reference present
PASS: no append-write to .orchestrator/
PASS: no .orchestrator/ creation in preflight surface
SUMMARY: m029-p03-auto-preflight-shape.sh pass=14 fail=0
```

This task is documentation-only — no executable surface lands here. The SC-8 + SC-9 acceptance scripts in T04 will exercise the documented surface end-to-end against fixture milestones; this task is the design contract per Principle III.

The `predictive-surface.sh` source-code line `124` (`NO_PREDICT=1 → SUPPRESS=1`) is the load-bearing fact behind the AD-4 amendment. Any future planner who wants to add `--no-predict` back to the oracle MUST first re-read that line and confirm the semantics still match — `--no-predict` may at some point gain a "suppress prompt only, keep cost output" interpretation, in which case the SC-8 oracle would be reconsidered. As of 2026-05-06 the suppression is total.

Reasonably-foreseeable refactor path: if a future user demands a CLI-surface `bash scripts/dispatch/auto-preflight.sh` script (as opposed to the LLM-skill-driven docstring contract this task ships), it would land as a separate post-launch fast-follow. M029's launch posture keeps the preflight as a documented contract that the LLM agent reads and emits, not a Bash surface — this matches the design of every other `commands/*.md` skill document (where, status, context). The shape verifier is sufficient to gate the contract.
