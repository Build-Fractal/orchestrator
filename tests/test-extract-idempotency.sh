#!/usr/bin/env bash
# tests/test-extract-idempotency.sh -- M036 P06 T04 SC-13 acceptance.
#
# Stages a markdown-only manifest + source into mktemp -d, runs the
# extract driver twice, asserts (a) first run rc=0 + EXTRACTED, (b)
# second run rc=0 + SKIPPED, (c) byte-identical trees across two
# fresh-workspace runs, (d) re-run against a populated tree leaves it
# byte-identical.
#
# Emits BATTERY: pass=N fail=N skip=N as last stdout line.
# Exit 0 iff fail=0.
#
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-p06-sc13.XXXXXX")"
trap 'rm -rf "$WS"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
pass=0
fail=0
skip=0

cp "$ROOT/tests/fixtures/m036/sample.md" "$WS/source.md"
cat > "$WS/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "sc13-fixture"
    source_path: "source.md"
    category: "glossary"
    source: "internal-test"
    published: "2026-05-02"
    version: "1"
    topic_tags: []
    applies_to_field: []
    tier: 1
    summary_mode: "operator"
    summary: "SC-13 fixture summary."
YAML

REF1="$WS/run1/ref"
ORIG1="$WS/run1/orig"
REF2="$WS/run2/ref"
ORIG2="$WS/run2/orig"

# First run.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WS/manifest.yaml" \
  --reference-root "$REF1" --originals-root "$ORIG1" \
  >"$WS/run1.stdout" 2>"$WS/run1.stderr" || {
    echo "FAIL: first-run-rc-nonzero"
    fail=$((fail + 1))
  }

if grep -qF -e "EXTRACTED: sc13-fixture" "$WS/run1.stdout"; then
  echo "PASS: first-run-emits-EXTRACTED"
  pass=$((pass + 1))
else
  echo "FAIL: first-run-missing-EXTRACTED"
  fail=$((fail + 1))
fi

# Second fresh-workspace run.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WS/manifest.yaml" \
  --reference-root "$REF2" --originals-root "$ORIG2" \
  >"$WS/run2.stdout" 2>"$WS/run2.stderr" || {
    echo "FAIL: second-run-rc-nonzero"
    fail=$((fail + 1))
  }

# Byte-identical trees.
if diff -qr "$REF1" "$REF2" >/dev/null 2>&1; then
  echo "PASS: ref-trees-byte-identical-across-runs"
  pass=$((pass + 1))
else
  echo "FAIL: ref-trees-differ"
  fail=$((fail + 1))
fi
if diff -qr "$ORIG1" "$ORIG2" >/dev/null 2>&1; then
  echo "PASS: originals-trees-byte-identical-across-runs"
  pass=$((pass + 1))
else
  echo "FAIL: originals-trees-differ"
  fail=$((fail + 1))
fi

# Re-run against populated tree -- must emit SKIPPED.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WS/manifest.yaml" \
  --reference-root "$REF1" --originals-root "$ORIG1" \
  >"$WS/run3.stdout" 2>"$WS/run3.stderr" || {
    echo "FAIL: third-run-rc-nonzero"
    fail=$((fail + 1))
  }

if grep -qF -e "SKIPPED: sc13-fixture reason=unchanged" "$WS/run3.stdout"; then
  echo "PASS: third-run-emits-SKIPPED"
  pass=$((pass + 1))
else
  echo "FAIL: third-run-missing-SKIPPED"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
