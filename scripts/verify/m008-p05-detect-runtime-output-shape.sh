#!/usr/bin/env bash
# Verifies detect-runtime.sh emits runtime= and confidence= key=value lines.
set -u

SCRIPT="scripts/dispatch/detect-runtime.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing"
  exit 1
fi
if [[ ! -x "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT not executable"
  exit 1
fi

# Run with an empty HOME fixture so detection yields unknown, not real state.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
out="$(HOME="$tmpdir" CLAUDECODE="" CODEX_HOME="" CURSOR_TRACE_ID="" bash "$SCRIPT" 2>/dev/null)"
rc=$?

if [[ $rc -ne 0 ]]; then
  echo "FAIL: $SCRIPT exit=$rc (must exit 0 on any valid run)"
  exit 1
fi

if ! echo "$out" | grep -qE '^runtime='; then
  echo "FAIL: output missing runtime= line"
  echo "---OUTPUT---"
  echo "$out"
  exit 1
fi

if ! echo "$out" | grep -qE '^confidence='; then
  echo "FAIL: output missing confidence= line"
  echo "---OUTPUT---"
  echo "$out"
  exit 1
fi

echo "PASS: detect-runtime.sh emits runtime= and confidence= key=value lines"
