#!/usr/bin/env bash
# scripts/state/resolve-root.sh — Resolve the orchestrator state root.
#
# Resolution precedence (highest first):
#   1. ORCHESTRATOR_ROOT env var (explicit override)
#   2. state_root field in .orchestrator/config.yml or .specify/orchestrator/config.yml
#   3. .orchestrator/ directory (standalone canonical)
#   4. .specify/orchestrator/ directory (migration bridge)
#   5. Default: .orchestrator/ (new projects)
#
# Usage:
#   resolve-root.sh                  -> emits repo-relative root to stdout
#   resolve-root.sh --verbose        -> emits "root=<path>" plus "source=<precedence-rule>"
#   resolve-root.sh --absolute       -> emits absolute path to stdout
#
# Exit: 0 on success. 1 on malformed argument.
# Bash 3.2 compatible (MEM001).

set -u

VERBOSE=0
ABSOLUTE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=1; shift ;;
    --absolute) ABSOLUTE=1; shift ;;
    -h|--help)
      sed -n '2,17p' "$0"
      exit 0 ;;
    *)
      echo "ERROR: unknown argument '$1'" >&2
      exit 1 ;;
  esac
done

# Determine repo root. Walk up from $PWD looking for .git.
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

resolved=""
source_rule=""

# Rule 1: env var
if [[ -n "${ORCHESTRATOR_ROOT:-}" ]]; then
  resolved="$ORCHESTRATOR_ROOT"
  source_rule="env:ORCHESTRATOR_ROOT"
fi

# Rule 2: config file state_root field
if [[ -z "$resolved" ]]; then
  for cfg in "$repo_root/.orchestrator/config.yml" "$repo_root/.specify/orchestrator/config.yml"; do
    if [[ -f "$cfg" ]]; then
      candidate="$(grep -E '^state_root:' "$cfg" 2>/dev/null | head -n 1 | sed -E 's/^state_root:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
      if [[ -n "$candidate" ]]; then
        resolved="$candidate"
        source_rule="config:$cfg"
        break
      fi
    fi
  done
fi

# Rule 3: .orchestrator/ exists
if [[ -z "$resolved" ]] && [[ -d "$repo_root/.orchestrator" ]]; then
  resolved=".orchestrator"
  source_rule="existing:.orchestrator"
fi

# Rule 4: .specify/orchestrator/ exists (bridge)
if [[ -z "$resolved" ]] && [[ -d "$repo_root/.specify/orchestrator" ]]; then
  resolved=".specify/orchestrator"
  source_rule="bridge:.specify/orchestrator"
fi

# Rule 5: default
if [[ -z "$resolved" ]]; then
  resolved=".orchestrator"
  source_rule="default"
fi

# Strip trailing slash if any
resolved="${resolved%/}"

if [[ "$ABSOLUTE" = "1" ]]; then
  case "$resolved" in
    /*) : ;;
    *)  resolved="$repo_root/$resolved" ;;
  esac
fi

if [[ "$VERBOSE" = "1" ]]; then
  echo "root=$resolved"
  echo "source=$source_rule"
else
  echo "$resolved"
fi
