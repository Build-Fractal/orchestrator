---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M030"
goal: "Hook the P01 classifier into `scripts/dispatch/dispatch-interface.sh` behind `M030_SHADOW_MODE=1`, emit additive `dispatch_usage` JSONL fields (`model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`) without disturbing pre-M030 record byte-equality (CON-2/FR-19/SC-11), and ship `scripts/diagnostics/shadow-compare.sh` as a 4-verdict (`ready|partially_ready|block|evidence_insufficient`) flip-readiness aggregator that reads the pinned classifier-confidence stability metric (variance ≤ 0.10, rolling N=20, per-class coverage ≥ 50) from `references/model-routing.md` and verifies SC-3a (every shadow record's `model_routed` matches an independent re-classification of the referenced plan). All routing decisions resolve through `templates/model-routing.yml` `routing:` + `resolution:` (CON-3 — no hardcoded model IDs in dispatch-interface diff). Shadow JSONL writes are append-only (CON-6). Codex CLI / Cursor short-circuit to the existing emitter (CC-only launch posture) — only `CLAUDECODE=1` engages the shadow path."
demo_sentence: "An operator sets `M030_SHADOW_MODE=1` and runs 50 dispatches across two phases of any milestone; each `dispatch_usage` record in `.orchestrator/milestones/<M>/execution-log.jsonl` now carries `model_routed=<symbolic>` (the classifier's routing-table choice) plus `model_used=<runtime-default-id>`; runs `bash scripts/diagnostics/shadow-compare.sh` and observes a single line `flip_recommendation=ready|partially_ready|block|evidence_insufficient` plus per-class evidence count + per-class confidence-variance lines; in the `partially_ready` case observes the under-threshold class enumerated in a `withheld_classes=<list>` line; runs `bash tools/verify/p02-additive-schema.sh` and observes byte-identical pass against pre-M030 fixture JSONL; runs `bash tools/verify/p02-sc3a-roundtrip.sh` and observes every shadow record's `model_routed` matches `bash scripts/dispatch/classify-task.sh <plan>` re-run independently; runs `bash tools/verify/p02-phase-suite.sh` and observes `SUMMARY: p02-phase-suite.sh pass=N fail=0` exit 0."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned per-phase verifiers live under tools/verify/ with
     slug-bearing filenames (p02-*) so install-clobber risk is contained.
     Verifier authorship is co-scheduled with the artifact it gates, in
     the SAME task, per Plan-Time Discipline rule 2 (verifier-availability
     cross-check). No cross-task verifier dependencies. T01 deliberately
     ships the SC-11 byte-equality verifier + golden fixture BEFORE T02
     touches dispatch-interface.sh — this is the same discipline P01 used
     for the D-A4 timeline graduation: the additive-schema gate exists
     and gates the diff at the moment dispatch-interface.sh is amended. -->

### Truths

- A pre-M030 `dispatch_usage` JSONL fixture (`tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl`) exists at version-control with at minimum 5 records spanning happy-path, pricing-warning, and cost-null degradation shapes. The fixture's first-commit timestamp predates `dispatch-interface.sh`'s P02 amendment commit (mechanical proxy for additive-only-schema enforcement). (CON-2/FR-19/SC-11 foundation.)
  - Check: `bash tools/verify/p02-fixture-shape.sh`

- SC-11 byte-equality holds: when `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` is round-tripped through `scripts/dispatch/dispatch-interface.sh`'s emit path under `M030_SHADOW_MODE=0` (or unset), the emitter output for an equivalent fixture invocation is byte-identical to the recorded fixture line for the same `(unitId, backend, payload_bytes, model)` tuple. The verifier stages a fixture invocation, captures the emitter's stdout/log line, and `diff`s against the corresponding fixture record byte-for-byte — empty diff is the pass condition. New fields (`model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`) MUST NOT appear in the output when shadow mode is off; when shadow mode is on, they appear ONLY as appended fields after the existing field set. (CON-2/FR-19/SC-11.)
  - Check: `bash tools/verify/p02-additive-schema.sh`

- `scripts/dispatch/dispatch-interface.sh` invokes the P01 classifier on every dispatch when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`, resolves the routing-table choice symbolically through `templates/model-routing.yml` `routing:` + `resolution:` blocks, and records both `model_routed=<symbolic>` (the classifier's routing-table choice) and `model_used=<runtime-default-id>` (the actually-dispatched model — runtime default in shadow mode) in the `dispatch_usage` JSONL record. When `M030_SHADOW_MODE` is unset/0, the new fields MUST NOT appear (additive). When `CLAUDECODE` is unset (Codex CLI / Cursor), the shadow path short-circuits — `model_routed` and `model_used` are not emitted; the record is byte-equivalent to the pre-M030 shape. (FR-5/FR-7/CON-2/CON-3.)
  - Check: `bash tools/verify/p02-shadow-emit.sh`

- The shadow-mode amendment to `dispatch-interface.sh` contains zero hardcoded model IDs. Every concrete model identifier reachable from the new code path resolves through `templates/model-routing.yml`'s `resolution:` block at runtime — never via a literal embedded in `dispatch-interface.sh`. The verifier greps the post-amendment `dispatch-interface.sh` for the closed set of provider model-ID patterns (`claude-haiku-`, `claude-sonnet-`, `claude-opus-`, `gpt-`, `o1-`, `o3-`, `gemini-`) and asserts zero hits in lines added by P02 (lines NOT present in the pre-amendment `git show HEAD:scripts/dispatch/dispatch-interface.sh`). (CON-3.)
  - Check: `bash tools/verify/p02-con3-closure.sh`

- The shadow JSONL write path is append-only. The verifier stages a fixture milestone log file with N pre-existing records, runs an `M030_SHADOW_MODE=1` dispatch invocation against a fixture plan, and asserts: (a) the log file's first N lines are byte-identical before and after; (b) exactly one new line was appended; (c) no temporary file rewrite/swap occurred (the inode of the log file is identical pre- and post-invocation per `stat -f '%i'` macOS / `stat -c '%i'` GNU). (CON-6 — locks in the discipline P04 escalation will inherit.)
  - Check: `bash tools/verify/p02-append-only.sh`

- `scripts/diagnostics/shadow-compare.sh` exists and emits exactly one `flip_recommendation=` line whose value is drawn from the closed enum {`ready`, `partially_ready`, `block`, `evidence_insufficient`}. The verifier exercises four fixture corpora (one per verdict) and asserts on each: (a) exactly one line matching `^flip_recommendation=(ready|partially_ready|block|evidence_insufficient)$` appears on stdout; (b) no other `flip_recommendation=*` value appears anywhere in stdout. (FR-8/D-A1.)
  - Check: `bash tools/verify/p02-shadow-compare-verdicts.sh`

- `shadow-compare.sh`'s `partially_ready` verdict enumerates the withheld classes. The verifier stages a fixture corpus where exactly two classes (mechanical, standard) meet the 50-count + variance ≤ 0.10 thresholds and the third (novel) does not, runs `shadow-compare.sh`, and asserts: (a) `flip_recommendation=partially_ready` appears; (b) a single line matches `^withheld_classes=novel$` (or equivalent enumeration containing `novel` and not `mechanical` or `standard`); (c) the under-threshold class's routing-table default is `smart` per `templates/model-routing.yml` (D-A3 partial-flip safety constraint — verified by the verifier checking `templates/model-routing.yml routing.novel.claude-code` is the literal `smart`). (D-A3/FR-8.)
  - Check: `bash tools/verify/p02-partial-flip-enum.sh`

- `shadow-compare.sh` consumes the pinned classifier-confidence stability metric values from `references/model-routing.md` (variance threshold 0.10, rolling window N=20, per-class coverage 50). The values are not hardcoded inside `shadow-compare.sh`'s decision logic as plain literals untraceable to the SSOT — the script either (a) reads the values from `references/model-routing.md` at runtime via grep extraction, or (b) hardcodes them with an inline reference comment naming the source section (`## Classifier-Confidence Stability Metric` in `references/model-routing.md`) on the same line as the literal. The verifier greps `shadow-compare.sh` for the three numeric values and asserts each occurrence appears on a line that ALSO references either `references/model-routing.md` OR `model-routing` OR `Classifier-Confidence Stability Metric`. (Consumes P01 contract; pinned-numerics drift gate.)
  - Check: `bash tools/verify/p02-stability-metric-traceability.sh`

- SC-3a holds: for each record in a shadow-mode JSONL fixture corpus where `model_routed` is set, `bash scripts/dispatch/classify-task.sh <plan-path>` run independently on the plan referenced by the record's `unitId` (resolved via the standard `M###/P##/T##` → `.orchestrator/milestones/M###/phases/P##/tasks/T##-*-PLAN.md` glob — first match wins) emits `character=<c>` such that `routing[<c>][claude-code]` in `templates/model-routing.yml` equals the record's `model_routed` value. (D-A7/SC-3a — initial-write correctness gate that CON-6 alone does not provide.)
  - Check: `bash tools/verify/p02-sc3a-roundtrip.sh`

- `bash tools/verify/p02-phase-suite.sh` invokes all nine P02 sub-gates (fixture-shape, additive-schema, shadow-emit, con3-closure, append-only, shadow-compare-verdicts, partial-flip-enum, stability-metric-traceability, sc3a-roundtrip) in literal sequence (no loops, no eval), exits 0 iff every sub-gate passes, and emits `SUMMARY: p02-phase-suite.sh pass=N fail=M` on a single line before exit. Same straight-line shape as `p01-phase-suite.sh`. (Phase-close aggregator.)
  - Check: `bash tools/verify/p02-phase-suite.sh`

### Artifacts

- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (min 5 lines, contains "record_type", contains "dispatch_usage", contains "input_tokens_estimate") — create
- `tests/fixtures/m030-p02/shadow-corpus-ready.jsonl` (min 150 lines, contains "model_routed", contains "model_used", contains "fast") — create
- `tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl` (min 100 lines, contains "model_routed", contains "model_used", contains "balanced") — create
- `tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl` (min 0 lines — may be empty file) — create
- `tests/fixtures/m030-p02/shadow-corpus-block.jsonl` (min 30 lines, contains "model_routed") — create
- `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl` (min 6 lines, contains "model_routed", contains "unitId", contains "M0") — create
- `tools/verify/p02-fixture-shape.sh` (min 30 lines, contains "pre-m030-dispatch-usage.jsonl", contains "record_type", contains "SUMMARY:") — create
- `tools/verify/p02-additive-schema.sh` (min 50 lines, contains "pre-m030-dispatch-usage.jsonl", contains "diff", contains "SUMMARY:") — create
- `tools/verify/p02-shadow-emit.sh` (min 60 lines, contains "M030_SHADOW_MODE", contains "model_routed", contains "model_used", contains "CLAUDECODE", contains "SUMMARY:") — create
- `tools/verify/p02-con3-closure.sh` (min 40 lines, contains "claude-haiku", contains "claude-sonnet", contains "claude-opus", contains "dispatch-interface.sh", contains "SUMMARY:") — create
- `tools/verify/p02-append-only.sh` (min 50 lines, contains "M030_SHADOW_MODE", contains "stat", contains "SUMMARY:") — create
- `tools/verify/p02-shadow-compare-verdicts.sh` (min 60 lines, contains "shadow-compare.sh", contains "ready", contains "partially_ready", contains "block", contains "evidence_insufficient", contains "SUMMARY:") — create
- `tools/verify/p02-partial-flip-enum.sh` (min 50 lines, contains "shadow-compare.sh", contains "partially_ready", contains "withheld_classes", contains "novel", contains "SUMMARY:") — create
- `tools/verify/p02-stability-metric-traceability.sh` (min 30 lines, contains "shadow-compare.sh", contains "0.10", contains "20", contains "50", contains "model-routing", contains "SUMMARY:") — create
- `tools/verify/p02-sc3a-roundtrip.sh` (min 70 lines, contains "classify-task.sh", contains "model_routed", contains "templates/model-routing.yml", contains "SUMMARY:") — create
- `tools/verify/p02-phase-suite.sh` (min 50 lines, contains "p02-fixture-shape", contains "p02-additive-schema", contains "p02-shadow-emit", contains "p02-con3-closure", contains "p02-append-only", contains "p02-shadow-compare-verdicts", contains "p02-partial-flip-enum", contains "p02-stability-metric-traceability", contains "p02-sc3a-roundtrip", contains "SUMMARY:") — create
- `scripts/dispatch/dispatch-interface.sh` (modify — add classifier hook + shadow-mode emission of `model_routed`/`model_used`/`partial_flip_active`/`withheld_classes` fields gated by `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`; resolve symbolic tier through `templates/model-routing.yml`; preserve all existing emit-path semantics under shadow off) — modify
- `scripts/diagnostics/shadow-compare.sh` (min 200 lines, contains "flip_recommendation", contains "ready", contains "partially_ready", contains "block", contains "evidence_insufficient", contains "withheld_classes", contains "0.10", contains "20", contains "50", contains "model-routing") — create

### Key Links

- `specs/032-adaptive-model-selection/spec.md` → `scripts/dispatch/dispatch-interface.sh` (FR-5 names the classifier-invocation hook; FR-7 names the shadow-mode JSONL emission; FR-19 names the additive-schema discipline)
- `specs/032-adaptive-model-selection/spec.md` → `scripts/diagnostics/shadow-compare.sh` (FR-8 names the 4-verdict output; SC-2 + SC-3a name the acceptance criteria)
- `.orchestrator/milestones/M030/M030-CONTEXT.md` → `scripts/diagnostics/shadow-compare.sh` (D-A1 makes shadow-mode a classifier-calibration gate; D-A3 names the `partially_ready` partial-flip path; D-A7 names SC-3a)
- `scripts/dispatch/dispatch-interface.sh` → `templates/model-routing.yml` (CON-3 closure — symbolic tier resolution lives in routing.yml; dispatch-interface reads it, never embeds model IDs)
- `references/model-routing.md` → `scripts/diagnostics/shadow-compare.sh` (Classifier-Confidence Stability Metric numerics 0.10 / N=20 / 50 are the SSOT consumed by shadow-compare's stability check)
- `scripts/dispatch/dispatch-interface.sh` → `scripts/dispatch/classify-task.sh` (P01 classifier interface — character=/confidence= stdout consumed by dispatch-interface's shadow hook)
- `tools/verify/p02-phase-suite.sh` → `tools/verify/p02-additive-schema.sh` (suite invokes additive-schema gate)
- `tools/verify/p02-phase-suite.sh` → `tools/verify/p02-sc3a-roundtrip.sh` (suite invokes SC-3a gate)
- `tools/verify/p02-phase-suite.sh` → `tools/verify/p02-shadow-compare-verdicts.sh` (suite invokes 4-verdict-enum gate)

## Tasks

### T01: SC-11 byte-equality fixture + additive-schema gate (preflight)

See `tasks/T01-additive-schema-fixture-PLAN.md`.

This task ships **before** any work on `scripts/dispatch/dispatch-interface.sh` so the additive-only invariant is mechanically enforced at the moment T02 amends the emitter. Mirror of P01's D-A4 timeline-graduation discipline (verifier-before-deliverable). T01 authors `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (the byte-equality golden file — 5+ records spanning happy-path, pricing-warning, and cost-null shapes captured from the real `dispatch_usage` schema), `tools/verify/p02-fixture-shape.sh` (asserts the fixture is well-formed JSONL with the expected pre-M030 field set), and `tools/verify/p02-additive-schema.sh` (the SC-11 gate). T01 ends green: the fixture is on disk, both verifiers pass against the unmodified `dispatch-interface.sh` (shadow off → byte-identical output), and T02 inherits a hard gate that fails the moment the additive contract is violated.

### T02: dispatch-interface.sh shadow hook + classifier integration + CON-3 closure + append-only

See `tasks/T02-dispatch-shadow-hook-PLAN.md`.

T02 is the high-risk core amendment. Reads P01's classifier (`scripts/dispatch/classify-task.sh`) and routing table (`templates/model-routing.yml`); amends `scripts/dispatch/dispatch-interface.sh`'s `_di_emit_dispatch_usage` body so that when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`: (a) classifier runs against the task plan; (b) routing-table lookup resolves `(character × claude-code) → symbolic-tier`; (c) `model_routed=<symbolic>` and `model_used=<runtime-default-id>` are appended to the `dispatch_usage` record AFTER existing fields (additive-position discipline); (d) `partial_flip_active` and `withheld_classes` are emitted as no-op-empty fields ready for P03/P04 to populate. CC-only short-circuit: when `CLAUDECODE` is unset, the new branch is bypassed. CON-3: dispatch-interface NEVER embeds a literal model ID — `model_used` is sourced from `templates/model-routing.yml resolution.<tier>.claude-code`. Co-authored verifiers: `p02-shadow-emit.sh`, `p02-con3-closure.sh`, `p02-append-only.sh`. T02 also re-runs T01's `p02-additive-schema.sh` against the amended emitter to confirm shadow-off byte-equality holds.

### T03: shadow-compare.sh + 4-verdict + partial-flip enum + SC-3a + stability-metric traceability

See `tasks/T03-shadow-compare-PLAN.md`.

T03 authors `scripts/diagnostics/shadow-compare.sh` (the flip-readiness aggregator) and four co-scheduled verifiers. The script: (a) reads a JSONL corpus from `.orchestrator/milestones/*/execution-log.jsonl` (or a `--corpus <path>` override for fixtures); (b) per class (mechanical/standard/novel), tabulates dispatch count + rolling-window confidence-score variance (last N=20 records per class); (c) emits per-class lines reporting count, latest-window variance, and stability verdict; (d) emits exactly one `flip_recommendation=ready|partially_ready|block|evidence_insufficient` line per the D-A1/D-A3 logic; (e) on `partially_ready` emits a `withheld_classes=<csv>` line and confirms the under-threshold classes have routing-table default `smart` (D-A3 safety). Stability-metric values (0.10 / 20 / 50) are sourced from `references/model-routing.md` with inline reference comments per the traceability gate. SC-3a verifier (`p02-sc3a-roundtrip.sh`) re-classifies each record's referenced PLAN.md and asserts `model_routed` matches the routing-table-resolved symbolic tier. T03 closes the verdict-emission and write-path-correctness gates that gate the milestone-close acceptance battery.

### T04: P02 phase-suite + recent-changes dual-write + commit

See `tasks/T04-phase-suite-and-close-PLAN.md`.

T04 authors `tools/verify/p02-phase-suite.sh` — the straight-line aggregator over all nine P02 sub-gates (mirrors `p01-phase-suite.sh` shape). Each sub-gate is invoked as a literal `bash <path>` statement; `pass`/`fail` accumulators update via `pass=$((pass+1))`/`fail=$((fail+1))` per `$?`. Final line: `SUMMARY: p02-phase-suite.sh pass=N fail=M`. T04 also runs the dual-write recent-changes update against `CLAUDE.md` (and `AGENTS.md` if present) via `scripts/util/dual-write-runtime-md.sh` and stages + commits all P02 deliverables with `git commit -F <message-file>` (multi-line message; AP-008 heredoc-with-expansion forbids the inline-HEREDOC form per CLAUDE.md commit-authoring guidance).

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03 ──▶ T04
```

Strict linear chain. T01 ships the SC-11 byte-equality verifier + golden fixture BEFORE T02 amends `dispatch-interface.sh`, so the additive-only invariant has a mechanical gate at the moment the diff lands (mirrors P01's D-A4 graduation pattern). T02 ships the shadow-hook amendment + co-authored emit/closure/append-only verifiers; T03 consumes T02's emitted `model_routed`/`model_used` fields (the JSONL schema) to author `shadow-compare.sh` and the SC-3a roundtrip verifier. T04 closes the phase with the suite + commit.

T01 and T02 cannot be parallelized: T01 IS the gate that T02 must pass. T02 and T03 cannot be parallelized: T03's SC-3a verifier reads JSONL records that only exist after T02's shadow emitter runs against fixtures (T03 stages those fixtures by running T02's amended emitter under controlled `M030_SHADOW_MODE=1` invocations). T03 and T04 cannot be parallelized: T04's phase-suite invokes T03's verifiers.

## Files Likely Touched

- `scripts/dispatch/dispatch-interface.sh` (modify)
- `scripts/diagnostics/shadow-compare.sh` (create)
- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-ready.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl` (create)
- `tests/fixtures/m030-p02/shadow-corpus-block.jsonl` (create)
- `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl` (create)
- `tools/verify/p02-fixture-shape.sh` (create)
- `tools/verify/p02-additive-schema.sh` (create)
- `tools/verify/p02-shadow-emit.sh` (create)
- `tools/verify/p02-con3-closure.sh` (create)
- `tools/verify/p02-append-only.sh` (create)
- `tools/verify/p02-shadow-compare-verdicts.sh` (create)
- `tools/verify/p02-partial-flip-enum.sh` (create)
- `tools/verify/p02-stability-metric-traceability.sh` (create)
- `tools/verify/p02-sc3a-roundtrip.sh` (create)
- `tools/verify/p02-phase-suite.sh` (create)
- `CLAUDE.md` (modify — recent-changes region)
- `AGENTS.md` (modify if present — recent-changes region dual-write)

<!-- Phase plan and task plan files (this file + tasks/T0[1-4]-*-PLAN.md)
     are written by the planner, not by the executor — not listed here. -->
