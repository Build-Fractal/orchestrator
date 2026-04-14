#!/usr/bin/env bash
# scripts/dispatch/backend-registry.sh — Dispatch backend discovery and probing
#
# Scans scripts/dispatch/adapters/backend/*.sh and probes each adapter via
# --probe to determine which backends are available in the current
# environment. Outputs discovery and availability as key=value lines.
#
# Usage: backend-registry.sh [--list | --probe <backend>]
#   (no args)       — discover + probe all adapters; output key=value summary
#   --list          — list all discovered adapters (one per line), no probing
#   --probe <name>  — probe a single named adapter; print its raw probe output
#
# Output (default mode):
#   backends_discovered=<comma-list>
#   backends_available=<comma-list>
#   default_backend=<name or empty>
#
# FR-011: new backends are registered by dropping a *.sh file into the
# adapters/backend/ directory. No core edits required.
#
# Bash 3.2 compatible. Always exits 0.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTERS_DIR="${SCRIPT_DIR}/adapters/backend"

MODE="summary"
TARGET_BACKEND=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      MODE="list"; shift ;;
    --probe)
      MODE="probe"; TARGET_BACKEND="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Discovery ---

discovered_names=""
if [[ -d "$ADAPTERS_DIR" ]]; then
  for adapter in "$ADAPTERS_DIR"/*.sh; do
    [[ -f "$adapter" ]] || continue
    base="$(basename "$adapter" .sh)"
    if [[ -z "$discovered_names" ]]; then
      discovered_names="$base"
    else
      discovered_names="${discovered_names},${base}"
    fi
  done
fi

# --- Mode: list ---

if [[ "$MODE" = "list" ]]; then
  if [[ -n "$discovered_names" ]]; then
    # Print one adapter name per line
    old_ifs="$IFS"
    IFS=','
    for name in $discovered_names; do
      echo "$name"
    done
    IFS="$old_ifs"
  fi
  exit 0
fi

# --- Mode: probe a single named adapter ---

if [[ "$MODE" = "probe" ]]; then
  if [[ -z "$TARGET_BACKEND" ]]; then
    echo "FAIL: --probe requires a backend name" >&2
    exit 0
  fi
  adapter="${ADAPTERS_DIR}/${TARGET_BACKEND}.sh"
  if [[ ! -f "$adapter" ]]; then
    echo "available=false"
    echo "reason=adapter-not-found"
    exit 0
  fi
  bash "$adapter" --probe 2>/dev/null || echo "available=false"
  exit 0
fi

# --- Mode: summary (default) ---

available_names=""
if [[ -n "$discovered_names" ]]; then
  old_ifs="$IFS"
  IFS=','
  for name in $discovered_names; do
    adapter="${ADAPTERS_DIR}/${name}.sh"
    probe_output="$(bash "$adapter" --probe 2>/dev/null || echo "available=false")"
    # Extract the available= value
    is_available="$(echo "$probe_output" | grep -E '^available=' | head -n 1 | cut -d= -f2)"
    if [[ "$is_available" = "true" ]]; then
      if [[ -z "$available_names" ]]; then
        available_names="$name"
      else
        available_names="${available_names},${name}"
      fi
    fi
  done
  IFS="$old_ifs"
fi

default_backend=""
if [[ -n "$available_names" ]]; then
  default_backend="${available_names%%,*}"
fi

echo "backends_discovered=${discovered_names}"
echo "backends_available=${available_names}"
echo "default_backend=${default_backend}"
exit 0
