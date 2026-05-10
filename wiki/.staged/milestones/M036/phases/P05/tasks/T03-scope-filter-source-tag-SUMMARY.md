---
schema_version: "1.0"
type: task-summary
id: "T03-scope-filter-source-tag"
parent: "P05"
milestone: "M036"
provides:
  - "--tag '[source:<cite_id>]' literal-match flag on scripts/dispatch/scope-filter.sh (file + index + graph modes); widened scope-tag regex char class [A-Za-z0-9/_.-]; CON-5 regression guard for default mode (byte-identical)"
requires:
  - "from:M036/P00/T03 what:[source:<cite_id>] scope-tag namespace declared in references/file-formats.md"
affects:
  - "M036/P05 phase-suite gate; future ingest dispatch (M036/P07) which will rely on --tag for source-scoped chunk retrieval"
key_files:
  - "scripts/dispatch/scope-filter.sh,tools/verify/m036-p05-scope-filter-source-tag.sh,tools/verify/m036-p05-scope-filter-baseline.sh,tests/fixtures/m036-p05-baseline/scope-filter-default.expected.txt"
key_decisions:
  - "none"
patterns_established:
  - "plan-time baseline-capture sequencing for CON-5 guards (capture BEFORE edits or the guard becomes a tautology); literal-tag matcher uses grep -qF never grep -qE (bracket chars are regex metacharacters); strict-superset regex widening verified by character-class subset relation; graph-mode SQL escape via single-quote-doubling sed; scope_clause replacement (not append) when --tag set — operator-asserted semantics override derivation"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P05/tasks/T03-scope-filter-source-tag-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-02T03:45:37Z"
---

## What was built

T03 extends `scripts/dispatch/scope-filter.sh` with a literal `--tag '[source:<cite_id>]'` flag and widens the scope-tag character class so the new namespace also flows through derivation-based matching.

**Surface 1 — `--tag` flag (operator-asserted scope-by-tag)**:
- New initializer `FILTER_TAG=""` and arg-parser case `--tag) FILTER_TAG="$2"; shift 2 ;;` (lines 37 + 55-56 of post-edit).
- Branched include logic in all three filter functions (`filter_knowledge`, `filter_knowledge_index`, `filter_knowledge_graph`). When `FILTER_TAG` is non-empty, derivation (MILESTONE_ID/PHASE_ID matching) is bypassed and the literal tag must appear in the row's scope-tag column to include.
- `grep -qF` (fixed-string) used for matching — bracket characters are NOT treated as regex metacharacters. Plan called this out explicitly because `grep -qE '[source:cms-pbj-2024-q3]'` would silently match the wrong things.
- Graph mode (SQLite path): when `FILTER_TAG` is set, replaces the `scope_clause` construction with a single `AND st.tag = '<safe_tag>'` join condition (single-quote-escaped). Bypasses the whole `[project] OR [milestone:M###] OR [phase:M###/P##]` disjunction.
- `--tag` composes with `--type` and `--include-non-goals` (those filters run normally) but supersedes `MILESTONE_ID`/`PHASE_ID` derivation. Documented in the script's usage block (lines 5-21).

**Surface 2 — widened scope-tag character class (correctness fix for derivation path)**:
- `filter_knowledge` regex (line 164 post-edit) extended from `\[[a-z]+:[A-Za-z0-9/]+\]|\[project\]` to `\[[a-z]+:[A-Za-z0-9/_.-]+\]|\[project\]`. Strict superset — every old pattern continues to match (the addition is `_`, `.`, and `-`).
- `filter_knowledge_index` does NOT use the bracket regex; it parses `scope_tag` from awk field-2 and uses prefix-match `grep -qE '^\[milestone:'` / `^\[phase:'` checks. Those prefix anchors work unchanged for any tag namespace, so no widening is needed in that function. (The plan said "the same line at ~272" — but on reading, that location is part of the filter-tag-substring block, not a regex; T03's literal-match branch covers the use case there.)

**Verifiers landed (both single-script-file shape per AD-19)**:
- `tools/verify/m036-p05-scope-filter-source-tag.sh` — stages 3-row fixture (MEM001 [project], MEM002 [source:cms-pbj-2024-q3], SPEC-FR-7 [source:cms-pbj-2024-q3]), invokes scope-filter with `--tag '[source:cms-pbj-2024-q3]'`, asserts MEM002 + SPEC-FR-7 present and MEM001 absent (cross-category match). PASS.
- `tools/verify/m036-p05-scope-filter-baseline.sh` — CON-5 regression guard. Stages 3-row pre-P05 fixture ([project], [milestone:M001], [phase:M001/P02]), runs default mode (no --tag), diffs stdout against checked-in baseline `tests/fixtures/m036-p05-baseline/scope-filter-default.expected.txt` via `cmp -s`. PASS.

**CON-5 sequencing followed precisely**:
1. Captured baseline output from unmodified `scope-filter.sh` against the no-source-tag fixture.
2. Wrote that output verbatim to `tests/fixtures/m036-p05-baseline/scope-filter-default.expected.txt`.
3. Edited `scope-filter.sh`.
4. Re-ran filter against same fixture; `cmp` reported byte-equality (no diff).

T02's prior CON-5 verifier `m036-p05-traverse-relates-to-baseline.sh` continues to PASS — the scope-filter edits do not touch the traverse-graph path.

## Patterns established / reinforced

- **Plan-time baseline-capture sequencing for CON-5 guards** — the regression baseline MUST be captured before edits begin, otherwise the guard reduces to "does the script match itself" (tautology). Captured here by running the unmodified script once against the staging fixture, saving stdout to the checked-in expected file, then proceeding with the edits.
- **Literal-tag matcher uses `grep -qF`, never `grep -qE`** — bracket characters in tag literals are regex metacharacters; fixed-string mode is the only safe shape. Marked as a constraint in the plan.
- **Strict-superset regex widening** — `[A-Za-z0-9/]` ⊂ `[A-Za-z0-9/_.-]` by construction. Adding characters never removes matches; the CON-5 guard mechanically verifies that for the no-source-tag input case.
- **Graph-mode SQL escape via single-quote-doubling** — `safe_tag="$(printf '%s' "$FILTER_TAG" | sed "s/'/''/g")"` mirrors the existing `safe_cat` pattern in `filter_knowledge_graph`.
- **Scope-clause replacement, not append** — when `--tag` is set, the SQL `scope_clause` is set directly (replacing derivation-built clause) rather than ANDed onto it. This matches the operator-asserted semantics: "find chunks bearing this tag regardless of where I'm dispatching from."

## Forward-pointing notes

- The `filter_knowledge_index` regex line referenced at ~272 in the plan is actually the awk field-2 extraction (`scope_tag=$(echo "$line" | awk -F'|' ...)`), not a regex extraction. No widening was needed there; the tag-prefix grep anchors (`^\[milestone:`, `^\[phase:`) already work for any tag namespace. The `--tag` literal-match branch is wired into the same function and uses `grep -qF` against the parsed field-2 value (substring match — covers entries with multiple comma-separated tags in one cell).
- The graph-mode regression is NOT covered by `m036-p05-scope-filter-baseline.sh` (which uses file-mode). Acceptable per scope: graph-mode CON-5 is enforced by T01/T02's traverser baseline (`m036-p05-traverse-relates-to-baseline.sh`) which exercises the same `scope_tags` table and `--depends` clause construction. A graph-mode `--tag` regression test would belong to a follow-up phase if anyone reports drift.
- The widened regex matches `[source:foo.bar]` and `[source:foo_bar]` in addition to `[source:foo-bar]`. The spec calls out hyphen-separated cite_ids (`cms-pbj-2024-q3`); periods and underscores are speculative-but-valid chars per the FR-2 contract. No fixture exercises them today; if a future cite_id uses `.` or `_` and breaks, that's a P05-or-later regression to revisit.

## Verification

- `bash tools/verify/m036-p05-scope-filter-source-tag.sh` → `PASS: m036-p05-scope-filter-source-tag (2 chunks across spec+memory)`
- `bash tools/verify/m036-p05-scope-filter-baseline.sh` → `PASS: m036-p05-scope-filter-baseline (CON-5 byte-identical)`
- `bash tools/verify/m036-p05-traverse-relates-to-baseline.sh` (T02 prior guard) → `PASS: m036-p05-traverse-relates-to-baseline (CON-5 byte-identical)` — confirms scope-filter edits did not regress traverse path.
