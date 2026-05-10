---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M036"
provides:
  - "tests/fixtures/m036-tier-1-adapters/ (4 sample binaries + 4 expected-output files),scripts/lifecycle/probe-extraction-tools.sh (host-tool probe; informational; exit 0),tools/verify/m036-p01-fixture-corpus-shape.sh (8-check verifier),tools/verify/m036-p01-probe-shape.sh (4-check verifier)"
requires:
  - "from:M036/P00 what:scripts/dispatch/adapters/format/registry.tsv (canonical adapter list cross-referenced from probe top comment)"
affects:
  - "M036/P01/T02,M036/P01/T03,M036/P01/T04"
key_files:
  - "tests/fixtures/m036-tier-1-adapters/sample.md,tests/fixtures/m036-tier-1-adapters/sample.pdf,tests/fixtures/m036-tier-1-adapters/sample.docx,tests/fixtures/m036-tier-1-adapters/sample.xlsx,tests/fixtures/m036-tier-1-adapters/expected/sample-pdf.txt,tests/fixtures/m036-tier-1-adapters/expected/sample-docx.txt,tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet1.csv,tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet2.csv,scripts/lifecycle/probe-extraction-tools.sh,tools/verify/m036-p01-fixture-corpus-shape.sh,tools/verify/m036-p01-probe-shape.sh"
key_decisions:
  - "none"
patterns_established:
  - "hand-authored minimal PDF (5-object: catalog/pages/page/contents/font + xref) + minimal OOXML (zipfile stdlib only) generator pattern for binary fixtures on hosts without pandoc/openpyxl,probe-shape verifier captures stdout to TMPDIR file + four discrete grep -q anchor checks (avoids piped chains; AD-19 single-script-file shape),informational-only probe contract (exit 0 regardless; Hint-on-miss with one-line install suggestion; trailing SUMMARY: probe k=v line for downstream parsing)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P01/tasks/T01-fixtures-and-probe-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-02T12:07:44Z"
---

T01 (Fixtures + host-tool probe) lands the binary fixture corpus and the informational host-tool probe that gate-bracket the four format-adapter implementations T02 and T03 will deliver.

**What was built**:

- **Fixture corpus** — `tests/fixtures/m036-tier-1-adapters/` populated with one minimal sample per format (`sample.md` 116B, `sample.pdf` 607B, `sample.docx` 958B, `sample.xlsx` 2346B — every binary file <50KB, well within the CON-3 amended budget). The `expected/` subdir carries four token-allowlist / expected-CSV files that T02/T03 verifiers will diff against adapter output.

- **Probe script** — `scripts/lifecycle/probe-extraction-tools.sh` (executable, Bash 3.2 / POSIX-sh) reports presence of `pdftotext` (poppler), `pandoc`, and Python `openpyxl` in fixed order with one-line install hints when missing. Informational only — exits 0 regardless. Top-comment cross-references the canonical adapter list at `scripts/dispatch/adapters/format/registry.tsv`.

- **Two shape verifiers** — `tools/verify/m036-p01-fixture-corpus-shape.sh` (8 file-existence checks) and `tools/verify/m036-p01-probe-shape.sh` (4 anchor-string checks against probe stdout). Both single-script-file shape per AD-19 / AP-009 (no compound chains, no piped substitutions, no subshells beyond the trap-protected temp file).

**Generation method (no pandoc / no openpyxl on dev host)**:

The dev host lacks pandoc and openpyxl (the probe correctly reports both as `present=no`). To produce the binary fixtures without those tools, T01 staged a single Python generator at `/tmp/m036-gen-fixtures.py` that uses only stdlib (`zipfile` + manual XML literals + manual PDF object table). The PDF was hand-authored as a five-object minimal PDF with a single content stream containing the literal phrase `M036 pdf fixture body text`; the DOCX and XLSX are minimal OOXML packages with the `[Content_Types].xml`, `_rels/.rels`, and the smallest legal main-part XML each format requires. The generator script is staged in `/tmp` (not committed) — re-running it is idempotent and reproducible from the body of this summary if the fixtures ever need to be regenerated. The PDF was end-to-end verified by running `pdftotext` against the produced sample.pdf and observing the expected literal phrase emerge unmodified (`M036 pdf fixture body text`).

**Verification (3/3 PASS)**:

- `tools/verify/m036-p01-fixture-corpus-shape.sh` -> `SUMMARY: m036-p01-fixture-corpus-shape pass=8 fail=0`, exit 0.
- `tools/verify/m036-p01-probe-shape.sh` -> `SUMMARY: m036-p01-probe-shape pass=4 fail=0`, exit 0.
- `bash scripts/lifecycle/probe-extraction-tools.sh` -> exit 0; reports `pdftotext: present=yes`, `pandoc: present=no`, `openpyxl: present=no` with hint lines (matches the predicted dev-host state in the task plan Notes).

**Forward-pointing notes**:

- T02 (markdown + pdf adapters) and T03 (docx + xlsx adapters) consume the fixture corpus directly. The DOCX and XLSX fixtures were produced without their target host tools (pandoc / openpyxl) — when those tools land on the host (or in CI), the per-adapter verifiers T02/T03 ship will be the first to round-trip-validate them. The fixtures are syntactically minimal but conformant OOXML; if a tool rejects them, the failure is more likely a missing optional XML part than a malformed core part.
- The Python generator at `/tmp/m036-gen-fixtures.py` is intentionally NOT committed. If the fixtures ever need regeneration, the body of this summary documents the generation algorithm completely; alternatively a future cleanup may promote it to `tests/fixtures/m036-tier-1-adapters/regenerate.py` if regen-velocity ever matters. Today the fixtures are stable bytes on disk and don't need a build step.
- AD-19 single-script-file shape was honored throughout — both new verifiers use discrete `grep -q` or `[ -f ... ]` calls, no piped chains, no compound substitutions. The probe-shape verifier captures probe stdout to a `${TMPDIR}` file via straight redirection then runs four discrete `grep -q` calls against it.
