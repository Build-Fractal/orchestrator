#!/usr/bin/env bash
# Verifies speckit.sh --read maps a spec-kit tasks.md into native shape,
# and that --write is rejected (one-directional read only).
set -u

ADAPTER="scripts/dispatch/adapters/format/speckit.sh"
NATIVE="scripts/dispatch/adapters/format/native.sh"

if [[ ! -f "$ADAPTER" ]]; then
  echo "FAIL: $ADAPTER missing"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Build minimal spec-kit tasks.md + plan.md fixture.
mkdir -p "$tmpdir/specs/example"
cat > "$tmpdir/specs/example/tasks.md" <<'EOF'
# Tasks

## T01: First spec-kit task

Do the thing.

## T02: Second

Other thing.
EOF

cat > "$tmpdir/specs/example/plan.md" <<'EOF'
# Plan
phase: P05
milestone: M008
EOF

out="$(bash "$ADAPTER" --read "$tmpdir/specs/example/tasks.md" 2>/dev/null)"
rc=$?

if [[ $rc -ne 0 ]]; then
  echo "FAIL: $ADAPTER --read exited $rc"
  exit 1
fi

if ! echo "$out" | grep -qE '^task: "T01"'; then
  echo "FAIL: speckit output missing task: T01"
  echo "---OUTPUT---"
  echo "$out"
  exit 1
fi
if ! echo "$out" | grep -qE '^type: "task-plan"'; then
  echo "FAIL: speckit output missing type: task-plan"
  exit 1
fi

# Round-trip through native validator if native exists.
if [[ -f "$NATIVE" ]]; then
  tmpfile="$tmpdir/native-input.md"
  echo "$out" > "$tmpfile"
  bash "$NATIVE" --read "$tmpfile" >/dev/null 2>&1
  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "FAIL: speckit output does not validate via native.sh --read"
    exit 1
  fi
fi

# --write must be rejected.
bash "$ADAPTER" --write "$tmpdir/out.md" >/dev/null 2>&1
rc=$?
if [[ $rc -eq 0 ]]; then
  echo "FAIL: $ADAPTER accepted --write (must be one-directional read only)"
  exit 1
fi

echo "PASS: speckit.sh --read maps to native shape; --write is rejected"
