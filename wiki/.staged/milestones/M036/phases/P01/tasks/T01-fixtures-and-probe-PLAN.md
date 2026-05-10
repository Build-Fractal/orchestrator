---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M036"
name: "Fixtures + host-tool probe"
depends_on: []
---

## Prerequisites

- P00 closed (verified): `tools/verify/m036-p00-phase-suite.sh` exists and exits 0; `scripts/dispatch/adapters/format/registry.tsv` exists with four `status=stub` rows.
- Host tools (informational, not gating): `pdftotext` present at `/opt/homebrew/bin/pdftotext`; `pandoc` may be missing; `python3` present; `openpyxl` may be missing. The probe this task ships REPORTS these conditions; it does not require them.

## Description

Establish the binary fixture corpus the four adapters will be tested against, and ship the host-tool probe that documents (and helps install) the external dependencies. Two-track output: (a) `tests/fixtures/m036-tier-1-adapters/` populated with one minimal sample per format plus an `expected/` subdir containing token allowlists / expected CSVs, and (b) `scripts/lifecycle/probe-extraction-tools.sh` reporting `pdftotext`, `pandoc`, and Python `openpyxl` presence with one-line install hints when missing.

CON-3 (amended 2026-05-01) explicitly permits binary fixtures under `tests/fixtures/m036-tier-1-adapters/` for adapter-roundtrip tests — small samples, ~tens of KB per file.

## Steps

1. Create the fixture directory `tests/fixtures/m036-tier-1-adapters/` and its `expected/` subdir.

2. Author `tests/fixtures/m036-tier-1-adapters/sample.md` (a tiny markdown file containing the literal token `M036` somewhere in the body — e.g., a heading `# M036 fixture markdown` plus a one-line body).

3. Generate `tests/fixtures/m036-tier-1-adapters/sample.pdf`. Use `pdftotext`'s sibling tooling or any minimal-PDF generator. Acceptable approach: hand-author a known-good minimal-PDF (one page, ASCII body text containing the literal phrase `M036 pdf fixture body text`). If `pandoc` is available, `pandoc sample.md -o sample.pdf` is acceptable; if not, a pre-generated tiny PDF committed as a binary blob is acceptable. Target size <50 KB.

4. Generate `tests/fixtures/m036-tier-1-adapters/sample.docx`. Hand-author or use `pandoc sample.md -o sample.docx` (one heading `M036 docx fixture` + one body paragraph containing the literal phrase `docx fixture body text`). Target size <50 KB.

5. Generate `tests/fixtures/m036-tier-1-adapters/sample.xlsx` with two sheets:
   - Sheet "Sheet1": header row `id,name,value`; two data rows `1,alpha,100` and `2,beta,200`.
   - Sheet "Sheet2": header row `field,note`; one data row `staff_count,M036 xlsx fixture`.
   Use any local tool to author (Numbers/Excel/openpyxl one-shot script). Target size <50 KB.

6. Author `tests/fixtures/m036-tier-1-adapters/expected/sample-pdf.txt` containing one-token-per-line allowlist of body-text tokens that MUST appear in pdftotext's output (e.g., `M036`, `pdf`, `fixture`, `body`, `text`).

7. Author `tests/fixtures/m036-tier-1-adapters/expected/sample-docx.txt` containing one-token-per-line allowlist for pandoc's plain output (e.g., `M036`, `docx`, `fixture`).

8. Author `tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet1.csv`:

   ```csv
   id,name,value
   1,alpha,100
   2,beta,200
   ```

9. Author `tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet2.csv`:

   ```csv
   field,note
   staff_count,M036 xlsx fixture
   ```

10. Author `scripts/lifecycle/probe-extraction-tools.sh`. Behavioral contract:

    - Bash 3.2 / POSIX-sh per CON-2.
    - Probes three tools: `pdftotext` (via `command -v`), `pandoc` (via `command -v`), Python `openpyxl` (via `python3 -c "import openpyxl"`).
    - Emits one stdout line per tool in fixed order: `pdftotext: present=<yes|no> path=<path-or-empty>`, `pandoc: present=<yes|no> path=<path-or-empty>`, `openpyxl: present=<yes|no> python=<python3-path-or-empty>`.
    - When `present=no`, emits a follow-up line `  hint: <one-line-install-suggestion>` (e.g., `hint: brew install poppler`, `hint: brew install pandoc`, `hint: pipx install openpyxl  # or: python3 -m pip install --user openpyxl`).
    - Exits 0 informationally regardless of presence (this is a diagnostic, not a gate).
    - Final summary line: `SUMMARY: probe pdftotext=<y|n> pandoc=<y|n> openpyxl=<y|n>`.
    - References the canonical adapter list: include a top-comment pointer to `scripts/dispatch/adapters/format/registry.tsv`.

11. Author `tools/verify/m036-p01-fixture-corpus-shape.sh`. Behavioral contract:
    - Asserts each of `sample.md`, `sample.pdf`, `sample.docx`, `sample.xlsx` exists under `tests/fixtures/m036-tier-1-adapters/`.
    - Asserts each `expected/sample-*` file exists.
    - Single-script-file shape (no compound chains).
    - Emits `PASS:` per asserted file, `FAIL:` on miss, exits 0 iff all pass.

12. Author `tools/verify/m036-p01-probe-shape.sh`. Behavioral contract:
    - Invokes `bash scripts/lifecycle/probe-extraction-tools.sh` and captures stdout to a temp file under `/tmp` or `${TMPDIR}`.
    - Asserts the temp file contains `pdftotext:`, `pandoc:`, `openpyxl:`, and a `SUMMARY: probe` line via four discrete `grep -q` calls (no piped chains).
    - Exits 0 iff all four assertions pass.

## Must-Haves

- Fixture corpus exists with one sample per format (Truth: fixture-corpus-shape).
- Probe script exists, executes, emits the documented shape (Truth: probe-shape).
- Artifacts: all sample files + probe script meet line/content thresholds declared in the phase plan.

## Verification

```bash
bash tools/verify/m036-p01-fixture-corpus-shape.sh
bash tools/verify/m036-p01-probe-shape.sh
bash scripts/lifecycle/probe-extraction-tools.sh
```

## Inputs

### From Previous Tasks

None (T01 is the entry task for P01).

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/format/registry.tsv` (P00 deliverable) — read-only reference for the canonical four-format list. Probe script's top comment points at this file.
- `references/reference-source-types.yaml` (P00 deliverable) — read-only; not consumed at runtime by this task but documented as upstream context.
- `tools/verify/m036-p00-phase-suite.sh` — convention reference: copy the `set -eu` + run-helper pattern when authoring the new verifiers.

## Constraints

- CON-2: Bash 3.2 / POSIX-sh for all `.sh` files. No `declare -A`. Optional `jq` permitted but not required.
- CON-3 (amended): binary fixtures permitted ONLY under `tests/fixtures/m036-tier-1-adapters/`. Each binary file ~tens of KB; nothing >100 KB committed.
- AD-19 / AP-009: every verifier `Check:` and every `## Verification` line MUST be a single-script-file invocation. No `( ... )` subshells, no `$(...|...)`, no `<(...)`, no compound `;` chains >2.
- The probe script is informational-only (exit 0 regardless). It does not gate anything.

## Notes

Expected verifier output:
- `tools/verify/m036-p01-fixture-corpus-shape.sh` — emits `PASS:` per file (4 samples + 4 expected files = 8 lines), final `SUMMARY: m036-p01-fixture-corpus-shape pass=8 fail=0`, exit 0.
- `tools/verify/m036-p01-probe-shape.sh` — emits `PASS: probe-output-contains-<tool>` (4 lines), final `SUMMARY: m036-p01-probe-shape pass=4 fail=0`, exit 0.
- `scripts/lifecycle/probe-extraction-tools.sh` — informational; exits 0 regardless. On the dev host today it should report `pdftotext: present=yes`, `pandoc: present=no`, `openpyxl: present=no` with hint lines.

## Expected Output

After T01 completes:
- `tests/fixtures/m036-tier-1-adapters/` exists with `sample.md`, `sample.pdf`, `sample.docx`, `sample.xlsx`, and `expected/` containing per-format expected-output files.
- `scripts/lifecycle/probe-extraction-tools.sh` exists, is executable, and reports tool presence.
- `tools/verify/m036-p01-fixture-corpus-shape.sh` and `tools/verify/m036-p01-probe-shape.sh` exist and exit 0.
- T02 and T03 can both consume the fixture corpus.
