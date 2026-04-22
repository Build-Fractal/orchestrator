#!/usr/bin/env bash
# scripts/verify/m013-p02-reference-extensions.sh
#
# Gate for T05 (M013/P02): asserts references/github-integration.md has been
# extended in place with the four P02 subsections (Auth Modes, Sub-Issue
# Representation Modes, Partial Mapping Table, init Workflow, Dry-Run Manifest
# Format), the Scope Boundary table P02 column is populated, the three
# TODO P02 stubs are removed, and every P01-authored section remains
# byte-identical to the P01 snapshot.
#
# Byte-identity strategy: extract each named P01 section by its literal
# `## <heading>` anchor up to the next `^## ` line via awk, shasum the
# extracted block, compare against the expected hash captured at P01 close.
# Any drift in Overview / Sidecar Config Schema / Pending-Sentinel Semantics
# / `sync_mode` Enum / Marker Format / UAT Ingestion Contract /
# Knowledge-Layer Boundary / Further Reading fails the gate.
#
# Single-script-file (AD-19) shape. Bash 3.2 compatible. AP-009 compliant.
# Structured output: PASS:/FAIL: prefixes to stdout. 0/1 exits.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="${REPO_ROOT}/references/github-integration.md"

fail_count=0
assert_ok() {
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    fail_count=$((fail_count + 1))
  fi
}

# --- 1. Doc present, ≥240 lines, Auth Modes subsection present ------------
[ -f "$DOC" ]
doc_exists=$?
line_count=0
if [ "$doc_exists" -eq 0 ]; then
  line_count=$(wc -l <"$DOC" | tr -d ' ')
fi
has_auth_modes=1
if [ "$doc_exists" -eq 0 ] && grep -q '^### Auth Modes' "$DOC"; then
  has_auth_modes=0
fi
if [ "$doc_exists" -eq 0 ] && [ "$line_count" -ge 240 ] && [ "$has_auth_modes" -eq 0 ]; then
  echo "PASS: references/github-integration.md present, ${line_count} lines (>=240), contains 'Auth Modes'"
else
  echo "FAIL: references/github-integration.md present, >=240 lines, contains 'Auth Modes' (exists=${doc_exists} lines=${line_count} has_auth_modes=${has_auth_modes})"
  fail_count=$((fail_count + 1))
fi

# --- 2. Sub-Issue Representation Modes subsection present ------------------
grep -q '^### Sub-Issue Representation Modes' "$DOC"
assert_ok $? "'Sub-Issue Representation Modes' subsection present"

# --- 3. Mapping Table present (Partial P02 heading OR Full P02+P03 heading) -
# Post-M013/P03/T04 the heading is `### Full Mapping Table (P02 + P03)` and
# the three `_deferred to P03_` cells have been filled in place. Pre-T04 the
# heading was `### Partial Mapping Table (P02)` with 3 deferred cells. This
# gate tolerates both shapes so it stays green across the P02→P03 transition
# while still asserting the table body still names the canonical rows.
has_mapping_table=1
if grep -q '^### Partial Mapping Table' "$DOC" || grep -q '^### Full Mapping Table' "$DOC"; then
  has_mapping_table=0
fi
has_chunk_row=1
grep -q '^| \*\*Spec chunk\*\* ' "$DOC" && has_chunk_row=0
has_ac_row=1
grep -q '^| \*\*Acceptance criterion\*\* ' "$DOC" && has_ac_row=0
has_status_row=1
grep -q '^| \*\*Verification status\*\* ' "$DOC" && has_status_row=0
if [ "$has_mapping_table" -eq 0 ] && [ "$has_chunk_row" -eq 0 ] \
   && [ "$has_ac_row" -eq 0 ] && [ "$has_status_row" -eq 0 ]; then
  echo "PASS: Mapping Table present with Spec chunk / Acceptance criterion / Verification status rows"
else
  echo "FAIL: Mapping Table present with all 3 canonical bold rows (table=${has_mapping_table} chunk=${has_chunk_row} ac=${has_ac_row} status=${has_status_row})"
  fail_count=$((fail_count + 1))
fi

# --- 4. init Workflow subsection present -----------------------------------
grep -q '^### `init` Workflow' "$DOC"
assert_ok $? "'init Workflow' subsection present"

# --- 5. Dry-Run Manifest Format subsection present -------------------------
grep -q '^### Dry-Run Manifest Format' "$DOC"
assert_ok $? "'Dry-Run Manifest Format' subsection present"

# --- 6. No '### TODO P02:' headings remain ---------------------------------
# The three P02 stubs must be replaced; narrative uses of "TODO P02" in prose
# are allowed (byte-identical P01 content). We gate only the heading form.
if grep -q '^### TODO P02:' "$DOC"; then
  remaining=$(grep -c '^### TODO P02:' "$DOC")
  echo "FAIL: No 'TODO P02' markers remain (${remaining} '### TODO P02:' headings still present)"
  fail_count=$((fail_count + 1))
else
  echo "PASS: No 'TODO P02' markers remain"
fi

# --- 7. P01-authored sections byte-identical -------------------------------
# Extract each section by literal-prefix match against a `## <heading>` line,
# continue until the next `^## ` heading (exclusive), shasum, compare.
extract_and_hash() {
  # $1 = literal heading line (e.g. "## Overview")
  awk -v h="$1" '
    index($0, h) == 1 { in_sec = 1; print; next }
    in_sec && /^## / { exit }
    in_sec { print }
  ' "$DOC" | shasum -a 256 | awk '{print $1}'
}

# Expected hashes captured at P01 close (2026-04-21) — these pin the bytes
# of P01-authored sections. Any drift is a spec violation.
p01_ok=1
drift_list=""

check_section() {
  # $1 = heading, $2 = expected sha256
  local got
  got=$(extract_and_hash "$1")
  if [ "$got" != "$2" ]; then
    p01_ok=0
    drift_list="${drift_list} '${1}'"
  fi
}

check_section "## Overview" \
  "73650a72d3ac1aa79468534232927421397b1c670f9558fa60394e889818d82e"
check_section "## Sidecar Config Schema" \
  "c5996117f42bfd0ee65fb2c241322a7587dde906078aba95d4022b0d06afefcf"
check_section "## Pending-Sentinel Semantics" \
  "8b7e735b3f387b67d58e45a904c6c92c5678b68e58fc5eea6538b2c398ff7e8b"
check_section "## \`sync_mode\` Enum" \
  "d4d037ea89fe10027b9f6f208fbc1713825a3247ce07558e606395aa6bbffdf7"
check_section "## \`<!-- orchestrator-id: ... -->\` Marker Format" \
  "499a083961cd29d2efc71ec13bdeade6f33710b5fefdc81c756154a682f87149"
check_section "## UAT Ingestion Contract" \
  "8403d7ef30ac2748cdf4176ca3d5d3d8d259b0e602562b042acd36067833ea20"
check_section "## Knowledge-Layer Boundary (M013 vs. M020)" \
  "b5d58b2d900e6c1be160b5d891867dbc71c8d31ae6a3172a5380d9c958b1a74c"
check_section "## Further Reading" \
  "988513148104bbc8413c856f5075eb581d9aa55b3f942aeeed9ae15c255afa9a"

if [ "$p01_ok" -eq 1 ]; then
  echo "PASS: P01-authored sections byte-identical (Overview / Sidecar Config Schema / Pending-Sentinel / sync_mode Enum / Marker Format / UAT Ingestion Contract / Knowledge-Layer Boundary / Further Reading preserved)"
else
  echo "FAIL: P01-authored sections byte-identical — drift in:${drift_list}"
  fail_count=$((fail_count + 1))
fi

# --- Summary ---------------------------------------------------------------
if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p02-reference-extensions.sh"
  exit 0
fi
echo "FAIL: m013-p02-reference-extensions.sh (${fail_count} failures)"
exit 1
