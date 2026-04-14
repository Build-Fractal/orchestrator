#!/usr/bin/env bash
# Verifies claude-code.sh --register writes orchestrator-*.md files into
# a hermetic HOME fixture's .claude/commands/ directory.
set -u

ADAPTER="scripts/dispatch/adapters/runtime/claude-code.sh"

if [[ ! -f "$ADAPTER" ]]; then
  echo "FAIL: $ADAPTER missing"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

out="$(HOME="$tmpdir" bash "$ADAPTER" --register 2>&1)"
rc=$?

if [[ $rc -ne 0 ]]; then
  echo "FAIL: $ADAPTER --register exit=$rc"
  echo "---OUTPUT---"
  echo "$out"
  exit 1
fi

target_dir="$tmpdir/.claude/commands"
if [[ ! -d "$target_dir" ]]; then
  echo "FAIL: $target_dir was not created"
  exit 1
fi

count="$(find "$target_dir" -type f -name 'orchestrator-*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$count" = "0" ]]; then
  echo "FAIL: no orchestrator-*.md files written into $target_dir"
  exit 1
fi

echo "PASS: claude-code.sh --register wrote $count orchestrator-*.md files into hermetic \$HOME/.claude/commands/"
