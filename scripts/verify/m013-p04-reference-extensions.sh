#!/usr/bin/env bash
# scripts/verify/m013-p04-reference-extensions.sh
#
# T06 gate: references/github-integration.md P04 extensions.
#
# Asserts:
#   (1) Five new P04 subsections present: Sync Modes, Rate-Limit & Auth-Expiry
#       Semantics, Observability Record Schema, --verify-cache Semantics,
#       Conversus Gate Invocation Contract.
#   (2) Zero `### TODO P04:` stubs remain (all filled).
#   (3) Full Mapping Table has sync action rows.
#   (4) Scope Boundary table has a P04 column.
#   (5) P01-authored section byte-identity preserved via pinned sha.
#       (awk range: `^## Overview` through `^## Sidecar Config Schema` —
#       matches the P02 gate's Overview section boundary stop.)
#   (6) P02-authored init Workflow section byte-identity preserved via pinned
#       sha (awk range: `^### `init` Workflow` through `^### Dry-Run Manifest
#       Format`).
#   (7) P03-authored Re-init Adoption Contract section byte-identity preserved
#       via pinned sha (awk range: `^### Re-init Adoption Contract` through
#       `^### Sync Workflow`).
#   (8) Reference doc line count floor held (>=400 lines).
#   (9) P02 reference-extensions gate still green (SSOT for `^## ` section
#       byte-identity on the eight P01-authored top-level sections).
#  (10) P04 filled subsections contain load-bearing anchors (FR-15, FR-16,
#       FR-17, FR-18, updateProjectV2ItemFieldValue, strict mode, 30s timeout).
#
# Single-script-file (AD-19) shape. Bash 3.2 compatible. AP-009 compliant.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REF="${REPO_ROOT}/references/github-integration.md"

passed=0
failed=0
fail() {
  echo "FAIL: $1"
  failed=$((failed + 1))
}
pass() {
  echo "PASS: $1"
  passed=$((passed + 1))
}

# Pre-flight: doc exists.
if [ ! -f "$REF" ]; then
  fail "references/github-integration.md missing at ${REF}"
  echo "SUMMARY: m013-p04-reference-extensions.sh pass=${passed} fail=${failed}"
  echo "FAIL: m013-p04-reference-extensions.sh" >&2
  exit 1
fi

# (1) Five new subsection headings.
for h in "### Sync Modes" "### Rate-Limit & Auth-Expiry Semantics" "### Observability Record Schema" "### \`--verify-cache\` Semantics" "### Conversus Gate Invocation Contract"; do
  if grep -qF "$h" "$REF"; then
    pass "subsection present: ${h}"
  else
    fail "subsection missing: ${h}"
  fi
done

# (2) Zero `### TODO P04:` stubs remain.
if grep -qE '^### TODO P04:' "$REF"; then
  todo_remaining=$(grep -cE '^### TODO P04:' "$REF" | tr -d ' \n')
  fail "${todo_remaining} '### TODO P04:' stubs still present"
else
  pass "zero '### TODO P04:' stubs remain"
fi

# (3) Full Mapping Table has sync action rows. We assert the Sync Action
# Mapping (P04) subsection is present and names each of the three reasons.
if grep -q '^#### Sync Action Mapping' "$REF"; then
  pass "Sync Action Mapping (P04) sub-subsection present"
else
  fail "Sync Action Mapping (P04) sub-subsection missing"
fi
if grep -q 'skip-nochange' "$REF"; then
  pass "sync action 'skip-nochange' documented"
else
  fail "sync action 'skip-nochange' missing"
fi
if grep -q 'status-sync' "$REF"; then
  pass "sync action 'status-sync' documented"
else
  fail "sync action 'status-sync' missing"
fi

# (4) Scope Boundary P04 column populated. The table header should name P04.
if grep -qE '^\| Section \| P01 \| P02 \| P03 \| P04 \|' "$REF"; then
  pass "Scope Boundary table has P04 column header"
else
  fail "Scope Boundary table P04 column header missing"
fi
# And the renamed heading.
if grep -q '^## Scope Boundary (P01 vs. P02 vs. P03 vs. P04)' "$REF"; then
  pass "Scope Boundary heading renamed to include P04"
else
  fail "Scope Boundary heading not renamed for P04"
fi

# (5) P01 byte-identity via pinned sha.
# awk range: `## Overview` through `## Sidecar Config Schema`.
P01_SECTIONS_SHA="a468192a724ad7505c2051852895f69267a16bbc27e925b4238b8454fa9c75ee"
current_p01=$(awk '/^## Overview/,/^## Sidecar Config Schema/' "$REF" | shasum -a 256 | awk '{print $1}')
if [ "$current_p01" = "$P01_SECTIONS_SHA" ]; then
  pass "P01 sections byte-identical (Overview..Sidecar Config Schema sha pinned)"
else
  fail "P01 sections sha drift: ${current_p01} != ${P01_SECTIONS_SHA}"
fi

# (6) P02 init Workflow byte-identity via pinned sha.
# awk range: `### `init` Workflow` through `### Dry-Run Manifest Format`.
P02_SECTIONS_SHA="1238e0f344e2bad08e1f51293534e887ecacf6cef6984bf39885a38c312b5c98"
current_p02=$(awk '/^### `init` Workflow/,/^### Dry-Run Manifest Format/' "$REF" | shasum -a 256 | awk '{print $1}')
if [ "$current_p02" = "$P02_SECTIONS_SHA" ]; then
  pass "P02 init Workflow subsection byte-identical (sha pinned)"
else
  fail "P02 init Workflow sha drift: ${current_p02} != ${P02_SECTIONS_SHA}"
fi

# (7) P03 Re-init Adoption Contract byte-identity via pinned sha.
# awk range: `### Re-init Adoption Contract` through `### Sync Workflow`.
P03_SECTIONS_SHA="e0d0dfd375f1fa1f045a00f571164cea5473d66d628ba16031f0ee6c3f9098f6"
current_p03=$(awk '/^### Re-init Adoption Contract/,/^### Sync Workflow/' "$REF" | shasum -a 256 | awk '{print $1}')
if [ "$current_p03" = "$P03_SECTIONS_SHA" ]; then
  pass "P03 Re-init Adoption Contract subsection byte-identical (sha pinned)"
else
  fail "P03 Re-init Adoption Contract sha drift: ${current_p03} != ${P03_SECTIONS_SHA}"
fi

# (8) Line count floor.
lc=$(wc -l < "$REF" | tr -d ' ')
if [ "${lc:-0}" -ge 400 ]; then
  pass "reference line count >= 400 (${lc})"
else
  fail "reference line count ${lc} < 400"
fi

# (9) P02 reference-extensions gate still green (SSOT for `^## ` section hashes).
p02_gate="${REPO_ROOT}/scripts/verify/m013-p02-reference-extensions.sh"
if [ -f "$p02_gate" ]; then
  bash "$p02_gate" > /dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "P02 reference-extensions gate still green (P01-section byte-identity SSOT)"
  else
    fail "P02 reference-extensions gate REGRESSION (rc=${rc})"
  fi
else
  fail "P02 reference-extensions gate missing at ${p02_gate}"
fi

# (10) P04 anchor checks in filled content.
for anchor in "FR-15" "FR-16" "FR-17" "FR-18" "updateProjectV2ItemFieldValue" "30s" "strict"; do
  if grep -q -- "$anchor" "$REF"; then
    pass "P04 anchor present: ${anchor}"
  else
    fail "P04 anchor missing: ${anchor}"
  fi
done

echo "SUMMARY: m013-p04-reference-extensions.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-reference-extensions.sh"
  exit 0
fi
echo "FAIL: m013-p04-reference-extensions.sh" >&2
exit 1
