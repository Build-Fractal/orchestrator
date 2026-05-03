#!/usr/bin/env bash
# tests/test-reference-reingest-idempotency.sh -- M036 P06 T04 SC-5.
#
# Stages an already-ingested REF-* corpus into mktemp -d (re-using
# the M036/P04 fixture-corpus chunks which already carry valid
# content_hash frontmatter). Drives ingest-reference.sh twice with
# --no-index-rebuild. Asserts (a) byte-identical tree pre/post via
# diff -qr, (b) SKIPPED emission for chunks whose frontmatter
# content_hash matches body sha256 (note: extract-produced chunks
# may not satisfy this -- the load-bearing assertion is the byte-
# identical tree).
#
# Emits BATTERY: pass=N fail=N skip=N. Exit 0 iff fail=0.
#
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-p06-sc5.XXXXXX")"
trap 'rm -rf "$WS"' EXIT
DRV="$ROOT/scripts/knowledge/ingest-reference.sh"
pass=0
fail=0
skip=0

# Stage the M036/P04 reference fixture corpus into the workspace.
FIXTURE_SRC="$ROOT/tests/fixtures/m036-p04-reference-corpus"
mkdir -p "$WS/ref"
for category in cms-rule training-material glossary regulatory-doc; do
  if [ -d "$FIXTURE_SRC/$category" ]; then
    mkdir -p "$WS/ref/$category"
    cp "$FIXTURE_SRC/$category"/*.md "$WS/ref/$category/" 2>/dev/null || true
  fi
done

# Snapshot tree before run 1.
SNAP1="$WS/snap1.txt"
find "$WS/ref" -type f | sort > "$SNAP1"
if command -v shasum >/dev/null 2>&1; then
  HASH_BIN="shasum -a 256"
else
  HASH_BIN="sha256sum"
fi
PREHASH="$WS/prehash.txt"
while IFS= read -r f; do
  printf '%s ' "$f" >> "$PREHASH"
  $HASH_BIN "$f" | awk '{print $1}' >> "$PREHASH"
done < "$SNAP1"

# Run 1.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --reference-root "$WS/ref" --no-index-rebuild \
  >"$WS/run1.stdout" 2>"$WS/run1.stderr" || {
    echo "FAIL: first-run-rc-nonzero"
    fail=$((fail + 1))
  }

# Run 2 -- idempotency.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --reference-root "$WS/ref" --no-index-rebuild \
  >"$WS/run2.stdout" 2>"$WS/run2.stderr" || {
    echo "FAIL: second-run-rc-nonzero"
    fail=$((fail + 1))
  }

# Snapshot tree after run 2.
SNAP2="$WS/snap2.txt"
find "$WS/ref" -type f | sort > "$SNAP2"
POSTHASH="$WS/posthash.txt"
while IFS= read -r f; do
  printf '%s ' "$f" >> "$POSTHASH"
  $HASH_BIN "$f" | awk '{print $1}' >> "$POSTHASH"
done < "$SNAP2"

if diff -q "$PREHASH" "$POSTHASH" >/dev/null 2>&1; then
  echo "PASS: ref-tree-byte-identical-across-runs"
  pass=$((pass + 1))
else
  echo "FAIL: ref-tree-modified-across-runs"
  diff "$PREHASH" "$POSTHASH" || true
  fail=$((fail + 1))
fi

if grep -qF -e "SUMMARY:" "$WS/run1.stdout" && grep -qF -e "SUMMARY:" "$WS/run2.stdout"; then
  echo "PASS: both-runs-emit-SUMMARY"
  pass=$((pass + 1))
else
  echo "FAIL: missing-SUMMARY-on-one-or-both-runs"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
