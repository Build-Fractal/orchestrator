---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M041"
name: "file-issue.sh confirmation gate + test updates"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/file-issue.sh` exists (from P02) with mock + live write paths
- `commands/detective.md` already documents `--yes` and the FR-9 TTY rule (from P01)

## Description

Add the FR-9 confirmation gate to `file-issue.sh`: a `--yes` flag plus a `confirm_or_degrade` function that runs before any GitHub write (mock or live). Update the three write-path verifiers to pass `--yes`, and add P05 gate verifiers.

## Steps

1. **file-issue.sh**: add `assume_yes=0`, parse `--yes`, and define `confirm_or_degrade`:
   - `--yes` → `return 0` (proceed)
   - `[ -t 0 ]` (interactive) → print the action, `read -r` a `[y/N]` reply, proceed only on `y/Y/yes/YES`; otherwise print cancel diagnostic, cat report, `exit 0`
   - non-TTY without `--yes` → print `DETECTIVE: non-interactive without --yes -- report follows for manual filing`, cat report, `exit 0`
   - Call it before the mock branch, with a create-vs-comment action message.

2. **Write-path test updates** (the gate now wraps mock writes, so these must confirm):
   - `tools/verify/m041-p02-file-issue-mock.sh` → add `--yes`
   - `tools/verify/m041-p02-file-issue-comment.sh` → add `--yes`
   - `tools/verify/m041-p03-acceptance-battery.sh` SC-3 → add `--yes`

3. **New P05 verifiers**:
   - `m041-p05-gate-yes-proceeds.sh` — `--yes` + `< /dev/null` writes the mock request
   - `m041-p05-gate-noninteractive-degrades.sh` — no `--yes` + `< /dev/null` → no write, report on stdout, `non-interactive without --yes` on stderr, exit 0
   - `m041-p05-phase-suite.sh` — aggregator

## Must-Haves

- `--yes` proceeds non-interactively
- non-interactive without `--yes` degrades (no write, exit 0)
- P02 suite still green with `--yes` added

## Verification

```bash
bash tools/verify/m041-p05-phase-suite.sh
```

```bash
bash tools/verify/m041-p02-phase-suite.sh
```

## Inputs

### From Disk (Pre-existing)

- `scripts/diagnostics/file-issue.sh` (from P02) — mock path keys on `GH_MOCK_DIR`; live path calls `gh issue create/comment`
- `commands/detective.md` — FR-9 contract (`--yes`, TTY rule)

## Constraints

- Bash 3.2+ compatible (CON-3)
- Gate degrades (never blocks/deadlocks) when non-interactive
- Gate wraps both mock and live writes (faithful simulation)

## Expected Output

- Modified `file-issue.sh` with `--yes` + `confirm_or_degrade`
- 3 write-path verifiers updated with `--yes`
- 3 new P05 verifiers; suite `pass=2 fail=0`; P02 suite still `pass=5 fail=0`
