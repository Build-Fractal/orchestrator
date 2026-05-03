---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M036"
name: "DOCX + XLSX live adapters (with openpyxl shim)"
depends_on: ["T01"]
---

## Prerequisites

- T01 completed: `tests/fixtures/m036-tier-1-adapters/sample.docx`, `sample.xlsx`, `expected/sample-docx.txt`, `expected/sample-xlsx-sheet1.csv`, `expected/sample-xlsx-sheet2.csv` exist.
- Host tools: `pandoc` and Python `openpyxl` SHOULD be present for the verifiers to fully exercise. If absent, the per-adapter verifiers gracefully SKIP (same posture as T02's pdf verifier) — the operator's probe (T01) surfaces install hints.

## Description

Author the two harder Tier 1 adapters and flip their registry rows from `stub` to `live`:

- **DOCX adapter** — shells out to `pandoc <input> -t plain` (preserves heading hierarchy as plain Markdown-ish text per US-6 acceptance scenario 2; pandoc's `plain` writer renders `# H1` etc. cleanly).
- **XLSX adapter** — invokes a Python shim (`scripts/dispatch/adapters/format/lib/xlsx-to-csv.py`) using `openpyxl`. Per US-6 AS-3 and the spec's "Excel→CSV is better than Excel→Markdown for typical sheets", the adapter emits **one CSV per sheet** to a target directory (passed via `--out-dir`). The first row of each sheet is treated as the header (header-aware extraction).

The xlsx adapter's CLI shape:

```
xlsx.sh <input.xlsx> --out-dir <target-dir>
```

Writes `<target-dir>/<sheet-name>.csv` per sheet. Sheet names are sanitized (replace `/`, whitespace with `-`) to avoid filesystem hazards. Stdout emits one `CSV:` line per emitted file naming the path. Exit 0 on success.

## Steps

1. Author `scripts/dispatch/adapters/format/docx.sh`. Behavioral contract:

   ```bash
   #!/usr/bin/env bash
   # scripts/dispatch/adapters/format/docx.sh -- Tier 1 DOCX text-extraction adapter.
   # Usage: docx.sh <input-path>
   # Shells out to `pandoc <input> -t plain` (pandoc's plain writer
   # preserves heading hierarchy and paragraph breaks). Emits text on stdout.
   # Exit 0 on success, 1 on missing input, 2 on missing pandoc.
   # Run scripts/lifecycle/probe-extraction-tools.sh for install hints.
   set -eu
   if [ "$#" -lt 1 ]; then
     echo "usage: docx.sh <input-path>" >&2
     exit 1
   fi
   input="$1"
   if [ ! -f "$input" ]; then
     echo "docx.sh: input not found: $input" >&2
     exit 1
   fi
   if ! command -v pandoc >/dev/null 2>&1; then
     echo "docx.sh: pandoc not found on PATH; run scripts/lifecycle/probe-extraction-tools.sh for install hints" >&2
     exit 2
   fi
   pandoc "$input" -t plain
   ```

   Make executable.

2. Author `scripts/dispatch/adapters/format/lib/xlsx-to-csv.py` (Python shim). Behavioral contract:

   - Pure stdlib + `openpyxl` only.
   - Argument shape: `xlsx-to-csv.py <input.xlsx> --out-dir <target-dir>`.
   - Validates input file exists and `--out-dir` exists (creates if missing via `os.makedirs(..., exist_ok=True)`).
   - Imports `openpyxl`; on `ImportError`, prints to stderr `xlsx-to-csv.py: openpyxl not installed; install via 'pipx install openpyxl' or 'python3 -m pip install --user openpyxl'` and exits 2.
   - Loads workbook with `openpyxl.load_workbook(path, data_only=True, read_only=True)` (data_only=True returns formula values; read_only=True is memory-efficient for large sheets).
   - For each `wb.sheetnames`: sanitize the name (`re.sub(r'[/\s]+', '-', name).strip('-')`), open `<out_dir>/<sanitized>.csv` with `csv.writer`, iterate `ws.iter_rows(values_only=True)`, write each row. The first row IS the header by convention (no schema-detection magic — header-aware = "first row is the header" matches the openpyxl idiom and the SC-9 contract).
   - Empty cells written as empty strings.
   - For each emitted file, print `CSV: <absolute-path>` to stdout.
   - Final stdout line: `SUMMARY: xlsx-to-csv sheets=<N>`.
   - Exit 0 on success.

   Reference shape (the implementing agent fills exact code):

   ```python
   #!/usr/bin/env python3
   """xlsx-to-csv.py -- Tier 1 XLSX -> per-sheet CSV shim.

   Usage: xlsx-to-csv.py <input.xlsx> --out-dir <target-dir>
   Emits one CSV per sheet under <target-dir>, named <sanitized-sheet>.csv,
   with the first row treated as the header. Exits 2 if openpyxl is not
   installed (with install hint on stderr).
   """
   import argparse, csv, os, re, sys
   try:
       import openpyxl
   except ImportError:
       sys.stderr.write("xlsx-to-csv.py: openpyxl not installed; "
                        "install via 'pipx install openpyxl' or "
                        "'python3 -m pip install --user openpyxl'\n")
       sys.exit(2)
   # ... argparse, load_workbook, per-sheet csv.writer loop ...
   ```

   Target ~50-80 lines including docstring + argparse.

3. Author `scripts/dispatch/adapters/format/xlsx.sh`. Behavioral contract:

   ```bash
   #!/usr/bin/env bash
   # scripts/dispatch/adapters/format/xlsx.sh -- Tier 1 XLSX -> per-sheet CSV adapter.
   # Usage: xlsx.sh <input.xlsx> --out-dir <target-dir>
   # Delegates to scripts/dispatch/adapters/format/lib/xlsx-to-csv.py
   # (openpyxl-based pure-Python shim). Emits one CSV per sheet to
   # <target-dir>; stdout lists emitted paths via `CSV:` lines.
   # Exit 0 on success, 1 on missing input/args, 2 on missing python3 or openpyxl.
   # Run scripts/lifecycle/probe-extraction-tools.sh for install hints.
   set -eu
   if [ "$#" -lt 3 ]; then
     echo "usage: xlsx.sh <input.xlsx> --out-dir <target-dir>" >&2
     exit 1
   fi
   input="$1"
   if [ ! -f "$input" ]; then
     echo "xlsx.sh: input not found: $input" >&2
     exit 1
   fi
   if ! command -v python3 >/dev/null 2>&1; then
     echo "xlsx.sh: python3 not found on PATH" >&2
     exit 2
   fi
   here="$(cd "$(dirname "$0")" && pwd)"
   shim="$here/lib/xlsx-to-csv.py"
   if [ ! -f "$shim" ]; then
     echo "xlsx.sh: shim not found at $shim" >&2
     exit 1
   fi
   python3 "$shim" "$@"
   ```

   Make executable. Note: passing `"$@"` forwards `--out-dir <target-dir>` cleanly. The script's own arg-count guard ensures we got at least `<input> --out-dir <target>`.

4. Modify `scripts/dispatch/adapters/format/registry.tsv` — flip the `docx` and `xlsx` rows' `status` field from `stub` to `live`. Update the `notes` column to remove the "P01 deliverable" prefix and describe the live behavior (e.g., `docx -> pandoc -t plain`, `xlsx -> per-sheet CSV via openpyxl shim`).

5. Author `tools/verify/m036-p01-docx-adapter.sh`. Behavioral contract:
   - SKIP gracefully if `command -v pandoc` fails (`SKIP: pandoc-absent (install via probe hints)`, exit 0).
   - When pandoc present: capture `bash scripts/dispatch/adapters/format/docx.sh tests/fixtures/m036-tier-1-adapters/sample.docx` to a temp file.
   - Assert exit code 0, non-empty.
   - For each token in `tests/fixtures/m036-tier-1-adapters/expected/sample-docx.txt`, assert presence via `grep -q -F`.
   - Emit `PASS:` / `FAIL:` per assertion, final summary, exit 0 iff all pass.

6. Author `tools/verify/m036-p01-xlsx-adapter.sh`. Behavioral contract:
   - SKIP gracefully if `python3 -c "import openpyxl"` fails (`SKIP: openpyxl-absent (install via probe hints)`, exit 0).
   - When openpyxl present: create a temp dir under `${TMPDIR:-/tmp}`. Run `bash scripts/dispatch/adapters/format/xlsx.sh tests/fixtures/m036-tier-1-adapters/sample.xlsx --out-dir <temp-dir>`.
   - Assert exit code 0.
   - Assert `<temp-dir>/Sheet1.csv` exists and `diff -q` matches `tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet1.csv` (byte-identical CSV).
   - Assert `<temp-dir>/Sheet2.csv` exists and matches `expected/sample-xlsx-sheet2.csv`.
   - Emit `PASS:` / `FAIL:` per assertion, final summary, exit 0 iff all pass.

## Must-Haves

- DOCX adapter exists, exits 0 on the fixture, stdout contains expected tokens (Truth: m036-p01-docx-adapter).
- XLSX adapter exists, exits 0 on the fixture, emits one CSV per sheet with header row preserved (Truth: m036-p01-xlsx-adapter).
- Registry shows `docx` and `xlsx` at `status=live` (covered by T04's verifier).
- openpyxl shim exists and is invokable (Artifact: `xlsx-to-csv.py` ≥30 lines, contains "openpyxl").
- Key Links: registry references `docx.sh` and `xlsx.sh`; xlsx.sh references `lib/xlsx-to-csv.py`.

## Verification

```bash
bash tools/verify/m036-p01-docx-adapter.sh
bash tools/verify/m036-p01-xlsx-adapter.sh
```

> Note: the per-adapter verifiers are host-tooling-aware and SKIP gracefully when `pandoc` or `openpyxl` is absent (exit 0 with `SKIP:` line). Direct invocation of `docx.sh` / `xlsx.sh` against a fixture is intentionally not a Truth Check here because the adapters' documented contract is exit-2 when the host tool is missing — that's correct behavior, not a verification failure. T04's acceptance harness exercises the live positive path on hosts where pandoc + openpyxl are present.

## Inputs

### From Previous Tasks

- `tests/fixtures/m036-tier-1-adapters/sample.docx` (from T01) — input for docx adapter.
- `tests/fixtures/m036-tier-1-adapters/sample.xlsx` (from T01) — input for xlsx adapter; 2 sheets (Sheet1, Sheet2) per T01 step 5.
- `tests/fixtures/m036-tier-1-adapters/expected/sample-docx.txt` (from T01) — token allowlist for pandoc plain output.
- `tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet1.csv` and `sample-xlsx-sheet2.csv` (from T01) — byte-identical comparison targets for the xlsx-adapter verifier.
- `scripts/lifecycle/probe-extraction-tools.sh` (from T01) — referenced in adapter error messages for install hints.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/format/registry.tsv` — modified: flip `docx` and `xlsx` rows from `stub` to `live`. (T02 already flipped `markdown` and `pdf`; if T02 and T03 run truly in parallel, both must flip ONLY their own rows — they touch disjoint lines so the merge is safe.)
- `scripts/dispatch/adapters/format/native.sh`, `speckit.sh` — sibling adapter shape reference.

## Constraints

- CON-2: Bash 3.2 / POSIX-sh for adapter shells. Python shim uses Python 3 (`#!/usr/bin/env python3`). Bash compatibility constraint does not apply to the Python shim.
- AD-19 / AP-009: verifier shapes single-invocation. The xlsx-adapter verifier creates a temp dir via `mktemp -d` (single command, no compound), runs the adapter (single command), then runs `diff -q` per file (each its own statement). Document as a sequence of independent statements, not a piped chain.
- CON-3 (amended): xlsx fixture is binary, ~tens of KB, lives under the permitted `tests/fixtures/m036-tier-1-adapters/`.
- The xlsx shim MUST work with `openpyxl read_only=True` mode for memory efficiency on real-world XLSX (regulatory CMS sheets can be tens of thousands of rows). The fixture is small but the shim must not assume small inputs.
- Sheet name sanitization must be deterministic — same input always yields the same CSV filename (so the verifier's `diff -q` against expected files is reliable).

## Notes

Expected verifier output (when host tools present):
- `m036-p01-docx-adapter.sh` — `PASS: exit-0`, `PASS: non-empty`, plus one `PASS:` per allowlist token, final summary, exit 0.
- `m036-p01-xlsx-adapter.sh` — `PASS: exit-0`, `PASS: Sheet1.csv-exists`, `PASS: Sheet1.csv-byte-identical`, `PASS: Sheet2.csv-exists`, `PASS: Sheet2.csv-byte-identical`, final summary, exit 0.

Expected adapter output:
- `docx.sh sample.docx` — emits plain text containing at least the tokens `M036`, `docx`, `fixture`.
- `xlsx.sh sample.xlsx --out-dir /tmp/m036-xlsx-out.XXX` — emits `CSV: /tmp/.../Sheet1.csv` and `CSV: /tmp/.../Sheet2.csv` lines on stdout, plus `SUMMARY: xlsx-to-csv sheets=2`.

## Expected Output

After T03 completes:
- Two new live adapter scripts (`docx.sh`, `xlsx.sh`) plus the openpyxl shim (`lib/xlsx-to-csv.py`).
- Registry rows for `docx` and `xlsx` flipped to `status=live`. Combined with T02's flips, all four registry rows are now `status=live`.
- Two new verifier scripts (`m036-p01-docx-adapter.sh`, `m036-p01-xlsx-adapter.sh`) both exiting 0 (or SKIP-with-exit-0 when host tooling absent).
- T04 can land the SC-9 acceptance harness against all four real adapters.
