---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M041"
goal: "Implement the FR-9 confirmation gate in file-issue.sh so GitHub writes require operator confirmation (--yes, interactive prompt, or non-interactive degrade)"
demo_sentence: "file-issue.sh --yes writes; without --yes in a non-interactive context it degrades to stdout-only (no GitHub write); an interactive TTY prompts before writing."
risk: "medium"
depends_on: ["P04"]
---

## Must-Haves

### Truths

- With `--yes`, `file-issue.sh` proceeds with the write even non-interactively (stdin not a TTY)
  - Check: `bash tools/verify/m041-p05-gate-yes-proceeds.sh`
- Without `--yes` in a non-interactive context, `file-issue.sh` degrades to stdout-only — no GitHub write, report printed, exit 0
  - Check: `bash tools/verify/m041-p05-gate-noninteractive-degrades.sh`
- The pre-existing write-path verifiers (P02 mock/comment, P03 SC-3) still pass with `--yes` added
  - Check: `bash tools/verify/m041-p02-phase-suite.sh`

### Artifacts

- `scripts/diagnostics/file-issue.sh` (modify — `--yes` flag + `confirm_or_degrade` gate)

### Key Links

- `commands/detective.md` → `scripts/diagnostics/file-issue.sh` (`--yes` contract documented in P01, enforced here)

## Tasks

### T01: file-issue.sh confirmation gate + test updates

Single cohesive task — gate implementation, write-path test updates, new gate verifiers.

## Task Dependencies

T01 (single task)

## Files Likely Touched

- `scripts/diagnostics/file-issue.sh` (modify)
- `tools/verify/m041-p02-file-issue-mock.sh` (modify — add `--yes`)
- `tools/verify/m041-p02-file-issue-comment.sh` (modify — add `--yes`)
- `tools/verify/m041-p03-acceptance-battery.sh` (modify — SC-3 add `--yes`)
- `tools/verify/m041-p05-gate-yes-proceeds.sh` (create)
- `tools/verify/m041-p05-gate-noninteractive-degrades.sh` (create)
- `tools/verify/m041-p05-phase-suite.sh` (create)

## Design Notes

The gate sits before BOTH the mock and live write branches so the mock faithfully simulates the gated real flow. Three branches (FR-9):

- `--yes` → proceed.
- interactive TTY (`[ -t 0 ]`) → prompt `[y/N]`, read from stdin, proceed only on yes; otherwise degrade.
- non-TTY without `--yes` → degrade to stdout-only (print report, exit 0). This is the deadlock-prevention path: when FR-10 piped input has consumed stdin, there is no TTY to read a confirmation from, so we must not block.

Because the gate wraps the mock path too, the three pre-existing write-path verifiers must opt in with `--yes` — they exercise the *write*, which now legitimately requires confirmation.
