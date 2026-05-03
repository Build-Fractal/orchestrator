#!/usr/bin/env bash
# tools/verify/m036-p05-scope-filter-source-tag.sh — `--tag` literal-match shape.
#
# Asserts that scripts/dispatch/scope-filter.sh accepts `--tag '[source:<cite_id>]'`
# and returns every chunk (memory + spec) bearing that tag literal, regardless of
# the operator's MILESTONE_ID/PHASE_ID context. Stages a 3-row KNOWLEDGE-INDEX.md
# fragment under mktemp:
#   - MEM001  | [project]                    | patterns      (no source tag)
#   - MEM002  | [source:cms-pbj-2024-q3]    | patterns      (matching tag)
#   - SPEC-FR-7 | [source:cms-pbj-2024-q3]  | spec/requirement (matching tag — cross-category)
#
# Invokes:
#   scope-filter.sh <fixture> M036/P05 --type knowledge --tag '[source:cms-pbj-2024-q3]'
#
# Asserts output:
#   - Contains MEM002 (memory match)
#   - Contains SPEC-FR-7 (cross-category — spec match)
#   - Does NOT contain MEM001 (no matching tag)
#
# T03 of M036/P05. Single-script-file invocation per AD-19.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fixture="$tmpdir/KNOWLEDGE-INDEX.md"
cat > "$fixture" <<'EOF_FIXTURE'
# Knowledge Index
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->

MEM001 | [project] | patterns | 0.9 | 2026-01-01 | verified:2026-01-01 | hits:1 | A
MEM002 | [source:cms-pbj-2024-q3] | patterns | 0.9 | 2026-01-01 | verified:2026-01-01 | hits:1 | B
SPEC-FR-7 | [source:cms-pbj-2024-q3] | spec/requirement | 0.9 | 2026-01-01 | verified:2026-01-01 | hits:1 | C
EOF_FIXTURE

# Run scope-filter.sh with --tag flag
out_file="$tmpdir/out.txt"
bash "$ROOT/scripts/dispatch/scope-filter.sh" \
  "$fixture" M036/P05 \
  --type knowledge \
  --tag '[source:cms-pbj-2024-q3]' \
  > "$out_file"

fail=0

# Assertion 1: MEM002 (memory match) MUST be present
if ! grep -qF 'MEM002 |' "$out_file"; then
  echo "FAIL: m036-p05-scope-filter-source-tag — MEM002 missing from --tag output" >&2
  fail=1
fi

# Assertion 2: SPEC-FR-7 (cross-category spec match) MUST be present
if ! grep -qF 'SPEC-FR-7 |' "$out_file"; then
  echo "FAIL: m036-p05-scope-filter-source-tag — SPEC-FR-7 missing from --tag output (cross-category)" >&2
  fail=1
fi

# Assertion 3: MEM001 (no matching tag) MUST be excluded
if grep -qF 'MEM001 |' "$out_file"; then
  echo "FAIL: m036-p05-scope-filter-source-tag — MEM001 leaked into --tag output (no matching tag)" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "Output was:" >&2
  cat "$out_file" >&2
  exit 1
fi

echo "PASS: m036-p05-scope-filter-source-tag (2 chunks across spec+memory)"
exit 0
