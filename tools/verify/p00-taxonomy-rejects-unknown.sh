#!/usr/bin/env bash
# tools/verify/p00-taxonomy-rejects-unknown.sh -- M036 P00 T03 negative
# test for the chunk-frontmatter validator. Asserts the validator
# rejects out-of-taxonomy categories AND out-of-{0,1,2} tiers, and
# accepts in-policy combinations.
#
# Three fixtures, three assertions:
#   A: category=blog-post + tier=1   -> reject (out-of-taxonomy category)
#   B: category=cms-rule + tier=5    -> reject (out-of-enum tier)
#   C: category=cms-rule + tier=2    -> accept (in-policy)
set -eu
VALIDATOR="${1:-tools/verify/lib/p00-validate-chunk-frontmatter.sh}"
pass=0
fail=0
if [ ! -f "$VALIDATOR" ]; then
  echo "FAIL: $VALIDATOR missing"
  echo "SUMMARY: p00-taxonomy-rejects-unknown.sh pass=0 fail=1"
  exit 1
fi
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Fixture A -- out-of-taxonomy category, must reject (validator exits 1).
cat > "$TMPDIR/a.yaml" <<'EOF'
category: blog-post
tier: 1
EOF
if bash "$VALIDATOR" "$TMPDIR/a.yaml" >/dev/null 2>&1; then
  fail=$((fail + 1))
  echo "FAIL: validator accepted out-of-taxonomy category=blog-post (expected reject)"
else
  pass=$((pass + 1))
fi

# Fixture B -- out-of-enum tier, must reject (validator exits 1).
cat > "$TMPDIR/b.yaml" <<'EOF'
category: cms-rule
tier: 5
EOF
if bash "$VALIDATOR" "$TMPDIR/b.yaml" >/dev/null 2>&1; then
  fail=$((fail + 1))
  echo "FAIL: validator accepted out-of-enum tier=5 (expected reject)"
else
  pass=$((pass + 1))
fi

# Fixture C -- in-policy, must accept (validator exits 0).
cat > "$TMPDIR/c.yaml" <<'EOF'
category: cms-rule
tier: 2
EOF
if bash "$VALIDATOR" "$TMPDIR/c.yaml" >/dev/null 2>&1; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "FAIL: validator rejected in-policy category=cms-rule tier=2 (expected accept)"
fi

echo "SUMMARY: p00-taxonomy-rejects-unknown.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
