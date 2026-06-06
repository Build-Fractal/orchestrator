#!/usr/bin/env bash
# tools/verify/m034-p01-schema-shape.sh — M034 P01 T01 slice verifier.
#
# Asserts the decision-packet schema-shape contract:
#   (a) templates/decisions-packet.md exists, is versioned, carries the
#       decision-packet frontmatter type, and documents all eight
#       required fields in its schema-doc comment block.
#   (b) scripts/knowledge/lib/decisions-constants.sh exists and defines
#       the severity default, type default, and FR-4 warn threshold.
#   (c) the P00 baseline fixture validates against the schema — every
#       `## D-N` block carries the eight required `- **field**:` lines.
#
# Prints "PASS: m034-p01 schema-shape" on success; "FAIL: <file>:<reason>"
# + exit 1 on any miss. Bash 3.2 / POSIX-sh; grep/test only (CON-1/CON-2).

# Resolve repo root from this script's location (tools/verify/ -> repo root).
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

TEMPLATE="$REPO_ROOT/templates/decisions-packet.md"
CONSTANTS="$REPO_ROOT/scripts/knowledge/lib/decisions-constants.sh"
FIXTURE="$REPO_ROOT/.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md"

REQUIRED_FIELDS="id summary picked_value rationale alternatives_considered concrete_impact severity type"

fail() {
  printf 'FAIL: %s\n' "$1"
  exit 1
}

# --- (a) template -----------------------------------------------------------
test -f "$TEMPLATE" || fail "$TEMPLATE:missing"
grep -q 'schema_version' "$TEMPLATE" || fail "$TEMPLATE:no schema_version"
grep -q 'type: decision-packet' "$TEMPLATE" || fail "$TEMPLATE:no type: decision-packet frontmatter"

for field in $REQUIRED_FIELDS; do
  grep -q "$field" "$TEMPLATE" || fail "$TEMPLATE:schema-doc missing field $field"
done

# --- (b) constants SSOT ------------------------------------------------------
test -f "$CONSTANTS" || fail "$CONSTANTS:missing"
grep -q 'DECISIONS_SEVERITY_DEFAULT' "$CONSTANTS" || fail "$CONSTANTS:no DECISIONS_SEVERITY_DEFAULT"
grep -q 'DECISIONS_TYPE_DEFAULT' "$CONSTANTS" || fail "$CONSTANTS:no DECISIONS_TYPE_DEFAULT"
grep -q 'DECISIONS_WARN_FINDING_THRESHOLD' "$CONSTANTS" || fail "$CONSTANTS:no DECISIONS_WARN_FINDING_THRESHOLD"

# --- (c) baseline fixture validates against the schema ----------------------
test -f "$FIXTURE" || fail "$FIXTURE:missing"

# Collect the decision-entry block ids (## D-N headings).
block_ids=$(grep -E '^## D-[0-9]+' "$FIXTURE" | sed -e 's/^## //')

if [ -z "$block_ids" ]; then
  fail "$FIXTURE:no ## D-N entry blocks found"
fi

# For each block, slice out its body and assert the eight required fields.
for bid in $block_ids; do
  # Body = lines from "## <bid>" up to the next "## " heading (or EOF).
  body=$(awk -v id="$bid" '
    $0 == "## " id { inblk=1; next }
    inblk && /^## / { inblk=0 }
    inblk { print }
  ' "$FIXTURE")

  for field in $REQUIRED_FIELDS; do
    if ! printf '%s\n' "$body" | grep -q "^- \*\*$field\*\*:"; then
      fail "$FIXTURE:$bid missing required field $field"
    fi
  done
done

printf 'PASS: m034-p01 schema-shape\n'
exit 0
