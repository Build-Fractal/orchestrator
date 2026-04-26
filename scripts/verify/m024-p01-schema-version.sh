#!/usr/bin/env bash
# scripts/verify/m024-p01-schema-version.sh
# Asserts proposal frontmatter pins schema_version: "1.0" (AD-3) and does
# NOT introduce intake_schema_version.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$ROOT/templates/intake-proposal.md"

if ! grep -q '^schema_version: "1.0"' "$TEMPLATE"; then
  echo "FAIL: $TEMPLATE missing 'schema_version: \"1.0\"' pin"
  exit 1
fi

if grep -q '^intake_schema_version' "$TEMPLATE"; then
  echo "FAIL: $TEMPLATE introduces intake_schema_version (forbidden by AD-3)"
  exit 1
fi

echo "PASS: schema_version pin AD-3 honored"
exit 0
