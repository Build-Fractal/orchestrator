#!/usr/bin/env bash
# scripts/lifecycle/evaluate-preflight.sh — Evaluate command pre-flight checks
# Single-script replacement for inline conditional logic in evaluate.md that
# triggers Claude Code harness safety heuristics (AD-19).
#
# Combines:
#   1. Extension availability check (scaffold.sh existence)
#   2. Config override check (default_tier)
#   3. Permission generation pipeline (autonomy.generate_on_init)
#
# Usage: evaluate-preflight.sh <project-root> <tier> [--skip-permissions]
#
# Output (stdout):
#   PREFLIGHT:OK extension=true config_tier=<A|B|C|auto> permissions=<generated|skipped|merged|error>
#   PREFLIGHT:ERROR reason=<description>
#
# Exit 0 on success, 1 on fatal error.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${1:-.}"
TIER="${2:-C}"
SKIP_PERMISSIONS=false

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-permissions) SKIP_PERMISSIONS=true; shift ;;
    *) shift ;;
  esac
done

READ_CONFIG="$SCRIPT_DIR/../state/read-config.sh"
SCAFFOLD="$SCRIPT_DIR/scaffold.sh"
GENERATE="$SCRIPT_DIR/generate-permissions.sh"
WRITE_PERMS="$SCRIPT_DIR/write-permissions.sh"

# --- Check 1: Extension availability ---
if [[ ! -f "$SCAFFOLD" ]]; then
  echo "PREFLIGHT:ERROR reason=extension_not_installed"
  exit 1
fi

# --- Check 2: Config tier override ---
config_tier="auto"
if [[ -f "$READ_CONFIG" ]]; then
  config_tier=$(bash "$READ_CONFIG" default_tier 2>/dev/null) || config_tier="auto"
  if [[ -z "$config_tier" || "$config_tier" = "null" ]]; then
    config_tier="auto"
  fi
fi

# --- Check 3: Permission generation ---
perm_status="skipped"

if [[ "$SKIP_PERMISSIONS" = "false" && "$TIER" != "A" ]]; then
  gen_on_init="true"
  if [[ -f "$READ_CONFIG" ]]; then
    gen_on_init=$(bash "$READ_CONFIG" autonomy.generate_on_init 2>/dev/null) || gen_on_init="true"
    if [[ -z "$gen_on_init" || "$gen_on_init" = "null" ]]; then
      gen_on_init="true"
    fi
  fi

  if [[ "$gen_on_init" = "true" ]]; then
    if [[ -x "$GENERATE" && -x "$WRITE_PERMS" ]]; then
      # Use project-local temp instead of /tmp (AD-19: avoid /tmp writes)
      orch_tmp="$PROJECT_ROOT/.specify/orchestrator/tmp"
      mkdir -p "$orch_tmp"
      canon_file="$orch_tmp/evaluate-canon.json"

      if bash "$GENERATE" "$PROJECT_ROOT" --tier "$TIER" > "$canon_file" 2>/dev/null; then
        if bash "$WRITE_PERMS" "$PROJECT_ROOT" < "$canon_file" 2>/dev/null; then
          perm_status="generated"
        else
          perm_status="error"
        fi
      else
        perm_status="error"
      fi
      # Clean up project-local temp (safe, scoped)
      rm -f "$canon_file"
    else
      perm_status="skipped"
    fi
  fi
fi

echo "PREFLIGHT:OK extension=true config_tier=$config_tier permissions=$perm_status"
