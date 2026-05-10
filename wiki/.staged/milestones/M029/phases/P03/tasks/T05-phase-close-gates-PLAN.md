---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P03"
milestone: "M029"
name: "P03 close gates: phase-suite + p03-acceptance-battery + readonly-invariant + scope-guard + spec amendment record (AD-4)"
depends_on: ["T04"]
---

## Prerequisites

- All P03 deliverables T01–T04 are on disk and their individual verifiers exit 0:
  - T01: `scripts/diagnostics/render-position.sh --live` + `display_thresholds.compression_savings_pct` knob + `tools/verify/m029-p03-{render-position-live-shape, display-thresholds-config-shape}.sh`.
  - T02: `commands/auto.md` `## Preflight Summary` section + `tools/verify/m029-p03-auto-preflight-shape.sh`.
  - T03: `commands/start.md` `## --auto-chain Flag` + `scripts/lifecycle/start.sh` chain-driver + `tools/verify/m029-p03-auto-chain-shape.sh`.
  - T04: `tests/m029-acceptance/measure-live-tail-latency.sh` + 4 SC acceptance scripts + 3 fixture trees + 5 T04 shape verifiers (`m029-p03-{measure-live-tail-latency-shape, sc7-shape, sc8-shape, sc9-shape, sc10-shape}.sh`).
- The P01 phase-suite at `tools/verify/m029-p01-phase-suite.sh` and P02 phase-suite at `tools/verify/m029-p02-phase-suite.sh` are on disk as structural precedents.
- The P02 readonly-invariant at `tools/verify/m029-p02-readonly-invariant.sh` and scope-guard at `tools/verify/m029-p02-scope-guard.sh` are on disk as patterns to mirror.
- `specs/037-roadmap-visibility-cli-ux/spec.md` is on disk and writable.
- No file currently lives at any T05 deliverable path (path-collision rule 6 verified at plan-authoring time):
  - `[ ! -f tests/m029-acceptance/p03-acceptance-battery.sh ]` PASS
  - `[ ! -f tools/verify/m029-p03-acceptance-battery-shape.sh ]` PASS
  - `[ ! -f tools/verify/m029-p03-readonly-invariant.sh ]` PASS
  - `[ ! -f tools/verify/m029-p03-scope-guard.sh ]` PASS
  - `[ ! -f tools/verify/m029-p03-spec-amendment-shape.sh ]` PASS
  - `[ ! -f tools/verify/m029-p03-phase-suite.sh ]` PASS

## Description

T05 ships the **P03 close-gate scaffolding** (mirroring P02/T05's pattern) plus the AD-4 spec amendment record entry:

1. **`tests/m029-acceptance/p03-acceptance-battery.sh`** — wraps the four P03 SC acceptance scripts (SC-7, SC-8, SC-9, SC-10) and emits `BATTERY: pass=4 fail=0` per the M030/[M031](../../../../../milestones/M031/index.md) acceptance-battery convention. Re-used by `tests/m029-acceptance/run-acceptance-battery.sh` (T06 deliverable) alongside the P01 + P02 batteries.

2. **`tools/verify/m029-p03-acceptance-battery-shape.sh`** — asserts the battery script's shape AND runs it behaviorally (mirrors P02/T05 pattern of combining shape-check + behavioral run in the same verifier).

3. **`tools/verify/m029-p03-readonly-invariant.sh`** — extends the P02 sentinel-file precursor pattern to cover P03's surfaces:
   - Runs `bash scripts/diagnostics/render-position.sh --live --milestone M029` for ~1.5s under a sentinel-mtime guard (kill-after-timeout via `( sleep 1.5; kill $RENDERER_PID ) &`).
   - Runs the auto-preflight contract surface against the SC-8 fixture.
   - Runs `bash scripts/lifecycle/start.sh --project-dir <tmpdir> --auto-chain --yes` against a fresh tmp-fixture seeded from `auto-chain-greenfield.fixture`.
   - Asserts no `.orchestrator/` file under the LIVE project tree (excluding sentinel + start-state markers when `--auto-chain` is the unit under test) has an mtime newer than the sentinel.
   - Mirrors P02's project-tree readonly-invariant; LIVE-tree variant complements the FIXTURE-tree variants in SC-14.

4. **`tools/verify/m029-p03-scope-guard.sh`** — captures `git status --porcelain=v1` output, classifies each touched path against the P03 allowlist + denylist:
   - **Allowlist** (paths the P03 plan declares as `Files Likely Touched`):
     - `scripts/diagnostics/render-position.sh`
     - `references/file-formats.md`
     - `templates/orchestrator-config-default.yml`
     - `scripts/state/read-config.sh`
     - `commands/auto.md`
     - `commands/start.md`
     - `scripts/lifecycle/start.sh`
     - `specs/037-roadmap-visibility-cli-ux/spec.md`
     - `tests/m029-acceptance/measure-live-tail-latency.sh`
     - `tests/m029-acceptance/p03-*.sh` (recursive glob)
     - `tests/m029-acceptance/run-acceptance-battery.sh`
     - `tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/...` (recursive)
     - `tests/m029-acceptance/fixtures/auto-preflight-quick.fixture/...` (recursive)
     - `tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/...` (recursive)
     - `tools/verify/m029-p03-*.sh` (recursive glob)
     - `.orchestrator/milestones/M029/phases/P03/...` (plan/summary churn)
     - `.orchestrator/milestones/M029/M029-VALIDATED` (T06 deliverable)
     - [`.orchestrator/milestones/M029/M029-SUMMARY.md`](../../../../../milestones/M029/M029-SUMMARY.md) (T06 deliverable)
     - `.orchestrator/milestones/M029/execution-log.jsonl` (T06 milestone-grain unit_close append)
   - **Denylist** (paths that must NEVER be touched by P03):
     - `commands/init.md` ([M033](../../../../../milestones/M033/index.md) surface)
     - `scripts/lifecycle/auto-loop.sh` (Principle XV — M029 does not touch the auto loop)
     - `scripts/diagnostics/metrics-rollup.sh`, `scripts/diagnostics/efficiency-footer.sh` ([M027](../../../../../milestones/M027/index.md) read-only consumer per CON-7/AD-8)
     - `scripts/dispatch/predictive-surface.sh` (M027 read-only consumer)
     - `.orchestrator/integrations/github.json` (CON-4 / FR-11)
     - [`.orchestrator/KNOWLEDGE.md`](../../../../../knowledge.md), [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) ([M020](../../../../../milestones/M020/index.md) schema authority)
   - On any deny hit: `FAIL: scope violation by <path>` + non-zero exit. Unclassified: `WARN:` (advisory, P02 precedent).

5. **`specs/037-roadmap-visibility-cli-ux/spec.md` Spec Amendment Record entry (AD-4)** — appended to the existing spec body (or under a new `## Spec Amendment Record` section if absent):

   ```markdown
   ## Spec Amendment Record

   ### 2026-05-06 — AD-4 SC-8 oracle interface clarification (#Q-G2 P0 resolution)

   **Original SC-8 oracle as drafted in spec.md** (lines ~152):
   > `bash scripts/dispatch/predictive-surface.sh --milestone <M###>` output

   **Issue surfaced at orchestrator:discuss**: `scripts/dispatch/predictive-surface.sh` does NOT accept `--milestone`. The shipped surface is `--description <text> --intensity quick|standard|full [--no-predict] [--yes] [--config-defaults <path>]`. Captured as RISK-2 / `#Q-G2` at the conversus gate.

   **Decision (AD-4, finalized at orchestrator:discuss 2026-05-05)**: Amend SC-8 to use the shipped surface via an M029-owned wrapper rather than extend `predictive-surface.sh` (which is closed under M027 / CON-7 knowledge-layer boundary).

   **Amended SC-8 oracle wrapper**:
   ```bash
   bash scripts/dispatch/predictive-surface.sh \
     --description "$(bash scripts/diagnostics/summarize-milestone.sh M### --format=keys)" \
     --intensity standard
   ```

   `scripts/diagnostics/summarize-milestone.sh` is a P02-owned read-only helper that emits a deterministic four-key `key=value` block (`phase_count`, `phases_complete`, `tasks_remaining`, `intensity`) for a given milestone. The block becomes the `--description` argument to `predictive-surface.sh`.

   **Why `--no-predict` is NOT used in the oracle invocation**: `scripts/dispatch/predictive-surface.sh:124` short-circuits to zero stdout when `--no-predict` is set (`NO_PREDICT=1 → SUPPRESS=1`). The byte-identity contract operates on the un-suppressed cost block — specifically the `cost_standard_usd=` line, extracted via `grep -F 'cost_standard_usd=' | cut -d= -f2`. The SC-8 acceptance script asserts the FR-9 preflight block's `predicted_cost` numeric value matches this scalar byte-for-byte.

   **Effective SC-8 (re-stated)**:
   > `orchestrator:auto` at Standard intensity invoked against the SC-8 fixture milestone emits a preflight block on stderr whose `predicted_cost` numeric value matches the `cost_standard_usd=` scalar emitted by `bash scripts/dispatch/predictive-surface.sh --description "$(bash scripts/diagnostics/summarize-milestone.sh M### --format=keys)" --intensity standard`. With `--yes` set, the auto loop proceeds without prompting.

   **References**:
   - [`.orchestrator/milestones/M029/M029-CONTEXT.md`](../../../../../milestones/M029/M029-CONTEXT.md) AD-4 (full discussion).
   - `commands/auto.md` `## Preflight Summary` section (AD-3 + AD-4 contract surface).
   - `tests/m029-acceptance/p03-sc8-auto-preflight.sh` (SC-8 acceptance script).
   - `scripts/diagnostics/summarize-milestone.sh` (P02 deliverable; oracle wrapper input).
   ```

6. **`tools/verify/m029-p03-spec-amendment-shape.sh`** — asserts the spec amendment record entry contains the AD-4 reference, names `summarize-milestone.sh`, `predictive-surface.sh`, `cost_standard_usd`, and the byte-identity contract clarification.

7. **`tools/verify/m029-p03-phase-suite.sh`** — the canonical P03 close gate. Aggregates every P03 verifier in dependency order:
   - T01: `m029-p03-render-position-live-shape.sh`, `m029-p03-display-thresholds-config-shape.sh`
   - T02: `m029-p03-auto-preflight-shape.sh`
   - T03: `m029-p03-auto-chain-shape.sh`
   - T04: `m029-p03-measure-live-tail-latency-shape.sh`, `m029-p03-sc7-shape.sh`, `m029-p03-sc8-shape.sh`, `m029-p03-sc9-shape.sh`, `m029-p03-sc10-shape.sh`
   - T05: `m029-p03-spec-amendment-shape.sh`, `m029-p03-acceptance-battery-shape.sh`, `m029-p03-readonly-invariant.sh`, `m029-p03-scope-guard.sh`

   Total: **13 gates** (T01:2 + T02:1 + T03:1 + T04:5 + T05:4 = 13). T06 introduces a 14th gate (validate-milestone-pass + closure-ceremony-shape) but those land in T06 not T05, so the P03 phase-suite scope is 13 in T05.

   *Wait — re-read the phase plan must-haves*. The phase plan lists `m029-p03-validate-milestone-pass.sh` and `m029-p03-closure-ceremony-shape.sh` as T06 deliverables, but the phase-suite must include them too if the phase-suite is the canonical "P03 is done" signal. Resolution: the phase-suite chains T01-T05 gates only (13). T06 ships its own milestone-grain validators that `validate-milestone.sh M029` consumes; those are NOT included in the per-phase suite because they are milestone-grain not phase-grain.

   Actual P03 phase-suite gate count: **13** (matching P02's exactly).

   Emits `OK:` / `FAIL:` per gate + final `SUMMARY: m029-p03-phase-suite.sh pass=N fail=M`. Exit 0 iff `fail=0`.

## Steps

1. **Author `tests/m029-acceptance/p03-acceptance-battery.sh`** (≥25 lines, executable, AD-19 single-script-file shape, bash 3.2):

   ```bash
   #!/usr/bin/env bash
   # tests/m029-acceptance/p03-acceptance-battery.sh
   # M029 / P03 acceptance battery -- wraps the four P03 SC acceptance scripts.
   #
   # SC coverage: SC-7 (live-tail latency + ▽ saved Nk marker),
   # SC-8 (auto preflight predicted_cost byte-identity),
   # SC-9 (Quick intensity suppresses preflight),
   # SC-10 (--auto-chain marker writes + resume).
   #
   # Re-used by tests/m029-acceptance/run-acceptance-battery.sh (T06)
   # alongside p01-acceptance-battery.sh + p02-acceptance-battery.sh.
   #
   # Bash 3.2 / MEM001. AD-19 straight-line bash. Mirrors p02-acceptance-battery.sh.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"

   pass=0
   fail=0

   bash tests/m029-acceptance/p03-sc7-live-tail.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 1 )); printf 'OK: SC-7\n'; else fail=$(( fail + 1 )); printf 'FAIL: SC-7\n'; fi

   bash tests/m029-acceptance/p03-sc8-auto-preflight.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 1 )); printf 'OK: SC-8\n'; else fail=$(( fail + 1 )); printf 'FAIL: SC-8\n'; fi

   bash tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 1 )); printf 'OK: SC-9\n'; else fail=$(( fail + 1 )); printf 'FAIL: SC-9\n'; fi

   bash tests/m029-acceptance/p03-sc10-auto-chain.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 1 )); printf 'OK: SC-10\n'; else fail=$(( fail + 1 )); printf 'FAIL: SC-10\n'; fi

   printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"

   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   `chmod +x`.

2. **Author `tools/verify/m029-p03-acceptance-battery-shape.sh`** (≥25 lines, AD-19, bash 3.2). Asserts:
   - `[ -x tests/m029-acceptance/p03-acceptance-battery.sh ]`.
   - The script body references each SC acceptance script.
   - The `BATTERY: pass=` literal appears.
   - The `Bash 3.2` or `MEM001` token appears.
   - **Behavioural run**: invokes the battery and asserts `BATTERY: pass=4 fail=0` exit 0.
   - Emits `PASS:`/`FAIL:` per assertion + `SUMMARY:`.

3. **Author `tools/verify/m029-p03-readonly-invariant.sh`** (≥40 lines, AD-19, bash 3.2). Pattern after `m029-p02-readonly-invariant.sh`:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m029-p03-readonly-invariant.sh
   # M029 / P03 / T05 -- LIVE-tree readonly invariant for P03 surfaces.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"

   pass=0
   fail=0

   SENTINEL="${TMPDIR:-/tmp}/m029-p03-readonly.$$.sentinel"
   trap 'rm -f "$SENTINEL"' EXIT
   touch "$SENTINEL"
   sleep 1   # ensure mtime resolution gap

   # Smoke 1: render-position --live (timed kill at 1.5s)
   ( bash scripts/diagnostics/render-position.sh --live --milestone M029 >/dev/null 2>&1 & RP_PID=$!; sleep 1.5; kill "$RP_PID" 2>/dev/null || true )

   # Smoke 2: at-rest render to the M029 milestone (FR-5 baseline)
   bash scripts/diagnostics/render-position.sh --milestone M029 >/dev/null 2>&1 || true

   # Smoke 3: summarize-milestone (used by AD-4 oracle wrapper)
   bash scripts/diagnostics/summarize-milestone.sh --milestone M029 --format=keys >/dev/null 2>&1 || true

   # Scan for offenders newer than sentinel, excluding execution-log.jsonl + auto-loop noise
   OFFENDERS=$(find .orchestrator -type f -newer "$SENTINEL" \
     ! -name 'execution-log.jsonl' \
     ! -name '*.complete' \
     ! -name '*.txt' \
     2>/dev/null)

   if [ -z "$OFFENDERS" ]; then
     pass=$(( pass + 1 ))
     printf 'PASS: P03 read-only invariant held (no .orchestrator/ files newer than sentinel)\n'
   else
     while IFS= read -r f; do
       fail=$(( fail + 1 ))
       printf 'FAIL: offender %s\n' "$f"
     done <<< "$OFFENDERS"
   fi

   printf 'SUMMARY: m029-p03-readonly-invariant.sh pass=%d fail=%d\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   - The `<<<` herestring on `OFFENDERS` is bash 3.2-safe via `printf '%s\n' "$OFFENDERS" | while read -r f; do ... done` if needed; verify against bash 3.2 (`<<<` is bash 2.05b+ so should be fine, but the canonical orchestrator pattern uses `printf | while`). Use the safer pattern.

4. **Author `tools/verify/m029-p03-scope-guard.sh`** (≥60 lines, AD-19, bash 3.2). Pattern after `m029-p02-scope-guard.sh`. Captures `git status --porcelain=v1` to a temp file via straight redirection (no `$()` with pipes). Iterates each line; classifies as allow/deny/unclassified. On any deny hit: `FAIL: scope violation by <path>` + non-zero exit. WARN-on-unclassified.

5. **Author the spec amendment record entry**: open `specs/037-roadmap-visibility-cli-ux/spec.md`, find the natural insertion point (end of file, or after the existing `## Dependencies` / `## Downstream Consumers` sections). Append the H2 `## Spec Amendment Record` section with the AD-4 entry shown in Description.

6. **Author `tools/verify/m029-p03-spec-amendment-shape.sh`** (≥25 lines, AD-19, bash 3.2):
   - Asserts `[ -f specs/037-roadmap-visibility-cli-ux/spec.md ]`.
   - Asserts the file contains literal `Spec Amendment Record`, `AD-4`, `summarize-milestone.sh`, `predictive-surface.sh`, `cost_standard_usd`, `--no-predict`, `byte-identity`.
   - Emits `PASS:`/`FAIL:` per assertion + `SUMMARY:`.

7. **Author `tools/verify/m029-p03-phase-suite.sh`** (≥100 lines, AD-19 straight-line, bash 3.2). Pattern after `m029-p02-phase-suite.sh`:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m029-p03-phase-suite.sh -- M029 P03 phase-close gate suite.
   #
   # Aggregates every P03 verifier from T01..T05.
   # validate-milestone.sh M029 (T06 deliverable) consumes this suite
   # alongside m029-p01-phase-suite.sh + m029-p02-phase-suite.sh + the
   # full SC battery (run-acceptance-battery.sh).
   #
   # Sub-gates (in dependency order):
   #   T01: render-position-live-shape, display-thresholds-config-shape
   #   T02: auto-preflight-shape
   #   T03: auto-chain-shape
   #   T04: measure-live-tail-latency-shape, sc7-shape, sc8-shape, sc9-shape, sc10-shape
   #   T05: spec-amendment-shape, acceptance-battery-shape, readonly-invariant, scope-guard
   # Total: 13 gates.

   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"

   pass=0
   fail=0

   emit_gate_result() {
       rc="$1"
       name="$2"
       if [ "$rc" -eq 0 ]; then
           pass=$(( pass + 1 ))
           printf 'OK: %s\n' "$name"
       else
           fail=$(( fail + 1 ))
           printf 'FAIL: %s\n' "$name"
       fi
   }

   # ---------- T01 Gate 1: render-position-live-shape ----------
   bash tools/verify/m029-p03-render-position-live-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-render-position-live-shape.sh"

   # ---------- T01 Gate 2: display-thresholds-config-shape ----------
   bash tools/verify/m029-p03-display-thresholds-config-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-display-thresholds-config-shape.sh"

   # ---------- T02 Gate 3: auto-preflight-shape ----------
   bash tools/verify/m029-p03-auto-preflight-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-auto-preflight-shape.sh"

   # ---------- T03 Gate 4: auto-chain-shape ----------
   bash tools/verify/m029-p03-auto-chain-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-auto-chain-shape.sh"

   # ---------- T04 Gate 5: measure-live-tail-latency-shape ----------
   bash tools/verify/m029-p03-measure-live-tail-latency-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-measure-live-tail-latency-shape.sh"

   # ---------- T04 Gate 6: sc7-shape ----------
   bash tools/verify/m029-p03-sc7-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-sc7-shape.sh"

   # ---------- T04 Gate 7: sc8-shape ----------
   bash tools/verify/m029-p03-sc8-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-sc8-shape.sh"

   # ---------- T04 Gate 8: sc9-shape ----------
   bash tools/verify/m029-p03-sc9-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-sc9-shape.sh"

   # ---------- T04 Gate 9: sc10-shape ----------
   bash tools/verify/m029-p03-sc10-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-sc10-shape.sh"

   # ---------- T05 Gate 10: spec-amendment-shape ----------
   bash tools/verify/m029-p03-spec-amendment-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-spec-amendment-shape.sh"

   # ---------- T05 Gate 11: acceptance-battery-shape ----------
   bash tools/verify/m029-p03-acceptance-battery-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-acceptance-battery-shape.sh"

   # ---------- T05 Gate 12: readonly-invariant ----------
   bash tools/verify/m029-p03-readonly-invariant.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-readonly-invariant.sh"

   # ---------- T05 Gate 13: scope-guard ----------
   bash tools/verify/m029-p03-scope-guard.sh
   rc=$?
   emit_gate_result "$rc" "m029-p03-scope-guard.sh"

   # ---------- Aggregate summary ----------
   printf 'SUMMARY: m029-p03-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

8. **`chmod +x` every new `.sh` file**.

9. **Run the phase-suite** — should exit 0 with `SUMMARY: m029-p03-phase-suite.sh pass=13 fail=0` after T05 completes. This is the canonical "P03 is done" signal.

## Must-Haves

This task addresses these P03 phase truths:
- The P03 phase-suite aggregator `tools/verify/m029-p03-phase-suite.sh` chains every P03 verifier and emits `SUMMARY: m029-p03-phase-suite.sh pass=13 fail=0` on success.
- The P03 acceptance battery `tests/m029-acceptance/p03-acceptance-battery.sh` chains the four P03 SC acceptance scripts and emits `BATTERY: pass=4 fail=0`.
- The P03 readonly-invariant verifier covers P03 surfaces (--live, preflight, --auto-chain) against the LIVE project tree.
- The P03 scope-guard enforces allowlist/denylist + WARN-on-unclassified.
- The Spec Amendment Record entry per AD-4 is appended to `specs/037-roadmap-visibility-cli-ux/spec.md`.

This task creates these P03 phase artifacts:
- `tests/m029-acceptance/p03-acceptance-battery.sh`
- `tools/verify/m029-p03-acceptance-battery-shape.sh`
- `tools/verify/m029-p03-readonly-invariant.sh`
- `tools/verify/m029-p03-scope-guard.sh`
- `tools/verify/m029-p03-spec-amendment-shape.sh`
- `tools/verify/m029-p03-phase-suite.sh`

This task modifies:
- `specs/037-roadmap-visibility-cli-ux/spec.md` (additive — append `## Spec Amendment Record` section).

## Verification

```bash
bash tools/verify/m029-p03-phase-suite.sh
```

## Inputs

### From Previous Tasks

- All T01–T04 verifiers (full list above in Description).
  - Key API: each verifier emits `SUMMARY: <name> pass=N fail=M` to stdout and exits 0 iff `fail=0`.
  - Behavioural contract: invocation from project root (`cd $PROJECT_ROOT; bash tools/verify/<name>`); no env-var dependencies; no positional args.
- T04 acceptance scripts under `tests/m029-acceptance/p03-sc{7,8,9,10}-*.sh`.
  - Key API: each emits `SUMMARY: <name> pass=N fail=0` and exits 0 on full SC pass.
- T04 fixtures under `tests/m029-acceptance/fixtures/auto-{preflight-standard,preflight-quick,chain-greenfield}.fixture/`.

### From Disk (Pre-existing)

- `tools/verify/m029-p01-phase-suite.sh` — structural precedent.
- `tools/verify/m029-p02-phase-suite.sh` — structural precedent.
- `tests/m029-acceptance/p01-acceptance-battery.sh` — battery-pattern precedent.
- `tests/m029-acceptance/p02-acceptance-battery.sh` — battery-pattern precedent.
- `tools/verify/m029-p02-readonly-invariant.sh` — readonly-invariant precedent.
- `tools/verify/m029-p02-scope-guard.sh` — scope-guard precedent.

## Constraints

- **AD-19 straight-line bash**: every verifier MUST be straight-line (NO inline compound chains, NO plain subshells, NO `$(cmd | …)`, NO process substitution). The phase-suite aggregator pattern is `bash <verifier>; rc=$?; emit_gate_result "$rc" <name>` per gate — exactly the P02 precedent.
- **Bash 3.2 (MEM001)**: NO `declare -A`, parallel indexed scalars. The `<<<` herestring should be replaced with `printf | while read` for portability. Function bodies MAY use pipes (MEM004 carve-out).
- **Read-only verifier discipline**: `m029-p03-readonly-invariant.sh` writes its sentinel under `${TMPDIR:-/tmp}/` (run-probe.sh scope rule 4 domain), NOT under `.orchestrator/`.
- **Scope-guard advisory**: `WARN:` for unclassified paths, FAIL only for denylist hits. P02 precedent stands.
- **Per CON-7 + AD-8**: T05 introduces NO new schemas. The new `tests/m029-acceptance/*.sh` and `tools/verify/m029-p03-*.sh` files + the spec amendment text are the only artifacts.
- **Path-collision rule 6**: every artifact path checked at plan-authoring time — all clean.

## Expected Output

After T05 completes:
- `tests/m029-acceptance/p03-acceptance-battery.sh` exists, executable, exits 0 with `BATTERY: pass=4 fail=0`.
- `tools/verify/m029-p03-acceptance-battery-shape.sh` exists, executable, exits 0.
- `tools/verify/m029-p03-readonly-invariant.sh` exists, executable, exits 0.
- `tools/verify/m029-p03-scope-guard.sh` exists, executable, exits 0 (or with `WARN:` advisories only).
- `tools/verify/m029-p03-spec-amendment-shape.sh` exists, executable, exits 0.
- `tools/verify/m029-p03-phase-suite.sh` exists, executable, exits 0 with `SUMMARY: m029-p03-phase-suite.sh pass=13 fail=0`.
- `specs/037-roadmap-visibility-cli-ux/spec.md` carries the appended `## Spec Amendment Record` section with the AD-4 entry.
- A summary file at [`.orchestrator/milestones/M029/phases/P03/tasks/T05-phase-close-gates-SUMMARY.md`](../../../../../milestones/M029/phases/P03/tasks/T05-phase-close-gates-SUMMARY.md) documents the deliverables.

## Notes

Expected phase-suite output:
```
OK: m029-p03-render-position-live-shape.sh
OK: m029-p03-display-thresholds-config-shape.sh
OK: m029-p03-auto-preflight-shape.sh
OK: m029-p03-auto-chain-shape.sh
OK: m029-p03-measure-live-tail-latency-shape.sh
OK: m029-p03-sc7-shape.sh
OK: m029-p03-sc8-shape.sh
OK: m029-p03-sc9-shape.sh
OK: m029-p03-sc10-shape.sh
OK: m029-p03-spec-amendment-shape.sh
OK: m029-p03-acceptance-battery-shape.sh
OK: m029-p03-readonly-invariant.sh
OK: m029-p03-scope-guard.sh
SUMMARY: m029-p03-phase-suite.sh pass=13 fail=0
```

`validate-milestone.sh M029` (T06 deliverable) chains the P01 phase-suite (14 gates) + P02 phase-suite (13 gates) + P03 phase-suite (13 gates) + the full SC-1..SC-14 acceptance battery (`run-acceptance-battery.sh`). P03's contribution to the milestone validator is the 13 gates above plus the 4 SC battery hits.

The Spec Amendment Record entry is the BBN-permanent artifact of the AD-4 discuss-time decision. Future readers who land on `specs/037-roadmap-visibility-cli-ux/spec.md` will find both the original SC-8 wording AND the amendment that re-states it via the shipped surface — no silent rewrite. This mirrors the M033 / [M032](../../../../../milestones/M032/index.md) pattern of in-spec amendment records.

The `tools/verify/m029-p03-readonly-invariant.sh` `<<<` herestring concern: bash 3.2 supports `<<<` (added in bash 2.05b, 2002), but the orchestrator's preferred pattern across `m029-p01-readonly-invariant.sh` / `m029-p02-readonly-invariant.sh` is `printf '%s\n' "$VAR" | while read -r LINE; do ... done`. Mirror that pattern to keep the verifier shape uniform across phases.
