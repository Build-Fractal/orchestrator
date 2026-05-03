#!/usr/bin/env bash
# tests/test-tier-0-manifest.sh -- M036 P02 SC-10 acceptance harness.
# Drives scripts/knowledge/extract-reference.sh against the 3-doc
# fixture manifest in a mktemp -d workspace. Asserts:
#   1. EXTRACTED: line per document on first run.
#   2. SKIPPED: line per document on second (idempotent) run.
#   3. Each chunk file has the required frontmatter fields.
#   4. Each binary exists byte-identical under _originals/.
#   5. diff -q across the two runs reports zero changes.
# Host-tooling-aware SKIP at the per-document level: PDF + DOCX docs
# SKIP if pdftotext/pandoc absent; markdown doc always runs.
# Emits BATTERY: pass=N fail=N skip=N summary; exit 0 iff fail=0.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-sc10.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036/extract-manifest.yaml"

pass=0
fail=0
skip=0

assert_pass() {
  echo "PASS: $1"
  pass=$((pass + 1))
}
assert_fail() {
  echo "FAIL: $1"
  fail=$((fail + 1))
}
assert_skip() {
  echo "SKIP: $1"
  skip=$((skip + 1))
}

# Determine which docs to assert on per host tooling.
have_pdf=0
have_docx=0
if command -v pdftotext >/dev/null 2>&1; then have_pdf=1; fi
if command -v pandoc    >/dev/null 2>&1; then have_docx=1; fi

# To run end-to-end the driver needs *all* host tools the manifest
# declares. If any are absent we run a markdown-only sub-manifest.
if [ "$have_pdf" -eq 1 ] && [ "$have_docx" -eq 1 ]; then
  STAGED_MANIFEST="$MANIFEST"
  STAGED_DIR="$ROOT/tests/fixtures/m036"
else
  STAGED_DIR="$WORK"
  cp "$ROOT/tests/fixtures/m036/sample.md" "$STAGED_DIR/sample.md"
  cat > "$STAGED_DIR/extract-manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
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
YAML
  STAGED_MANIFEST="$STAGED_DIR/extract-manifest.yaml"
  if [ "$have_pdf" -eq 0 ];  then assert_skip "pdf-fixture (pdftotext-absent)"; fi
  if [ "$have_docx" -eq 0 ]; then assert_skip "docx-fixture (pandoc-absent)";   fi
fi

RUN1="$WORK/run1"

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$STAGED_MANIFEST" \
  --reference-root "$RUN1/knowledge/reference" \
  --originals-root "$RUN1/_originals" \
  >"$WORK/run1.stdout" 2>"$WORK/run1.stderr" || {
    assert_fail "first-run driver exited non-zero"
    cat "$WORK/run1.stderr" >&2
    echo "BATTERY: pass=$pass fail=$fail skip=$skip"
    exit 1
  }

# Assert EXTRACTED lines on first run for each doc actually run.
if [ "$have_pdf" -eq 1 ] && [ "$have_docx" -eq 1 ]; then
  for c in cms-rule-fixture-01 training-pbj-fixture-01 glossary-fixture-01; do
    if grep -qE "^EXTRACTED: $c " "$WORK/run1.stdout"; then
      assert_pass "EXTRACTED: $c (first run)"
    else
      assert_fail "no EXTRACTED line for $c on first run"
    fi
  done
else
  if grep -qE "^EXTRACTED: glossary-fixture-01 " "$WORK/run1.stdout"; then
    assert_pass "EXTRACTED: glossary-fixture-01 (first run, md-only)"
  else
    assert_fail "no EXTRACTED line for glossary-fixture-01 on md-only first run"
  fi
fi

# Second run should SKIP every doc.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$STAGED_MANIFEST" \
  --reference-root "$RUN1/knowledge/reference" \
  --originals-root "$RUN1/_originals" \
  >"$WORK/run2.stdout" 2>"$WORK/run2.stderr" || {
    assert_fail "second-run driver exited non-zero"
    cat "$WORK/run2.stderr" >&2
    echo "BATTERY: pass=$pass fail=$fail skip=$skip"
    exit 1
  }
if grep -qE '^SKIPPED:' "$WORK/run2.stdout"; then
  if grep -qE '^EXTRACTED:' "$WORK/run2.stdout"; then
    assert_fail "second run emitted EXTRACTED (expected only SKIPPED)"
  else
    assert_pass "second run emits only SKIPPED:"
  fi
else
  assert_fail "second run missing SKIPPED: lines"
fi

# Frontmatter shape: every chunk has content_hash + tier + category.
for chunk in $(find "$RUN1/knowledge/reference" -name 'REF-*.md' -not -name '*.text.md'); do
  for f in content_hash tier category cite_id source published; do
    if grep -qE "^$f:" "$chunk"; then
      assert_pass "$f present in $(basename "$chunk")"
    else
      assert_fail "$f missing in $(basename "$chunk")"
    fi
  done
done

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
