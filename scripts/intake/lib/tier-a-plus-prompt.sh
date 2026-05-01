#!/usr/bin/env bash
# scripts/intake/lib/tier-a-plus-prompt.sh -- M031 P02 T03
#
# AD-7 + AD-20 Tier A+ approval prompt -- the single load-bearing UX
# surface for the entire Tier A+ middle flow. Fires once between the
# research dispatch and the plan dispatch (AD-7 one-prompt convention).
#
# Sourceable + directly invokable.
#
# CLI surface:
#   bash scripts/intake/lib/tier-a-plus-prompt.sh \
#       --research-path .orchestrator/tier-a-plus/<slug>/research.md \
#       --task-slug <slug> \
#       [--yes] \
#       [--session-id <id>] \
#       [--no-prompt-mode y|n|c]
#
# Exit codes:
#   0 = proceed to plan dispatch (operator pressed y, OR --yes was passed).
#   1 = re-run research with different framing (operator pressed n).
#   2 = abort flow (operator pressed c OR timeout/EOF/empty-line; default).
#
# AD-20 mechanical contract (the SC-16 acceptance test asserts each clause):
#
#   1. Plain-language framing -- the prompt body does NOT contain the
#      literal token null, the brace characters that delimit JSON
#      objects, nor the scaffold-placeholder marker byte pattern from
#      CON-7 (the seven-character token starting with the open-bracket
#      character followed by T O D O colon space). Reads like a
#      colleague handing off, not a CLI status line.
#   2. Inline research summary -- the first N lines of research.md are
#      rendered directly in the prompt body, where N is the active
#      config value of `tier_a_plus_prompt_summary_lines` (P00 default
#      8). The lines render verbatim with no truncation or reflow.
#   3. Three named single-keystroke options (y / n / c) with the
#      default-on-no-answer = c (timeout / EOF / empty-line all map to
#      cancel).
#   4. Ellipsis line `(M more lines at <path>)` when research.md
#      exceeds the inline summary budget. The literal numeric M MUST
#      equal `(total_lines - inline_lines)` exactly.
#   5. Resume-vs-rerun marker -- when invoked against a research.md
#      already on disk before this Tier A+ session began (detected via
#      the `.session-id` sidecar mismatch), the prompt prefix MUST
#      include `[resume from prior research]`. When the sidecar
#      matches the current session, it MUST include
#      `[fresh research from this session]`. Operator never wonders
#      which they are looking at.
#   6. --yes skip -- no interactive prompt fires; instead a single
#      `research: <path>` audit line emits to stderr and the helper
#      exits 0 (proceed to plan dispatch).
#   7. Path emission discipline -- the research findings path emits
#      regardless of mode. Interactive: embedded in body + ellipsis.
#      --yes: dedicated stderr audit line.
#
# Bash 3.2 compatible (MEM001): no `declare -A`, no process
# substitution, no `$()` containing pipes inside conditionals.
#
# CON-7 token hygiene: this file MUST NOT embed the scaffold-placeholder
# bracket-TODO byte pattern. Any reference to that pattern is
# paraphrased above.

# Default config knob value when the active config layer is silent.
TIER_A_PLUS_PROMPT_DEFAULT_SUMMARY_LINES=8

# _tap_read_summary_lines <project-root>
#   Echoes the active value of tier_a_plus_prompt_summary_lines from
#   `.orchestrator/config.yml` if present, else the
#   `templates/orchestrator-config-default.yml` extension default.
#   Falls through to the hardcoded P00 default of 8 when neither
#   layer carries a value.
#
#   Direct YAML scan via grep + sed (mirrors read_yaml_value in
#   scripts/state/read-config.sh; that script's VALID_KEYS list does
#   not yet whitelist this knob, so we resolve directly from the
#   config files and follow the same 4-layer precedence pattern).
_tap_read_summary_lines() {
    _tap_root="$1"
    _tap_local_cfg="$_tap_root/.orchestrator/config.yml"
    _tap_default_cfg="$_tap_root/templates/orchestrator-config-default.yml"
    _tap_val=""
    if [ -f "$_tap_local_cfg" ]; then
        _tap_val=$(grep '^tier_a_plus_prompt_summary_lines:' "$_tap_local_cfg" 2>/dev/null | head -1 | sed 's/^tier_a_plus_prompt_summary_lines:[[:space:]]*//' | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//')
    fi
    if [ -z "$_tap_val" ] && [ -f "$_tap_default_cfg" ]; then
        _tap_val=$(grep '^tier_a_plus_prompt_summary_lines:' "$_tap_default_cfg" 2>/dev/null | head -1 | sed 's/^tier_a_plus_prompt_summary_lines:[[:space:]]*//' | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//')
    fi
    if [ -z "$_tap_val" ]; then
        _tap_val="$TIER_A_PLUS_PROMPT_DEFAULT_SUMMARY_LINES"
    fi
    # Sanity: must be a positive integer.
    case "$_tap_val" in
        ''|*[!0-9]*)
            _tap_val="$TIER_A_PLUS_PROMPT_DEFAULT_SUMMARY_LINES"
            ;;
    esac
    printf '%s' "$_tap_val"
}

# _tap_resume_marker <research-path> <session-id>
#   Echoes `[fresh research from this session]` when the .session-id
#   sidecar adjacent to research.md matches the supplied --session-id;
#   echoes `[resume from prior research]` otherwise. The sidecar is
#   written by T04's router on first invocation per session per
#   <task-slug>; when missing we treat the research as pre-existing
#   (correct default -- no session was active when research.md was
#   first authored).
_tap_resume_marker() {
    _tap_research="$1"
    _tap_session="$2"
    _tap_dir=$(dirname "$_tap_research")
    _tap_sidecar="$_tap_dir/.session-id"
    if [ -n "$_tap_session" ] && [ -f "$_tap_sidecar" ]; then
        _tap_sidecar_val=$(awk 'NR==1 {print; exit}' "$_tap_sidecar" 2>/dev/null || true)
        if [ "$_tap_sidecar_val" = "$_tap_session" ]; then
            printf '%s' "[fresh research from this session]"
            return 0
        fi
    fi
    printf '%s' "[resume from prior research]"
}

# _tap_emit_audit <path>
#   Single-line stderr audit emission. Used in --yes mode and once at
#   the top of the interactive prompt body so the path is greppable
#   either way.
_tap_emit_audit() {
    printf 'research: %s\n' "$1" >&2
}

# _tap_emit_prompt_body <marker> <research-path> <inline-text> <remaining>
#   Emits the operator-facing prompt prose to stdout. All printf calls
#   in this function emit literal English; the only dynamic values
#   substituted are <marker>, <research-path>, <inline-text>, and the
#   numeric <remaining>. The shape verifier extracts this region by
#   the BEGIN/END sentinels below and asserts the literal byte
#   patterns disallowed by AD-20 clause 1 do not appear here.
_tap_emit_prompt_body() {
    _tap_b_marker="$1"
    _tap_b_path="$2"
    _tap_b_inline="$3"
    _tap_b_remaining="$4"
    # BEGIN PROMPT BODY
    printf '%s\n' "$_tap_b_marker"
    printf 'Tier A+ research findings: %s\n' "$_tap_b_path"
    printf '\n'
    printf '%s' "$_tap_b_inline"
    if [ "$_tap_b_remaining" -gt 0 ]; then
        printf '(%d more lines at %s)\n' "$_tap_b_remaining" "$_tap_b_path"
    fi
    printf '\n'
    printf 'What now?\n'
    printf '  (y) plan against this research\n'
    printf '  (n) re-run research with different framing\n'
    printf '  (c) abort this Tier A+ flow\n'
    printf '> '
    # END PROMPT BODY
}

# Public CLI entry point. When this file is sourced the function is
# exposed; when invoked directly the bottom-of-file dispatcher calls
# it with the script's argv.
tier_a_plus_prompt() {
    _tap_research_path=""
    _tap_task_slug=""
    _tap_yes=0
    _tap_session_id=""
    _tap_no_prompt_mode=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --research-path)
                _tap_research_path="$2"; shift 2 ;;
            --task-slug)
                _tap_task_slug="$2"; shift 2 ;;
            --yes)
                _tap_yes=1; shift ;;
            --session-id)
                _tap_session_id="$2"; shift 2 ;;
            --no-prompt-mode)
                _tap_no_prompt_mode="$2"; shift 2 ;;
            *)
                printf 'tier-a-plus-prompt: unknown argument %s\n' "$1" >&2
                return 64
                ;;
        esac
    done

    if [ -z "$_tap_research_path" ]; then
        printf 'tier-a-plus-prompt: --research-path is required\n' >&2
        return 64
    fi
    if [ -z "$_tap_task_slug" ]; then
        printf 'tier-a-plus-prompt: --task-slug is required\n' >&2
        return 64
    fi
    if [ ! -f "$_tap_research_path" ]; then
        printf 'tier-a-plus-prompt: research.md not found at %s\n' \
            "$_tap_research_path" >&2
        return 65
    fi

    # --yes: skip the interactive prompt; emit the audit line and
    # return 0 (proceed to plan dispatch).
    if [ "$_tap_yes" -eq 1 ]; then
        _tap_emit_audit "$_tap_research_path"
        return 0
    fi

    # Resolve project root from this file's location so
    # _tap_read_summary_lines reads the active config layer
    # regardless of caller cwd.
    _tap_self="${BASH_SOURCE[0]:-}"
    if [ -z "$_tap_self" ]; then
        _tap_self="$0"
    fi
    _tap_self_dir=$(cd "$(dirname "$_tap_self")" && pwd)
    _tap_root=$(cd "$_tap_self_dir/../../.." && pwd)

    _tap_inline=$(_tap_read_summary_lines "$_tap_root")
    _tap_total=$(awk 'END {print NR}' "$_tap_research_path")
    if [ -z "$_tap_total" ]; then
        _tap_total=0
    fi

    _tap_marker=$(_tap_resume_marker "$_tap_research_path" "$_tap_session_id")

    # Audit line on stderr regardless of mode (path emission discipline,
    # AD-20 clause 7). The interactive body emits the same path on
    # stdout for human visibility; stderr is the machine-greppable
    # audit trail and stays present in both --yes and interactive
    # paths.
    _tap_emit_audit "$_tap_research_path"

    _tap_remaining=$(( _tap_total - _tap_inline ))
    _tap_inline_text=$(awk -v n="$_tap_inline" 'NR<=n {print}' "$_tap_research_path")
    # Trailing newline: command substitution strips final newline; add one
    # so the inline block ends cleanly before the optional ellipsis.
    _tap_inline_text="$_tap_inline_text
"
    _tap_emit_prompt_body "$_tap_marker" "$_tap_research_path" \
        "$_tap_inline_text" "$_tap_remaining"

    # Test-only --no-prompt-mode bypass for environments that cannot
    # drive `read` reliably. The SC-16 test exercises every other UX
    # clause via this bypass; the interactive `read` path stays the
    # production default.
    if [ -n "$_tap_no_prompt_mode" ]; then
        _tap_ans="$_tap_no_prompt_mode"
    else
        # 60-second timeout; bash 3.2 supports `read -t`. Empty / EOF /
        # timeout all collapse to the `c` cancel default.
        _tap_ans=""
        if read -r -n 1 -t 60 _tap_ans; then
            :
        else
            _tap_ans=""
        fi
    fi

    case "$_tap_ans" in
        y|Y) return 0 ;;
        n|N) return 1 ;;
        c|C|'') return 2 ;;
        *) return 2 ;;
    esac
}

# Direct-invocation dispatcher. When the file is sourced, BASH_SOURCE
# differs from $0 and we skip the call so callers source freely.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    tier_a_plus_prompt "$@"
    exit $?
fi
