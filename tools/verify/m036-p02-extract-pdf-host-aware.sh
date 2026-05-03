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
