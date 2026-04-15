#!/usr/bin/env bash
# scripts/verify/m003-p08-status-wrapper-works.sh
# Truth: scripts/orchestrator/status.sh --root <migrated-output> exits 0 and
# stdout contains both a MILESTONE: line and a STATE: line.
#
# Two invocation modes:
#   1. --root <dir>    : point at an existing populated root.
#   2. no args         : run the migration against the synthetic fixture into
#                        a mktemp dir and run status.sh against that.
#
# AD-19 / MEM001 safe. Exit 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATUS_SH="$REPO_ROOT/scripts/orchestrator/status.sh"
MIGRATE_SH="$REPO_ROOT/scripts/migrate/migrate.sh"
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

# Scoped cleanup for auto-migrate mode
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
  # No --root given -> auto-migrate the synthetic fixture
  if [ ! -d "$FIXTURE/.gsd" ]; then
    echo "FAIL: synthetic fixture missing at $FIXTURE/.gsd"
    exit 1
  fi
  root="$(mktemp -d -t m003-p08-status-XXXXXX)"
  auto_cleanup=1
  if ! bash "$MIGRATE_SH" --source gsd2 --path "$FIXTURE" --output "$root" --force \
       >"$root/.migrate.log" 2>&1; then
    echo "FAIL: migrate.sh failed (log: $root/.migrate.log)"
    exit 1
  fi
fi

if [ ! -d "$root" ]; then
  echo "FAIL: root directory does not exist: $root"
  exit 1
fi

# Capture status.sh stdout; on non-zero exit, fail.
status_out="$(bash "$STATUS_SH" --root "$root" 2>&1)" || {
  echo "FAIL: status.sh --root $root exited non-zero"
  echo "$status_out"
  exit 1
}

if ! echo "$status_out" | grep -q '^MILESTONE:'; then
  echo "FAIL: status.sh stdout missing MILESTONE: line"
  echo "$status_out"
  exit 1
fi

if ! echo "$status_out" | grep -q '^STATE:'; then
  echo "FAIL: status.sh stdout missing STATE: line"
  echo "$status_out"
  exit 1
fi

echo "PASS: status.sh --root <dir> emits MILESTONE:/STATE: lines"
exit 0
