---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M036"
name: "Manifest contract reference + 3-doc fixture corpus + .gitignore _originals/ entry"
depends_on: []
---

## Prerequisites

This task is the entry point of P02 and consumes only P00/P01 deliverables (already on disk):

- `references/reference-taxonomy.md` (P00) — the four categories (`cms-rule`, `training-material`, `glossary`, `regulatory-doc`).
- `references/reference-source-types.yaml` (P00) — per-category default tier (used by manifest contract cross-reference).
- `references/reference-frontmatter-contract.md` (P00) — chunk frontmatter SSOT (used by manifest contract cross-reference).
- `tests/fixtures/m036-tier-1-adapters/sample.pdf` and `sample.docx` (P01) — real binary fixtures byte-copied into `tests/fixtures/m036/`.
- `.gitignore` (project root) — exists; append-only modification.

Confirmed on disk at plan-authoring time via `ls -la`.

## Description

Create the manifest contract reference doc, the fixture manifest, the 3-doc fixture corpus, and the `.gitignore` `_originals/` entry. This task lands the *declarative surface* P02 needs before the driver is authored in T02. Three shape verifiers gate the surface.

The fixture manifest declares 3 documents:

1. A `cms-rule` PDF (`sample.pdf`, copied from P01) at `tier: 1`, `summary_mode: operator`, with operator-supplied summary string.
2. A `training-material` DOCX (`sample.docx`, copied from P01) at `tier: 1`, `summary_mode: operator`, with operator-supplied summary string.
3. A `glossary` markdown file (`sample.md`, freshly authored) at `tier: 0`, `summary_mode: operator`, with operator-supplied summary string.

This corpus mix exercises three of the four taxonomy categories and three formats (PDF / DOCX / MD), all at `summary_mode: operator` so CI runs are deterministic and require no LLM provider (CON-3).

## Steps

### 1. Author `references/extract-manifest-contract.md`

Create the file with this exact content (it is a SSOT — Principle XI; consumers read this single doc, not duplicated inline schemas):

```markdown
---
schema_version: "1.0"
type: extract-manifest-contract
milestone: "M036"
phase: "P02"
created_at: "2026-05-02"
---

# Extract Manifest Contract (M036 SSOT)

The `orchestrator:extract` command (see `commands/extract.md`) consumes
an extraction manifest declaring per-document tier targets, summary
modes, and provenance frontmatter. This file is the single source of
truth (Principle XI) for the manifest schema. Consumers:

- `scripts/knowledge/extract-reference.sh` — the driver. Reads + validates.
- `scripts/knowledge/lib/extract-manifest.sh` — pure parser helpers.

Adding or changing a manifest field requires a follow-on M036 D-row in
`.orchestrator/DECISIONS.md` and a coordinated update to driver + lib
helpers + this contract in lockstep.

## Top-Level Fields

- `schema_version` — string, currently `"1.0"`.
- `type` — string, currently `"extract-manifest"`.
- `milestone` — string. Identifies the consumer's milestone for
  attribution in `unit_close` records (see FR-19, P03).
- `size_cap_bytes` — integer (default `10485760` = 10 MiB). Per CON-7,
  binaries above this cap record an `external_pointer:` instead of
  being copied into `_originals/`. Per-document override available via
  `size_cap_bytes_override:` in the document record.
- `documents:` — YAML list of per-document records (see Per-Document
  Fields below).

## Per-Document Fields (each list entry under `documents:`)

Required:

- `cite_id` — unique stable identifier. Becomes the chunk slug
  (`REF-<category>-<cite_id>`). Must be unique within a manifest
  pass; duplicates rejected per spec Edge Cases.
- `source_path` — relative path to the source binary, resolved against
  the manifest's directory (or absolute path).
- `category` — one of `cms-rule|training-material|glossary|regulatory-doc`
  (see `references/reference-taxonomy.md`). Out-of-taxonomy values
  rejected by `tools/verify/lib/p00-validate-chunk-frontmatter.sh`.
- `source` — operator-facing identifier of the publishing body (per
  `references/reference-frontmatter-contract.md`).
- `published` — `YYYY-MM-DD`.
- `version` — free-form string.
- `topic_tags` — YAML list (may be empty).
- `applies_to_field` — YAML list (may be empty).

Optional:

- `tier` — `0|1|2`. When omitted, the driver resolves from
  `references/reference-source-types.yaml` per category (FR-17).
- `summary_mode` — `operator|stub|auto` (see Summary Modes below).
  Default: `operator`.
- `summary` — operator-supplied summary text (required when
  `summary_mode: operator`).
- `size_cap_bytes_override` — integer, per-document override of the
  manifest-level `size_cap_bytes`.

## Summary Modes (P02 scope)

- `operator` — manifest entry's `summary:` string is written to the
  chunk frontmatter verbatim. Required field is `summary:`. Used in
  CI and for hand-authored summaries.
- `stub` — driver writes a deterministic placeholder summary
  (`"[stub-summary] <category>: <cite_id>"`). Used for smoke tests
  and Tier-2-pending docs that the operator hasn't yet annotated.
- `auto` — driver routes the summary call through the Tier 2 LLM
  pipeline. **NOT IMPLEMENTED in P02** — driver exits non-zero with a
  stderr message naming "P03" and "not implemented". P03 wires the
  conversus-gated Tier 2 path that fills this seam.

## Default-Tier Resolution

When a document record omits `tier:`, the driver reads
`references/reference-source-types.yaml` and resolves the category's
`default_tier`. For the launch taxonomy:

- `cms-rule` → 2
- `training-material` → 2
- `glossary` → 2
- `regulatory-doc` → 1

Per-document `tier:` overrides any default.

## Tier Output Layout (P02 = Tier 0/1)

For each document the driver emits:

- `_originals/<source>/<basename(source_path)>` — byte-identical copy
  of the binary, OR an `external_pointer:` recorded in chunk
  frontmatter when the binary exceeds `size_cap_bytes`. (FR-14, CON-7.)
- `knowledge/reference/<category>/REF-<category>-<cite_id>.md` — the
  chunk file (manifest entry + Tier 0 summary).
- `knowledge/reference/<category>/REF-<category>-<cite_id>.text.md` —
  Tier 1 plain-text extraction (only when `tier: 1` or `tier: 2`).
- `knowledge/reference/<category>/REF-<category>-<cite_id>.structured.md`
  — Tier 2 structured Markdown. **Authored in P03**, not P02.

## Idempotency

Re-running the driver on an unchanged manifest produces zero
modifications to the chunk store and the `_originals/` tree. Content
hash gates re-extraction at every tier (CON-4, FR-9). Output: every
doc emits `SKIPPED:` on the second run.

## Cross-References

- Closed taxonomy: `references/reference-taxonomy.md`.
- Per-category default tier: `references/reference-source-types.yaml`.
- Chunk frontmatter shape: `references/reference-frontmatter-contract.md`.
- Spec authority: `specs/033-reference-corpus-ingest/spec.md` (FR-14, FR-16, FR-17, CON-4, CON-7).
```

### 2. Create the fixture manifest at `tests/fixtures/m036/extract-manifest.yaml`

```yaml
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "cms-rule-fixture-01"
    source_path: "sample.pdf"
    category: "cms-rule"
    source: "cms"
    published: "2024-09-01"
    version: "2024-Q3"
    topic_tags: ["pbj-staffing", "cms-§483.20"]
    applies_to_field: ["staff_count"]
    tier: 1
    summary_mode: "operator"
    summary: "Fixture cms-rule PDF for M036 P02 extract harness."

  - cite_id: "training-pbj-fixture-01"
    source_path: "sample.docx"
    category: "training-material"
    source: "sme-pbj-circle"
    published: "2024-08-15"
    version: "2024-08"
    topic_tags: ["pbj-staffing"]
    applies_to_field: []
    tier: 1
    summary_mode: "operator"
    summary: "Fixture training-material DOCX for M036 P02 extract harness."

  - cite_id: "glossary-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2024-01-01"
    version: "2024-01"
    topic_tags: ["pbj-staffing", "definitions"]
    applies_to_field: ["staff_count", "census"]
    tier: 0
    summary_mode: "operator"
    summary: "Fixture glossary markdown for M036 P02 extract harness."
```

### 3. Author the markdown fixture at `tests/fixtures/m036/sample.md`

```markdown
# M036 Glossary Fixture

This is a synthetic glossary fixture used by the M036 P02 extract harness.

- **staff_count** — total nurse + aide hours per resident day, per CMS PBJ.
- **census** — total resident-day count for the reporting period.
```

### 4. Byte-copy the P01 PDF + DOCX fixtures

```bash
cp tests/fixtures/m036-tier-1-adapters/sample.pdf  tests/fixtures/m036/sample.pdf
cp tests/fixtures/m036-tier-1-adapters/sample.docx tests/fixtures/m036/sample.docx
```

Both files are <2 KiB and have already been exercised against the live Tier 1 adapters in P01 (verifier `m036-p01-pdf-adapter.sh` + `m036-p01-docx-adapter.sh` reported PASS where host tools present). Re-using them avoids re-authoring fragile minimal binaries.

### 5. Append the `_originals/` line to `.gitignore`

Add the following two lines to the end of `.gitignore` (idempotency: skip if already present):

```
# M036 P02: orchestrator-owned binary preservation under Tier 0. CON-7 (b) — operators opt-in by listing exceptions.
.orchestrator/knowledge/reference/_originals/
```

### 6. Author `tools/verify/m036-p02-manifest-contract-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-manifest-contract-shape.sh -- M036 P02 T01.
# Asserts references/extract-manifest-contract.md exists with the
# required headings + schema field declarations. Single-script-file
# shape per AD-19 (no compound chains at the invocation layer).
# Bash 3.2 / POSIX-sh per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DOC="$ROOT/references/extract-manifest-contract.md"
fail=0
if [ ! -f "$DOC" ]; then
  echo "FAIL: missing $DOC"
  exit 1
fi
check() {
  local pattern="$1"
  if grep -qF "$pattern" "$DOC"; then
    echo "PASS: contains '$pattern'"
  else
    echo "FAIL: missing '$pattern'"
    fail=$((fail + 1))
  fi
}
check "## Top-Level Fields"
check "## Per-Document Fields"
check "## Summary Modes"
check "## Default-Tier Resolution"
check "size_cap_bytes"
check "summary_mode"
check "cite_id"
check "category"
check "topic_tags"
check "applies_to_field"
check "operator"
check "stub"
check "auto"
echo "SUMMARY: m036-p02-manifest-contract-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 7. Author `tools/verify/m036-p02-fixture-manifest-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-fixture-manifest-shape.sh -- M036 P02 T01.
# Asserts the fixture manifest declares 3 documents covering 3 of the
# four taxonomy categories (cms-rule, training-material, glossary).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
M="$ROOT/tests/fixtures/m036/extract-manifest.yaml"
fail=0
if [ ! -f "$M" ]; then
  echo "FAIL: missing $M"
  exit 1
fi
check() {
  local pattern="$1"
  if grep -qF "$pattern" "$M"; then
    echo "PASS: contains '$pattern'"
  else
    echo "FAIL: missing '$pattern'"
    fail=$((fail + 1))
  fi
}
check "documents:"
check "cite_id:"
check "category: \"cms-rule\""
check "category: \"training-material\""
check "category: \"glossary\""
check "summary_mode:"
check "summary:"
echo "SUMMARY: m036-p02-fixture-manifest-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 8. Author `tools/verify/m036-p02-fixture-corpus-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-fixture-corpus-shape.sh -- M036 P02 T01.
# Asserts the 3-doc fixture corpus exists (PDF, DOCX, MD).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DIR="$ROOT/tests/fixtures/m036"
fail=0
check() {
  local p="$1"
  if [ -f "$DIR/$p" ]; then
    echo "PASS: exists $p"
  else
    echo "FAIL: missing $p"
    fail=$((fail + 1))
  fi
}
check "extract-manifest.yaml"
check "sample.pdf"
check "sample.docx"
check "sample.md"
echo "SUMMARY: m036-p02-fixture-corpus-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 9. Make all three verifiers executable

```bash
chmod +x tools/verify/m036-p02-manifest-contract-shape.sh \
         tools/verify/m036-p02-fixture-manifest-shape.sh \
         tools/verify/m036-p02-fixture-corpus-shape.sh
```

## Must-Haves

This task addresses the following P02 must-haves:

- The manifest contract reference doc declares the required top-level + per-document fields and the summary-mode enum.
- The fixture manifest at `tests/fixtures/m036/extract-manifest.yaml` validates against the manifest contract (3 documents covering 3 categories).
- The 3-doc fixture corpus exists with one binary per format.

## Verification

```bash
bash tools/verify/m036-p02-manifest-contract-shape.sh
bash tools/verify/m036-p02-fixture-manifest-shape.sh
bash tools/verify/m036-p02-fixture-corpus-shape.sh
```

## Inputs

### From Previous Tasks

None — T01 is the entry point of P02.

### From Disk (Pre-existing)

- `references/reference-taxonomy.md` — closed-taxonomy SSOT. Used: cross-reference target in the manifest contract; the four category values feed the fixture manifest content.
- `references/reference-source-types.yaml` — per-category default-tier SSOT. Used: cross-reference target documenting how the driver resolves missing `tier:` fields.
- `references/reference-frontmatter-contract.md` — chunk frontmatter SSOT. Used: cross-reference target documenting the chunk-output shape.
- `tests/fixtures/m036-tier-1-adapters/sample.pdf` — P01 fixture PDF, byte-copied to `tests/fixtures/m036/sample.pdf`.
- `tests/fixtures/m036-tier-1-adapters/sample.docx` — P01 fixture DOCX, byte-copied to `tests/fixtures/m036/sample.docx`.

## Constraints

- Bash 3.2 / POSIX-sh in all verifier scripts (CON-2).
- All three verifiers use single-script-file invocation shape inside their own bodies; only `grep -qF`, `[ -f ]`, and structured stdout (`PASS:` / `FAIL:` / `SUMMARY:`) — no compound shapes.
- The `_originals/` gitignore line is a CON-7 (b) requirement (operators opt-in to commit binaries).
- No live LLM calls; CON-3 — `summary_mode: operator` is the only mode the fixture manifest uses.
- Path-collision check: every `create` deliverable confirmed not-on-disk at plan-authoring time.

## Notes

Expected verifier output on success:

- `m036-p02-manifest-contract-shape.sh` → `SUMMARY: m036-p02-manifest-contract-shape.sh fail=0`, exit 0.
- `m036-p02-fixture-manifest-shape.sh` → `SUMMARY: m036-p02-fixture-manifest-shape.sh fail=0`, exit 0.
- `m036-p02-fixture-corpus-shape.sh` → `SUMMARY: m036-p02-fixture-corpus-shape.sh fail=0`, exit 0.

The `(min N lines, contains P)` discipline of `scripts/verify/check-must-haves.sh` will additionally gate `references/extract-manifest-contract.md` (≥50 lines, contains "summary_mode") and `tests/fixtures/m036/extract-manifest.yaml` (≥20 lines, contains "documents:") at phase-close time.

## Expected Output

Files created:

- `references/extract-manifest-contract.md` (~120 lines)
- `tests/fixtures/m036/extract-manifest.yaml` (~30 lines)
- `tests/fixtures/m036/sample.md` (5 lines)
- `tests/fixtures/m036/sample.pdf` (byte-copy of P01 fixture, ~600 bytes)
- `tests/fixtures/m036/sample.docx` (byte-copy of P01 fixture, ~960 bytes)
- `tools/verify/m036-p02-manifest-contract-shape.sh`
- `tools/verify/m036-p02-fixture-manifest-shape.sh`
- `tools/verify/m036-p02-fixture-corpus-shape.sh`

Files modified:

- `.gitignore` — append two lines (comment + path).
