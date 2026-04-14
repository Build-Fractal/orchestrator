#!/usr/bin/env bash
# scripts/state/config-system.sh — Unified config get/set/list for the orchestrator.
#
# Stores configuration at <root>/config.yml where <root> is resolved via
# scripts/state/resolve-root.sh. File format is a flat YAML subset:
#   key: value
#   nested.key: value     (dot notation on a single line)
#
# Usage:
#   config-system.sh get <key>
#   config-system.sh set <key> <value>
#   config-system.sh list
#
# Exit: 0 success, 1 missing key on `get`, 2 bad arguments.
# Bash 3.2 compatible (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVE_ROOT="$SCRIPT_DIR/resolve-root.sh"

if [[ ! -x "$RESOLVE_ROOT" ]]; then
  echo "ERROR: resolve-root.sh not found or not executable at $RESOLVE_ROOT" >&2
  exit 2
fi

SUBCOMMAND="${1:-}"
if [[ -z "$SUBCOMMAND" ]]; then
  echo "Usage: config-system.sh {get|set|list} [args]" >&2
  exit 2
fi
shift

# Resolve config file location once, up front.
root_path="$(bash "$RESOLVE_ROOT" --absolute)"
config_file="$root_path/config.yml"

ensure_config_dir() {
  if [[ ! -d "$root_path" ]]; then
    mkdir -p "$root_path"
  fi
  if [[ ! -f "$config_file" ]]; then
    touch "$config_file"
  fi
}

case "$SUBCOMMAND" in
  get)
    key="${1:-}"
    if [[ -z "$key" ]]; then
      echo "Usage: config-system.sh get <key>" >&2
      exit 2
    fi
    if [[ ! -f "$config_file" ]]; then
      exit 1
    fi
    value="$(grep -E "^${key}:" "$config_file" 2>/dev/null | head -n 1 | sed -E "s/^${key}:[[:space:]]*(.*)[[:space:]]*$/\1/")"
    if [[ -z "$value" ]]; then
      exit 1
    fi
    echo "$value"
    ;;

  set)
    key="${1:-}"
    value="${2:-}"
    if [[ -z "$key" ]] || [[ -z "$value" ]]; then
      echo "Usage: config-system.sh set <key> <value>" >&2
      exit 2
    fi
    ensure_config_dir
    # Upsert: remove any existing line for the key, then append.
    tmp_file="$config_file.tmp.$$"
    if grep -qE "^${key}:" "$config_file" 2>/dev/null; then
      grep -vE "^${key}:" "$config_file" > "$tmp_file" || true
      mv "$tmp_file" "$config_file"
    fi
    echo "${key}: ${value}" >> "$config_file"
    ;;

  list)
    if [[ ! -f "$config_file" ]]; then
      exit 0
    fi
    # Strip blank lines and comments, sort, print as key=value.
    grep -vE '^[[:space:]]*(#|$)' "$config_file" \
      | sed -E 's/^([^:]+):[[:space:]]*(.*)$/\1=\2/' \
      | sort
    ;;

  *)
    echo "ERROR: unknown subcommand '$SUBCOMMAND' (expected get|set|list)" >&2
    exit 2
    ;;
esac
