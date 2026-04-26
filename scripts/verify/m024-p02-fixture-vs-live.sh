#!/usr/bin/env bash
# scripts/verify/m024-p02-fixture-vs-live.sh
# Asserts the P01 fixture key-list equals the live M014 reader's key-list
# (same keys, same canonical order). When they drift, FAIL names both sets;
# operator re-captures the fixture by hand from the live reader output.
#
# DEVIATION FROM T04-PLAN: plan referenced specs/023-github-native-integration as
# the spec-path target. The reader requires `type: feature-spec` frontmatter which
# 023 lacks; this verify pivots to specs/028-universal-intake-routing (matches the
# precedent set by scripts/verify/m024-p02-m014-manifest-read.sh from T02).

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
READER="$ROOT/scripts/intake/m014-manifest-read.sh"
FIXTURE="$ROOT/tests/fixtures/m014-interim-manifest-keys.txt"
SPEC="$ROOT/specs/028-universal-intake-routing/spec.md"

[ -x "$READER" ]  || { echo "FAIL: reader missing: $READER"; exit 1; }
[ -f "$FIXTURE" ] || { echo "FAIL: fixture missing: $FIXTURE"; exit 1; }
[ -f "$SPEC" ]    || { echo "FAIL: spec missing: $SPEC"; exit 1; }

tmp_live=$(mktemp)
tmp_fix=$(mktemp)
trap 'rm -f "$tmp_live" "$tmp_fix"' EXIT

# Live: extract key portion (left of the `=`).
bash "$READER" --spec-path "$SPEC" | sed -E 's/=.*//' > "$tmp_live"

# Fixture: strip comments and blanks.
grep -v '^#' "$FIXTURE" | grep -v '^$' > "$tmp_fix"

if ! diff -q "$tmp_fix" "$tmp_live" >/dev/null 2>&1; then
  echo "FAIL: fixture key-list drifted from live reader."
  echo "----- fixture -----"; cat "$tmp_fix"
  echo "----- live -----"; cat "$tmp_live"
  echo "Recover: re-capture fixture by running 'bash $READER --spec-path $SPEC | sed -E s/=.*//'"
  exit 1
fi

echo "PASS: fixture-vs-live — fixture key-list matches live M014 reader output"
exit 0
