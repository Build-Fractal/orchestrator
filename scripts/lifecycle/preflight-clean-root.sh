#!/usr/bin/env bash
# scripts/lifecycle/preflight-clean-root.sh — Preflight clean-root check
#
# Verifies the git working tree is clean (or contains only allowlisted
# orchestrator working-area paths) before destructive lifecycle actions
# like mark-complete.sh.
#
# Inspired by gsd-2 v2.77 milestone-completion preflight hardening, but
# advisory-only — no auto-stash. Per Constitution VI, silent working-tree
# mutation is the failure mode the principle exists to prevent.
#
# Usage: preflight-clean-root.sh <orchestrator-root>
#
# Allowlist (paths relative to git toplevel that do NOT block):
#   .orchestrator/scratch/**
#   .orchestrator/tmp/**
#   .orchestrator/milestones/*/*-result.txt
#   .orchestrator/milestones/*/execution-log.jsonl
#
# Exit codes:
#   0 — clean (or non-git repo, or env override)
#   1 — usage / arg error
#   2 — dirty working tree (blocking changes present)
#
# Env overrides:
#   ORCHESTRATOR_ALLOW_DIRTY_MARK=1 — bypass check (returns 0 with notice)
#
# Stdout:
#   PREFLIGHT: clean
#   PREFLIGHT: not a git repo (skipped)
#   PREFLIGHT: skipped (env override)
#   PREFLIGHT: dirty — N path(s)
#
# Stderr (only on dirty):
#   <list of blocking paths, one per line>
#   <remediation hint>
#
# Called by: scripts/lifecycle/mark-complete.sh
# Safe to call from: scripts/lifecycle/phase-transition.sh in future
#
# Bash 3.2 compatible (no declare -A per K001).

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: preflight-clean-root.sh <orchestrator-root>" >&2
  exit 1
fi

ORCH_ROOT="$1"

if [ ! -d "$ORCH_ROOT" ]; then
  echo "ERROR: orchestrator-root does not exist: $ORCH_ROOT" >&2
  exit 1
fi

# Env override — bypass with audit notice.
if [ "${ORCHESTRATOR_ALLOW_DIRTY_MARK:-}" = "1" ]; then
  echo "PREFLIGHT: skipped (env override)"
  exit 0
fi

# Locate git repo top. If orch-root is not inside a git repo, skip.
if ! command -v git >/dev/null 2>&1; then
  echo "PREFLIGHT: not a git repo (skipped)"
  exit 0
fi

GIT_TOP="$(git -C "$ORCH_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$GIT_TOP" ]; then
  echo "PREFLIGHT: not a git repo (skipped)"
  exit 0
fi

# Collect porcelain status. Each line is "XY <path>" (XY = 2 status chars).
# Renames present as "<orig> -> <new>"; we check the new path against allowlist.
status_output="$(git -C "$GIT_TOP" status --porcelain)"

if [ -z "$status_output" ]; then
  echo "PREFLIGHT: clean"
  exit 0
fi

blocking=""
blocking_count=0

while IFS= read -r line; do
  [ -z "$line" ] && continue
  path="${line:3}"
  case "$path" in
    *" -> "*) path="${path##* -> }" ;;
  esac

  case "$path" in
    .orchestrator/scratch/*) continue ;;
    .orchestrator/tmp/*) continue ;;
    .orchestrator/milestones/*/*-result.txt) continue ;;
    .orchestrator/milestones/*/execution-log.jsonl) continue ;;
  esac

  blocking_count=$((blocking_count + 1))
  if [ -z "$blocking" ]; then
    blocking="$path"
  else
    blocking="$blocking
$path"
  fi
done <<< "$status_output"

if [ "$blocking_count" -eq 0 ]; then
  echo "PREFLIGHT: clean"
  exit 0
fi

echo "PREFLIGHT: dirty — $blocking_count path(s)"
{
  echo "$blocking"
  echo ""
  echo "Remediation: commit, stash, or set ORCHESTRATOR_ALLOW_DIRTY_MARK=1"
} >&2
exit 2
