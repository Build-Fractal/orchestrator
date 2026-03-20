#!/usr/bin/env bash
# scripts/verify/run-commands.sh — Tier 2 command execution verification
# Runs configured verification commands and captures results.
#
# Usage: run-commands.sh [command1] [command2] ... [--config <config-file>]
#   Commands can be passed as positional arguments or read from a config file.
#   --config  Path to orchestrator config file (reads verification_commands key)
#
# Output: Structured PASS/FAIL/SKIP lines to stdout. Errors to stderr.
# Exit: 0 if all commands pass (or none configured), 1 if any fail.

set -euo pipefail

# --- Argument parsing ---
COMMANDS=()
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"; shift 2 ;;
    -*)
      echo "run-commands.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      COMMANDS+=("$1"); shift ;;
  esac
done

# If config file provided and no direct commands, read from config
if [[ ${#COMMANDS[@]} -eq 0 && -n "$CONFIG_FILE" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "run-commands.sh: config file not found: $CONFIG_FILE" >&2
    exit 1
  fi

  # Read verification_commands from YAML config
  # Format: verification_commands:\n  - cmd1\n  - cmd2
  IN_SECTION=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^verification_commands:'; then
      IN_SECTION=true
      # Check for inline value (e.g., "verification_commands: []")
      inline=$(echo "$line" | sed 's/^verification_commands:[[:space:]]*//')
      if [[ "$inline" = "[]" ]]; then
        break
      fi
      continue
    fi
    if [[ "$IN_SECTION" = "true" ]]; then
      # Lines starting with "  - " are list items
      if echo "$line" | grep -qE '^[[:space:]]+-'; then
        cmd=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')
        if [[ -n "$cmd" ]]; then
          COMMANDS+=("$cmd")
        fi
      else
        # Non-list line ends the section
        break
      fi
    fi
  done < "$CONFIG_FILE"
fi

# No commands configured
if [[ ${#COMMANDS[@]} -eq 0 ]]; then
  echo "SKIP: no verification commands configured"
  exit 0
fi

# --- Execute commands ---
FAILURES=0

for cmd in "${COMMANDS[@]}"; do
  # Capture output and exit code
  cmd_output=""
  cmd_exit=0
  cmd_output=$(eval "$cmd" 2>&1) || cmd_exit=$?

  if [[ "$cmd_exit" -eq 0 ]]; then
    echo "PASS: $cmd (exit 0)"
  else
    # Show first 5 lines of output for failed commands
    first_lines=$(echo "$cmd_output" | head -5)
    echo "FAIL: $cmd (exit $cmd_exit): $first_lines"
    FAILURES=$((FAILURES + 1))
  fi
done

# --- Exit ---
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
exit 0
