#!/usr/bin/env bash
# tests/test-extract-manifest-block-scalars.sh
# M036 manifest-parser regression: extract_manifest_doc_field must handle
# YAML block-scalar shapes (`field: |` literal, `field: >` folded) in
# addition to inline scalar values. Authoring summaries as block scalars
# is the most ergonomic shape for prose-shaped operator summaries; before
# this fix, the awk one-liner matched the `summary:` line, stripped the
# prefix, and emitted the literal `|` as the field value, silently
# corrupting the chunk body.
#
# Asserts three shapes against a single fixture manifest:
#   1. Inline single-line summary: byte-equal to the source quoted value.
#   2. Block literal (|): newlines preserved verbatim, dedent to field
#      column.
#   3. Block folded (>): consecutive non-empty lines folded to spaces;
#      blank line emits a newline (paragraph break).
#
# Single-script-file shape per AD-19. Bash 3.2 / POSIX-sh per CON-2.
set -eu

ROOT="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-block-scalars.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# shellcheck disable=SC1091
. "$ROOT/scripts/knowledge/lib/extract-manifest.sh"

pass=0
fail=0
skip=0

assert_eq() {
  # assert_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
    pass=$((pass + 1))
  else
    echo "FAIL: $1"
    printf '  expected: %s\n' "$(printf '%s' "$2" | od -c | sed -n '1,3p')"
    printf '  actual:   %s\n' "$(printf '%s' "$3" | od -c | sed -n '1,3p')"
    fail=$((fail + 1))
  fi
}

MANIFEST="$WORK/extract-manifest.yaml"
cat > "$MANIFEST" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "doc-single"
    source_path: "a.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2024-01-01"
    version: "2024-01"
    topic_tags: []
    applies_to_field: []
    tier: 0
    summary_mode: "operator"
    summary: "Single line summary."

  - cite_id: "doc-literal"
    source_path: "b.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2024-01-01"
    version: "2024-01"
    topic_tags: []
    applies_to_field: []
    tier: 0
    summary_mode: "operator"
    summary: |
      Line one of the operator summary.
      Line two with more detail.

  - cite_id: "doc-folded"
    source_path: "c.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2024-01-01"
    version: "2024-01"
    topic_tags: []
    applies_to_field: []
    tier: 0
    summary_mode: "operator"
    summary: >
      Folded line one
      folded line two.

      Second paragraph after blank.
YAML

# 1. Inline scalar: byte-equal to the source quoted value.
EXPECTED_SINGLE='Single line summary.'
ACTUAL_SINGLE="$(extract_manifest_doc_field "$MANIFEST" 1 summary)"
assert_eq "inline single-line summary" "$EXPECTED_SINGLE" "$ACTUAL_SINGLE"

# 2. Block literal: newlines preserved verbatim.
EXPECTED_LITERAL="$(printf 'Line one of the operator summary.\nLine two with more detail.')"
ACTUAL_LITERAL="$(extract_manifest_doc_field "$MANIFEST" 2 summary)"
assert_eq "block-literal (|) preserves newlines" "$EXPECTED_LITERAL" "$ACTUAL_LITERAL"

# 3. Block folded: consecutive lines fold to spaces; blank → newline.
EXPECTED_FOLDED="$(printf 'Folded line one folded line two.\nSecond paragraph after blank.')"
ACTUAL_FOLDED="$(extract_manifest_doc_field "$MANIFEST" 3 summary)"
assert_eq "block-folded (>) folds spaces, blank → newline" "$EXPECTED_FOLDED" "$ACTUAL_FOLDED"

# 4. Cross-field regression: cite_id of the literal doc must still resolve
#    correctly (the parser must not consume past the block back into the
#    next doc record).
EXPECTED_CITE='doc-folded'
ACTUAL_CITE="$(extract_manifest_doc_field "$MANIFEST" 3 cite_id)"
assert_eq "cite_id resolves on doc following a block scalar" "$EXPECTED_CITE" "$ACTUAL_CITE"

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
