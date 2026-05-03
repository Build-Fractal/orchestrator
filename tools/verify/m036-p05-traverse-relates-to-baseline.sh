#!/usr/bin/env bash
# tools/verify/m036-p05-traverse-relates-to-baseline.sh — CON-5 regression guard.
#
# Asserts that traverse-graph.sh default invocation (no --edge-types flag) is
# byte-identical to pre-P05 for a relates_to fixture. Stages the tests/fixtures/
# m036-p05-baseline/ corpus under a mktemp PROJECT_ROOT, rebuilds the graph DB,
# runs the traverser in default mode, and diffs stdout against the baseline file
# captured BEFORE T02's edits.
#
# Baseline file: tests/fixtures/m036-p05-baseline/traverse-relates-to.expected.txt
# (captured 2026-05-01 from unmodified scripts/knowledge/traverse-graph.sh).
#
# Any byte-level diff exits 1 with "FAIL: CON-5 regression at line <N>: ...".
#
# T02 of M036/P05: regression guard. Single-script-file invocation per AD-19.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

baseline="$ROOT/tests/fixtures/m036-p05-baseline/traverse-relates-to.expected.txt"
if [ ! -f "$baseline" ]; then
  echo "FAIL: m036-p05-traverse-relates-to-baseline (baseline file missing at $baseline)" >&2
  exit 1
fi

# Stage knowledge tree: two MEM entries with relates_to: [MEM002] on MEM001.
# Frontmatter mirrors the corpus used at baseline-capture time so the traverser
# emits byte-identical output. The new edge fields (cites/derived_from/
# applies_to_field) are present-but-empty so rebuild-index.sh's pipefail-grep
# loop doesn't trip on missing fields (T01 contract).
mkdir -p "$tmpdir/knowledge/patterns"

cat > "$tmpdir/knowledge/patterns/MEM001.md" <<'EOF_MEM1'
---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 0
source_unit: "M036/P05"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: [MEM002]
cites: []
derived_from: []
applies_to_field: []
content_hash: ""
---

# MEM001: Baseline fixture for CON-5 regression guard
EOF_MEM1

cat > "$tmpdir/knowledge/patterns/MEM002.md" <<'EOF_MEM2'
---
id: MEM002
scope_tags: "[project]"
category: patterns
confidence: 0.90
created_at: 2026-04-14
last_verified: 2026-04-14
hit_count: 0
source_unit: "M036/P05"
source_type: consolidation
supersedes: ""
superseded_by: ""
relates_to: []
cites: []
derived_from: []
applies_to_field: []
content_hash: ""
---

# MEM002: Baseline fixture peer
EOF_MEM2

# Rebuild the graph DB against the staged corpus
PROJECT_ROOT="$tmpdir" bash "$ROOT/scripts/knowledge/rebuild-index.sh" >/dev/null

# Run the traverser in DEFAULT mode (no --edge-types) and capture stdout
actual="$tmpdir/actual.txt"
PROJECT_ROOT="$tmpdir" bash "$ROOT/scripts/knowledge/traverse-graph.sh" --id MEM001 > "$actual"

# Byte-level diff against the baseline
if cmp -s "$baseline" "$actual"; then
  echo "PASS: m036-p05-traverse-relates-to-baseline (CON-5 byte-identical)"
  exit 0
fi

# Find the first differing line for diagnostic output
diff_line="$(diff "$baseline" "$actual" | head -20)"
exp_first="$(head -1 "$baseline")"
got_first="$(head -1 "$actual")"
echo "FAIL: CON-5 regression at line 1: expected '${exp_first}' got '${got_first}'" >&2
echo "full diff:" >&2
printf '%s\n' "$diff_line" >&2
exit 1
