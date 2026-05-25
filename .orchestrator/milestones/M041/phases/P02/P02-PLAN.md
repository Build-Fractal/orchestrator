---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M041"
goal: "Deliver GitHub integration scripts (search-issues.sh, file-issue.sh) with mock harness so detective can search, file, and comment on Build-Fractal/orchestrator GitHub Issues — with graceful degradation when gh is unavailable"
demo_sentence: "Running search-issues.sh against the mock fixture returns valid JSON with match scores; file-issue.sh writes the correct request to the mock; invoking detective with gh absent from PATH prints the report to stdout with a degradation diagnostic."
risk: "medium"
depends_on: ["P01"]
---

## Must-Haves

### Truths

- `search-issues.sh` exits 0 and returns valid JSON (array of objects with `number`, `title`, `match_score` fields) when run against the `GH_MOCK_DIR` fixture
  - Check: `bash tools/verify/m041-p02-search-issues-mock.sh`
- `file-issue.sh` exits 0 and writes a request file to `$GH_MOCK_DIR/issue-create-request.json` containing the expected title, labels, and body when run against the mock
  - Check: `bash tools/verify/m041-p02-file-issue-mock.sh`
- When `gh` is absent from PATH, detective exits 0 and stderr contains `DETECTIVE: gh unavailable`
  - Check: `bash tools/verify/m041-p02-gh-degradation.sh`
- `search-issues.sh` respects `GH_MOCK_DIR` for offline testing — when set, reads from mock files instead of calling `gh`
  - Check: `bash tools/verify/m041-p02-mock-substitution.sh`
- `file-issue.sh` supports both create and comment modes — `--comment-on <N>` comments on an existing issue, otherwise creates a new one
  - Check: `bash tools/verify/m041-p02-file-issue-comment.sh`

### Artifacts

- `scripts/diagnostics/search-issues.sh` (min 40 lines, contains "match_score")
- `scripts/diagnostics/file-issue.sh` (min 40 lines, contains "issue create")
- `tests/fixtures/detective/gh-mock/issue-list-response.json` (min 5 lines, contains "number")

### Key Links

- `commands/detective.md` → `scripts/diagnostics/search-issues.sh` (already referenced, now script exists)
- `commands/detective.md` → `scripts/diagnostics/file-issue.sh` (already referenced, now script exists)

## Tasks

### T01: search-issues.sh — GitHub issue search with mock harness

Implement the issue search script with `GH_MOCK_DIR` offline testing support.

### T02: file-issue.sh — GitHub issue create/comment with mock harness

Implement the issue filing script with mock support for both create and comment modes.

### T03: Mock fixtures + verifiers + phase suite

Create the mock fixture data and all P02 verifier scripts, then run the suite.

## Task Dependencies

T01 → T02 → T03

## Files Likely Touched

- `scripts/diagnostics/search-issues.sh` (create)
- `scripts/diagnostics/file-issue.sh` (create)
- `tests/fixtures/detective/gh-mock/issue-list-response.json` (create)
- `tests/fixtures/detective/gh-mock/issue-create-response.json` (create)
- `tools/verify/m041-p02-search-issues-mock.sh` (create)
- `tools/verify/m041-p02-file-issue-mock.sh` (create)
- `tools/verify/m041-p02-gh-degradation.sh` (create)
- `tools/verify/m041-p02-mock-substitution.sh` (create)
- `tools/verify/m041-p02-file-issue-comment.sh` (create)
- `tools/verify/m041-p02-phase-suite.sh` (create)
