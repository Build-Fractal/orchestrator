---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M024"
goal: "Empty input + bounded Q&A — `evaluate` with no argument runs at most 5 Q&A turns, captures the transcript, and emits a proposal with `input_shape: empty_qa` plus a `## Q&A` body section; `enough` short-circuit flips `qa_short_circuited: true` and `low_confidence: true` so the P04 fast-path cannot auto-bypass."
demo_sentence: "An operator running `orchestrator:evaluate` with no `--input` and no `--spec-path` is asked up to 5 load-bearing questions, can short-circuit at any point with `enough`, and ends the invocation with a proposal at `.orchestrator/intake/<NNN>-empty-qa/proposal.md` whose frontmatter records `input_shape: empty_qa` and whose body contains the question/answer transcript under `## Q&A` — and where short-circuit additionally records `qa_short_circuited: true` + `low_confidence: true`."
risk: "medium"
depends_on: ["P01", "P04"]
---

## Resolution Of #Q-3 (qa-question-source)

Per the planning-payload tasking and the D019 reuse-over-rebuild posture, P05 ships a **static template** (`templates/intake-qa-questions.md`) as the question source. Conversus-loop and knowledge-driven sources are explicitly deferred unless dogfood signals demand otherwise — recorded as a Decision in the milestone's DECISIONS section if/when that flips. The static template is the simplest shape that earns SC-3 and FR-5; promoting to a dynamic source is a future M024.x extension.

The five questions cover the load-bearing axes the proposal needs to populate:

1. **Goal** — What outcome does the operator want? (drives input-shape rationale + scope_tier evidence)
2. **Scope** — Single fix, single feature, or multi-phase milestone? (drives decomposition axis)
3. **Visible surface** — Code, docs, config, or workflow? (drives design_gate signal — UI work hints at design walkthrough)
4. **Adversarial review** — Does the change touch security, correctness, or contested design? (drives conversus_gate signal)
5. **Time boxing** — Quick fix (≤30m), Standard (≤2h), or Full (multi-session)? (drives intensity axis)

Operators can answer any subset and short-circuit at any point with the literal token `enough`. The transcript is preserved verbatim in the proposal body so the operator (or a downstream agent) can re-read the inputs that produced the routing decision.

## Boundary

- **Produces**: `templates/intake-qa-questions.md` (the static 5-question template per #Q-3), `scripts/intake/qa-loop.sh` (≤5-turn loop; `enough` short-circuit; transcript capture; line-mode `--answers-from <file>` testability path); empty-input wiring in `scripts/intake/proposal-emit.sh` that flips `input_shape: empty_qa`, embeds the `## Q&A` body section, and sets `qa_short_circuited` / `low_confidence` on short-circuit; two phase-level tests (`tests/test-empty-qa-loop.sh`, `tests/test-qa-short-circuit.sh`); seven `scripts/verify/m024-p05-*` per-claim gates plus the suite runner; a one-line note in `commands/evaluate.md`'s Input Shapes table promoting the empty row from "P05+ wires" to "wired in P05".
- **Consumes**: P01 proposal schema (`input_shape: "empty_qa"` value + `qa_short_circuited` + `low_confidence` frontmatter keys + `## Q&A` body section); P01 `proposal-emit.sh` empty-input branch (currently emits a stub paragraph-style proposal with `input_shape=empty`); P01 `shape-detect.sh` (returns `input_shape=empty` for the no-input case — P05 wraps it); P04 `approval-gate.sh --mode check-fast-path` (relies on `low_confidence: true` as a fifth disqualifying condition — P04 already enforces this; P05 must therefore set `low_confidence: true` on short-circuit for the P04 guard to fire); spec FR-5, SC-3, edge case "Q&A short-circuit on question 1"; #Q-3 (resolved in this plan: static template first cut).

## M024/P05 → P06/P07 Forward Wiring (informational)

- **P06 (revision flow)**: revisions on a Q&A-derived proposal MUST preserve the `## Q&A` transcript section verbatim across `proposal-v<N>.md` snapshots so the operator can see the originating answers even after axis overrides. P06 needs no further changes — the transcript lives in body markdown that P06's existing in-place rewrite leaves untouched.
- **P07 (design-gate)**: when P07 wires the design-gate axis classifier against Q&A-derived proposals, the answers to question 3 ("Visible surface") become the load-bearing evidence. P07 will read `## Q&A` answers as one of its evidence sources.

## Must-Haves

### Truths

- `templates/intake-qa-questions.md` exists with YAML frontmatter (`schema_version: "1.0"`, `type: intake-qa-questions`) and a body containing exactly five questions numbered `### Q1` through `### Q5`, each with a one-line prompt and a one-line guidance hint. The five question topics (goal / scope / surface / adversarial / time-boxing) are present and grep-stable.
  - Check: `bash scripts/verify/m024-p05-qa-questions-template.sh`
- `scripts/intake/qa-loop.sh` is executable, accepts `--answers-from <file>` (line-mode: one answer per line, blank line or `enough` short-circuits), and emits a transcript to a caller-supplied path via `--transcript-out <path>`. The transcript file format is one `### Q<N>` heading + one prose answer block per turn, plus a final `qa_short_circuited=true|false` stdout key=value line.
  - Check: `bash scripts/verify/m024-p05-qa-loop-script.sh`
- `scripts/intake/qa-loop.sh` enforces the FR-5 cap: a `--answers-from` file with more than 5 lines is truncated to the first 5; the resulting transcript contains exactly 5 `### Q` headings; `qa_short_circuited=false` is emitted.
  - Check: `bash scripts/verify/m024-p05-qa-loop-cap.sh`
- `scripts/intake/qa-loop.sh` honors the `enough` short-circuit: when an answer line is the literal lowercase string `enough` (whitespace-trimmed, case-insensitive) the loop terminates after the prior turn; the resulting transcript contains exactly the answers gathered before the `enough` token; `qa_short_circuited=true` is emitted.
  - Check: `bash scripts/verify/m024-p05-qa-loop-shortcircuit.sh`
- `scripts/intake/proposal-emit.sh`, when invoked with neither `--input` nor `--spec-path`, accepts a new `--qa-answers-from <file>` flag that triggers the qa-loop, embeds the resulting transcript under a `## Q&A` heading in the proposal body, sets `input_shape: empty_qa` (instead of the P01 `empty` stub), and propagates `qa_short_circuited=true|false` to the proposal frontmatter. When `qa_short_circuited=true`, `low_confidence: true` is also set so the P04 fast-path guard fires.
  - Check: `bash scripts/verify/m024-p05-proposal-emit-empty-qa.sh`
- A full-5-answers Q&A flow produces a proposal with `input_shape: empty_qa`, `qa_short_circuited: false`, `low_confidence: false` (unless overridden by the shape-detect classifier — N/A for empty-qa), and a `## Q&A` section containing exactly 5 `### Q<N>` headings.
  - Check: `bash scripts/verify/m024-p05-empty-qa-full.sh`
- A short-circuited Q&A flow (operator types `enough` after turn 2) produces a proposal with `input_shape: empty_qa`, `qa_short_circuited: true`, `low_confidence: true`, and a `## Q&A` section containing exactly 2 `### Q<N>` headings; the proposal cannot auto-proceed via the P04 fast-path because `low_confidence: true` is one of the five disqualifying conditions.
  - Check: `bash scripts/verify/m024-p05-empty-qa-shortcircuit.sh`
- All P05-introduced shell scripts respect SB-3 write-confinement: writes target only `.orchestrator/intake/<id>/` (proposal frontmatter + body mutations) and `/tmp` (test scratch + transcript scratch). The qa-loop itself writes only to its `--transcript-out` argument.
  - Check: `bash scripts/verify/m024-p05-write-confinement.sh`
- `commands/evaluate.md`'s Input Shapes table row for the `empty` shape no longer contains the literal string "P05+ wires" — the row is updated to name the wired qa-loop and the `empty_qa` shape value. (FR-6 byte-compatibility on the legacy spec path is preserved; only the empty row is touched.)
  - Check: `bash scripts/verify/m024-p05-evaluate-md.sh`
- The P05 phase suite (the two phase-level tests + every per-task verify) exits 0 on a clean checkout.
  - Check: `bash scripts/verify/m024-p05-suite.sh`

### Artifacts

- templates/intake-qa-questions.md (min 30 lines, contains "schema_version")
- scripts/intake/qa-loop.sh (min 90 lines, contains "qa_short_circuited")
- scripts/intake/proposal-emit.sh (min 320 lines, contains "empty_qa")
- commands/evaluate.md (min 200 lines, contains "empty_qa")
- tests/test-empty-qa-loop.sh (min 60 lines, contains "empty_qa")
- tests/test-qa-short-circuit.sh (min 60 lines, contains "qa_short_circuited")
- scripts/verify/m024-p05-qa-questions-template.sh (min 25 lines, contains "Q1")
- scripts/verify/m024-p05-qa-loop-script.sh (min 25 lines, contains "qa_short_circuited")
- scripts/verify/m024-p05-qa-loop-cap.sh (min 25 lines, contains "qa_short_circuited=false")
- scripts/verify/m024-p05-qa-loop-shortcircuit.sh (min 25 lines, contains "qa_short_circuited=true")
- scripts/verify/m024-p05-proposal-emit-empty-qa.sh (min 30 lines, contains "empty_qa")
- scripts/verify/m024-p05-empty-qa-full.sh (min 30 lines, contains "empty_qa")
- scripts/verify/m024-p05-empty-qa-shortcircuit.sh (min 30 lines, contains "low_confidence")
- scripts/verify/m024-p05-write-confinement.sh (min 20 lines, contains "intake")
- scripts/verify/m024-p05-evaluate-md.sh (min 20 lines, contains "empty_qa")
- scripts/verify/m024-p05-suite.sh (min 15 lines, contains "test-empty-qa-loop")

### Key Links

- scripts/intake/qa-loop.sh → templates/intake-qa-questions.md (loop reads question prompts from the static template)
- scripts/intake/proposal-emit.sh → scripts/intake/qa-loop.sh (emitter invokes the qa-loop on the empty-input branch when `--qa-answers-from` is supplied)
- scripts/intake/proposal-emit.sh → templates/intake-proposal.md (emitter renders `## Q&A` section into the proposal body)
- scripts/intake/proposal-emit.sh → scripts/intake/approval-gate.sh (emitter's existing P04 fast-path check now sees `low_confidence: true` on short-circuit and refuses to auto-proceed — no new wiring, just a behavioral consequence the test asserts)
- tests/test-empty-qa-loop.sh → scripts/intake/proposal-emit.sh (test invokes the emitter with a 5-line answers file)
- tests/test-qa-short-circuit.sh → scripts/intake/qa-loop.sh (test exercises the loop directly with an `enough`-bearing answers file)
- commands/evaluate.md → scripts/intake/qa-loop.sh (Input Shapes table row for `empty` references the wired loop)

## Tasks

### T01: Static qa-questions template — `templates/intake-qa-questions.md`

See `tasks/T01-PLAN.md`. Authors `templates/intake-qa-questions.md` — the static 5-question template that resolves #Q-3 first cut. YAML frontmatter (`schema_version: "1.0"`, `type: intake-qa-questions`); body contains exactly five `### Q1`–`### Q5` blocks each with a one-line prompt and one-line guidance hint covering the five load-bearing axes (goal / scope / surface / adversarial / time-boxing). Pure markdown; no logic. Authors `scripts/verify/m024-p05-qa-questions-template.sh` to assert the schema fields and the five `### Q<N>` headings exist.

### T02: `scripts/intake/qa-loop.sh` — bounded loop with `enough` short-circuit + line-mode answers

See `tasks/T02-PLAN.md`. Authors `scripts/intake/qa-loop.sh` — a pure-shell qa-loop that reads questions from the T01 template and answers from a `--answers-from <file>` argument (line-mode: one answer per line; blank line or `enough` short-circuits). Writes a transcript to `--transcript-out <path>` in the format the P01 template's `## Q&A` body section will embed verbatim (`### Q<N>` heading + answer block per turn). Emits two stdout key=value lines: `qa_short_circuited=<true|false>` and `qa_turns=<count>`. Enforces the FR-5 cap (truncate to 5 turns). Authors `scripts/verify/m024-p05-qa-loop-script.sh`, `scripts/verify/m024-p05-qa-loop-cap.sh`, and `scripts/verify/m024-p05-qa-loop-shortcircuit.sh` exercising the script across the three behavioral modes (line-mode happy path, cap enforcement, short-circuit). AD-19 single-script-file shape; bash 3.2 portable; no `declare -A`; no `$(... | ...)` containing pipes.

The interactive (TTY-prompt) mode is **deferred** — P05 ships line-mode only. The interactive surface is an ergonomic add-on, not a load-bearing acceptance criterion (SC-3 verifies on a `--answers-from` invocation). A future task can add a TTY mode without breaking the line-mode contract.

### T03: Wire qa-loop into `scripts/intake/proposal-emit.sh` (empty-input branch)

See `tasks/T03-PLAN.md`. Extends `scripts/intake/proposal-emit.sh` with a new `--qa-answers-from <file>` flag that triggers the empty-input branch. After axis resolution but before the final render, the emitter:

1. Detects empty-input (no `--input`, no `--spec-path`) AND `--qa-answers-from` supplied.
2. Allocates a transcript scratch path under `/tmp`.
3. Invokes `bash scripts/intake/qa-loop.sh --answers-from <file> --transcript-out <tmp>` and parses the two stdout lines.
4. Reads the transcript file and folds it under a `## Q&A` heading appended to the proposal body (or wired via a new `{{qa_section}}` placeholder — to be decided by T03 author per actual template flexibility; see Task plan for the recommended idiom).
5. Sets `input_shape="empty_qa"` (overriding the shape-detect's `empty` value), `qa_short_circuited=<bool>` from the loop's stdout, and — when short-circuited — `low_confidence="true"` so the P04 fast-path guard fires.

The wiring sits in the `proposal-emit.sh` invocation flow ahead of the existing P04 fast-path check block (lines 220–246 today) so the gate sees the up-to-date `low_confidence` value. A `QA_AXES_DONE` flag (mirroring P04's `FAST_PATH_AXES_DONE`, P03's `PARA_AXES_DONE`, and P02's `SPEC_AXES_DONE`) prevents later axis-rationale loops from clobbering the empty-qa rationale slots. Authors `scripts/verify/m024-p05-proposal-emit-empty-qa.sh`. SB-3 preserved — writes target only `.orchestrator/intake/<id>/` and `/tmp`.

### T04: Phase tests + suite + evaluate.md row update

See `tasks/T04-PLAN.md`. Authors two phase-level tests (`tests/test-empty-qa-loop.sh` covering the 5-answers happy path; `tests/test-qa-short-circuit.sh` covering the `enough` after turn 2 path including the `low_confidence: true` propagation that blocks the P04 fast-path), three additional verify scripts (`m024-p05-empty-qa-full.sh`, `m024-p05-empty-qa-shortcircuit.sh`, `m024-p05-write-confinement.sh`), the `m024-p05-evaluate-md.sh` verify, and the suite runner `m024-p05-suite.sh` (MEM002 parallel-array tracking, structured `PASS:`/`FAIL:` summary). Updates the empty-shape row in `commands/evaluate.md`'s Input Shapes table to name the wired qa-loop and the `empty_qa` shape value (one-line edit; FR-6 unchanged on the legacy spec path).

## Task Dependencies

```
T01 → T02         (T02's loop reads questions from T01's template)
T02 → T03         (T03's emitter wiring invokes T02's loop)
T01 + T02 + T03 → T04
```

T01 (template) is pure data — no behavior change. T02 (loop) is purely additive — exercises the line-mode contract on a stub answers file before any emitter wiring exists. T03 (emit wiring) is the load-bearing change that flips `input_shape: empty_qa` and embeds the transcript. T04 (tests + suite) exercises the full path end-to-end, asserts the short-circuit→fast-path-blocked invariant, and updates the operator-facing doc.

## Files Likely Touched

- templates/intake-qa-questions.md (create)
- scripts/intake/qa-loop.sh (create)
- scripts/intake/proposal-emit.sh (modify — add --qa-answers-from flag + empty-qa branch + Q&A section embedding)
- commands/evaluate.md (modify — update empty-shape row in Input Shapes table)
- tests/test-empty-qa-loop.sh (create)
- tests/test-qa-short-circuit.sh (create)
- scripts/verify/m024-p05-qa-questions-template.sh (create)
- scripts/verify/m024-p05-qa-loop-script.sh (create)
- scripts/verify/m024-p05-qa-loop-cap.sh (create)
- scripts/verify/m024-p05-qa-loop-shortcircuit.sh (create)
- scripts/verify/m024-p05-proposal-emit-empty-qa.sh (create)
- scripts/verify/m024-p05-empty-qa-full.sh (create)
- scripts/verify/m024-p05-empty-qa-shortcircuit.sh (create)
- scripts/verify/m024-p05-write-confinement.sh (create)
- scripts/verify/m024-p05-evaluate-md.sh (create)
- scripts/verify/m024-p05-suite.sh (create)
