#!/usr/bin/env bash
# tests/test-intake-manifest-superset.sh — SC-8 / FR-15 / DC-5 strict-superset
# assertion: proposal frontmatter contains every key from the M014 interim
# manifest fixture, plus at least one M024-specific key.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
FIXTURE="$ROOT/tests/fixtures/m014-interim-manifest-keys.txt"

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: fixture missing: $FIXTURE"
  exit 1
fi
if [ ! -x "$EMIT" ]; then
  echo "FAIL: emitter missing: $EMIT"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

out=$(bash "$EMIT" --input "test input for manifest superset assertion" --intake-root "$tmp")
proposal_path=$(echo "$out" | sed -n 's/^proposal_path=//p')
if [ -z "$proposal_path" ] || [ ! -f "$proposal_path" ]; then
  echo "FAIL: emitter produced no file (out: $out)"
  exit 1
fi

# Extract the proposal's frontmatter key list.
prop_keys_file="$tmp/proposal-keys.txt"
awk 'BEGIN{in_fm=0} /^---$/{in_fm++; next} in_fm==1 && /^[a-z_]+:/ {sub(/:.*/, ""); print}' "$proposal_path" > "$prop_keys_file"

# Containment check.
missing=""
fixture_count=0
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  fixture_count=$((fixture_count + 1))
  if ! grep -qx "$line" "$prop_keys_file"; then
    missing="$missing $line"
  fi
done < "$FIXTURE"

if [ -n "$missing" ]; then
  echo "FAIL: proposal frontmatter missing M014 manifest keys —$missing"
  exit 1
fi

# Strictness check: proposal must have keys NOT in fixture.
prop_count=$(wc -l < "$prop_keys_file" | tr -d ' ')
if [ "$prop_count" -le "$fixture_count" ]; then
  echo "FAIL: superset is not strict (proposal=$prop_count keys, fixture=$fixture_count keys)"
  exit 1
fi

echo "PASS: test-intake-manifest-superset.sh — proposal contains all $fixture_count M014 manifest keys + $((prop_count - fixture_count)) M024-specific keys"
exit 0
