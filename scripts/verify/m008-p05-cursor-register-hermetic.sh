#!/usr/bin/env bash
# Verifies cursor.sh --register writes orchestrator-*.md rules into
# a hermetic PROJECT_DIR fixture's .cursor/rules/ directory.
set -u

ADAPTER="scripts/dispatch/adapters/runtime/cursor.sh"

if [[ ! -f "$ADAPTER" ]]; then
  echo "FAIL: $ADAPTER missing"
  exit 1
fi

project_dir="$(mktemp -d)"
home_fix="$(mktemp -d)"
trap 'rm -rf "$project_dir" "$home_fix"' EXIT

out="$(HOME="$home_fix" bash "$ADAPTER" --register --project-dir "$project_dir" 2>&1)"
rc=$?

if [[ $rc -ne 0 ]]; then
  echo "FAIL: $ADAPTER --register exit=$rc"
  echo "---OUTPUT---"
  echo "$out"
  exit 1
fi

target_dir="$project_dir/.cursor/rules"
if [[ ! -d "$target_dir" ]]; then
  echo "FAIL: $target_dir was not created"
  exit 1
fi

count="$(find "$target_dir" -type f -name 'orchestrator-*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$count" = "0" ]]; then
  echo "FAIL: no orchestrator-*.md files written into $target_dir"
  exit 1
fi

# Also assert HOME fixture was not written to.
home_count="$(find "$home_fix" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$home_count" != "0" ]]; then
  echo "FAIL: cursor.sh wrote $home_count files into HOME (should only write to project-dir)"
  exit 1
fi

echo "PASS: cursor.sh --register wrote $count orchestrator-*.md files into hermetic .cursor/rules/"
