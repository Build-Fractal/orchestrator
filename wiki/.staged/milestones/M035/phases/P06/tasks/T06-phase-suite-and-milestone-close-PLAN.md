---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P06"
milestone: "M035"
name: "Phase-suite aggregator + milestone close (M035-VALIDATED + M035-SUMMARY.md + milestone-grain unit_close JSONL)"
depends_on: ["T01", "T02", "T03", "T04", "T05"]
---

## Prerequisites

- **T01–T05 all closed** with their per-truth verifiers + battery on
  disk:
  - `tools/verify/m035-p06-config-schema-shape.sh` (T01)
  - `tools/verify/m035-p06-multi-source-dispatch-shape.sh` (T02)
  - `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh` (T03)
  - `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh` (T04)
  - `tools/verify/m035-p06-acceptance-battery-shape.sh` (T05)
  - `tests/m035-acceptance/run-acceptance-battery.sh` (T05)
- **Pattern reference** — `tools/verify/m035-p05-phase-suite.sh`
  (P05 T06) is the canonical aggregator shape this task mirrors.
  T06 reads it at execution time. The P05 form is the
  "summing-counters" variant (sums each child verifier's pass/fail/skip
  rather than counting one-per-child); T06 uses the same form because
  P06's child verifiers have heterogeneous BATTERY counts.
- **`scripts/lib/errors.sh`** exports `emit_result`. Used by the
  aggregator and the milestone-close-shape verifier.
- **`scripts/verify/validate-milestone.sh`** exists. T06 invokes
  this AFTER the phase-suite aggregator + acceptance battery both
  pass, AND BEFORE writing `M035-VALIDATED`.
- **`.orchestrator/milestones/M035/`** exists with all upstream phase
  artifacts:
  - `M035-EVALUATION.md`, `M035-CONTEXT.md`, `M035-ROADMAP.md`
  - `phases/P00/P00-SUMMARY.md` through `phases/P05/P05-SUMMARY.md`
  - `phases/P06/P06-PLAN.md` + every `tasks/T0N-*-PLAN.md`
- **No `tools/verify/m035-p06-phase-suite.sh`, no
  `.orchestrator/milestones/M035/M035-VALIDATED`, no
  [`.orchestrator/milestones/M035/M035-SUMMARY.md`](../../../../../milestones/M035/M035-SUMMARY.md)** at plan-authoring
  time (Plan-Time Discipline Rule 6 confirmed absent).
- **Pattern reference for milestone summary** —
  [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md) (122/122 PASS,
  closed 2026-05-05) and [`.orchestrator/milestones/M037/M037-SUMMARY.md`](../../../../../milestones/M037/M037-SUMMARY.md)
  (71/71 PASS, closed 2026-05-07) are the recent canonical summary
  shapes. T06 reads at execution time and mirrors the shape.

## Description

T06 closes M035 with three deliverables:

1. **`tools/verify/m035-p06-phase-suite.sh`** — phase-suite aggregator
   that chains every P06 per-truth verifier and emits a single
   `BATTERY: pass=N fail=0 skip=M` rollup. Mirrors the P05 T06
   summing-counters form. Load-bearing for `validate-milestone.sh
   M035` invocation.

2. **`tools/verify/m035-p06-milestone-close-shape.sh`** — verifier
   that asserts the milestone-close artifacts are present and
   well-shaped: `M035-VALIDATED` marker exists with a valid timestamp,
   `M035-SUMMARY.md` exists and contains the required headings,
   and the validate-milestone.sh M035 invocation reports PASS.

3. **`M035-VALIDATED` + `M035-SUMMARY.md` + milestone-grain
   `unit_close` JSONL entry** — written at the very end of T06's
   execution, AFTER `validate-milestone.sh M035` reports PASS and
   the acceptance battery emits `BATTERY: pass=N fail=0`. The
   marker is a one-line file with an ISO 8601 UTC timestamp; the
   summary is a structured markdown document per the M032/[M037](../../../../../milestones/M037/index.md)
   precedent; the JSONL entry appends to
   `.orchestrator/observability/<date>.jsonl` with
   `{"event":"unit_close","unit":"M035","result":"success",...}`.

## Steps

1. **Read `tools/verify/m035-p05-phase-suite.sh`** to confirm the
   exact aggregation shape (BATTERY-line parsing, exit code policy,
   error redirection, per-verifier output policy). T06 mirrors P05
   T06 idioms verbatim where they apply.

2. **Author `tools/verify/m035-p06-phase-suite.sh`**. ~80 lines.
   Single-script-file shape, AD-19. Bash 3.2 compatible. Mirrors the
   P05 T06 summing-counters form.

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p06-phase-suite.sh
   # M035 P06 — phase-suite aggregator.
   # Chains every P06 per-truth verifier; emits BATTERY rollup.
   # Mirrors the P05 T06 summing-counters form.

   set -u
   REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
   cd "$REPO_ROOT"

   total_pass=0
   total_fail=0
   total_skip=0

   verifiers="
   tools/verify/m035-p06-config-schema-shape.sh
   tools/verify/m035-p06-multi-source-dispatch-shape.sh
   tools/verify/m035-p06-update-run-jsonl-emission-shape.sh
   tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh
   tools/verify/m035-p06-acceptance-battery-shape.sh
   tools/verify/m035-p06-milestone-close-shape.sh
   "

   for v in $verifiers; do
     if [ ! -x "$v" ]; then
       printf 'SKIP: %s — not found\n' "$v"
       total_skip=$(( total_skip + 1 ))
       continue
     fi
     out_log="$(mktemp)"
     err_log="$(mktemp)"
     bash "$v" >"$out_log" 2>"$err_log"
     rc=$?
     battery_line="$(grep -E '^BATTERY:' "$out_log" | tail -1)"
     p=0; f=0; s=0
     if [ -n "$battery_line" ]; then
       p="$(echo "$battery_line" | sed -E 's/.*pass=([0-9]+).*/\1/' | head -1)"
       f="$(echo "$battery_line" | sed -E 's/.*fail=([0-9]+).*/\1/' | head -1)"
       case "$battery_line" in
         *skip=*) s="$(echo "$battery_line" | sed -E 's/.*skip=([0-9]+).*/\1/' | head -1)" ;;
         *)       s=0 ;;
       esac
     fi
     case "$p" in ''|*[!0-9]*) p=0 ;; esac
     case "$f" in ''|*[!0-9]*) f=0 ;; esac
     case "$s" in ''|*[!0-9]*) s=0 ;; esac
     total_pass=$(( total_pass + p ))
     total_fail=$(( total_fail + f ))
     total_skip=$(( total_skip + s ))
     if [ "$rc" -eq 0 ]; then
       printf 'PASS: %s (pass=%s fail=%s skip=%s)\n' "$v" "$p" "$f" "$s"
     else
       printf 'FAIL: %s (rc=%d pass=%s fail=%s skip=%s)\n' "$v" "$rc" "$p" "$f" "$s"
       cat "$err_log" >&2
     fi
     rm -f "$out_log" "$err_log"
   done

   printf 'BATTERY: pass=%d fail=%d skip=%d\n' "$total_pass" "$total_fail" "$total_skip"

   if [ "$total_fail" -eq 0 ]; then
     exit 0
   else
     exit 1
   fi
   ```

   Make it executable. Note: the aggregator references
   `m035-p06-milestone-close-shape.sh` which is the next step's
   deliverable — the `if [ ! -x "$v" ]; then SKIP` branch tolerates
   the absence on the first run before T06 finishes. After T06
   completes, the aggregator chains all six verifiers cleanly.

3. **Author `tools/verify/m035-p06-milestone-close-shape.sh`**. ~60
   lines. Single-script-file shape, AD-19. Asserts:

   1. `.orchestrator/milestones/M035/M035-VALIDATED` exists.
   2. The marker file is non-empty AND contains a valid ISO 8601
      UTC timestamp matching `YYYY-MM-DDTHH:MM:SSZ` (regex assertion
      via `grep -qE`).
   3. [`.orchestrator/milestones/M035/M035-SUMMARY.md`](../../../../../milestones/M035/M035-SUMMARY.md) exists.
   4. The summary contains the required H1 heading `# M035 — packaging & distribution`.
   5. The summary contains an H2 `## What was built`.
   6. The summary contains an H2 `## Verification`.
   7. The summary references `tests/m035-acceptance/run-acceptance-battery.sh`
      (SC-15 evidence pointer).
   8. The summary references the `BATTERY:` rollup line of the
      acceptance battery (operator can find the evidence).
   9. `bash scripts/verify/validate-milestone.sh M035` exits 0 (this
      is the SC-16 oracle assertion).

   Emit `BATTERY: pass=9 fail=0`. Note: this verifier ASSUMES the
   marker + summary are present — it's the "after" view. Before
   T06's final step writes the marker, this verifier reports
   `FAIL: M035-VALIDATED missing`. The phase-suite aggregator's
   `SKIP-when-not-found` semantics tolerate the chicken-and-egg
   only when the verifier is absent from disk, NOT when its
   assertions FAIL — so this verifier MUST be invoked AFTER the
   marker is written.

4. **Run the acceptance battery** to confirm everything is green:
   `bash tests/m035-acceptance/run-acceptance-battery.sh`. The
   battery exits 0 iff every sub-aggregator passes. If ANY
   sub-aggregator FAILs, T06 STOPS — milestone closure is gated on
   green battery.

5. **Run `validate-milestone.sh M035`** to confirm the milestone
   meets the framework-side validation: `bash scripts/verify/validate-milestone.sh M035`.
   Exit 0 → milestone is structurally complete (every must-have
   verified, every truth checked, no orphan artifacts). If non-zero,
   T06 STOPS — milestone closure is gated on validate-milestone PASS.

6. **Author [`.orchestrator/milestones/M035/M035-SUMMARY.md`](../../../../../milestones/M035/M035-SUMMARY.md)** per
   the M032/M037 template shape. Read those summaries at execution
   time to mirror the shape. Required headings:

   ```markdown
   # M035 — packaging & distribution

   <one-paragraph milestone-level summary: what M035 delivered,
    when it closed, the headline launch readiness state.>

   ## What was built

   - **P00 (closed YYYY-MM-DD)**: ...
   - **P01 (closed YYYY-MM-DD)**: ...
   - **P01.5 (closed YYYY-MM-DD)**: ...
   - **P02 (closed YYYY-MM-DD)**: ...
   - **P03 (closed YYYY-MM-DD)**: ...
   - **P04 (closed YYYY-MM-DD)**: ...
   - **P05 (closed YYYY-MM-DD)**: ...
   - **P06 (closed YYYY-MM-DD)**: ...

   ## Plan-phase Open Questions resolved

   <enumerate every #Q-N + #Q-G-N + AD-N + DR/D row resolved across
    M035 — read each P0N-SUMMARY.md to compile.>

   ## Manual Operator Steps deferred

   - **MOS-3** (homebrew first-release smoke) — deferred to first
     `v*` tag publication.
   - **MOS-4** (curl-pipe-bash first-release smoke) — same.
   - **MOS-5** (synthetic v0.0.0-test tag push against fork) — same.

   ## Verification

   - `bash tests/m035-acceptance/run-acceptance-battery.sh` →
     `BATTERY: pass=N fail=0 skip=M`
   - `bash scripts/verify/validate-milestone.sh M035` → 100% PASS
   - `M035-VALIDATED` marker on disk

   ## Patterns established

   <enumerate cross-cutting patterns surfaced across the milestone
    — read each P0N-SUMMARY.md `patterns_established:` list to
    compile.>

   ## Caveats and follow-ups

   - <BSD-sed bracket-class papercut from P03/P05 surfaced; ships as
     post-launch follow-up.>
   - <Live-channel evidence (MOS-3/MOS-4/MOS-5) deferred to first-release
     time.>
   - <Any other surfaces flagged across phase summaries.>

   ## Next milestone

   <Per the launch-sequencing-amendment + CLAUDE.md forward roadmap:
    M035 is the launch-event milestone. Post-launch fast-follows in
    queue order: M009 multi-runtime parity audit, M023 design layer,
    M034/M038 paired demand-driven slot, M036b reference-corpus
    post-launch slice, wiki-ux-deep + external-tool-adapters,
    M010 Managed Agents + Codex Cloud.>
   ```

   The summary's `What was built` bullets cite the closure date and
   one-sentence headline per phase (read each P0N-SUMMARY.md). The
   `Verification` section's BATTERY count is filled in from the
   actual battery run output captured in step 4.

7. **Write the `M035-VALIDATED` marker**. Single-line file at
   `.orchestrator/milestones/M035/M035-VALIDATED` containing:

   ```
   M035 validated at <ISO 8601 UTC timestamp>; acceptance battery PASS; validate-milestone.sh PASS.
   ```

   Use `date -u +%Y-%m-%dT%H:%M:%SZ` to generate the timestamp.

8. **Append the milestone-grain `unit_close` JSONL event** to
   `.orchestrator/observability/<today>.jsonl`. Match the convention
   used by P03/P04 milestone-close commits (commit `ad9dce25`,
   `d4a681fc`):

   ```json
   {"event":"unit_close","unit":"M035","result":"success","verification_result":"pass","completed_at":"<ISO 8601 UTC>","summary_path":"[.orchestrator/milestones/M035/M035-SUMMARY.md](../../../../../milestones/M035/M035-SUMMARY.md)"}
   ```

   `mkdir -p` the directory first; append (don't overwrite).

9. **Re-run the milestone-close-shape verifier**:
   `bash tools/verify/m035-p06-milestone-close-shape.sh`. Should
   now emit `BATTERY: pass=9 fail=0` (marker + summary + everything
   else verified).

10. **Re-run the phase-suite aggregator**:
    `bash tools/verify/m035-p06-phase-suite.sh`. Should now chain
    all six verifiers cleanly and emit
    `BATTERY: pass=<sum> fail=0 skip=0`.

## Must-Haves

- `tools/verify/m035-p06-phase-suite.sh` exists, executable, ~80+
  lines, contains `BATTERY:`, chains all six P06 verifiers (T01–T05
  task-grain + T06 milestone-close-shape), emits
  `BATTERY: pass=<sum> fail=0 skip=K`.
- `tools/verify/m035-p06-milestone-close-shape.sh` exists,
  executable, ~60+ lines, contains `BATTERY:` AND `M035-VALIDATED`,
  asserts marker + summary + validate-milestone.sh M035 PASS, emits
  `BATTERY: pass=9 fail=0`.
- `.orchestrator/milestones/M035/M035-VALIDATED` exists, single line,
  contains an ISO 8601 UTC timestamp.
- [`.orchestrator/milestones/M035/M035-SUMMARY.md`](../../../../../milestones/M035/M035-SUMMARY.md) exists, populated
  per the milestone-summary template (H1 + ## What was built + ##
  Verification + ## Patterns established + ## Caveats and follow-ups
  + ## Next milestone).
- `.orchestrator/observability/<today>.jsonl` contains a
  `unit_close` event for M035 with `result=success` and
  `verification_result=pass`.

## Verification

```bash
bash tools/verify/m035-p06-phase-suite.sh
```

```bash
bash tools/verify/m035-p06-milestone-close-shape.sh
```

```bash
bash tests/m035-acceptance/run-acceptance-battery.sh
```

```bash
bash scripts/verify/validate-milestone.sh M035
```

## Inputs

### From Previous Tasks

- `tools/verify/m035-p06-config-schema-shape.sh` (T01)
- `tools/verify/m035-p06-multi-source-dispatch-shape.sh` (T02)
- `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh` (T03)
- `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh` (T04)
- `tools/verify/m035-p06-acceptance-battery-shape.sh` (T05)
- `tests/m035-acceptance/run-acceptance-battery.sh` (T05)
  - Key contract: each emits a single `BATTERY: pass=N fail=N skip=M`
    line. T06's phase-suite aggregator chains them all and sums the
    counters.

### From Disk (Pre-existing)

- `tools/verify/m035-p05-phase-suite.sh` — pattern reference for the
  summing-counters aggregator form.
- `scripts/verify/validate-milestone.sh` — framework-side milestone
  validator. T06 invokes this AFTER the battery passes, BEFORE
  writing the marker.
- [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md) and
  [`.orchestrator/milestones/M037/M037-SUMMARY.md`](../../../../../milestones/M037/M037-SUMMARY.md) — recent canonical
  milestone-summary shapes. T06 reads at execution time and mirrors.
- Every `phases/P0N/P0N-SUMMARY.md` (P00 → P05) — T06 reads each to
  compile the M035-SUMMARY.md `What was built` section.
- `scripts/lib/errors.sh` — sourceable lib exporting `emit_result`.

## Constraints

- **AD-19 single-script-file shape** — every check command is `bash
  <single-script>`. The aggregator's per-verifier loop body uses
  function-style composition (mktemp + bash + grep + sed) inside a
  `for v in $verifiers; do ... done` loop, mirroring the P05 T06
  precedent.
- **Bash 3.2 + POSIX-sh** — CON-2/CON-7. The aggregator and
  milestone-close-shape verifier both run on macOS bash 3.2
  unmodified.
- **Milestone-close ordering is load-bearing** — sequence MUST be:
  (1) acceptance battery PASS → (2) validate-milestone.sh M035 PASS
  → (3) write M035-SUMMARY.md → (4) write M035-VALIDATED marker →
  (5) emit unit_close JSONL → (6) re-run milestone-close-shape
  verifier to confirm.
  Inverting the order (writing the marker before the battery passes)
  would falsely advertise milestone closure.
- **Single commit at milestone close** — per the prior in-milestone
  convention (`d4a681fc M035 P04: phase close`, `8a2386d5 M035 P05:
  close phase`), the milestone-close artifacts (marker + summary +
  unit_close JSONL) all land in the SAME commit as the T06 task
  artifacts (phase-suite + milestone-close-shape verifier). Operator
  controls when the actual `git commit` fires; T06 stages everything.
- **Plan-Time Discipline Rule 6 (Path-collision)** — `ls -la`
  performed against every `create` path. All ABSENT.

## Expected Output

Stdout from `bash tools/verify/m035-p06-phase-suite.sh` (post all
T01–T06 closures):

```
PASS: tools/verify/m035-p06-config-schema-shape.sh (pass=7 fail=0 skip=0)
PASS: tools/verify/m035-p06-multi-source-dispatch-shape.sh (pass=13 fail=0 skip=0)
PASS: tools/verify/m035-p06-update-run-jsonl-emission-shape.sh (pass=12 fail=0 skip=0)
PASS: tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh (pass=12 fail=0 skip=0)
PASS: tools/verify/m035-p06-acceptance-battery-shape.sh (pass=16 fail=0 skip=0)
PASS: tools/verify/m035-p06-milestone-close-shape.sh (pass=9 fail=0 skip=0)
BATTERY: pass=69 fail=0 skip=0
```

Stdout from `bash tools/verify/m035-p06-milestone-close-shape.sh`
(post marker + summary write):

```
PASS: M035-VALIDATED marker exists
PASS: M035-VALIDATED carries valid ISO 8601 UTC timestamp
PASS: M035-SUMMARY.md exists
PASS: M035-SUMMARY.md contains H1 # M035 — packaging & distribution
PASS: M035-SUMMARY.md contains ## What was built
PASS: M035-SUMMARY.md contains ## Verification
PASS: M035-SUMMARY.md references tests/m035-acceptance/run-acceptance-battery.sh
PASS: M035-SUMMARY.md cites BATTERY rollup
PASS: validate-milestone.sh M035 reports PASS
BATTERY: pass=9 fail=0
```

`.orchestrator/milestones/M035/M035-VALIDATED` content:

```
M035 validated at 2026-05-09T19:42:00Z; acceptance battery PASS; validate-milestone.sh PASS.
```

`.orchestrator/observability/<today>.jsonl` will contain a single
appended line:

```json
{"event":"unit_close","unit":"M035","result":"success","verification_result":"pass","completed_at":"2026-05-09T19:42:00Z","summary_path":".orchestrator/milestones/M035/M035-SUMMARY.md"}
```
