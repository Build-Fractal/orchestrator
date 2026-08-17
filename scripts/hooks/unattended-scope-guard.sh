#!/usr/bin/env bash
# scripts/hooks/unattended-scope-guard.sh -- M046/P05 PreToolUse scope guard.
#
# Framework-owned, default-DENY PreToolUse hook for the self-continuing
# UNATTENDED child (FR-9 / FR-20; Decisions D017 / D018 / D019). It is the
# productionization of the M046/P01 throwaway probe
# (.orchestrator/milestones/M046/phases/P01/spike/hook/unattended-deny-probe.sh):
# same stdin -> exit-0-pass / exit-2-deny contract, same jq-free Bash 3.2 sed
# string extraction, plus exactly four production changes:
#
#   1. Env-gate (D017). The FIRST executable statement after `set -u` is an
#      exit 0 unless ORCHESTRATOR_UNATTENDED is set. In the operator's
#      interactive session that variable is unset, so the hook is a pure
#      fast no-op and NEVER constrains attended work. Only the driver-spawned
#      unattended child exports ORCHESTRATOR_UNATTENDED=1, so only that child
#      is enforced against.
#   2. Policy env var (D018). The allowlist path is read from
#      ORCHESTRATOR_UNATTENDED_POLICY (not the probe's DENY_PROBE_POLICY).
#      Empty/unreadable => fail closed (deny all except read-class tools).
#   3. readonly_path directive (FR-20 / CON-7). A new policy directive marks a
#      protected "scoring" surface (SC definitions, verification harness, the
#      guard machinery itself, the roadmap/plan/attempts-ledger added per-run
#      by the driver). Edit / NotebookEdit on it is denied unconditionally;
#      Write is denied when the target already exists (overwrite = gaming) but
#      PASSED when the target does not yet exist (the child may CREATE a new
#      verifier, but may never MUTATE the harness/SC/scoring surface). This is
#      the doing-vs-scoring seam.
#   4. Reason prefix + expanded Bash denylist. Deny reasons carry the
#      `UNATTENDED_SCOPE_GUARD:` prefix. The Bash dangerous-class denylist
#      widens the probe's lone `curl` to the network family (curl / wget / nc /
#      ncat / ssh / scp / sftp / telnet) and keeps `git push` + `rm -rf`
#      outside allow_path. `allow_bash <ERE>` still wins over the denylist.
#
# Policy directive vocabulary (one per line in the ORCHESTRATOR_UNATTENDED_POLICY
# file; `#` starts a comment):
#   allow_path <abs-prefix>     Write/Edit/NotebookEdit file_path prefix (writable)
#   readonly_path <abs-prefix>  protected surface: deny Edit; deny Write-if-exists
#   allow_tool <exact-name>     exact-match mcp__* allowlist (absent => deny all mcp__*)
#   allow_bash <ERE>            Bash command allowlist regex (wins over denylist)
#
# Policy semantics:
#   mcp__*                  -> DENY unless an exact allow_tool matches (D019)
#   Write|Edit|NotebookEdit -> readonly_path checked FIRST (see FR-20 above),
#                              then DENY unless file_path starts with allow_path
#   Bash                    -> PASS if allow_bash matches; else DENY on
#                              `git push`, the network family, or `rm -rf`
#                              outside allow_path; else pass (enumerated-class
#                              deny, not blanket Bash deny)
#   Read|Glob|Grep          -> pass (read-class, always -- even fail-closed)
#   anything else           -> pass
#
# Fail-closed: absent/unreadable policy, empty stdin, or unparseable tool_name
# => DENY (except read-class). DENY = one-line stderr reason + exit 2.
#
# Conventions mirror scripts/hooks/pre-bash-shape-guard.sh: self-contained (no
# sourcing), `set -u`, exit 2 = deny with stderr reason. Bash 3.2 compatible:
# no `declare -A`, no process substitution, sed/grep/case only, no jq.

set -u

# -----------------------------------------------------------------------------
# Env-gate (D017) -- FIRST executable statement. Attended = pure no-op.
# -----------------------------------------------------------------------------

if [ -z "${ORCHESTRATOR_UNATTENDED:-}" ]; then
  exit 0
fi

deny() {
  # $* = "<tool> <detail>" -- UNATTENDED_SCOPE_GUARD reason shape.
  printf 'UNATTENDED_SCOPE_GUARD: %s not in allowlist\n' "$*" >&2
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
# Policy file (D018). Fail closed when absent or unreadable.
# -----------------------------------------------------------------------------

POLICY_FILE="${ORCHESTRATOR_UNATTENDED_POLICY:-}"
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

# readonly_path_match <path> -> 0 if <path> starts with a readonly_path prefix
readonly_path_match() {
  while IFS= read -r _line; do
    case "$_line" in
      "readonly_path "*)
        _val="${_line#readonly_path }"
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
    # D019: default-DENY every mcp__* unless an exact allow_tool names it.
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

    # FR-20 / CON-7: readonly_path checked BEFORE allow_path (doing-vs-scoring).
    if readonly_path_match "$FILE_PATH"; then
      case "$TOOL_NAME" in
        Edit|NotebookEdit)
          deny "$TOOL_NAME readonly-surface $FILE_PATH"
          ;;
        Write)
          if [ -e "$FILE_PATH" ]; then
            deny "Write readonly-overwrite $FILE_PATH"
          fi
          # Write to a not-yet-existing readonly path: fall through to the
          # allow_path check (the child may CREATE a new file there).
          ;;
      esac
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
    # Minimal unescape (fixtures are simple; production install stages this
    # alongside the shape-guard, which owns full unescape for its own path).
    CMD="$(printf '%s' "$RAW_CMD" | sed -e 's/\\"/"/g')"

    # Explicit allow_bash regex wins over the dangerous-class deny list.
    if allow_bash_match "$CMD"; then
      exit 0
    fi

    case "$CMD" in
      *"git push"*)
        deny "Bash git-push ($CMD)"
        ;;
    esac

    # Network family: curl / wget / nc / ncat / ssh / scp / sftp / telnet as a
    # command word (bounded by line-start/whitespace/;&| on the left and
    # whitespace/line-end on the right).
    if printf '%s' "$CMD" | grep -Eq '(^|[[:space:];&|])(curl|wget|nc|ncat|ssh|scp|sftp|telnet)([[:space:]]|$)'; then
      deny "Bash network ($CMD)"
    fi

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

    # Non-dangerous Bash passes: FR-9 denies the enumerated classes, not all
    # Bash.
    exit 0
    ;;

  *)
    # Everything else passes (read-class already handled above).
    exit 0
    ;;
esac
