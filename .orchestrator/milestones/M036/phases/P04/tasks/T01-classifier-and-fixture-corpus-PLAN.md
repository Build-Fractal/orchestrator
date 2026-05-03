---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M036"
name: "Reference fixture corpus + classifier helper + classifier shape verifiers"
depends_on: []
---

## Prerequisites

- P03 closed (`P03-SUMMARY.md` exists at `.orchestrator/milestones/M036/phases/P03/P03-SUMMARY.md`).
- `references/reference-taxonomy.md` exists (P00 T01 deliverable; the four-category SSOT).
- `references/reference-frontmatter-contract.md` exists (P00 T01 deliverable; FR-2 required-field SSOT).
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` exists (P00 T03 deliverable; the existing taxonomy + tier validator).

Verified at plan-authoring time: all four files present.

## Description

Land the fixture corpus + classifier helper that the rest of P04 consumes:

1. The fixture corpus at `tests/fixtures/m036-p04-reference-corpus/` — 6 hand-authored REF chunks across the 4 taxonomy categories (cms-rule × 2, training-material × 2, glossary × 1, regulatory-doc × 1) + 3 negative-path chunks under `_negative/<reason>/` subdirectories that the driver explicitly skips when walking the tree (only top-level taxonomy-category subdirectories are scanned). The fixtures are text-only (no binaries; CON-3 deterministic CI).
2. The classifier helper `scripts/knowledge/classify-reference.sh` — a pure helper lib (MEM004) that wraps the existing `tools/verify/lib/p00-validate-chunk-frontmatter.sh` and adds the FR-2 required-field presence check. Two pure functions: `classify_reference_required_fields <chunk-file>` (returns 0 if all six required fields present, 1 with stderr error naming missing fields) and `classify_reference_file <chunk-file>` (composes the required-field check + the existing taxonomy/tier validator; returns 0 if both pass, 1 otherwise).
3. Four shape verifiers under `tools/verify/m036-p04-*`: classifier-shape, classifier-rejects-unknown, classifier-rejects-missing-required, fixture-corpus-shape.

## Steps

### Step 1 — Author the valid fixture corpus

Create the four taxonomy-category subdirectories and 6 valid fixture chunks. The frontmatter shape mirrors the M036 `extract-reference.sh` chunk output exactly (same field order, same field names — the ingest layer must accept these chunks unchanged when extract-reference produces them).

Create `tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-01.md`:

```markdown
---
schema_version: "1.0"
type: reference-chunk
milestone: "M036"
id: "REF-cms-rule-fixture-01"
category: "cms-rule"
chunk_id: "REF-cms-rule-fixture-01"
cite_id: "fixture-01"
source: "cms"
published: "2024-09-01"
version: "fixture-v1"
tier: 2
content_hash: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
size_bytes: 0
summary_mode: "operator"
topic_tags: [pbj-staffing, cms-section-483-20]
applies_to_field: [staff_count, census]
scope_tags: "[project], [milestone:M036], [source:fixture-01]"
---

# CMS Rule Fixture 01 — PBJ Staffing Requirements

This is a fixture for the M036 P04 reference-ingest acceptance harness.
The body simulates a CMS regulatory rule excerpt covering the
nursing-staff-count and resident-census definitions.
```

Create `tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-02.md` — same shape, with `cite_id: "fixture-02"`, `id: "REF-cms-rule-fixture-02"`, `chunk_id: "REF-cms-rule-fixture-02"`, `topic_tags: [pbj-staffing, cms-section-483-30]`, distinct content_hash (any other 64-hex string), and a body referencing a different fixture excerpt. Keep tier=2.

Create `tests/fixtures/m036-p04-reference-corpus/training-material/REF-training-material-fixture-01.md` — `category: "training-material"`, `cite_id: "fixture-tm-01"`, `id: "REF-training-material-fixture-01"`, `chunk_id: "REF-training-material-fixture-01"`, `source: "sme-pbj-circle"`, `published: "2024-08-15"`, `version: "fixture-v1"`, `tier: 2`, distinct content_hash, `topic_tags: [pbj-staffing, training-2024-08]`, `applies_to_field: [staff_count]`. Body is a synthetic SME training excerpt.

Create `tests/fixtures/m036-p04-reference-corpus/training-material/REF-training-material-fixture-02.md` — same shape, `cite_id: "fixture-tm-02"`, `id: "REF-training-material-fixture-02"`, `chunk_id: "REF-training-material-fixture-02"`, distinct content_hash.

Create `tests/fixtures/m036-p04-reference-corpus/glossary/REF-glossary-fixture-01.md` — `category: "glossary"`, `cite_id: "glossary-pbj-2024"`, `id: "REF-glossary-fixture-01"`, `chunk_id: "REF-glossary-fixture-01"`, `source: "internal-glossary"`, `published: "2026-05-02"`, `version: "fixture-v1"`, `tier: 2`, distinct content_hash, `topic_tags: [definitions, pbj-staffing]`, `applies_to_field: [staff_count, census]`. Body is a glossary fixture with two term definitions.

Create `tests/fixtures/m036-p04-reference-corpus/regulatory-doc/REF-regulatory-doc-fixture-01.md` — `category: "regulatory-doc"`, `cite_id: "regulatory-cms-som-app-pp"`, `id: "REF-regulatory-doc-fixture-01"`, `chunk_id: "REF-regulatory-doc-fixture-01"`, `source: "cms"`, `published: "2024-06-01"`, `version: "fixture-v1"`, `tier: 1` (regulatory-doc default per `references/reference-source-types.yaml`), distinct content_hash, `topic_tags: [cms-som-app-pp]`, `applies_to_field: []`. Body is a synthetic regulatory excerpt.

Each chunk's frontmatter MUST include all of: `schema_version`, `type`, `milestone`, `id`, `category`, `chunk_id`, `cite_id`, `source`, `published`, `version`, `tier`, `content_hash`, `size_bytes`, `summary_mode`, `topic_tags`, `applies_to_field`, `scope_tags`. The `id:` field is the field `rebuild-index.sh::fm_field` reads; it must equal the file's `chunk_id`.

### Step 2 — Author the negative-path fixtures

Create `tests/fixtures/m036-p04-reference-corpus/_negative/unknown-category/REF-blog-post-fixture.md`:

```markdown
---
schema_version: "1.0"
type: reference-chunk
milestone: "M036"
id: "REF-blog-post-fixture"
category: "blog-post"
chunk_id: "REF-blog-post-fixture"
cite_id: "blog-fixture-01"
source: "external-blog"
published: "2024-01-01"
version: "fixture-v1"
tier: 1
content_hash: "1111111111111111111111111111111111111111111111111111111111111111"
size_bytes: 0
summary_mode: "operator"
topic_tags: []
applies_to_field: []
scope_tags: "[project]"
---

# Blog Post Fixture (NEGATIVE — taxonomy rejection)

This chunk's `category: "blog-post"` is outside the M036 closed taxonomy.
The classifier MUST reject this file.
```

Create `tests/fixtures/m036-p04-reference-corpus/_negative/missing-source/REF-cms-rule-no-source.md` — same general shape but **omit the `source:` field entirely** from the frontmatter. Set `category: "cms-rule"` (valid taxonomy) so the rejection path is the FR-2 required-field check, not the FR-1 taxonomy check. Body line: "This chunk's `source:` field is missing. Classifier MUST reject on FR-2 required-field violation."

Create `tests/fixtures/m036-p04-reference-corpus/_negative/tier-2-block/REF-cms-rule-blocked.md` — full valid frontmatter (passes FR-1 + FR-2), with `category: "cms-rule"`, `cite_id: "fixture-blocked-01"`, `id: "REF-cms-rule-blocked"`, `chunk_id: "REF-cms-rule-blocked"`, `tier: 2`, AND an additional frontmatter field `tier_2_verdict: "BLOCK"`. Body line: "This chunk simulates a Tier 2 conversus-gate BLOCK verdict (P03/T03). Ingest MUST emit BLOCKED: advisory and MUST NOT promote a `.structured.md` sibling."

### Step 3 — Author the classifier helper

Create `scripts/knowledge/classify-reference.sh`:

```bash
#!/usr/bin/env bash
# scripts/knowledge/classify-reference.sh -- M036 P04 T01.
# Pure helper lib (MEM004): no top-level execution; safe to source.
# Exposes two pure functions for the reference-ingest classifier path:
#
#   classify_reference_required_fields <chunk-file>
#     Asserts FR-2 required-field presence. Returns 0 if all six fields
#     present (source, published, version, cite_id, topic_tags,
#     applies_to_field), 1 if any missing. Errors to stderr name the
#     missing field(s).
#
#   classify_reference_file <chunk-file>
#     Composes the FR-2 required-field check with the existing P00 T03
#     taxonomy + tier validator (tools/verify/lib/p00-validate-chunk-
#     frontmatter.sh). Returns 0 if both pass, 1 if either fails.
#
# Bash 3.2 / POSIX-sh per CON-2. No top-level I/O — sourceable from any
# context. AD-19: invocation form is `bash scripts/knowledge/classify-
# reference.sh` (not directly callable; lib only). The driver
# `scripts/knowledge/ingest-reference.sh` sources this file.

# Guard against accidental direct execution.
if [ "${0##*/}" = "classify-reference.sh" ] && [ -z "${BASH_SOURCE[0]:-}" -o "${BASH_SOURCE[0]:-}" = "$0" ]; then
  : # sourced; OK
fi

# classify_reference_required_fields <chunk-file>
classify_reference_required_fields() {
  local chunk="$1"
  if [ -z "$chunk" ] || [ ! -f "$chunk" ]; then
    echo "classify-reference: chunk file missing: $chunk" >&2
    return 1
  fi
  local missing=""
  for field in source published version cite_id topic_tags applies_to_field; do
    if ! grep -qE "^${field}:" "$chunk"; then
      if [ -z "$missing" ]; then
        missing="$field"
      else
        missing="$missing,$field"
      fi
    fi
  done
  if [ -n "$missing" ]; then
    echo "classify-reference: required field(s) missing in $chunk: $missing" >&2
    return 1
  fi
  return 0
}

# classify_reference_file <chunk-file>
classify_reference_file() {
  local chunk="$1"
  if [ -z "$chunk" ] || [ ! -f "$chunk" ]; then
    echo "classify-reference: chunk file missing: $chunk" >&2
    return 1
  fi
  # FR-2 required-field check.
  if ! classify_reference_required_fields "$chunk"; then
    return 1
  fi
  # FR-1 taxonomy + tier validator (delegates to existing P00 T03 lib).
  local root
  root="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
  local validator="$root/tools/verify/lib/p00-validate-chunk-frontmatter.sh"
  if [ ! -f "$validator" ]; then
    echo "classify-reference: validator missing: $validator" >&2
    return 1
  fi
  if ! bash "$validator" "$chunk" >/dev/null 2>&1; then
    echo "classify-reference: taxonomy/tier validation failed for $chunk" >&2
    return 1
  fi
  return 0
}
```

Make executable: `chmod +x scripts/knowledge/classify-reference.sh`.

### Step 4 — Author the classifier shape verifier

Create `tools/verify/m036-p04-classifier-shape.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-classifier-shape.sh -- M036 P04 T01.
# Asserts scripts/knowledge/classify-reference.sh exists, is executable,
# and exposes the two required pure functions
# (classify_reference_required_fields, classify_reference_file) plus
# the delegation to P00 T03's chunk-frontmatter validator.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/classify-reference.sh"
fail=0
if [ -f "$LIB" ]; then
  echo "PASS: lib exists $LIB"
else
  echo "FAIL: lib missing $LIB"
  fail=$((fail + 1))
fi
if [ -x "$LIB" ]; then
  echo "PASS: lib executable"
else
  echo "FAIL: lib not executable"
  fail=$((fail + 1))
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$LIB"; then
    echo "PASS: '$pat' in $(basename "$LIB")"
  else
    echo "FAIL: '$pat' missing in $(basename "$LIB")"
    fail=$((fail + 1))
  fi
}
checkpat "classify_reference_required_fields()"
checkpat "classify_reference_file()"
checkpat "p00-validate-chunk-frontmatter.sh"
checkpat "source published version cite_id topic_tags applies_to_field"
checkpat "MEM004"
echo "SUMMARY: m036-p04-classifier-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 5 — Author the classifier-rejects-unknown verifier

Create `tools/verify/m036-p04-classifier-rejects-unknown.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-classifier-rejects-unknown.sh -- M036 P04 T01.
# Drives classify_reference_file against the unknown-category negative
# fixture. Asserts return code 1 + stderr names "taxonomy".
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/classify-reference.sh"
FX="$ROOT/tests/fixtures/m036-p04-reference-corpus/_negative/unknown-category/REF-blog-post-fixture.md"
fail=0
if [ ! -f "$LIB" ] || [ ! -f "$FX" ]; then
  echo "FAIL: prerequisite missing (LIB=$LIB FX=$FX)"
  echo "SUMMARY: m036-p04-classifier-rejects-unknown.sh fail=1"
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"
set +e
classify_reference_file "$FX" 2>/tmp/m036-p04-classifier-rejects-unknown-err.$$.txt
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "PASS: classifier rejected unknown-category fixture (rc=$rc)"
else
  echo "FAIL: classifier accepted unknown-category fixture (rc=$rc)"
  fail=$((fail + 1))
fi
if grep -qF -e "taxonomy" /tmp/m036-p04-classifier-rejects-unknown-err.$$.txt; then
  echo "PASS: stderr names 'taxonomy'"
else
  echo "FAIL: stderr does not name 'taxonomy'"
  fail=$((fail + 1))
fi
rm -f /tmp/m036-p04-classifier-rejects-unknown-err.$$.txt
echo "SUMMARY: m036-p04-classifier-rejects-unknown.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 6 — Author the classifier-rejects-missing-required verifier

Create `tools/verify/m036-p04-classifier-rejects-missing-required.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-classifier-rejects-missing-required.sh -- M036 P04 T01.
# Drives classify_reference_required_fields against the missing-source
# negative fixture. Asserts return code 1 + stderr names "source".
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/classify-reference.sh"
FX="$ROOT/tests/fixtures/m036-p04-reference-corpus/_negative/missing-source/REF-cms-rule-no-source.md"
fail=0
if [ ! -f "$LIB" ] || [ ! -f "$FX" ]; then
  echo "FAIL: prerequisite missing (LIB=$LIB FX=$FX)"
  echo "SUMMARY: m036-p04-classifier-rejects-missing-required.sh fail=1"
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"
set +e
classify_reference_required_fields "$FX" 2>/tmp/m036-p04-classifier-rejects-missing-required-err.$$.txt
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "PASS: classifier rejected missing-source fixture (rc=$rc)"
else
  echo "FAIL: classifier accepted missing-source fixture (rc=$rc)"
  fail=$((fail + 1))
fi
if grep -qF -e "source" /tmp/m036-p04-classifier-rejects-missing-required-err.$$.txt; then
  echo "PASS: stderr names 'source'"
else
  echo "FAIL: stderr does not name 'source'"
  fail=$((fail + 1))
fi
rm -f /tmp/m036-p04-classifier-rejects-missing-required-err.$$.txt
echo "SUMMARY: m036-p04-classifier-rejects-missing-required.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 7 — Author the fixture-corpus shape verifier

Create `tools/verify/m036-p04-fixture-corpus-shape.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-fixture-corpus-shape.sh -- M036 P04 T01.
# Asserts the P04 reference-corpus fixture is on disk: 6 valid REF
# chunks across the 4 taxonomy categories + 3 negative-path chunks
# under _negative/<reason>/.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
FX="$ROOT/tests/fixtures/m036-p04-reference-corpus"
fail=0
checkfile() {
  local p="$1"
  if [ -f "$p" ]; then
    echo "PASS: exists $p"
  else
    echo "FAIL: missing $p"
    fail=$((fail + 1))
  fi
}
# Valid fixtures (one per file across the 4 taxonomy categories).
checkfile "$FX/cms-rule/REF-cms-rule-fixture-01.md"
checkfile "$FX/cms-rule/REF-cms-rule-fixture-02.md"
checkfile "$FX/training-material/REF-training-material-fixture-01.md"
checkfile "$FX/training-material/REF-training-material-fixture-02.md"
checkfile "$FX/glossary/REF-glossary-fixture-01.md"
checkfile "$FX/regulatory-doc/REF-regulatory-doc-fixture-01.md"
# Negative fixtures (under _negative/ — driver does NOT auto-walk).
checkfile "$FX/_negative/unknown-category/REF-blog-post-fixture.md"
checkfile "$FX/_negative/missing-source/REF-cms-rule-no-source.md"
checkfile "$FX/_negative/tier-2-block/REF-cms-rule-blocked.md"
# Frontmatter-shape spot-checks on a representative valid fixture.
SAMPLE="$FX/cms-rule/REF-cms-rule-fixture-01.md"
if [ -f "$SAMPLE" ]; then
  for pat in "category: \"cms-rule\"" "cite_id: \"fixture-01\"" "tier: 2" "topic_tags:" "applies_to_field:"; do
    if grep -qF -e "$pat" "$SAMPLE"; then
      echo "PASS: '$pat' in $(basename "$SAMPLE")"
    else
      echo "FAIL: '$pat' missing in $(basename "$SAMPLE")"
      fail=$((fail + 1))
    fi
  done
fi
# Tier-2-block fixture must declare the BLOCK verdict.
BLOCKED="$FX/_negative/tier-2-block/REF-cms-rule-blocked.md"
if [ -f "$BLOCKED" ]; then
  if grep -qF -e 'tier_2_verdict: "BLOCK"' "$BLOCKED"; then
    echo "PASS: BLOCK fixture declares tier_2_verdict"
  else
    echo "FAIL: BLOCK fixture missing tier_2_verdict"
    fail=$((fail + 1))
  fi
fi
echo "SUMMARY: m036-p04-fixture-corpus-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Make all four verifiers executable: `chmod +x tools/verify/m036-p04-{classifier-shape,classifier-rejects-unknown,classifier-rejects-missing-required,fixture-corpus-shape}.sh`.

## Must-Haves

(Subset of phase must-haves T01 addresses)

- `scripts/knowledge/classify-reference.sh` exists, is executable, and exposes pure helper functions.
- A fixture chunk whose `category:` is outside the M036 taxonomy is rejected.
- A fixture chunk missing a required frontmatter field is rejected.
- The fixture corpus exists with 6 valid REF chunks across the four taxonomy categories + 3 negative-path chunks.

## Verification

```bash
bash tools/verify/m036-p04-classifier-shape.sh
```

```bash
bash tools/verify/m036-p04-classifier-rejects-unknown.sh
```

```bash
bash tools/verify/m036-p04-classifier-rejects-missing-required.sh
```

```bash
bash tools/verify/m036-p04-fixture-corpus-shape.sh
```

## Inputs

### From Previous Tasks

(none — T01 is the foundational task in P04)

### From Disk (Pre-existing)

- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` — P00 T03 deliverable. CLI shape: `bash <path> <frontmatter-or-chunk-file>`. Reads `category:` and `tier:` fields; rejects if `category` is outside `cms-rule|training-material|glossary|regulatory-doc` or `tier` is outside `{0,1,2}`. Exit 0 on accept, 1 on reject. Stdout: `ACCEPT: ...` / `REJECT: ...` lines. The classifier helper delegates to this validator for FR-1 (taxonomy) + tier-enum checks; T01's helper only adds the FR-2 required-field presence check.
- `references/reference-taxonomy.md` — the four-category SSOT. Categories: `cms-rule`, `training-material`, `glossary`, `regulatory-doc`. T01's fixture corpus uses each.
- `references/reference-frontmatter-contract.md` — the FR-2 required-field SSOT. Six fields: `source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`. T01's classifier helper enforces presence of these.
- `references/reference-source-types.yaml` — per-category default-tier mapping. `cms-rule: 2`, `training-material: 2`, `glossary: 2`, `regulatory-doc: 1`. The fixture corpus matches these defaults.

## Constraints

- CON-2 (Bash 3.2 / POSIX-sh).
- CON-3 (text-only fixtures; no binaries).
- CON-5 (no spec-chunk schema change — REF-* fixture frontmatter is additive on top of the spec-chunk frontmatter contract; existing SPEC-* fixtures elsewhere in `tests/fixtures/` remain untouched).
- AD-19 single-script-file shape for verifier `Check:` invocations.
- MEM004 pure-lib pattern for `classify-reference.sh` (no top-level I/O; sourceable safely).
- MEM001 structured-stdout protocol (verifiers emit `PASS:` / `FAIL:` / `SUMMARY:` prefix lines; errors to stderr).
- Verifier filename milestone-prefixed slug `m036-p04-*` per the post-M031 plan-phase contract.
- Verifiers use `grep -qF -e "$pat"` (not `grep -qF "$pat"`) so leading-dash tokens are not misinterpreted as flags by BSD-grep on macOS — pattern carried from M036/P02 + M036/P03.

## Expected Output

After T01 completes:

- 9 fixture markdown files exist under `tests/fixtures/m036-p04-reference-corpus/` (6 valid + 3 negative-path).
- `scripts/knowledge/classify-reference.sh` exists and is executable.
- 4 new executable verifier scripts under `tools/verify/m036-p04-*`.
- All four verifiers exit 0 on this branch.

## Notes

The classifier helper deliberately does NOT validate the body content (e.g., whether `content_hash` matches the actual body sha256) — that's idempotency-gate territory and lives in the driver (T02). Classifier scope is frontmatter-shape only: required-field presence + taxonomy/tier validity. This matches the spec-chunk classifier's separation of concerns (`scripts/knowledge/ingest-spec.sh` validates section shape; `rebuild-index.sh` computes the hash).

The `_negative/` subdirectory naming convention is read by T02's driver: when walking the reference root, the driver only descends into directories whose basename matches one of the four taxonomy categories. Anything under `_negative/` (or any other non-taxonomy basename) is silently skipped. This keeps the negative fixtures ergonomically co-located with the positive corpus without polluting the ingest pass.

The `id:` frontmatter field is required for `rebuild-index.sh::fm_field` to discover the chunk. The fixtures set `id:` equal to `chunk_id:` (`REF-<category>-<cite_id>`); this is the same convention `extract-reference.sh` will use after the corresponding amendment in a future phase if needed (P02's existing chunk emitter writes `chunk_id:` but not `id:` — operators relying on the rebuild-index path may need that follow-up; the P04 fixture corpus pre-bakes both fields so the index pickup is unambiguous and T02's idempotency path can read either).
