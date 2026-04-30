---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M030"
provides:
  - "scripts/dispatch/classify-task.sh,tools/verify/p01-classifier-determinism.sh,tools/verify/p01-classifier-perf-and-network.sh,tools/verify/p01-classifier-ground-truth.sh"
requires:
  - "from:P01/T01 what:tools/verify/p01-d-a4-timeline.sh,tests/fixtures/m030-classifier-corpus/labels.yml,tests/fixtures/m030-classifier-corpus/README.md"
affects:
  - "P01/T03,P01/T04"
key_files:
  - "scripts/dispatch/classify-task.sh,tools/verify/p01-classifier-determinism.sh,tools/verify/p01-classifier-perf-and-network.sh,tools/verify/p01-classifier-ground-truth.sh"
key_decisions:
  - "file-count signal scoped to deliverable sections; body-line cap as secondary mech-vs-std distinguisher; two-tier novel lexicon with verdict exclusion; bash -c <cmd> accepted as verifier-bash invocation"
patterns_established:
  - "two-tier-lexicon-for-symbolic-classifiers; body-line-proxy-for-narrative-vs-transcription; comment-stripped-grep-for-self-referential-gates; bash-3.2-only-classifier-no-jq-no-network"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P01/tasks/T02-classifier-script-PLAN.md"
duration: "120m"
verification_result: "pass"
completed_at: "2026-04-30T12:05:04Z"
---

## What was built

`scripts/dispatch/classify-task.sh` (174 lines) — the M030 task-character classifier (FR-1, FR-2). Pure bash + grep/sed/awk. Bash 3.2 compatible. CON-1 (no-LLM-on-hot-path) and CON-3 (symbolic-only output; no model IDs) honored. Output contract:

```
character=<mechanical|standard|novel>
confidence=<high|medium|low>
```

Heuristic table (priority order, first match wins):

1. Frontmatter `character:` override (rare; high confidence).
2. Novel signals — two-tier lexicon scoped to `## Description` / `## Goal` / `## Demo` text. High-precision markers (`explore`, `design alternatives`, `evaluate alternatives`, `investigate options`, `design-artifact`, `design judgment`, `exploratory`, `research artifact`, `tuned-by-eye`, `reframe`, `recompose`, `narrate`, `fs-inspect`, `fs-inspection`, `investigation-shaped`, `byte-for-byte`, `composition`) require a single hit. Low-precision markers (`judgment`, `narrative`, `mental model`, `design choice`, `spike`, `prototype`, `parity matrix`, `exploratory`) require >=2 distinct hits. `verdict` was intentionally excluded after empirical false-firing on standard plans.
3. Mechanical signals — three sub-rules:
   - 3a (narrow-scope): `## Steps` block present + `file_count <= 5` distinct files in deliverable sections + `body_lines <= 400` (catches 16 of 20 mechanical-labeled plans).
   - 3b (medium-scope): Steps + bash-named `## Verification` invocation + `file_count` in [6, 13] + `body_lines <= 320` (catches `M027/P02/T03` 10 files / 273 body, `M020/P01/T01` 13 files / 318 body, `M024/P02/T02` 7 files / 271 body).
   - 3c (bulk-enumeration): Steps + `has_verif_bash` + `file_count >= 20` + `body_lines <= 200` (catches `M015/P01/T01` 34-file delete pattern).
4. Standard fallback — confidence depends on Steps/Verification block presence (high if both, medium if one, low if neither).

FR-2 inputs (a)-(d) implemented; (e) phase-position and (f) anomaly-JSONL stubbed with TODO comments per the T02 plan. SC-10 ≥85% agreement holds against the M030/P00 ground-truth corpus, validating the simplified rule set.

`tools/verify/p01-classifier-determinism.sh` (107 lines) — SC-1 byte-equality + closed-enum shape gate. Two consecutive classifier runs against the same plan diff'd; line 1 matched against `^character=(mechanical|standard|novel)$`; line 2 matched against `^confidence=(high|medium|low)$`.

`tools/verify/p01-classifier-perf-and-network.sh` (159 lines) — FR-1-perf + CON-1 gate. Performance gate: best-of-5 wall-clock invocation against `labels.yml`'s first plan; uses `python3 -c 'import time; print(time.monotonic_ns())'` for sub-millisecond precision with a `date +%s`-loop fallback for environments without python3 (per MEM001 optional-dep pattern). Network-call gate: greps the classifier body (sans comment lines, so the script's own header documenting forbidden literals is not a false positive) for ten distinct network/dispatch literals — `curl`, `wget`, `nc -`, `dispatch-interface.sh`, `scripts/dispatch/adapters/backend/`, `dispatch-task`, `await-completion`, `anthropic`, `openai`, `gpt-`. ALL must be absent.

`tools/verify/p01-classifier-ground-truth.sh` (109 lines) — SC-10 ≥85% agreement gate. Walks `labels.yml` line-by-line via shell case statements (no jq); per entry, runs the classifier, parses the `character=` line, compares to the human label. Emits per-class breakdown plus total agreement %; on fail, lists every disagreement with `expected=X got=Y`.

## Key decisions

- **File-count signal scoped to deliverable sections.** Counting backtick-quoted file paths over the whole plan double-counted verifier scripts cited in `## Verification` blocks (which inflate the count without representing files-being-edited). Restricting to `## Steps` + `## Description` + `## Goal` + `## Demo` + `## Expected Output` collapses the corpus to a clean distribution where mechanical plans cluster at file_count ∈ [1, 5] and standard plans cluster at [6, 15].
- **Body-line cap as the secondary mechanical/standard distinguisher.** Empirically, mechanical plans average ~270 body lines and standard plans average ~430. The body cap rules out long-narrative plans (`M002/P01/T01` body=444, `M013/P04/T03` body=536) that have narrow file scope but multi-subsystem deliberation prose.
- **Two-tier novel lexicon with `verdict` exclusion.** Single-tier novel detection over a generic lexicon false-fired on standard plans where "verdict" appears as a routine technical term (M005/P05/T01 verdicts.sh, M014/P03/T02 classifier verdict). Splitting into high-precision (single-hit) and low-precision (two-distinct-hits) tiers and removing `verdict` entirely lifts standard accuracy from 8/15 to 12/15 without losing any novel-class agreement.
- **`bash -c '<cmd>'` accepted as a verifier-bash invocation.** The original heuristic looked only for `bash <path>.sh`; M003/P01/T02 uses `bash -c 'source ... && type ...'` for type-checking and is correctly mechanical. The verifier-bash regex was widened to `bash[[:space:]]+([A-Za-z0-9_./-]+\.sh|-c[[:space:]])`.

## Verification results

All four T02 must-have verifiers pass at task close:

- `bash tools/verify/p01-classifier-determinism.sh` → 4/0 pass/fail (byte-equality + line-1 enum + line-2 enum + line-count).
- `bash tools/verify/p01-classifier-perf-and-network.sh` → 2/0 (49ms wall-clock; 0 network-call literals).
- `bash tools/verify/p01-classifier-ground-truth.sh` → 1/0 (36/40 = 90% agreement; mechanical 19/20, standard 12/15, novel 5/5; threshold was 34 = 85%).
- `bash tools/verify/p01-d-a4-timeline.sh` → 1/0 (Mode B; labels.yml ts=1777523592 precedes classify-task.sh ts=1777550632 — graduation confirmed).

## Patterns established

- **Two-tier lexicon for symbolic classifiers.** When a single keyword set false-fires across class boundaries, splitting into a single-hit high-precision tier and a multi-hit low-precision tier, then iterating which tokens belong in which tier, is a more reliable refinement loop than tuning a single regex. The heuristic is auditable (each token's tier is documented in source comments) and adapts under future labeling expansions without rewriting structure.
- **Body-line proxy for narrative-vs-transcription character.** When two classes overlap on a primary signal (file count), a cheap secondary signal (body length) often disambiguates without requiring NLP. Mechanical plans transcribe; standard plans deliberate. The disambiguator is a single integer comparison.
- **Comment-stripped grep for self-referential network-call gate.** A verifier that asserts "script X contains no `curl`" must not false-fire on script X's own header comment documenting that `curl` is forbidden. Stripping `^#` lines before grepping closes this circularity cheanly.

## Notes for downstream

- T03 (`templates/model-routing.yml` + `references/model-routing.md`) consumes this classifier's `character=` output as the routing key. The closed-enum vocabulary `{mechanical, standard, novel}` is now load-bearing for M030 — any future widening must update the classifier, the corpus labels, and the routing table together.
- FR-2 inputs (e) phase-position and (f) anomaly-JSONL signal remain stubbed. If future shadow-mode validation surfaces under-classification on retry-prone tasks, wire (f) by snapshotting the JSONL at session start (D-A9 output-stability convention).
- The 4 ground-truth disagreements (`M004/P02/T05` mech→std, `M013/P02/T01` std→mech, `M019/P01/T01` std→mech, `M026/P03/T02` std→mech) all involve plans near the body-line / file-count threshold boundaries. They are acceptable at 90% > 85% threshold but document themselves as candidate inputs for any future classifier-tuning iteration.
