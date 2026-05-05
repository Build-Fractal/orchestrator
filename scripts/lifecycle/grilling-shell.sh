#!/usr/bin/env bash
# scripts/lifecycle/grilling-shell.sh
#
# FR-17 reusable conversational-shell module (M033 / 036-project-onboarding-experience).
# CON-5 sequential-never-batched. Sourced (not executed) by P03/P04/P05 calling
# commands; exposes a single uniform public function:
#
#     ask_one <question> <recommendation> [<context-file>]
#
# Recommendation-not-interrogation framing — the recommendation is named FIRST,
# then the question asks the operator to confirm or correct.
#
# Bash 3.2 compatibility (MEM001):
#   - no `declare -A` (associative arrays)
#   - no process substitution `<(...)`
#   - no `$(...)` containing pipes
#
# Sourceability rules:
#   - This module is meant to be `source`-ed. NO top-level `set -e -u -o pipefail`
#     (would corrupt caller settings). NO top-level `exit` calls. All non-success
#     paths use `return <code>`.
#   - Top-level code is limited to function definitions, the fenced SSOT comment
#     blocks, and the trailing direct-execution informational guard.
#
# T03 ships:
#   - ask_one core API + recommendation-not-interrogation framing.
#   - Reserved fenced SSOT comment blocks for T04 to populate.
#   - No-op stubs for _grilling_check_contradiction and _grilling_glossary_update;
#     T04 replaces the stub bodies with real MIT-007 + FR-18 logic in-place.
#
# T04 will populate:
#   - >>> contradiction-pairs >>> SSOT block (closed contradiction-table entries).
#   - >>> glossary-triggers >>> SSOT block (closed glossary-trigger key set).
#   - Real bodies for _grilling_check_contradiction (MIT-007) and
#     _grilling_glossary_update (FR-18).
#   - SC-11 acceptance script.
#
# T04 reads caller-set bash vars _GRILLING_CURRENT_QKEY and
# _GRILLING_CURRENT_DEFINITION (set by callers before invoking ask_one) when
# resolving glossary triggers.

# >>> grilling-protocol-rules >>>
# 1. Sequential never batched (CON-5 hard architectural invariant).
# 2. Code-first speculation cap — calling commands MUST read project
#    state (manifests, directory structure, prior answers) before
#    invoking ask_one. ask_one is a library function; calling
#    commands enforce this convention.
# 3. Inline doc updates — when ask_one resolves a domain term, the
#    glossary writer fires immediately (T04 deliverable).
# 4. Surface contradictions live — when ask_one is invoked with a
#    [<context-file>] the contradiction detector fires before
#    returning success (T04 deliverable per MIT-007).
# Plus: recommendation-not-interrogation — recommendation named
# first, then the question asks for confirm-or-correct.
# <<< grilling-protocol-rules <<<

# >>> contradiction-pairs >>>
# Format: question-key:value-a:value-b — answers a and b are mutually
# exclusive when both appear under the same question-key in the
# accumulator. v1 ships the minimal set; expand demand-driven.
# Calling commands MUST set _GRILLING_CURRENT_QKEY before invoking
# ask_one for contradiction detection to fire.
_GRILLING_CONTRADICTION_PAIRS="target-user:consumer:enterprise
target-user:consumer:internal-tools-only
target-user:enterprise:internal-tools-only
deployment-target:serverless:self-hosted-vm
deployment-target:serverless:kubernetes
deployment-target:self-hosted-vm:kubernetes
auth-model:passwordless:password-required
auth-model:passwordless:sso-only
auth-model:password-required:sso-only"
# <<< contradiction-pairs <<<

# >>> glossary-triggers >>>
# Question-keys that, when answered via ask_one, trigger an
# immediate write to <PROJECT_DIR>/wiki/glossary.md per FR-18.
# v1 ships the minimal set; expand demand-driven.
_GRILLING_GLOSSARY_TRIGGERS="domain-term-defined
acronym-resolved
convention-named
framework-chosen"
# <<< glossary-triggers <<<

# ----------------------------------------------------------------------------
# ask_one — the FR-17 public API.
#
# Args:
#   $1  question        (required)  The question text printed after the
#                                   recommendation.
#   $2  recommendation  (required)  The recommended answer; named FIRST.
#   $3  context-file    (optional)  Path to a context file consulted by the
#                                   MIT-007 contradiction detector. T03 ships
#                                   a no-op stub; T04 implements the wiring.
#
# Behavior:
#   - Prints `recommendation: <recommendation>` to stdout (load-bearing token).
#   - Prints the question with one-keystroke prompt `[Y/n/<answer>]: ` to stdout.
#   - Reads exactly ONE line of stdin via `read -r` (CON-5 sequential).
#   - One-keystroke contract:
#       Y / y / <enter>  -> accept the recommendation
#       N / n            -> request explicit answer (re-prompts via stderr)
#       *                -> treat input as the explicit operator-supplied answer
#   - Echoes the resolved answer on a single line `answer: <value>` to stdout
#     (the load-bearing token for downstream tests).
#   - Returns 0 on success, 2 on bad usage / no explicit answer supplied.
#
# Returns:
#   0  resolved answer printed.
#   2  missing required arg, or `n`-branch with empty explicit answer.
# ----------------------------------------------------------------------------
ask_one() {
    local question="${1:-}"
    local recommendation="${2:-}"
    local context_file="${3:-}"

    if [ -z "$question" ] || [ -z "$recommendation" ]; then
        echo "ask_one: question and recommendation are required" >&2
        echo "usage: ask_one <question> <recommendation> [<context-file>]" >&2
        return 2
    fi

    # Recommendation-not-interrogation framing — recommendation FIRST.
    printf 'recommendation: %s\n' "$recommendation"
    printf '%s [Y/n/<answer>]: ' "$question"

    local input=""
    # Sequential read of one line (CON-5).
    IFS= read -r input || input=""

    local resolved=""
    case "$input" in
        ""|Y|y)
            resolved="$recommendation"
            ;;
        N|n)
            printf 'enter explicit answer: ' >&2
            IFS= read -r resolved || resolved=""
            if [ -z "$resolved" ]; then
                echo "no explicit answer provided" >&2
                return 2
            fi
            ;;
        *)
            resolved="$input"
            ;;
    esac

    # MIT-007 contradiction-detection wiring. Only fires when caller supplied a
    # context-file. Returns 2 on re-prompt request; 0 on no-contradiction or on
    # accept-with-attestation.
    if [ -n "$context_file" ]; then
        _grilling_check_contradiction "$resolved" "$context_file"
        local rc=$?
        if [ "$rc" -eq 2 ]; then
            # Single retry: re-prompt the operator for an alternative answer.
            printf 'reprompt: enter alternative answer: ' >&2
            local alt=""
            IFS= read -r alt || alt=""
            if [ -z "$alt" ]; then
                printf 'contradiction-unresolved: empty alternative\n' >&2
                return 3
            fi
            resolved="$alt"
            _grilling_check_contradiction "$resolved" "$context_file"
            local rc2=$?
            if [ "$rc2" -eq 2 ]; then
                printf 'contradiction-unresolved: second contradiction on retry\n' >&2
                return 3
            elif [ "$rc2" -ne 0 ]; then
                return "$rc2"
            fi
        elif [ "$rc" -ne 0 ]; then
            return "$rc"
        fi
    fi

    # FR-18 glossary inline-update writer. Reads caller-set
    # _GRILLING_CURRENT_QKEY / _GRILLING_CURRENT_DEFINITION.
    _grilling_glossary_update "$question" "$resolved"

    # Append the resolved answer to the accumulator (context-file) AFTER passing
    # contradiction detection so subsequent ask_one invocations see it.
    if [ -n "$context_file" ]; then
        local qkey_for_append="${_GRILLING_CURRENT_QKEY:-}"
        if [ -n "$qkey_for_append" ]; then
            printf '%s: %s\n' "$qkey_for_append" "$resolved" >> "$context_file"
        fi
    fi

    printf 'answer: %s\n' "$resolved"
    return 0
}

# ----------------------------------------------------------------------------
# _grilling_check_contradiction — T04 deliverable (MIT-007 wiring).
#
# T03 ships a no-op stub. T04 replaces the body in-place with the real
# contradiction detector that consults the closed contradiction-pairs SSOT
# block above.
#
# Args:
#   $1  resolved      The answer ask_one resolved.
#   $2  context_file  Path to a project-state file consulted for contradictions.
#
# Returns:
#   0  no contradiction detected (T03 always returns 0).
#   non-zero  contradiction surfaced (T04 may return >0 to abort ask_one).
# ----------------------------------------------------------------------------
_grilling_check_contradiction() {
    # MIT-007 wiring — alphabetized-insert (FR-18 sibling). Scans the accumulator
    # context_file for a prior answer under _GRILLING_CURRENT_QKEY and compares
    # against the closed contradiction-pairs SSOT block above.
    local resolved="${1:-}"
    local context_file="${2:-}"

    # No context file → no contradiction check (still a valid call shape).
    if [ -z "$context_file" ] || [ ! -f "$context_file" ]; then
        return 0
    fi

    # Determine the question-key for this resolved answer. Calling commands set
    # _GRILLING_CURRENT_QKEY before invoking ask_one (e.g.,
    # _GRILLING_CURRENT_QKEY=target-user; ask_one ...).
    local qkey="${_GRILLING_CURRENT_QKEY:-}"
    if [ -z "$qkey" ]; then
        # No question-key context → cannot check contradictions.
        return 0
    fi

    # Scan the accumulator file for prior answers under this qkey. We use
    # `grep` then `tail -1` then `sed` in three separate $(...) calls (no
    # internal pipes) per the bash 3.2 + AP-007 constraint.
    local prior_line=""
    prior_line=$(grep "^${qkey}:" "$context_file" 2>/dev/null || true)
    if [ -z "$prior_line" ]; then
        return 0
    fi
    # Take the last matching line.
    local prior_last=""
    prior_last=$(printf '%s\n' "$prior_line" | tail -1)
    # Strip the qkey: prefix and any leading whitespace from the value.
    local prior_answer=""
    prior_answer=$(printf '%s\n' "$prior_last" | sed -E 's/^[^:]+:[[:space:]]*//')
    if [ -z "$prior_answer" ]; then
        return 0
    fi

    # Check if (qkey, prior_answer, resolved) matches a contradiction pair.
    local found_contradiction=0
    local IFSO="$IFS"
    IFS=$'\n'
    local pair
    for pair in $_GRILLING_CONTRADICTION_PAIRS; do
        local pkey pa pb
        pkey=$(printf '%s' "$pair" | cut -d: -f1)
        pa=$(printf '%s' "$pair" | cut -d: -f2)
        pb=$(printf '%s' "$pair" | cut -d: -f3)
        if [ "$pkey" = "$qkey" ]; then
            if [ "$pa" = "$prior_answer" ] && [ "$pb" = "$resolved" ]; then
                found_contradiction=1
                break
            fi
            if [ "$pb" = "$prior_answer" ] && [ "$pa" = "$resolved" ]; then
                found_contradiction=1
                break
            fi
        fi
    done
    IFS="$IFSO"

    if [ "$found_contradiction" -eq 1 ]; then
        printf 'contradiction: %s prior=%s new=%s\n' "$qkey" "$prior_answer" "$resolved"
        printf 'reconcile [r=re-prompt, !<reason>=accept-with-attestation]: ' >&2
        local reconcile=""
        IFS= read -r reconcile || reconcile="r"
        case "$reconcile" in
            r|R|"")
                return 2
                ;;
            "!"*)
                printf 'attestation: %s\n' "${reconcile#!}"
                return 0
                ;;
            *)
                printf 'unrecognized reconciliation: %s — re-prompt\n' "$reconcile" >&2
                return 2
                ;;
        esac
    fi
    return 0
}

# ----------------------------------------------------------------------------
# _grilling_glossary_update — T04 deliverable (FR-18 inline-update writer).
#
# T03 ships a no-op stub. T04 replaces the body in-place with the real glossary
# writer. T04 reads caller-set bash vars _GRILLING_CURRENT_QKEY and
# _GRILLING_CURRENT_DEFINITION (set by callers before invoking ask_one) when
# the question matches a glossary trigger from the SSOT block above.
#
# Args:
#   $1  question  The question text passed to ask_one.
#   $2  resolved  The answer ask_one resolved.
#
# Returns:
#   0  always (T03 stub; T04 may keep return 0 — writer is best-effort).
# ----------------------------------------------------------------------------
_grilling_glossary_update() {
    # FR-18 inline-update writer — alphabetized-insert via awk single-pass.
    # When the caller-set _GRILLING_CURRENT_QKEY is in the closed
    # _GRILLING_GLOSSARY_TRIGGERS set, write `<term>: <definition>` to
    # <PROJECT_DIR>/wiki/glossary.md. Idempotent on identical input.
    local question="${1:-}"
    local resolved="${2:-}"

    # Question-key extraction: calling commands set _GRILLING_CURRENT_QKEY.
    local qkey="${_GRILLING_CURRENT_QKEY:-}"
    if [ -z "$qkey" ]; then
        return 0
    fi

    # Check if this qkey is a glossary trigger.
    local triggered=0
    local IFSO="$IFS"
    IFS=$'\n'
    local trigger
    for trigger in $_GRILLING_GLOSSARY_TRIGGERS; do
        if [ "$trigger" = "$qkey" ]; then
            triggered=1
            break
        fi
    done
    IFS="$IFSO"

    if [ "$triggered" -eq 0 ]; then
        return 0
    fi

    # Determine the project dir (caller sets PROJECT_DIR; fall back to PWD).
    local project_dir="${PROJECT_DIR:-$PWD}"
    local glossary_dir="$project_dir/wiki"
    local glossary_path="$glossary_dir/glossary.md"
    mkdir -p "$glossary_dir"

    # Term derived from the resolved answer; definition from caller-set
    # _GRILLING_CURRENT_DEFINITION or fallback to the question text.
    local term="$resolved"
    local definition="${_GRILLING_CURRENT_DEFINITION:-$question}"

    # Idempotent check: if the entry already exists with this exact
    # term + definition, no-op (no file write so byte-equality preserved).
    if [ -f "$glossary_path" ]; then
        if grep -qF "${term}: ${definition}" "$glossary_path"; then
            return 0
        fi
    fi

    # Alphabetized-insert via awk single-pass. Preserves comments / non-entry
    # lines transparently.
    local tmp=""
    tmp=$(mktemp)
    if [ -f "$glossary_path" ]; then
        awk -v term="$term" -v def="$definition" '
            BEGIN { inserted=0 }
            /^[^:]+: / && !inserted {
                existing_term = $0
                sub(/:.*$/, "", existing_term)
                if (term < existing_term) {
                    printf "%s: %s\n", term, def
                    inserted=1
                }
            }
            { print }
            END {
                if (!inserted) {
                    printf "%s: %s\n", term, def
                }
            }
        ' "$glossary_path" > "$tmp"
    else
        printf '%s: %s\n' "$term" "$definition" > "$tmp"
    fi
    mv "$tmp" "$glossary_path"
    return 0
}

# Module-level guard: this file is meant to be sourced, not executed.
# If executed directly, print the API surface and exit informationally.
if [ "${BASH_SOURCE[0]:-}" = "${0:-}" ]; then
    echo "scripts/lifecycle/grilling-shell.sh — FR-17 conversational-shell module"
    echo "API: ask_one <question> <recommendation> [<context-file>]"
    echo "usage: source this file from a calling command, then invoke ask_one."
fi
