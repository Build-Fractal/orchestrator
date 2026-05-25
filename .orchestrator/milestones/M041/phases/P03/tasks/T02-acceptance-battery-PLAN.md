---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M041"
name: "Acceptance battery + phase suite"
depends_on: ["T01"]
---

## Prerequisites

- All P01 deliverables: `scripts/diagnostics/triage-issue.sh`, `commands/detective.md`
- All P02 deliverables: `scripts/diagnostics/search-issues.sh`, `scripts/diagnostics/file-issue.sh`, `tests/fixtures/detective/gh-mock/`
- P03/T01 deliverable: `scripts/diagnostics/detective-recommend.sh`, modified `run-doctor.sh`

## Description

Create the full acceptance battery (`tools/verify/m041-p03-acceptance-battery.sh`) covering SC-1 through SC-7 from the spec, plus the individual P03 verifiers and phase suite. This is the final milestone-level quality gate.

## Steps

1. **Create `tools/verify/m041-p03-doctor-recommendation.sh`**:
   - Run `bash scripts/diagnostics/run-doctor.sh 2>"$tmpfile"` against the current project
   - The current project may or may not have orchestrator-side orphans — this test verifies the hook is wired, not that it fires on every run
   - Verify that `detective-recommend.sh` exists and is callable: `bash scripts/diagnostics/detective-recommend.sh --symptom "test orphan" --path "$ORCH_ROOT/scripts/nonexistent.sh"` emits `RECOMMEND:` to stderr
   - Print PASS/FAIL

2. **Create `tools/verify/m041-p03-path-disambiguation.sh`**:
   - Resolve `$ORCHESTRATOR_ROOT` via `scripts/state/resolve-root.sh`
   - Test orchestrator-internal path: `bash scripts/diagnostics/detective-recommend.sh --symptom "test" --path "$ORCH_ROOT/scripts/foo.sh" 2>"$tmpfile"` — stderr must contain `RECOMMEND:`
   - Test user-project path: `bash scripts/diagnostics/detective-recommend.sh --symptom "test" --path "/some/user/project/scripts/foo.sh" 2>"$tmpfile"` — stderr must NOT contain `RECOMMEND:`
   - Print PASS/FAIL

3. **Create `tools/verify/m041-p03-acceptance-battery.sh`** covering SC-1 through SC-7:

   **SC-1**: `bash scripts/diagnostics/triage-issue.sh --symptom "test symptom" --capture-log` exits 0 and stdout contains all 6 body sections.
   
   **SC-2**: `GH_MOCK_DIR=<fixture-path> bash scripts/diagnostics/search-issues.sh --query "test query" --repo Build-Fractal/orchestrator` exits 0 and stdout is valid JSON with `number`, `title`, `match_score` fields.
   
   **SC-3**: Generate a triage report to tmpfile, then `GH_MOCK_DIR=<tmpdir> bash scripts/diagnostics/file-issue.sh --triage-report <tmpfile> --repo Build-Fractal/orchestrator` exits 0 and the mock request file contains `title`, `labels`, `body`.
   
   **SC-4**: `env PATH="/usr/bin:/bin" GH_MOCK_DIR="" bash scripts/diagnostics/search-issues.sh --query "test" 2>"$tmpfile"` exits 0 and stderr contains `DETECTIVE: gh unavailable`.
   
   **SC-5**: `commands/detective.md` exists and contains `description:` in frontmatter.
   
   **SC-6**: `bash scripts/diagnostics/detective-recommend.sh --symptom "test orphan" --path "$ORCH_ROOT/scripts/nonexistent.sh" 2>"$tmpfile"` — stderr contains `RECOMMEND: orchestrator:detective`.
   
   **SC-7**: Run `bash scripts/diagnostics/triage-issue.sh --symptom "acceptance test" 2>/dev/null > /dev/null` then check `.orchestrator/execution-log.jsonl` for a recent `unit_close` with `command` containing `detective` or `triage`. Note: triage-issue.sh per CON-2 does NOT write to execution-log — SC-7 tests the detective command's overall unit_close. Since the full orchestrator:detective command isn't wired as an executable script yet (it's a command doc, not a CLI entry point), mark SC-7 as SKIP with reason "detective command-level unit_close requires full command wiring, not individual script invocation; verify manually at milestone close".

   Print summary: `BATTERY: pass=N skip=M fail=0` with per-SC lines.

4. **Create `tools/verify/m041-p03-phase-suite.sh`**: aggregator over all `m041-p03-*.sh` verifiers.

5. **Run the suite**: `bash tools/verify/m041-p03-phase-suite.sh`

## Must-Haves

- SC-1 through SC-6 pass
- SC-7 documented as SKIP with rationale
- Phase suite reports pass=3 fail=0

## Verification

```bash
bash tools/verify/m041-p03-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `scripts/diagnostics/detective-recommend.sh` (from T01)
  - Key API: `--symptom <text>`, `--path <error-path>`; emits `RECOMMEND:` to stderr for orchestrator-internal paths; exit 0 always
- `scripts/diagnostics/run-doctor.sh` (modified by T01) — calls detective-recommend.sh after checks

### From Disk (Pre-existing)

- All P01/P02 deliverables (triage-issue.sh, search-issues.sh, file-issue.sh, commands/detective.md, mock fixtures)
- `scripts/state/resolve-root.sh` — for path comparison in disambiguation test

## Constraints

- Bash 3.2+ compatible
- Verifier filenames: `m041-p03-*`
- SC-7 SKIP is acceptable — the command-level unit_close is wired when the detective skill is registered, not when individual scripts are invoked

## Expected Output

- 4 verifier scripts under `tools/verify/m041-p03-*`
- Acceptance battery: `BATTERY: pass=6 skip=1 fail=0`
- Phase suite: `pass=3 fail=0`
