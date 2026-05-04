#!/usr/bin/env bash
# tools/verify/m032-p02-lookup-mems-glossary.sh
# M032/P02/T04 verifier -- exercises scripts/knowledge/lookup-mems.sh
# --kind=glossary against six scenarios:
#   (a) Standard profile / full glossary -- 3 records emitted, ids match shape.
#   (b) Idempotency -- ids stable across re-invocations against unchanged glossary.
#   (c) Quick + task-description hit -- exactly one record (the matched term).
#   (d) Quick + task-description miss -- zero records.
#   (e) Quick + file-change-set hit -- the matched-term record emitted.
#   (f) Quick safe-default-no-terms (MIT-010) -- zero records.
#
# Single-script-file shape per AD-19; bash 3.2 compatible per MEM001.
# Fixture lives under a mktemp -d sandbox; the orchestrator's own
# wiki/glossary.md is NOT touched.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADAPTER="$REPO_ROOT/scripts/knowledge/lookup-mems.sh"

if [ ! -x "$ADAPTER" ]; then
  echo "FAIL: m032-p02-lookup-mems-glossary: adapter not executable at $ADAPTER" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stage a fixture glossary with three known terms (alphabetized per US-6 format).
mkdir -p "$TMP/wiki"
cat > "$TMP/wiki/glossary.md" <<'EOF'
# Glossary

### Bar
Bar definition.

### Baz
Baz definition.

### Foo
Foo definition.
EOF

# (a) Standard profile / full glossary -- 3 records, ids well-formed.
bash "$ADAPTER" --kind=glossary --profile=standard --root "$TMP" > "$TMP/standard.txt" 2>/dev/null
N_STD="$(grep -c '^id: gloss-' "$TMP/standard.txt" || true)"
if [ "$N_STD" != "3" ]; then
  echo "FAIL: standard profile expected 3 records, got $N_STD" >&2
  exit 1
fi
grep -q '^id: gloss-foo$' "$TMP/standard.txt" || { echo "FAIL: missing gloss-foo under standard" >&2; exit 1; }
grep -q '^id: gloss-bar$' "$TMP/standard.txt" || { echo "FAIL: missing gloss-bar under standard" >&2; exit 1; }
grep -q '^id: gloss-baz$' "$TMP/standard.txt" || { echo "FAIL: missing gloss-baz under standard" >&2; exit 1; }

# Assert each id matches ^id: gloss-[a-z0-9-]+$
BAD_ID="$(grep '^id: gloss-' "$TMP/standard.txt" | grep -v -E '^id: gloss-[a-z0-9-]+$' || true)"
if [ -n "$BAD_ID" ]; then
  echo "FAIL: malformed id line(s):" >&2
  printf '%s\n' "$BAD_ID" >&2
  exit 1
fi

# (b) Idempotency -- same ids across re-invocations (timestamps may differ).
bash "$ADAPTER" --kind=glossary --profile=standard --root "$TMP" > "$TMP/standard2.txt" 2>/dev/null
grep '^id: ' "$TMP/standard.txt" | sort > "$TMP/ids1.txt"
grep '^id: ' "$TMP/standard2.txt" | sort > "$TMP/ids2.txt"
if ! diff -q "$TMP/ids1.txt" "$TMP/ids2.txt" >/dev/null; then
  echo "FAIL: idempotency violated -- ids differ between runs" >&2
  diff "$TMP/ids1.txt" "$TMP/ids2.txt" >&2 || true
  exit 1
fi

# (c) Quick profile + task-description hit (case-insensitive substring).
bash "$ADAPTER" --kind=glossary --profile=quick --task-description 'rename a foo file' --root "$TMP" > "$TMP/quick-hit.txt" 2>/dev/null
N_HIT="$(grep -c '^id: gloss-' "$TMP/quick-hit.txt" || true)"
if [ "$N_HIT" != "1" ]; then
  echo "FAIL: quick + task-desc hit expected 1 record, got $N_HIT" >&2
  exit 1
fi
grep -q '^id: gloss-foo$' "$TMP/quick-hit.txt" || { echo "FAIL: quick + task-desc hit did not emit gloss-foo" >&2; exit 1; }

# (d) Quick profile + task-description miss.
bash "$ADAPTER" --kind=glossary --profile=quick --task-description 'unrelated text' --root "$TMP" > "$TMP/quick-miss.txt" 2>/dev/null
N_MISS="$(grep -c '^id: gloss-' "$TMP/quick-miss.txt" || true)"
if [ "$N_MISS" != "0" ]; then
  echo "FAIL: quick + task-desc miss expected 0 records, got $N_MISS" >&2
  exit 1
fi

# (e) Quick + file-change-set hit -- staged file body contains 'Foo'.
echo "this file contains Foo" > "$TMP/changed.txt"
bash "$ADAPTER" --kind=glossary --profile=quick --file-change-set "$TMP/changed.txt" --root "$TMP" > "$TMP/quick-fcs.txt" 2>/dev/null
grep -q '^id: gloss-foo$' "$TMP/quick-fcs.txt" || { echo "FAIL: quick + file-change-set did not emit gloss-foo" >&2; exit 1; }

# (f) Quick safe-default-no-terms (MIT-010 fallback).
bash "$ADAPTER" --kind=glossary --profile=quick --root "$TMP" > "$TMP/quick-safe.txt" 2>/dev/null
N_SAFE="$(grep -c '^id: gloss-' "$TMP/quick-safe.txt" || true)"
if [ "$N_SAFE" != "0" ]; then
  echo "FAIL: quick safe-default expected 0 records, got $N_SAFE (MIT-010)" >&2
  exit 1
fi

echo "PASS: m032-p02-lookup-mems-glossary"
exit 0
