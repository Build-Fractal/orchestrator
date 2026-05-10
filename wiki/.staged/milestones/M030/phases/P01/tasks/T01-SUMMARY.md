---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M030"
provides:
  - "tools/verify/p01-d-a4-timeline.sh"
requires:
  - "from:P00 what:tests/fixtures/m030-classifier-corpus/labels.yml,tools/verify/p00-d-a4-independence.sh,tools/verify/p00-phase-suite.sh"
affects:
  - "P01/T02"
key_files:
  - "tools/verify/p01-d-a4-timeline.sh"
key_decisions:
  - "D-A4 timeline-graduation verifier authored before classify-task.sh ships -- automatic mode swap on T02 commit"
patterns_established:
  - "graduation-verifier-pattern (two-mode pre/post-graduation gate keyed off filesystem state); single-pipeline command-substitution exemption under AD-19"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P01/tasks/T01-d-a4-timeline-graduation-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-30T11:50:43Z"
---

## What was built

`tools/verify/p01-d-a4-timeline.sh` (69 lines) — the D-A4/SC-10 timeline-ordering graduation verifier. Two-mode operation:

- **Mode A** (pre-T02, `scripts/dispatch/classify-task.sh` absent on disk): pass by absence — delegates to the same independence-by-construction semantics as `tools/verify/p00-d-a4-independence.sh`. Emits `OK: classify-task.sh absent -- D-A4 independence by construction (pre-T02 mode)`.
- **Mode B** (post-T02, `classify-task.sh` exists): asserts via `git log --diff-filter=A --pretty=format:%at` that `tests/fixtures/m030-classifier-corpus/labels.yml`'s first-add commit timestamp is numerically less than `scripts/dispatch/classify-task.sh`'s first-add commit timestamp. Emits `OK: labels.yml committed at <ts1> precedes classify-task.sh at <ts2>` on success.

Output contract: stdout final line is `SUMMARY: p01-d-a4-timeline.sh pass=N fail=M`. Exit 0 iff `pass=1 fail=0`. Bash 3.2 compatible. AD-19 single-script-file shape — uses only `[ ... ]` conditionals, single-pipe `$(git log ... | tail -1)` assignment (the canonical shape used in `tools/verify/p00-d-a4-independence.sh`), and `echo`. No compound `&&`/`||` chains, no process substitution, no heredocs feeding pipes.

T01 ends with `scripts/dispatch/classify-task.sh` STILL absent on disk. The classifier is T02's deliverable; T01 ships only the verifier so it is on-disk before classify-task.sh is, and the moment T02 commits the classifier, re-running the verifier will fire Mode B automatically.

## Verification results

All three Must-Have verifiers pass at T01 close:

- `bash tools/verify/p00-d-a4-independence.sh` → `OK: classify-task.sh absent -- D-A4 independence by construction`, `SUMMARY: p00-d-a4-independence.sh pass=1 fail=0`, exit 0.
- `bash tools/verify/p00-phase-suite.sh` → 5 sub-gates pass (corpus-shape pass=6/0, plans-exist pass=40/0, class-coverage pass=5/0, readme-shape pass=7/0, d-a4-independence pass=1/0). Final: `SUMMARY: p00-phase-suite.sh pass=5 fail=0`, exit 0.
- `bash tools/verify/p01-d-a4-timeline.sh` (Mode A) → `OK: classify-task.sh absent -- D-A4 independence by construction (pre-T02 mode)`, `SUMMARY: p01-d-a4-timeline.sh pass=1 fail=0`, exit 0.

## Patterns established

- **Graduation-verifier pattern** — a single verifier that operates in two modes (pre-graduation absence-check / post-graduation ordering-check) keyed off filesystem state. The pre-graduation mode preserves the proxy semantics of the prior phase's gate; the post-graduation mode strengthens to the real check the moment its preconditions are met. Authoring the verifier *before* the gated artifact ships means the assertion fires automatically on the next dispatch — no separate "swap the verifier" task.
- **Single-pipeline command-substitution exemption (AD-19)** — `$(git log --diff-filter=A --pretty=format:%at -- "$path" | tail -1)` is permitted: it is a plain command-substitution with one pipe whose output is assigned to a variable. The forbidden shape is `$()` containing pipes feeding *further compound operators*, not single-pipeline assignment.

## Notes for downstream

- T02 (`scripts/dispatch/classify-task.sh` author) does NOT need to graduate any verifier — the graduation is automatic. After T02's commit lands, re-running `bash tools/verify/p01-d-a4-timeline.sh` triggers Mode B.
- The labels.yml `--diff-filter=A` add-commit is `9f99df2`. T02's classifier commit will land later, satisfying the timeline ordering by construction (commits are linearly-ordered by `%at`).
- D-A4 independence is now permanently locked by version control — no future amendment to the corpus or to the classifier can violate the timeline-ordering proof without producing a verifier failure.
