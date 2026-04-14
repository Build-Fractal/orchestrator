#!/usr/bin/env bash
# scripts/state/namespace-aliases.sh — Generate the
# speckit.orchestrator.* -> orchestrator:* mapping table.
#
# Scans the commands/ directory for command files, derives the short
# command name from each filename, and emits both the legacy
# speckit.orchestrator.<name> form and the new orchestrator:<name> form.
#
# This is a documentation tool. Runtime adapters (P05) register commands
# under the new namespace directly; this script does not route at
# runtime.
#
# Usage:
#   namespace-aliases.sh                 -> emit two-column mapping to stdout
#   namespace-aliases.sh --markdown      -> emit a markdown table
#
# Exit: 0 on success, 1 if commands/ is absent.
# Bash 3.2 compatible.

set -u

MARKDOWN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown) MARKDOWN=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

# Locate repo root
repo_root="$PWD"
while [[ "$repo_root" != "/" ]]; do
  if [[ -d "$repo_root/.git" ]] || [[ -f "$repo_root/.git" ]]; then
    break
  fi
  repo_root="$(dirname "$repo_root")"
done

cmd_dir="$repo_root/commands"
if [[ ! -d "$cmd_dir" ]]; then
  echo "ERROR: commands directory not found at $cmd_dir" >&2
  exit 1
fi

if [[ "$MARKDOWN" = "1" ]]; then
  echo "| Legacy namespace | New namespace |"
  echo "| --- | --- |"
fi

for cmd_file in "$cmd_dir"/*.md; do
  [[ -f "$cmd_file" ]] || continue
  base="$(basename "$cmd_file" .md)"
  # Skip README-style files
  case "$base" in
    README|AGENTS) continue ;;
  esac
  if [[ "$MARKDOWN" = "1" ]]; then
    echo "| \`speckit.orchestrator.$base\` | \`orchestrator:$base\` |"
  else
    echo "speckit.orchestrator.$base -> orchestrator:$base"
  fi
done
