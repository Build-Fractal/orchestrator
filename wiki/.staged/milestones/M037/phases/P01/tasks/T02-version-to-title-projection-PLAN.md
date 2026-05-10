---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M037"
name: "Stub version: → title: projection + Typeset evaluation gate + nav generator pass-through"
depends_on: []
---

## Prerequisites

- `scripts/wiki/wiki-generate-stubs.sh` exists (verified at plan-authoring time).
- `scripts/wiki/wiki-generate-nav.sh` exists (verified at plan-authoring time).
- M036a chunk corpus carries `version:` frontmatter on Tier 0/1/2 chunks (closed 2026-05-02 per CLAUDE.md; FR-5 / FR-12 / FR-13 read these at projection time per A2 in spec).

## Description

Lands FR-5 + FR-6 + the US-2 AS-5 Typeset-evaluation gate. The pre-condition gate (≤ 1 hour, time-boxed) evaluates Material's built-in `Typeset` plugin to confirm it does NOT subsume FR-5 — Typeset operates on heading-text formatting in nav/TOC, not on frontmatter-field projection. Default expectation: gate falls through, FR-5 ships as planned. Gate outcome recorded in the task SUMMARY at execution time.

Implementation: extends `scripts/wiki/wiki-generate-stubs.sh` with a `derive_stub_title` step that reads each source chunk's frontmatter `version:` field and emits the stub's frontmatter `title:` to that value. When `version:` is absent, falls back to the chunk-id slug as `title:` and emits a debug-level diagnostic. **Conditional-overwrite (MIT-01 P0)**: when an existing stub on disk carries `auto_generated: false` in its frontmatter, the generator MUST NOT overwrite that stub's `title:` (operator escape hatch).

Modifies `scripts/wiki/wiki-generate-nav.sh` to honor stub `title:` if it does not already; verification at execution time discovers actual current behavior. The fix is small if the script reads frontmatter; larger only if the script currently derives nav titles from filename slugs alone.

## Steps

1. **Typeset evaluation gate (≤ 1 hour, time-boxed) [executor pre-condition]**. Read Material's `Typeset` plugin documentation (https://squidfunk.github.io/mkdocs-material/plugins/typeset/) and confirm it operates on rendered heading-text formatting (preserves `<code>`, `<em>`, etc. in nav/TOC) and NOT on frontmatter-field-to-nav-title projection. Record outcome in task SUMMARY:
   - **Likely outcome (default expectation)**: Typeset does NOT subsume FR-5. Proceed to step 2 with full FR-5 scope.
   - **Unlikely outcome**: Typeset DOES subsume FR-5 for our use case. Scope down to a 1-line plugin enable in `wiki/mkdocs.yml` (`plugins: - typeset`) plus the MIT-01 `auto_generated: false` idempotency test. Update SUMMARY with the scope reduction rationale.

2. **Extend `scripts/wiki/wiki-generate-stubs.sh` with `derive_stub_title`**. The step:
   - Reads each source chunk's frontmatter `version:` field via the existing frontmatter-parsing pattern in the script (likely a `read_frontmatter_field` helper or inline awk/sed). On absent: fall back to the chunk-id slug as `title:` and emit a debug-level message (write to stderr only when `WIKI_DEBUG=1` env var is set, or use the existing diagnostic helper if one exists in the script).
   - On stub-write path: BEFORE overwriting an existing stub at `wiki/docs/<path>.md`, read the existing stub's frontmatter for `auto_generated:`. When it equals literal `false`, skip overwrite of the entire stub (operator escape hatch — MIT-01 P0). When it equals `true` or is absent, proceed with the re-derive.
   - Quote `version:` values that contain markdown-active characters (backticks, brackets, double quotes) using YAML double-quote escaping (`"<value>"` with `\"` for embedded double quotes) so the rendered nav YAML preserves them byte-identical (Edge Case in spec).

3. **Modify `scripts/wiki/wiki-generate-nav.sh` to honor stub `title:`**. Read the script's current nav-rendering logic (likely a per-stub iteration that emits a YAML line per entry). The change: when a stub frontmatter carries `title:`, use that value; otherwise fall back to the existing default (filename-slug or `version:`-from-source). If the script already does this, no change required — the verifier confirms.

4. **Author `tests/fixtures/m037-version-projection/` corpus**. Four-fixture corpus for SC-2 (FR-5 + MIT-02 P0 escape-hatch fixture):
   - `chunk-a.md` — frontmatter `version: "Human Label A"`, expects stub `title: "Human Label A"`.
   - `chunk-b.md` — frontmatter `version: "QSO-21-06-NH (December 4, 2020)"`, expects stub `title: "QSO-21-06-NH (December 4, 2020)"` (markdown-active characters preserved via YAML quoting).
   - `chunk-c.md` — no `version:` field, expects stub `title:` to fall back to chunk-id slug.
   - **Pre-existing `wiki/docs/.../existing-stub.md`** with frontmatter `auto_generated: false` and an operator-edited `title: "Operator Custom Title"`. Expects the generator to preserve byte-identical across re-runs. (MIT-02 P0 fixture.)

5. **Author `tools/verify/m037-p01-version-to-title.sh`** (Truth #2 verifier). Asserts the stub generator script contains `version:` reading logic + `title:` writing logic (regex match against function name or comment marker). Single-script-file shape.

6. **Author `tools/verify/m037-p01-auto-generated-escape-hatch.sh`** (Truth #3 verifier). Asserts the stub generator script contains an `auto_generated:` branch (regex `auto_generated[ ]*:[ ]*false` in the script) AND that the script's overwrite path is gated on this branch.

7. **Author `tests/m037-acceptance/p01-version-to-nav-title.sh`** (acceptance test, SC-2). Stages the four-fixture corpus into a temp dir, invokes the stub generator against the fixture, asserts each emitted stub's `title:` field matches the expected value, and on the MIT-02 fixture asserts the operator-edited title survives byte-identical across two consecutive runs of the generator.

## Must-Haves

- Truth #2 (stub generator reads `version:` and emits `title:`).
- Truth #3 (stub generator preserves `auto_generated: false` operator escape hatch).
- Phase artifact: `tests/m037-acceptance/p01-version-to-nav-title.sh` (min 30 lines, contains "auto_generated: false").
- SC-2 acceptance test passes against all four fixture cases.

## Verification

```bash
bash tools/verify/m037-p01-version-to-title.sh
bash tools/verify/m037-p01-auto-generated-escape-hatch.sh
bash tests/m037-acceptance/p01-version-to-nav-title.sh
```

## Notes

- Expected output of `tools/verify/m037-p01-version-to-title.sh`: `PASS: m037-p01-version-to-title`.
- Expected output of `tools/verify/m037-p01-auto-generated-escape-hatch.sh`: `PASS: m037-p01-auto-generated-escape-hatch`.
- Expected output of `tests/m037-acceptance/p01-version-to-nav-title.sh`: `PASS: p01-version-to-nav-title (4/4 fixtures)`.
- The Typeset evaluation gate outcome MUST be recorded in `T02-version-to-title-projection-SUMMARY.md` under a `## Typeset Evaluation Gate Outcome` section before phase close.
- If the gate finds Typeset subsumes FR-5 and you scope down: only step 1's `mkdocs.yml plugins: - typeset` and the MIT-01 escape-hatch test from step 7 are required. Steps 2-6 collapse into a doc-only artifact in the SUMMARY.

## Inputs

### From Previous Tasks

(none — T02 has no upstream task dependencies)

### From Disk (Pre-existing)

- `scripts/wiki/wiki-generate-stubs.sh` — extended with `derive_stub_title` step. Existing [M032](../../../../../milestones/M032/index.md) functions (read frontmatter, emit stub) remain callable; `derive_stub_title` is a new pre-emit step.
- `scripts/wiki/wiki-generate-nav.sh` — read-only at first; verifier confirms whether it already honors stub `title:`. If not: minimal modification to add a `title:` lookup ahead of the filename-slug fallback.
- M036a chunk corpus under `references/` and any project's `knowledge/reference/<category>/REF-*.md` — read-only; provides the source `version:` frontmatter.
- `wiki/mkdocs.yml` — read-only unless gate-step-1 finds Typeset subsumes FR-5 (in which case `plugins:` block grows by one line).

## Constraints

- **CON-1 — Zero new mkdocs plugin dependencies**: even on the unlikely Typeset path, Material's built-in plugins do not require a `requirements.txt` change (Typeset ships with mkdocs-material core). No external pip package.
- **CON-2 — Projection-not-source-mutation**: source chunks remain authoritative. `derive_stub_title` reads `version:` and writes `title:` only to the projected stub at `wiki/docs/<path>.md`, never back to the source.
- **MIT-01 P0 — Conditional-overwrite escape hatch**: HARD CONTRACT. Skipping the `auto_generated: false` branch on stub-overwrite is a P0 bug. SC-2's MIT-02 fixture exercises this; the Truth #3 verifier confirms presence statically.
- **MEM001 — bash 3.2 + POSIX sh**: no process substitution, no `$()`-containing-pipes, no associative arrays.
- **AD-19 — Verifier shape**: single-script-file invocations under `tools/verify/m037-p01-*.sh`.

## Expected Output

- `scripts/wiki/wiki-generate-stubs.sh` extended with `derive_stub_title` step + `auto_generated: false` overwrite gate.
- `scripts/wiki/wiki-generate-nav.sh` either already honors stub `title:` (no change) or extended to honor it.
- `tests/fixtures/m037-version-projection/` corpus with four chunks (a, b, c + escape-hatch fixture).
- `tools/verify/m037-p01-version-to-title.sh` exits 0.
- `tools/verify/m037-p01-auto-generated-escape-hatch.sh` exits 0.
- `tests/m037-acceptance/p01-version-to-nav-title.sh` exits 0 with all four fixtures passing.
- `T02-version-to-title-projection-SUMMARY.md` contains a `## Typeset Evaluation Gate Outcome` section with the gate result.
