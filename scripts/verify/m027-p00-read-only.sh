#!/usr/bin/env bash
# scripts/verify/m027-p00-read-only.sh — M027/P00 FR-12 / SC-9.
#
# Captures `git status --porcelain` BEFORE running the rollup against every
# fixture under tests/fixtures/m027-p00/. Runs the rollup CLI against each
# fixture in turn. Captures `git status --porcelain` AFTER. Asserts the two
# captures are byte-identical (no new modifications). Also asserts no new
# files appeared under .orchestrator/milestones/.
#
# The semantic invariant verified here is the same one expressed by
# `git diff --quiet` — the rollup must not modify any tracked file. We
# use porcelain status rather than `git diff --quiet` because porcelain
# also catches new untracked files under .orchestrator/milestones/.
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-read-only.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
FIX_DIR="$PROJECT_ROOT/tests/fixtures/m027-p00"
MS_DIR="$PROJECT_ROOT/.orchestrator/milestones"

if [ ! -r "$ROLLUP" ] || [ ! -d "$FIX_DIR" ]; then
  printf 'FAIL: %s rollup-or-fix-dir-missing\n' "$NAME" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

before="$tmp/before.status"
after="$tmp/after.status"
ms_before="$tmp/ms.before"
ms_after="$tmp/ms.after"

# Snapshot git status (porcelain) and the milestones tree listing.
( cd "$PROJECT_ROOT" && git status --porcelain ) > "$before" 2>/dev/null || true
( cd "$MS_DIR" && find . -type f ) > "$ms_before" 2>/dev/null || true

ran=0
for fix in "$FIX_DIR"/*.jsonl; do
  [ -f "$fix" ] || continue
  bash "$ROLLUP" --granularity milestone --milestone M999 --log "$fix" >/dev/null 2>/dev/null
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'FAIL: %s rollup against %s rc=%d\n' "$NAME" "$fix" "$rc" >&2
    exit 1
  fi
  ran=$((ran + 1))
done

if [ "$ran" -lt 1 ]; then
  printf 'FAIL: %s no fixtures found in %s\n' "$NAME" "$FIX_DIR" >&2
  exit 1
fi

( cd "$PROJECT_ROOT" && git status --porcelain ) > "$after" 2>/dev/null || true
( cd "$MS_DIR" && find . -type f ) > "$ms_after" 2>/dev/null || true

if ! cmp -s "$before" "$after"; then
  printf 'FAIL: %s git status changed during rollup runs\n' "$NAME" >&2
  diff "$before" "$after" >&2 || true
  exit 1
fi

if ! cmp -s "$ms_before" "$ms_after"; then
  printf 'FAIL: %s .orchestrator/milestones/ tree changed\n' "$NAME" >&2
  diff "$ms_before" "$ms_after" >&2 || true
  exit 1
fi

printf 'PASS: %s ran=%d git-status-stable milestones-tree-stable\n' "$NAME" "$ran"
exit 0
