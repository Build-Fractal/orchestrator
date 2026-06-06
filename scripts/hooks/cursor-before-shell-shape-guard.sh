#!/usr/bin/env bash
# scripts/hooks/cursor-before-shell-shape-guard.sh — Cursor beforeShellExecution
# shape-guard (M009 FR-3). The Cursor analog of pre-bash-shape-guard.sh.
#
# Cursor's `beforeShellExecution` hook contract DIFFERS from Claude Code's
# PreToolUse contract (verified live 2026-06-06, see
# .orchestrator/milestones/M009/probe-fixtures/cursor-hook-input.json):
#   - stdin JSON carries the shell command at TOP LEVEL: {"command":"...",
#     "hook_event_name":"beforeShellExecution","cwd":"...",...}
#     (Claude Code nests it at tool_input.command.)
#   - the hook ALLOWS/DENIES by emitting {"permission":"allow"|"deny"|"ask"}
#     on stdout (with optional agentMessage/userMessage), NOT Claude Code's
#     {"hookSpecificOutput":{"permissionDecision":...}} shape.
#
# This wrapper reads Cursor's stdin, classifies the command via the SAME
# shape-classifier library the Claude Code guard uses
# (scripts/verify/lib/shape-classifier.sh), and translates the verdict:
#   allow / ''     -> {"permission":"allow"}                       (exit 0)
#   reject:<class> -> {"permission":"deny", agentMessage:<diag>}    (exit 0)
#   rewrite:<...>  -> {"permission":"deny", agentMessage:<suggest>} (exit 0)
#                     (Cursor's hook cannot transparently rewrite the command
#                      the way Claude Code's updatedInput can, so a rewrite
#                      class becomes a deny-with-suggested-form: the agent
#                      re-issues the corrected command. This is the honest
#                      Tier-A degradation — strictly safe, slightly chattier.)
#
# Fail-OPEN on infrastructure failure (missing/unsourceable classifier, empty
# stdin, unparseable command) — emit {"permission":"allow"} and exit 0. This
# matches the established orchestrator shape-guard philosophy (M028 Finding A:
# "never hard-fail the hook on a missing classifier"): the guard is a
# shape-CORRECTOR, not a security boundary, so a broken guard must not brick
# autonomous runs. The companion hooks.json therefore sets failClosed:false
# (a deliberate divergence from the M009 brief's failClosed:true suggestion,
# rationale recorded in the findings note).
#
# Bash 3.2 compatible. No jq. No process substitution.

set -u

# --- reject_lookup: mirror pre-bash-shape-guard.sh's wrapper/AP mapping ------
reject_lookup() {
  case "$1" in
    nested-cmd-sub)             printf 'run-probe.sh AP-009\n'   ;;
    compound-chain-gt2)         printf 'run-probe.sh AP-009\n'   ;;
    heredoc-with-expansion)     printf 'run-probe.sh AP-008\n'   ;;
    quoted-brace)               printf 'read-range.sh AP-007\n'  ;;
    cmd-sub-in-pattern)         printf 'grep-files.sh AP-010\n'  ;;
    quoted-arg-newline-hash)    printf 'read-range.sh AP-011\n'  ;;
    multiline-quoted-script)    printf 'node-eval.sh AP-012\n'   ;;
    unquoted-brace-glob)        printf 'peek-files.sh AP-013\n'  ;;
    xargs-sh-c-compound-body)   printf 'peek-files.sh AP-014\n'  ;;
    *)                          printf 'run-probe.sh AP-009\n'   ;;
  esac
}

# --- emit allow + exit (the fail-open / passthrough path) --------------------
allow_exit() {
  printf '{"permission":"allow"}\n'
  exit 0
}

# --- Locate classifier (self-relative, mirrors pre-bash-shape-guard.sh) ------
HOOK_DIR_RAW="$(dirname "${BASH_SOURCE[0]}")"
HOOK_DIR="$(cd "$HOOK_DIR_RAW" && pwd -P)"
CLASSIFIER=""
if [ -f "${HOOK_DIR}/shape-classifier.sh" ]; then
  CLASSIFIER="${HOOK_DIR}/shape-classifier.sh"
elif [ -f "${HOOK_DIR}/../verify/lib/shape-classifier.sh" ]; then
  CLASSIFIER="${HOOK_DIR}/../verify/lib/shape-classifier.sh"
fi
[ -n "$CLASSIFIER" ] || allow_exit
[ -f "$CLASSIFIER" ] || allow_exit

# --- Read stdin (Cursor's hook JSON) -----------------------------------------
STDIN_JSON="$(cat)"
[ -n "$STDIN_JSON" ] || allow_exit

# --- Guard: only act on beforeShellExecution events --------------------------
EVENT="$(printf '%s' "$STDIN_JSON" \
  | tr '\n' ' ' \
  | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -1)"
# Empty event name is tolerated (older/edge shapes) — only bail if a NON-shell
# event is explicitly named.
if [ -n "$EVENT" ] && [ "$EVENT" != "beforeShellExecution" ]; then
  allow_exit
fi

# --- Extract the top-level "command" string (JSON-escaped) -------------------
RAW_CMD="$(printf '%s' "$STDIN_JSON" \
  | tr '\n' ' ' \
  | sed -E -n 's/.*"command"[[:space:]]*:[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' \
  | head -1)"
[ -n "$RAW_CMD" ] || allow_exit

# --- Unescape JSON string escapes (identical approach to the CC guard) -------
CMD="$(printf '%s' "$RAW_CMD" | sed -e 's/\\\\/\\\\__BS__\\\\/g')"
CMD="$(printf '%s' "$CMD" \
  | sed -e 's/\\"/"/g' \
        -e 's/\\\//\//g' \
        -e 's/\\t/	/g' \
        -e 's/\\r//g')"
CMD="$(printf '%s' "$CMD" | awk '{gsub(/\\n/, "\n"); print}' | awk 'BEGIN{first=1} {if (!first) printf "\n"; printf "%s", $0; first=0}')"
CMD="$(printf '%s' "$CMD" | sed -e 's/\\\\__BS__\\\\/\\/g')"
[ -n "$CMD" ] || allow_exit

# --- Source the classifier (fail-open on any sourcing failure) ---------------
# shellcheck disable=SC1090
. "$CLASSIFIER" || allow_exit

CLASS="$(classify_command "$CMD" 2>/dev/null || true)"

# --- JSON-escape a string for embedding in agentMessage ----------------------
json_escape() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk 'BEGIN{first=1} {if (!first) printf "\\n"; printf "%s", $0; first=0} END{printf ""}'
}

case "$CLASS" in
  allow|'')
    allow_exit
    ;;
  rewrite:*)
    RESULT="${CLASS#rewrite:}"
    MSG="orchestrator shape-guard: this command shape is auto-corrected under Claude Code but Cursor's hook cannot rewrite in place. Re-issue this exact form instead: ${RESULT}"
    # Emit the structured deny JSON AND exit 2: the live probe (2026-06-06)
    # showed Cursor surfaces the hook's message to the agent on the exit-2
    # path (the JSON-only/exit-0 path blocks but shows a generic message).
    printf '{"permission":"deny","agentMessage":"%s","userMessage":"shape-guard: use the corrected command form"}\n' "$(json_escape "$MSG")"
    printf '%s\n' "$MSG" >&2
    exit 2
    ;;
  reject:*)
    PATTERN_CLASS="${CLASS#reject:}"
    LOOKUP="$(reject_lookup "$PATTERN_CLASS")"
    WRAPPER="$(printf '%s' "$LOOKUP" | awk '{print $1}')"
    AP_ID="$(printf '%s' "$LOOKUP" | awk '{print $2}')"
    # Em dash (U+2014) to match the CC guard's diagnostic verbatim.
    MSG="$(printf 'REJECT: %s \xe2\x80\x94 use scripts/util/%s instead. See ANTIPATTERNS.md#%s.' "$PATTERN_CLASS" "$WRAPPER" "$AP_ID")"
    printf '{"permission":"deny","agentMessage":"%s","userMessage":"%s"}\n' "$(json_escape "$MSG")" "$(json_escape "$MSG")"
    # stderr + exit 2 so Cursor surfaces the diagnostic to the agent (verbatim
    # parity with pre-bash-shape-guard.sh, which also writes the REJECT line to
    # stderr and exits 2).
    printf '%s\n' "$MSG" >&2
    exit 2
    ;;
  *)
    # Unknown classifier output — passthrough defensively (fail-open).
    allow_exit
    ;;
esac
