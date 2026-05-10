---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M030"
name: "shadow-compare.sh + 4-verdict + partial-flip enum + SC-3a + stability-metric traceability"
depends_on: ["T02"]
---

## Prerequisites

- `scripts/dispatch/dispatch-interface.sh` is amended with the shadow hook + 4 additive fields, gated by `M030_SHADOW_MODE=1` AND `CLAUDECODE=1` (T02 close).
- `tools/verify/p02-shadow-emit.sh`, `tools/verify/p02-con3-closure.sh`, `tools/verify/p02-append-only.sh` all exit 0 (T02 close).
- `tools/verify/p02-additive-schema.sh` re-passes against the amended `dispatch-interface.sh` (T02 close — shadow-off byte-equality preserved).
- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` + `tests/fixtures/m030-p02/round-trip-stage/` exist (T01 close).
- `scripts/dispatch/classify-task.sh` exists and emits `character=` + `confidence=` (P01/T02 close).
- `templates/model-routing.yml` exists with `routing:` + `resolution:` + `cost_rates:` sections (P01/T03 close).
- `references/model-routing.md` exists with `## Classifier-Confidence Stability Metric` section pinning numerics 0.10 / N=20 / 50 (P01/T03 close).

Plan-time prerequisite-existence verification: every path above is asserted by T01 + T02's closure conditions; P01 deliverables are present per P01-SUMMARY.md `key_files:`. The pinned numerics 0.10 / 20 / 50 in `references/model-routing.md` were located at lines 153-170 during plan-authoring (`grep -n` returned "Rolling per-class confidence-score variance threshold = 0.10" at line 153, `N=20` at line 157, "Minimum class-coverage count = 50" at line 163).

## Description

T03 ships the `shadow-compare.sh` aggregator and four co-scheduled verifiers. The script reads JSONL records produced by T02's amended `dispatch-interface.sh` (or by hand-authored fixtures), tabulates per-class evidence + confidence-variance, and emits a single 4-verdict `flip_recommendation=` line per the D-A1/D-A3 logic.

### Five deliverables

1. **`scripts/diagnostics/shadow-compare.sh`** — the aggregator. Reads JSONL corpus from default `.orchestrator/milestones/*/execution-log.jsonl` glob (or `--corpus <path>` override). Per class (mechanical/standard/novel): tabulates dispatch count, computes rolling variance of `confidence=` values over the last N=20 records (where `confidence=` enum {high, medium, low} is mapped to numeric {1.0, 0.5, 0.0} for variance computation), and reports stability verdict per the pinned thresholds.

2. **`tests/fixtures/m030-p02/shadow-corpus-ready.jsonl`** — fixture corpus with all 3 classes meeting the 50-count + variance ≤ 0.10 thresholds. Drives the `flip_recommendation=ready` verdict.

3. **`tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl`** — fixture corpus with mechanical + standard meeting thresholds; novel under-threshold (0 records) AND novel's routing-table default is `smart` (per `templates/model-routing.yml` shipped). Drives the `flip_recommendation=partially_ready` + `withheld_classes=novel` enumeration.

4. **`tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl`** — empty file. Drives the `flip_recommendation=evidence_insufficient` verdict (corpus has 0 dispatches per FR-8 threshold definition).

5. **`tests/fixtures/m030-p02/shadow-corpus-block.jsonl`** — fixture corpus where ≥1 class has dispatches but ALL classes are below threshold (or where 1 of 3 is over threshold but the partial-flip safety constraint fails — under-threshold class's routing default is NOT `smart`). Drives the `flip_recommendation=block` verdict. (For the shipped routing table, novel's default IS `smart` and standard's default is `balanced` — so the simplest `block` fixture has all classes <50 records or all classes with variance > 0.10.)

6. **`tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl`** — 6 hand-authored shadow records, each with a `unitId` that resolves to an existing PLAN.md in `.orchestrator/milestones/`. The `model_routed` value in each record is the routing-table-resolved tier matching the classifier's output for the referenced plan. Drives `p02-sc3a-roundtrip.sh` round-trip verification.

### shadow-compare.sh behavior contract (FR-8 + D-A1 + D-A3)

Inputs:
- `--corpus <path>` flag — if provided, read JSONL records from `<path>` instead of default glob.
- Default corpus: every `.orchestrator/milestones/M*/execution-log.jsonl` file the user has on disk; concat them into a single stream (cat-into-tmp-file pattern).

Per-class processing:
- For each class `c ∈ {mechanical, standard, novel}`:
  - Count records where `"model_routed":"<tier(c)>"` AND class signal can be reverse-extracted. (Implementation detail: T03 records the `character` symbolic value in the JSONL alongside `model_routed` — but T02 emits only `model_routed` as the symbolic tier. Reverse-mapping `model_routed → character` requires reading `templates/model-routing.yml routing:` and inverting the mapping. Awk inversion: for class `c`, the matching tier is `routing[c][claude-code]`; record matches class `c` iff its `model_routed` equals that tier.)
  - For each matching record, extract `confidence=` value if present (T02 currently emits `model_routed` + `model_used` + `partial_flip_active` + `withheld_classes`; T03's `shadow-compare.sh` may need to additionally read `confidence` from records that capture it — OR fold the variance-stability check into `model_routed` consistency. **Simplification**: since T02 records `model_routed` directly, and the stability metric is "rolling variance of confidence-score values," the practical approach is for T02 to ALSO emit `classifier_confidence` as an additive field. **Plan amendment for T03**: extend `shadow-compare.sh` to read `classifier_confidence` from the JSONL record. **Implementation detail for T03 itself**: when authoring the script, document that the classifier-confidence field is expected at the canonical key name `classifier_confidence`. The fixture corpora T03 authors include this field on every record. T03 does NOT amend `dispatch-interface.sh` — that field will be appended by P03 when it resumes the shadow-emit work, OR T03 amends T02's emitter via a small follow-up. **Decision**: T03 authors a one-line amendment to `dispatch-interface.sh` adding `classifier_confidence` to the shadow-on `printf` template alongside the existing four shadow fields. This keeps the contract end-to-end in P02 rather than punting to P03.)

  - Compute the last-20-records rolling variance of confidence values mapped to {high=1.0, medium=0.5, low=0.0}. Variance formula: mean = sum/n; var = sum((x_i - mean)^2)/n. Use awk for the math (no python, no jq, no bc).
  - Class is "stable" iff count >= 50 AND latest-window variance < 0.10.

Verdict logic:
- All 3 classes stable → `flip_recommendation=ready`.
- Total corpus count == 0 → `flip_recommendation=evidence_insufficient`.
- ≥2 classes stable AND every under-threshold class's routing-table default is `smart` (per `templates/model-routing.yml routing.<class>.claude-code`) → `flip_recommendation=partially_ready`. Emit `withheld_classes=<comma-separated-list-of-under-threshold-classes>`.
- Otherwise → `flip_recommendation=block`.

Output shape (stdout):
```
class=mechanical count=<N> variance=<F> stable=<true|false>
class=standard count=<N> variance=<F> stable=<true|false>
class=novel count=<N> variance=<F> stable=<true|false>
flip_recommendation=<ready|partially_ready|block|evidence_insufficient>
[ if partially_ready: ]
withheld_classes=<csv>
```

Stability-metric values (0.10, 20, 50) MUST appear in the script body with inline reference comments naming the SSOT — `references/model-routing.md` (`## Classifier-Confidence Stability Metric` section). Example:

```bash
# Stability thresholds — sourced from references/model-routing.md
# (## Classifier-Confidence Stability Metric section).
VARIANCE_MAX=0.10        # references/model-routing.md
ROLLING_WINDOW=20         # references/model-routing.md
CLASS_COVERAGE_MIN=50     # references/model-routing.md
```

(The traceability gate `p02-stability-metric-traceability.sh` greps each numeric for SSOT-naming on the same line.)

### SC-3a verifier (p02-sc3a-roundtrip.sh)

For each record in `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl`:
1. Extract `unitId` field via `awk` (find `"unitId":"<value>"`).
2. Resolve `unitId` (M###/P##/T##) to a PLAN.md path via the canonical glob: `.orchestrator/milestones/M###/phases/P##/tasks/T##-*-PLAN.md`. First match wins.
3. Run `bash scripts/dispatch/classify-task.sh <plan-path>` → capture `character=<c>` line.
4. Look up `routing.<c>.claude-code` in `templates/model-routing.yml` (awk section-walker) → expected tier.
5. Extract `model_routed` from the JSONL record.
6. Assert expected tier == `model_routed`.

Per-record pass/fail; final `SUMMARY: p02-sc3a-roundtrip.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

The fixture corpus is hand-authored to contain 6 records spanning real M030 PLAN.md paths (e.g., `unitId: "M001/P01/T01"` → `.orchestrator/milestones/M001/phases/P01/tasks/T01-*-PLAN.md`). T03 picks 6 known plans (e.g., from M001, [M005](../../../../../milestones/M005/index.md), [M013](../../../../../milestones/M013/index.md), [M019](../../../../../milestones/M019/index.md), [M020](../../../../../milestones/M020/index.md), [M027](../../../../../milestones/M027/index.md)) and runs `classify-task.sh` against each at fixture-authoring time to record the correct `model_routed` value. The SC-3a verifier then re-runs the classifier independently and asserts agreement.

## Steps

1. **Confirm T02 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p02-additive-schema.sh
   bash tools/verify/p02-shadow-emit.sh
   bash tools/verify/p02-con3-closure.sh
   bash tools/verify/p02-append-only.sh
   ```

   Expected: all four exit 0. If any fails, T02 must be re-opened.

2. **Amend `scripts/dispatch/dispatch-interface.sh` to additionally emit `classifier_confidence`.** Surgical extension to T02's amendment. The shadow-on `printf` format string at the new shadow-on branch gains one more trailing field BEFORE `model_routed`:

   ```text
   ,"classifier_confidence":"%s","model_routed":"%s",...
   ```

   The shell variable `shadow_confidence` is set in the same env-var-gated block as `shadow_routed`/`shadow_used`:

   ```bash
   shadow_confidence="$(printf '%s\n' "$classifier_out" | grep -E '^confidence=' | head -n 1 | sed 's/^confidence=//')"
   ```

   Re-run `p02-additive-schema.sh` after this edit — the shadow-off branch is unchanged so byte-equality still holds. Re-run `p02-shadow-emit.sh` — the existing token-presence checks still pass; add a 4th token assertion (`classifier_confidence`) for Scenario A. (T03 amends `p02-shadow-emit.sh` to include the new token in its assertion list — a one-line edit per scenario.)

3. **Author `tests/fixtures/m030-p02/shadow-corpus-ready.jsonl`.** 150 hand-authored shadow `dispatch_usage` records: 50 with `model_routed=fast` (mechanical class), 50 with `model_routed=balanced` (standard class), 50 with `model_routed=smart` (novel class). All `classifier_confidence` values within each class are `high` (or all `medium`) — variance = 0 < 0.10. Each record's other fields are realistic (timestamps spaced 1 minute apart starting 2026-04-30T10:00:00Z; `unitId` pulled from real M030 phases or synthesized as `M999/P0X/T0Y`). Author one record manually with the full schema, then duplicate-and-vary for the remaining 149 (a small bash loop authored as a one-shot helper script under `/tmp/` — NOT committed; the OUTPUT is the committed fixture).

4. **Author `tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl`.** 100 records: 50 mechanical (variance < 0.10), 50 standard (variance < 0.10), 0 novel. Drives `partially_ready` because: 2 of 3 classes meet thresholds; under-threshold class is novel; novel's routing-table default is `smart` (per shipped `templates/model-routing.yml routing.novel.claude-code: smart`).

5. **Author `tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl`.** Empty file (`touch <path>`). The verdict logic detects `total_count == 0` and emits `evidence_insufficient`.

6. **Author `tests/fixtures/m030-p02/shadow-corpus-block.jsonl`.** 30 records spread across 3 classes (10 each — all classes below the 50-count threshold). Drives `block` because: no class meets the count threshold AND `total_count > 0` (so not `evidence_insufficient`).

7. **Author `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl`.** 6 hand-authored shadow records, each referencing a real PLAN.md by `unitId`. For each, run `bash scripts/dispatch/classify-task.sh <plan-path>` (one-shot, at fixture-authoring time) to determine the correct `character` and look up the resolved tier in `templates/model-routing.yml`. Record the resolved tier as `model_routed` in the fixture. Choose 6 plans spanning all 3 classes (2 mechanical, 2 standard, 2 novel) for full SC-3a coverage. Suggested plans: pick from milestones M001, M005, M013, M019, M020, M027 — all closed, all have stable PLAN.md paths.

8. **Author `scripts/diagnostics/shadow-compare.sh`** per the behavior contract above. Bash 3.2-compatible. Internal carve-out for awk/pipes (mirrors MEM004 emitter-internal pattern — the script is the dispatch-diagnostics SSOT). The body uses awk for variance computation, grep + awk for class-bucket extraction, and the awk YAML section-walker pattern (P01) for routing-table lookup. Stability thresholds declared with inline `references/model-routing.md` comments per the traceability gate. Verdict logic implemented as a sequence of `if`/`elif`/`else` branches against per-class stable flags.

   Inputs handling: parse `--corpus <path>` flag; if absent, glob `.orchestrator/milestones/M*/execution-log.jsonl` (use `find` instead of glob to avoid shell-glob expansion edge cases on missing dirs). Concatenate all JSONL files into `/tmp/shadow-compare-corpus.jsonl` for processing; clean up at exit.

9. **Author `tools/verify/p02-shadow-compare-verdicts.sh`.** Bash 3.2-compatible. Exercises four scenarios — one per fixture corpus:
   - Scenario A: `bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p02/shadow-corpus-ready.jsonl`. Assert exit 0; assert stdout contains exactly one line matching `^flip_recommendation=ready$`.
   - Scenario B: same with `shadow-corpus-partially-ready.jsonl`. Assert `^flip_recommendation=partially_ready$`.
   - Scenario C: same with `shadow-corpus-block.jsonl`. Assert `^flip_recommendation=block$`.
   - Scenario D: same with `shadow-corpus-evidence-insufficient.jsonl`. Assert `^flip_recommendation=evidence_insufficient$`.
   For each, ALSO assert: count of lines matching `^flip_recommendation=` is exactly 1 (closed-enum invariant — no double-emit). Per-scenario pass/fail; final `SUMMARY: p02-shadow-compare-verdicts.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

10. **Author `tools/verify/p02-partial-flip-enum.sh`.** Bash 3.2-compatible. Single scenario:
    - Run `bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl`.
    - Capture stdout to `/tmp/p02-partial-flip-stdout.txt`.
    - Assert `grep -q '^flip_recommendation=partially_ready$' /tmp/p02-partial-flip-stdout.txt`.
    - Assert `grep -q '^withheld_classes=' /tmp/p02-partial-flip-stdout.txt`.
    - Extract withheld list: `grep '^withheld_classes=' /tmp/p02-partial-flip-stdout.txt | head -1 | sed 's/^withheld_classes=//' > /tmp/p02-withheld.txt`.
    - Assert withheld list contains `novel` AND does not contain `mechanical` AND does not contain `standard` (via three `grep -q`/`grep -qv` calls).
    - Assert under-threshold class's routing default is `smart`: awk-walk `templates/model-routing.yml routing.novel.claude-code`; assert value == `smart`.
    - Cleanup: `rm -f /tmp/p02-{partial-flip-stdout,withheld}.txt`.
    Final `SUMMARY: p02-partial-flip-enum.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

11. **Author `tools/verify/p02-stability-metric-traceability.sh`.** Bash 3.2-compatible. Greps `scripts/diagnostics/shadow-compare.sh` for each pinned numeric and asserts each occurrence is on a line that ALSO references the SSOT:
    - `grep -n '0\.10' scripts/diagnostics/shadow-compare.sh` → for each match line, assert it contains `references/model-routing.md` OR `model-routing` OR `Classifier-Confidence Stability Metric`.
    - Same for `20` (rolling window) — but this requires a more careful match because `20` is a common literal; restrict to lines that ALSO contain `WINDOW`, `window`, `ROLLING`, or `rolling` to scope to the stability context.
    - Same for `50` (class coverage) — restrict to lines containing `COVERAGE`, `coverage`, `CLASS`, or `class`.
    For each numeric, count the in-scope occurrences and assert all of them have an SSOT reference. Per-numeric pass/fail; final `SUMMARY: p02-stability-metric-traceability.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

12. **Author `tools/verify/p02-sc3a-roundtrip.sh`** per the behavior contract above. Bash 3.2-compatible. Per-record loop unrolled into 6 explicit blocks (no inline `for` loop — AD-19). Each block:
    - Reads the i-th line from `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl` via `sed -n '<i>p' < <path> > /tmp/p02-sc3a-record-<i>.txt`.
    - Extracts `unitId` via `grep -oE '"unitId":"[^"]+"' < /tmp/p02-sc3a-record-<i>.txt | head -1 | sed 's/.*:"//; s/"$//' > /tmp/p02-sc3a-uid-<i>.txt`. Reads `unitId` from the tmp file.
    - Resolves PLAN.md path via `find .orchestrator/milestones/<M>/phases/<P>/tasks/ -name '<T>-*-PLAN.md' | head -1 > /tmp/p02-sc3a-path-<i>.txt`. Reads path from tmp file.
    - Runs `bash scripts/dispatch/classify-task.sh <path> > /tmp/p02-sc3a-classified-<i>.txt`. Extracts `character=<c>` from output.
    - Awk-walks `templates/model-routing.yml routing.<c>.claude-code` → expected tier.
    - Extracts `model_routed` from the original record.
    - Asserts expected tier == `model_routed`. Per-record `pass`/`fail` accumulator.
    - Cleanup tmp files at end of each block.
    Final `SUMMARY: p02-sc3a-roundtrip.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

13. **Run all five new T03 verifiers as a self-check:**

    ```bash
    bash tools/verify/p02-additive-schema.sh
    bash tools/verify/p02-shadow-emit.sh
    bash tools/verify/p02-shadow-compare-verdicts.sh
    bash tools/verify/p02-partial-flip-enum.sh
    bash tools/verify/p02-stability-metric-traceability.sh
    bash tools/verify/p02-sc3a-roundtrip.sh
    ```

    Expected: all six exit 0. If `p02-shadow-compare-verdicts.sh` fails on a verdict, the verdict-logic branching in `shadow-compare.sh` is wrong — re-check the count + variance + partial-flip-safety conditions. If `p02-partial-flip-enum.sh` fails on `withheld_classes` content, the partially_ready branch's enumeration logic is wrong. If `p02-stability-metric-traceability.sh` fails, a numeric literal is on a line without SSOT-naming — add the inline comment. If `p02-sc3a-roundtrip.sh` fails on a record, the fixture's `model_routed` value disagrees with the live classifier output — re-run the classifier against the fixture's PLAN.md and update the fixture to match (or accept the disagreement as a real classifier-vs-fixture drift signal that needs investigation).

14. **Stage and commit.** Stage `scripts/dispatch/dispatch-interface.sh` (small Step-2 amendment), `scripts/diagnostics/shadow-compare.sh`, `tools/verify/p02-shadow-compare-verdicts.sh`, `tools/verify/p02-partial-flip-enum.sh`, `tools/verify/p02-stability-metric-traceability.sh`, `tools/verify/p02-sc3a-roundtrip.sh`, `tests/fixtures/m030-p02/shadow-corpus-{ready,partially-ready,block,evidence-insufficient}.jsonl`, `tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl`. Author commit message file via Write to `/tmp/p02-t03-commit-msg.txt`; commit with `git commit -F /tmp/p02-t03-commit-msg.txt`. Recommended message subject: `M030/P02/T03: shadow-compare 4-verdict + SC-3a + stability-metric traceability`.

## Must-Haves

This task satisfies the phase truths:

- "`scripts/diagnostics/shadow-compare.sh` exists and emits exactly one `flip_recommendation=` line whose value is drawn from the closed enum..." — gated by `tools/verify/p02-shadow-compare-verdicts.sh`.
- "`shadow-compare.sh`'s `partially_ready` verdict enumerates the withheld classes..." — gated by `tools/verify/p02-partial-flip-enum.sh`.
- "`shadow-compare.sh` consumes the pinned classifier-confidence stability metric values from `references/model-routing.md`..." — gated by `tools/verify/p02-stability-metric-traceability.sh`.
- "SC-3a holds: for each record in a shadow-mode JSONL fixture corpus where `model_routed` is set..." — gated by `tools/verify/p02-sc3a-roundtrip.sh`.

## Verification

```bash
bash tools/verify/p02-additive-schema.sh
bash tools/verify/p02-shadow-emit.sh
bash tools/verify/p02-shadow-compare-verdicts.sh
bash tools/verify/p02-partial-flip-enum.sh
bash tools/verify/p02-stability-metric-traceability.sh
bash tools/verify/p02-sc3a-roundtrip.sh
```

Each verifier uses single-script-file shape per AD-19. All six must exit 0 before T03 closes.

## Inputs

### From Previous Tasks

- `scripts/dispatch/dispatch-interface.sh` (amended by T02)
  - Key API: emits shadow `dispatch_usage` records with `classifier_confidence` (added in T03 Step 2), `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes` fields when `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`.
- `tools/verify/p02-shadow-emit.sh` (T02 + T03 amendment)
  - Key API: amended in Step 2 to also assert `classifier_confidence` token presence in shadow-on Scenario A.
- `tools/verify/p02-additive-schema.sh` (T01)
  - Key API: SC-11 byte-equality gate. Re-runs after T03 Step 2 amendment to confirm shadow-off byte-equality preserved.

### From Disk (Pre-existing)

- `scripts/dispatch/classify-task.sh` (P01/T02)
  - Key API: `bash <path> <plan-path>` writes `character=<c>` + `confidence=<c>`. Used by `shadow-compare.sh` (no — by SC-3a verifier) and by fixture-authoring at Step 7.
- `templates/model-routing.yml` (P01/T03)
  - Key API: `routing.<character>.claude-code` → symbolic tier; `resolution.<tier>.claude-code` → concrete model ID. T03's `shadow-compare.sh` reads via awk section-walker (P01 pattern).
- `references/model-routing.md` (P01/T03)
  - Key API: `## Classifier-Confidence Stability Metric` section pins variance ≤ 0.10, rolling N=20, per-class coverage 50. T03's `shadow-compare.sh` cites this section in inline comments next to the numeric literals.
- `.orchestrator/milestones/M*/` — real PLAN.md tree consumed by SC-3a fixture-authoring (Step 7) and by `p02-sc3a-roundtrip.sh` resolution.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The verifiers' internal logic uses tmp-file intermediates rather than inline pipes-in-command-substitution.
- **MEM004 dispatch-internal carve-out**: `scripts/diagnostics/shadow-compare.sh` is a dispatch-diagnostic SSOT; awk/pipes/`$()` permitted in its body. The verifiers that GATE it (the four `p02-*.sh` files) follow strict AD-19.
- **CON-3 (symbolic-tier closure)**: `shadow-compare.sh` reads `templates/model-routing.yml` for class → tier mapping; never embeds tier-symbol literals like `fast`/`balanced`/`smart` in routing logic without a corresponding awk YAML lookup. (Tier *names* may appear as constants — they are part of the symbolic interface, not concrete model IDs. The CON-3 verifier checks for concrete model-ID literals only, not symbolic tier names.)
- **CON-2/FR-19/SC-11 (additive-only schema)**: T03 Step 2's small amendment to `dispatch-interface.sh` adds `classifier_confidence` ONLY in the shadow-on `printf` branch. The shadow-off branch is unchanged. Re-run `p02-additive-schema.sh` after Step 2 confirms byte-equality preserved.
- **CON-6 (append-only shadow corpus)**: `shadow-compare.sh` is read-only against the corpus — never writes to JSONL files. Verified implicitly (the script's body contains no `>>` or `>` redirection to `*.jsonl` paths; the verifier `p02-append-only.sh` would catch a regression if `shadow-compare.sh` were ever invoked from `dispatch-interface.sh`'s emit path, which it is not).
- **D-A1 (4-verdict closed enum)**: exactly one `flip_recommendation=<value>` line on stdout per invocation; value drawn from {ready, partially_ready, block, evidence_insufficient}. Verified by `p02-shadow-compare-verdicts.sh`.
- **D-A3 (partial_flip enumeration + safety constraint)**: when `partially_ready`, emit `withheld_classes=<csv>`; under-threshold class's routing-table default MUST be `smart`. Verified by `p02-partial-flip-enum.sh`.
- **D-A7 (SC-3a write-path correctness)**: every shadow record's `model_routed` matches an independent re-classification of the referenced plan. Verified by `p02-sc3a-roundtrip.sh`.
- **Stability-metric traceability**: numeric literals 0.10 / 20 / 50 in `shadow-compare.sh` MUST appear on lines that name `references/model-routing.md` OR equivalent SSOT identifier. Verified by `p02-stability-metric-traceability.sh`.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. The variance computation uses awk (which has its own variable scoping; bash 3.2 only matters at the shell-glue level).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T03 does NOT introduce SQL — N/A.

## Expected Output

- `scripts/dispatch/dispatch-interface.sh` — small Step-2 amendment adding `classifier_confidence` to the shadow-on `printf` template.
- `scripts/diagnostics/shadow-compare.sh` — 4-verdict aggregator, stability-metric traceable, partially_ready enumerates withheld classes.
- 5 fixture JSONL files at `tests/fixtures/m030-p02/`.
- 4 new verifiers at `tools/verify/p02-{shadow-compare-verdicts,partial-flip-enum,stability-metric-traceability,sc3a-roundtrip}.sh`.
- `tools/verify/p02-shadow-emit.sh` updated to assert `classifier_confidence` token presence in Scenario A.
- `bash tools/verify/p02-shadow-compare-verdicts.sh` exits 0 with `SUMMARY: pass=4 fail=0` (4 scenarios).
- `bash tools/verify/p02-partial-flip-enum.sh` exits 0 with `SUMMARY: pass=N fail=0`.
- `bash tools/verify/p02-stability-metric-traceability.sh` exits 0 with `SUMMARY: pass=N fail=0`.
- `bash tools/verify/p02-sc3a-roundtrip.sh` exits 0 with `SUMMARY: pass=6 fail=0` (6 records).

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p02/shadow-corpus-ready.jsonl` → 3 per-class lines + `flip_recommendation=ready`, exit 0.
- Same with `shadow-corpus-partially-ready.jsonl` → 3 per-class lines + `flip_recommendation=partially_ready` + `withheld_classes=novel`, exit 0.
- Same with `shadow-corpus-evidence-insufficient.jsonl` → minimal output (possibly just `flip_recommendation=evidence_insufficient` if zero records produces empty per-class output).
- `bash tools/verify/p02-sc3a-roundtrip.sh` → 6 per-record OK lines + `SUMMARY: p02-sc3a-roundtrip.sh pass=6 fail=0`, exit 0.

The choice to read corpus via `--corpus <path>` vs default-glob is operationally important: in production, operators run `bash scripts/diagnostics/shadow-compare.sh` (no flag) against their `.orchestrator/milestones/*/execution-log.jsonl`; for testing, the verifiers pin the corpus path explicitly. The verifier ladder therefore exercises the `--corpus` path; production-glob is exercised post-launch when real shadow data accumulates.

The `classifier_confidence` field added in Step 2 is the load-bearing addition that makes the variance-stability check possible. Without it, `shadow-compare.sh` could only check class-coverage count, not confidence-variance — degrading the "calibration gate" from D-A1's 2-axis check to a 1-axis count check. Step 2 is therefore on the critical path for the D-A1 calibration story and not optional. The amendment is one shell-variable line + one format-string field — the additive-schema discipline is preserved (shadow-off byte-equality unchanged).

P03 will consume T03's `partial_flip_active` and `withheld_classes` placeholder fields by populating them at dispatch time when an operator activates a partial flip via config. T03 reserves the schema position; P03 fills in the values. The verifier `p02-partial-flip-enum.sh` exercises this via a hand-authored fixture in P02 (no live config plumbing yet) — P03 will extend it to exercise the live config-driven path.

P04 will consume T03's `shadow-compare.sh` directly via the FR-9 programmatic flip-gate — `dispatch-interface.sh` will call `shadow-compare.sh` before the first live-routed dispatch and refuse to proceed on `evidence_insufficient` or `block` verdicts. T03's verdict contract is the FR-9 gate's input; the four-verdict closed enum IS the FR-9 contract surface.
