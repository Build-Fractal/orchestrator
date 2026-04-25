#!/usr/bin/env bash
# scripts/knowledge/lib/decision-history.sh — FR-7 + OQ-2 helper consumed by
# scripts/knowledge/graduate.sh (P03 cluster-aware extension).
#
# Provides:
#   dh_resolve_operator              -> echoes operator identity (one line)
#   dh_emit_jsonl <event> <kv>...    -> appends a JSONL record to
#                                       $ORCH_ROOT/execution-log.jsonl
#
# Pure helpers — neither writes to knowledge/**. Frontmatter mutation flows
# through scripts/knowledge/lib/frontmatter.sh::fm_append_decision_history
# directly from graduate.sh.
#
# Bash 3.2 compatible. AD-19 single-script-invocation shape (no inline
# compounds in any callable surface). MEM001 prefixed-output conventions.

# --- Double-source guard ---
[ -n "${_DECISION_HISTORY_HELPER_SOURCED:-}" ] && return 0
_DECISION_HISTORY_HELPER_SOURCED=1

# --- Operator identity resolver (OQ-2) ---
# Order: git config user.email -> preferences.yml:operator_identifier
#        -> unknown@local
# Pure read — never writes.
dh_resolve_operator() {
  local email
  email="$(git config user.email 2>/dev/null || true)"
  if [ -n "$email" ]; then
    printf '%s\n' "$email"
    return 0
  fi

  local prefs_file=".orchestrator/preferences.yml"
  if [ -f "$prefs_file" ]; then
    local pref_val
    pref_val="$(awk '
      /^operator_identifier:[[:space:]]/ {
        sub(/^operator_identifier:[[:space:]]*/, "")
        sub(/[[:space:]]+$/, "")
        sub(/^"/, ""); sub(/"$/, "")
        print
        exit
      }
    ' "$prefs_file" 2>/dev/null || true)"
    if [ -n "$pref_val" ]; then
      printf '%s\n' "$pref_val"
      return 0
    fi
  fi

  printf '%s\n' "unknown@local"
}

# --- JSONL record emitter ---
# Usage: dh_emit_jsonl <event-type> <key1>=<val1> [<key2>=<val2> ...]
#
# Appends a single JSON object on its own line to
#   ${ORCH_ROOT:-.orchestrator}/execution-log.jsonl
#
# The record always carries a top-level event="<type>" + timestamp=<ISO 8601 UTC>
# + milestone=<active-milestone-id-or-empty>; remaining key=value pairs are
# inlined as JSON string values. Values are not type-coerced (everything is
# emitted as a JSON string) — keep it simple per Principle XIV.
#
# JSON escaping is conservative: backslashes and double-quotes inside values
# are escaped; control chars are passed through (we never put them in any
# value supplied by graduate.sh, which only emits ASCII rationale-hashes and
# entry-IDs).
dh_emit_jsonl() {
  local event="$1"
  shift
  local orch_root="${ORCH_ROOT:-.orchestrator}"
  local log_file="$orch_root/execution-log.jsonl"
  mkdir -p "$orch_root" 2>/dev/null || true

  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Resolve active milestone (best effort — empty string if not derivable).
  local milestone=""
  if [ -f "$orch_root/active-milestone" ]; then
    milestone="$(cat "$orch_root/active-milestone" 2>/dev/null || true)"
  fi

  # Build the JSON object body. Conservative escaping: backslash + double-quote.
  local body
  body="$(printf '"event":"%s","timestamp":"%s","milestone":"%s"' \
    "$(_dh_json_escape "$event")" \
    "$(_dh_json_escape "$timestamp")" \
    "$(_dh_json_escape "$milestone")")"

  local kv key val esc_val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    esc_val="$(_dh_json_escape "$val")"
    body="$body,\"$key\":\"$esc_val\""
  done

  printf '{%s}\n' "$body" >>"$log_file"
}

# --- Internal: minimal JSON string escaping ---
_dh_json_escape() {
  local s="$1"
  # Escape backslash first so the next sed does not double-escape.
  s="$(printf '%s' "$s" | sed 's/\\/\\\\/g')"
  s="$(printf '%s' "$s" | sed 's/"/\\"/g')"
  printf '%s' "$s"
}
