#!/usr/bin/env bash
# scripts/knowledge/increment-hits.sh — Increment hit_count on a knowledge entry
# Usage: increment-hits.sh --id MEM###
# Thin wrapper around update-entry.sh --increment-hits for discoverability.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/update-entry.sh" "$@" --increment-hits
