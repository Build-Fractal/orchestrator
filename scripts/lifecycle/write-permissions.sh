#!/usr/bin/env bash
# scripts/lifecycle/write-permissions.sh — Agent-host translator for canonical permissions.
#
# AD-9 writer half. AD-13 additive merge for user-authored files. Reads the
# canonical JSON envelope (T02 generator output) and writes the host-specific
# settings file (Claude Code today; other hosts pluggable).
#
# Bash 3.2 compatible (NFR-200). No jq required. Relies on canonical format
# being well-shaped (AD-16).
#
# CRITICAL: AD-13 additive merge only. Never remove user-authored entries.

set -eu

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
INPUT_FILE=""
HOST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --input) INPUT_FILE="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "write-permissions.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

. "$PROJECT_ROOT/scripts/lib/errors.sh"
. "$PROJECT_ROOT/scripts/lib/events.sh"

# --- Read canonical input ---
if [ -z "$INPUT_FILE" ]; then
  INPUT_FILE="$(mktemp -t p07-input.XXXXXX)"
  cat > "$INPUT_FILE"
  trap 'rm -f "$INPUT_FILE"' EXIT
fi

if [ ! -s "$INPUT_FILE" ]; then
  emit_result error IO "input file is empty: $INPUT_FILE"
  exit 1
fi

# --- Host detection ---
if [ -z "$HOST" ]; then
  caps="$(bash "$PROJECT_ROOT/scripts/dispatch/detect-capabilities.sh" 2>/dev/null || true)"
  case "$caps" in
    *host_claude_code=true*) HOST="claude_code" ;;
    *host_cursor=true*) HOST="cursor" ;;
    *host_copilot=true*) HOST="copilot" ;;
    *) HOST="claude_code" ;;  # First-host default: Claude Code (AD-16)
  esac
fi

case "$HOST" in
  claude_code) TARGET="$PROJECT_ROOT/.claude/settings.json" ;;
  cursor) TARGET="$PROJECT_ROOT/.cursor/settings.json" ;;
  copilot) TARGET="$PROJECT_ROOT/.github/copilot/settings.json" ;;
  *)
    emit_result error CONFIG "unknown host: $HOST"
    exit 1
    ;;
esac

# Cursor and copilot hosts are pluggable stubs (per M005 scope: YAGNI until
# a user needs them). Ship them refusing to write with a clear message.
if [ "$HOST" != "claude_code" ]; then
  emit_result error DISPATCH "host '$HOST' is a pluggable stub — only claude_code ships in v0.1"
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"

# --- JSON array helpers ---

# extract_array <file> <key>
# Extracts array entries from a JSON file. Relies on the AD-16 canonical
# shape where arrays are well-formatted with one entry per line.
extract_array() {
  local file="$1"
  local key="$2"
  awk -v k="\"$key\":" '
    $0 ~ k "[[:space:]]*\\[" { in_block=1; next }
    in_block && /^[[:space:]]*\]/ { in_block=0; next }
    in_block && /^[[:space:]]*"[^"]*"/ {
      match($0, /"[^"]*"/)
      print substr($0, RSTART+1, RLENGTH-2)
    }
  ' "$file"
}

# write_array <list> <indent>
# Writes a newline-separated list as JSON array entries.
write_array() {
  local list="$1"
  local indent="$2"
  local sep=""
  local entry
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    printf '%s%s"%s"' "$sep" "$indent" "$entry"
    sep=",
"
  done <<WRITE_EOF
$list
WRITE_EOF
}

# --- Additive merge function (AD-13) ---
# SCOPE: v0.1 merge only covers the permissions block. Other top-level
# Claude Code settings.json fields (hooks, mcpServers, statusLine) are
# NOT preserved by this merge. When merging into a user-authored file
# containing those fields, the writer fails safely (see pre-merge guard
# below) instead of silently dropping them.
merge_additive() {
  local new_file="$1"
  local current="$2"

  # Extract allow array entries from both files.
  local new_allow new_deny cur_allow cur_deny
  new_allow="$(extract_array "$new_file" "allow")"
  new_deny="$(extract_array "$new_file" "deny")"
  cur_allow="$(extract_array "$current" "allow")"
  cur_deny="$(extract_array "$current" "deny")"

  # Append new entries that aren't already in the current set. Preserve
  # the current set's order (AD-13: never reorder user-authored entries).
  merged_allow="$cur_allow"
  merged_deny="$cur_deny"
  local pattern
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    printf '%s\n' "$cur_allow" | grep -Fxq "$pattern" || merged_allow="$(printf '%s\n%s' "$merged_allow" "$pattern")"
  done <<ALLOW_EOF
$new_allow
ALLOW_EOF
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    printf '%s\n' "$cur_deny" | grep -Fxq "$pattern" || merged_deny="$(printf '%s\n%s' "$merged_deny" "$pattern")"
  done <<DENY_EOF
$new_deny
DENY_EOF

  # Rewrite the target file with merged arrays. Preserve everything outside
  # the allow/deny blocks (including defaultMode, comments, markers).
  local tmp
  tmp="$(mktemp -t p07-merge.XXXXXX)"

  # Extract current defaultMode (leave untouched per AD-13)
  local cur_default_mode
  cur_default_mode="$(sed -n 's/.*"defaultMode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$current" | head -1)"
  [ -z "$cur_default_mode" ] && cur_default_mode="default"

  # AD-13: do NOT add _generated_by markers to user-authored files. Only
  # emit a stripped-down permissions object.
  printf '{\n' > "$tmp"
  printf '  "permissions": {\n' >> "$tmp"
  printf '    "defaultMode": "%s",\n' "$cur_default_mode" >> "$tmp"
  printf '    "deny": [\n' >> "$tmp"
  write_array "$merged_deny" "      " >> "$tmp"
  printf '\n    ],\n' >> "$tmp"
  printf '    "allow": [\n' >> "$tmp"
  write_array "$merged_allow" "      " >> "$tmp"
  printf '\n    ]\n' >> "$tmp"
  printf '  }\n' >> "$tmp"
  printf '}\n' >> "$tmp"

  mv "$tmp" "$current"
}

# --- Determine write mode: overwrite vs additive merge ---
# If target exists and contains the _generated_by marker -> orchestrator-generated -> overwrite.
# If target exists and does NOT contain the marker -> user-authored -> additive merge (AD-13).
# If target does not exist -> fresh write.
MODE="fresh"
if [ -f "$TARGET" ]; then
  if grep -q '"_generated_by"[[:space:]]*:[[:space:]]*"speckit-orchestrator"' "$TARGET"; then
    MODE="overwrite"
  else
    MODE="merge"
  fi
fi

# AD-13 safety: refuse to merge into files with top-level fields beyond
# permissions — we would silently destroy them otherwise.
if [ "$MODE" = "merge" ]; then
  if grep -qE '^\s*"(hooks|mcpServers|statusLine|statusLineConfig)"' "$TARGET"; then
    emit_result error IO "user-authored $TARGET contains unsupported top-level fields — refusing merge (v0.1 only handles 'permissions')"
    exit 1
  fi
fi

case "$MODE" in
  fresh)
    # Claude Code's shape IS the canonical shape — passthrough (AD-16).
    cp "$INPUT_FILE" "$TARGET"
    emit_event HOOK_COMPLETE script=write-permissions.sh mode=fresh host="$HOST" target="$TARGET"
    emit_result ok "" "wrote $TARGET in mode=fresh"
    ;;
  overwrite)
    # AD-7: sentinel-scoped overwrite. Replace ONLY the span between
    # _generated_start and _generated_end in TARGET with the span between
    # the same sentinels in INPUT_FILE. Preserve everything outside the
    # span byte-identical so user-added top-level keys (hooks, mcpServers,
    # statusLine) and any manual allow-list additions made outside the
    # generated block survive re-runs.
    if ! grep -q '_generated_start' "$TARGET" || ! grep -q '_generated_end' "$TARGET"; then
      # Legacy file — no sentinels. Fall back to passthrough (pre-AD-7 behavior)
      # but emit a SAFETY_WARNING so operators know this file will get
      # sentinels on next regeneration.
      cp "$INPUT_FILE" "$TARGET"
      emit_event SAFETY_WARNING reason=no_sentinels target="$TARGET" action=passthrough
      emit_result ok "" "wrote $TARGET in mode=overwrite (legacy: no sentinels)"
    else
      bash "$PROJECT_ROOT/scripts/lifecycle/apply-sentinel-overwrite.sh" \
        --target "$TARGET" --input "$INPUT_FILE"
      emit_event HOOK_COMPLETE script=write-permissions.sh mode=overwrite-sentinel host="$HOST" target="$TARGET"
      emit_result ok "" "sentinel-scoped overwrite of $TARGET (AD-7)"
    fi
    ;;
  merge)
    # AD-13: additive merge. Must preserve every entry already in $TARGET.
    merge_additive "$INPUT_FILE" "$TARGET"
    emit_event HOOK_COMPLETE script=write-permissions.sh mode=merge host="$HOST" target="$TARGET"
    emit_result ok "" "merged into user-authored $TARGET (AD-13 additive only)"
    ;;
esac
