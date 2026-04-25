#!/usr/bin/env bash
# m020-p01-frontmatter-helper-contract.sh — exercise every public function
# of lib/frontmatter.sh against a tempfile fixture. Bash 3.2 safe.
#
# Cases:
#   1. fm_read_status returns "graduated" when status: line is absent (FR-10)
#   2. fm_write_status inserts the field on first write
#   3. fm_write_status replaces (not duplicates) on subsequent writes
#   4. fm_assert_closed_enum rejects out-of-enum values
#   5. fm_write_archived_into writes the back-reference field
#   6. fm_append_decision_history creates the key + record on first call
#   7. atomic write discipline — no .tmp.* debris remains after writes
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/knowledge/lib/frontmatter.sh"

if [ ! -f "$HELPER" ]; then
  echo "FAIL: frontmatter helper missing at $HELPER"
  exit 1
fi

# shellcheck source=/dev/null
. "$ROOT/scripts/knowledge/lib/index-utils.sh"
# shellcheck source=/dev/null
. "$ROOT/scripts/knowledge/lib/detail-utils.sh"
# shellcheck source=/dev/null
. "$HELPER"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
fixture="$tmpdir/MEM999.md"

cat > "$fixture" <<'EOF'
---
id: MEM999
scope_tags: "[project]"
category: patterns
confidence: 0.5
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 0
source_unit: "test"
source_type: test
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
---

# MEM999: Fixture entry for contract test

Body content.
EOF

# --- Test 1: fm_read_status default (FR-10) ---
result="$(fm_read_status "$fixture")"
if [ "$result" != "graduated" ]; then
  echo "FAIL: fm_read_status default returned '$result', expected 'graduated'"
  exit 1
fi

# --- Test 2: fm_write_status inserts on first write ---
fm_write_status "$fixture" candidate >/dev/null
if ! grep -q "^status: candidate$" "$fixture"; then
  echo "FAIL: fm_write_status did not insert status line"
  exit 1
fi

# read-back round-trip
result="$(fm_read_status "$fixture")"
if [ "$result" != "candidate" ]; then
  echo "FAIL: fm_read_status after insert returned '$result', expected 'candidate'"
  exit 1
fi

# --- Test 3: fm_write_status replaces on subsequent write ---
fm_write_status "$fixture" graduated >/dev/null
count="$(grep -c "^status:" "$fixture" | tr -d ' ')"
if [ "$count" != "1" ]; then
  echo "FAIL: fm_write_status produced $count status lines, expected 1"
  exit 1
fi
if ! grep -q "^status: graduated$" "$fixture"; then
  echo "FAIL: fm_write_status did not replace value"
  exit 1
fi

# --- Test 4: closed-enum rejection ---
# Run in subshell so the exit 1 from fm_assert_closed_enum doesn't kill us.
if ( fm_write_status "$fixture" pending ) 2>/dev/null; then
  echo "FAIL: fm_write_status accepted out-of-enum value 'pending'"
  exit 1
fi
# After rejection the file must still have exactly one status line, and it
# must still be the prior value (the rejection runs BEFORE the tempfile).
count="$(grep -c "^status:" "$fixture" | tr -d ' ')"
if [ "$count" != "1" ]; then
  echo "FAIL: rejected enum write left file with $count status lines"
  exit 1
fi
if ! grep -q "^status: graduated$" "$fixture"; then
  echo "FAIL: rejected enum write mutated prior value"
  exit 1
fi

# --- Test 5: archived_into write ---
fm_write_archived_into "$fixture" MEM042 >/dev/null
if ! grep -q "^archived_into: MEM042$" "$fixture"; then
  echo "FAIL: fm_write_archived_into did not write field"
  exit 1
fi
count="$(grep -c "^archived_into:" "$fixture" | tr -d ' ')"
if [ "$count" != "1" ]; then
  echo "FAIL: archived_into has $count lines, expected 1"
  exit 1
fi

# --- Test 6: decision_history append (creates key when absent) ---
fm_append_decision_history "$fixture" "merge test" "tester" "C1" >/dev/null
if ! grep -q "^decision_history:" "$fixture"; then
  echo "FAIL: fm_append_decision_history did not create key"
  exit 1
fi
if ! grep -q 'rationale: "merge test"' "$fixture"; then
  echo "FAIL: fm_append_decision_history did not write rationale"
  exit 1
fi
if ! grep -q 'operator: "tester"' "$fixture"; then
  echo "FAIL: fm_append_decision_history did not write operator"
  exit 1
fi
if ! grep -q 'cluster_id: "C1"' "$fixture"; then
  echo "FAIL: fm_append_decision_history did not write cluster_id"
  exit 1
fi
if ! grep -q 'timestamp: "20[0-9][0-9]-' "$fixture"; then
  echo "FAIL: fm_append_decision_history did not write ISO-8601 timestamp"
  exit 1
fi

# --- Test 7: atomic write discipline — no .tmp.* debris ---
leftover="$(find "$tmpdir" -name '*.tmp.*' -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$leftover" != "0" ]; then
  echo "FAIL: $leftover .tmp files left behind after writes"
  exit 1
fi

# --- Test 8 (bonus): byte-equivalence of unrelated body content ---
# The body line "Body content." must survive every write untouched.
if ! grep -q "^Body content\.$" "$fixture"; then
  echo "FAIL: body content was mutated by frontmatter writes (CON-4 violated)"
  exit 1
fi

echo "PASS: frontmatter helper contract honored (7/7 cases)"
exit 0
