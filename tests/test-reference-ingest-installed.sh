#!/usr/bin/env bash
# tests/test-reference-ingest-installed.sh -- E2E regression coverage for
# the "as-installed" reference-ingest path.
#
# Reproduces the install-time runtime by staging packaging/bundle/manifest.yml's
# project_assets list into a tempdir via the same readers + handlers the
# real installers use (scripts/lifecycle/read-project-assets.sh +
# scripts/lifecycle/install-asset-mode.sh), then drives the *staged*
# ingest-reference.sh against a single REF-*.md chunk and asserts:
#
#   * exit 0
#   * SUMMARY reports created=1 rejected=0
#   * stderr contains no "validator missing" message
#   * no REJECTED line emitted
#
# Closes the test-coverage hole that allowed the FR-1 taxonomy validator
# (scripts/knowledge/lib/validate-chunk-frontmatter.sh — relocated 2026-05-06
# from tools/verify/lib/p00-validate-chunk-frontmatter.sh) to ship without
# being staged into installed projects. Pre-fix behavior in installed
# projects: every chunk REJECTED with reason=unknown-classifier-error,
# masking the underlying "validator missing" error.
#
# Emits BATTERY: pass=N fail=N skip=N as last stdout line.
# Exit 0 iff fail=0.
#
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu

ROOT="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
READER="$ROOT/scripts/lifecycle/read-project-assets.sh"
HANDLER="$ROOT/scripts/lifecycle/install-asset-mode.sh"
BUNDLE="$ROOT/packaging/bundle"
FX="$ROOT/tests/fixtures/m036-p04-reference-corpus/glossary/REF-glossary-fixture-01.md"

WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-as-installed.XXXXXX")"
trap 'rm -rf "$WS"' EXIT

pass=0
fail=0
skip=0

step_pass() { echo "PASS: $1"; pass=$((pass + 1)); }
step_fail() { echo "FAIL: $1"; fail=$((fail + 1)); }

# --- Sanity: dependencies present in the dev tree ---
for dep in "$READER" "$HANDLER" "$BUNDLE/manifest.yml" "$FX"; do
  if [ ! -f "$dep" ]; then
    step_fail "dev-tree dependency missing: $dep"
    echo "BATTERY: pass=$pass fail=$fail skip=$skip"
    exit 1
  fi
done

# --- 1. Stage project_assets into the tempdir using the real installer pipeline ---
# The reader emits one tab-separated tuple per project_assets entry;
# install-asset-mode.sh handles the per-mode copy/symlink dispatch.
PROJECT_DIR="$WS/project"
mkdir -p "$PROJECT_DIR"

while IFS= read -r tuple; do
  src_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^source=/){sub(/^source=/, "", $i); print $i}}}')
  tgt_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
  mode_val=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^mode=/){sub(/^mode=/, "", $i); print $i}}}')
  src_abs="$ROOT/${src_rel%/}"
  dst_abs="$PROJECT_DIR/${tgt_rel%/}"
  if [ ! -d "$src_abs" ]; then
    step_fail "project_assets source missing on disk: $src_abs"
    echo "BATTERY: pass=$pass fail=$fail skip=$skip"
    exit 1
  fi
  bash "$HANDLER" "$src_abs" "$dst_abs" "$mode_val" "$PROJECT_DIR" >/dev/null 2>&1 || {
    step_fail "install-asset-mode.sh failed staging $src_rel ($mode_val)"
    echo "BATTERY: pass=$pass fail=$fail skip=$skip"
    exit 1
  }
done < <(bash "$READER" "$BUNDLE/")

# Assertion: the runtime validator dependency MUST be present in the staged tree.
# This is the surgical assertion that would have failed before the validator
# was relocated into scripts/knowledge/lib/.
if [ -f "$PROJECT_DIR/scripts/knowledge/lib/validate-chunk-frontmatter.sh" ]; then
  step_pass "validator staged at scripts/knowledge/lib/validate-chunk-frontmatter.sh"
else
  step_fail "validator NOT staged — packaging gap reintroduced"
  echo "  staged scripts/knowledge/lib contents:"
  ls "$PROJECT_DIR/scripts/knowledge/lib/" 2>&1 | sed 's/^/    /'
fi
if [ -f "$PROJECT_DIR/scripts/knowledge/classify-reference.sh" ]; then
  step_pass "classifier staged at scripts/knowledge/classify-reference.sh"
else
  step_fail "classifier NOT staged"
fi
if [ -f "$PROJECT_DIR/scripts/knowledge/ingest-reference.sh" ]; then
  step_pass "ingest driver staged at scripts/knowledge/ingest-reference.sh"
else
  step_fail "ingest driver NOT staged"
fi

# --- 2. Place a single valid REF-*.md chunk under the staged knowledge tree ---
REF_ROOT="$PROJECT_DIR/knowledge/reference"
mkdir -p "$REF_ROOT/glossary"
cp "$FX" "$REF_ROOT/glossary/"

# --- 3. Drive the STAGED ingest-reference.sh against the chunk ---
# Critically: invoke the staged copy under $PROJECT_DIR, not the dev-tree
# copy under $ROOT. ORCHESTRATOR_ROOT is set to $PROJECT_DIR so all
# resolution stays inside the simulated install.
DRV="$PROJECT_DIR/scripts/knowledge/ingest-reference.sh"
OUT="$WS/ingest.stdout"
ERR="$WS/ingest.stderr"

ORCHESTRATOR_ROOT="$PROJECT_DIR" bash "$DRV" \
  --reference-root "$REF_ROOT" --no-index-rebuild \
  > "$OUT" 2> "$ERR"
rc=$?

if [ "$rc" -eq 0 ]; then
  step_pass "ingest-reference.sh exit 0 (as-installed)"
else
  step_fail "ingest-reference.sh exit $rc (as-installed)"
  echo "  stderr:"
  sed -e 's/^/    /' "$ERR"
fi

# --- 4. SUMMARY assertions: created=1 rejected=0 ---
if grep -qE 'SUMMARY: ingest-reference\.sh created=1 ' "$OUT"; then
  step_pass "SUMMARY reports created=1"
else
  step_fail "SUMMARY does not report created=1 (got: $(grep '^SUMMARY:' "$OUT" || echo NONE))"
fi
if grep -qE 'SUMMARY:.* rejected=0 ' "$OUT"; then
  step_pass "SUMMARY reports rejected=0"
else
  step_fail "SUMMARY does not report rejected=0 (got: $(grep '^SUMMARY:' "$OUT" || echo NONE))"
fi

# --- 5. CREATED line emitted, REJECTED line NOT emitted ---
if grep -qF -e "CREATED: REF-glossary-fixture-01" "$OUT"; then
  step_pass "CREATED emitted for REF-glossary-fixture-01"
else
  step_fail "CREATED missing for REF-glossary-fixture-01 (full stdout below)"
  sed -e 's/^/    /' "$OUT"
fi
if grep -qE '^REJECTED:' "$OUT"; then
  step_fail "unexpected REJECTED line in as-installed run: $(grep '^REJECTED:' "$OUT" | head -n 1)"
else
  step_pass "no REJECTED lines emitted"
fi

# --- 6. Stderr MUST NOT contain 'validator missing' ---
# This is the regression assertion proper — pre-fix this string would have
# appeared (because the validator was not staged), and the rejection reason
# would have been swallowed into 'unknown-classifier-error' on stdout.
if grep -qF 'validator missing' "$ERR"; then
  step_fail "validator-missing leak: $(grep -F 'validator missing' "$ERR" | head -n 1)"
else
  step_pass "stderr clean of 'validator missing'"
fi

# --- 7. Surface-test the error-handler fix at ingest-reference.sh:131-138 ---
# Synthesize a chunk whose frontmatter omits a required FR-2 field so the
# classifier emits 'required field(s) missing: ...' — assert the staged
# driver bubbles that string into the REJECTED reason instead of the
# generic 'unknown-classifier-error' bucket.
BAD_REF_ROOT="$WS/bad-corpus/knowledge/reference"
mkdir -p "$BAD_REF_ROOT/glossary"
BAD_CHUNK="$BAD_REF_ROOT/glossary/REF-glossary-bad-fixture.md"
# Drop topic_tags + applies_to_field to trigger the FR-2 missing-required-field path.
sed -e '/^topic_tags:/d' -e '/^applies_to_field:/d' "$FX" > "$BAD_CHUNK"
# Update id/chunk_id to a unique value so we don't conflict with the good chunk.
sed -i.bak -e 's/REF-glossary-fixture-01/REF-glossary-bad-fixture/g' "$BAD_CHUNK"
rm -f "$BAD_CHUNK.bak"

BAD_OUT="$WS/ingest-bad.stdout"
ORCHESTRATOR_ROOT="$PROJECT_DIR" bash "$DRV" \
  --reference-root "$BAD_REF_ROOT" --no-index-rebuild \
  > "$BAD_OUT" 2>/dev/null || true
if grep -qE '^REJECTED: REF-glossary-bad-fixture reason=required field' "$BAD_OUT"; then
  step_pass "error-handler surfaces 'required field' as REJECTED reason (not unknown-classifier-error)"
else
  step_fail "error-handler did not surface FR-2 reason cleanly (got: $(grep '^REJECTED:' "$BAD_OUT" || echo NONE))"
fi

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
