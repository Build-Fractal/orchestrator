#!/usr/bin/env bash
# unattended-deny-probe.sh -- M046/P01/T01 THROWAWAY SPIKE (#Q-1 probe).
#
# Default-DENY PreToolUse hook probe. NOT a production surface -- the
# production hook is P05's deliverable. This probe answers: does a
# deny-unless-allowlisted policy work through the real Claude Code hook
# contract (stdin JSON -> exit 0 pass / exit 2 deny + stderr reason)?
#
# Contract (mirrors scripts/hooks/pre-bash-shape-guard.sh conventions):
#   - Reads the full hook JSON from stdin (single cat).
#   - Extracts tool_name; for Bash, tool_input.command; for Write/Edit/
#     NotebookEdit, tool_input.file_path -- via sed string extraction.
#     No jq. No process substitution. Bash 3.2 compatible.
#   - Policy read from the file pointed at by $DENY_PROBE_POLICY, one
#     directive per line:
#       allow_path <prefix>   -- Write/Edit/NotebookEdit file_path prefix
#       allow_tool <name>     -- exact-match MCP tool allowlist
#       allow_bash <regex>    -- ERE matched against the Bash command
#   - Policy semantics:
#       mcp__*                 -> DENY unless allow_tool matches exactly
#       Write|Edit|NotebookEdit-> DENY unless file_path starts with an
#                                 allow_path prefix
#       Bash                   -> PASS if an allow_bash regex matches;
#                                 else DENY on `git push`, `curl`, or
#                                 `rm -rf` outside an allow_path prefix;
#                                 else pass (probe scope per T01 plan)
#       Read|Glob|Grep         -> pass (read-class, always)
#       anything else          -> pass (per T01 plan step 2)
#   - Fail-closed: absent/unreadable policy file -> DENY everything
#     except read-class tools (reason: policy-missing). Unparseable
#     payload (empty stdin / no tool_name) -> DENY (default-DENY spirit).
#   - DENY = one-line reason on stderr + exit 2. PASS = empty stdout,
#     exit 0.
#
# JSON-escape note: this probe does only minimal unescaping (\" -> ")
# of extracted strings. Fixture payloads are simple; the production P05
# hook must inherit the shape-guard's full unescape pass.

set -u

deny() {
  # $* = "<tool> <detail>" -- emitted in the T01-specified reason shape.
  printf 'DENY_PROBE: %s not in allowlist\n' "$*" >&2
  exit 2
}

# -----------------------------------------------------------------------------
# Read stdin (Claude Code's hook JSON). Fail closed on empty payload.
# -----------------------------------------------------------------------------

STDIN_JSON="$(cat)"
if [ -z "$STDIN_JSON" ]; then
  deny "unknown-tool empty-hook-payload"
fi

FLAT="$(printf '%s' "$STDIN_JSON" | tr '\n' ' ')"

TOOL_NAME="$(printf '%s' "$FLAT" \
  | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -1)"

if [ -z "$TOOL_NAME" ]; then
  deny "unknown-tool tool_name-unparseable"
fi

# -----------------------------------------------------------------------------
# Read-class tools always pass -- even under fail-closed policy-missing.
# -----------------------------------------------------------------------------

case "$TOOL_NAME" in
  Read|Glob|Grep)
    exit 0
    ;;
esac

# -----------------------------------------------------------------------------
# Policy file. Fail closed when absent or unreadable.
# -----------------------------------------------------------------------------

POLICY_FILE="${DENY_PROBE_POLICY:-}"
if [ -z "$POLICY_FILE" ] || [ ! -r "$POLICY_FILE" ]; then
  deny "$TOOL_NAME policy-missing (fail-closed)"
fi

# allow_tool_match <tool-name> -> 0 if an allow_tool directive matches exactly
allow_tool_match() {
  while IFS= read -r _line; do
    case "$_line" in
      "allow_tool "*)
        _val="${_line#allow_tool }"
        if [ "$1" = "$_val" ]; then
          return 0
        fi
        ;;
    esac
  done < "$POLICY_FILE"
  return 1
}

# allow_path_match <path> -> 0 if <path> starts with an allow_path prefix
allow_path_match() {
  while IFS= read -r _line; do
    case "$_line" in
      "allow_path "*)
        _val="${_line#allow_path }"
        case "$1" in
          "$_val"*)
            return 0
            ;;
        esac
        ;;
    esac
  done < "$POLICY_FILE"
  return 1
}

# allow_bash_match <command> -> 0 if an allow_bash ERE matches the command
allow_bash_match() {
  while IFS= read -r _line; do
    case "$_line" in
      "allow_bash "*)
        _val="${_line#allow_bash }"
        if printf '%s' "$1" | grep -Eq "$_val"; then
          return 0
        fi
        ;;
    esac
  done < "$POLICY_FILE"
  return 1
}

# -----------------------------------------------------------------------------
# Per-tool policy dispatch
# -----------------------------------------------------------------------------

case "$TOOL_NAME" in

  mcp__*)
    if allow_tool_match "$TOOL_NAME"; then
      exit 0
    fi
    deny "$TOOL_NAME mcp-tool"
    ;;

  Write|Edit|NotebookEdit)
    FILE_PATH="$(printf '%s' "$FLAT" \
      | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
      | head -1)"
    if [ -z "$FILE_PATH" ]; then
      deny "$TOOL_NAME file_path-unparseable"
    fi
    if allow_path_match "$FILE_PATH"; then
      exit 0
    fi
    deny "$TOOL_NAME $FILE_PATH"
    ;;

  Bash)
    RAW_CMD="$(printf '%s' "$FLAT" \
      | sed -E -n 's/.*"tool_input"[[:space:]]*:[[:space:]]*\{[^}]*"command"[[:space:]]*:[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' \
      | head -1)"
    if [ -z "$RAW_CMD" ]; then
      deny "Bash command-unparseable"
    fi
    # Minimal unescape (fixtures are simple; see header note).
    CMD="$(printf '%s' "$RAW_CMD" | sed -e 's/\\"/"/g')"

    # Explicit allow_bash regex wins over the dangerous-pattern deny list.
    if allow_bash_match "$CMD"; then
      exit 0
    fi

    case "$CMD" in
      *"git push"*)
        deny "Bash git-push ($CMD)"
        ;;
    esac
    case "$CMD" in
      "curl "*|*" curl "*|*"|curl "*|*";curl "*|*"&curl "*)
        deny "Bash curl ($CMD)"
        ;;
    esac
    if printf '%s' "$CMD" | grep -Eq '(^|[[:space:];&|])rm[[:space:]]+-[a-zA-Z]*rf|(^|[[:space:];&|])rm[[:space:]]+-[a-zA-Z]*fr'; then
      RM_TARGET="$(printf '%s' "$CMD" \
        | sed -n 's/.*rm[[:space:]][[:space:]]*-[a-zA-Z][a-zA-Z]*[[:space:]][[:space:]]*\([^[:space:]]*\).*/\1/p' \
        | head -1)"
      if [ -z "$RM_TARGET" ]; then
        deny "Bash rm-rf target-unparseable ($CMD)"
      fi
      if allow_path_match "$RM_TARGET"; then
        exit 0
      fi
      deny "Bash rm-rf $RM_TARGET"
    fi

    # Non-dangerous Bash passes at probe scope (T01 plan step 2; the
    # production P05 hook decides full Bash default-deny).
    exit 0
    ;;

  *)
    # Everything else passes per T01 plan step 2.
    exit 0
    ;;
esac
