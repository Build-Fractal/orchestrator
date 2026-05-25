---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M041"
name: "search-issues.sh — GitHub issue search with mock harness"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/triage-issue.sh` exists (from P01)
- `gh` CLI interface is understood (search via `gh issue list --search`)

## Description

Create `scripts/diagnostics/search-issues.sh` — searches Build-Fractal/orchestrator GitHub Issues for matches against a query string. Returns a JSON array of matches with a `match_score` field (keyword overlap count). Supports `GH_MOCK_DIR` env var for offline testing.

## Steps

1. Create `scripts/diagnostics/search-issues.sh` with `#!/usr/bin/env bash` and `set -euo pipefail`.

2. Argument parsing (Bash 3.2 compatible):
   - `--query <text>` — search keywords (required)
   - `--repo <owner/name>` — target repo (default: `Build-Fractal/orchestrator`)
   - `--state <open|closed|all>` — issue state filter (default: `open`)
   - `--limit <N>` — max results (default: 20)

3. Mock substitution: when `GH_MOCK_DIR` is set and non-empty, read from `$GH_MOCK_DIR/issue-list-response.json` instead of calling `gh`. This must be a simple env-var check at the top of the gh-call function.

4. Live path: call `gh issue list --search "<query>" --repo "<repo>" --state "$state" --limit "$limit" --json number,title,body,labels`.

5. Match scoring: for each returned issue, compute `match_score` as the count of query keywords that appear in the issue's title or body (case-insensitive). Extract keywords from query by splitting on whitespace and filtering to words >= 3 chars.

6. Output: emit a JSON array to stdout. Each element has `number`, `title`, `match_score`, and `labels` fields. Sort by `match_score` descending. Use `jq` if available, otherwise construct JSON manually with printf.

7. Graceful degradation: if `gh` is not in PATH and `GH_MOCK_DIR` is not set, emit `[]` to stdout and `DETECTIVE: gh unavailable` to stderr, exit 0.

8. Exit codes: 0 on success (including empty results and degradation), 1 on usage error.

## Must-Haves

- Exits 0 with valid JSON array when run against mock
- Each result object has `number`, `title`, `match_score` fields
- `GH_MOCK_DIR` substitution works for offline testing
- Graceful degradation when `gh` is absent

## Verification

```bash
bash tools/verify/m041-p02-search-issues-mock.sh
```

## Inputs

### From Disk (Pre-existing)

- `commands/detective.md` — references this script by name

## Constraints

- Bash 3.2+ compatible (CON-3)
- `jq` is optional — script must work without it (construct JSON with printf)
- No writes to `.orchestrator/` (CON-2)

## Expected Output

`scripts/diagnostics/search-issues.sh` (~80-120 lines, executable) that searches GitHub Issues via `gh` or reads from `GH_MOCK_DIR`, computes keyword match scores, and emits sorted JSON.
