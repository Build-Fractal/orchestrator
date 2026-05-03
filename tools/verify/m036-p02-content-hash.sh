#!/usr/bin/env bash
# tools/verify/m036-p02-content-hash.sh -- M036 P02 T02.
# Drives the extract driver against the fixture manifest and asserts
# each emitted chunk's content_hash frontmatter equals shasum -a 256
# of the source binary.
# Host-tooling-aware SKIP if pdftotext/pandoc absent.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-ch.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036/extract-manifest.yaml"

if ! command -v pdftotext >/dev/null 2>&1; then echo "SKIP: pdftotext-absent"; exit 0; fi
if ! command -v pandoc    >/dev/null 2>&1; then echo "SKIP: pandoc-absent"; exit 0; fi

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" \
  --manifest "$MANIFEST" \
  --reference-root "$WORK/knowledge/reference" \
  --originals-root "$WORK/_originals" \
  >/dev/null 2>&1 || { echo "FAIL: driver exited non-zero"; exit 1; }

fail=0
verify_hash() {
  local src="$1"
  local chunk="$2"
  local actual
  local frontmatter
  actual=$(shasum -a 256 "$src" | awk '{print $1}')
  frontmatter=$(grep -E '^content_hash:' "$chunk" | head -n 1 | sed -E 's/^content_hash:[[:space:]]*//' | tr -d '"')
  if [ "$actual" = "$frontmatter" ]; then
    echo "PASS: hash matches for $(basename "$chunk")"
  else
    echo "FAIL: hash mismatch for $(basename "$chunk") (src=$actual frontmatter=$frontmatter)"
    fail=$((fail + 1))
  fi
}
verify_hash "$ROOT/tests/fixtures/m036/sample.pdf"  "$WORK/knowledge/reference/cms-rule/REF-cms-rule-cms-rule-fixture-01.md"
verify_hash "$ROOT/tests/fixtures/m036/sample.docx" "$WORK/knowledge/reference/training-material/REF-training-material-training-pbj-fixture-01.md"
verify_hash "$ROOT/tests/fixtures/m036/sample.md"   "$WORK/knowledge/reference/glossary/REF-glossary-glossary-fixture-01.md"
echo "SUMMARY: m036-p02-content-hash.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
