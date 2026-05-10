---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M028"
name: "Collapse-decision evidence + per-screenshot causal trace"
depends_on: [T01]
---

## Prerequisites

- T01 completed: [`.orchestrator/milestones/M028/phases/P01/classifier-audit.md`](../../../../../milestones/M028/phases/P01/classifier-audit.md) exists and `bash scripts/util/run-probe.sh scripts/verify/m028/p01-replay-coverage.sh` exits 0.
- T02 completed (file path only — content not consumed): `tests/fixtures/m028-pre-repair-snapshot.json` exists. T03 references this path in `P01-VERIFICATION.md`'s "Cited fixtures" section but does not read the file content.
- The M028 spec (`specs/031-autonomous-hardening-v3/spec.md`) and context draft ([`.orchestrator/milestones/M028/M028-CONTEXT.md`](../../../../../milestones/M028/M028-CONTEXT.md)) are on-disk. T03 reads the Architectural Decisions section of the context draft for the collapse-mechanics option-(a) replanning hook.

## Description

Read T01's classifier audit, attribute every source event to one or more findings (A, B, C, D, E, F, G), and write the canonical P01 verification document. The document does three things:

1. **Per-screenshot causal trace**: for every source event in T01's audit, name the finding (or findings — some events trace to multiple) responsible for the in-the-wild failure. This is the operator-facing evidence record — it is read by humans during retrospective and by the planner during the collapse-decision pass.

2. **Collapse-decision recommendation**: count how many source events trace to Finding A (hook portability) only — that is, would be resolved by P02's hook portability fix alone, with no other finding contributing. If the count is ≥ 6 of 7 (per the spec's collapse threshold), recommend `collapse-to-2-PRs`; otherwise recommend `full-5-phase`. Cite per-event evidence; the recommendation must be reproducible from the cited evidence alone.

3. **Corpus-staging note**: list the candidate corpus entries that P03 will append to `tests/fixtures/m021-prompt-corpus.txt`. For each candidate, record (a) the verbatim command, (b) the expected verdict under the M028 classifier (i.e., the AP-ID that should fire after P03 ships), (c) the source event ID from T01's audit. P03 will consume this list verbatim — T03's job is to land the list, not author the corpus entries themselves.

## Steps

1. Read [`.orchestrator/milestones/M028/phases/P01/classifier-audit.md`](../../../../../milestones/M028/phases/P01/classifier-audit.md). For each `## SE-NN` source-event section, parse the "Source", "Verbatim command", "Existing-classifier verdict", and "Observed behavior in the wild" fields.

2. For each source event, attribute root cause(s) by matching evidence to findings. The mapping rubric (apply in order; an event may match multiple):

   | Trigger | Finding | Notes |
   |---|---|---|
   | The event occurred under a `$CLAUDE_PROJECT_DIR` that is not the orchestrator repo (path prefix not `orchestrator`) AND the existing classifier verdict is `REJECT` | A | Hook portability — would have rejected if hook had run |
   | The event's existing-classifier verdict is `ALLOW` (or absent) AND the command shape matches one of AP-010 / AP-011 / AP-012 / AP-013 / AP-014 | B (or G if AP-014 specifically) | Classifier shape — under-matched |
   | The event is a Stop-hook `command not found` failure naming `orchestrator-post-verify` or `orchestrator-before-commit` | F | Adapter+installer — bare names not on PATH |
   | The event involves `/bin/rm` and `&&` chained with `ls` for output verification | D | Destructive op — needs `cleanup-stale-results.sh` wrapper |
   | The event involves agent-constructed `grep …; echo "---"; grep …` or `node -e "<multiline>"` shapes for investigation | E | Investigation pattern — needs wrapper |
   | The event's existing-classifier verdict is `ALLOW` AND the command contains `xargs -I{} sh -c '<body>'` with in-body connectors that combined with top-level pipe count exceed 2 | G | Body-descent — AP-014 specifically |
   | Any compound-shell shape that the existing AP-009 should have caught but did not | C | Classifier under-match (sibling of B/G — record both if applicable) |

3. **Compute the collapse-decision count**: a source event is "resolved by Finding A alone" iff Finding A is the only attribution from step 2 AND removing the hook-portability gap would have caused the existing classifier verdict to fire (i.e., the existing verdict is `REJECT`, just on the wrong project). Count these.

   - If count ≥ 6 of 7 Bash-classification source events (excluding the Finding F Stop-hook event from the denominator — it is not a Bash classification target): recommend `collapse-to-2-PRs`. PR-1 = hook portability + adapter+installer dedup (P02 unchanged); PR-2 = the one outlier as a corpus entry + classifier rule.
   - Otherwise: recommend `full-5-phase`. P02 → P03 → P04 → P05 ship as roadmapped.

4. **Build the corpus-staging list**. For every source event whose attribution includes B or G (under-matched shapes), record a candidate corpus entry with:
   - Verbatim command (byte-for-byte from T01's audit).
   - Expected verdict under M028 classifier — the AP-ID that should fire (AP-010, AP-011, AP-012, AP-013, or AP-014). Choose by command shape per the rubric in step 2.
   - Source event ID (`SE-NN`) from T01's audit.

   Per FR-13 the corpus extension lands at 7 entries. If the staging list lands at a different count, T03 documents the discrepancy in a "Corpus count rationale" subsection — the spec's "seven" is the target but the operator-confirmed count after attribution is what P03 ships.

5. Compose `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md`. Required structure:

   ```markdown
   ---
   schema_version: "1.0"
   type: phase-verification
   phase: "P01"
   milestone: "M028"
   verified_at: "<ISO-8601 timestamp>"
   collapse_decision: "<full-5-phase | collapse-to-2-PRs>"
   ---

   ## Cited Inputs

   - [`.orchestrator/milestones/M028/phases/P01/classifier-audit.md`](../../../../../milestones/M028/phases/P01/classifier-audit.md) (T01 deliverable)
   - `tests/fixtures/m028-pre-repair-snapshot.json` (T02 deliverable; consumed by P02 `--repair` verifier)
   - `specs/031-autonomous-hardening-v3/spec.md` (canonical source of source-event verbatim commands)

   ## Per-Screenshot Causal Trace

   <!-- One section per source event from classifier-audit.md, in audit order -->

   ### SE-NN: <label from audit>

   - **Source**: <as cited in audit>
   - **Verbatim command**: see `classifier-audit.md` SE-NN "Verbatim command"
   - **Existing-classifier verdict**: <ALLOW | REJECT: AP-NNN | absent>
   - **Root-cause attribution**: <one or more of A, B, C, D, E, F, G>
   - **Resolved-by-Finding-A-alone**: <YES | NO>
   - **Rationale**: <one or two sentences citing the rubric step that drove the attribution>

   ## Collapse Decision

   - **Bash-classification source events**: <N> (excludes Finding F Stop-hook event)
   - **Resolved by Finding A alone**: <M> of <N>
   - **Threshold**: M ≥ (N − 1)
   - **Decision**: `<full-5-phase | collapse-to-2-PRs>`
   - **Rationale**: <one paragraph citing per-event evidence>
   - **Replanning trigger**: if `collapse-to-2-PRs`, the planner enters `replanning` after this verification, marks P02–P05 stale per `M028-CONTEXT.md` Architectural Decisions option-(a), and rewrites them into PR-1 (hook portability) + PR-2 (the one outlier as corpus entry + classifier rule). If `full-5-phase`, P02–P05 stay as-roadmapped.

   ## Corpus Staging List (consumed by P03)

   - **Target count**: 7 (per FR-13)
   - **Authored count**: <K>
   - **Discrepancy rationale**: <only if K ≠ 7>

   ### Candidate corpus entries

   <!-- One subsection per candidate -->

   #### Candidate <i>

   - **Source event**: SE-NN
   - **Verbatim command**: see `classifier-audit.md` SE-NN
   - **Expected M028-classifier verdict**: `REJECT: AP-NNN — <reason>`
   - **Reject_lookup remediation target**: `scripts/util/<wrapper>.sh` or "remediation hint only"
   ```

6. Author `scripts/verify/m028/p01-collapse-decision-recorded.sh`. Single-script-file shape per AD-19. The script:
   - Verifies `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md` exists.
   - Asserts the file's frontmatter contains a `collapse_decision:` field whose value is exactly `full-5-phase` or `collapse-to-2-PRs` (no other values accepted).
   - Asserts the body contains a `## Collapse Decision` section heading.
   - Asserts the body contains a `## Per-Screenshot Causal Trace` section heading.
   - Asserts the body contains a `## Corpus Staging List` section heading.
   - Asserts that within the Per-Screenshot Causal Trace section, every line containing `**Resolved-by-Finding-A-alone**:` is followed (on the same line) by either `YES` or `NO`.
   - On all checks PASS, exit 0 with `PASS: P01-VERIFICATION.md collapse-decision shape-valid`.
   - On any FAIL, exit 1 with `FAIL: <which check> — <one-line diagnostic>`.

7. Run the verifier:

   ```bash
   bash scripts/util/run-probe.sh scripts/verify/m028/p01-collapse-decision-recorded.sh
   ```

   Confirm `PASS`. If FAIL, iterate on `P01-VERIFICATION.md` content — never edit the verifier to make it pass.

## Must-Haves

This task addresses the Truth: "The collapse-decision evidence file records, for every source event, both the existing-classifier verdict and a root-cause attribution mapping to one or more findings (A, B, C, D, E, F, G); and records an explicit collapse-decision recommendation with cited per-event evidence." It produces the artifacts `P01-VERIFICATION.md` and `scripts/verify/m028/p01-collapse-decision-recorded.sh` referenced by the phase-plan must-haves, and satisfies both Key Links (`P01-VERIFICATION.md` → `classifier-audit.md` and → `tests/fixtures/m028-pre-repair-snapshot.json`).

## Verification

```bash
bash scripts/verify/m028/p01-collapse-decision-recorded.sh
```

## Notes

Expected verifier output is a single line of the form `PASS: P01-VERIFICATION.md collapse-decision shape-valid`.

## Inputs

### From Previous Tasks

- [`.orchestrator/milestones/M028/phases/P01/classifier-audit.md`](../../../../../milestones/M028/phases/P01/classifier-audit.md) (from T01)
  - Key shape: per-source-event sections with `## SE-NN`, fields `Source`, `Cited at`, `Observed behavior in the wild`, `Verbatim command` (fenced block), `Existing-classifier verdict` (fenced block).
  - Reads: T03 reads every section's Source, Verbatim command, and Existing-classifier verdict to drive the attribution rubric.

- `tests/fixtures/m028-pre-repair-snapshot.json` (from T02)
  - Key use: T03 references this file path in `P01-VERIFICATION.md`'s "Cited Inputs" section. T03 does not read the file content.

### From Disk (Pre-existing)

- `specs/031-autonomous-hardening-v3/spec.md` — canonical source of finding definitions; T03 reads the per-finding evidence sections to confirm rubric application is consistent with the spec's own narrative.
- [`.orchestrator/milestones/M028/M028-CONTEXT.md`](../../../../../milestones/M028/M028-CONTEXT.md) — Architectural Decisions section pins the option-(a) replanning hook; T03 cites this as the authority for the "Replanning trigger" line in the Collapse Decision section.

## Constraints

- **AD-19 single-script-file shape**: `scripts/verify/m028/p01-collapse-decision-recorded.sh` is a flat single-file bash script. No nested helper dirs, no compound-chain bodies > 2 connectors, no plain subshells, no `bash -c '...'` chains.
- **bash 3.2 + POSIX sh (CON-2)**: every line of the verifier runs on bash 3.2.
- **Reproducibility**: the collapse-decision recommendation must be reproducible from `classifier-audit.md` + the rubric in step 2 alone. T03 does not introduce evidence not present in T01's audit; the recommendation derives mechanically from the attribution counts.
- **No replanning execution in T03**: T03 records the decision; it does not execute the replanning. If the decision is `collapse-to-2-PRs`, the orchestrator's planning subsystem consumes the decision in a separate pass when the operator runs `orchestrator:plan-phase` for P02. T03's job is the evidence; the action is downstream.
- **Threshold floor**: the collapse threshold is `M ≥ (N − 1)` where N is the count of Bash-classification source events. Per the spec's "if Finding A alone resolves 6 of 7", N = 7 and threshold = 6. T03's verifier does not assert N or M values — it asserts shape only — but the document body must show the arithmetic.

## Expected Output

- `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md` — markdown with required frontmatter (`collapse_decision:` field) and required sections (Cited Inputs, Per-Screenshot Causal Trace, Collapse Decision, Corpus Staging List). ≥ 80 lines, contains the literal substring `Collapse Decision`, references both `classifier-audit.md` and `tests/fixtures/m028-pre-repair-snapshot.json`.
- `scripts/verify/m028/p01-collapse-decision-recorded.sh` — flat bash script, ≥ 10 lines, references `Collapse Decision`.
- Standard task summary at [`.orchestrator/milestones/M028/phases/P01/tasks/T03-collapse-decision-evidence-SUMMARY.md`](../../../../../milestones/M028/phases/P01/tasks/T03-collapse-decision-evidence-SUMMARY.md).
