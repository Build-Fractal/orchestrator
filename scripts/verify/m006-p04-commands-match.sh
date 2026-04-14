#!/usr/bin/env bash
# Verify every speckit.orchestrator.* command name in getting-started.md exists in extension.yml.
set -eu
f="docs/getting-started.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -f "extension.yml" || { echo "FAIL: extension.yml missing"; exit 1; }

# Extract orchestrator command names from the guide
cmds=$(grep -oE 'speckit\.orchestrator\.[a-z_-]+' "$f" | sort -u)

# Check each command exists in extension.yml
for cmd in $cmds; do
  if ! grep -q "$cmd" extension.yml; then
    echo "FAIL: command '$cmd' mentioned in getting-started.md but not found in extension.yml"
    exit 1
  fi
done

# Verify at least 5 distinct commands are mentioned (sanity check)
count=$(echo "$cmds" | wc -l | tr -d ' ')
if [ "$count" -lt 5 ]; then
  echo "FAIL: only $count distinct orchestrator commands mentioned (expected at least 5)"
  exit 1
fi

echo "PASS: all $count command names in getting-started.md match extension.yml"
