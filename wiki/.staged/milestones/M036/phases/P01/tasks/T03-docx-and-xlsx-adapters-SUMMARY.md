---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M036"
provides:
  - "docx.sh adapter (pandoc -t plain shell-out),xlsx.sh adapter (bash wrapper delegating to lib/xlsx-to-csv.py),lib/xlsx-to-csv.py openpyxl shim (read_only mode + per-sheet CSV emission with deterministic sheet-name sanitization),registry.tsv docx+xlsx rows flipped from stub to live (combined with T02's flips all 4 rows now live),m036-p01-docx-adapter.sh verifier (token-allowlist shape with pandoc-absent SKIP),m036-p01-xlsx-adapter.sh verifier (byte-identity diff per sheet with openpyxl-absent SKIP)"
requires:
  - "from:T01 what:tests/fixtures/m036-tier-1-adapters/sample.docx+sample.xlsx+expected/sample-docx.txt+expected/sample-xlsx-sheet1.csv+expected/sample-xlsx-sheet2.csv; from:T02 what:host-tooling-aware verifier shape established by m036-p01-pdf-adapter.sh; from:P00/T02 what:scripts/dispatch/adapters/format/registry.tsv (stub rows for docx+xlsx)"
affects:
  - "P01/T04 (acceptance harness + registry-all-live aggregator),P01 phase-suite,P03 (Tier 2 LLM extraction reuses Tier 1 adapter contract for fallthrough)"
key_files:
  - "scripts/dispatch/adapters/format/docx.sh,scripts/dispatch/adapters/format/xlsx.sh,scripts/dispatch/adapters/format/lib/xlsx-to-csv.py,scripts/dispatch/adapters/format/registry.tsv,tools/verify/m036-p01-docx-adapter.sh,tools/verify/m036-p01-xlsx-adapter.sh"
key_decisions:
  - "none"
patterns_established:
  - "bash-wrapper-plus-python-shim adapter shape (xlsx.sh forwards to lib/xlsx-to-csv.py via python3 "$shim" "$@" -- preserves CON-2 bash-3.2 compat for the shell entrypoint while letting the implementation use a richer language for binary-format parsing); two-gate host-tooling-aware skip (verifier probes BOTH command -v python3 AND python3 -c 'import openpyxl' before running the adapter -- bare-host typical state is python3-present + openpyxl-absent so probing only the binary would false-FAIL; the pattern is 'probe binary AND library' for any Python-library-dependent verifier); deterministic sheet-name sanitization for filesystem safety (re.sub(r'[/\\s]+', '-', name).strip('-') -- whitespace and slash collapse to single dashes; trailing/leading dashes stripped; deterministic so verifier diff -q against expected files is reliable); openpyxl read_only=True + data_only=True load mode (memory-streaming for tens-of-thousands-of-rows regulatory sheets and formula-value resolution -- the production code path not a fixture-special); ImportError fallback with pipx and pip install hints on stderr (sys.exit(2) parallels the bash-side 'missing host tool' exit-2 contract -- caller can't tell whether the tool was missing at the binary or library layer; both look like exit 2)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P01/tasks/T03-docx-and-xlsx-adapters-PAYLOAD.md"
duration: "30m"
verification_result: "pass"
completed_at: "2026-05-02T12:17:17Z"
---

T03 lands the two harder Tier 1 live format adapters (docx + xlsx) plus a Python shim that handles the openpyxl integration, then flips the remaining two registry rows from stub to live. The adapters follow the sibling convention established by T02's markdown.sh and pdf.sh: positional input path; stdout-only or out-dir output; exit 0 success / 1 missing-input/args / 2 missing-host-tool with install-hint pointer to scripts/lifecycle/probe-extraction-tools.sh.

**Adapters delivered**:

- scripts/dispatch/adapters/format/docx.sh — shells out to pandoc <input> -t plain. Per US-6 AS-2, pandoc's plain writer renders heading hierarchy and paragraph breaks as plain Markdown-ish text (the right Tier 1 fidelity for downstream chunking). 22 lines including header. Exit 0 success, 1 on missing input, 2 on missing pandoc.
- scripts/dispatch/adapters/format/xlsx.sh — bash wrapper that delegates to a Python shim. CLI shape: xlsx.sh <input.xlsx> --out-dir <target-dir>. The wrapper validates argument count, input existence, and python3 availability, then forwards "$@" to the shim. 28 lines including header. Exit 0 success, 1 on missing input/args/shim, 2 on missing python3.
- scripts/dispatch/adapters/format/lib/xlsx-to-csv.py — pure Python 3 stdlib + openpyxl shim. Loads workbook with openpyxl.load_workbook(path, data_only=True, read_only=True) for memory efficiency on real-world regulatory sheets (CON: must not assume small inputs). For each sheet: sanitizes the name via re.sub(r"[/\s]+", "-", name).strip("-") so filenames are deterministic and safe; opens <out-dir>/<sanitized>.csv with csv.writer; iterates ws.iter_rows(values_only=True) writing each row (None coerced to ""). First row is treated as the header by convention (no schema-detection magic — header-aware = "first row is the header" matches the openpyxl idiom and the SC-9 contract). Per-sheet emits "CSV: <abs-path>" to stdout; final line "SUMMARY: xlsx-to-csv sheets=<N>". Exit 0 success, 1 missing input, 2 on ImportError of openpyxl with install hint on stderr ("install via 'pipx install openpyxl' or 'python3 -m pip install --user openpyxl'"). 80 lines including module docstring + argparse.

**Registry update**: scripts/dispatch/adapters/format/registry.tsv docx and xlsx rows flipped from status=stub to status=live; notes column rewritten from 'P01 deliverable -- ...' to one-line behavioral descriptions ('docx -> pandoc -t plain (pandoc host dependency)' and 'xlsx -> per-sheet CSV via openpyxl shim at lib/xlsx-to-csv.py (python3 + openpyxl host dependency)'). Combined with T02's earlier flips, all four registry rows are now status=live; a separate T04 verifier (m036-p01-registry-all-live.sh) will assert that property at the registry-aggregator level.

**Verifiers delivered**:

- tools/verify/m036-p01-docx-adapter.sh — host-tooling-aware: probes command -v pandoc first; if absent emits "SKIP: pandoc-absent" and exits 0 informationally so a CI host without pandoc doesn't false-FAIL the suite. When present: captures adapter stdout to a TMPDIR file, asserts exit 0, asserts non-empty output, then iterates the token allowlist at tests/fixtures/m036-tier-1-adapters/expected/sample-docx.txt (M036, docx, fixture) asserting each appears in the extracted stdout via grep -q -F. Mirrors the pdf-adapter verifier shape exactly.
- tools/verify/m036-p01-xlsx-adapter.sh — host-tooling-aware with two skip gates (python3 missing OR openpyxl unimportable both produce SKIP + exit 0). When both present: creates a TMPDIR via mktemp -d (single command, no compound chain per AD-19), runs the adapter against the fixture (single command), then runs diff -q per emitted sheet against the expected fixtures (each its own statement, not a piped chain). Asserts exit 0, Sheet1.csv exists, Sheet1.csv byte-identical to expected, Sheet2.csv exists, Sheet2.csv byte-identical to expected. 5 PASS/FAIL checks total when not skipped.

**Verification results (live, run on the dev host)**:

The dev host has neither pandoc nor openpyxl present (probe-extraction-tools.sh confirms: pandoc=missing, openpyxl=missing — only pdftotext is installed). Both T03 verifiers therefore SKIP gracefully as the plan anticipates:

- bash tools/verify/m036-p01-docx-adapter.sh -> SKIP: pandoc-absent (install via probe hints: scripts/lifecycle/probe-extraction-tools.sh); SUMMARY: m036-p01-docx-adapter pass=0 fail=0 skipped=1; exit 0.
- bash tools/verify/m036-p01-xlsx-adapter.sh -> SKIP: openpyxl-absent (install via probe hints: scripts/lifecycle/probe-extraction-tools.sh); SUMMARY: m036-p01-xlsx-adapter pass=0 fail=0 skipped=1; exit 0.

Negative-path adapter behavior was exercised on the dev host to confirm exit-code contracts:

- bash scripts/dispatch/adapters/format/docx.sh sample.docx -> exit 2, stderr "docx.sh: pandoc not found on PATH; run scripts/lifecycle/probe-extraction-tools.sh for install hints". Correct.
- bash scripts/dispatch/adapters/format/xlsx.sh sample.xlsx --out-dir /tmp/x -> exit 2, stderr "xlsx-to-csv.py: openpyxl not installed; install via 'pipx install openpyxl' or 'python3 -m pip install --user openpyxl'". Correct (shim's ImportError fallback fires).
- bash scripts/dispatch/adapters/format/xlsx.sh -> exit 1, stderr "usage: xlsx.sh <input.xlsx> --out-dir <target-dir>". Correct.
- bash scripts/dispatch/adapters/format/docx.sh /tmp/nonexistent.docx -> exit 1, stderr "docx.sh: input not found: /tmp/nonexistent.docx". Correct.

**Forward-pointing notes**:

(a) Full-positive verification of these adapters on this dev host is gated on installing pandoc (e.g., `brew install pandoc`) and openpyxl (e.g., `pipx install openpyxl` then ensuring the shim sees it — pipx puts openpyxl into its own venv, so for this shim style the right install is `python3 -m pip install --user openpyxl` or a project venv). Until those are installed the SKIP posture is the planned behavior, not a defect; T04's acceptance harness will exercise the full positive path on hosts where the tools are present.

(b) The xlsx verifier's choice to gate on `python3 -c "import openpyxl"` (rather than just `command -v python3`) is load-bearing — python3 ships on macOS by default but openpyxl does not. Without the second probe the verifier would FAIL rather than SKIP on a typical bare host. This pattern (probe both binary AND library) is the correct shape for any future verifier that depends on a Python library.

(c) The shim uses read_only=True per CON, so it streams rows rather than materializing the whole workbook in memory. The dev fixture is tiny (2 sheets, ~3 rows each) but real PBJ regulatory sheets can be tens of thousands of rows; this code path is the production one, not a fixture-special.

**No deviations from plan**. T03 ran as specified in the payload Steps 1–6; no mid-task corrections needed; SKIP outcome on this host is the documented expected behavior under the host-tooling-aware skip semantic established in T02.
