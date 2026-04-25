#!/usr/bin/env bash
# m020-p03-schema-lint-vocabulary-drift.sh — assert the schema-authority lint
# rejects status: values outside the MEM031 closed enum.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LINT="$ROOT/scripts/verify/knowledge-schema-lint.sh"

if [ ! -x "$LINT" ]; then
  echo "FAIL: knowledge-schema-lint.sh missing or not executable at $LINT"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

cat >"$tmpdir/knowledge/patterns/MEM801.md" <<'EOF'
---
id: MEM801
status: deprecated
last_verified: 2026-04-25
---

# MEM801: vocabulary-drift fixture
EOF

set +e
out="$(bash "$LINT" --root "$tmpdir" 2>&1)"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "FAIL: schema-lint accepted status=deprecated. Output: $out"
  exit 1
fi

case "$out" in
  *"vocabulary-drift"*"deprecated"*) ;;
  *)
    echo "FAIL: schema-lint diagnostic missing 'vocabulary-drift' + offending value. Got: $out"
    exit 1 ;;
esac

# Also assert each canonical status value passes (no false positive for valid enum).
for valid in candidate graduated archived; do
  cat >"$tmpdir/knowledge/patterns/MEM801.md" <<EOF
---
id: MEM801
status: ${valid}
last_verified: 2026-04-25
---

# MEM801: ${valid} fixture
EOF
  if ! bash "$LINT" --root "$tmpdir" >/dev/null 2>&1; then
    echo "FAIL: schema-lint rejected valid status='$valid'"
    exit 1
  fi
done

echo "PASS: schema-lint rejects vocabulary drift, accepts every valid enum value"
exit 0
