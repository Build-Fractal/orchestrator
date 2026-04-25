#!/usr/bin/env bash
# m020-p02-query-help.sh — assert query.sh --help enumerates the FR-2 flags.
# Bash 3.2 safe.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: query.sh missing or not executable at $SCRIPT"
  exit 1
fi

out="$(bash "$SCRIPT" --help 2>&1 || true)"

for needle in "--topic" "--state" "--format"; do
  case "$out" in
    *"$needle"*) ;;
    *)
      echo "FAIL: query.sh --help does not mention $needle"
      exit 1
      ;;
  esac
done

echo "PASS: query.sh --help enumerates --topic, --state, --format"
exit 0
