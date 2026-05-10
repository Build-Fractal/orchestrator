---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M036"
goal: "Tier 1 live format adapters: markdown passthrough, pdf via pdftotext, docx via pandoc, xlsx via openpyxl shim — all four flipped to status=live in the registry"
demo_sentence: "Operator runs `bash scripts/dispatch/adapters/format/pdf.sh tests/fixtures/m036-tier-1-adapters/sample.pdf` and gets exit 0 with stdout containing the PDF's body text; same for docx.sh, xlsx.sh (one CSV per sheet to a temp dir), and markdown.sh (passthrough); registry.tsv lists all four with status=live."
risk: "medium"
depends_on: ["P00"]
---

## Boundary Map

**Produces:**

- `scripts/dispatch/adapters/format/markdown.sh` — live passthrough (cat)
- `scripts/dispatch/adapters/format/pdf.sh` — live, calls `pdftotext -layout`
- `scripts/dispatch/adapters/format/docx.sh` — live, calls `pandoc --to=plain`
- `scripts/dispatch/adapters/format/xlsx.sh` — live, sheet-by-sheet CSV via openpyxl Python shim
- `scripts/dispatch/adapters/format/lib/xlsx-to-csv.py` — pure-Python openpyxl shim (header-aware, one CSV per sheet to a target dir)
- `scripts/dispatch/adapters/format/registry.tsv` — modify in place: flip all four rows to `status=live`
- `scripts/lifecycle/probe-extraction-tools.sh` — host-tool probe (presence check + fallback messages for missing pdftotext/pandoc/openpyxl)
- `tests/fixtures/m036-tier-1-adapters/` — fixture corpus (small samples per format: sample.pdf, sample.docx, sample.xlsx, sample.md, plus an optional `expected/` text file per format)
- `tests/test-tier-1-adapters.sh` — SC-9 acceptance harness (real-binary roundtrip per CON-3 amended)
- `tools/verify/m036-p01-markdown-adapter.sh` — Truth verifier
- `tools/verify/m036-p01-pdf-adapter.sh` — Truth verifier
- `tools/verify/m036-p01-docx-adapter.sh` — Truth verifier
- `tools/verify/m036-p01-xlsx-adapter.sh` — Truth verifier
- `tools/verify/m036-p01-registry-all-live.sh` — Truth verifier (registry contract)
- `tools/verify/m036-p01-probe-shape.sh` — Truth verifier (probe presence + output shape)
- `tools/verify/m036-p01-fixture-corpus-shape.sh` — Truth verifier (fixtures exist)
- `tools/verify/m036-p01-test-harness.sh` — Truth verifier (the SC-9 test exists and is invocable)
- `tools/verify/m036-p01-phase-suite.sh` — phase-suite aggregator (8 sub-gates)

**Consumes:**

- P00 adapter registry seam: `scripts/dispatch/adapters/format/registry.tsv` (4 rows currently `status=stub`)
- P00 SSOTs: `references/reference-source-types.yaml`, `references/reference-frontmatter-contract.md` (read-only, for tier-mapping context)
- Existing dispatch adapter convention: `scripts/dispatch/adapters/format/native.sh`, `speckit.sh` (file-naming + invocation shape: `bash <adapter>.sh <input-path>` writes to stdout, exit 0 on success)
- Host system tooling: `pdftotext` (poppler-utils), `pandoc`, `python3 + openpyxl`

## External Tooling Decision (justification)

The roadmap leaves the Excel parser choice open. After plan-time host probe:

- `pdftotext` — present at `/opt/homebrew/bin/pdftotext` on the dev host.
- `pandoc` — NOT present on dev host today; widely available via `brew install pandoc` / `apt install pandoc`. Standard cross-platform DOCX→text tool.
- `python3` — present at `/opt/homebrew/bin/python3`. `openpyxl` — NOT present today; standard pure-Python XLSX reader, installable via `pip install openpyxl` or `pipx install openpyxl`.

**Excel parser choice: `python3 + openpyxl` shim** (`scripts/dispatch/adapters/format/lib/xlsx-to-csv.py`). Rationale:

1. **Portability** — pure Python, no native libs; works identically on macOS/Linux/WSL.
2. **De-facto standard** — `xlsx2csv` (the obvious Bash candidate) wraps openpyxl internally; using openpyxl directly removes a wrapper layer and one packaging dependency.
3. **Header-aware** — openpyxl exposes per-sheet first-row access cleanly, satisfying SC-9's "header detection" requirement without parser hacks.
4. **Composes with the probe pattern** — `python3 -c "import openpyxl"` is a one-line presence check that mirrors `command -v pdftotext` and `command -v pandoc`.

`gnumeric` `ssconvert` was rejected (not portable to macOS by default). `libreoffice --headless` was rejected (heavyweight, slow startup, not standard on dev/CI hosts). `xlsx2csv` was rejected (extra wrapper layer over openpyxl).

The probe script documents fallback messages for each missing tool (one-line install hint per platform: `brew install poppler` / `brew install pandoc` / `pipx install openpyxl`).

## Must-Haves

### Truths

<!-- Each Truth's Check is a single-script-file invocation (AD-19 / AP-009).
     All verifier slugs are milestone-prefixed (m036-p01-*) per the
     "milestone slug REQUIRED" naming convention. All verifiers live under
     tools/verify/ (project-owned, slug-bearing). -->

- The markdown adapter passes its source content through unchanged on stdout and exits 0.
  - Check: `bash tools/verify/m036-p01-markdown-adapter.sh`
- The pdf adapter exits 0 against `tests/fixtures/m036-tier-1-adapters/sample.pdf` and stdout contains expected body-text tokens.
  - Check: `bash tools/verify/m036-p01-pdf-adapter.sh`
- The docx adapter exits 0 against `tests/fixtures/m036-tier-1-adapters/sample.docx` and stdout contains expected body-text tokens.
  - Check: `bash tools/verify/m036-p01-docx-adapter.sh`
- The xlsx adapter exits 0 against `tests/fixtures/m036-tier-1-adapters/sample.xlsx` and emits one CSV per sheet to its `--out-dir` target with the header row preserved.
  - Check: `bash tools/verify/m036-p01-xlsx-adapter.sh`
- The adapter registry lists all four formats (`markdown`, `pdf`, `docx`, `xlsx`) at `status=live` (no `stub` rows remaining for those formats).
  - Check: `bash tools/verify/m036-p01-registry-all-live.sh`
- The host-tool probe exists, is executable, exits 0 (informational), and emits one line per probed tool with `present=` or `missing=` plus a fallback hint when missing.
  - Check: `bash tools/verify/m036-p01-probe-shape.sh`
- The fixture corpus directory exists with one sample per format (markdown, pdf, docx, xlsx).
  - Check: `bash tools/verify/m036-p01-fixture-corpus-shape.sh`
- The SC-9 acceptance harness (`tests/test-tier-1-adapters.sh`) exists, is executable, runs all four real adapters against real binary fixtures, and emits a `BATTERY: pass=N fail=0` summary line.
  - Check: `bash tools/verify/m036-p01-test-harness.sh`

### Artifacts

- `scripts/dispatch/adapters/format/markdown.sh` (min 8 lines, contains `cat`)
- `scripts/dispatch/adapters/format/pdf.sh` (min 12 lines, contains `pdftotext`)
- `scripts/dispatch/adapters/format/docx.sh` (min 12 lines, contains `pandoc`)
- `scripts/dispatch/adapters/format/xlsx.sh` (min 15 lines, contains `xlsx-to-csv.py`)
- `scripts/dispatch/adapters/format/lib/xlsx-to-csv.py` (min 30 lines, contains `openpyxl`)
- `scripts/dispatch/adapters/format/registry.tsv` (min 5 lines, contains "status")
- `scripts/lifecycle/probe-extraction-tools.sh` (min 25 lines, contains "pdftotext")
- `tests/fixtures/m036-tier-1-adapters/sample.md` (min 1 lines, contains "M036")
- `tests/test-tier-1-adapters.sh` (min 30 lines, contains "BATTERY:")
- `tools/verify/m036-p01-phase-suite.sh` (min 25 lines, contains "SUMMARY: m036-p01-phase-suite.sh")

### Key Links

- `scripts/dispatch/adapters/format/registry.tsv` → `scripts/dispatch/adapters/format/markdown.sh` (registry row points at the live adapter file)
- `scripts/dispatch/adapters/format/registry.tsv` → `scripts/dispatch/adapters/format/pdf.sh`
- `scripts/dispatch/adapters/format/registry.tsv` → `scripts/dispatch/adapters/format/docx.sh`
- `scripts/dispatch/adapters/format/registry.tsv` → `scripts/dispatch/adapters/format/xlsx.sh`
- `scripts/dispatch/adapters/format/xlsx.sh` → `scripts/dispatch/adapters/format/lib/xlsx-to-csv.py` (xlsx adapter invokes the openpyxl shim)
- `tests/test-tier-1-adapters.sh` → `scripts/dispatch/adapters/format/pdf.sh` (the SC-9 harness exercises all four adapters)
- `scripts/lifecycle/probe-extraction-tools.sh` → `scripts/dispatch/adapters/format/registry.tsv` (probe references the registry as the canonical adapter list)
- `tools/verify/m036-p01-phase-suite.sh` → `tools/verify/m036-p01-pdf-adapter.sh` (aggregator wires the sub-gate)

## Tasks

### T01: Fixtures + host-tool probe (preflight surface)

See `tasks/T01-fixtures-and-probe-PLAN.md`. Establishes the fixture corpus + probe so subsequent tasks have a real-binary input set and a documented host-tool dependency surface to consult.

### T02: Markdown + PDF live adapters

See `tasks/T02-markdown-and-pdf-adapters-PLAN.md`. The two simplest adapters (one passthrough + one shell-out). Flips their registry rows to `live`. Lands shape verifiers `m036-p01-markdown-adapter.sh` and `m036-p01-pdf-adapter.sh`.

### T03: DOCX + XLSX live adapters (with openpyxl shim)

See `tasks/T03-docx-and-xlsx-adapters-PLAN.md`. The two harder adapters: pandoc shell-out + Python shim for sheet-by-sheet CSV emission. Authors `lib/xlsx-to-csv.py`. Flips their registry rows to `live`. Lands shape verifiers `m036-p01-docx-adapter.sh` and `m036-p01-xlsx-adapter.sh`.

### T04: SC-9 acceptance harness + phase-suite aggregator

See `tasks/T04-acceptance-harness-and-aggregator-PLAN.md`. Authors `tests/test-tier-1-adapters.sh` (the SC-9 harness running real adapters against real binary fixtures per Plan-Time Discipline rule 5), the registry-all-live verifier, the test-harness shape verifier, and the M036 P01 phase-suite aggregator wiring all 8 sub-gates.

## Task Dependencies

```
T01 (fixtures + probe)
   |
   +--> T02 (markdown + pdf adapters)
   |
   +--> T03 (docx + xlsx adapters)
   |
   T02 + T03 --> T04 (SC-9 harness + phase-suite aggregator)
```

T02 and T03 can run in parallel after T01 (different files; both consume the same fixture corpus + registry but land non-overlapping rows). T04 depends on both because the SC-9 battery exercises all four adapters.

## Files Likely Touched

- `scripts/dispatch/adapters/format/markdown.sh` (create)
- `scripts/dispatch/adapters/format/pdf.sh` (create)
- `scripts/dispatch/adapters/format/docx.sh` (create)
- `scripts/dispatch/adapters/format/xlsx.sh` (create)
- `scripts/dispatch/adapters/format/lib/xlsx-to-csv.py` (create)
- `scripts/dispatch/adapters/format/registry.tsv` (modify — flip 4 rows from stub to live)
- `scripts/lifecycle/probe-extraction-tools.sh` (create)
- `tests/fixtures/m036-tier-1-adapters/sample.md` (create)
- `tests/fixtures/m036-tier-1-adapters/sample.pdf` (create — small binary fixture, ~tens of KB per CON-3 amended)
- `tests/fixtures/m036-tier-1-adapters/sample.docx` (create — small binary fixture)
- `tests/fixtures/m036-tier-1-adapters/sample.xlsx` (create — small binary fixture, 2 sheets)
- `tests/fixtures/m036-tier-1-adapters/expected/sample-pdf.txt` (create — expected-token allowlist)
- `tests/fixtures/m036-tier-1-adapters/expected/sample-docx.txt` (create)
- `tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet1.csv` (create)
- `tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet2.csv` (create)
- `tests/test-tier-1-adapters.sh` (create)
- `tools/verify/m036-p01-markdown-adapter.sh` (create)
- `tools/verify/m036-p01-pdf-adapter.sh` (create)
- `tools/verify/m036-p01-docx-adapter.sh` (create)
- `tools/verify/m036-p01-xlsx-adapter.sh` (create)
- `tools/verify/m036-p01-registry-all-live.sh` (create)
- `tools/verify/m036-p01-probe-shape.sh` (create)
- `tools/verify/m036-p01-fixture-corpus-shape.sh` (create)
- `tools/verify/m036-p01-test-harness.sh` (create)
- `tools/verify/m036-p01-phase-suite.sh` (create)

## Plan-Time Discipline checks performed

1. **Prerequisite-existence verification** — Upstream P00 artifacts cited by tasks (`references/reference-source-types.yaml`, `scripts/dispatch/adapters/format/registry.tsv`, `tools/verify/m036-p00-phase-suite.sh`) all confirmed on disk.
2. **Verifier-availability cross-check** — Every `## Verification` command in each task plan resolves to a script that is either (a) framework-owned and on disk (`scripts/verify/check-must-haves.sh`), or (b) a project-owned `m036-p01-*.sh` verifier scheduled as a deliverable inside *that same task*. No cross-task verifier dependencies (T04's verifiers are T04's own deliverables).
3. **Classifier-shape pre-validation** — All Truth `Check:` commands and all `## Verification` commands use the single-script-file shape (`bash <path>.sh [args]`). No inline compounds, subshells, command-substitution-with-pipes, or process substitution. Adapter scripts and the openpyxl shim are invoked as `bash <adapter> <path>` and `python3 <shim> <args>` — both single-invocation forms that pass `classify_command`.
4. **`run-probe.sh` scope discipline** — All verifier invocations target `tools/verify/<...>.sh` directly via `bash <path>`. No `run-probe.sh` wrapping (these verifiers live in the project tree, not under `/tmp` / `/var/folders` / `<repo>/tmp/`).
5. **Real-DB / real-app smoke test** — Not SQL-bound. The analogous discipline (real-binary smoke) IS satisfied: `tests/test-tier-1-adapters.sh` invokes the real adapter scripts against the real binary fixtures (CON-3 amended permits binary fixtures specifically under `tests/fixtures/m036-tier-1-adapters/`). No mocks at the adapter boundary.
6. **Path-collision check** — Every `create` deliverable was checked via `ls`. None of the M036/P01 paths exist on disk today. Note: `tools/verify/p01-*.sh` files DO exist but they are [M030](../../../../milestones/M030/index.md) verifiers (different milestone) under unprefixed slugs. Our new verifiers use the milestone-prefixed `m036-p01-*` slug per the "milestone slug REQUIRED" rule and do NOT collide. The phase-suite path `tools/verify/m036-p01-phase-suite.sh` is verified clear (the existing `tools/verify/p01-phase-suite.sh` belongs to M030).
