#!/usr/bin/env bash
# Verify every file/directory path mentioned in references/architecture.md exists.
# Extracts paths matching scripts/, commands/, templates/, references/ patterns
# and checks each one exists on disk.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

failures=0
# Extract paths that look like project file/directory references
# Match patterns like scripts/engine/run.sh, commands/auto.md, etc.
paths=$(grep -oE '(scripts|commands|templates|references)/[a-zA-Z0-9_./-]+\.(sh|md|yml|yaml|json|jsonl)' "$f" | sort -u)

for path in $paths; do
  if [ ! -e "$path" ]; then
    echo "FAIL: path mentioned in architecture.md does not exist: $path"
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "FAIL: $failures path(s) referenced in architecture.md do not exist"
  exit 1
fi
echo "PASS: all file paths in architecture.md exist on disk"
