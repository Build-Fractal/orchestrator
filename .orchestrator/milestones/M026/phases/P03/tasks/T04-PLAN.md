---
schema_version: "1.0"
task: "T04"
phase: "P03"
milestone: "M026"
name: "DECISIONS.md D-row + CHANGELOG.md migration entry (DC-2)"
depends_on: []
---

## Prerequisites

- `.orchestrator/DECISIONS.md` exists. Last existing row is **D021** (recorded 2026-04-24, the bbt-companion hotfix batch). T04 adds **D022**.
- `CHANGELOG.md` exists at the repo root. Current version heading is **v0.9.1** (per CLAUDE.md project status).
- Roadmap §P03 Boundary Map and DC-2 specify: "new D-row in `.orchestrator/DECISIONS.md` naming the edition-resolution pattern" and "`CHANGELOG.md` entry under the current version heading".

## Description

Two artifacts:

1. **DECISIONS.md row D022** — captures the M026 edition-resolution + paid-escape-hatch decision in the canonical When/Scope/Decision/Choice/Rationale/Revisable shape. Cross-references MEM029 (pattern) and MEM030 (convention) graduated by T03 so the graduated knowledge is discoverable from the decision audit trail.

2. **CHANGELOG.md entry** under the current `v0.9.1` heading — one bullet describing the M026 migration shipping (resolver flip, env-var escape hatch, JSONL edition field, paid-only-preset diagnostic, doc updates).

T04 also creates the verifier `scripts/verify/m026-p03-decision-row.sh`.

## Steps

1. **Read the tail of `.orchestrator/DECISIONS.md`** to confirm the last row ID and the table format:

   ```sh
   tail -3 .orchestrator/DECISIONS.md
   ```

   Confirm last row begins `| D021 |`. Note the column order: `# | When | Scope | Decision | Choice | Rationale | Revisable?`.

2. **Append D022 to `.orchestrator/DECISIONS.md`**. The table is single-row-per-line markdown (very long lines — see D008 / D016 / D017 / D021 for shape). Append the following row after D021:

   ```
   | D022 | M026/P03 (2026-04-24) | scope, contract, knowledge | Edition-resolution two-tier detection (env-var primary + metadata-probe fallback) committed as the orchestrator's canonical pattern for runtime edition identification under single-venv reality; `<TOOL>_EDITION=<value>` committed as the paid-escape-hatch env-var convention; `edition_required: <edition>` committed as the preset-frontmatter contract for adapter-side refusal; CHANGELOG.md updated to record the M026 conversus-OSS migration. | (1) Adapter `_resolve_edition` (M026/P02/T01, `scripts/dispatch/adapters/tool/conversus.sh:132-179`) is the canonical implementation: env-var primary with `oss\|paid` closed enum (stderr warning + fall-through on bad values), metadata-probe fallback via `pip show conversus` `Home-page:` parsing, short-circuit `edition=unknown reason=stub` under stub mode. Output contract: `edition=` + `reason=` lines on stdout in stable order, warnings on stderr (DC-5). (2) `<TOOL>_EDITION=<value>` env-var name is reserved as the convention for any future OSS-default-with-paid-escape-hatch tool integration in this repo (graduated as MEM030, `knowledge/conventions/MEM030.md`). The paired two-tier-detection pattern is graduated as MEM029 (`knowledge/patterns/MEM029.md`). (3) Preset frontmatter `edition_required: paid` (M026/P03/T01, `scripts/dispatch/adapters/tool/conversus.sh` `_read_preset_edition_required`) refuses paid-only presets on OSS-resolved binaries before any `conversus run` invocation; diagnostic on stderr matches case-insensitive regex `paid-only.*CONVERSUS_EDITION=paid` (SC-7). Diagnostic uses `FAIL:` prefix per the adapter's `_emit_fail` convention rather than the FR-11 literal `ERROR:` opener — body content satisfies the SC-7 regex regardless. (4) CHANGELOG.md records the migration under v0.9.1 heading. (5) Cross-cuts: M013/P04 observability shape unchanged (additive `edition` field per AD-4 adjacency rule); spec-026 M014 shell-impl Pass 3 wiring is the next consumer that may exercise the new resolver under a fresh-install code path. | The decision is the consolidation point for three load-bearing M026 commitments that downstream milestones (M013, M014, M018, M023, M024) need a single auditable reference for. Rather than scattering the rationale across three MEM entries and the M026-SUMMARY (not yet authored), the D-row anchors the cross-references in the existing DECISIONS audit trail. The two-tier detection pattern is reusable beyond conversus (any pip/pipx-installed Python tool with multi-channel publishing); naming the convention now means the next adapter migration can adopt the shape without re-deliberating env-var naming. The `edition_required:` preset-frontmatter contract was deferred to OQ-3 at spec-027 discuss-finalize and chose the minimum-viable shape (single optional field, no auto-detect of CLI-flag-based paid-only signals per NG-6) — D022 commits the decision in the audit trail so future scope-expansion conversations have the rationale in hand. The `FAIL:`-vs-`ERROR:` prefix uniformity rationale lives here because it is a one-line decision (preserve adapter convention; SC-7 regex accommodates) that does not warrant its own MEM entry. | Yes — (a) if a future tool integration prefers a different env-var shape (e.g., `<TOOL>_TIER` instead of `<TOOL>_EDITION` for non-edition distinctions like community/enterprise), MEM030's convention can be amended via a new D-row noting the broadening. (b) The `edition_required:` minimum-viable shape can be extended (e.g., add `edition_required: paid_or_higher` for tier-ordered semantics) without reopening this D-row — adding a new value to the closed enum is a forward-compatible change. (c) If the `FAIL:`-vs-`ERROR:` prefix uniformity becomes a runbook friction (e.g., operators searching logs for `ERROR:` miss the diagnostic), revisit by either (i) tweaking `_emit_fail` to accept an optional severity-prefix argument, or (ii) adding a one-line ERROR: pre-line before the FAIL: line for SC-7 grep-matchers. |
   ```

   Notes:
   - Long lines: emulate D016 / D017 / D021 — single-line table rows, no soft-wrap, no escaping pipes (the body uses `\|` once for `oss\|paid`; the table renderer treats this correctly).
   - Add a leading blank line before the row only if the immediate predecessor row does not already provide separation (D021 ends with the `e23599d` parenthetical and a blank line — append D022 with no extra blank line).

3. **Append a CHANGELOG.md entry** under the v0.9.1 heading. Read the existing CHANGELOG.md to find the v0.9.1 heading shape:

   ```sh
   grep -n '^## ' CHANGELOG.md | head -5
   ```

   Insert under the v0.9.1 heading (or the current unreleased heading, whichever is the active one):

   ```markdown
   - **M026 (conversus-OSS migration)**: orchestrator's default Conversus integration flipped from paid (`~/Sites/conversus`) to OSS (`~/Sites/conversus-oss`). New `CONVERSUS_EDITION=oss|paid` env var declares the active edition (operator escape hatch). Adapter `check` subcommand emits `edition=<oss|paid|unknown>` on stdout. Every `conversus_gate_invocation` JSONL record now carries an `edition` field. Presets may declare `edition_required: paid` in their YAML frontmatter; invoking such a preset against an OSS-resolved binary produces an actionable refusal diagnostic. Six doc surfaces updated (commands/conversus-gate.md, commands/ingest.md, commands/specify.md, docs/ingesting-arbitrary-specs.md, references/github-integration.md, references/spec-management.md). New knowledge entries: MEM029 (edition-resolution pattern), MEM030 (paid-escape-hatch env-var convention). DECISIONS.md D022 records the consolidation. See `.orchestrator/milestones/M026/`.
   ```

   If `CHANGELOG.md` has no v0.9.1 heading yet (i.e., changes are being accumulated under an `Unreleased` heading), insert under that heading instead. If neither exists, create a new v0.9.1 heading at the top of the file (after any leading title/intro):

   ```markdown
   ## v0.9.1 (2026-04-24)

   - <the M026 entry above>
   ```

4. **Create `scripts/verify/m026-p03-decision-row.sh`** (single-script-file shape, AD-19, Bash 3.2):

   ```sh
   #!/usr/bin/env bash
   # scripts/verify/m026-p03-decision-row.sh
   # Verifies M026/P03/T04: D022 row in DECISIONS.md + M026 entry in CHANGELOG.md.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   DECISIONS="${REPO_ROOT}/.orchestrator/DECISIONS.md"
   CHANGELOG="${REPO_ROOT}/CHANGELOG.md"

   if grep -qE '^\| D022 \|' "$DECISIONS"; then _pass "DECISIONS.md contains D022 row"; else _fail "DECISIONS.md missing D022 row"; fi
   if grep -qE 'D022.*edition-resolution' "$DECISIONS"; then _pass "D022 names edition-resolution"; else _fail "D022 does not reference edition-resolution"; fi
   if grep -qE 'D022.*MEM029' "$DECISIONS"; then _pass "D022 cross-references MEM029"; else _fail "D022 missing MEM029 cross-ref"; fi
   if grep -qE 'D022.*MEM030' "$DECISIONS"; then _pass "D022 cross-references MEM030"; else _fail "D022 missing MEM030 cross-ref"; fi

   if grep -qE 'M026.*conversus-OSS' "$CHANGELOG"; then _pass "CHANGELOG.md mentions M026 conversus-OSS migration"; else _fail "CHANGELOG.md missing M026 entry"; fi
   if grep -qE 'CONVERSUS_EDITION' "$CHANGELOG"; then _pass "CHANGELOG.md mentions CONVERSUS_EDITION"; else _fail "CHANGELOG.md missing CONVERSUS_EDITION mention"; fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

5. **Run the verifier**:

   ```sh
   bash scripts/verify/m026-p03-decision-row.sh
   ```

   Expected:

   ```
   ----
   SUMMARY: m026-p03-decision-row.sh pass=6 fail=0
   PASS: m026-p03-decision-row.sh
   ```

## Must-Haves

Addresses phase must-haves:
- "Truth: .orchestrator/DECISIONS.md gains a new D### row naming the edition-resolution precedence decision, and CHANGELOG.md records the M026 migration entry under the current version heading"
- Artifacts: `.orchestrator/DECISIONS.md` (modified), `CHANGELOG.md` (modified), `scripts/verify/m026-p03-decision-row.sh`

## Verification

```
bash scripts/verify/m026-p03-decision-row.sh
```

Must exit 0 with `SUMMARY: ... pass=6 fail=0` and `PASS:` final line.

## Inputs

### From Previous Tasks

T03 outputs (MEM029 + MEM030) are referenced in D022's body — but T04 does not need T03 to have completed before drafting D022 (the cross-references are forward-references; the D-row body is text-only and does not validate the linked files exist at draft time). The phase suite at T05 catches any inconsistency.

### From Disk (Pre-existing)

- `.orchestrator/DECISIONS.md` — append target.
- `CHANGELOG.md` — append target.

## Constraints

- **CON-6** (dual-write): T04 does NOT write Recent Changes — that is T05's responsibility via `dual-write-runtime-md.sh`. T04 writes only DECISIONS.md and CHANGELOG.md.
- **DC-2**: D022 names the edition-resolution pattern explicitly (verified by grep `D022.*edition-resolution`).
- **AD-19**: verifier uses no compound bash.
- **Append-only**: do NOT modify pre-existing D-rows or CHANGELOG entries; T04 is purely additive.
- **Idempotent**: re-running T04 must not duplicate the D022 row or the CHANGELOG bullet. The verifier checks for presence, not count — but the executor should grep before appending to avoid duplication.

## Expected Output

- `.orchestrator/DECISIONS.md` — modified: one new row D022 appended.
- `CHANGELOG.md` — modified: one new bullet under v0.9.1 (or current active heading).
- `scripts/verify/m026-p03-decision-row.sh` — created (~35-45 lines).
- `bash scripts/verify/m026-p03-decision-row.sh` exits 0 with `SUMMARY: ... pass=6 fail=0`.
