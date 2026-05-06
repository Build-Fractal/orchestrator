#!/usr/bin/env bash
# tests/test-extract-frontmatter-fields.sh -- regression coverage for the
# FR-2 required-field emission contract of scripts/knowledge/extract-
# reference.sh. Drives the extractor end-to-end against a markdown-only
# manifest that exercises three list-shape cases (inline-list, block-list,
# empty-list) and asserts that every produced REF-*.md chunk contains
# all six FR-2 required frontmatter fields.
#
# Closes the test-coverage hole that allowed extract-reference.sh to
# ship without ever emitting topic_tags / applies_to_field — the two
# required list fields that classify-reference.sh checks for at ingest.
#
# Emits BATTERY: pass=N fail=N skip=N as last stdout line.
# Exit 0 iff fail=0.
#
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu

ROOT="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-extract-fm-fields.XXXXXX")"
trap 'rm -rf "$WS"' EXIT

pass=0
fail=0
skip=0

step_pass() { echo "PASS: $1"; pass=$((pass + 1)); }
step_fail() { echo "FAIL: $1"; fail=$((fail + 1)); }

if [ ! -f "$DRV" ]; then
  step_fail "driver missing: $DRV"
  echo "BATTERY: pass=$pass fail=$fail skip=$skip"
  exit 1
fi

cp "$ROOT/tests/fixtures/m036/sample.md" "$WS/source-inline.md"
cp "$ROOT/tests/fixtures/m036/sample.md" "$WS/source-block.md"
cp "$ROOT/tests/fixtures/m036/sample.md" "$WS/source-empty.md"

# Three docs cover three list-frontmatter shapes:
#   doc1: inline-list topic_tags + inline-list applies_to_field
#   doc2: block-list topic_tags + empty applies_to_field
#   doc3: empty topic_tags + block-list applies_to_field
cat > "$WS/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "fm-fields-inline"
    source_path: "source-inline.md"
    category: "glossary"
    source: "internal-test"
    published: "2026-05-06"
    version: "1"
    topic_tags: ["pbj-staffing", "definitions"]
    applies_to_field: ["staff_count", "census"]
    tier: 1
    summary_mode: "operator"
    summary: "Inline-list shape fixture."

  - cite_id: "fm-fields-block"
    source_path: "source-block.md"
    category: "glossary"
    source: "internal-test"
    published: "2026-05-06"
    version: "1"
    topic_tags:
      - pbj-staffing
      - cms-rules
    applies_to_field: []
    tier: 1
    summary_mode: "operator"
    summary: "Block-list topic_tags + empty applies_to_field fixture."

  - cite_id: "fm-fields-empty-tags"
    source_path: "source-empty.md"
    category: "glossary"
    source: "internal-test"
    published: "2026-05-06"
    version: "1"
    topic_tags: []
    applies_to_field:
      - staff_count
    tier: 1
    summary_mode: "operator"
    summary: "Empty topic_tags + block-list applies_to_field fixture."
YAML

REF="$WS/ref"
ORIG="$WS/orig"

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WS/manifest.yaml" \
  --reference-root "$REF" --originals-root "$ORIG" \
  >"$WS/extract.stdout" 2>"$WS/extract.stderr" || {
    step_fail "extract-reference.sh exited non-zero"
    echo "  stderr:"
    sed -e 's/^/    /' "$WS/extract.stderr"
    echo "BATTERY: pass=$pass fail=$fail skip=$skip"
    exit 1
  }
step_pass "driver exit 0"

# All three chunks should be EXTRACTED (not SKIPPED) on first run.
for cid in fm-fields-inline fm-fields-block fm-fields-empty-tags; do
  if grep -qF -e "EXTRACTED: $cid" "$WS/extract.stdout"; then
    step_pass "EXTRACTED emitted for $cid"
  else
    step_fail "EXTRACTED missing for $cid"
  fi
done

# All six FR-2 required fields present in every produced chunk.
required_fields="cite_id source published version topic_tags applies_to_field"
chunk_count=0
for chunk in "$REF"/glossary/REF-*.md; do
  case "$(basename "$chunk")" in
    *.text.md|*.structured.md) continue ;;
  esac
  [ -f "$chunk" ] || continue
  chunk_count=$((chunk_count + 1))
  base="$(basename "$chunk")"
  for field in $required_fields; do
    if grep -qE "^${field}:" "$chunk"; then
      step_pass "$base has $field"
    else
      step_fail "$base missing $field"
    fi
  done
done

if [ "$chunk_count" -eq 0 ]; then
  step_fail "no REF-*.md chunks produced under $REF/glossary"
fi

# Spot-check that list-field values actually round-trip (not the bare
# scalar mangling fallback that `extract_manifest_doc_field` would
# produce — that helper would have printed `["pbj-staffing", ...]` as a
# single quoted string, defeating any list-shape downstream consumer).
chunk_inline="$REF/glossary/REF-glossary-fm-fields-inline.md"
if [ -f "$chunk_inline" ]; then
  if grep -qE '^topic_tags: \["pbj-staffing", "definitions"\]$' "$chunk_inline"; then
    step_pass "inline topic_tags round-tripped intact"
  else
    step_fail "inline topic_tags malformed (got: $(grep '^topic_tags:' "$chunk_inline" || echo NONE))"
  fi
  if grep -qE '^applies_to_field: \["staff_count", "census"\]$' "$chunk_inline"; then
    step_pass "inline applies_to_field round-tripped intact"
  else
    step_fail "inline applies_to_field malformed (got: $(grep '^applies_to_field:' "$chunk_inline" || echo NONE))"
  fi
fi

chunk_block="$REF/glossary/REF-glossary-fm-fields-block.md"
if [ -f "$chunk_block" ]; then
  if grep -qE '^topic_tags: \[pbj-staffing, cms-rules\]$' "$chunk_block"; then
    step_pass "block topic_tags reconstructed as inline list"
  else
    step_fail "block topic_tags malformed (got: $(grep '^topic_tags:' "$chunk_block" || echo NONE))"
  fi
  if grep -qE '^applies_to_field: \[\]$' "$chunk_block"; then
    step_pass "empty applies_to_field emitted as []"
  else
    step_fail "empty applies_to_field malformed (got: $(grep '^applies_to_field:' "$chunk_block" || echo NONE))"
  fi
fi

chunk_empty="$REF/glossary/REF-glossary-fm-fields-empty-tags.md"
if [ -f "$chunk_empty" ]; then
  if grep -qE '^topic_tags: \[\]$' "$chunk_empty"; then
    step_pass "empty topic_tags emitted as []"
  else
    step_fail "empty topic_tags malformed (got: $(grep '^topic_tags:' "$chunk_empty" || echo NONE))"
  fi
  if grep -qE '^applies_to_field: \[staff_count\]$' "$chunk_empty"; then
    step_pass "block applies_to_field reconstructed as inline list"
  else
    step_fail "block applies_to_field malformed (got: $(grep '^applies_to_field:' "$chunk_empty" || echo NONE))"
  fi
fi

# Downstream contract: produced chunks must pass the M036/P04 classifier.
# This is the bug the upstream patches are closing — the extract output
# previously failed `required field(s) missing: topic_tags,applies_to_field`.
# shellcheck disable=SC1091
. "$ROOT/scripts/knowledge/classify-reference.sh"
for chunk in "$REF"/glossary/REF-*.md; do
  case "$(basename "$chunk")" in
    *.text.md|*.structured.md) continue ;;
  esac
  [ -f "$chunk" ] || continue
  base="$(basename "$chunk")"
  if classify_reference_required_fields "$chunk" 2>/dev/null; then
    step_pass "classify-reference accepts $base"
  else
    step_fail "classify-reference rejects $base"
  fi
done

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
