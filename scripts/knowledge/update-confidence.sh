#!/usr/bin/env bash
# scripts/knowledge/update-confidence.sh — Update confidence on a knowledge entry
# Usage: update-confidence.sh --id MEM### --confidence 0.85
# Thin wrapper around update-entry.sh for discoverability.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/update-entry.sh" "$@"
