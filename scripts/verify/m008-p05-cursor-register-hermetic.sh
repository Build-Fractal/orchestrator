#!/usr/bin/env bash
# Verifies cursor.sh --register writes (M009 FR-4 split):
#   - invocable commands -> .cursor/commands/orchestrator-*.md
#   - an always-on rule  -> .cursor/rules/orchestrator.md
# into a hermetic PROJECT_DIR fixture, and never touches HOME.
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

# FR-4: invocable commands land in .cursor/commands/orchestrator-*.md
commands_dir="$project_dir/.cursor/commands"
if [[ ! -d "$commands_dir" ]]; then
  echo "FAIL: $commands_dir was not created"
  exit 1
fi
count="$(find "$commands_dir" -type f -name 'orchestrator-*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$count" = "0" ]]; then
  echo "FAIL: no orchestrator-*.md files written into $commands_dir"
  exit 1
fi

# FR-4: the always-on rule lands at .cursor/rules/orchestrator.md.
rule_file="$project_dir/.cursor/rules/orchestrator.md"
if [[ ! -f "$rule_file" ]]; then
  echo "FAIL: always-on rule $rule_file was not created"
  exit 1
fi
if ! grep -q 'alwaysApply: true' "$rule_file"; then
  echo "FAIL: $rule_file missing alwaysApply frontmatter"
  exit 1
fi

# Also assert HOME fixture was not written to (hermetic guard preserved).
home_count="$(find "$home_fix" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$home_count" != "0" ]]; then
  echo "FAIL: cursor.sh wrote $home_count files into HOME (should only write to project-dir)"
  exit 1
fi

echo "PASS: cursor.sh --register wrote $count commands + always-on rule into hermetic .cursor/ (HOME untouched)"
