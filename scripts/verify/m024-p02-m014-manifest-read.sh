#!/usr/bin/env bash
# scripts/verify/m024-p02-m014-manifest-read.sh
# M024/P02/T02 — Verifies m014-manifest-read.sh emits the six M014 manifest keys
# in canonical order against an in-repo spec, and that --spec-path / --specs-dir
# yield byte-identical output.
#
# DEVIATION FROM T02-PLAN: plan named specs/023-github-native-integration as the
# in-repo fixture, but that spec predates the M014 type:feature-spec frontmatter
# rollout. Using specs/028-universal-intake-routing instead (in-repo, M014-migrated).
# Same precedent as T01-SUMMARY.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
READER="$ROOT/scripts/intake/m014-manifest-read.sh"
SPEC_DIR="$ROOT/specs/028-universal-intake-routing"
SPEC="$SPEC_DIR/spec.md"

if [ ! -x "$READER" ]; then
  echo "FAIL: $READER not executable"
  exit 1
fi
if [ ! -f "$SPEC" ]; then
  echo "FAIL: fixture spec missing: $SPEC"
  exit 1
fi

out=$(bash "$READER" --spec-path "$SPEC")

# Six lines, in canonical order.
line_count=$(printf '%s\n' "$out" | grep -c '^')
if [ "$line_count" -ne 6 ]; then
  echo "FAIL: expected 6 lines, got $line_count — out: $out"
  exit 1
fi

printf '%s\n' "$out" | sed -n '1p' | grep -q '^schema_version=' || { echo "FAIL: line 1 not schema_version"; exit 1; }
printf '%s\n' "$out" | sed -n '2p' | grep -q '^type='           || { echo "FAIL: line 2 not type"; exit 1; }
printf '%s\n' "$out" | sed -n '3p' | grep -q '^feature_slug='   || { echo "FAIL: line 3 not feature_slug"; exit 1; }
printf '%s\n' "$out" | sed -n '4p' | grep -q '^created_at='     || { echo "FAIL: line 4 not created_at"; exit 1; }
printf '%s\n' "$out" | sed -n '5p' | grep -q '^status='         || { echo "FAIL: line 5 not status"; exit 1; }
printf '%s\n' "$out" | sed -n '6p' | grep -q '^milestone='      || { echo "FAIL: line 6 not milestone"; exit 1; }

# --specs-dir resolution must produce identical output to --spec-path.
out2=$(bash "$READER" --specs-dir "$SPEC_DIR")

tmp_a=$(mktemp)
tmp_b=$(mktemp)
trap 'rm -f "$tmp_a" "$tmp_b"' EXIT
printf '%s\n' "$out"  > "$tmp_a"
printf '%s\n' "$out2" > "$tmp_b"
if ! diff -q "$tmp_a" "$tmp_b" >/dev/null 2>&1; then
  echo "FAIL: --spec-path and --specs-dir produced different output"
  exit 1
fi

echo "PASS: m014-manifest-read.sh — six keys in canonical order, --spec-path / --specs-dir parity"
exit 0
