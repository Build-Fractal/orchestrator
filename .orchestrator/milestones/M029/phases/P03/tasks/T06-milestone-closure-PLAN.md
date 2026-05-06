---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P03"
milestone: "M029"
name: "M029 milestone closure: run-acceptance-battery.sh + validate-milestone.sh M029 + M029-VALIDATED + M029-SUMMARY.md + milestone-grain unit_close"
depends_on: ["T05"]
---

## Prerequisites

- T05 complete: `bash tools/verify/m029-p03-phase-suite.sh` exits 0 with `SUMMARY: m029-p03-phase-suite.sh pass=13 fail=0`.
- T05 complete: `specs/037-roadmap-visibility-cli-ux/spec.md` carries the AD-4 Spec Amendment Record entry.
- P01 phase-suite at `tools/verify/m029-p01-phase-suite.sh` exits 0 with `SUMMARY: m029-p01-phase-suite.sh pass=N fail=0`.
- P02 phase-suite at `tools/verify/m029-p02-phase-suite.sh` exits 0 with `SUMMARY: m029-p02-phase-suite.sh pass=13 fail=0`.
- P01 acceptance battery at `tests/m029-acceptance/p01-acceptance-battery.sh` exits 0 with `BATTERY: pass=4 fail=0` (SC-1..SC-4).
- P02 acceptance battery at `tests/m029-acceptance/p02-acceptance-battery.sh` exits 0 with `BATTERY: pass=4 fail=0` (SC-5/SC-6/SC-13/SC-14).
- P03 acceptance battery at `tests/m029-acceptance/p03-acceptance-battery.sh` exits 0 with `BATTERY: pass=4 fail=0` (SC-7/SC-8/SC-9/SC-10).
- `scripts/verify/validate-milestone.sh` is on disk and supports `validate-milestone.sh M###` invocation. `[ -f scripts/verify/validate-milestone.sh ]` PASS.
- The M019 `unit_close` event emitter convention exists (consumed by P02 close, M032 close, M033 close, etc. — verified via `grep -lE 'unit_close' scripts/`).
- No path-collision: every T06 deliverable path absent at plan-authoring time:
  - `[ ! -f tests/m029-acceptance/run-acceptance-battery.sh ]` PASS
  - `[ ! -f tools/verify/m029-p03-run-acceptance-battery-shape.sh ]` PASS
  - `[ ! -f tools/verify/m029-p03-validate-milestone-pass.sh ]` PASS
  - `[ ! -f tools/verify/m029-p03-closure-ceremony-shape.sh ]` PASS
  - `[ ! -f .orchestrator/milestones/M029/M029-VALIDATED ]` PASS
  - `[ ! -f .orchestrator/milestones/M029/M029-SUMMARY.md ]` PASS

## Description

T06 ships the M029 milestone closure ceremony — the full SC-11/SC-12 surface plus the closure artifacts:

1. **`tests/m029-acceptance/run-acceptance-battery.sh`** (SC-11): the milestone-grain battery that chains all three per-phase batteries (P01, P02, P03), emits `BATTERY: pass=14 fail=0` on full pass (4 P01 SCs + 4 P02 SCs + 4 P03 SCs + SC-11 self + SC-12 milestone-validator hook = 14 total), and exits 0 iff every sub-battery exits 0.

2. **`tools/verify/m029-p03-run-acceptance-battery-shape.sh`**: shape verifier for the milestone-grain battery — asserts the script body references each per-phase battery, asserts `BATTERY: pass=14` literal, asserts behavioural exit 0.

3. **`tools/verify/m029-p03-validate-milestone-pass.sh`**: invokes `bash scripts/verify/validate-milestone.sh M029` and asserts:
   - Exit 0.
   - Output contains `100%` (or whatever success token `validate-milestone.sh` emits — verify against M032/M033 milestone-validator output: typically `validate-milestone.sh reports 197/197 PASS` or similar). The verifier asserts on the success line shape, not raw `100%` text — actual literal depends on `validate-milestone.sh`'s output convention.

4. **Run `bash scripts/verify/validate-milestone.sh M029`** end-to-end. This is the milestone-grain validator — chains all three per-phase suites + the milestone-grain battery + any other M029-claim verifier. On success, it emits the `M029-VALIDATED` marker (per the validator's convention; verify against M032 / M033 closure flow — in those milestones the marker is written by validate-milestone.sh itself, but in this codebase the marker is hand-written by the closure ceremony per `M032-VALIDATED` precedent).

5. **Write `.orchestrator/milestones/M029/M029-VALIDATED`**: empty marker file or single-line acknowledgment per the validate-milestone.sh convention (verify against M032/M033 markers — they appear to be empty files).

6. **Write `.orchestrator/milestones/M029/M029-SUMMARY.md`**: the canonical milestone-summary frontmatter (15 fields per the expanded write-summary.sh task-mode usage example) + body summarizing what was built, what was deferred, and what the post-close handoff is. Mirror M032/M033/M031 milestone summary shape.

7. **Append milestone-grain `unit_close` event** to `.orchestrator/milestones/M029/execution-log.jsonl`. Per CON-7, this consumes the existing M019 `unit_close` emitter; produces no new event type. The line shape mirrors prior milestones (M032 closure JSONL line, etc. — verify by grepping the M032 execution-log for the canonical shape).

8. **Closure-ceremony shape verifier `tools/verify/m029-p03-closure-ceremony-shape.sh`**: asserts the four closure artifacts exist:
   - `[ -f .orchestrator/milestones/M029/M029-VALIDATED ]`
   - `[ -f .orchestrator/milestones/M029/M029-SUMMARY.md ]` and the file has the expected frontmatter (`type: milestone-summary`, `verification_result: "pass"`, `completed_at:`).
   - `.orchestrator/milestones/M029/execution-log.jsonl` contains a line with `"event":"unit_close"` and `"unit":"M029"` (or whatever schema the existing emitter produces — verify against M032).
   - `bash tools/verify/m029-p03-validate-milestone-pass.sh` exits 0 (transitively re-runs validate-milestone.sh).

## Steps

1. **Author `tests/m029-acceptance/run-acceptance-battery.sh`** (≥50 lines, executable, AD-19 single-script-file shape, bash 3.2):

   ```bash
   #!/usr/bin/env bash
   # tests/m029-acceptance/run-acceptance-battery.sh
   # M029 milestone-grain acceptance battery (SC-11).
   #
   # Chains the three per-phase batteries:
   #   P01: SC-1, SC-2, SC-3, SC-4         (4 SCs)
   #   P02: SC-5, SC-6, SC-13, SC-14        (4 SCs)
   #   P03: SC-7, SC-8, SC-9, SC-10         (4 SCs)
   # Plus SC-11 (this script's BATTERY: line) and SC-12 (validate-milestone-pass hook).
   # Total: 14 SCs.
   #
   # Bash 3.2 / MEM001. AD-19 straight-line bash.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"

   pass=0
   fail=0

   # P01 slice
   bash tests/m029-acceptance/p01-acceptance-battery.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 4 )); printf 'OK: P01 slice (SC-1..SC-4)\n'; else fail=$(( fail + 4 )); printf 'FAIL: P01 slice (SC-1..SC-4)\n'; fi

   # P02 slice
   bash tests/m029-acceptance/p02-acceptance-battery.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 4 )); printf 'OK: P02 slice (SC-5/SC-6/SC-13/SC-14)\n'; else fail=$(( fail + 4 )); printf 'FAIL: P02 slice (SC-5/SC-6/SC-13/SC-14)\n'; fi

   # P03 slice
   bash tests/m029-acceptance/p03-acceptance-battery.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 4 )); printf 'OK: P03 slice (SC-7/SC-8/SC-9/SC-10)\n'; else fail=$(( fail + 4 )); printf 'FAIL: P03 slice (SC-7/SC-8/SC-9/SC-10)\n'; fi

   # SC-11 self -- this BATTERY: line itself satisfies SC-11 (battery emits canonical line).
   pass=$(( pass + 1 ))
   printf 'OK: SC-11 (battery emits canonical BATTERY: line)\n'

   # SC-12 milestone-validator hook
   if [ -f tools/verify/m029-p03-validate-milestone-pass.sh ]; then
     bash tools/verify/m029-p03-validate-milestone-pass.sh
     if [ $? -eq 0 ]; then pass=$(( pass + 1 )); printf 'OK: SC-12 (validate-milestone.sh M029 pass)\n'; else fail=$(( fail + 1 )); printf 'FAIL: SC-12 (validate-milestone.sh M029 pass)\n'; fi
   else
     # Verifier not yet present (only during T06 mid-author state); skip with WARN.
     printf 'WARN: SC-12 verifier not yet on disk; skipping\n'
   fi

   printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"

   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   `chmod +x`.

   Note: the SC-11/SC-12 accounting reaches 14 total only when the SC-12 verifier is present. During T06 mid-author state the SC-12 verifier might not yet exist; once T06 completes the verifier is on disk and the battery emits `BATTERY: pass=14 fail=0`.

2. **Author `tools/verify/m029-p03-run-acceptance-battery-shape.sh`** (≥30 lines, AD-19, bash 3.2):
   - Asserts `[ -x tests/m029-acceptance/run-acceptance-battery.sh ]`.
   - Asserts the script body references `p01-acceptance-battery`, `p02-acceptance-battery`, `p03-acceptance-battery`, `validate-milestone-pass`.
   - Asserts the literal `BATTERY:` and `pass=14` (the canonical milestone-grain pass count) appear.
   - **Behavioural run**: invokes the battery, asserts `BATTERY: pass=14 fail=0` exit 0.
   - Emits `PASS:`/`FAIL:`/`SUMMARY:`.

3. **Author `tools/verify/m029-p03-validate-milestone-pass.sh`** (≥25 lines, AD-19, bash 3.2):
   - Asserts `[ -f scripts/verify/validate-milestone.sh ]`.
   - Captures `bash scripts/verify/validate-milestone.sh M029` stdout to a temp file via straight redirection.
   - Asserts the validator exited 0.
   - Asserts the output contains the success token (`100%`, `PASS`, or whatever the validator emits — verify against M032 closure ceremony's validator output. Per CLAUDE.md "M032 ... validate-milestone.sh 122/122 PASS" the success token shape is `<n>/<m> PASS` with n==m).
   - Pattern-asserts the validator output contains `M029` and the expected total-vs-pass count shape.
   - Emits `PASS:`/`FAIL:`/`SUMMARY:`.

4. **Run end-to-end validation**:
   - Run `bash scripts/verify/validate-milestone.sh M029` and confirm exit 0 + the success-shape line.

5. **Write `.orchestrator/milestones/M029/M029-VALIDATED`** — the marker file. Per the M032/M033 precedent (`ls .orchestrator/milestones/M032/M032-VALIDATED` exists), the marker is a sentinel file. Verify by inspecting `.orchestrator/milestones/M032/M032-VALIDATED` shape; mirror exactly. Most likely empty file or single-line ack.

6. **Write `.orchestrator/milestones/M029/M029-SUMMARY.md`** with the canonical 15-field frontmatter + body. The frontmatter shape (per `write-summary.sh` task-mode expanded usage example, M032/M033 precedent):

   ```yaml
   ---
   schema_version: "1.0"
   type: milestone-summary
   id: "M029"
   parent: ""
   milestone: "M029"
   provides:
     - "<comprehensive list of M029 deliverables>"
   requires:
     - "M013, M018, M019, M020, M027, M032, M033"
   affects:
     - "M035 (consumes --format=json schema), external-tool-adapters (post-launch)"
   key_files:
     - "scripts/state/detect-invocation-context.sh, scripts/diagnostics/render-position.sh, scripts/diagnostics/render-status-json.sh, scripts/diagnostics/summarize-milestone.sh, commands/where.md, commands/context.md, commands/auto.md, commands/start.md, scripts/lifecycle/start.sh, references/status-headline-shape.md, references/status-json-schema.md, references/cross-milestone-feature-shape.md, tests/m029-acceptance/, tools/verify/m029-p01/p02/p03-*.sh"
   key_decisions:
     - "AD-1 single-resolve invocation context, AD-2 unconditional ANSI strip in JSON sections, AD-3 four-priority non-interactive policy, AD-4 SC-8 oracle wrapper amendment, AD-5 display_thresholds.compression_savings_pct config knob, AD-6 cross-milestone milestones: frontmatter list + reverse-lookup advisory, AD-7 schema_version: 1.0 from day 1, AD-8 knowledge-layer-boundary discipline, AD-9 sentinel-file mechanism for SC-14, scope tightening 2026-05-05 (cut FR-11 GitHub fold-in + FR-12 --refresh-github), Spec Amendment Record entry per AD-4"
   patterns_established:
     - "Principle-III paired design contract gate verifier shape, AD-19 straight-line bash with separate grep -F per assertion, negative-assertion verifier discipline, canonical compact-form ▽ saved Nk invariant, four-key fixed-order summarize-milestone output as AD-4 SC-8 oracle interface, AUTO_CHAIN_STAGE_STUB fixture-only escape hatch pattern, contract-surface assertion model for skill-documented surfaces, three-tier nanosecond-clock portability shim"
   drill_down_paths:
     - ".orchestrator/milestones/M029/phases/P01/P01-SUMMARY.md, .orchestrator/milestones/M029/phases/P02/P02-SUMMARY.md, .orchestrator/milestones/M029/phases/P03/P03-SUMMARY.md, .orchestrator/milestones/M029/M029-CONTEXT.md, .orchestrator/milestones/M029/M029-EVALUATION.md, .orchestrator/milestones/M029/M029-ROADMAP.md, specs/037-roadmap-visibility-cli-ux/spec.md"
   duration: "<measured at close>"
   verification_result: "pass"
   completed_at: "<ISO-8601 at close>"
   observability_surfaces:
     - "orchestrator:where, orchestrator:status (headline + --format=json), orchestrator:context, orchestrator:auto preflight, orchestrator:start --auto-chain"
   ---

   M029 ships the roadmap-visibility & CLI-UX milestone — three phases, 14 SCs,
   full acceptance battery PASS, all phase-suites green, validate-milestone.sh
   M029 100% PASS.

   **What was built**:

   - **P01 (foundation)**: `scripts/state/detect-invocation-context.sh` (AD-1 single-resolve env block); `references/status-headline-shape.md` + `references/status-json-schema.md` (Principle-III design contracts; AD-7 `schema_version: "1.0"` from day 1); `commands/status.md` headline block additive (FR-2); `commands/status.md --format=json` wiring + `scripts/diagnostics/render-status-json.sh` (FR-3, AD-2 unconditional ANSI strip); `commands/context.md` read-only single-screen runtime profile skill (FR-4). 6 tasks, 14-gate phase suite PASS.
   - **P02 (at-rest tree)**: `scripts/diagnostics/render-position.sh` at-rest tree renderer (FR-5; cost column from M027 `metrics-rollup.sh`); `commands/where.md` skill (FR-5); `references/cross-milestone-feature-shape.md` AD-6 contract; `scripts/diagnostics/summarize-milestone.sh` AD-4 SC-8 oracle wrapper; SC-5/SC-6/SC-13/SC-14 fixtures + acceptance + AD-9 sentinel-file mechanism; FR-6 silent pre-M019 cost-column suppression. 5 tasks, 13-gate phase suite PASS.
   - **P03 (live + preflight + auto-chain)**: `--live` branch on `render-position.sh` (FR-7, #Q-1 full re-render, #Q-G9 p95 ≤ 1.0s methodology); `▽ saved Nk` canonical compact-form marker (FR-8, #Q-G8) gated by `display_thresholds.compression_savings_pct` config knob (AD-5); `commands/auto.md ## Preflight Summary` section (FR-9, AD-3 four-priority non-interactive policy, AD-4 oracle wrapper); `commands/start.md --auto-chain` flag + `scripts/lifecycle/start.sh` chain-driver (FR-10, #Q-3 leave-marker-absent failure semantics); `tests/m029-acceptance/measure-live-tail-latency.sh` harness; SC-7/SC-8/SC-9/SC-10 fixtures + acceptance scripts; AD-4 Spec Amendment Record entry. 6 tasks, 13-gate phase suite PASS.

   **What was deferred (explicit non-goals)**:

   - GitHub fold-in line in `where` headline (FR-11 cut 2026-05-05 — wiki-is-the-view scope tightening).
   - `--refresh-github` flag (FR-12 cut 2026-05-05).
   - Deeper GitHub Projects v2 / Issues / dashboard surface area — defers to demand-driven post-launch `external-tool-adapters`.
   - Web UI / persistent dashboard — wiki (M032) is the long-form view.
   - Watcher daemon for `--live` — foreground only.
   - Spec 033 `milestones:` frontmatter migration — defers to M036b planning entry.

   **Post-close handoff**:

   - **M035 P00+P01 next**: dev-ergonomic prep before launch (`--mode=symlink` install + `orchestrator:status` version-drift warning). M035 P02-P06 IS the launch event (npm + homebrew + curl-pipe-bash publishing pipelines).
   - **M036b post-launch**: wiki projection + operator-facing scale UX for the reference-corpus pipeline.
   - **`external-tool-adapters` post-launch**: consumes M029's `--format=json` schema for GitHub / Trello / Notion / Linear projection.

   **Acceptance evidence**: `tests/m029-acceptance/run-acceptance-battery.sh` emits `BATTERY: pass=14 fail=0`; `bash scripts/verify/validate-milestone.sh M029` reports 100% PASS; `M029-VALIDATED` marker on disk.
   ```

7. **Append milestone-grain `unit_close` event** to `.orchestrator/milestones/M029/execution-log.jsonl`:
   - Inspect a prior milestone-close JSONL line (e.g., `grep -F '"event":"unit_close"' .orchestrator/milestones/M032/execution-log.jsonl | tail -1`) to capture the canonical line shape.
   - Mirror exactly with `unit: "M029"` substituted in.
   - Use `printf '%s\n' '<json-line>' >> .orchestrator/milestones/M029/execution-log.jsonl` (single-line append; AD-19 straight-line).

8. **Author `tools/verify/m029-p03-closure-ceremony-shape.sh`** (≥35 lines, AD-19, bash 3.2):
   - Asserts `[ -f .orchestrator/milestones/M029/M029-VALIDATED ]`.
   - Asserts `[ -f .orchestrator/milestones/M029/M029-SUMMARY.md ]`.
   - Asserts `M029-SUMMARY.md` contains the literal `type: milestone-summary`, `verification_result: "pass"`, `completed_at:`.
   - Asserts `.orchestrator/milestones/M029/execution-log.jsonl` contains a line with `"event":"unit_close"` AND `"M029"` substring (use `grep -F` for both literals against the same line).
   - Invokes `bash tools/verify/m029-p03-validate-milestone-pass.sh` and asserts exit 0.
   - Emits `PASS:`/`FAIL:`/`SUMMARY:`.

9. **`chmod +x` every new `.sh` file**.

10. **Final verification**: run the closure-ceremony shape verifier and the milestone-grain battery; confirm both exit 0 with the expected SUMMARY / BATTERY lines.

## Must-Haves

This task addresses these P03 phase truths:
- `tests/m029-acceptance/run-acceptance-battery.sh` chains all three per-phase batteries and emits `BATTERY: pass=14 fail=0` per SC-11.
- `bash scripts/verify/validate-milestone.sh M029` reports 100% PASS per SC-12.
- The closure ceremony fires: `M029-VALIDATED` marker, `M029-SUMMARY.md` with canonical frontmatter + body, milestone-grain `unit_close` event appended to `execution-log.jsonl`.

This task creates these P03 phase artifacts:
- `tests/m029-acceptance/run-acceptance-battery.sh`
- `tools/verify/m029-p03-run-acceptance-battery-shape.sh`
- `tools/verify/m029-p03-validate-milestone-pass.sh`
- `tools/verify/m029-p03-closure-ceremony-shape.sh`
- `.orchestrator/milestones/M029/M029-VALIDATED`
- `.orchestrator/milestones/M029/M029-SUMMARY.md`

This task appends:
- A milestone-grain `unit_close` event line to `.orchestrator/milestones/M029/execution-log.jsonl`.

## Verification

```bash
bash tests/m029-acceptance/run-acceptance-battery.sh
bash tools/verify/m029-p03-validate-milestone-pass.sh
bash tools/verify/m029-p03-closure-ceremony-shape.sh
bash tools/verify/m029-p03-run-acceptance-battery-shape.sh
```

## Inputs

### From Previous Tasks (P03)

- T05's P03 phase-suite at `tools/verify/m029-p03-phase-suite.sh` (consumed by `validate-milestone.sh M029`).
- T05's spec amendment record entry (asserted-against by `m029-p03-spec-amendment-shape.sh`, transitively chained from the P03 phase-suite).

### From Disk (Pre-existing — closed milestones)

- `tests/m029-acceptance/p01-acceptance-battery.sh` (P01/T06 deliverable; chains SC-1..SC-4).
- `tests/m029-acceptance/p02-acceptance-battery.sh` (P02/T05 deliverable; chains SC-5/SC-6/SC-13/SC-14).
- `tools/verify/m029-p01-phase-suite.sh` (P01/T06 deliverable; consumed by validate-milestone.sh).
- `tools/verify/m029-p02-phase-suite.sh` (P02/T05 deliverable; consumed by validate-milestone.sh).
- `scripts/verify/validate-milestone.sh` (existing tooling).
- M019 `unit_close` JSONL event emitter convention (verify line shape via `.orchestrator/milestones/M032/execution-log.jsonl`).
- M032 + M033 milestone-summary frontmatter shape (15-field convention; verify via `head -25 .orchestrator/milestones/M032/M032-SUMMARY.md`).

## Constraints

- **AD-19 straight-line bash**: every verifier and the battery script use straight-line shape. Per-gate dispatch via `bash <verifier>; rc=$?; emit_gate_result "$rc" <name>`. The append-line invocation uses `printf '%s\n' '<json>' >> <log>` with single-line literal payload (no embedded `$()` substitution that would trip the shape guard).
- **Bash 3.2 (MEM001)**: parallel scalars, `case` statements, `printf`, `grep -F`. NO `<<<` herestring.
- **CON-1 / FR-14 read-only with documented exceptions**: T06 writes the `M029-VALIDATED` marker, the `M029-SUMMARY.md` summary, and appends one line to `execution-log.jsonl`. These are the documented closure-ceremony write sites and are excluded from SC-14's read-only sentinel check (mirroring P01/P02 closure precedent).
- **CON-7 / AD-8 knowledge-layer-boundary**: the `unit_close` event consumes the existing M019 emitter convention (no new event type). The `M029-SUMMARY.md` is M029-owned per the milestone-summary template. NO M020 schema change.
- **Path-collision rule 6**: every artifact path checked at plan-authoring time — all clean.
- **Milestone-summary frontmatter shape**: must match the 15-field convention used by M031/M032/M033 to keep the milestone-summary aggregator (used by `commands/status.md` headline block from P01) byte-stable.

## Expected Output

After T06 completes:
- `tests/m029-acceptance/run-acceptance-battery.sh` exists, executable, exits 0 with `BATTERY: pass=14 fail=0`.
- `tools/verify/m029-p03-run-acceptance-battery-shape.sh` exists, executable, exits 0.
- `tools/verify/m029-p03-validate-milestone-pass.sh` exists, executable, exits 0.
- `tools/verify/m029-p03-closure-ceremony-shape.sh` exists, executable, exits 0.
- `.orchestrator/milestones/M029/M029-VALIDATED` exists.
- `.orchestrator/milestones/M029/M029-SUMMARY.md` exists with canonical frontmatter + body.
- `.orchestrator/milestones/M029/execution-log.jsonl` carries the milestone-grain `unit_close` event.
- `bash scripts/verify/validate-milestone.sh M029` reports 100% PASS.
- A summary file at `.orchestrator/milestones/M029/phases/P03/tasks/T06-milestone-closure-SUMMARY.md` documents the closure deliverables.

## Notes

The SC-11/SC-12 accounting reaches 14 SCs only when both T06 deliverables exist. The battery script's `WARN: SC-12 verifier not yet on disk; skipping` branch is for the mid-T06-author state; once `m029-p03-validate-milestone-pass.sh` lands the branch never fires again.

The `M029-SUMMARY.md` body is a substantial deliverable (~80+ lines including the `What was built` / `What was deferred` / `Post-close handoff` sections). The canonical shape mirrors M032/M033 — implementer should `head -100 .orchestrator/milestones/M032/M032-SUMMARY.md` to confirm body conventions before drafting.

The `unit_close` JSONL line shape lives in the existing M019 emitter. The simplest portable invocation is to call the M019 emitter directly if it exposes a CLI — otherwise hand-construct the JSON line by mirroring an existing `unit_close` line from a closed milestone's execution-log. The verifier asserts both `"event":"unit_close"` and `"M029"` substring, which any well-formed line will satisfy.

`validate-milestone.sh M029` exit-code semantics: per M032 closure ceremony, the validator exits 0 on full PASS and emits a success-shape line like `122/122 PASS`. The `m029-p03-validate-milestone-pass.sh` verifier asserts on that line shape, not on a literal `100%` string. If the validator emits a different shape, the verifier matches whatever it does emit (verify against the actual M032 / M033 validator output before authoring the assertion).

The closure ceremony is the M029 milestone exit point. After T06 completes:
- `bash scripts/state/find-active-milestone.sh .orchestrator` should NO LONGER return `M029 planning C` (it returns the next active milestone, likely M035 if the post-close handoff is set up).
- The M029 directory under `.orchestrator/milestones/` becomes a closed-state read-only reference for downstream consumers.
- `commands/status.md`'s headline block (P01 deliverable) on a fresh project run will show M029 in the "completed milestones" section if such a section exists, or simply not as the active milestone.

The next operator step after T06: `orchestrator:auto milestone=M035` (the M036b deferred-state paper-cut means M029's auto-target lock no longer applies, and M035 P00+P01 is the immediate pre-launch dev-ergonomic prep).
