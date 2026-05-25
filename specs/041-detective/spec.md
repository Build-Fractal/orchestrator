---
schema_version: "1.0"
type: feature-spec
feature_slug: "041-detective"
created_at: "2026-05-25"
status: "Draft"
milestone: "M041"
---

# Feature Specification: 041-detective

**Feature Branch**: `041-detective`
**Created**: 2026-05-25
**Status**: Draft
**Milestone**: M041
**Input**: User description: "orchestrator:detective — a new command that triages issues with the orchestrator itself (not user-project bugs), searches Build-Fractal/orchestrator GitHub Issues for matches, either comments on existing issues or opens new ones with a structured triage report, and suggests PRs for simple fixes. Auto-recommended by other commands (doctor, verify, auto, dispatch) when they detect orchestrator-side inconsistencies."

## Problem Statement

When an orchestrator command encounters an internal inconsistency — a script that exits non-zero unexpectedly, a template that fails validation, a state-machine derivation that produces an impossible state — the operator is left to diagnose the issue manually, search GitHub Issues by hand, and decide whether to file a new issue or comment on an existing one. There is no structured path from "the orchestrator broke" to "a triage report exists on GitHub."

Three concrete pain-points follow from this gap: (1) **Duplicate issue filing** — operators encountering the same bug independently file separate issues because there is no search-before-file workflow; related issues fragment across the tracker and maintainers waste triage time deduplicating. (2) **Lost diagnostic context** — by the time an operator navigates to GitHub to file an issue, the shell output, stack trace, and disk-state snapshot that would make the report actionable have scrolled away or been discarded; triage reports lack the structured evidence that Constitution Principle II demands. (3) **Invisible fix opportunities** — simple issues (typo in a template path, missing file that scaffold should have created, off-by-one in a script) could be addressed with a single-commit PR, but the operator-to-PR path has too much friction; the fix rots in the tracker instead.

The minimum surface that fixes all three: a new `orchestrator:detective` command backed by three diagnostic scripts (`triage-issue.sh`, `search-issues.sh`, `file-issue.sh`) that capture structured triage context, search `Build-Fractal/orchestrator` GitHub Issues for matches, and either comment on an existing issue or open a new one — plus cross-command recommendation hooks so that `doctor`, `verify`, `auto`, and `dispatch` surface a "run detective" suggestion when they detect orchestrator-side inconsistencies.

This feature explicitly does not attempt to debug user-project bugs (that is `orchestrator:diagnose`), replace the `doctor` health-check suite, or implement automated PR creation beyond suggesting a fix description and the files to change.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

US-1 (manual triage) + US-2 (GitHub search) + FR-1 through FR-6. This slice delivers the core loop: operator invokes `detective` with a symptom description or error output, the command captures diagnostic context, searches GitHub Issues, and either comments on a match or opens a new issue. Cross-command recommendation hooks (US-4) and PR suggestion (US-3) build on top of this slice but are not required to close the dogfood loop — manual invocation with GitHub round-trip is the load-bearing deliverable.

### User Story 1 — Manual Triage (Priority: P1)

As an orchestrator operator who has encountered an internal inconsistency (script failure, unexpected state, template error), I want to run `orchestrator:detective` with a description of the symptom so that a structured triage report is generated capturing the error context, relevant disk state, and recent execution-log entries — without me having to manually assemble this information.

**Why this priority**: This is the foundation — without structured triage capture, the GitHub integration (US-2) and cross-command hooks (US-4) have nothing to operate on.

**Independent Test**: Run `scripts/diagnostics/triage-issue.sh --symptom "scaffold.sh exits 1 when milestone dir exists" --capture-log` in a fixture project with a seeded execution-log.jsonl. Verify exit 0 and that stdout contains a YAML-frontmatter triage report with fields: `symptom`, `captured_at`, `orchestrator_version`, `recent_log_entries`, `relevant_files`, `disk_state_snapshot`.

**Acceptance Scenarios**:

1. **Given** an orchestrator-installed project with execution history, **When** the operator runs `detective --symptom "derive-phase.sh returns impossible state 'foo'"`, **Then** a triage report is emitted to stdout containing the symptom, the orchestrator version, the last 10 execution-log entries, and a list of files matching the symptom keywords.
2. **Given** an orchestrator-installed project with no execution-log.jsonl, **When** the operator runs `detective --symptom "missing lock file"`, **Then** the triage report is still generated with `recent_log_entries: []` and a diagnostic noting the missing log.

---

### User Story 2 — GitHub Issue Search and Filing (Priority: P1)

As an orchestrator operator with a triage report, I want the detective command to search `Build-Fractal/orchestrator` GitHub Issues for matching reports and either comment on an existing issue (if a match is found) or open a new issue with the triage report as the body — so that diagnostic context reaches the tracker without manual copy-paste.

**Why this priority**: Co-equal with US-1 because the triage-to-GitHub round-trip is the core value proposition. Without it, detective is just a fancy `echo`.

**Independent Test**: Mock `gh issue list` and `gh issue create` via a `GH_MOCK_DIR` fixture. When `GH_MOCK_DIR` is set, `search-issues.sh` reads `$GH_MOCK_DIR/issue-list-response.json` instead of calling `gh issue list`, and `file-issue.sh` writes `$GH_MOCK_DIR/issue-create-request.json` instead of calling `gh issue create`/`gh issue comment`. A fixture directory at `tests/fixtures/detective/gh-mock/` provides representative mock data. The mock substitution uses Bash 3.2-compatible env-var conditionals (CON-3). Run `scripts/diagnostics/search-issues.sh --query "scaffold exits 1"` against the mock and verify it returns matching issue numbers. Run `scripts/diagnostics/file-issue.sh --triage-report <path>` against the mock and verify it produces the correct arguments in the request file.

**Acceptance Scenarios**:

1. **Given** a triage report and `gh` CLI authenticated against `Build-Fractal/orchestrator`, **When** detective searches and finds an open issue whose title or body contains 3+ keyword matches from the symptom, **Then** detective comments on that issue with the triage report and prints `DETECTIVE: commented on #<N>`.
2. **Given** a triage report and no matching open issues, **When** detective completes the search, **Then** detective opens a new issue with a structured title and the triage report as body, and prints `DETECTIVE: opened #<N>`.
3. **Given** `gh` CLI is not installed or not authenticated, **When** detective attempts the GitHub round-trip, **Then** detective prints the triage report to stdout with a `DETECTIVE: gh unavailable — report printed to stdout` diagnostic and exits 0 (graceful degradation).

---

### User Story 3 — PR Suggestion for Simple Fixes (Priority: P2)

As an orchestrator maintainer reviewing a detective-filed issue, I want the triage report to include a "Suggested Fix" section when the issue is mechanically simple (missing file, typo, single-line change) — so that I can act on it immediately without a separate investigation.

**Why this priority**: P2 because it adds value but is not load-bearing. The core triage-and-file loop works without fix suggestions.

**Independent Test**: Seed a fixture with a known simple issue (e.g., a template referencing a path that doesn't exist). Run `triage-issue.sh` with `--suggest-fix`. Verify the report contains a `## Suggested Fix` section naming the file and the expected change.

**Acceptance Scenarios**:

1. **Given** a symptom that resolves to a single missing file referenced in a template or command, **When** detective runs with `--suggest-fix`, **Then** the triage report includes a `## Suggested Fix` section with the missing file path and the referencing location.
2. **Given** a symptom that does not resolve to a mechanically simple fix, **When** detective runs with `--suggest-fix`, **Then** the `## Suggested Fix` section reads "No simple fix identified — manual investigation required."

---

### User Story 4 — Cross-Command Recommendation Hooks (Priority: P2)

As an orchestrator operator running `doctor`, `verify`, `auto`, or `dispatch`, I want those commands to recommend `orchestrator:detective` when they detect an orchestrator-side inconsistency (as opposed to a user-project issue) — so that I discover the detective workflow without having to know it exists.

**Why this priority**: P2 because it improves discoverability but the detective command is fully functional without it. Can ship in a later phase after the core command stabilizes.

**Independent Test**: Run `scripts/diagnostics/run-doctor.sh` against a fixture with a seeded orchestrator-side anomaly (e.g., orphaned script reference). Verify that stderr contains `RECOMMEND: orchestrator:detective --symptom "<description>"`.

**Acceptance Scenarios**:

1. **Given** `run-doctor.sh` detects an orphaned artifact that references a non-existent script, **When** the doctor check completes, **Then** the output includes a recommendation line: `RECOMMEND: orchestrator:detective --symptom "orphaned reference to <path>"`.
2. **Given** `commands/verify.md` detects a verification failure caused by a missing orchestrator template (not a user-project file), **When** verify completes, **Then** the output includes a recommendation line pointing to detective.
3. **Given** `commands/auto.md` encounters a dispatch failure where the error originates in an orchestrator script (not user code), **When** auto logs the failure, **Then** the failure entry includes a `detective_recommendation` field.

---

## Edge Cases

- **Rate limiting**: `gh` API rate limits may prevent search or file operations. Detective must detect 403/429 responses and degrade to stdout-only mode with a clear diagnostic.
- **Duplicate detection false positives**: Keyword matching may surface issues that are topically related but not the same bug. Detective must present matches with a confidence indicator and require operator confirmation before commenting (unless `--yes` is set).
- **Enormous execution logs**: Projects with thousands of execution-log entries must not cause detective to hang. The log tail is capped at the last 20 entries (configurable via `--log-tail <N>`).
- **Offline operation**: When no network is available, detective must still produce the triage report locally and exit 0. The GitHub round-trip is best-effort.
- **Non-orchestrator repo**: If run outside an orchestrator-installed project, detective exits 2 with "orchestrator not installed" (consistent with other commands).
- **Symptom-less invocation**: If `--symptom` is omitted and stdin is not a pipe, detective prompts for a symptom description interactively. If stdin is a pipe, detective reads the piped content as the symptom.

---

## Functional Requirements

- **FR-1 (triage-report-schema)**: `scripts/diagnostics/triage-issue.sh` produces a structured triage report with YAML frontmatter (`symptom`, `captured_at`, `orchestrator_version`, `config_hash`, `log_tail_count`) and Markdown body sections (`## Symptom`, `## Environment`, `## Recent Execution Log`, `## Relevant Files`, `## Disk State`, `## Suggested Fix`). The `## Suggested Fix` section is always present regardless of flags; when `--suggest-fix` is not passed, the section reads "No simple fix identified — run with --suggest-fix for heuristic analysis." The triage report schema is a versioned contract — implementers must not make section presence conditional on any flag in any version. Satisfies US-1 SC-1.
- **FR-2 (issue-search)**: `scripts/diagnostics/search-issues.sh` searches `Build-Fractal/orchestrator` GitHub Issues using `gh issue list --search "<keywords>" --state open --json number,title,body,labels`. Returns a JSON array of matches with a `match_score` field (keyword overlap count). Satisfies US-2 SC-2.
- **FR-3 (issue-file)**: `scripts/diagnostics/file-issue.sh` creates or comments on a GitHub Issue using `gh issue create` or `gh issue comment`. Title format: `[detective] <first-60-chars-of-symptom>`. Labels: `detective-triage`. Body: the full triage report. Satisfies US-2 SC-2.
- **FR-4 (gh-degradation)**: When `gh` is unavailable (not installed, not authenticated, or API error), all GitHub operations degrade gracefully: the triage report is printed to stdout, exit code remains 0, and a `DETECTIVE: gh unavailable` diagnostic is emitted to stderr. Satisfies US-2 AS-3.
- **FR-5 (command-definition)**: `commands/detective.md` defines the `orchestrator:detective` command with the standard command-doc structure (frontmatter `description:`, sections for usage, prerequisites, output, idempotency, error handling, gotchas, referenced scripts). Satisfies US-1.
- **FR-6 (execution-log-capture)**: The triage report's `## Recent Execution Log` section includes the last N entries (default 20) from `.orchestrator/execution-log.jsonl`, filtered to entries with `result: "FAIL"` or `result: "ERROR"` if `--errors-only` is set. Satisfies US-1 SC-1.
- **FR-7 (suggest-fix)**: When `--suggest-fix` is passed, `triage-issue.sh` runs a heuristic check against the `## Suggested Fix` section (which is always present per FR-1): if the symptom references a file path and that path does not exist, or if the symptom matches a known pattern (missing template, broken symlink, stale reference), the section is populated with the file path, the expected state, and a one-line description of the fix. Without `--suggest-fix`, the section reads "No simple fix identified — run with --suggest-fix for heuristic analysis." The `--suggest-fix` flag controls whether the heuristic *populates* the section, not whether the section is present. Satisfies US-3.
- **FR-8 (cross-command-hooks)**: Commands `doctor`, `verify`, `auto`, and `dispatch` emit a `RECOMMEND: orchestrator:detective --symptom "<description>"` line to stderr when they detect an orchestrator-side inconsistency (defined as: an error whose file path begins with the resolved `$ORCHESTRATOR_ROOT` prefix, obtained via `scripts/state/resolve-root.sh` — errors in user-project paths that incidentally contain `scripts/` or `commands/` subdirectories must not trigger the recommendation hook). Non-interactive callers (auto, dispatch) should include `--yes` in the emitted recommendation format. The recommendation is advisory and never blocks the calling command. Satisfies US-4.
- **FR-9 (confirmation-gate)**: Before commenting on or creating a GitHub Issue, detective presents the action to the operator and waits for confirmation unless `--yes` is passed. Under `--yes`, the action proceeds without confirmation. **TTY-detection rule**: when stdin is not a TTY (`[ ! -t 0 ]`), detective treats the invocation as non-interactive — `--yes` is required to proceed with GitHub actions; without `--yes` in non-interactive mode, detective degrades to stdout-only mode (consistent with FR-4 degradation contract). This prevents deadlock when FR-10 has consumed stdin via pipe. Satisfies Edge Case: duplicate detection false positives.
- **FR-10 (pipe-input)**: When stdin is a pipe, detective reads the piped content as the symptom (equivalent to `--symptom "$(cat)"`). When stdin is a TTY and `--symptom` is omitted, detective prompts interactively. Note: piped invocations consume stdin, so FR-9's confirmation gate cannot read from stdin — the TTY-detection rule in FR-9 governs this interaction. Satisfies Edge Case: symptom-less invocation.

## Success Criteria

- **SC-1**: `bash scripts/diagnostics/triage-issue.sh --symptom "test symptom" --capture-log` exits 0 and stdout contains a report with all six body sections (`## Symptom`, `## Environment`, `## Recent Execution Log`, `## Relevant Files`, `## Disk State`, `## Suggested Fix`).
- **SC-2**: `GH_MOCK_DIR=tests/fixtures/detective/gh-mock bash scripts/diagnostics/search-issues.sh --query "test query" --repo Build-Fractal/orchestrator` exits 0 and stdout is valid JSON (array of objects with `number`, `title`, `match_score` fields). Verifiable via mock without `gh` authentication.
- **SC-3**: `GH_MOCK_DIR=tests/fixtures/detective/gh-mock bash scripts/diagnostics/file-issue.sh --triage-report <path> --repo Build-Fractal/orchestrator` exits 0 and `$GH_MOCK_DIR/issue-create-request.json` contains the expected title, labels, and body. Verifiable via mock without `gh` authentication.
- **SC-4**: Running detective with `gh` absent from PATH exits 0 and stderr contains `DETECTIVE: gh unavailable`.
- **SC-5**: `commands/detective.md` exists and passes `scripts/verify/spec-shape-lint.sh` (well-formed command doc).
- **SC-6**: After modifying `scripts/diagnostics/run-doctor.sh` to include the recommendation hook, running doctor against a fixture with an orchestrator-side orphan produces stderr output matching `RECOMMEND: orchestrator:detective`.
- **SC-7**: The detective command's `unit_close` record appears in `.orchestrator/execution-log.jsonl` after a successful run.

## Non-Goals

- **NG-1 (user-project debugging)**: Detective does not debug user-project bugs. That is `orchestrator:diagnose`'s job. Detective's scope is orchestrator-internal issues only.
- **NG-2 (automated PR creation)**: Detective suggests fixes in the triage report but does not create PRs, branches, or commits. The maintainer acts on the suggestion manually.
- **NG-3 (health-check replacement)**: Detective does not replace `orchestrator:doctor`. Doctor detects symptoms; detective triages and files them. They are complementary, not competing.
- **NG-4 (issue management)**: Detective does not close, label (beyond `detective-triage`), assign, or prioritize issues. It creates/comments and steps back.
- **NG-5 (cross-repo search)**: Detective searches only `Build-Fractal/orchestrator`. Multi-repo issue search is out of scope.

## Constraints

- **CON-1 (gh-CLI-dependency)**: GitHub operations require `gh` CLI (>= 2.0) authenticated against the `Build-Fractal/orchestrator` repo. Detective must not bundle or install `gh`. Graceful degradation (FR-4) is the fallback.
- **CON-2 (no-state-writes)**: Detective does not write to `.orchestrator/milestones/`, `.orchestrator/DECISIONS.md`, or any state-machine-relevant files. It appends to `execution-log.jsonl` only (observability, not state).
- **CON-3 (bash-3.2-compat)**: All new scripts must be Bash 3.2+ / POSIX sh compatible, consistent with the project's shell baseline.
- **CON-4 (rate-limit-respect)**: GitHub API calls must respect rate limits. Detective must not retry on 403/429 — it degrades to stdout-only mode.

### Knowledge-Layer Boundary (this milestone vs. M020)

This milestone creates no new knowledge-graph node types or edge types. The `detective-triage` label and the triage-report schema are orchestrator-internal conventions, not knowledge-layer extensions. If a future milestone wants detective reports to feed into the knowledge graph (e.g., as `lesson/incident` entries), that work belongs in a knowledge-layer milestone (M020 lineage), not here.

## Assumptions

- `gh` CLI is available in the operator's PATH for GitHub integration. If not, detective degrades gracefully (FR-4).
- The `Build-Fractal/orchestrator` GitHub repository exists and the operator has write access (for issue creation/commenting). Read-only access supports search but not filing.
- `scripts/diagnostics/run-doctor.sh` and `commands/verify.md` expose a seam where recommendation lines can be injected without restructuring their output format.
- The execution-log JSONL format (`execution-log.jsonl`) is stable and documented in `references/file-formats.md`.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle II (Evidence Before Claims)**: Detective is the operationalization of Principle II for orchestrator-internal issues. Every triage report captures structured evidence (execution-log entries, disk-state snapshots, file listings) before the issue reaches the tracker. The report schema enforces evidence presence — a report without the `## Recent Execution Log` section is malformed.
- **Principle VI (State On Disk Is Truth)**: Detective reads all diagnostic context from disk (execution-log.jsonl, file system, config). It does not rely on in-memory state from the calling command. The triage report is a snapshot of disk state at capture time.
- **Principle VII (Knowledge Compounds)**: Filed issues with structured triage reports create a searchable knowledge base of orchestrator-internal incidents. Future detective invocations benefit from this history via the GitHub search integration (US-2).
- **Principle VIII (No Dead Infrastructure)**: All three new scripts are referenced by the command definition. The cross-command hooks reference detective by name. No orphaned files.
- **Principle XIV (No Speculative Complexity)**: Detective does not create PRs (NG-2), manage issues (NG-4), or extend the knowledge graph (Knowledge-Layer Boundary). Each scope boundary is explicitly defended.
- **Principle XV (Surgical Precision)**: Cross-command hooks add a single recommendation line to stderr in existing commands. No restructuring of doctor, verify, auto, or dispatch output formats.

## Open Questions (defer to planning)

- **#Q-1 match-score-threshold**: What keyword-overlap count constitutes a "match" for duplicate detection? Strawman: 3+ keywords from the symptom appearing in the issue title or body. Resolved at plan-phase time by the implementer after reviewing typical issue text in `Build-Fractal/orchestrator`. *[Conversus advisory — RISK-06]*: Before implementing `search-issues.sh` match-score logic, the plan-phase implementer must retrieve the 20 most recent issues, compute keyword-overlap counts across semantically unrelated pairs, and document the false-positive rate (target: below 20%). The `--yes` flag must not be used in automated or unattended detective invocations until the threshold has been validated. If false-positive rate exceeds 40% at any threshold <= 10 keywords, escalate to a different detection mechanism.
- **#Q-2 recommendation-hook-scope**: Should the recommendation hook fire in `commands/status.md` and `commands/resume.md` as well, or only in the four commands named in US-4? Resolved at plan-phase time based on how many orchestrator-side errors those commands can surface.
- **#Q-3 triage-report-format**: Should the triage report use YAML frontmatter + Markdown body (as specified) or pure JSON for machine consumption? The Markdown format is human-readable in GitHub Issues; JSON would require a rendering step. Strawman: Markdown with a `--format json` flag for programmatic consumers.
- **#Q-4 repo-config**: Should the target repo (`Build-Fractal/orchestrator`) be hardcoded or configurable via `.orchestrator/config.yml`? Hardcoded is simpler and this is a self-referential tool; configurable supports forks. Strawman: default to `Build-Fractal/orchestrator`, overridable via `--repo <owner/name>` flag and `detective.repo` config key.
- **#Q-5 partial-github-failure-sequence** *[Conversus advisory — RISK-07]*: When search succeeds but file/comment returns 403, the spec should define the operator-facing output sequence: emit triage report to stdout with `DETECTIVE: GitHub action failed — report follows for manual filing` prefix, exit 0, append `unit_close` record with `result: DEGRADED`. Resolved at plan-phase time.
- **#Q-6 fr-8-path-disambiguation** *[Conversus advisory — RISK-05]*: FR-8's path-matching heuristic must use `$ORCHESTRATOR_ROOT` (via `scripts/state/resolve-root.sh`) as the comparison anchor, not bare directory-name substring matching. Plan document must include an Implementation Note specifying prefix comparison and a test fixture verifying that user-project `scripts/` errors do not trigger the recommendation hook. Resolved at plan-phase time.

## Dependencies

- `gh` CLI (>= 2.0) — external tool, not an orchestrator dependency. Graceful degradation when absent.
- `scripts/diagnostics/run-doctor.sh` — existing, modified to add recommendation hook (US-4).
- `commands/verify.md` — existing, modified to add recommendation hook (US-4).
- `commands/auto.md` — existing, modified to add recommendation hook (US-4).
- `commands/dispatch.md` — existing, modified to add recommendation hook (US-4).
- `references/file-formats.md` — existing, consumed for execution-log schema.

## Downstream Consumers (informational, not binding)

- **M040 (ambient feedback loop)** — detective-filed issues could feed into the `/orchestrator-brief` daily synthesis as incident signals, if M040 ships with GitHub Issue reading capability.
- **M034 (interactive review gates)** — detective's triage report schema could be consumed as a decision-packet variant for incident-driven review gates.
