#!/usr/bin/env bash
# tools/verify/m036-p02-size-cap-external-pointer.sh -- M036 P02 T02.
# Stages a synthetic single-doc manifest in a temp workspace whose
# size_cap_bytes=1 forces the source binary above the cap. Asserts the
# emitted chunk frontmatter contains an external_pointer: line and the
# binary is NOT copied under _originals/.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-cap.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

# Stage a 1-doc manifest with cap=1 against the markdown fixture.
cp "$ROOT/tests/fixtures/m036/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 1

documents:
  - cite_id: "size-cap-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "test"
    published: "2026-05-02"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 0
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
chunk="$WORK/knowledge/reference/glossary/REF-glossary-size-cap-fixture-01.md"
if [ ! -f "$chunk" ]; then
  echo "FAIL: chunk not emitted at $chunk"
  exit 1
fi
if grep -qE '^external_pointer:' "$chunk"; then
  echo "PASS: external_pointer recorded in chunk"
else
  echo "FAIL: external_pointer missing in chunk"
  fail=$((fail + 1))
fi
if [ -f "$WORK/_originals/test/sample.md" ]; then
  echo "FAIL: binary was copied despite above-cap"
  fail=$((fail + 1))
else
  echo "PASS: binary not copied (above cap)"
fi
echo "SUMMARY: m036-p02-size-cap-external-pointer.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
