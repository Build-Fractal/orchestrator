#!/usr/bin/env bash
# scripts/knowledge/lib/preferences.sh — FR-6 / US-5 preferences resolution helper.
#
# Provides:
#   pref_resolve <key>
#       Echoes the effective scalar value of <key> on stdout, applying
#       project>user>built-in-default precedence per-key (THREAT-007).
#       Closed-enum keys: default_state_filter, similarity_threshold,
#       staleness_threshold, preferred_cluster_size, operator_identifier.
#       Built-in defaults: graduated, 0.7, 14, 8, unknown@local.
#       Malformed values fall back with a single-line stderr diagnostic;
#       the preferences file is NEVER mutated.
#       Path resolution honors PROJECT_ROOT and HOME env vars for fixture
#       isolation (P01/P02/P05 verifier convention).
#
# Pure read helper — no writes anywhere. AD-19 single-script-invocation safe.
# Bash 3.2 compatible (MEM001). MEM001 prefixed-output conventions.

# --- Double-source guard ---
[ -n "${_PREFERENCES_HELPER_SOURCED:-}" ] && return 0
_PREFERENCES_HELPER_SOURCED=1

# --- Built-in defaults (single source of truth) ---
_PREF_DEFAULT_default_state_filter="graduated"
_PREF_DEFAULT_similarity_threshold="0.7"
_PREF_DEFAULT_staleness_threshold="14"
_PREF_DEFAULT_preferred_cluster_size="8"
_PREF_DEFAULT_operator_identifier="unknown@local"

# --- Closed-enum key vocabulary ---
_pref_is_known_key() {
  case "$1" in
    default_state_filter|similarity_threshold|staleness_threshold|preferred_cluster_size|operator_identifier)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Per-key validators. Return 0 iff $2 is a valid value for key $1. ---
_pref_validate_value() {
  local key="$1"
  local val="$2"
  case "$key" in
    default_state_filter)
      case "$val" in
        candidate|graduated|archived) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    similarity_threshold)
      # Float in [0.0, 1.0]. Accept N, N.NN, .NN forms.
      printf '%s\n' "$val" | awk '
        /^[0-9]+(\.[0-9]+)?$|^\.[0-9]+$/ {
          v = $0 + 0.0
          if (v >= 0.0 && v <= 1.0) { exit 0 } else { exit 1 }
        }
        { exit 1 }
      '
      return $?
      ;;
    staleness_threshold)
      # Int in [1, 365].
      case "$val" in
        ''|*[!0-9]*) return 1 ;;
      esac
      [ "$val" -ge 1 ] && [ "$val" -le 365 ]
      ;;
    preferred_cluster_size)
      # Int in [1, 50].
      case "$val" in
        ''|*[!0-9]*) return 1 ;;
      esac
      [ "$val" -ge 1 ] && [ "$val" -le 50 ]
      ;;
    operator_identifier)
      # Non-empty, no embedded newline or surrounding whitespace.
      [ -n "$val" ] || return 1
      case "$val" in
        ' '*|*' '|*"$(printf '\n')"*) return 1 ;;
      esac
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Read a scalar key from a YAML file (grep+sed; AD-5 strategy). ---
# Echoes the raw scalar on stdout if found; empty stdout + return 1 if absent.
# Strips surrounding whitespace and surrounding single/double quotes.
_pref_read_scalar() {
  local file="$1"
  local key="$2"
  [ -f "$file" ] || return 1
  local raw
  raw="$(grep -E "^${key}:[[:space:]]" "$file" 2>/dev/null | head -1 \
    | sed -E "s/^${key}:[[:space:]]*//; s/[[:space:]]*\$//; s/^['\"]//; s/['\"]\$//")"
  [ -n "$raw" ] || return 1
  printf '%s\n' "$raw"
  return 0
}

# --- Resolve the project preferences path (PROJECT_ROOT-aware). ---
_pref_project_path() {
  local root
  if [ -n "${PROJECT_ROOT:-}" ]; then
    root="$PROJECT_ROOT"
  else
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  fi
  printf '%s/.orchestrator/preferences.yml\n' "$root"
}

# --- Resolve the user preferences path (HOME-aware). ---
_pref_user_path() {
  printf '%s/.orchestrator/preferences.yml\n' "${HOME:-/tmp}"
}

# --- Try one source: read scalar, validate, echo + return 0 OR diagnose + return 1. ---
# Args: <key> <file> <next-source-label-for-diagnostic>
_pref_try_source() {
  local key="$1"
  local file="$2"
  local next="$3"
  local raw
  raw="$(_pref_read_scalar "$file" "$key")" || return 1
  if _pref_validate_value "$key" "$raw"; then
    printf '%s\n' "$raw"
    return 0
  fi
  printf "WARN: pref_resolve: malformed value for '%s' in '%s': '%s' — falling back to %s\n" \
    "$key" "$file" "$raw" "$next" >&2
  return 1
}

# --- Public: pref_resolve <key>. ---
pref_resolve() {
  local key="${1:-}"
  if [ -z "$key" ]; then
    echo "FAIL: pref_resolve: missing key argument" >&2
    return 1
  fi
  if ! _pref_is_known_key "$key"; then
    echo "FAIL: pref_resolve: unknown key '$key'" >&2
    return 1
  fi

  local proj_file user_file
  proj_file="$(_pref_project_path)"
  user_file="$(_pref_user_path)"

  # Step 1: project file (highest precedence).
  _pref_try_source "$key" "$proj_file" "user-or-default" && return 0

  # Step 2: user file.
  _pref_try_source "$key" "$user_file" "default" && return 0

  # Step 3: built-in default.
  local default_var="_PREF_DEFAULT_${key}"
  printf '%s\n' "${!default_var}"
  return 0
}
