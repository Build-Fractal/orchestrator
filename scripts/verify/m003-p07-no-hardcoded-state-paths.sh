#!/usr/bin/env bash
set -eu
# Find any .specify/orchestrator literal in code lines (not comments).
# Code-line heuristic: line does not start (after optional whitespace) with '#'.
hits=0
for f in scripts/migrate/migrate.sh scripts/migrate/transform/milestone-rollup.sh scripts/migrate/transform/active-milestone.sh scripts/migrate/transform/milestone-tiering.sh; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
  while IFS= read -r line; do
    case "$line" in
      \#*|"") continue ;;
      *[[:space:]]\#*) continue ;;
    esac
    case "$line" in
      *.specify/orchestrator*) hits=$((hits+1)); echo "  hit in $f: $line" ;;
    esac
  done < "$f"
done
if [ "$hits" -gt 0 ]; then
  echo "FAIL: found $hits hardcoded .specify/orchestrator path(s) in migration code"
  exit 1
fi
echo "PASS: no hardcoded .specify/orchestrator paths in migration code"
