#!/usr/bin/env bash
set -eu
matches=$(find .claude/commands -maxdepth 1 -name 'speckit.*.md' -print 2>/dev/null | wc -l | tr -d ' ')
test "$matches" = "0" || { echo "FAIL: $matches dogfooded /speckit.* command file(s) remain in .claude/commands/"; exit 1; }
echo "PASS: no dogfooded speckit command files remain"
