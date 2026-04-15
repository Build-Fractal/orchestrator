#!/usr/bin/env bash
# scripts/verify/m003-p08-report-has-nonzero-counts.sh
# Truth: MIGRATION-REPORT.md produced by the pipeline has at least one non-zero
# integer in each of the five expected sections:
#   ## Knowledge, ## Decisions, ## Requirements, ## Milestones, ## Telemetry.
#
# Two invocation modes:
#   1. --report <path> : validate an existing report file.
#   2. no args         : run migrate.sh against the synthetic fixture into a
#                        mktemp dir and validate the produced report.
#
# AD-19 / MEM001 safe. Exit 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIGRATE_SH="$REPO_ROOT/scripts/migrate/migrate.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/m003-p08-gsd-minimal"

report=""
auto_cleanup_dir=""

while [ $# -gt 0 ]; do
  case "$1" in
    --report)
      if [ $# -lt 2 ]; then
        echo "FAIL: --report requires a value"
        exit 1
      fi
      report="$2"
      shift 2
      ;;
    *)
      echo "FAIL: unknown arg: $1"
      exit 1
      ;;
  esac
done

cleanup_auto() {
  if [ -n "$auto_cleanup_dir" ] && [ -d "$auto_cleanup_dir" ]; then
    case "$auto_cleanup_dir" in
      /var/folders/*|/tmp/*)
        rm -rf "$auto_cleanup_dir"
        ;;
    esac
  fi
}
trap cleanup_auto EXIT

if [ -z "$report" ]; then
  if [ ! -d "$FIXTURE/.gsd" ]; then
    echo "FAIL: synthetic fixture missing at $FIXTURE/.gsd"
    exit 1
  fi
  auto_cleanup_dir="$(mktemp -d -t m003-p08-report-XXXXXX)"
  if ! bash "$MIGRATE_SH" --source gsd2 --path "$FIXTURE" --output "$auto_cleanup_dir" --force \
       >"$auto_cleanup_dir/.migrate.log" 2>&1; then
    echo "FAIL: migrate.sh failed (log: $auto_cleanup_dir/.migrate.log)"
    exit 1
  fi
  report="$auto_cleanup_dir/MIGRATION-REPORT.md"
fi

if [ ! -f "$report" ]; then
  echo "FAIL: report not found: $report"
  exit 1
fi

# Check each required section. For each section, extract the body until the
# next heading (## or EOF), then assert at least one positive integer is
# present. Using awk keeps this portable (bash 3.2 + POSIX awk).
check_section() {
  local section="$1"
  local found
  found="$(awk -v sect="$section" '
    $0 == sect { inside=1; next }
    /^## / { inside=0 }
    inside { print }
  ' "$report" | grep -cE '[1-9][0-9]*' || true)"

  if [ "${found:-0}" -eq 0 ]; then
    echo "FAIL: report section '$section' has no non-zero integer (report: $report)"
    return 1
  fi
  return 0
}

failed=0
for section in "## Knowledge" "## Decisions" "## Requirements" "## Milestones" "## Telemetry"; do
  check_section "$section" || failed=1
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "PASS: MIGRATION-REPORT.md has non-zero counts in all 5 sections"
exit 0
