---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M041"
name: "Mock fixtures + verifiers + phase suite"
depends_on: ["T01", "T02"]
---

## Prerequisites

- `scripts/diagnostics/search-issues.sh` exists (from T01)
- `scripts/diagnostics/file-issue.sh` exists (from T02)
- `scripts/diagnostics/triage-issue.sh` exists (from P01)

## Description

Create the `GH_MOCK_DIR` fixture data, all P02 verifier scripts, and the phase suite aggregator. The mock fixtures provide representative GitHub Issue data for offline testing of search-issues.sh and file-issue.sh.

## Steps

1. Create fixture directory: `mkdir -p tests/fixtures/detective/gh-mock`

2. Create `tests/fixtures/detective/gh-mock/issue-list-response.json`:
   ```json
   [
     {
       "number": 42,
       "title": "[detective] scaffold.sh exits 1 when milestone dir exists",
       "body": "## Symptom\n\nscaffold.sh exits non-zero when the milestone directory already exists.\n\n## Environment\n\n- Orchestrator version: 0.9.2\n- Platform: Darwin",
       "labels": [{"name": "detective-triage"}, {"name": "bug"}]
     },
     {
       "number": 15,
       "title": "derive-phase.sh returns unexpected state",
       "body": "The state machine returns 'foo' which is not a valid state. Happens after interrupted auto run.",
       "labels": [{"name": "bug"}]
     },
     {
       "number": 7,
       "title": "Feature request: add --verbose flag to status command",
       "body": "Would be nice to have more detail in orchestrator:status output.",
       "labels": [{"name": "enhancement"}]
     }
   ]
   ```

3. Create `tests/fixtures/detective/gh-mock/issue-create-response.json`:
   ```json
   {
     "number": 999,
     "url": "https://github.com/Build-Fractal/orchestrator/issues/999",
     "title": "[detective] test issue",
     "state": "open"
   }
   ```

4. Create verifier scripts (all under `tools/verify/`, executable, `#!/usr/bin/env bash`, `set -euo pipefail`):

   **m041-p02-search-issues-mock.sh**: Set `GH_MOCK_DIR=tests/fixtures/detective/gh-mock`, run `search-issues.sh --query "scaffold exits milestone"`, verify exit 0, stdout is valid JSON (contains `[` and `"number"`), and at least one result has a `match_score` field.

   **m041-p02-file-issue-mock.sh**: Generate a triage report to a tmpfile via `triage-issue.sh --symptom "test filing"`, set `GH_MOCK_DIR` to a temp directory, run `file-issue.sh --triage-report "$tmpfile"`, verify exit 0 and `$GH_MOCK_DIR/issue-create-request.json` exists and contains `"title"` and `"body"` and `"detective-triage"`.

   **m041-p02-gh-degradation.sh**: Temporarily modify PATH to exclude `gh`, run `search-issues.sh --query "test"` (without GH_MOCK_DIR), verify exit 0 and stderr contains `DETECTIVE: gh unavailable`. Use `env PATH="/usr/bin:/bin" bash scripts/diagnostics/search-issues.sh ...` pattern to exclude gh.

   **m041-p02-mock-substitution.sh**: Set `GH_MOCK_DIR=tests/fixtures/detective/gh-mock`, run `search-issues.sh --query "test"`, verify that the script did NOT call `gh` (it should have read from mock). Check that output is valid JSON array.

   **m041-p02-file-issue-comment.sh**: Generate a triage report to tmpfile, set `GH_MOCK_DIR` to a temp directory, run `file-issue.sh --triage-report "$tmpfile" --comment-on 42`, verify exit 0 and `$GH_MOCK_DIR/issue-comment-request.json` exists and contains `"issue_number"` and `"comment"`.

   **m041-p02-phase-suite.sh**: Aggregator — iterate over all `tools/verify/m041-p02-*.sh` (excluding itself), run each, count pass/fail, print `SUITE: pass=N fail=M`, exit 1 if any failures.

5. Run the phase suite: `bash tools/verify/m041-p02-phase-suite.sh`

## Must-Haves

- Mock fixture directory and files exist
- All 5 verifiers pass
- Phase suite reports `pass=5 fail=0`

## Verification

```bash
bash tools/verify/m041-p02-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `scripts/diagnostics/search-issues.sh` (from T01)
  - Key API: `--query <text>`, `--repo <owner/name>`; stdout is JSON array; reads `GH_MOCK_DIR` for offline mode
- `scripts/diagnostics/file-issue.sh` (from T02)
  - Key API: `--triage-report <path>`, `--repo <owner/name>`, `--comment-on <N>`; writes to `GH_MOCK_DIR`; stdout is issue number

### From Disk (Pre-existing)

- `scripts/diagnostics/triage-issue.sh` (from P01) — used to generate test triage reports
- `tools/verify/` — project-owned verifier directory

## Constraints

- All verifier filenames must be `m041-p02-*` prefixed
- Bash 3.2+ compatible
- Verifiers must not require real `gh` authentication

## Expected Output

- `tests/fixtures/detective/gh-mock/` with 2 fixture files
- 6 verifier scripts under `tools/verify/m041-p02-*`
- Phase suite: `pass=5 fail=0`
