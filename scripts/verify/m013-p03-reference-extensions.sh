#!/usr/bin/env bash
# scripts/verify/m013-p03-reference-extensions.sh — M013/P03/T04 gate.
#
# Asserts:
#   (1) 3 `_deferred to P03_` cells are GONE from the Full Mapping Table.
#   (2) Table heading is `### Full Mapping Table (P02 + P03)`.
#   (3) 3 `### TODO P03:` stub headings are relabeled to `### TODO P04:`
#       (zero P03 headings remain; exactly 3 P04 headings present).
#   (4) `### Re-init Adoption Contract (FR-14)` subsection present with key
#       anchors (adopted=, gh_marker_search_remote, integration-marker-duplicate).
#   (5) Scope Boundary table has the FR-5 lint row referencing
#       `scripts/verify/graphql-call-shape.sh`.
#   (6) P01-authored sections byte-identity preserved (via P02 gate green).
#   (7) P02-authored sections byte-identity preserved (via P02 gate green).
#   (8) commands/github-init.md contains `--re-init` in its content.
#
# Byte-identity gating reuses the P02/T05 pattern: rather than embedding
# section-content sha256 hashes here, this gate relies on the P02
# reference-extensions gate as the definitive regression guard — if the
# P02 gate still exits 0, no P01/P02-hashed section was touched. This
# keeps hash embeddings in one place (AD-19 single-source).
#
# Single-script-file (AD-19) shape. Bash 3.2 compatible. AP-009 compliant.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="${REPO_ROOT}/references/github-integration.md"
CMD="${REPO_ROOT}/commands/github-init.md"

passed=0
failed=0

pass() {
  echo "PASS: $1"
  passed=$((passed + 1))
}
fail() {
  echo "FAIL: $1"
  failed=$((failed + 1))
}

# Pre-flight: target doc exists.
if [ ! -f "$DOC" ]; then
  fail "references/github-integration.md missing at ${DOC}"
  echo "SUMMARY: m013-p03-reference-extensions.sh pass=${passed} fail=${failed}"
  echo "FAIL: m013-p03-reference-extensions.sh" >&2
  exit 1
fi
if [ ! -f "$CMD" ]; then
  fail "commands/github-init.md missing at ${CMD}"
  echo "SUMMARY: m013-p03-reference-extensions.sh pass=${passed} fail=${failed}"
  echo "FAIL: m013-p03-reference-extensions.sh" >&2
  exit 1
fi

# (1) No _deferred to P03_ cells remain.
if grep -q '_deferred to P03_' "$DOC"; then
  fail "Mapping table still contains _deferred to P03_ cells"
else
  pass "All _deferred to P03_ cells filled"
fi

# (2) Heading rename.
if grep -q '^### Full Mapping Table (P02 + P03)$' "$DOC"; then
  pass "Mapping table heading renamed to Full Mapping Table (P02 + P03)"
else
  fail "Expected heading '### Full Mapping Table (P02 + P03)' missing"
fi

# (3a) Zero `### TODO P03:` headings remain.
if grep -qE '^### TODO P03:' "$DOC"; then
  fail "'### TODO P03:' headings still present (should be relabeled to P04)"
else
  pass "'### TODO P03:' headings relabeled"
fi

# (3b) Exactly three `### TODO P04:` headings.
p04_count=$(grep -cE '^### TODO P04:' "$DOC" 2>/dev/null || echo 0)
# strip any whitespace (macOS grep -c can emit leading spaces on empty case)
p04_count=$(printf '%s' "$p04_count" | tr -d ' \n')
if [ "${p04_count:-0}" = "3" ]; then
  pass "3 '### TODO P04:' headings present"
else
  fail "Expected 3 '### TODO P04:' headings, got ${p04_count:-0}"
fi

# (4) Re-init Adoption Contract subsection present with anchors.
if grep -q '^### Re-init Adoption Contract (FR-14)$' "$DOC"; then
  pass "Re-init Adoption Contract (FR-14) heading present"
else
  fail "Re-init Adoption Contract (FR-14) heading missing"
fi
if grep -q 'adopted=' "$DOC"; then
  pass "adopted= footer documented"
else
  fail "adopted= footer not documented"
fi
if grep -q 'gh_marker_search_remote' "$DOC"; then
  pass "gh_marker_search_remote helper name mentioned"
else
  fail "gh_marker_search_remote helper name missing"
fi
if grep -q 'integration-marker-duplicate' "$DOC"; then
  pass "integration-marker-duplicate diagnostic documented"
else
  fail "integration-marker-duplicate diagnostic missing"
fi

# (5) FR-5 lint row in Scope Boundary table.
if grep -q 'FR-5 GraphQL call-shape lint' "$DOC"; then
  pass "FR-5 GraphQL call-shape lint row in Scope Boundary"
else
  fail "FR-5 GraphQL call-shape lint row missing from Scope Boundary"
fi
if grep -q 'scripts/verify/graphql-call-shape.sh' "$DOC"; then
  pass "scripts/verify/graphql-call-shape.sh path referenced"
else
  fail "scripts/verify/graphql-call-shape.sh path not referenced in doc"
fi

# (6,7) P01 + P02 section byte-identity via the P02 gate as SSOT.
p02_gate="${REPO_ROOT}/scripts/verify/m013-p02-reference-extensions.sh"
if [ -f "$p02_gate" ]; then
  bash "$p02_gate" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "P02 reference-extensions gate still green (P01/P02 section byte-identity preserved)"
  else
    fail "P02 reference-extensions gate REGRESSION (rc=${rc}) — P01/P02 sections touched"
  fi
else
  fail "P02 reference-extensions gate missing at ${p02_gate}"
fi

# (8) commands/github-init.md names --re-init.
if grep -q -- '--re-init' "$CMD"; then
  pass "--re-init documented in commands/github-init.md"
else
  fail "--re-init missing from commands/github-init.md"
fi

# Regression guard: P02 github-init-command gate still green.
p02_cmd_gate="${REPO_ROOT}/scripts/verify/m013-p02-github-init-command.sh"
if [ -f "$p02_cmd_gate" ]; then
  bash "$p02_cmd_gate" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "P02 github-init-command gate still green"
  else
    fail "P02 github-init-command gate REGRESSION (rc=${rc})"
  fi
else
  fail "P02 github-init-command gate missing at ${p02_cmd_gate}"
fi

echo "SUMMARY: m013-p03-reference-extensions.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-reference-extensions.sh"
  exit 0
fi
echo "FAIL: m013-p03-reference-extensions.sh" >&2
exit 1
