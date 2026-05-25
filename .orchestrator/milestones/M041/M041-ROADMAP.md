---
schema_version: "1.0"
type: roadmap
milestone: "M041"
feature_ref: "041-detective"
feature_spec: "specs/041-detective/spec.md"
vision: "Structured triage-to-GitHub pipeline for orchestrator-internal issues with cross-command discoverability"
tier: "B"
created_at: "2026-05-25T05:35:00Z"
updated_at: "2026-05-25T05:35:00Z"
---

## Phases

- [x] **P01**: Core triage engine + command definition — "Running `triage-issue.sh --symptom 'test' --capture-log` exits 0 and prints a structured report with all six body sections; `commands/detective.md` passes shape lint."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces: `scripts/diagnostics/triage-issue.sh`, `commands/detective.md`, triage-report schema (6-section Markdown with YAML frontmatter)
    - Consumes: `references/file-formats.md` (execution-log JSONL schema), `scripts/state/resolve-root.sh` (orchestrator root resolution), `templates/` (command-doc structure conventions)

- [x] **P02**: GitHub integration + mock harness — "Running `search-issues.sh` against the mock fixture returns valid JSON with match scores; `file-issue.sh` writes the correct request to the mock; invoking detective with `gh` absent from PATH prints the report to stdout with a degradation diagnostic."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces: `scripts/diagnostics/search-issues.sh`, `scripts/diagnostics/file-issue.sh`, `tests/fixtures/detective/gh-mock/` (mock fixture directory with `issue-list-response.json` and `issue-create-response.json`), `GH_MOCK_DIR` env-var convention
    - Consumes: triage-report schema (from P01), `scripts/diagnostics/triage-issue.sh` (from P01)

- [x] **P03**: Doctor hook + acceptance battery — "Running `run-doctor.sh` with failing checks emits `RECOMMEND: orchestrator:detective` on stderr; the full acceptance battery (SC-1 through SC-7) passes."
  - Risk: low
  - Depends: P02
  - Boundary Map:
    - Produces: recommendation hook in `scripts/diagnostics/run-doctor.sh`, `scripts/diagnostics/detective-recommend.sh` (shared helper), acceptance battery at `tools/verify/m041-p03-acceptance-battery.sh`
    - Consumes: `scripts/diagnostics/triage-issue.sh` (from P01), `scripts/diagnostics/search-issues.sh` (from P02), `scripts/diagnostics/file-issue.sh` (from P02), `tests/fixtures/detective/gh-mock/` (from P02), `scripts/state/resolve-root.sh` (for `$ORCHESTRATOR_ROOT` prefix comparison in FR-8)
  - Note: P03 shipped only the doctor hook. FR-8's verify/auto/dispatch hooks were deferred to P04 (gap surfaced by post-implementation code review). P03's original boundary map over-claimed verify/auto/dispatch guidance — corrected here.

- [ ] **P04**: Complete FR-8 — auto/dispatch/verify recommendation hooks — "Feeding `auto-loop.sh` an unexpected state emits `RECOMMEND: orchestrator:detective` on stderr; `commands/verify.md` and `commands/dispatch.md` carry detective-recommendation guidance in their Error Handling sections; doctor's hook names the specific failing checks."
  - Risk: low
  - Depends: P03
  - Boundary Map:
    - Produces: mechanical hook in `scripts/lifecycle/auto-loop.sh` (unexpected-state exit-12 seam), detective-recommendation guidance in `commands/verify.md` + `commands/dispatch.md` Error Handling sections, improved specific-symptom emission in `scripts/diagnostics/run-doctor.sh`, P04 verifiers + phase suite
    - Consumes: `scripts/diagnostics/detective-recommend.sh` (from P03), `scripts/state/resolve-root.sh` (path disambiguation)

## Cross-Cutting Concerns

- **Graceful degradation** — P01, P02, P03. P01 establishes the degradation pattern (missing execution-log → empty section, not failure). P02 extends it to GitHub operations (missing `gh` → stdout-only mode with diagnostic). P03 must follow the same pattern for recommendation hooks (missing detective script → no recommendation, not failure).
- **Bash 3.2 compatibility (CON-3)** — P01, P02, P03. All new scripts must avoid Bash 4+ features (associative arrays, `${var,,}`, `|&`). P01 establishes the baseline; P02 and P03 must conform.
- **TTY/pipe stdin handling** — P01, P02. P01 implements the FR-10 pipe-input reader and FR-9 TTY-detection rule. P02 wires the confirmation gate to the TTY-detection rule for GitHub actions. The interaction between FR-9 and FR-10 is the conversus gate's RISK-04 surface — P01 must get this right because P02 depends on it.

## Dependency Graph

```
P01 → P02 → P03 → P04
```

Linear dependency chain. No parallelization opportunities — each phase builds on the prior phase's artifacts.

## Execution Order

1. **P01** — foundation, no dependencies. Highest risk (report schema is a versioned contract, TTY/pipe interaction). Delivers US-1 (manual triage).
2. **P02** — depends on P01. Medium risk (external `gh` integration, mock harness). Delivers US-2 (GitHub search and filing) and US-3 (PR suggestion via `--suggest-fix`).
3. **P03** — depends on P02. Low risk (single-line stderr additions to existing commands). Delivers US-4 (cross-command hooks) and the acceptance battery covering SC-1 through SC-7.

## Validation

- **No conflicting producers**: PASS — each script is produced by exactly one phase; no overlapping artifacts.
- **All consumed items have producers**: PASS — P02 consumes triage-report schema and `triage-issue.sh` from P01; P03 consumes all three scripts from P01/P02 and the mock fixture from P02. All consumed items trace to a produces entry in an upstream phase.
- **DAG is acyclic**: PASS — linear chain P01 → P02 → P03, no cycles.
- **Demo sentence coverage**: PASS — each phase has a concrete, mechanically testable demo sentence referencing specific scripts and observable outputs.
