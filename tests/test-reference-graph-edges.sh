#!/usr/bin/env bash
# tests/test-reference-graph-edges.sh -- SC-4 acceptance test for M036/P05.
#
# Exercises the full reference-corpus data path end-to-end:
#   1. Author a fixture spec chunk declaring `cites: [REF-cms-rule-483-20]`
#      and a corresponding reference chunk under a mktemp PROJECT_ROOT.
#   2. Run scripts/knowledge/rebuild-index.sh against the staged tree --
#      this is the path that turns frontmatter `cites:` into edge rows in
#      the SQLite graph DB.
#   3. Run scripts/knowledge/traverse-graph.sh --id SPEC-requirement-FR-7
#      --edge-types cites --max-depth 1 against the staged DB and assert
#      that the labeled substring `REF-cms-rule-483-20|cites` appears in
#      the output.
#
# This is a real end-to-end test -- no mocks. The frontmatter shape mirrors
# the M036/P05 T01-T02 verifiers (full chunk-frontmatter contract) so the
# fixture is not a happy-path simplification of what production chunks
# actually carry.
#
# MEM001/MEM002 conventions: pass_count/fail_count scalars (bash 3.2 safe),
# prefixed `PASS:` / `FAIL:` output, mktemp + trap teardown, PROJECT_ROOT
# env override (no live knowledge/ tree mutation). AD-19 single-script-file
# shape.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass_count=0
fail_count=0
pass() { printf 'PASS: %s\n' "$1"; pass_count=$((pass_count + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; fail_count=$((fail_count + 1)); }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# --- Stage fixture knowledge tree ---
mkdir -p "$tmpdir/knowledge/spec/requirement"
mkdir -p "$tmpdir/knowledge/reference/cms-rule"

# Spec chunk citing the regulatory reference. Frontmatter mirrors the T01/T02
# verifier fixtures so we exercise the production chunk shape.
cat > "$tmpdir/knowledge/spec/requirement/SPEC-requirement-FR-7.md" <<'FIXTURE_SPEC'
---
id: SPEC-requirement-FR-7
scope_tags: "[project]"
category: spec/requirement
confidence: 0.95
created_at: 2026-05-01
last_verified: 2026-05-01
hit_count: 0
source_unit: "M036/P05"
source_type: spec
supersedes: ""
superseded_by: ""
relates_to: []
cites: [REF-cms-rule-483-20]
derived_from: []
applies_to_field: []
content_hash: ""
---

# SPEC-requirement-FR-7: SC-4 fixture spec chunk citing a regulatory reference
FIXTURE_SPEC

# Reference chunk: target of the cites edge, no outgoing edges.
cat > "$tmpdir/knowledge/reference/cms-rule/REF-cms-rule-483-20.md" <<'FIXTURE_REF'
---
id: REF-cms-rule-483-20
scope_tags: "[project]"
category: cms-rule
confidence: 0.95
created_at: 2026-05-01
last_verified: 2026-05-01
hit_count: 0
source_unit: "M036/P05"
source_type: regulatory
supersedes: ""
superseded_by: ""
relates_to: []
cites: []
derived_from: []
applies_to_field: []
content_hash: ""
---

# REF-cms-rule-483-20: SC-4 fixture regulatory reference chunk
FIXTURE_REF

# --- Step 1: rebuild graph DB against staged tree ---
if ! PROJECT_ROOT="$tmpdir" bash "$ROOT/scripts/knowledge/rebuild-index.sh" >/dev/null 2>&1; then
  fail "SC-4: rebuild-index.sh failed against staged PROJECT_ROOT"
  printf 'TEST: pass=%d fail=%d\n' "$pass_count" "$fail_count"
  exit 1
fi

# --- Step 2: traverse cites edges from spec chunk at depth 1 ---
output="$(PROJECT_ROOT="$tmpdir" bash "$ROOT/scripts/knowledge/traverse-graph.sh" --id SPEC-requirement-FR-7 --edge-types cites --max-depth 1 2>&1 || true)"

# --- Step 3: assert labeled cites edge surfaces target ---
case "$output" in
  *"REF-cms-rule-483-20|cites"*)
    pass "SC-4: cites edge surfaced with label (REF-cms-rule-483-20|cites)"
    ;;
  *)
    fail "SC-4: expected 'REF-cms-rule-483-20|cites' in traverse output, got: $output"
    ;;
esac

printf 'TEST: pass=%d fail=%d\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
