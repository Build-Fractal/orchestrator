#!/usr/bin/env bash
# scripts/lib/conversus-detect.sh -- Optional sister-project detection helper.
#
# Sourced by the three install scripts under packaging/install/ to emit a
# trailing informational note about the conversus sibling project after the
# SUMMARY: line. Pure additive output — never alters install behavior, never
# exits non-zero (the orchestrator runs fine without conversus; the
# `scripts/dispatch/adapters/tool/conversus.sh` adapter degrades gracefully).
#
# The resolver order MUST stay aligned with the adapter's order at
# `scripts/dispatch/adapters/tool/conversus.sh:106-155`:
#   1. CONVERSUS_STUB=1                            -- stub (test-only; skipped here)
#   2. command -v conversus                        -- PATH
#   3. $CONVERSUS_HOME/bin/conversus               -- explicit env var
#   4. $HOME/Sites/conversus-oss/bin/conversus     -- user-local OSS
#   5. $HOME/Sites/conversus/bin/conversus         -- user-local paid
#
# Usage:
#   . "$REPO_ROOT/scripts/lib/conversus-detect.sh"
#   emit_conversus_note
#
# Bash 3.2 compatible.

emit_conversus_note() {
  _cv_path=""
  if command -v conversus >/dev/null 2>&1; then
    _cv_path="$(command -v conversus)"
  elif [ -n "${CONVERSUS_HOME:-}" ] && [ -x "${CONVERSUS_HOME}/bin/conversus" ]; then
    _cv_path="${CONVERSUS_HOME}/bin/conversus"
  elif [ -x "${HOME:-}/Sites/conversus-oss/bin/conversus" ]; then
    _cv_path="${HOME}/Sites/conversus-oss/bin/conversus"
  elif [ -x "${HOME:-}/Sites/conversus/bin/conversus" ]; then
    _cv_path="${HOME}/Sites/conversus/bin/conversus"
  fi

  if [ -n "$_cv_path" ]; then
    echo "Detected conversus at ${_cv_path}; deliberation gates available via /orchestrator-conversus-gate."
  else
    echo "Optional sister project: conversus enables multi-agent deliberation gates via /orchestrator-conversus-gate."
    echo "  Install: pip install git+https://github.com/Build-Fractal/conversus-oss.git"
  fi
}
