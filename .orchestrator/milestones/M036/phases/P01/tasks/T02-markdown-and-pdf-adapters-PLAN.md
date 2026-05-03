---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M036"
name: "Markdown + PDF live adapters"
depends_on: ["T01"]
---

## Prerequisites

- T01 completed: `tests/fixtures/m036-tier-1-adapters/sample.md`, `sample.pdf`, `expected/sample-pdf.txt` all exist on disk.
- Host tool `pdftotext` present (verified by T01 probe). If absent, the pdf-adapter verifier exits 2 with a clear pointer to `scripts/lifecycle/probe-extraction-tools.sh` for installation hints — but a reviewer running this task should have pdftotext installed (see probe output).

## Description

Author the two simplest Tier 1 adapters and flip their registry rows from `stub` to `live`:

- **Markdown adapter** — passthrough. Reads the input path with `cat`. Used for already-normalized reference content; the Tier 1 contract is "emit plain text" so cat is the correct semantic.
- **PDF adapter** — shell-out to `pdftotext -layout <input> -` (the trailing `-` writes to stdout per pdftotext convention). `-layout` preserves visual ordering, which matters for tabular regulatory PDFs.

Both adapters follow the dispatch-adapter convention used by `scripts/dispatch/adapters/format/native.sh` and `speckit.sh` (sibling files in the same directory): take the input path as `$1`, write extracted text to stdout, exit 0 on success, non-zero on host-tool absence or input error.

## Steps

1. Author `scripts/dispatch/adapters/format/markdown.sh`. Behavioral contract:

   ```bash
   #!/usr/bin/env bash
   # scripts/dispatch/adapters/format/markdown.sh -- Tier 1 markdown passthrough adapter.
   # Usage: markdown.sh <input-path>
   # Reads <input-path> and emits its content to stdout unchanged. The Tier 1
   # contract for already-normalized markdown is "preserve the source body
   # verbatim" — cat is the correct semantic. Exit 0 on success, 1 on missing
   # or unreadable input. Bash 3.2 / POSIX-sh per CON-2.
   set -eu
   if [ "$#" -lt 1 ]; then
     echo "usage: markdown.sh <input-path>" >&2
     exit 1
   fi
   input="$1"
   if [ ! -f "$input" ]; then
     echo "markdown.sh: input not found: $input" >&2
     exit 1
   fi
   cat "$input"
   ```

   Make executable (`chmod +x`).

2. Author `scripts/dispatch/adapters/format/pdf.sh`. Behavioral contract:

   ```bash
   #!/usr/bin/env bash
   # scripts/dispatch/adapters/format/pdf.sh -- Tier 1 PDF text-extraction adapter.
   # Usage: pdf.sh <input-path>
   # Shells out to `pdftotext -layout <input> -` (poppler-utils). -layout
   # preserves visual ordering, which matters for tabular regulatory PDFs.
   # Exit 0 on success, 1 on missing input, 2 on missing pdftotext.
   # Run scripts/lifecycle/probe-extraction-tools.sh for install hints.
   set -eu
   if [ "$#" -lt 1 ]; then
     echo "usage: pdf.sh <input-path>" >&2
     exit 1
   fi
   input="$1"
   if [ ! -f "$input" ]; then
     echo "pdf.sh: input not found: $input" >&2
     exit 1
   fi
   if ! command -v pdftotext >/dev/null 2>&1; then
     echo "pdf.sh: pdftotext not found on PATH; run scripts/lifecycle/probe-extraction-tools.sh for install hints" >&2
     exit 2
   fi
   pdftotext -layout "$input" -
   ```

   Make executable.

3. Modify `scripts/dispatch/adapters/format/registry.tsv` — flip the `markdown` and `pdf` rows' `status` field from `stub` to `live`. Update the `notes` column to remove the "P01 deliverable" prefix (replace with a one-line description of what the adapter does, e.g., `markdown -> passthrough (cat)`). Leave `docx` and `xlsx` rows at `stub` until T03 lands them.

4. Author `tools/verify/m036-p01-markdown-adapter.sh`. Behavioral contract:
   - Captures `bash scripts/dispatch/adapters/format/markdown.sh tests/fixtures/m036-tier-1-adapters/sample.md` to a temp file under `${TMPDIR:-/tmp}`.
   - Asserts exit code 0.
   - Asserts the temp file's content is byte-identical to the input fixture (`diff -q` between temp file and `tests/fixtures/m036-tier-1-adapters/sample.md`, exit 0 means identical).
   - Single-script-file shape: each step is its own statement; no compound chains.
   - Emits `PASS:` / `FAIL:` lines, final `SUMMARY: m036-p01-markdown-adapter pass=N fail=N`, exits 0 iff all pass.

5. Author `tools/verify/m036-p01-pdf-adapter.sh`. Behavioral contract:
   - First check `command -v pdftotext` — if missing, emit `SKIP: pdftotext-absent (install via probe hints)` and exit 0 informationally (the verifier is host-tooling-aware; this avoids false-FAILing on a CI host without poppler). Document this skip semantic in the script's top comment.
   - When pdftotext is present: capture `bash scripts/dispatch/adapters/format/pdf.sh tests/fixtures/m036-tier-1-adapters/sample.pdf` to a temp file.
   - Assert exit code 0.
   - Assert the temp file is non-empty.
   - For each token listed in `tests/fixtures/m036-tier-1-adapters/expected/sample-pdf.txt`, assert presence in the temp file via `grep -q -F "$token" <temp>`.
   - Single-script-file shape; no piped chains in `Check:`.
   - Emits per-token `PASS:` / `FAIL:`, final summary, exits 0 iff all pass (or skipped).

## Must-Haves

- Markdown adapter exists, exits 0 on the fixture, emits identical bytes (Truth: m036-p01-markdown-adapter).
- PDF adapter exists, exits 0 on the fixture, stdout contains expected tokens (Truth: m036-p01-pdf-adapter).
- Registry shows `markdown` and `pdf` at `status=live` (covered by T04's `m036-p01-registry-all-live.sh`).
- Artifacts: `markdown.sh`, `pdf.sh` meet line/content thresholds.
- Key Links: registry references `markdown.sh` and `pdf.sh`.

## Verification

```bash
bash tools/verify/m036-p01-markdown-adapter.sh
bash tools/verify/m036-p01-pdf-adapter.sh
bash scripts/dispatch/adapters/format/markdown.sh tests/fixtures/m036-tier-1-adapters/sample.md
bash scripts/dispatch/adapters/format/pdf.sh tests/fixtures/m036-tier-1-adapters/sample.pdf
```

## Inputs

### From Previous Tasks

- `tests/fixtures/m036-tier-1-adapters/sample.md` (from T01) — input for markdown adapter; verifier asserts byte-identical passthrough.
- `tests/fixtures/m036-tier-1-adapters/sample.pdf` (from T01) — input for pdf adapter.
- `tests/fixtures/m036-tier-1-adapters/expected/sample-pdf.txt` (from T01) — token allowlist; verifier asserts each token appears in pdftotext's output. Format: one token per line, blank lines / `#`-comment lines ignored.
- `scripts/lifecycle/probe-extraction-tools.sh` (from T01) — referenced in pdf.sh's error message for install hints; not invoked at adapter runtime.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/format/registry.tsv` (P00 deliverable) — modified in this task: flip `markdown` and `pdf` rows from `stub` to `live`. Leave `docx` and `xlsx` rows untouched.
- `scripts/dispatch/adapters/format/native.sh`, `speckit.sh` — sibling adapters, used as shape reference (script header, set -eu, usage-on-no-args, exit-1-on-bad-input convention).

## Constraints

- CON-2: Bash 3.2 / POSIX-sh for all adapter scripts.
- AD-19 / AP-009: verifier `Check:` and `## Verification` commands MUST be single-script-file invocations.
- AP-008 (heredoc-with-expansion): the adapter scripts above are written as-is (not via heredoc inside a bash subprocess); when authoring via the Write tool this is fine. If a future executor uses `bash -c "$(cat <<EOF ...)"` it will trip the shape-guard — Write the files directly.
- pdf-adapter verifier MUST gracefully skip when pdftotext is absent (host-tooling-aware skip, not a false fail). Same posture used for the docx verifier in T03.

## Notes

Expected verifier output (when host tools present):
- `m036-p01-markdown-adapter.sh` — `PASS: exit-0`, `PASS: byte-identical`, `SUMMARY: m036-p01-markdown-adapter pass=2 fail=0`.
- `m036-p01-pdf-adapter.sh` — `PASS: exit-0`, `PASS: non-empty-output`, plus one `PASS:` per allowlist token, final summary, exit 0.

Expected adapter output:
- `markdown.sh sample.md` — emits the file's bytes verbatim.
- `pdf.sh sample.pdf` — emits ASCII text containing at least the tokens `M036`, `pdf`, `fixture`, `body`, `text`.

## Expected Output

After T02 completes:
- Two new live adapter scripts under `scripts/dispatch/adapters/format/`.
- Registry rows for `markdown` and `pdf` flipped to `status=live`.
- Two new verifier scripts under `tools/verify/` (`m036-p01-markdown-adapter.sh`, `m036-p01-pdf-adapter.sh`) both exiting 0.
- T03 can run in parallel (or after) without coordination — it touches different registry rows and different adapter files.
