#!/usr/bin/env bash
# scripts/hooks/pre-bash-shape-guard.sh -- PreToolUse hook for Bash tool calls.
#
# Reads Claude Code's hook JSON from stdin, consults the shape classifier
# library (scripts/verify/lib/shape-classifier.sh), and either:
#   (a) passes through silently (exit 0, empty stdout),
#   (b) emits a rewritten updatedInput JSON (exit 0),
#   (c) hard-rejects with a wrapper-pointing diagnostic (exit 2).
#
# Installed via .claude/settings.json hooks.PreToolUse entry:
#   { "matcher": "Bash", "hooks": [{ "type": "command",
#     "command": "bash scripts/hooks/pre-bash-shape-guard.sh" }] }
#
# Protocol: AD-1a in .orchestrator/milestones/M021/M021-CONTEXT.md
# Matrix:   AD-2 (10 patterns, closed on M011/P05-P07 evidence)
# Bash 3.2 compatible. No jq. No process substitution.

set -u

# -----------------------------------------------------------------------------
# Helpers (defined before any caller)
# -----------------------------------------------------------------------------

# reject_lookup <pattern-class> -> prints "<wrapper.sh> <AP-ID>"
#
# M021 baseline arms (nested-cmd-sub, compound-chain-gt2, heredoc-with-expansion,
# quoted-brace) and the catch-all default are preserved byte-for-byte (CON-7
# strict-superset). M028/P03/T03 appends five new arms for the AP-010..AP-014
# pattern classes T02 added to the classifier; their wrapper basenames
# (grep-files.sh, read-range.sh, node-eval.sh, peek-files.sh) reference
# investigation-class wrappers (read-range.sh ships today; the others are P04
# deliverables). The diagnostic surfaces the AP-ID; ANTIPATTERNS.md#AP-NNN
# carries the operator-facing remedy.
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

# -----------------------------------------------------------------------------
# Locate classifier -- self-relative via BASH_SOURCE (Finding A fix, M028/P02/T01)
#
# The hook resolves the classifier from its own on-disk location only. The
# project-dir env var that older revisions consulted is intentionally retired
# from the resolution logic; it was the project-relative path that did not
# exist in consumer projects, so the hook fell through silently. The hook
# now lives at the runtime-stable ~/.claude/orchestrator-hooks/ dir (M028/P02
# installer) and resolves its sibling classifier from there. The in-tree
# development location (hook at scripts/hooks/, classifier at
# scripts/verify/lib/) is supported via a one-step parent-fallback. On both
# miss, fail open (exit 0) -- never hard-fail the hook on a missing
# classifier; that is the install-roundtrip gate's job.
# -----------------------------------------------------------------------------

HOOK_DIR_RAW="$(dirname "${BASH_SOURCE[0]}")"
HOOK_DIR="$(cd "$HOOK_DIR_RAW" && pwd -P)"
CLASSIFIER=""

if [ -f "${HOOK_DIR}/shape-classifier.sh" ]; then
  CLASSIFIER="${HOOK_DIR}/shape-classifier.sh"
elif [ -f "${HOOK_DIR}/../verify/lib/shape-classifier.sh" ]; then
  CLASSIFIER="${HOOK_DIR}/../verify/lib/shape-classifier.sh"
fi

if [ -z "$CLASSIFIER" ]; then
  exit 0
fi
if [ ! -f "$CLASSIFIER" ]; then
  exit 0
fi

# -----------------------------------------------------------------------------
# Read stdin (Claude Code's hook JSON)
# -----------------------------------------------------------------------------

STDIN_JSON="$(cat)"

if [ -z "$STDIN_JSON" ]; then
  # Empty stdin -- passthrough.
  exit 0
fi

# -----------------------------------------------------------------------------
# Extract tool_name via pure-Bash sed
# -----------------------------------------------------------------------------

TOOL_NAME="$(printf '%s' "$STDIN_JSON" \
  | tr '\n' ' ' \
  | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -1)"

if [ "$TOOL_NAME" != "Bash" ]; then
  # Not our concern -- passthrough.
  exit 0
fi

# -----------------------------------------------------------------------------
# Extract tool_input.command (raw JSON-escaped string)
# -----------------------------------------------------------------------------
# Match `"command":"..."` inside tool_input, where "..." may contain
# escaped quotes (\") and escaped backslashes (\\). The regex class
# \(\\.\|[^"\\]\)* handles both.

RAW_CMD="$(printf '%s' "$STDIN_JSON" \
  | tr '\n' ' ' \
  | sed -E -n 's/.*"tool_input"[[:space:]]*:[[:space:]]*\{[^}]*"command"[[:space:]]*:[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' \
  | head -1)"

if [ -z "$RAW_CMD" ]; then
  # Parse failure or empty command -- passthrough.
  exit 0
fi

# -----------------------------------------------------------------------------
# Unescape JSON string escapes: \\, \", \n, \t, \r, \/
# -----------------------------------------------------------------------------
# Order matters: decode \\ last so we don't double-unescape. Use a unique
# sentinel for \\ to prevent interference with subsequent sed passes.

CMD="$(printf '%s' "$RAW_CMD" \
  | sed -e 's/\\\\/\\\\__BS__\\\\/g')"
# Now \\ in input is represented as \\__BS__\\ temporarily; real sequences
# like \" are still \" (single backslash before the quote).
# Unescape the single-backslash sequences.
CMD="$(printf '%s' "$CMD" \
  | sed -e 's/\\"/"/g' \
        -e 's/\\\//\//g' \
        -e 's/\\t/	/g' \
        -e 's/\\r//g')"
# Replace newline escape: use awk since sed \n handling varies on BSD.
CMD="$(printf '%s' "$CMD" | awk '{gsub(/\\n/, "\n"); print}' | awk 'BEGIN{first=1} {if (!first) printf "\n"; printf "%s", $0; first=0}')"
# Collapse the sentinel back to a single backslash.
CMD="$(printf '%s' "$CMD" | sed -e 's/\\\\__BS__\\\\/\\/g')"

if [ -z "$CMD" ]; then
  # Empty after unescape -- passthrough.
  exit 0
fi

# -----------------------------------------------------------------------------
# Source the classifier (fail-safe: passthrough on any sourcing failure)
# -----------------------------------------------------------------------------

if [ ! -f "$CLASSIFIER" ]; then
  echo "pre-bash-shape-guard.sh: classifier library not found at $CLASSIFIER" >&2
  exit 0
fi

# shellcheck disable=SC1090
. "$CLASSIFIER" || exit 0

# -----------------------------------------------------------------------------
# Classify
# -----------------------------------------------------------------------------

CLASS="$(classify_command "$CMD" 2>/dev/null || true)"

case "$CLASS" in
  allow|'')
    exit 0
    ;;

  rewrite:*)
    RESULT="${CLASS#rewrite:}"
    # JSON-escape the result for emission: backslash first, then quote,
    # then newlines -> \n, tabs -> \t, carriage-returns -> \r.
    ESCAPED="$(printf '%s' "$RESULT" \
      | sed -e 's/\\/\\\\/g' \
            -e 's/"/\\"/g' \
      | awk 'BEGIN{first=1} {if (!first) printf "\\n"; printf "%s", $0; first=0} END{printf ""}')"
    # Emit single-line JSON on stdout. Exit 0.
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"%s"}}}\n' "$ESCAPED"
    exit 0
    ;;

  reject:*)
    PATTERN_CLASS="${CLASS#reject:}"
    LOOKUP="$(reject_lookup "$PATTERN_CLASS")"
    WRAPPER="$(printf '%s' "$LOOKUP" | awk '{print $1}')"
    AP_ID="$(printf '%s' "$LOOKUP" | awk '{print $2}')"
    # Emit the exact US-4 AS2 diagnostic with U+2014 em dash (0xE2 0x80 0x94).
    printf 'REJECT: %s \xe2\x80\x94 use scripts/util/%s instead. See ANTIPATTERNS.md#%s.\n' \
      "$PATTERN_CLASS" "$WRAPPER" "$AP_ID" >&2
    exit 2
    ;;

  *)
    # Unknown classifier output -- passthrough defensively.
    echo "pre-bash-shape-guard.sh: unknown classifier output: $CLASS" >&2
    exit 0
    ;;
esac
