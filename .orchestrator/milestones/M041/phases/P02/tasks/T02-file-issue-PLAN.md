---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M041"
name: "file-issue.sh — GitHub issue create/comment with mock harness"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/triage-issue.sh` exists (from P01) — produces the triage report body
- `scripts/diagnostics/search-issues.sh` exists (from T01) — provides match results

## Description

Create `scripts/diagnostics/file-issue.sh` — creates a new GitHub Issue or comments on an existing one with a triage report. Supports `GH_MOCK_DIR` for offline testing. Title format: `[detective] <first-60-chars-of-symptom>`. Labels: `detective-triage`.

## Steps

1. Create `scripts/diagnostics/file-issue.sh` with `#!/usr/bin/env bash` and `set -euo pipefail`.

2. Argument parsing (Bash 3.2 compatible):
   - `--triage-report <path>` — path to the triage report file (required)
   - `--repo <owner/name>` — target repo (default: `Build-Fractal/orchestrator`)
   - `--comment-on <N>` — comment on existing issue number N instead of creating new
   - `--title <text>` — override auto-generated title
   - `--labels <csv>` — override labels (default: `detective-triage`)

3. Title generation: if `--title` not provided, extract the `symptom:` field from the triage report YAML frontmatter, take the first 60 characters, prefix with `[detective] `.

4. Mock substitution: when `GH_MOCK_DIR` is set:
   - For create mode: write a JSON file to `$GH_MOCK_DIR/issue-create-request.json` with fields `title`, `body`, `labels`, `repo`, `mode` (value: `"create"`). Print `DETECTIVE: opened #999 (mock)` to stderr. Print `999` to stdout.
   - For comment mode: write to `$GH_MOCK_DIR/issue-comment-request.json` with fields `issue_number`, `body`, `repo`, `mode` (value: `"comment"`). Print `DETECTIVE: commented on #<N> (mock)` to stderr. Print the issue number to stdout.

5. Live path (create): `gh issue create --repo "$repo" --title "$title" --label "$labels" --body "$(cat "$triage_report")"`. Parse the created issue URL from stdout to extract the issue number.

6. Live path (comment): `gh issue comment "$issue_number" --repo "$repo" --body "$(cat "$triage_report")"`. Print the issue number.

7. Graceful degradation: if `gh` is not in PATH and `GH_MOCK_DIR` is not set:
   - Print `DETECTIVE: gh unavailable — report printed to stdout` to stderr
   - Cat the triage report to stdout
   - Exit 0

8. Mid-operation failure (RISK-07 / #Q-5): if `gh` returns non-zero (403/429/network error):
   - Print `DETECTIVE: GitHub action failed — report follows for manual filing` to stderr
   - Cat the triage report to stdout
   - Exit 0

9. Exit codes: 0 on success (including degradation), 1 on usage error (missing `--triage-report`).

## Must-Haves

- Create mode writes correct request JSON to mock
- Comment mode writes correct request JSON to mock  
- Graceful degradation when `gh` absent
- Mid-operation failure prints report to stdout

## Verification

```bash
bash tools/verify/m041-p02-file-issue-mock.sh
```

```bash
bash tools/verify/m041-p02-file-issue-comment.sh
```

## Inputs

### From Disk (Pre-existing)

- `scripts/diagnostics/triage-issue.sh` (from P01) — produces triage reports consumed as `--triage-report` input
  - Key API: stdout is YAML-frontmatter + 6-section Markdown; `symptom:` in frontmatter used for title generation

## Constraints

- Bash 3.2+ compatible (CON-3)
- No writes to `.orchestrator/` (CON-2)
- Rate limit respect (CON-4): no retry on 403/429

## Expected Output

`scripts/diagnostics/file-issue.sh` (~80-120 lines, executable) that creates/comments on GitHub Issues via `gh` or writes mock request files to `GH_MOCK_DIR`.
