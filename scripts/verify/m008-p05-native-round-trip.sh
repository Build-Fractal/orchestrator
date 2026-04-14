#!/usr/bin/env bash
# Verifies native.sh --read preserves task/phase/milestone frontmatter.
set -u

ADAPTER="scripts/dispatch/adapters/format/native.sh"

if [[ ! -f "$ADAPTER" ]]; then
  echo "FAIL: $ADAPTER missing"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fixture="$tmpdir/task-plan.md"
cat > "$fixture" <<'EOF'
---
schema_version: "1.0"
type: "task-plan"
task: "T42"
phase: "P05"
milestone: "M008"
name: "fixture"
depends_on: []
---

## Description

Round-trip fixture.
EOF

out="$(bash "$ADAPTER" --read "$fixture" 2>/dev/null)"
rc=$?

if [[ $rc -ne 0 ]]; then
  echo "FAIL: $ADAPTER --read exited $rc"
  exit 1
fi

if ! echo "$out" | grep -qE '^task: "T42"'; then
  echo "FAIL: output missing task: T42"
  echo "---OUTPUT---"
  echo "$out"
  exit 1
fi
if ! echo "$out" | grep -qE '^phase: "P05"'; then
  echo "FAIL: output missing phase: P05"
  exit 1
fi
if ! echo "$out" | grep -qE '^milestone: "M008"'; then
  echo "FAIL: output missing milestone: M008"
  exit 1
fi

# Negative: missing frontmatter should fail.
bad="$tmpdir/bad.md"
echo "no frontmatter here" > "$bad"
bash "$ADAPTER" --read "$bad" >/dev/null 2>&1
rc=$?
if [[ $rc -eq 0 ]]; then
  echo "FAIL: $ADAPTER --read accepted a file with no frontmatter"
  exit 1
fi

echo "PASS: native.sh --read round-trips task/phase/milestone frontmatter"
