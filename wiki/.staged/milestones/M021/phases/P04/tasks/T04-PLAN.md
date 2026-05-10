---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M021"
name: "DECISIONS.md D012 (M021-before-M019 reorder) + ANTIPATTERNS.md AP-005..AP-009 cross-reference pass"
depends_on: ["T01"]
---

## Prerequisites

- T01 has produced `tests/fixtures/m021-prompt-corpus.txt` (its relative path appears verbatim in the new ANTIPATTERNS.md cross-reference text).
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) contains rows D001..D011 (current head-of-file state) — verify before editing.
- `ANTIPATTERNS.md` contains entries AP-001..AP-009 (AP-005..AP-009 were authored in M021/P02) — verify before editing.

### Current state landmarks

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — GitHub-style markdown table with header row plus 11 data rows (D001..D011). Column order: `#`, `When`, `Scope`, `Decision`, `Choice`, `Rationale`, `Revisable?`. Append-only; new rows go at the end.
- `ANTIPATTERNS.md` — markdown file with append-only AP-### entries. Each entry follows a fixed structure: `## AP-NNN: <title>`, then `**Observed In**`, `**Principle Violated**`, `**Description**`, `**Evidence**`, `**Remedy**` blocks. Entries AP-005..AP-009 were authored in M021/P02 with M011/P05–P07 screenshot citations and wrapper-path remedies.

### On the D010 vs D012 question

The M021 roadmap and M021-CONTEXT.md (authored 2026-04-17) anticipated that the M021-before-[M019](../../../../../milestones/M019/index.md) reorder decision would land as `D010`. Between roadmap authoring and P04 execution, `D010` ([M018](../../../../../milestones/M018/index.md) framing amendment per article synthesis) and `D011` ([M020](../../../../../milestones/M020/index.md) trigger criteria at M012/P02 close) landed in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md). P04 therefore logs the M021 reorder as **`D012`** — the next available sequential ID — with a parenthetical note in the Rationale column documenting the ID reassignment for audit continuity.

This is a surgical correction (constitution XV) — the ID moves, the semantic content of the decision does not.

## Description

T04 has two independent sub-tasks operating on two different files:

1. **T04.a — Append D012 to [`.orchestrator/DECISIONS.md`](../../../../../decisions.md)**: one new row documenting the M021-before-M019 reorder. Every pre-existing row (D001..D011) remains byte-identical.
2. **T04.b — Add Cross-Refs lines to AP-005..AP-009 in `ANTIPATTERNS.md`**: a new `**Cross-Refs**:` line added to each of the five Class B antipattern entries, naming the P03 hook (`scripts/hooks/pre-bash-shape-guard.sh`) as the enforcement layer and the P04 replay corpus (`tests/fixtures/m021-prompt-corpus.txt`) as the regression detection layer. AP-001..AP-004 are not modified.

Both sub-tasks are additive — no existing content is edited or removed. T05's structural gates assert the pre-existing content remains intact.

## Steps

### Step 1 (T04.a): Append D012 row to [`.orchestrator/DECISIONS.md`](../../../../../decisions.md)

Append the following single row to the end of the table (no trailing blank line after — match the existing file convention):

```
| D012 | Roadmap / pre-M019 (M021 reorder) | sequencing, scope | Insert M021 (Autonomous Hardening v2) before M019 and position M019 Tier 1 emitter only after M021 closes | Revised sequence: **M011 (closed) → M021 (active) → M019 Tier 1 emitter → M012 → M013 → M014 → M019 Tier 2+3 → M018 → M009 → M010**. M021 closes the residual Class B prompt triggers (12 shape patterns surviving M016's Class A hardening) identified in 20 M011/P05–P07 auto-mode screenshots via three layers: a three-wrapper catalog under `scripts/util/`, linter v2 (AP-005..AP-009 detectors + scope widening to task-PAYLOADs), and a PreToolUse shape-guard hook enforcing a closed 10-pattern rewrite/reject matrix. Ordered before M019 so observability metrics (time/tokens/$/quality) dogfood on a **zero-prompt baseline** rather than mixing cost measurements with interruption overhead — cleaner Tier 1 data from M012–M014 dogfooding, more defensible launch narrative. (ID note: this entry was anticipated as D010 in M021-ROADMAP.md and M021-CONTEXT.md on 2026-04-17; D010/D011 landed first, so this reorder decision is recorded as D012.) | Evidence-grounded: 20 M011/P05–P07 screenshots define the closed pattern matrix (AD-2, AD-5); no speculative additions (constitution XIV). M021 itself dogfoods via its own `orchestrator:auto` execution through P01–P04 (AD-8) — SC-7 attestation is produced by `scripts/verify/m021-p04-dogfood-attestation.sh` and the permanent replay corpus at `tests/fixtures/m021-prompt-corpus.txt`. Adding M021 ahead of M019 costs ~1 milestone of sequencing but eliminates the noise floor that would otherwise contaminate every subsequent metrics measurement — principle I (Context Minimization) applied to the measurement apparatus itself. | No — once the hook is live and the replay corpus is in CI, rolling back is a permission-only change in `.claude/settings.json` (disable the hook entry) but the corpus and AP-005..AP-009 entries stay as knowledge (constitution VII). |
```

This is a single line in the source file — DO NOT introduce a line break mid-row. GitHub-flavored markdown tables require each row on one line.

### Step 2 (T04.a): Verify D001..D011 are byte-identical after the edit

The only way to accidentally regress an earlier row is a stray edit during insertion. Before moving on, run `diff` mentally (or via a scratch copy) to confirm D001..D011 rows are unchanged. T05's `scripts/verify/m021-p04-decisions-d012.sh` gate asserts:

- D001..D011 headers still present in order.
- New D012 row present with the required substrings (`D012`, `sequencing`, `M019`, `zero-prompt`).
- Total row count grew by exactly 1 (from 11 data rows to 12).

### Step 3 (T04.b): Add `**Cross-Refs**` line to AP-005 through AP-009

For each of the five Class B entries (AP-005, AP-006, AP-007, AP-008, AP-009), locate the `**Remedy**:` block (the last structural section of each entry before the next `## AP-NNN:` heading or end-of-file). Append a new `**Cross-Refs**:` section immediately after the existing `**Remedy**` block with exactly this content, adjusted per-entry for the correct wrapper path and pattern-class label:

```
**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (P03 PreToolUse hook — this AP ID appears in the hook's reject-diagnostic text via `ANTIPATTERNS.md#AP-00X` pointer).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (P04 replay fixture — one or more verbatim screenshot entries exercise this pattern-class via `EXPECTED_OUTCOME: reject:<class>` or `rewrite:<result>`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (P03 shared shape-classifier library — the `classify_command` function emits the pattern-class label this AP ID documents).
```

Per-entry pattern-class values (for mental substitution of `<class>` in the middle bullet):

- AP-005 (simple-expansion / trailing-rc-echo rewrite class)
- AP-006 (command-substitution in redirect targets / redirect-cmd-sub rewrite class)
- AP-007 (braces inside quoted strings / quoted-brace reject class)
- AP-008 (heredoc + variable expansion / heredoc-with-expansion reject class + cat-heredoc-exec rewrite class)
- AP-009 (task-PAYLOAD compound / compound-chain-gt2 + nested-cmd-sub reject classes)

The structured per-entry label enrichment is nice-to-have — the structural gate (T05) only asserts that both `scripts/hooks/pre-bash-shape-guard.sh` and `tests/fixtures/m021-prompt-corpus.txt` appear at least once under each AP-005..AP-009 section. If the three-bullet pattern above is followed verbatim for all five entries, the gate passes trivially.

### Step 4 (T04.b): Do not modify AP-001..AP-004

AP-001..AP-004 predate M021. They do not get Cross-Refs lines. T05's `scripts/verify/m021-p04-antipatterns-crossrefs.sh` gate asserts AP-001..AP-004 headings are unchanged byte-for-byte.

### Step 5: Neither file grows beyond its envelope

After the edits:

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) grows by exactly 1 line (one table row).
- `ANTIPATTERNS.md` grows by approximately 5 × 4 = 20 lines (5 entries × ~4 lines of Cross-Refs content each). Envelope: ≥5, ≤40 new lines.

## Must-Haves

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) contains a new D012 row with required substrings: `D012`, `sequencing`, `M019`, `zero-prompt`.
- D001..D011 rows remain byte-identical.
- `ANTIPATTERNS.md` contains a Cross-Refs block under each of AP-005, AP-006, AP-007, AP-008, AP-009 naming both `scripts/hooks/pre-bash-shape-guard.sh` and `tests/fixtures/m021-prompt-corpus.txt`.
- AP-001..AP-004 entries remain structurally unchanged (headings and body text intact).
- Neither file grows beyond its envelope (DECISIONS: +1 line; ANTIPATTERNS: +5 to +40 lines).
- Both files remain valid markdown (table structure intact, heading structure intact).

## Verification

- `bash scripts/verify/m021-p04-decisions-d012.sh` (T05) exits 0.
- `bash scripts/verify/m021-p04-antipatterns-crossrefs.sh` (T05) exits 0.
- `bash scripts/verify/run-suite.sh m021 P04` includes both gates among its reported PASS entries.
- Repo-wide lint passes: `bash scripts/verify/anti-pattern-lint.sh` exits 0 (neither file introduces a forbidden shape — they contain illustrative content inside markdown prose, not agent-facing bash).

## Inputs

### From Previous Tasks

- `tests/fixtures/m021-prompt-corpus.txt` (from T01) — path referenced verbatim in each AP-005..AP-009 Cross-Refs block.

### From Disk (Pre-existing)

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — 11 data rows (D001..D011); T04 appends D012.
- `ANTIPATTERNS.md` — 9 entries (AP-001..AP-009); T04 adds Cross-Refs to AP-005..AP-009.
- `scripts/hooks/pre-bash-shape-guard.sh` — P03 hook; path referenced in Cross-Refs.
- `scripts/verify/lib/shape-classifier.sh` — P03 classifier library; path referenced in Cross-Refs.

## Constraints

- **Append-only for DECISIONS.md**: no existing row is edited, reordered, or deleted. Only D012 is added.
- **Additive for ANTIPATTERNS.md**: Cross-Refs blocks are inserted after the existing Remedy blocks on AP-005..AP-009 only. AP-001..AP-004 are not touched.
- **Markdown table integrity**: D012 row is a single physical line with the correct pipe-delimited column count matching the existing table header.
- **No content escape**: text inside the rationale column must not contain unescaped pipe characters that would break the table parse. Use `\|` for any literal pipes needed in prose (the provided row above uses none).
- **No new AP-### entry**: T04 does NOT introduce AP-010 or higher. The cross-ref pass is pure annotation. Future antipatterns earn new AP-### IDs via the AD-11 append-only discipline — separate milestone scope.
- **Spec fidelity**: the D012 entry's Rationale column explicitly names the anticipated `D010` slot from M021-ROADMAP.md for audit-trail continuity.

## Expected Output

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — 12 data rows (D001..D012); file size grows by approximately 1 line's worth of content.
- `ANTIPATTERNS.md` — 9 entries unchanged in identity; AP-005..AP-009 each have a new Cross-Refs block; file size grows by ~20 lines.
- `bash scripts/verify/m021-p04-decisions-d012.sh` (T05) exits 0 with PASS output.
- `bash scripts/verify/m021-p04-antipatterns-crossrefs.sh` (T05) exits 0 with PASS output.
- `bash scripts/verify/anti-pattern-lint.sh` continues to exit 0 over the repo.
