#!/usr/bin/env bash
# scripts/state/detect-speckit.sh — Detect spec-kit installation.
#
# Signals (any one triggers speckit_installed=true):
#   - .specify/ directory at repo root
#   - .specify/memory/constitution.md file
#   - speckit binary on PATH
#
# Usage:
#   detect-speckit.sh                  -> emits two key=value lines
#   detect-speckit.sh --force-disabled -> integration_mode=disabled even if installed
#
# Output (stdout):
#   speckit_installed=<true|false>
#   integration_mode=<enabled|disabled>
#
# Exit: 0 always (detection is informational, not failure-mode).
# Bash 3.2 compatible.

set -u

FORCE_DISABLED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-disabled) FORCE_DISABLED=1; shift ;;
    -h|--help)
      sed -n '2,13p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

# Locate repo root
repo_root="$PWD"
while [[ "$repo_root" != "/" ]]; do
  if [[ -d "$repo_root/.git" ]] || [[ -f "$repo_root/.git" ]]; then
    break
  fi
  repo_root="$(dirname "$repo_root")"
done
if [[ "$repo_root" = "/" ]]; then
  repo_root="$PWD"
fi

installed="false"

if [[ -d "$repo_root/.specify" ]]; then
  installed="true"
fi
if [[ "$installed" = "false" ]] && [[ -f "$repo_root/.specify/memory/constitution.md" ]]; then
  installed="true"
fi
if [[ "$installed" = "false" ]] && command -v speckit >/dev/null 2>&1; then
  installed="true"
fi

if [[ "$installed" = "true" ]] && [[ "$FORCE_DISABLED" = "0" ]]; then
  mode="enabled"
else
  mode="disabled"
fi

echo "speckit_installed=$installed"
echo "integration_mode=$mode"
