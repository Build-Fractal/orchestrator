---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M037"
name: "DR-### heading-shape pivot for this repo + shape-lint verifier"
depends_on: []
---

## Prerequisites

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) exists (verified at plan-authoring time, 33 lines containing 28 row entries — see Notes for the actual scope clarification).

## Description

Restructures [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) from a 7-column markdown table to `### Title { #dr-code-nnn }` heading entries with a code-chip body markup, preserving every legacy `#dr-code-nnn` permalink anchor via `attr_list`. Authors a framework-owned `scripts/verify/decisions-shape-lint.sh` that enforces the new shape (per #Q-7 resolution). Authors `tests/m037-acceptance/p01-dr-heading-shape.sh` invoking the lint plus a permalink-resolution check across cross-referencing files in the repo.

**Scope note**: the operator's pre-resolved brief described "~150 row entries" in DECISIONS.md. The actual file at plan-authoring time is 33 physical lines containing 28 markdown-table rows (D001–D028). This task restructures all 28 rows; the migration shape and the verifier contract are unchanged from the brief. The smaller scope means less manual restructuring work — closer to a half-day than a full day.

## Steps

1. **Read [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) in full**. The current shape is a markdown table:

   ```
   | # | When | Scope | Decision | Choice | Rationale | Revisable? |
   |---|------|-------|----------|--------|-----------|------------|
   | D001 | M004/P03 | scope | Roadmap reassessment ... | ... | ... | No |
   | D002 | ... |
   ```

   Each `| Dnnn |` line is one entry. The legacy permalink anchor was auto-derived by mkdocs-material from the row content's `D001`-style code (verified by grep across repo for `#d001`-shaped fragments).

2. **Restructure to heading-shape entries**. The new shape per row:

   ```markdown
   ### <Decision title — short, scannable> { #dr-code-nnn }

   <span class="md-tag md-tag-icon md-tag--decision">DR-CODE-NNN</span>
   {: .code-chip-row }

   - **When**: M004/P03
   - **Scope**: scope
   - **Choice**: <one-line choice summary>
   - **Revisable**: No

   <Rationale paragraph(s) — long-form explanatory text from the original Rationale column.>

   ---
   ```

   Rules:
   - The heading text is the human-readable concept (the original "Decision" column condensed to a scannable phrase).
   - The `{ #dr-code-nnn }` anchor MUST preserve the legacy permalink format. Migration mapping: `D001` → `#dr-code-001`, `D002` → `#dr-code-002`, etc. (the `dr-code-` prefix is the convention; the trailing zero-padded number matches the original `Dnnn` numeric suffix).
   - The body chip markup uses `<span>` + `attr_list` block-level class — both already enabled in `wiki/mkdocs.yml`. The chip renders as a small permalink-style suffix below the heading.
   - The original `Choice` and `Rationale` columns become bulleted metadata + a free-form paragraph.
   - Each entry is separated by a horizontal rule `---` for visual scannability in the rendered TOC.

3. **Audit all inbound permalink references**. Run `grep -RnE '#d(r-code-)?[0-9]+' --include='*.md' .` across the repo to find every cross-referencing file. For each match:
   - If it cites `#d001`-shape: rewrite to `#dr-code-001`.
   - If it cites `#dr-code-001`-shape (already-correct): leave byte-identical.
   - Files likely to contain matches: `specs/**/*.md`, `.orchestrator/milestones/M*/M*-ROADMAP.md`, `.orchestrator/milestones/M*/phases/**/*.md`, `.orchestrator/proposals/**/*.md`, `references/**/*.md`, `wiki/docs/**/*.md`.

4. **Author `scripts/verify/decisions-shape-lint.sh`** (framework-owned per #Q-7 resolution; ships in install bundle). Single-script-file shape per AD-19. The script:
   - Accepts a single argument: path to a DECISIONS.md file (defaults to [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) in CWD).
   - Reads the file line-by-line.
   - For each `### ` heading line: asserts the line matches the regex `^### .+ \{ #(dr|bg|an|mem|q)-[a-z0-9-]+ \}$`. On miss: emit `FAIL: <path>:<lineno>: heading does not match required shape: <line>` and exit 1.
   - For each line matching the legacy table-row shape (`^| D[0-9]+ |`): emit `FAIL: <path>:<lineno>: legacy 7-column-table row remains: <line>` and exit 1.
   - For each `{ #<anchor> }` extracted from a heading: assert `<anchor>` is unique within the file (no duplicate permalinks).
   - On success: print `PASS: decisions-shape-lint <path> (N entries, all anchors unique)` and exit 0.

5. **Author `tools/verify/m037-p01-decisions-shape.sh`** wrapper that invokes the framework verifier against this repo's DECISIONS.md (the Truth #4 Check command in the phase plan invokes `scripts/verify/decisions-shape-lint.sh` directly — this wrapper is a sibling for the phase-suite aggregator's convenience).

6. **Author `tests/m037-acceptance/p01-dr-heading-shape.sh`** (acceptance test, SC-3). The test:
   - Invokes `bash scripts/verify/decisions-shape-lint.sh [.orchestrator/DECISIONS.md](../../../../../decisions.md)` and asserts exit 0.
   - Greps the repo for inbound `#d`-shaped fragment references (excluding files inside `.orchestrator/milestones/M037/`).
   - For each match: asserts the cited anchor exists in DECISIONS.md as a `{ #<anchor> }` declaration. On miss: fails with `FAIL: broken inbound permalink <file>:<lineno> -> <anchor>`.
   - On full pass: emits `PASS: p01-dr-heading-shape (N entries, M inbound permalinks resolved)`.

## Must-Haves

- Truth #4 (DECISIONS.md matches new heading-shape regex; legacy permalinks resolve).
- Phase artifacts: `scripts/verify/decisions-shape-lint.sh` (min 20 lines, contains "{ #"), `tests/m037-acceptance/p01-dr-heading-shape.sh` (min 20 lines).
- SC-3 acceptance test passes.

## Verification

```bash
bash scripts/verify/decisions-shape-lint.sh .orchestrator/DECISIONS.md
bash tests/m037-acceptance/p01-dr-heading-shape.sh
```

## Notes

- Expected output of `scripts/verify/decisions-shape-lint.sh`: `PASS: decisions-shape-lint [.orchestrator/DECISIONS.md](../../../../../decisions.md) (28 entries, all anchors unique)`.
- Expected output of `tests/m037-acceptance/p01-dr-heading-shape.sh`: a final line `PASS: p01-dr-heading-shape (28 entries, M inbound permalinks resolved)` where M is the count of inbound references found by grep.
- This task is intentionally restructure-now (operator confirmed Option 1 in the brief). Consumer-project rollout strategy (one-shot rewriter for PBJ-central, lakeledger, etc.) is **NOT** P01 scope per #Q-3 (a) resolution.
- The 28-entry actual scope is smaller than the brief's "~150" estimate — surface this in `T03-SUMMARY.md` as a planning-vs-actual delta if it affects time estimation.

## Inputs

### From Previous Tasks

(none)

### From Disk (Pre-existing)

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — restructured in place. 28 row entries become 28 `### Title { #dr-code-nnn }` heading blocks.
- Cross-referencing files across `specs/`, `.orchestrator/milestones/`, `.orchestrator/proposals/`, `references/`, `wiki/docs/` — read+modify for permalink-form normalization (`#d001` → `#dr-code-001` rewrite).
- `wiki/mkdocs.yml` — read-only; verifies `attr_list` and `md_in_html` are already enabled in `markdown_extensions:` (confirmed at plan-authoring time, lines 38-44).

## Constraints

- **CON-1 — Zero new mkdocs plugin dependencies**: `attr_list` is already enabled (line 40 of `wiki/mkdocs.yml`). The body-chip markup uses standard `<span>` + class — no new plugin.
- **CON-2 — Projection-not-source-mutation does not apply here**: DECISIONS.md is operator-authored content, not source-chunk projection. This task is content migration, not a projection-layer change.
- **AD-19 — Verifier shape**: `scripts/verify/decisions-shape-lint.sh` is a framework-owned single-script-file verifier. No subshells, no `$()` containing pipes.
- **MEM001 — bash 3.2 + POSIX sh** in the verifier.
- **Permalink stability is HARD**: every `#dr-code-nnn` anchor cited from external files MUST resolve in the migrated file. The acceptance test's permalink-resolution loop is the gate.

## Expected Output

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) restructured: zero rows match `^| D[0-9]+ |`; every `### ` heading matches `^### .+ \{ #(dr|bg|an|mem|q)-[a-z0-9-]+ \}$`; every legacy `#dr-code-nnn` permalink target preserved.
- All inbound `#d`-shaped permalink references in the repo normalized to the new `#dr-code-nnn` form (where applicable).
- `scripts/verify/decisions-shape-lint.sh` exists, ≥ 20 lines, contains `{ #`, exits 0 against the migrated DECISIONS.md.
- `tools/verify/m037-p01-decisions-shape.sh` exists as a phase-suite-callable wrapper.
- `tests/m037-acceptance/p01-dr-heading-shape.sh` exits 0.
