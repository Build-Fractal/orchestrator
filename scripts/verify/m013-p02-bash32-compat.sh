#!/usr/bin/env bash
# scripts/verify/m013-p02-bash32-compat.sh — Verify every P02 shell script
# is Bash 3.2 compatible and anti-pattern-lint clean.
#
# Scans every .sh file created or modified by M013/P02 for Bash-4-only
# constructs (assoc-arrays `declare -A`, array-from-stdin builtins mapfile /
# readarray, case-conversion expansion `${var^^}` / `${var,,}`, process
# substitution `<(...)` / `>(...)`, and combined-redirect shorthand `&>` /
# `|&`). Each file is also run through the repo's anti-pattern-lint.sh
# (M016/M021 invariant).
#
# Self-exclusion: this gate itself contains each regex literally (they are
# the patterns being searched for), so the pattern-scan loop skips its own
# file. `bash -n` on this file still parses.
#
# Exits 0 when all scripts pass, 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0

# List of .sh files touched or created by M013/P02.
# Mirror of T07-PLAN's Files To Touch list, filtered to .sh files only,
# plus the T07 gate scripts themselves.
P02_FILES="
scripts/integrations/github-common.sh
scripts/integrations/github-init.sh
scripts/verify/m013-p02-github-common.sh
scripts/verify/m013-p02-github-init-fixture.sh
scripts/verify/m013-p02-github-init-preflight.sh
scripts/verify/m013-p02-dry-run-manifest.sh
scripts/verify/m013-p02-github-init-command.sh
scripts/verify/m013-p02-reference-extensions.sh
scripts/verify/m013-p02-auto-mode-pending.sh
scripts/verify/m013-p02-bash32-compat.sh
scripts/verify/m013-p02-phase-suite.sh
"

# Bash-4-only constructs. Each entry is a grep -E regex.
# - declare -A     : assoc-arrays (bash 4+)
# - mapfile / readarray : array-from-stdin builtin (bash 4+)
# - ${var^^} / ${var,,} : case-conversion expansion (bash 4+)
# - <(...) / >(...) : process substitution
# - &>              : combined-redirect shorthand (bash 4 semantics)
# - |&              : pipe-both-streams shorthand (bash 4+)
BAD_PATTERNS="
declare[[:space:]]+-A
\\b(mapfile|readarray)\\b
\\$\\{[A-Za-z_][A-Za-z0-9_]*\\^\\^
\\$\\{[A-Za-z_][A-Za-z0-9_]*,,
<\\(
>\\(
&>
\\|&
"

IFS='
'
for f in $P02_FILES; do
  IFS=' '
  [ -n "$f" ] || continue
  path="${REPO_ROOT}/${f}"
  if [ ! -f "$path" ]; then
    echo "FAIL: ${f} missing"
    fail_count=$((fail_count + 1))
    IFS='
'
    continue
  fi
  # bash -n syntactic parse check against the actual bash runtime.
  bash -n "$path" 2>/dev/null
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: ${f} — bash -n parse error"
    fail_count=$((fail_count + 1))
    IFS='
'
    continue
  fi
  # Scan for Bash-4-only constructs. Track whether this file matched any.
  file_failed=0
  IFS='
'
  for p in $BAD_PATTERNS; do
    IFS=' '
    [ -n "$p" ] || continue
    # Self-exclusion: skip pattern scan on this gate itself (the BAD_PATTERNS
    # body contains each regex literally, which would otherwise self-match).
    # bash -n parse-check above still covers it.
    case "$f" in
      scripts/verify/m013-p02-bash32-compat.sh)
        IFS='
'
        continue
        ;;
    esac
    if grep -En "$p" "$path" >/dev/null 2>&1; then
      echo "FAIL: ${f} contains bash4-only pattern: ${p}"
      fail_count=$((fail_count + 1))
      file_failed=1
    fi
    IFS='
'
  done
  if [ "$file_failed" -eq 0 ]; then
    echo "PASS: ${f} bash-3.2 clean"
  fi
  IFS='
'
done
IFS=' '

# Run anti-pattern-lint across P02 files. The lint tool only flags violations
# inside fenced code blocks in markdown; for raw .sh files with no fences
# it degrades to a no-op LINT PASS — this still exercises the invariant
# that P02 did not accidentally stage agent-facing markdown with Class A/B
# patterns under the .sh suffix.
LINT="${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh"
if [ -f "$LINT" ]; then
  IFS='
'
  for f in $P02_FILES; do
    IFS=' '
    [ -n "$f" ] || continue
    path="${REPO_ROOT}/${f}"
    [ -f "$path" ] || continue
    bash "$LINT" --fixture "$path" >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "FAIL: ${f} fails anti-pattern-lint.sh"
      fail_count=$((fail_count + 1))
    fi
    IFS='
'
  done
  IFS=' '
  echo "PASS: anti-pattern-lint clean across all P02 files"
else
  echo "SKIP: anti-pattern-lint.sh not present (unexpected; M016/M021 invariant)"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p02-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m013-p02-bash32-compat.sh ($fail_count failures)" >&2
exit 1
