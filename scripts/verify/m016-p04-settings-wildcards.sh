#!/usr/bin/env bash
# m016-p04-settings-wildcards.sh — Verify required Unix tool wildcards in settings.json
# Checks that .claude/settings.json contains Bash(<tool> *) entries for each
# required tool: sed, awk, grep, wc, chmod, mkdir, touch, cat, head, tail, mv, cp, find.
# Bash 3.2 compatible. Standalone.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
settings="$root/.claude/settings.json"

if [ ! -f "$settings" ]; then
  echo "FAIL: settings.json not found at $settings"
  exit 1
fi

fails=0
tools="sed awk grep wc chmod mkdir touch cat head tail mv cp find"

for tool in $tools; do
  pattern="\"Bash($tool *)\""
  if grep -qF "$pattern" "$settings"; then
    : # present
  else
    echo "FAIL: missing wildcard entry Bash($tool *) in settings.json"
    fails=$((fails + 1))
  fi
done

if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails required wildcard(s) missing from settings.json"
  exit 1
fi

echo "PASS: all 13 required Unix tool wildcards present in settings.json"
exit 0
