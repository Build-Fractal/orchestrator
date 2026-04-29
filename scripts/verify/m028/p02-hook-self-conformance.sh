#!/usr/bin/env bash
# scripts/verify/m028/p02-hook-self-conformance.sh
#
# M028/P02/T01 verifier: asserts every line T01 introduces into the
# PreToolUse shape-guard hook (the BASH_SOURCE-based classifier-resolution
# block) self-conforms to the M021 shape classifier under AP-009 (no
# compound chain > 2 connectors). Hard gate per CON-3 + FR-21.
#
# Scoped to the resolution block (between the "# Locate classifier --"
# header and the "# Read stdin" divider). Pre-existing M021 lines outside
# this block are immutable per the M028 spec's "M021 surface revision"
# non-goal and are not gated here; FR-21's P03 finding-G-self-conformance.sh
# is the broader companion check under the M028-extended classifier.
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX-sh safe.
# Top-level while loop is allowed (AD-19 prohibits inline embedded loops,
# not script-body control flow).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"
CLASSIFIER_LIB="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"

if [ ! -f "$HOOK" ]; then
  printf 'FAIL: hook file not found at %s\n' "$HOOK" >&2
  exit 1
fi

if [ ! -f "$CLASSIFIER_LIB" ]; then
  printf 'FAIL: M021 classifier library not found at %s\n' "$CLASSIFIER_LIB" >&2
  exit 1
fi

# Source the M021 classifier; classify_command writes verdict to stdout.
# shellcheck disable=SC1090
. "$CLASSIFIER_LIB"

# Resolution-block boundary markers (matched literally, anchored at line
# start with optional leading whitespace tolerance).
START_MARKER="# Locate classifier"
END_MARKER="# Read stdin"

inside_block=0
fail_count=0
ln=0

while IFS= read -r line; do
  ln=$((ln + 1))

  # Detect block boundaries.
  case "$line" in
    *"$START_MARKER"*)
      inside_block=1
      continue
      ;;
    *"$END_MARKER"*)
      inside_block=0
      continue
      ;;
  esac

  if [ "$inside_block" -ne 1 ]; then
    continue
  fi

  # Skip blank lines and comment-only lines.
  trimmed="${line#"${line%%[![:space:]]*}"}"
  case "$trimmed" in
    '')
      continue
      ;;
    \#*)
      continue
      ;;
  esac

  verdict="$(classify_command "$line" 2>/dev/null)"
  case "$verdict" in
    reject:*)
      printf 'FAIL: line %d classified %s -- %s\n' "$ln" "$verdict" "$line" >&2
      fail_count=$((fail_count + 1))
      ;;
  esac
done < "$HOOK"

# Sanity: ensure the boundary markers were both seen so we did not silently
# pass on a hook whose resolution block was deleted or renamed.
if ! grep -q "$START_MARKER" "$HOOK"; then
  printf 'FAIL: resolution-block start marker "%s" not found in hook\n' "$START_MARKER" >&2
  fail_count=$((fail_count + 1))
fi
if ! grep -q "$END_MARKER" "$HOOK"; then
  printf 'FAIL: resolution-block end marker "%s" not found in hook\n' "$END_MARKER" >&2
  fail_count=$((fail_count + 1))
fi

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

printf 'PASS: pre-bash-shape-guard.sh self-conforms to AP-009 (no compound chain > 2)\n'
exit 0
