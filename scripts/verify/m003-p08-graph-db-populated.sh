#!/usr/bin/env bash
# scripts/verify/m003-p08-graph-db-populated.sh
# Truth: <root>/knowledge.db exists and is non-empty, and at least one migrated
# knowledge entry (MEM*.md under <root>/knowledge/) is queryable via
# scripts/knowledge/traverse-graph.sh --id <MEM>.
#
# Two invocation modes:
#   1. --root <dir>    : validate an existing migrated root.
#   2. no args         : run migrate.sh against the synthetic fixture first.
#
# Exercises P04 graph rebuild wiring (P07/T03) end-to-end.
#
# AD-19 / MEM001 safe. Exit 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIGRATE_SH="$REPO_ROOT/scripts/migrate/migrate.sh"
TRAVERSE_SH="$REPO_ROOT/scripts/knowledge/traverse-graph.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/m003-p08-gsd-minimal"

root=""
auto_cleanup=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      if [ $# -lt 2 ]; then
        echo "FAIL: --root requires a value"
        exit 1
      fi
      root="$2"
      shift 2
      ;;
    *)
      echo "FAIL: unknown arg: $1"
      exit 1
      ;;
  esac
done

cleanup_auto() {
  if [ "$auto_cleanup" -eq 1 ] && [ -n "$root" ] && [ -d "$root" ]; then
    case "$root" in
      /var/folders/*|/tmp/*)
        rm -rf "$root"
        ;;
    esac
  fi
}
trap cleanup_auto EXIT

if [ -z "$root" ]; then
  if [ ! -d "$FIXTURE/.gsd" ]; then
    echo "FAIL: synthetic fixture missing at $FIXTURE/.gsd"
    exit 1
  fi
  root="$(mktemp -d -t m003-p08-graph-XXXXXX)"
  auto_cleanup=1
  if ! bash "$MIGRATE_SH" --source gsd2 --path "$FIXTURE" --output "$root" --force \
       >"$root/.migrate.log" 2>&1; then
    echo "FAIL: migrate.sh failed (log: $root/.migrate.log)"
    exit 1
  fi
fi

db="$root/knowledge.db"
if [ ! -s "$db" ]; then
  echo "FAIL: $db missing or empty"
  exit 1
fi

# Pick the first MEM*.md under <root>/knowledge/ (excluding archive)
first_mem=""
first_mem_file="$(find "$root/knowledge" -type f -name 'MEM*.md' -not -path '*/archive/*' -print 2>/dev/null | sort | head -1 || true)"
if [ -n "$first_mem_file" ]; then
  first_mem="$(basename "$first_mem_file" .md)"
fi

if [ -z "$first_mem" ]; then
  echo "FAIL: no MEM*.md entries found under $root/knowledge/"
  exit 1
fi

# Query the graph. traverse-graph.sh reads knowledge.db from PROJECT_ROOT.
if ! PROJECT_ROOT="$root" bash "$TRAVERSE_SH" --id "$first_mem" >/dev/null 2>&1; then
  echo "FAIL: traverse-graph.sh --id $first_mem failed against $root"
  exit 1
fi

echo "PASS: knowledge.db populated; traverse-graph resolved $first_mem"
exit 0
