#!/usr/bin/env bash
# m020-p03-schema-lint-contract.sh — assert the schema-authority lint:
#   1. Exits 0 against the live knowledge/**/MEM*.md tree.
#   2. Exits non-zero against a fixture introducing an unauthorized field.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LINT="$ROOT/scripts/verify/knowledge-schema-lint.sh"

if [ ! -x "$LINT" ]; then
  echo "FAIL: knowledge-schema-lint.sh missing or not executable at $LINT"
  exit 1
fi

# --- Case 1: live tree must pass ---
if ! bash "$LINT" --root "$ROOT" >/dev/null 2>&1; then
  out="$(bash "$LINT" --root "$ROOT" 2>&1 || true)"
  echo "FAIL: schema-lint failed against the live knowledge tree:"
  echo "$out"
  exit 1
fi

# --- Case 2: unauthorized-field fixture must fail ---
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

cat >"$tmpdir/knowledge/patterns/MEM800.md" <<'EOF'
---
id: MEM800
status: candidate
unauthorized_field: "this should fail the lint"
last_verified: 2026-04-25
---

# MEM800: unauthorized-field fixture
EOF

set +e
out2="$(bash "$LINT" --root "$tmpdir" 2>&1)"
rc2=$?
set -e

if [ "$rc2" -eq 0 ]; then
  echo "FAIL: schema-lint accepted unauthorized field. Output: $out2"
  exit 1
fi

case "$out2" in
  *"unauthorized-field"*"unauthorized_field"*) ;;
  *)
    echo "FAIL: schema-lint diagnostic missing 'unauthorized-field' for the offending field. Got: $out2"
    exit 1 ;;
esac

echo "PASS: schema-lint accepts live tree + rejects unauthorized field"
exit 0
