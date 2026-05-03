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
