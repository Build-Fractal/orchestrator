#!/usr/bin/env bash
# Verifies dispatch-interface.sh contains NO backend-specific branching,
# satisfying FR-011 and SC-003 (new backends can be added by dropping
# an adapter file; zero edits to this interface file required).
set -u

f="scripts/dispatch/dispatch-interface.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Forbidden patterns: any conditional that names a specific backend
# indicates the interface is no longer backend-agnostic. Allowed
# references: the placeholder "${BACKEND}" or "$BACKEND" variable.
#
# Check for literal backend names appearing in conditional expressions.
# Matches on '= "local-agent"' or '= "local-codex"' or similar patterns
# that would tie the router to a specific backend.

if grep -E '\[\[[[:space:]]+["$]?BACKEND["$]?[[:space:]]*[=!]=?[[:space:]]*["]?(local-agent|local-codex)["]?' "$f" >/dev/null; then
  echo "FAIL: $f contains backend-specific branching (compares \$BACKEND to a literal adapter name)"
  exit 1
fi

# Also check for `case "$BACKEND" in local-agent)` style branches
if grep -E 'case[[:space:]]+["$]?BACKEND["$]?' "$f" >/dev/null; then
  echo "FAIL: $f switches on \$BACKEND (backend-specific branching)"
  exit 1
fi

# The file must use filename-based resolution (ADAPTERS_DIR + BACKEND + .sh)
grep -q 'ADAPTERS_DIR' "$f" || { echo "FAIL: $f does not use ADAPTERS_DIR for filename-based resolution"; exit 1; }
grep -qE '\$\{?ADAPTERS_DIR\}?/\$\{?BACKEND\}?\.sh' "$f" || { echo "FAIL: $f does not resolve adapter via \${ADAPTERS_DIR}/\${BACKEND}.sh"; exit 1; }

echo "PASS: dispatch-interface.sh is backend-agnostic (filename-based resolution only)"
