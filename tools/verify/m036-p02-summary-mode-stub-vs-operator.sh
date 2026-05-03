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
