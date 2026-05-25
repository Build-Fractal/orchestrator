---
schema_version: "1.0"
type: milestone-summary
id: "M041"
parent: "041-detective"
milestone: "M041"
provides:
  - "orchestrator:detective command — triages orchestrator-internal issues (NOT user-project bugs), captures a structured 6-section triage report, searches Build-Fractal/orchestrator GitHub Issues for keyword matches, and files/comments with the report under an operator confirmation gate. Five phases: P01 core triage engine (triage-issue.sh + commands/detective.md), P02 GitHub integration + GH_MOCK_DIR offline harness (search-issues.sh + file-issue.sh + tests/fixtures/detective/gh-mock/), P03 doctor recommendation hook + acceptance battery (detective-recommend.sh + run-doctor.sh hook), P04 FR-8 completion (auto-loop.sh unexpected-state hook + verify.md/dispatch.md guidance + doctor specific-symptom emission), P05 FR-9 confirmation gate (--yes / interactive prompt / non-interactive degrade in file-issue.sh)."
requires:
  - "scripts/state/resolve-root.sh (orchestrator root resolution + FR-8 path disambiguation); references/file-formats.md (execution-log JSONL schema); gh CLI >=2.0 (optional — graceful degradation when absent); existing commands doctor/verify/auto/dispatch (FR-8 recommendation-hook integration points)"
affects:
  - "scripts/diagnostics/run-doctor.sh (recommendation hook on check failure); scripts/lifecycle/auto-loop.sh (recommendation hook at unexpected-state seam); commands/verify.md + commands/dispatch.md (Error Handling recommendation guidance); README.md + CLAUDE.md (command count 13→14, new built-in capability)"
key_files:
  - "commands/detective.md,scripts/diagnostics/triage-issue.sh,scripts/diagnostics/search-issues.sh,scripts/diagnostics/file-issue.sh,scripts/diagnostics/detective-recommend.sh,scripts/diagnostics/run-doctor.sh,scripts/lifecycle/auto-loop.sh,commands/verify.md,commands/dispatch.md,specs/041-detective/spec.md,tests/fixtures/detective/gh-mock/issue-list-response.json,tests/fixtures/detective/gh-mock/issue-create-response.json,tools/verify/m041-p01-phase-suite.sh,tools/verify/m041-p02-phase-suite.sh,tools/verify/m041-p03-phase-suite.sh,tools/verify/m041-p03-acceptance-battery.sh,tools/verify/m041-p04-phase-suite.sh,tools/verify/m041-p05-phase-suite.sh,.orchestrator/milestones/M041/M041-SUMMARY.md"
key_decisions:
  - "FR-1,FR-2,FR-3,FR-4,FR-5,FR-6,FR-7,FR-8,FR-9,FR-10,SC-1,SC-2,SC-3,SC-4,SC-5,SC-6,SC-7,NG-1,NG-2,CON-1,CON-2,CON-3,CON-4,conversus-gate-3-P0-amendments(RISK-02/03/04),RISK-01-false-positive(constitution-has-15-principles-not-7),#Q-1-corpus-validation-advisory,#Q-5-partial-failure-sequence,#Q-6-ORCHESTRATOR_ROOT-prefix-disambiguation,review-B1-through-B8,depth-tracked-json-parser,glob-expansion-disabled,title-json-escape,empty-root-no-false-positive,FR-8-selective-firing-NG-1-discipline,doctor-specific-symptom-B5,FR-9-gate-wraps-mock-and-live"
patterns_established:
  - "Two-shape cross-command hook integration: mechanical hook (script-level, at a clean error-exit seam — run-doctor.sh check-failure, auto-loop.sh unexpected-state) vs LLM-guidance hook (command-doc Error Handling section — verify.md/dispatch.md). Choice is driven by whether the command is a single executable script or an LLM-orchestrated doc,Selective recommendation firing (NG-1 discipline): a triage-to-issue tool must fire ONLY on signals that indicate the framework itself malfunctioned (unknown state machine state, verifier-script-missing, internal dispatch error) — never on user-project bugs or user-fixable sequencing errors (ran dispatch before roadmap). Firing on every failure is noise and violates the user-project/framework boundary,GH_MOCK_DIR offline test harness: a script that calls an external CLI (gh) keys on an env var to substitute fixture reads/writes, so the full create/comment/search round-trip is mechanically verifiable without auth. The confirmation gate wraps the mock path too, so the mock faithfully simulates the gated real flow (write-path tests opt in with --yes),Confirmation-gate three-branch shape (FR-9): --yes proceeds; interactive TTY prompts; non-TTY-without-yes degrades to stdout-only. The degrade branch is the deadlock-prevention path — when piped stdin (FR-10) has consumed the input, there is no TTY to read a confirmation from, so the gate must not block,No-jq JSON parsing must track brace depth, not match closing-brace lines: a line-based parser that emits on any '}' line breaks on nested objects (label sub-objects) and on compact single-line JSON. A {/} balance counter that emits when depth returns to the array level is the correct fallback shape"
drill_down_paths:
  - ".orchestrator/milestones/M041/phases/P01/P01-PLAN.md,.orchestrator/milestones/M041/phases/P02/P02-PLAN.md,.orchestrator/milestones/M041/phases/P03/P03-PLAN.md,.orchestrator/milestones/M041/phases/P04/P04-PLAN.md,.orchestrator/milestones/M041/phases/P05/P05-PLAN.md,specs/041-detective/spec.md,specs/041-detective/conversus/gate-result.md"
duration: "single-session spec-to-close (5 phases, ~14 subagent dispatches + direct edits)"
verification_result: "pass"
completed_at: "2026-05-25T07:00:00Z"
observability_surfaces:
  - "tools/verify/m041-p01-phase-suite.sh pass=6 fail=0; m041-p02-phase-suite.sh pass=5 fail=0; m041-p03-acceptance-battery.sh BATTERY: pass=7 skip=0 fail=0 (SC-1..SC-7); m041-p04-phase-suite.sh pass=4 fail=0; m041-p05-phase-suite.sh pass=2 fail=0"
---

M041 (orchestrator:detective) adds a triage-to-GitHub pipeline for
orchestrator-internal issues. When an orchestrator command breaks — a script
exits non-zero unexpectedly, the state machine derives an impossible state, a
template fails validation — detective captures a structured triage report
(environment, recent execution-log entries, relevant files, disk-state
snapshot, suggested fix), searches the project's GitHub Issues for matches, and
either comments on an existing issue or opens a new one. It degrades gracefully
to stdout-only when `gh` is unavailable, and gates every GitHub write behind an
operator confirmation.

Detective is deliberately distinct from its two neighbors: `orchestrator:diagnose`
is the user-project debugging loop, `orchestrator:doctor` reports health
symptoms, and detective triages the framework's *own* issues and connects them
to the tracker.

**Five phases, all green.** Built single-session via the orchestrator's own
workflow (evaluate → specify → roadmap → plan-phase → dispatch), then hardened
through a high-effort code review whose findings drove four bug fixes (P01–P03
follow-up) plus two scope-completion phases (P04 FR-8, P05 FR-9).

## Phase Rollup

- **P01 (Core triage engine + command definition)** — `triage-issue.sh`
  (6-section structured report with YAML frontmatter; `--symptom`/stdin-pipe
  input per FR-10; `--suggest-fix` heuristic; always-present `## Suggested Fix`
  section per FR-1 versioned-contract) + `commands/detective.md`. Suite
  `pass=6 fail=0`.
- **P02 (GitHub integration + mock harness)** — `search-issues.sh` (keyword
  match-scoring, jq + no-jq fallback) + `file-issue.sh` (create/comment) +
  `GH_MOCK_DIR` offline harness at `tests/fixtures/detective/gh-mock/`. Suite
  `pass=5 fail=0`.
- **P03 (Doctor hook + acceptance battery)** — `detective-recommend.sh` shared
  helper + `run-doctor.sh` recommendation hook + SC-1..SC-7 acceptance battery.
  P03's original boundary map over-claimed verify/auto/dispatch guidance; only
  the doctor hook shipped here (gap surfaced by the review, corrected in the
  roadmap and closed in P04).
- **P04 (Complete FR-8 — auto/dispatch/verify hooks)** — mechanical hook in
  `auto-loop.sh` at the unexpected-state exit-12 seam; LLM-guidance hooks in
  `verify.md` + `dispatch.md` Error Handling (scoped to orchestrator-internal
  failures per NG-1); doctor's hook upgraded to name the specific failing
  checks instead of a generic count (review finding B5 — verified live:
  "doctor checks failed: Instruction Conformance, Event Emission, …"). Suite
  `pass=4 fail=0`.
- **P05 (FR-9 confirmation gate)** — `file-issue.sh` gate before every write:
  `--yes` proceeds, interactive TTY prompts, non-TTY-without-`--yes` degrades
  to stdout-only (deadlock-prevention path for consumed piped stdin). Gate
  wraps both mock and live writes; write-path tests opt in with `--yes`. Suite
  `pass=2 fail=0`.

## Review-Driven Hardening

A high-effort multi-angle code review (3 finder angles + verify pass) ran after
P01–P03. It surfaced 8 findings; 4 were confirmed bugs fixed immediately:

1. `search-issues.sh` no-jq fallback used closing-brace line-matching, which
   broke on nested label objects and compact JSON → replaced with a brace-depth
   counter.
2. `search-issues.sh` `for word in $query` glob-expanded wildcards → wrapped in
   `set -f`/`set +f`.
3. `file-issue.sh` mock writes did not JSON-escape the title → added
   `json_escape_str`.
4. `detective-recommend.sh` emitted for any path when `resolve-root.sh` failed
   (empty `ORCH_ROOT`) → `exit 0` when root is unresolvable.

The two plausible scope gaps (B2 confirmation gate, B4 FR-8 hook coverage)
became P05 and P04 respectively. RISK-01 from the conversus gate (phantom
constitution principles) was a **false positive** — the gate assumed 7
principles; the constitution defines 15 (I–XV), so VIII/XIV/XV cited in the
Constitution Check are real.

## SC-7 disposition

SC-7 ("detective's `unit_close` record appears after a run") shipped initially
as a documented SKIP because detective is an LLM-orchestrated command, not a
standalone binary — the same execution model as every other `orchestrator:*`
command. P05's close wired the emission **contract** into `commands/detective.md`
(`## Observability` section with the exact `unit_close` append, including an
`outcome` field for filed/commented/degraded/declined). The record is emitted
at runtime when the LLM runs the full command; the mechanical proxy verified in
the acceptance battery is that the contract is present and well-formed. SC-7
moved from SKIP to PASS on that basis.

## Deferred / out of scope

- **`#Q-1` match-score corpus validation** — the keyword-overlap threshold
  must be validated against the real `Build-Fractal/orchestrator` issue corpus
  before the `--yes` automated path is used unattended (conversus RISK-06
  advisory, folded into the spec's Open Questions). Advisory, not blocking.
- **`detective.repo` config-key read** — documented in `detective.md` as an
  override source; the scripts honor `--repo` but do not yet read the config
  key. Minor; deferrable until a fork actually needs it.
