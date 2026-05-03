#!/usr/bin/env bash
# tools/verify/m036-p06-supersede-chain-end-to-end.sh -- M036 P06 T01.
# Behavioral verifier: stages a markdown-only manifest, runs the
# extract driver, mutates the source body, runs again, asserts (a)
# versioned successor REF-cms-rule-fixture-v2.md exists, (b) prior
# chunk frontmatter contains superseded_by:, (c) stdout SUPERSEDED:
# line emitted, (d) re-running on the mutated source emits SKIPPED.
# No host-tool dependency (markdown floor only).
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-p06-supersede.XXXXXX")"
trap 'rm -rf "$WS"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
pass=0
fail=0

# Stage source markdown (V1).
{
  printf '%s\n' "# Supersede Fixture"
  printf '%s\n' ""
  printf '%s\n' "BODY V1 -- original content for the supersede-chain end-to-end verifier."
} > "$WS/source.md"

# Stage manifest pointing at the source.
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
    topic_tags: []
    applies_to_field: []
    tier: 1
    summary_mode: "operator"
    summary: "Supersede fixture summary."
YAML

REF="$WS/ref"
ORIG="$WS/orig"

# First extract -- writes V1 chunk file.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WS/manifest.yaml" \
  --reference-root "$REF" --originals-root "$ORIG" \
  >"$WS/run1.stdout" 2>"$WS/run1.stderr" || {
    echo "FAIL: first extract failed (rc=$?)"
    cat "$WS/run1.stderr" >&2
    echo "SUMMARY: m036-p06-supersede-chain-end-to-end.sh pass=0 fail=1"
    exit 1
  }

V1_FILE="$REF/cms-rule/REF-cms-rule-supersede-fixture.md"
if [ -f "$V1_FILE" ]; then
  echo "PASS: V1-chunk-written"
  pass=$((pass + 1))
else
  echo "FAIL: V1-chunk-not-written"
  fail=$((fail + 1))
fi

# Mutate source body.
{
  printf '%s\n' "# Supersede Fixture"
  printf '%s\n' ""
  printf '%s\n' "BODY V2 -- mutated content; content_hash now differs from V1."
} > "$WS/source.md"

# Second extract -- supersede branch should fire.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WS/manifest.yaml" \
  --reference-root "$REF" --originals-root "$ORIG" \
  >"$WS/run2.stdout" 2>"$WS/run2.stderr" || {
    echo "FAIL: second extract failed (rc=$?)"
    cat "$WS/run2.stderr" >&2
    echo "SUMMARY: m036-p06-supersede-chain-end-to-end.sh pass=$pass fail=$((fail + 1))"
    exit 1
  }

V2_FILE="$REF/cms-rule/REF-cms-rule-supersede-fixture-v2.md"
if [ -f "$V2_FILE" ]; then
  echo "PASS: V2-chunk-written"
  pass=$((pass + 1))
else
  echo "FAIL: V2-chunk-not-written"
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

# Third extract on now-mutated source -- chunk_file path is now the v2
# successor; content_hash gate matches; emit SKIPPED.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WS/manifest.yaml" \
  --reference-root "$REF" --originals-root "$ORIG" \
  >"$WS/run3.stdout" 2>"$WS/run3.stderr" || {
    echo "FAIL: third extract failed (rc=$?)"
    cat "$WS/run3.stderr" >&2
    fail=$((fail + 1))
  }

if grep -qF -e "SKIPPED: supersede-fixture reason=unchanged" "$WS/run3.stdout"; then
  echo "PASS: third-run-emits-SKIPPED"
  pass=$((pass + 1))
else
  echo "FAIL: third-run-did-not-emit-SKIPPED"
  fail=$((fail + 1))
fi

echo "SUMMARY: m036-p06-supersede-chain-end-to-end.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
