#!/usr/bin/env bash
# tools/verify/m041-p01-command-shape.sh
# Verifies commands/detective.md exists, has description: frontmatter,
# and references triage-issue.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/commands/detective.md"

if [ ! -f "$target" ]; then
  echo "FAIL: commands/detective.md does not exist"
  exit 1
fi

content="$(cat "$target")"

case "$content" in
  *"description:"*)
    : ;;
  *)
    echo "FAIL: commands/detective.md missing description: in frontmatter"
    exit 1 ;;
esac

case "$content" in
  *"triage-issue.sh"*)
    echo "PASS: commands/detective.md exists with description: and triage-issue.sh reference"
    ;;
  *)
    echo "FAIL: commands/detective.md does not reference triage-issue.sh"
    exit 1 ;;
esac
