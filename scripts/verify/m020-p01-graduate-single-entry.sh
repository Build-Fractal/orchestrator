#!/usr/bin/env bash
# m020-p01-graduate-single-entry.sh — exercise graduate.sh against an
# isolated fixture. Bash 3.2 safe. AD-19 single-script-invocation shape.
#
# Uses PROJECT_ROOT (honored by lib/index-utils.sh::get_project_root) to
# point the resolver at a tempdir, isolating live knowledge/ from test
# mutations.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: graduate.sh missing or not executable at $SCRIPT"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
fixture="$tmpdir/knowledge/patterns/MEM900.md"
cat > "$fixture" <<'EOF'
---
id: MEM900
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
status: candidate
---

# MEM900: Fixture entry

Body.
EOF

export PROJECT_ROOT="$tmpdir"

# Case 1: candidate -> graduated
out="$(bash "$SCRIPT" --rationale "test flip" MEM900)"
case "$out" in
  *"GRADUATED: MEM900 from=candidate to=graduated"*) ;;
  *)
    echo "FAIL: graduate output missing GRADUATED line. Got: $out"
    exit 1
    ;;
esac

if ! grep -q "^status: graduated$" "$fixture"; then
  echo "FAIL: status line not flipped to graduated in fixture"
  exit 1
fi

# Case 2: idempotency -- re-running is a NO-OP
out2="$(bash "$SCRIPT" --rationale "again" MEM900)"
case "$out2" in
  *"NO-OP: MEM900 already graduated"*) ;;
  *)
    echo "FAIL: second invocation did not produce NO-OP. Got: $out2"
    exit 1
    ;;
esac

# Case 3: missing --rationale rejected
if bash "$SCRIPT" MEM900 2>/dev/null; then
  echo "FAIL: graduate.sh accepted invocation without --rationale"
  exit 1
fi

# Case 4: missing entry rejected
if bash "$SCRIPT" --rationale "x" MEM999 2>/dev/null; then
  echo "FAIL: graduate.sh accepted nonexistent entry"
  exit 1
fi

echo "PASS: graduate.sh single-entry flip honors contract (4/4 cases)"
exit 0
