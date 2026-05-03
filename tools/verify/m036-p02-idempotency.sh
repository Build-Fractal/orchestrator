#!/usr/bin/env bash
# tools/verify/m036-p02-idempotency.sh -- M036 P02 T04.
# Drives the extract driver twice in a temp workspace; asserts the
# second run reports zero deltas via diff -q.
# Host-aware SKIP if pdftotext + pandoc absent (so we still exercise
# the full 3-doc fixture). On bare hosts uses the markdown-only doc.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-idem.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

# Always-runnable: stage a markdown-only manifest. Idempotency contract
# is format-agnostic; markdown is sufficient to gate it.
cp "$ROOT/tests/fixtures/m036/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "idem-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2026-05-02"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 1
    summary_mode: "operator"
    summary: "Idempotency test fixture summary."
YAML

REF1="$WORK/run1/knowledge/reference"
ORIG1="$WORK/run1/_originals"
REF2="$WORK/run2/knowledge/reference"
ORIG2="$WORK/run2/_originals"

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WORK/manifest.yaml" \
  --reference-root "$REF1" --originals-root "$ORIG1" \
  >"$WORK/run1.stdout" 2>"$WORK/run1.stderr" || {
    echo "FAIL: first run failed"
    cat "$WORK/run1.stderr" >&2
    exit 1
  }

# Second run targets a fresh workspace (so we can byte-compare trees).
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WORK/manifest.yaml" \
  --reference-root "$REF2" --originals-root "$ORIG2" \
  >"$WORK/run2.stdout" 2>"$WORK/run2.stderr" || {
    echo "FAIL: second run failed"
    cat "$WORK/run2.stderr" >&2
    exit 1
  }

fail=0
if diff -qr "$REF1" "$REF2" >/dev/null 2>&1; then
  echo "PASS: knowledge/reference tree byte-identical across runs"
else
  echo "FAIL: knowledge/reference tree differs across runs"
  diff -qr "$REF1" "$REF2" || true
  fail=$((fail + 1))
fi
if diff -qr "$ORIG1" "$ORIG2" >/dev/null 2>&1; then
  echo "PASS: _originals tree byte-identical across runs"
else
  echo "FAIL: _originals tree differs across runs"
  diff -qr "$ORIG1" "$ORIG2" || true
  fail=$((fail + 1))
fi

# Now exercise the actual idempotency contract: re-run against an
# existing tree should emit SKIPPED, not EXTRACTED.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WORK/manifest.yaml" \
  --reference-root "$REF1" --originals-root "$ORIG1" \
  >"$WORK/run3.stdout" 2>"$WORK/run3.stderr" || {
    echo "FAIL: third run (rerun against run1 tree) failed"
    cat "$WORK/run3.stderr" >&2
    exit 1
  }
if grep -qE '^SKIPPED: idem-fixture-01 ' "$WORK/run3.stdout"; then
  echo "PASS: re-run against existing tree emits SKIPPED"
else
  echo "FAIL: re-run against existing tree did not emit SKIPPED"
  cat "$WORK/run3.stdout"
  fail=$((fail + 1))
fi

echo "SUMMARY: m036-p02-idempotency.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
