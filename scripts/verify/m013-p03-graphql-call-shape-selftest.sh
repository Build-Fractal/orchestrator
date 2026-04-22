#!/usr/bin/env bash
# scripts/verify/m013-p03-graphql-call-shape-selftest.sh — T03 gate.
#
# Asserts:
#   (1) graphql-call-shape.sh exits 0 against the live repo (exactly the
#       whitelisted shapes are present post-P02).
#   (1b) the live-repo SHAPE: output reports createProjectV2 and
#        addProjectV2ItemById.
#   (2) graphql-call-shape.sh exits non-zero when a fixture contains an
#       injected fourth shape.
#   (3) the diagnostic line contains the offending shape name.
#
# Bash 3.2 compatible.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="${REPO_ROOT}/scripts/verify/graphql-call-shape.sh"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# (1) Live repo run — must exit 0.
if bash "$LINT" >/dev/null 2>&1; then
  pass "live repo: lint exits 0"
else
  fail "live repo: lint failed (post-P02 repo should have only whitelisted shapes)"
fi

# (1b) Live repo output must contain the two post-P02 shapes.
live_out="$(bash "$LINT" 2>/dev/null || true)"
if printf '%s\n' "$live_out" | grep -q 'SHAPE: createProjectV2'; then
  pass "createProjectV2 detected in live repo"
else
  fail "createProjectV2 not detected (regression in P02 init)"
fi
if printf '%s\n' "$live_out" | grep -q 'SHAPE: addProjectV2ItemById'; then
  pass "addProjectV2ItemById detected in live repo"
else
  fail "addProjectV2ItemById not detected (regression in P02 init)"
fi

# (2) Fixture with injected fourth shape.
fx_dir="$(mktemp -d -t m013-p03-lint.XXXXXX)"
cat > "${fx_dir}/github-evilrogue.sh" <<'EOF'
#!/usr/bin/env bash
# Fixture: inject a non-whitelisted mutation to confirm the lint catches it.
gh api graphql --field query='mutation($id:ID!){deleteProjectV2(input:{projectId:$id}){clientMutationId}}' || true
EOF

# Copy the real github-init.sh shapes so the lint finds whitelist members
# alongside the intruder (realistic failure shape).
cp "${REPO_ROOT}/scripts/integrations/github-init.sh" "${fx_dir}/" 2>/dev/null || true

fail_out="$(bash "$LINT" "$fx_dir" 2>&1 || true)"
if printf '%s\n' "$fail_out" | grep -q 'unexpected shape: deleteProjectV2'; then
  pass "fixture: deleteProjectV2 flagged as unexpected"
else
  fail "fixture: deleteProjectV2 NOT flagged"
fi

# Final rc must be non-zero when running against the fixture.
if bash "$LINT" "$fx_dir" >/dev/null 2>&1; then
  fail "fixture: lint exited 0 despite injected fourth shape"
else
  pass "fixture: lint exited non-zero on injected fourth shape"
fi

rm -rf "$fx_dir"
echo "SUMMARY: m013-p03-graphql-call-shape-selftest.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-graphql-call-shape-selftest.sh"
  exit 0
fi
echo "FAIL: m013-p03-graphql-call-shape-selftest.sh" >&2
exit 1
