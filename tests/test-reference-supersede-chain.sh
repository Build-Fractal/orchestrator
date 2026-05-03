#!/usr/bin/env bash
# tests/test-reference-supersede-chain.sh -- M036 P06 T04 SC-6.
#
# End-to-end supersede-chain story:
#   1. Stage V1 source from the on-disk fixture; run extract -- assert
#      V1 chunk written.
#   2. Replace source with V2 fixture; run extract -- assert v2 chunk
#      written + V1 frontmatter contains superseded_by + SUPERSEDED
#      stdout.
#   3. Run ingest against the workspace -- assert SUMMARY line emitted.
#      (The cross-citer REVIEW: walk via traverse-graph.sh requires
#      the project's KNOWLEDGE-INDEX to register the workspace's spec
#      chunks, which we do not rebuild here -- the helper-shape
#      verifier asserts the REVIEW format string is present in the
#      helper itself; full graph integration is exercised by the
#      M036b operator-facing acceptance battery.)
#
# Emits BATTERY: pass=N fail=N skip=N. Exit 0 iff fail=0.
#
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-p06-sc6.XXXXXX")"
trap 'rm -rf "$WS"' EXIT
EXTRACT="$ROOT/scripts/knowledge/extract-reference.sh"
INGEST="$ROOT/scripts/knowledge/ingest-reference.sh"
FIXTURES="$ROOT/tests/fixtures/m036-p06-supersede-corpus"
pass=0
fail=0
skip=0

# Copy V1 source into workspace.
cp "$FIXTURES/original/cms-rule/REF-cms-rule-supersede-fixture.md" "$WS/source.md"

cat > "$WS/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "supersede-fixture"
    source_path: "source.md"
    category: "cms-rule"
    source: "internal-test"
    published: "2026-05-02"
    version: "1"
    topic_tags: [pbj-staffing]
    applies_to_field: [staff_count]
    tier: 1
    summary_mode: "operator"
    summary: "SC-6 supersede fixture."
YAML

REF="$WS/ref"
ORIG="$WS/orig"

# Phase 1: V1 extract.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$EXTRACT" --manifest "$WS/manifest.yaml" \
  --reference-root "$REF" --originals-root "$ORIG" \
  >"$WS/run1.stdout" 2>"$WS/run1.stderr" || {
    echo "FAIL: V1-extract-rc-nonzero"
    fail=$((fail + 1))
  }

V1_FILE="$REF/cms-rule/REF-cms-rule-supersede-fixture.md"
if [ -f "$V1_FILE" ]; then
  echo "PASS: V1-chunk-written"
  pass=$((pass + 1))
else
  echo "FAIL: V1-chunk-not-written"
  fail=$((fail + 1))
fi

# Phase 2: replace source with V2 and re-extract.
cp "$FIXTURES/mutated/cms-rule/REF-cms-rule-supersede-fixture.md" "$WS/source.md"
ORCHESTRATOR_ROOT="$ROOT" \
bash "$EXTRACT" --manifest "$WS/manifest.yaml" \
  --reference-root "$REF" --originals-root "$ORIG" \
  >"$WS/run2.stdout" 2>"$WS/run2.stderr" || {
    echo "FAIL: V2-extract-rc-nonzero"
    fail=$((fail + 1))
  }

V2_FILE="$REF/cms-rule/REF-cms-rule-supersede-fixture-v2.md"
if [ -f "$V2_FILE" ]; then
  echo "PASS: v2-chunk-written"
  pass=$((pass + 1))
else
  echo "FAIL: v2-chunk-not-written"
  fail=$((fail + 1))
fi

if grep -qF -e 'superseded_by: "REF-cms-rule-supersede-fixture-v2"' "$V1_FILE"; then
  echo "PASS: V1-frontmatter-amended-with-superseded_by"
  pass=$((pass + 1))
else
  echo "FAIL: V1-frontmatter-missing-superseded_by"
  fail=$((fail + 1))
fi

if grep -qF -e "SUPERSEDED: REF-cms-rule-supersede-fixture -> REF-cms-rule-supersede-fixture-v2" "$WS/run2.stdout"; then
  echo "PASS: SUPERSEDED-stdout-emitted"
  pass=$((pass + 1))
else
  echo "FAIL: SUPERSEDED-stdout-missing"
  fail=$((fail + 1))
fi

# Phase 3: ingest the workspace -- SUMMARY line MUST be present;
# REVIEW: line is opportunistic (depends on graph state).
ORCHESTRATOR_ROOT="$ROOT" \
bash "$INGEST" --reference-root "$REF" --no-index-rebuild \
  >"$WS/ingest.stdout" 2>"$WS/ingest.stderr" || {
    echo "FAIL: ingest-rc-nonzero"
    fail=$((fail + 1))
  }

if grep -qF -e "SUMMARY:" "$WS/ingest.stdout"; then
  echo "PASS: ingest-emits-SUMMARY"
  pass=$((pass + 1))
else
  echo "FAIL: ingest-missing-SUMMARY"
  fail=$((fail + 1))
fi

# The REVIEW: walk depends on the project graph having a citer of
# REF-cms-rule-supersede-fixture. In a clean repo this is unlikely;
# the assertion is informational. Increment skip if no REVIEW: line
# found rather than failing.
if grep -qF -e "REVIEW:" "$WS/ingest.stdout"; then
  echo "PASS: REVIEW-line-emitted"
  pass=$((pass + 1))
else
  echo "SKIP: no-citer-in-project-graph (informational; helper-shape verifier asserts format string)"
  skip=$((skip + 1))
fi

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
