---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M036"
name: "Tier 0 summary helper + Tier 1 registry-dispatch leg + commands/extract.md"
depends_on: ["T02"]
---

## Prerequisites

T02 must be complete:

- `scripts/knowledge/extract-reference.sh` — driver scaffold with placeholder calls to `extract_tier_1_via_registry` and `generate_tier_0_summary`.
- `scripts/knowledge/lib/extract-manifest.sh` — manifest accessors.
- `scripts/knowledge/lib/extract-binary-preservation.sh` — sha256 + preservation helpers.
- `tools/verify/m036-p02-extract-driver-shape.sh` (PASS at T02 close).

T01 deliverables also required (already on disk):

- `tests/fixtures/m036/extract-manifest.yaml`
- `tests/fixtures/m036/sample.{pdf,docx,md}`
- `references/extract-manifest-contract.md`

P00 / P01 inputs (already on disk):

- `references/reference-source-types.yaml`
- `references/reference-frontmatter-contract.md`
- `references/reference-taxonomy.md`
- `scripts/dispatch/adapters/format/registry.tsv` (4 rows live)
- `scripts/dispatch/adapters/format/{markdown,pdf,docx,xlsx}.sh`

Confirmed on disk at plan-authoring time.

## Description

Author the Tier 0 summary helper, the Tier 1 registry-dispatch leg, and the `commands/extract.md` command document. With this task complete, the driver becomes end-to-end functional and T02's behavioural verifiers (`binary-preservation`, `content-hash`, `size-cap-external-pointer`) flip from amber to green.

The summary helper exposes two functions:

- `generate_tier_0_summary <mode> <category> <cite_id> <operator-summary> <tier>` — returns the summary text per the mode enum. `operator` mode echoes the operator-supplied string; `stub` mode emits a deterministic placeholder; `auto` mode exits with a message naming "P03" and "not implemented".
- `extract_tier_1_via_registry <source-path> <text-output-path> <registry-tsv-path>` — resolves the source path's extension to a registry row, invokes the adapter, captures stdout to the text-output-path. For XLSX (a multi-output adapter) the helper invokes the adapter with `--out-dir <text-output-path>.csv-out/` and writes a placeholder marker file at the text-output-path describing the CSV emission.

## Steps

### 1. Author `scripts/knowledge/lib/extract-tier-0-summary.sh`

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/extract-tier-0-summary.sh -- pure helpers for
# Tier 0 summary generation and Tier 1 adapter dispatch via registry.
# Sourced by scripts/knowledge/extract-reference.sh. No top-level I/O.
# Bash 3.2 / POSIX-sh per CON-2.

# generate_tier_0_summary <mode> <category> <cite_id> <operator-summary> <tier>
#   Echoes the chunk-body summary text per the mode enum.
#   Modes:
#     - operator: echo <operator-summary> verbatim. Exits 1 if empty
#                 (manifest violated `summary:` requirement).
#     - stub:     emit a deterministic placeholder: "[stub-summary]
#                 <category>: <cite_id>".
#     - auto:     P02 errors -- exit 1 with stderr "P03 not implemented:
#                 Tier 2 LLM extraction is the P03 deliverable; current
#                 P02 ships the synchronous Tier 0/1 path. Use
#                 summary_mode: operator or stub instead, or wait for
#                 P03 to land."
generate_tier_0_summary() {
  local mode="$1"
  local category="$2"
  local cite_id="$3"
  local op_summary="$4"
  local tier="$5"
  case "$mode" in
    operator)
      if [ -z "$op_summary" ]; then
        echo "generate_tier_0_summary: summary_mode=operator requires manifest summary:" >&2
        return 1
      fi
      printf '%s\n' "$op_summary"
      ;;
    stub)
      printf '[stub-summary] %s: %s\n' "$category" "$cite_id"
      ;;
    auto)
      if [ "$tier" = "2" ]; then
        echo "generate_tier_0_summary: P03 not implemented: Tier 2 LLM extraction is the P03 deliverable; current P02 ships the synchronous Tier 0/1 path. Use summary_mode: operator or stub instead, or wait for P03 to land." >&2
      else
        echo "generate_tier_0_summary: summary_mode=auto deferred to P03 (Tier 2 path). Use summary_mode: operator or stub for tier $tier." >&2
      fi
      return 1
      ;;
    *)
      echo "generate_tier_0_summary: unknown summary_mode '$mode' (expected: operator|stub|auto)" >&2
      return 1
      ;;
  esac
}

# extract_tier_1_via_registry <source-path> <text-output-path> <registry-tsv-path>
#   Resolves the source extension -> adapter via registry; invokes the
#   adapter, writes Tier 1 plain text to <text-output-path>. For
#   adapters with --out-dir contract (xlsx) emits a marker file at
#   <text-output-path> referencing the per-sheet CSV directory.
#   Exit 0 success, 1 missing input, 2 missing host tool (delegated
#   from adapter exit 2 -- caller decides whether to bail or continue).
extract_tier_1_via_registry() {
  local src="$1"
  local out="$2"
  local registry="$3"
  local ext="${src##*.}"
  local fmt
  case "$ext" in
    md|markdown) fmt="markdown" ;;
    pdf)         fmt="pdf" ;;
    docx)        fmt="docx" ;;
    xlsx)        fmt="xlsx" ;;
    *)
      echo "extract_tier_1_via_registry: unknown extension '$ext' for $src" >&2
      return 1
      ;;
  esac
  local adapter
  adapter=$(awk -F'\t' -v f="$fmt" '$1==f {print $2; exit}' "$registry")
  if [ -z "$adapter" ]; then
    echo "extract_tier_1_via_registry: no registry row for format '$fmt'" >&2
    return 1
  fi
  local root
  root=$(dirname "$registry")
  # Registry paths are repo-relative; if the registry stores
  # scripts/dispatch/adapters/format/markdown.sh, resolve relative to
  # ORCHESTRATOR_ROOT instead of the registry directory.
  local adapter_abs
  if [ "${adapter#/}" != "$adapter" ]; then
    adapter_abs="$adapter"
  else
    adapter_abs="${ORCHESTRATOR_ROOT:-$(pwd)}/$adapter"
  fi
  if [ "$fmt" = "xlsx" ]; then
    local outdir="${out}.csv-out"
    mkdir -p "$outdir"
    bash "$adapter_abs" "$src" --out-dir "$outdir" >/dev/null 2>&1 || return $?
    printf '[xlsx Tier 1: per-sheet CSVs at %s]\n' "$outdir" > "$out"
  else
    bash "$adapter_abs" "$src" > "$out" 2>/dev/null || return $?
  fi
  return 0
}
```

### 2. Make the helper sourceable

```bash
chmod +x scripts/knowledge/lib/extract-tier-0-summary.sh
```

### 3. Author `commands/extract.md`

```markdown
---
description: "Use when extracting reference materials (PDF / Word / Excel / Markdown) into the orchestrator's reference-corpus knowledge layer. Synchronous Tier 0 (manifest + binary preservation + summary) and Tier 1 (deterministic plain-text via shell adapters); Tier 2 (LLM-driven structured Markdown) routes through M030 + conversus and is wired in P03."
---

# orchestrator:extract

Run a tiered extraction pass over a manifest of source documents. The command preserves original binaries under `_originals/<source>/` (CON-7), computes content hashes (FR-9, FR-14), and emits Tier 0 chunk files plus Tier 1 plain-text extraction files into the reference-corpus tree.

This command is **separate from `orchestrator:ingest`**: extract produces the artifacts ingest later promotes to chunks (FR-16). They compose: extract → ingest → dispatch.

## Prerequisites

- An extraction manifest at a known path (default convention: `<reference-root>/extract-manifest.yaml`). See `references/extract-manifest-contract.md` for the schema.
- Tier 1 host tools available for the formats the manifest declares:
  - `pdftotext` (poppler-utils) for PDFs.
  - `pandoc` for DOCX.
  - `python3 + openpyxl` for XLSX.
  - None required for `.md` (passthrough).
- The orchestrator's reference-corpus directory tree (`knowledge/reference/`) — the command creates per-category subdirectories on demand.

## Inputs

- `--manifest <path>` (required) — path to the extraction manifest.
- `--reference-root <path>` (optional, default `knowledge/reference`) — root under which chunk files are written.
- `--originals-root <path>` (optional, default `.orchestrator/knowledge/reference/_originals`) — root under which preserved binaries are written.
- `--summary-mode <operator|stub|auto>` (optional) — overrides the manifest's per-document `summary_mode`. `auto` is **not implemented in P02**; that mode is the P03 seam.
- `--size-cap-bytes <int>` (optional) — overrides the manifest's `size_cap_bytes`. Files above the cap record an `external_pointer:` instead of being copied into `_originals/`.

## Output

For each document in the manifest:

- `_originals/<source>/<filename>` — byte-identical copy of the source binary, OR no copy when above the size cap (chunk frontmatter then carries `external_pointer:`).
- `knowledge/reference/<category>/REF-<category>-<cite_id>.md` — Tier 0 chunk: frontmatter (provenance + content_hash + tier) + body (Tier 0 summary).
- `knowledge/reference/<category>/REF-<category>-<cite_id>.text.md` — Tier 1 plain-text extraction (when `tier: 1` or `tier: 2`).
- *(Tier 2 structured Markdown lands in P03.)*

Stdout protocol:

- `EXTRACTED: <cite_id> tier=<n> bytes=<n> hash=<sha256-prefix>` per newly-extracted doc.
- `SKIPPED: <cite_id> reason=unchanged` per content-hash-matched re-run.

Errors to stderr; non-zero exit on any error.

## Idempotency

Re-running on an unchanged manifest produces zero modifications under `<reference-root>` and `<originals-root>` (CON-4 / FR-9). Content hash gates re-extraction at every tier.

## Error Handling

- Missing `--manifest` path: exit 1, stderr names the missing flag.
- Source binary not found: exit 1, names the doc + missing path.
- `summary_mode: operator` without a `summary:` field: exit 1, names the doc.
- `summary_mode: auto`: exit 1 with stderr "P03 not implemented" pointer (Tier 2 wires in P03).
- Tier 1 adapter exit 2 (host tool absent): driver bails with a stderr hint pointing at `scripts/lifecycle/probe-extraction-tools.sh`.
- Out-of-taxonomy `category:`: rejected by `tools/verify/lib/p00-validate-chunk-frontmatter.sh` defence-in-depth check.

## Referenced Scripts

- `scripts/knowledge/extract-reference.sh` — driver.
- `scripts/knowledge/lib/extract-manifest.sh` — manifest accessors.
- `scripts/knowledge/lib/extract-binary-preservation.sh` — sha256 + preservation.
- `scripts/knowledge/lib/extract-tier-0-summary.sh` — summary modes + Tier 1 registry dispatch.
- `scripts/dispatch/adapters/format/{markdown,pdf,docx,xlsx}.sh` — Tier 1 adapters (P01).
- `scripts/dispatch/adapters/format/registry.tsv` — adapter dispatch table (P00 / P01).
- `references/extract-manifest-contract.md` — manifest schema SSOT.
- `references/reference-source-types.yaml` — per-category default tier.
- `references/reference-frontmatter-contract.md` — chunk frontmatter SSOT.

## Reference Files

- `tests/fixtures/m036/extract-manifest.yaml` — the M036 fixture manifest exercised by `tests/test-tier-0-manifest.sh` (SC-10).
- `tests/test-tier-0-manifest.sh` — SC-10 acceptance harness.
- Spec authority: `specs/033-reference-corpus-ingest/spec.md` (FR-14, FR-16, FR-17, FR-18, FR-19, CON-3, CON-4, CON-7).
```

### 4. Author `tools/verify/m036-p02-extract-md.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-extract-md.sh -- M036 P02 T03.
# Drives the extract driver against the fixture manifest and asserts
# the markdown floor doc emits a chunk file containing the operator
# summary, plus an EXTRACTED: line per doc on stdout.
# No host-tool dependency for the markdown leg, so no SKIP gate here.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-md.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

# Stage a markdown-only manifest so we don't need pdftotext/pandoc.
cp "$ROOT/tests/fixtures/m036/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "md-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2026-05-02"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 1
    summary_mode: "operator"
    summary: "Markdown fixture summary for P02 verifier."
YAML

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$WORK/manifest.yaml" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt" || {
    echo "FAIL: driver exited non-zero"
    cat "$WORK/stderr.txt" >&2
    exit 1
  }

fail=0
chunk="$WORK/knowledge/reference/glossary/REF-glossary-md-fixture-01.md"
text="$WORK/knowledge/reference/glossary/REF-glossary-md-fixture-01.text.md"
if [ -f "$chunk" ]; then echo "PASS: chunk exists"; else echo "FAIL: chunk missing"; fail=$((fail + 1)); fi
if [ -f "$text" ];  then echo "PASS: text  exists"; else echo "FAIL: text missing";  fail=$((fail + 1)); fi
if grep -qF "Markdown fixture summary for P02 verifier." "$chunk"; then
  echo "PASS: operator summary in chunk body"
else
  echo "FAIL: operator summary missing"
  fail=$((fail + 1))
fi
if grep -qE '^EXTRACTED: md-fixture-01 ' "$WORK/stdout.txt"; then
  echo "PASS: EXTRACTED: line emitted"
else
  echo "FAIL: EXTRACTED: line missing"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p02-extract-md.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 5. Author `tools/verify/m036-p02-extract-pdf-host-aware.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-extract-pdf-host-aware.sh -- M036 P02 T03.
# Drives the extract driver against a PDF-only manifest. Probes
# pdftotext first; SKIP+exit 0 if absent. Asserts text file exists
# with non-empty body when present.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
if ! command -v pdftotext >/dev/null 2>&1; then
  echo "SKIP: pdftotext-absent"
  exit 0
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-pdf.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

cp "$ROOT/tests/fixtures/m036/sample.pdf" "$WORK/sample.pdf"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "pdf-fixture-01"
    source_path: "sample.pdf"
    category: "cms-rule"
    source: "cms"
    published: "2024-09-01"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 1
    summary_mode: "stub"
YAML

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$WORK/manifest.yaml" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt" || {
    echo "FAIL: driver exited non-zero"
    cat "$WORK/stderr.txt" >&2
    exit 1
  }

fail=0
text="$WORK/knowledge/reference/cms-rule/REF-cms-rule-pdf-fixture-01.text.md"
if [ ! -f "$text" ]; then
  echo "FAIL: text file missing"
  fail=$((fail + 1))
else
  echo "PASS: text file exists"
  bytes=$(wc -c < "$text" | tr -d ' ')
  if [ "$bytes" -gt 0 ]; then
    echo "PASS: text file non-empty (bytes=$bytes)"
  else
    echo "FAIL: text file empty"
    fail=$((fail + 1))
  fi
fi
echo "SUMMARY: m036-p02-extract-pdf-host-aware.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 6. Author `tools/verify/m036-p02-extract-docx-host-aware.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-extract-docx-host-aware.sh -- M036 P02 T03.
# Drives the extract driver against a DOCX-only manifest. SKIP+exit 0
# if pandoc absent. Asserts text file exists with non-empty body.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
if ! command -v pandoc >/dev/null 2>&1; then
  echo "SKIP: pandoc-absent"
  exit 0
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-dx.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

cp "$ROOT/tests/fixtures/m036/sample.docx" "$WORK/sample.docx"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "docx-fixture-01"
    source_path: "sample.docx"
    category: "training-material"
    source: "sme-pbj-circle"
    published: "2024-08-15"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 1
    summary_mode: "stub"
YAML

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$WORK/manifest.yaml" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt" || {
    echo "FAIL: driver exited non-zero"
    cat "$WORK/stderr.txt" >&2
    exit 1
  }

fail=0
text="$WORK/knowledge/reference/training-material/REF-training-material-docx-fixture-01.text.md"
if [ ! -f "$text" ]; then
  echo "FAIL: text file missing"
  fail=$((fail + 1))
else
  echo "PASS: text file exists"
  bytes=$(wc -c < "$text" | tr -d ' ')
  if [ "$bytes" -gt 0 ]; then
    echo "PASS: text file non-empty (bytes=$bytes)"
  else
    echo "FAIL: text file empty"
    fail=$((fail + 1))
  fi
fi
echo "SUMMARY: m036-p02-extract-docx-host-aware.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 7. Author `tools/verify/m036-p02-extract-command-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-extract-command-shape.sh -- M036 P02 T03.
# Asserts commands/extract.md exists with the required headings.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DOC="$ROOT/commands/extract.md"
fail=0
if [ ! -f "$DOC" ]; then
  echo "FAIL: missing $DOC"
  exit 1
fi
check() {
  local pat="$1"
  if grep -qF "$pat" "$DOC"; then
    echo "PASS: contains '$pat'"
  else
    echo "FAIL: missing '$pat'"
    fail=$((fail + 1))
  fi
}
check "## Prerequisites"
check "## Inputs"
check "## Output"
check "## Idempotency"
check "## Error Handling"
check "## Referenced Scripts"
check "--manifest"
check "EXTRACTED:"
check "SKIPPED:"
echo "SUMMARY: m036-p02-extract-command-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 8. Author `tools/verify/m036-p02-summary-mode-stub-vs-operator.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-summary-mode-stub-vs-operator.sh -- M036 P02 T03.
# Drives the driver twice (once with summary_mode=operator, once with
# stub) against a markdown-only fixture and asserts the resulting chunk
# bodies differ. No live LLM (CON-3).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-mode.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

cp "$ROOT/tests/fixtures/m036/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest-op.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "mode-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2026-05-02"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 0
    summary_mode: "operator"
    summary: "Operator-supplied summary text -- distinct token."
YAML

cat > "$WORK/manifest-stub.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "mode-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2026-05-02"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 0
    summary_mode: "stub"
YAML

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WORK/manifest-op.yaml" \
  --reference-root "$WORK/op/reference" \
  --originals-root "$WORK/op/_originals" \
  >/dev/null 2>"$WORK/op-err.txt" || { echo "FAIL: operator-mode driver"; cat "$WORK/op-err.txt" >&2; exit 1; }

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WORK/manifest-stub.yaml" \
  --reference-root "$WORK/stub/reference" \
  --originals-root "$WORK/stub/_originals" \
  >/dev/null 2>"$WORK/stub-err.txt" || { echo "FAIL: stub-mode driver"; cat "$WORK/stub-err.txt" >&2; exit 1; }

fail=0
op_chunk="$WORK/op/reference/glossary/REF-glossary-mode-fixture-01.md"
stub_chunk="$WORK/stub/reference/glossary/REF-glossary-mode-fixture-01.md"

if grep -qF "Operator-supplied summary text -- distinct token." "$op_chunk"; then
  echo "PASS: operator summary present"
else
  echo "FAIL: operator summary absent"
  fail=$((fail + 1))
fi
if grep -qF "[stub-summary] glossary: mode-fixture-01" "$stub_chunk"; then
  echo "PASS: stub summary present"
else
  echo "FAIL: stub summary absent"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p02-summary-mode-stub-vs-operator.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 9. Author `tools/verify/m036-p02-tier-2-deferred-error.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-tier-2-deferred-error.sh -- M036 P02 T03.
# Drives the driver against a manifest declaring tier:2 + summary_mode:auto.
# Asserts non-zero exit with stderr message naming "P03" + "not implemented".
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-tier2.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

cp "$ROOT/tests/fixtures/m036/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "tier2-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2026-05-02"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 2
    summary_mode: "auto"
YAML

set +e
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WORK/manifest.yaml" \
  --reference-root "$WORK/reference" \
  --originals-root "$WORK/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
rc=$?
set -e

fail=0
if [ "$rc" -eq 0 ]; then
  echo "FAIL: driver exited 0 (expected non-zero for tier:2 + summary_mode:auto)"
  fail=$((fail + 1))
else
  echo "PASS: driver exited non-zero (rc=$rc)"
fi
if grep -qF "P03" "$WORK/stderr.txt"; then
  echo "PASS: stderr names 'P03'"
else
  echo "FAIL: stderr missing 'P03'"
  fail=$((fail + 1))
fi
if grep -qF "not implemented" "$WORK/stderr.txt"; then
  echo "PASS: stderr names 'not implemented'"
else
  echo "FAIL: stderr missing 'not implemented'"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p02-tier-2-deferred-error.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 10. Make verifiers executable

```bash
chmod +x tools/verify/m036-p02-extract-md.sh \
         tools/verify/m036-p02-extract-pdf-host-aware.sh \
         tools/verify/m036-p02-extract-docx-host-aware.sh \
         tools/verify/m036-p02-extract-command-shape.sh \
         tools/verify/m036-p02-summary-mode-stub-vs-operator.sh \
         tools/verify/m036-p02-tier-2-deferred-error.sh
```

## Must-Haves

This task addresses:

- The `commands/extract.md` command document exists with required headings.
- Markdown floor extraction produces a chunk file with the operator summary + `EXTRACTED:` line.
- PDF extraction (host-aware SKIP) produces a `REF-cms-rule-*.text.md` Tier 1 file.
- DOCX extraction (host-aware SKIP) produces a `REF-training-material-*.text.md` Tier 1 file.
- `--summary-mode=stub` and `--summary-mode=operator` produce different deterministic summaries.
- A manifest entry declaring `tier: 2` + `summary_mode: auto` exits non-zero with stderr naming "P03" + "not implemented".

## Verification

```bash
bash tools/verify/m036-p02-extract-md.sh
bash tools/verify/m036-p02-extract-pdf-host-aware.sh
bash tools/verify/m036-p02-extract-docx-host-aware.sh
bash tools/verify/m036-p02-extract-command-shape.sh
bash tools/verify/m036-p02-summary-mode-stub-vs-operator.sh
bash tools/verify/m036-p02-tier-2-deferred-error.sh
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/extract-reference.sh` (from T02) — driver scaffold; this task adds `lib/extract-tier-0-summary.sh` which the driver sources at top.
  - Key API: driver invokes `generate_tier_0_summary "$mode" "$category" "$cite_id" "$op_summary" "$tier"` and `extract_tier_1_via_registry "$src_abs" "$text_file" "$REGISTRY_TSV"`. Both functions are this task's deliverables.
- `scripts/knowledge/lib/extract-manifest.sh` (from T02) — already wired into driver.
- `scripts/knowledge/lib/extract-binary-preservation.sh` (from T02) — already wired.
- T02's behavioural verifiers (`m036-p02-binary-preservation.sh`, `m036-p02-content-hash.sh`, `m036-p02-size-cap-external-pointer.sh`) become green at T03 close (T02 authored them but they couldn't pass without this task's helper).

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/format/registry.tsv` — registry rows used by `extract_tier_1_via_registry`.
- `scripts/dispatch/adapters/format/{markdown,pdf,docx,xlsx}.sh` — adapters invoked.
- `references/reference-source-types.yaml` — read by driver for default-tier resolution (T02 wired).
- `references/reference-frontmatter-contract.md` — chunk frontmatter shape (driver writes per this contract).
- `commands/ingest.md` — pattern template for `commands/extract.md` shape (read but not modified).

## Constraints

- Bash 3.2 / POSIX-sh per CON-2; no `declare -A`; no compound `(...)` subshells in the script bodies that would surface to the classifier.
- Tier 0 summary helper must NOT issue any LLM calls in P02 (CON-3). The `auto` mode is a hard error pointing at P03.
- Tier 1 dispatch via the registry honors the existing P01 adapter contract (positional input path; stdout = body text; xlsx adds `--out-dir`).
- No new host-tool dependencies introduced (Tier 1 leg uses the P01-blessed tools; Tier 2 not in scope).
- All verifier work in `mktemp -d` workspaces under `${TMPDIR:-/tmp}`. No project-tree mutation in verifiers.
- Path-collision check: every `create` deliverable confirmed not-on-disk at plan-authoring time.

## Notes

Order discipline:

- T02's `binary-preservation.sh` / `content-hash.sh` / `size-cap-external-pointer.sh` flip from amber to green at T03 close (the missing piece was `lib/extract-tier-0-summary.sh`). This is the standard cross-task pattern: code and verifier authored together; phase-suite enforces end-to-end PASS at phase close.
- Auto-loop's first-fail-retry semantic accommodates this: if the executor runs T02's verifiers first they'd fail because the driver source-line `. "$HERE/lib/extract-tier-0-summary.sh"` exits 1 on missing file. Once T03 lands the helper, those verifiers pass on retry.

Expected verifier output on success:

- `m036-p02-extract-md.sh` → `SUMMARY: m036-p02-extract-md.sh fail=0`, exit 0.
- `m036-p02-extract-pdf-host-aware.sh` → `SUMMARY: ... fail=0` (or `SKIP: pdftotext-absent` + exit 0).
- `m036-p02-extract-docx-host-aware.sh` → `SUMMARY: ... fail=0` (or `SKIP: pandoc-absent` + exit 0).
- `m036-p02-extract-command-shape.sh` → `SUMMARY: ... fail=0`, exit 0.
- `m036-p02-summary-mode-stub-vs-operator.sh` → `SUMMARY: ... fail=0`, exit 0.
- `m036-p02-tier-2-deferred-error.sh` → `SUMMARY: ... fail=0`, exit 0 (verifier expects non-zero exit *from the driver invocation it stages*, so the verifier itself exits 0 on success).

## Expected Output

Files created:

- `scripts/knowledge/lib/extract-tier-0-summary.sh` (~80 lines)
- `commands/extract.md` (~80 lines)
- `tools/verify/m036-p02-extract-md.sh`
- `tools/verify/m036-p02-extract-pdf-host-aware.sh`
- `tools/verify/m036-p02-extract-docx-host-aware.sh`
- `tools/verify/m036-p02-extract-command-shape.sh`
- `tools/verify/m036-p02-summary-mode-stub-vs-operator.sh`
- `tools/verify/m036-p02-tier-2-deferred-error.sh`
