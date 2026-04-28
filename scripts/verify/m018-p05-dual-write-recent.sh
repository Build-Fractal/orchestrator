#!/usr/bin/env bash
# scripts/verify/m018-p05-dual-write-recent.sh — phase-truth verifier:
# "CLAUDE.md and AGENTS.md `recent-changes` blocks both name M018/P05
# (or compression-eval) — phase-close dual-write via
# scripts/util/dual-write-runtime-md.sh."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

for f in "$REPO_ROOT/CLAUDE.md" "$REPO_ROOT/AGENTS.md"; do
  if [ ! -f "$f" ]; then
    printf 'FAIL: missing %s\n' "$f" >&2
    exit 1
  fi
  block="$(awk '
    /^# >>> orchestrator:recent-changes >>>/ { in_blk=1; next }
    /^# <<< orchestrator:recent-changes <<</ { in_blk=0 }
    in_blk { print }
  ' "$f")"
  if [ -z "$block" ]; then
    printf 'FAIL: %s has empty/missing orchestrator:recent-changes region\n' "$f" >&2
    exit 1
  fi
  if ! printf '%s\n' "$block" | grep -qE 'M018/P05|compression-eval'; then
    printf 'FAIL: %s recent-changes block missing M018/P05 or compression-eval marker\n' "$f" >&2
    printf '       block contents:\n%s\n' "$block" >&2
    exit 1
  fi
done

# recent-changes literal in this verifier (artifact contains check).
printf 'PASS: m018-p05-dual-write-recent (both CLAUDE.md and AGENTS.md name M018/P05 or compression-eval in recent-changes)\n'
exit 0
