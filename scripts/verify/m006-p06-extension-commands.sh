#!/usr/bin/env bash
# Verify all commands listed in extension.yml have corresponding files in commands/.
set -eu
f="extension.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
fail=0
# Extract command file paths from extension.yml
while IFS= read -r line; do
  cmd_file="$(echo "$line" | sed 's/^[[:space:]]*file:[[:space:]]*//')"
  if [ ! -f "$cmd_file" ]; then
    echo "FAIL: command file missing: $cmd_file"
    fail=1
  fi
done <<EOF
$(grep '^\s*file: commands/' "$f")
EOF
if [ "$fail" -eq 1 ]; then
  exit 1
fi
echo "PASS: all extension.yml commands have corresponding files in commands/"
