---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M031"
name: "AD-14 single-window post-M031 capture + FR-4 reconciliation of commands/dispatch.md:21"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/dispatch/build-context.sh` accepts `--profile=quick` and `--meta-out <file>` (verified by `bash tools/verify/m031-p01-build-context-profile-shape.sh`).
- T01 complete: `tools/verify/m031-p01-build-context-profile-shape.sh`, `m031-p01-quick-no-skip-branch.sh`, `m031-p01-config-knobs-stable.sh` all exist and exit 0.
- T01 invariant: `commands/dispatch.md` is BYTE-IDENTICAL to its pre-P01 state at T02 entry. The literal phrase "Skip payload assembly" still appears at line 21. T02's pre-condition is that this skip branch is still live so the AD-14 capture window is open.
- P00 complete: `tests/m031-acceptance/empirical-baseline.sh` exists with the `--post-m031-emitter <path>` seam (verified by `bash tools/verify/p00-baseline-harness-shape.sh`).
- P00 complete: `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl` exists with exactly 20 records (the AD-14 frozen pre-state).

## Description

T02 closes the AD-14 single-window. Until T02 runs, both the pre-M031 dispatch path (skip-branch via `commands/dispatch.md:21`) and the post-M031 dispatch path (T01's `build-context.sh --profile=quick`) are live simultaneously — that is the single window in which a real-world dual-execution capture is possible. T02 captures the post-M031 baseline JSONL (20 records, one per corpus task) into `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl` BEFORE amending `commands/dispatch.md:21` to remove the skip branch. Once the FR-4 amendment lands, the pre-M031 code path is gone forever; the dual-execution window is closed.

The order is normative:
1. Author the post-M031 emitter wrapper at `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh`.
2. Run `tests/m031-acceptance/empirical-baseline.sh --post-m031-emitter tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh` to capture the 20-record post-M031 baseline.
3. Confirm `post-m031-baseline.jsonl` exists with exactly 20 records carrying `path: "post-m031"` and non-zero `knowledge_section_tokens`.
4. ONLY THEN amend `commands/dispatch.md:21` per FR-4 (remove "Skip payload assembly", insert canonical "Quick profile" language).
5. Author and run the two T02 verifiers.

If step 3 fails (fewer than 20 records, missing field, etc.), DO NOT proceed to step 4. Diagnose and re-run the capture; the AD-14 window is open as long as the dispatch.md skip branch is live.

## Steps

1. **Author `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh`.** Bash 3.2-compatible, executable. Behavior:
   - CLI: `<task-fixture-path>` as positional argument. The harness invokes the emitter once per corpus task with the fixture path.
   - For each invocation:
     - Derive a synthetic `task_id` from the fixture filename (e.g., `task-01.txt` → `task-01`).
     - Invoke `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <task-fixture-path> --out /tmp/m031-p01-t02-payload-<task_id>.md --meta-out /tmp/m031-p01-t02-meta-<task_id>.json`.
     - Read `mem_count` and `total_tokens` from the meta JSON sidecar.
     - Estimate `knowledge_section_tokens` as the assembled-payload Knowledge-section token count (read from the sidecar's `total_tokens` minus other-section tokens, OR re-emit from a payload-section parser; the simplest robust path: read the meta sidecar's `total_tokens` and report it — the SC tests gate on the sidecar field, not on a re-derived count).
     - Read `compression_applied` and `snip_applied` from the sidecar.
     - For `verifier_pass`, emit `true` (the post-M031 path is the system under test; verifier-pass is determined by SC-3 / SC-15 separately at the SC-test level).
     - Emit exactly one JSONL line on stdout matching the schema:
       ```
       {"task_id":"<id>","path":"post-m031","knowledge_section_tokens":<int>,"compression_applied":<bool>,"snip_applied":<bool>,"total_task_tokens":<int>,"verifier_pass":true}
       ```
     - The schema is sibling-symmetric with the pre-M031 schema in `pre-m031-stub.sh` — same field set, only the `path` value and the `knowledge_section_tokens`/compression flags differ.
   - Exit 0 on success; exit 1 if `build-context.sh` exits non-zero.
   - File header MUST contain "build-context.sh", "--profile=quick", "post-m031", "knowledge_section_tokens" (these are the artifact-shape literals the T02 verifier asserts).

2. **Run the harness to capture the post-M031 baseline JSONL.** Single invocation:

   ```bash
   bash tests/m031-acceptance/empirical-baseline.sh --post-m031-emitter tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh
   ```

   Expected: harness invokes the emitter against each of `task-01.txt` through `task-20.txt`, appends 20 JSONL records to `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl`, prints `BASELINE: pre=20 post=20` on stdout, exits 0.

3. **Verify the post-M031 capture is complete.** The file `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl` MUST exist with exactly 20 lines, each a valid JSON object containing `"path":"post-m031"` and a `"knowledge_section_tokens":<positive_int>` field. If the file has fewer than 20 lines or any line lacks the post-m031 path tag, DIAGNOSE THE EMITTER and re-run; do NOT proceed to step 4.

4. **Amend `commands/dispatch.md:21` per FR-4.** ONLY AFTER step 3 confirms the 20-record post-M031 baseline. Edit the intensity table row for Quick:

   - **Before** (current text on line 21):
     ```
     | Quick     | sequential                    | Skip payload assembly (`build-context.sh`). Invoke `dispatch-interface.sh` with a minimal payload containing only the task plan. Run tasks sequentially — no parallel fan-out. |
     ```
   - **After** (FR-4 canonical replacement):
     ```
     | Quick     | sequential                    | Full payload assembly via `build-context.sh --profile=quick` (touched-files-only scope, 1-hop knowledge-graph traversal, no Decisions section, glossary slice over touched terms only). Knowledge + [M018](../../../../../milestones/M018/index.md) compression apply unconditionally per CON-1. Run tasks sequentially — no parallel fan-out. |
     ```
   - The replacement MUST contain the literal token "Quick profile" (the verifier asserts on this token verbatim per the FR-4 contract). If the chosen wording above does not contain that exact token, append a parenthetical such as `(Quick profile)` to satisfy the verifier — the verbatim token is the contract, not the exact phrasing.
   - The replacement MUST NOT contain the literal phrase "Skip payload assembly" (the verifier inverts on this phrase).
   - MUST NOT touch any other line in `commands/dispatch.md`. The diff is exactly one line replaced.

5. **Author `tools/verify/m031-p01-post-baseline-jsonl-population.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Assert `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl` exists.
   - Assert `wc -l` against the file reports exactly 20.
   - Assert every line contains the literal substring `"path":"post-m031"`.
   - Assert every line contains a `"knowledge_section_tokens":<int>` field; assert at least 19 of 20 records carry a non-zero value (allowing one degenerate-task fallback per the spec's "empty touched-file set falls back to milestone scope" edge case).
   - Output: `SUMMARY: m031-p01-post-baseline-jsonl-population.sh pass=N fail=M`. Exit 0 iff fail=0.

6. **Author `tools/verify/m031-p01-dispatch-md-reconciliation.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Assert `commands/dispatch.md` does NOT contain the literal phrase "Skip payload assembly" (FR-4 inversion check).
   - Assert `commands/dispatch.md` contains the literal token "Quick profile" at least once.
   - Assert the file contains a comment-or-prose reference to "FR-4" (M031 reconciliation provenance — encourages future maintainers to find the reasoning).
   - Output: `SUMMARY: m031-p01-dispatch-md-reconciliation.sh pass=N fail=M`. Exit 0 iff fail=0.
   - **Guard against well-intentioned future "fixes"**: include a header comment in the verifier explaining that the inverted-polarity assertion (absence of "Skip payload assembly") is intentional per FR-4 and MUST NOT be flipped by future maintainers (mirrors the P00 inverted-polarity verifier convention from `p00-spec-foldin-shape.sh`).

7. **Run both new verifiers locally** to confirm exit 0:
   - `bash tools/verify/m031-p01-post-baseline-jsonl-population.sh`
   - `bash tools/verify/m031-p01-dispatch-md-reconciliation.sh`

## Must-Haves

This task addresses the following Must-Haves from `P01-PLAN.md`:
- "commands/dispatch.md no longer contains the literal phrase 'Skip payload assembly'" (Truth #4; Check via `m031-p01-dispatch-md-reconciliation.sh`)
- "tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl exists with exactly 20 JSONL records" (Truth #5; Check via `m031-p01-post-baseline-jsonl-population.sh`)

## Verification

```bash
bash tools/verify/m031-p01-post-baseline-jsonl-population.sh
```

```bash
bash tools/verify/m031-p01-dispatch-md-reconciliation.sh
```

## Notes

- The AD-14 single-window discipline is the load-bearing constraint for T02. Step ordering is normative: the post-M031 capture MUST happen BEFORE the FR-4 amendment lands. The post-m031-baseline.jsonl is the frozen artifact that survives the destructive FR-4 edit; SC-11 (P04 acceptance battery) reads it.
- If the harness invocation in step 2 fails, the live skip branch is still in place — the window remains open. Diagnose, re-run; do not proceed to step 4 with a partial capture.
- The `m031-p01-dispatch-md-reconciliation.sh` verifier uses inverted-polarity grep (assert ABSENCE of "Skip payload assembly"). Per the P00 inverted-polarity verifier pattern, the verifier file MUST carry an explicit header comment guarding the inversion against future maintainer "fixes."
- D020 token hygiene (CON-7): authored prose in dispatch.md and the new verifiers MUST NOT embed the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code; paraphrase or escape.

## Inputs

### From Previous Tasks

- `scripts/dispatch/build-context.sh` (from T01) — accepts `--profile=quick|standard|full` and `--meta-out <file>`. T02's `post-m031-emitter.sh` invokes:
  - **Key API**: `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <path> --out <path> --meta-out <path>`
  - **Key types**: input is task plan markdown; output is assembled payload markdown + JSON sidecar.
  - **Behavioral contract**: exit 0 on success; meta sidecar contains `{mem_count, total_tokens, profile, compression_applied, snip_applied}`.

### From Disk (Pre-existing)

- `tests/m031-acceptance/empirical-baseline.sh` — P00 harness with `--post-m031-emitter <path>` seam. T02 invokes this once with the new emitter wrapper.
- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` — P00 frozen pre-state stub. T02's emitter is sibling-symmetric with this (same JSONL schema, only `path` value differs).
- `tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt` through `task-20.txt` — P00 corpus. T02 captures one post-M031 JSONL record per task.
- `commands/dispatch.md` — line 21 carries the live Quick-skip branch at T02 entry. T02 amends this single line per FR-4 (after the AD-14 capture).

## Constraints

- **Bash 3.2 compatibility** (MEM001).
- **Order discipline (AD-14 single-window)**: post-M031 capture BEFORE FR-4 amendment. Reverse order forfeits the dual-execution window forever.
- **Single-line diff to `commands/dispatch.md`**: T02 modifies exactly one line (the Quick row of the intensity table). Touching other lines is out-of-scope and will fail SC-12 scope-guard at T04.
- **No edits to `scripts/dispatch/build-context.sh`** in T02 (T01 owns the build-context.sh edits; T02 reads the T01-shipped surface).
- **No edits to `templates/orchestrator-config-default.yml`** in T02 (P00 owns the M031 knobs).
- **No edits to `tests/m031-acceptance/empirical-baseline.sh`** in T02 (P00 owns the harness; T02 invokes it via the existing `--post-m031-emitter` seam).
- **SC-12 scope-guard**: T02 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`.
- **Verifier path discipline**: `tools/verify/m031-p01-*.sh` (project-owned slug-bearing).

## Expected Output

After T02 completes:

1. `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh` exists, executable, sibling-symmetric with `pre-m031-stub.sh`.
2. `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl` exists with exactly 20 records (one per corpus task), each carrying `"path":"post-m031"` and a non-zero `knowledge_section_tokens` field (one degenerate fallback allowed).
3. `commands/dispatch.md` no longer contains "Skip payload assembly"; the Quick row of the intensity table contains "Quick profile" and references FR-4.
4. `tools/verify/m031-p01-post-baseline-jsonl-population.sh` exits 0 (`SUMMARY: ... pass=N fail=0`).
5. `tools/verify/m031-p01-dispatch-md-reconciliation.sh` exits 0.

T02 closes the AD-14 single-window: the pre-M031 code path is gone; the dual-execution capture is the only evidence we will ever have of pre-M031 behavior.
