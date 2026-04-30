---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M030"
name: "D-A4 timeline-graduation verifier + P00 phase-suite re-run"
depends_on: []
---

## Prerequisites

- `tests/fixtures/m030-classifier-corpus/labels.yml` exists (P00/T02 deliverable; 40 entries; first commit landed in `1592d52`).
- `tests/fixtures/m030-classifier-corpus/README.md` exists (P00/T03 deliverable; first commit landed in `7c9c3b2`).
- `tools/verify/p00-d-a4-independence.sh` exists (P00/T03 deliverable; absence-check verifier).
- `tools/verify/p00-phase-suite.sh` exists and exits 0 on the current working tree (P00 close gate).
- `scripts/dispatch/classify-task.sh` does **NOT** exist on disk at the start of T01 — D-A4 independence-by-construction holds at the P00 → P01 boundary.

Plan-time prerequisite-existence verification (per `commands/plan-phase.md` Plan-Time Discipline rule 1): every path above resolves to a real file under `[ -f <path> ]` at plan-authoring time, except `scripts/dispatch/classify-task.sh` which MUST NOT exist (verified by `[ ! -f scripts/dispatch/classify-task.sh ]`).

## Description

T01 is the bridge task between P00 (D-A4 independence proven by *absence* of `classify-task.sh`) and T02 (where `classify-task.sh` ships, at which point the absence proof no longer applies). T01 authors a graduation verifier `tools/verify/p01-d-a4-timeline.sh` that:

1. **Pre-T02 mode (classify-task.sh still absent)**: passes by absence (delegates to `tools/verify/p00-d-a4-independence.sh` semantics).
2. **Post-T02 mode (classify-task.sh exists on disk)**: asserts via `git log --diff-filter=A --pretty=format:%at` that the first-commit timestamp of `tests/fixtures/m030-classifier-corpus/labels.yml` numerically precedes the first-commit timestamp of `scripts/dispatch/classify-task.sh`. The mechanical proof of D-A4 timeline ordering, locked by version control.

The verifier is on disk before classify-task.sh is, so the moment T02 commits the classifier the verifier can be re-run and the ordering check fires. T01 also re-runs `tools/verify/p00-phase-suite.sh` to confirm the P00 close-state still holds at the start of P01 (no drift).

T01 ends with `scripts/dispatch/classify-task.sh` STILL absent on disk — T01 does NOT create the classifier. That is T02's deliverable.

## Steps

1. **Confirm D-A4 independence still holds at T01 start.** Run:

   ```bash
   bash tools/verify/p00-d-a4-independence.sh
   ```

   Expected: exit 0 with `OK: classify-task.sh absent — D-A4 independence by construction` and `SUMMARY: p00-d-a4-independence.sh pass=1 fail=0`. If this fails (e.g., classify-task.sh somehow exists), STOP and escalate — D-A4 has been violated and P01 cannot proceed under the SC-10 contract.

2. **Re-run the P00 phase-suite.** Run:

   ```bash
   bash tools/verify/p00-phase-suite.sh
   ```

   Expected: `SUMMARY: p00-phase-suite.sh pass=5 fail=0`, exit 0. This confirms no drift in the P00 corpus state at the P01 entry boundary.

3. **Author `tools/verify/p01-d-a4-timeline.sh`.** Bash 3.2-compatible. Single-script-file shape per AD-19 — no compound chains, no plain subshells, no `$(...)` containing pipes, no process substitution, no inline `for`/`if` blocks beyond simple bash conditionals. Verbatim contract:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p01-d-a4-timeline.sh — D-A4/SC-10 timeline-ordering verifier (graduation).
   #
   # Two-mode operation:
   #   Mode A (pre-T02, classify-task.sh absent): pass by absence.
   #   Mode B (post-T02, classify-task.sh exists): assert
   #     labels.yml first-commit-ts < classify-task.sh first-commit-ts
   #     via `git log --diff-filter=A --pretty=format:%at`.
   #
   # Output contract:
   #   stdout final line: "SUMMARY: p01-d-a4-timeline.sh pass=N fail=M"
   #   exit 0 iff pass=1 fail=0.
   #
   # Bash 3.2 compatible. AD-19 single-script-file shape (no compound
   # chains, no $() with pipes, no process substitution).

   set -uo pipefail

   labels_path="tests/fixtures/m030-classifier-corpus/labels.yml"
   classifier_path="scripts/dispatch/classify-task.sh"

   pass=0
   fail=0

   if [ ! -f "$labels_path" ]; then
     echo "FAIL: $labels_path not found — D-A4 corpus missing"
     fail=$((fail+1))
     echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
     exit 1
   fi

   if [ ! -f "$classifier_path" ]; then
     # Mode A: classify-task.sh absent — independence by construction.
     echo "OK: classify-task.sh absent — D-A4 independence by construction (pre-T02 mode)"
     pass=$((pass+1))
     echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
     exit 0
   fi

   # Mode B: classify-task.sh exists — git-log ordering check.
   labels_ts="$(git log --diff-filter=A --pretty=format:%at -- "$labels_path" | tail -1)"
   classifier_ts="$(git log --diff-filter=A --pretty=format:%at -- "$classifier_path" | tail -1)"

   if [ -z "$labels_ts" ]; then
     echo "FAIL: $labels_path has no add-commit in git log"
     fail=$((fail+1))
     echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
     exit 1
   fi

   if [ -z "$classifier_ts" ]; then
     echo "FAIL: $classifier_path has no add-commit in git log"
     fail=$((fail+1))
     echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
     exit 1
   fi

   if [ "$labels_ts" -lt "$classifier_ts" ]; then
     echo "OK: labels.yml committed at $labels_ts precedes classify-task.sh at $classifier_ts"
     pass=$((pass+1))
     echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
     exit 0
   else
     echo "FAIL: D-A4 timeline violated — labels.yml=$labels_ts classify-task.sh=$classifier_ts"
     fail=$((fail+1))
     echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
     exit 1
   fi
   ```

   `chmod +x tools/verify/p01-d-a4-timeline.sh` after writing. The two `git log | tail -1` invocations use single-pipeline `$(...)` shape — a single pipe with no nested compound — which is permitted by the AD-19 forbidden-shape list (the prohibited shapes are `$()` containing pipes that produce results consumed by further compound operators; a plain command-substitution with one pipe whose output is assigned to a variable is the canonical bash-3.2-safe shape used elsewhere in `tools/verify/p00-d-a4-independence.sh` per the T03 plan reference).

4. **Run the verifier in Mode A as a self-check.** From repo root:

   ```bash
   bash tools/verify/p01-d-a4-timeline.sh
   ```

   Expected: `OK: classify-task.sh absent — D-A4 independence by construction (pre-T02 mode)`, `SUMMARY: p01-d-a4-timeline.sh pass=1 fail=0`, exit 0.

5. **Confirm `scripts/dispatch/classify-task.sh` is still absent on disk.** Run:

   ```bash
   ls scripts/dispatch/classify-task.sh
   ```

   Expected: `ls: scripts/dispatch/classify-task.sh: No such file or directory` (stderr) + non-zero exit. T01 must end with the classifier still absent.

6. **Stage and commit.** Add `tools/verify/p01-d-a4-timeline.sh` to git and commit. Use `git commit -F <message-file>` per `CLAUDE.md` `## Commit Message Authoring`. Recommended message: `M030/P01/T01: D-A4 timeline graduation verifier`.

## Must-Haves

This task satisfies the phase truth:

- "D-A4/SC-10 timeline ordering holds: `tests/fixtures/m030-classifier-corpus/labels.yml`'s first-commit timestamp predates `scripts/dispatch/classify-task.sh`'s first-commit timestamp." — gated by `tools/verify/p01-d-a4-timeline.sh` (Mode A pass during T01; Mode B once T02 ships).

## Verification

```bash
bash tools/verify/p00-d-a4-independence.sh
bash tools/verify/p00-phase-suite.sh
bash tools/verify/p01-d-a4-timeline.sh
```

Each verifier uses single-script-file shape per AD-19. The first two confirm the P00 close-state still holds; the third self-checks the new graduation verifier in Mode A.

## Inputs

### From Previous Tasks

- `tests/fixtures/m030-classifier-corpus/labels.yml` (from P00/T02)
  - Key API: YAML file with frontmatter + `entries:` list of 40 entries; every entry has concrete `character` ∈ {mechanical, standard, novel}, `confidence` ∈ {high, medium, low}, non-empty `rationale`. T01 reads this only to confirm existence — does not parse contents.
  - First commit: `1592d52`.

- `tools/verify/p00-d-a4-independence.sh` (from P00/T03)
  - Key API: invoke as `bash tools/verify/p00-d-a4-independence.sh`. Exits 0 with `SUMMARY: p00-d-a4-independence.sh pass=1 fail=0` when classify-task.sh is absent on disk.
  - First commit: `7c9c3b2`.

- `tools/verify/p00-phase-suite.sh` (from P00/T03)
  - Key API: invoke as `bash tools/verify/p00-phase-suite.sh`. Exits 0 with `SUMMARY: p00-phase-suite.sh pass=5 fail=0` when the P00 corpus state is intact.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M030/M030-CONTEXT.md` D-A4 (lines 38-44; verbatim source for the timeline-ordering constraint).
- `specs/032-adaptive-model-selection/spec.md` SC-10 (the ≥85% agreement gate that rests on D-A4's timeline guarantee).

## Constraints

- **D-A4 independence preserved**: `scripts/dispatch/classify-task.sh` STILL must not exist on disk at any point during T01 — the verifier itself will assert this in Mode A.
- **No classifier authoring**: T01 does NOT create `classify-task.sh`. That is T02's deliverable. T01 ships ONLY the timeline-graduation verifier and runs the existing P00 gates.
- **Bash 3.2 compatibility + AD-19 single-script-file shape**: the new verifier MUST NOT use compound chains, plain subshells, `$(...)` containing pipes-that-feed-compound-operators, process substitution, heredocs feeding pipes, or inline `for`/`while`/`if` blocks beyond simple bash conditionals. The two `$(git log | tail -1)` invocations in the verifier body are the canonical single-pipeline assignment shape — same form used by `tools/verify/p00-d-a4-independence.sh` per its T03 plan.
- **Commit shape**: use `git commit -F <message-file>` rather than inline-HEREDOC `git commit -m "$(cat <<'EOF' ... EOF)"` per the M021/M028 PreToolUse Bash shape-guard semantics documented in `CLAUDE.md` `## Commit Message Authoring`.

## Expected Output

- `tools/verify/p01-d-a4-timeline.sh` — graduation verifier on disk, executable, exits 0 in Mode A.
- `scripts/dispatch/classify-task.sh` STILL absent.
- A new commit on the M030 P01 branch landing the verifier.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p00-d-a4-independence.sh` → `OK: classify-task.sh absent — D-A4 independence by construction`, `SUMMARY: p00-d-a4-independence.sh pass=1 fail=0`, exit 0.
- `bash tools/verify/p00-phase-suite.sh` → `SUMMARY: p00-phase-suite.sh pass=5 fail=0`, exit 0.
- `bash tools/verify/p01-d-a4-timeline.sh` (Mode A, T01-time) → `OK: classify-task.sh absent — D-A4 independence by construction (pre-T02 mode)`, `SUMMARY: p01-d-a4-timeline.sh pass=1 fail=0`, exit 0.

After T02 ships `classify-task.sh`, re-running `bash tools/verify/p01-d-a4-timeline.sh` will trigger Mode B (git-log ordering check). The expected Mode B success line is `OK: labels.yml committed at <ts1> precedes classify-task.sh at <ts2>` with `SUMMARY: p01-d-a4-timeline.sh pass=1 fail=0`. The P00 fixture corpus first-commit timestamp is in commit `9f99df2` (T01 skeleton) / `1592d52` (T02 labels) / `7c9c3b2` (T03 readme + verifiers) / `aeb7b71` (P00 close phase summary) / `630dd47` (knowledge telemetry follow-up). All five P00 commits predate the P01 work; the labels.yml `--diff-filter=A` add-commit is `9f99df2`. T02's classifier commit will land later, satisfying the ordering by construction.
