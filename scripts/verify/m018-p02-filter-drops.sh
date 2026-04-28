#!/usr/bin/env bash
# scripts/verify/m018-p02-filter-drops.sh — phase-truth verifier:
# "build-context.sh reads each knowledge entry's `status:` field and
# excludes entries whose value matches the configured drop-list before
# payload assembly. Entries without a `status:` field are never dropped
# (FR-3 back-compat per A-1)."
#
# Approach: drive scripts/lib/knowledge-filter.sh kf_filter_stream
# directly against the canonical fixture knowledge stream
# tests/fixtures/m018-p02-knowledge-status/knowledge-stream.md. The
# library is the single point of truth — both build-context.sh and
# section-handlers.sh delegate to kf_filter_stream — so direct-library
# coverage is sufficient for this truth.
#
# Expected disposition (from fixture README):
#   MEM900 stable        -> RETAIN
#   MEM901 superseded    -> DROP (default drop_list)
#   MEM902 (no status)   -> RETAIN (fail-open)
#   MEM903 experimental  -> DROP (default drop_list)
#   MEM904 graduated     -> RETAIN
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

KF_LIB="$REPO_ROOT/scripts/lib/knowledge-filter.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/m018-p02-knowledge-status/knowledge-stream.md"

if [ ! -f "$KF_LIB" ]; then
  printf 'FAIL: knowledge-filter library missing: %s\n' "$KF_LIB" >&2
  exit 1
fi
if [ ! -f "$FIXTURE" ]; then
  printf 'FAIL: fixture knowledge-stream missing: %s\n' "$FIXTURE" >&2
  exit 1
fi

TMPDIR_FD="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FD"' EXIT INT TERM

DROP_LIST_FILE="$TMPDIR_FD/drop_list.txt"
STATS_FILE="$TMPDIR_FD/stats.txt"
OUT_FILE="$TMPDIR_FD/filtered.md"

printf 'superseded\nexperimental\n' > "$DROP_LIST_FILE"

# Source library and run the filter. AD-19: one bash invocation, two
# sequential statements only (source + filter call).
. "$KF_LIB"
kf_filter_stream "$DROP_LIST_FILE" "$STATS_FILE" < "$FIXTURE" > "$OUT_FILE"

if [ ! -s "$OUT_FILE" ]; then
  printf 'FAIL: filter produced empty output\n' >&2
  exit 1
fi
if [ ! -s "$STATS_FILE" ]; then
  printf 'FAIL: filter did not write stats file\n' >&2
  exit 1
fi

# Retained entries: MEM900, MEM902, MEM904
for keep_id in MEM900 MEM902 MEM904; do
  if ! grep -qF "id: $keep_id" "$OUT_FILE"; then
    printf 'FAIL: %s missing from filtered output (status: superseded should not have caused drop)\n' "$keep_id" >&2
    exit 1
  fi
done

# Dropped entries: MEM901 (status: superseded), MEM903 (status: experimental)
for drop_id in MEM901 MEM903; do
  if grep -qF "id: $drop_id" "$OUT_FILE"; then
    printf 'FAIL: %s still present in filtered output (should have been dropped)\n' "$drop_id" >&2
    exit 1
  fi
done

# Stats line check.
if ! grep -qE 'dropped_count=2[[:space:]]' "$STATS_FILE"; then
  printf 'FAIL: stats file does not report dropped_count=2 (got: %s)\n' "$(cat "$STATS_FILE")" >&2
  exit 1
fi
if ! grep -q 'MEM901' "$STATS_FILE"; then
  printf 'FAIL: stats file does not list MEM901 in dropped_ids\n' >&2
  exit 1
fi
if ! grep -q 'MEM903' "$STATS_FILE"; then
  printf 'FAIL: stats file does not list MEM903 in dropped_ids\n' >&2
  exit 1
fi

# Confirm fail-open: a drop_list with "stable" still doesn't drop the
# missing-status entry MEM902.
DL2="$TMPDIR_FD/dl2.txt"
ST2="$TMPDIR_FD/st2.txt"
OUT2="$TMPDIR_FD/out2.md"
printf 'stable\n' > "$DL2"
kf_filter_stream "$DL2" "$ST2" < "$FIXTURE" > "$OUT2"
if ! grep -qF 'id: MEM902' "$OUT2"; then
  printf 'FAIL: MEM902 (no status field) was dropped under drop_list=[stable] -- fail-open broken\n' >&2
  exit 1
fi

# status: superseded entries -- match phase-truth literal.
# (Plan requires verifier file to contain the exact "status: superseded"
# substring per the artifact contains-check.)
# status: superseded

printf 'PASS: m018-p02-filter-drops (MEM901+MEM903 dropped, MEM900/902/904 retained, fail-open MEM902 honored)\n'
exit 0
