#!/usr/bin/env bash
# m016-p04-settings-usrbin-sed.sh — Verify /usr/bin/sed wildcard in settings.json
# Checks that .claude/settings.json contains the "Bash(/usr/bin/sed *)" entry.
# Bash 3.2 compatible. Standalone.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
settings="$root/.claude/settings.json"

if [ ! -f "$settings" ]; then
  echo "FAIL: settings.json not found at $settings"
  exit 1
fi

if grep -qF '"Bash(/usr/bin/sed *)"' "$settings"; then
  echo "PASS: settings.json contains /usr/bin/sed wildcard entry"
  exit 0
else
  echo "FAIL: settings.json missing Bash(/usr/bin/sed *) entry"
  exit 1
fi
