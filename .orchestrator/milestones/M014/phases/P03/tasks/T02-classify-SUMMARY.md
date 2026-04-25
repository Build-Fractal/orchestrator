---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M014"
provides:
  - "scripts/comments/classify.sh (FR-9 v1 regex/heuristic classifier per D023); templates/conversus-presets/classify-comment.yml (CON-4 ambiguous-routing preset, single-agent cooperative); specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md (SC-16 dogfood-data capture + D023 retune triggers); scripts/verify/m014-p03-classify.sh (8-case verifier covering four FR-9 classes + verdict shape + pin docstring + preset existence + dogfood D023 citation)"
requires:
  - "from:M014/P03/T01 what:scripts/comments/fetch.sh inbox JSON record shape (url, body, source_surface, fetched_at, body_shasum); from:disk what:.orchestrator/DECISIONS.md D023 pin rationale; from:disk what:scripts/dispatch/adapters/tool/conversus.sh gate interface (D007 reuse — not modified); from:disk what:tests/fixtures/m014-p03/sample-inbox.jsonl four-class fixture corpus"
affects:
  - "T03 (commands/comments.md cites dogfood-data file for D023 retune-trigger language); T04 (master pipeline invokes classify.sh and dispatches conversus adapter on class=ambiguous with --strict); T05 (references/spec-management.md Comment Classification section + phase-suite asserts RUNTIME-ASSUMPTIONS.md byte-identical)"
key_files:
  - "scripts/comments/classify.sh, templates/conversus-presets/classify-comment.yml, specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md, scripts/verify/m014-p03-classify.sh"
key_decisions:
  - "D023 (regex/heuristic v1 pin + retune triggers); D007 reuse (NEW preset, no adapter modification); CON-5/SC-5 (classify.sh pure verdict producer — spec-amendment always queues regardless of confidence); single-source-of-truth for retune triggers = dogfood-data file"
patterns_established:
  - "stdout-verdict + stderr-INFO split (machine-parseable verdict + human-readable rule trace); single-agent cooperative preset for refinement-only LLM calls (no red-blue deliberation when prior is already encoded); pre-existing fixture corpus reused as canonical four-class corpus with per-class mktemp split in verifier"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P03/tasks/T02-classify-PLAN.md, .orchestrator/milestones/M014/phases/P03/tasks/T02-classify-PAYLOAD.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-04-25T01:08:13Z"
---

## What Was Built

T02 ships the FR-9 v1 classifier per D023 (regex/heuristic, no LLM round-trip on the primary path) plus the ambiguous-routing preset for the conversus adapter and the SC-16 dogfood-data capture file.

**Core surface**:
- `scripts/comments/classify.sh` — pure per-comment classifier. Reads one cached inbox JSON, applies a 10-rule regex/heuristic ladder (R1-R10), emits a single-line stdout verdict in the shape `class=<class> confidence=<score> reason=<short-id>` plus an INFO stderr diagnostic. Bash 3.2 compatible (uses `tr` for case folding, no `${var,,}`).
- `templates/conversus-presets/classify-comment.yml` — minimal cooperative-mode preset for the ambiguous-routing path (CON-4). Single agent, verdict contract `class:uat-bug|decision-append|spec-amendment|ambiguous`. T02 ships only the preset; the orchestration code that calls the adapter lives in T04's master pipeline.
- `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` — SC-16 dogfood-data capture file (best-available signal at 2026-04-24 per D023). Documents snapshot state (0 organic stakeholder comments — wiki deployed one day before plan-phase), per-class counts (4 seeded fixture comments + 0 real-inbox), the 10-rule summary table, and the explicit retune trigger conditions (>=30 actioned comments OR >=20% calibration divergence).
- `scripts/verify/m014-p03-classify.sh` — 8-case verifier. Cases A-D exercise the four FR-9 classes against per-class scratch fixtures. Cases E-H assert the verdict shape, the D023 pin docstring, the preset existence, and the dogfood-file D023 citation.

**Rule ladder (R1-R10)** captured in classify.sh:

| Rule | Class | Confidence | Match shape |
|------|-------|-----------|-------------|
| R1 | uat-bug | 0.9 | YAML frontmatter `kind: uat-bug` |
| R2 | uat-bug | 0.7 | "acceptance ... fails" |
| R3 | uat-bug | 0.7 | "(bug|broken|...) ... on" |
| R4 | decision-append | 0.95 | `^/append-decision` explicit |
| R5 | decision-append | 0.85 | `^decision: ` prefix |
| R6 | decision-append | 0.75 | "we (decided|agreed|chose)" |
| R7 | spec-amendment | 0.85 | "FR-N (should|needs to|must|also cover)" |
| R8 | spec-amendment | 0.85 | "(AS|US|SC|CON)-N (is wrong|contradicts|missing)" |
| R9 | spec-amendment | 0.95 | `^(amend|propose amendment)` |
| R10 | ambiguous | 0.0 | fallthrough -> conversus (CON-4) |

## Key Decisions

- **Followed verbatim plan body** for the rule ladder, confidence assignments, output shape, and verifier case-list.
- **Confidence values pinned on intuition**, not measured precision/recall (documented in dogfood-data file). Coarse-grained 0.7-0.95 increments capture relative signal strength without overfitting on a 4-comment fixture.
- **D007 reuse preserved**: T02 ships a NEW preset under `templates/conversus-presets/`; does NOT modify `scripts/dispatch/adapters/tool/conversus.sh`.
- **D023 retune-trigger language standardized**: dogfood-data file is the single source of truth; T03 (commands/comments.md) and T05 (references/spec-management.md) cite this file rather than re-stating the conditions inline.
- **CON-5 / SC-5 boundary respected**: classify.sh is a pure verdict producer. spec-amendment ALWAYS queues regardless of confidence; auto-apply gating is T04's responsibility.

## Cross-Cutting Patterns Established

- **Stdout-verdict + stderr-INFO split**: classify.sh emits the machine-parseable verdict on stdout and a human-readable rule trace on stderr. T04's pipeline can capture stdout cleanly while operators tail stderr for debugging.
- **Single-agent cooperative preset for refinement-only LLM calls**: classify-comment.yml is single-agent because the regex layer already encoded the project's prior on the four classes. Red-blue deliberation is reserved for contested decisions, not edge-case refinement.
- **Pre-existing fixture corpus reused as canonical four-class corpus**: `tests/fixtures/m014-p03/sample-inbox.jsonl` (shipped with T01's plan-phase scaffolding) doubles as the calibration corpus. Verifier rebuilds per-class scratch files in mktemp rather than mutating the shared corpus.

## Verification Results

- `bash scripts/verify/m014-p03-classify.sh` -> exit 0, `SUMMARY: m014-p03-classify.sh pass=8 fail=0`, all 8 cases PASS.
- End-to-end against the canonical fixture corpus (split per-line into 4 comment files): c1 -> uat-bug/0.7/acceptance-fails; c2 -> decision-append/0.85/decision-prefix; c3 -> spec-amendment/0.85/fr-amend; c4 -> ambiguous/0.0/no-rule-fired.

## Deviations Worth Surfacing

None. Plan body executed verbatim. The verifier-self-exemption note for Case F (which scans for the literal "regex/heuristic" in classify.sh) is documented inline; the verifier scopes the grep to the classify script path so its own diagnostic strings are not in scope.

## Contract Handoff to T03/T04/T05

- **T03 (`commands/comments.md`)**: Document the regex/heuristic v1 baseline per D023 with explicit retune-trigger language. Cite `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` as the single source of truth for retune conditions rather than re-stating them inline.
- **T04 (master pipeline)**: Invoke `scripts/comments/classify.sh <inbox-file>` per cached inbox record. On `class=ambiguous`, dispatch `scripts/dispatch/adapters/tool/conversus.sh gate classify-comment <inbox-file> <verdict-output>` with `--strict`. On adapter unavailability under `--strict`, route to human triage. spec-amendment ALWAYS queues regardless of confidence (CON-5).
- **T05 (`references/spec-management.md` + phase-close)**: Add a "Comment Classification & Workflow Routing" section that documents the regex/heuristic v1 baseline, the four FR-9 classes, the D023 retune trigger (citing the dogfood-data file), and the CON-4 ambiguous-routing fallback. Phase-suite verifier asserts `RUNTIME-ASSUMPTIONS.md` is byte-identical (no new entry — D023 pinned non-LLM).
