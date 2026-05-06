#!/usr/bin/env bash
# scripts/state/detect-invocation-context.sh -- M029 / FR-1 / AD-1 invocation-context resolver.
#
# Principle XI (Single Source of Truth): every M029 surface (`status` headline,
# `--format=json`, `where`, `context`, live-tail, preflight) reads this script's
# emitted env block at command entry. No surface re-derives invocation context.
# This is the AD-1 single-resolve site.
#
# Output (stdout, fixed order, exactly three lines):
#     renderer=<tui|json|plain>
#     exit_code_scheme=<interactive|governance>
#     default_provider=<value>
#
# Resolution rules (locked at AD-1):
#   - --format=<tui|json|plain> wins (explicit downstream-command flag forwarded
#     to this resolver). When `--format=json` is present the renderer is `json`
#     regardless of TTY state.
#   - Otherwise: TTY=true AND no CI vars -> renderer=tui exit_code_scheme=interactive.
#   - Otherwise: renderer=plain exit_code_scheme=governance.
#
# Test-injection flags `--tty=<true|false>` and `--ci=<true|false>` let the SC-1
# acceptance battery exercise the resolver without manipulating real TTY state.
# Production callers omit these flags and rely on real `[ -t 1 ]` + env-var
# probing (`GITHUB_ACTIONS`, `CI`, `CLAUDECODE`).
#
# Cross-references:
#   - references/status-headline-shape.md (FR-2 headline contract; T01 design contract)
#   - references/status-json-schema.md (FR-3 JSON contract; T01 design contract)
#   - .orchestrator/milestones/M029/M029-CONTEXT.md AD-1 (single-resolve discipline)
#   - scripts/state/read-config.sh (default_provider passthrough)
#
# Read-only (CON-1 / FR-14): never writes to disk. No log emission, no state
# mutation, no config writes.
#
# Bash 3.2 compatible (no associative arrays, no `${var,,}`, no process
# substitution, no `<<<` herestrings). Mirrors scripts/diagnostics/efficiency-footer.sh.

set -u

# Re-source guard (sourceable as a library AND runnable as a CLI).
if [ -n "${_DETECT_INVOCATION_CONTEXT_SH_SOURCED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_DETECT_INVOCATION_CONTEXT_SH_SOURCED=1

_DIC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DIC_PROJECT_ROOT="$(cd "$_DIC_SCRIPT_DIR/../.." && pwd)"

# --- Argument parser --------------------------------------------------------

_dic_print_usage() {
    cat <<'EOF'
Usage: detect-invocation-context.sh [--tty=<true|false>] [--ci=<true|false>] [--format=<tui|json|plain>] [--help|-h]

Resolves the M029 invocation context (renderer, exit_code_scheme,
default_provider) and emits a three-line key=value env block on stdout.

Test-injection flags:
  --tty=<true|false>   Override TTY probe (defaults to real `[ -t 1 ]`).
  --ci=<true|false>    Override CI env-var probe.
  --format=<value>     Emulate the downstream-command --format flag.

Returns:
  0 on successful resolution.
  2 on unknown flag / argument parse error.
EOF
}

_DIC_TTY_OVERRIDE=""
_DIC_CI_OVERRIDE=""
_DIC_FORMAT_FLAG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --tty=*)
            _DIC_TTY_OVERRIDE="${1#--tty=}"
            shift
            ;;
        --ci=*)
            _DIC_CI_OVERRIDE="${1#--ci=}"
            shift
            ;;
        --format=*)
            _DIC_FORMAT_FLAG="${1#--format=}"
            shift
            ;;
        --help|-h)
            _dic_print_usage
            exit 0
            ;;
        *)
            printf 'unknown flag: %s\n' "$1" >&2
            _dic_print_usage >&2
            exit 2
            ;;
    esac
done

# --- Resolution helpers -----------------------------------------------------

# _resolve_renderer: emits one of {tui, json, plain} on stdout.
# Order of precedence:
#   1. Explicit --format=<tui|json|plain> flag wins.
#   2. Test-injection --tty / --ci flags.
#   3. Real `[ -t 1 ]` and env-var probing.
_resolve_renderer() {
    # 1. --format= flag wins (when valid).
    if [ -n "$_DIC_FORMAT_FLAG" ]; then
        case "$_DIC_FORMAT_FLAG" in
            tui|json|plain)
                printf '%s\n' "$_DIC_FORMAT_FLAG"
                return 0
                ;;
            *)
                printf 'unknown --format value: %s\n' "$_DIC_FORMAT_FLAG" >&2
                exit 2
                ;;
        esac
    fi

    # 2. Determine TTY (override or real probe).
    local tty_value=""
    if [ -n "$_DIC_TTY_OVERRIDE" ]; then
        tty_value="$_DIC_TTY_OVERRIDE"
    else
        if [ -t 1 ]; then
            tty_value="true"
        else
            tty_value="false"
        fi
    fi

    # 3. Determine CI (override or real env-var probe).
    local ci_value=""
    if [ -n "$_DIC_CI_OVERRIDE" ]; then
        ci_value="$_DIC_CI_OVERRIDE"
    else
        if [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${CI:-}" ] || [ -n "${CLAUDECODE:-}" ]; then
            ci_value="true"
        else
            ci_value="false"
        fi
    fi

    # 4. Apply resolution rules.
    if [ "$tty_value" = "true" ] && [ "$ci_value" = "false" ]; then
        printf 'tui\n'
    else
        printf 'plain\n'
    fi
}

# _resolve_exit_code_scheme: maps renderer -> exit_code_scheme.
#   renderer=tui   -> exit_code_scheme=interactive
#   renderer=json  -> exit_code_scheme=governance
#   renderer=plain -> exit_code_scheme=governance
_resolve_exit_code_scheme() {
    local renderer="$1"
    if [ "$renderer" = "tui" ]; then
        printf 'interactive\n'
    else
        printf 'governance\n'
    fi
}

# _resolve_default_provider: reads `default_provider` from project config (best
# effort) and falls back to `claude-code` when the read returns empty / null /
# unknown. The canonical default lives in templates/orchestrator-config-default.yml;
# `default_provider` is not a registered key in scripts/state/read-config.sh
# today, so a direct YAML read is performed instead. This is a passthrough --
# the resolver never writes the config and never registers schema.
_resolve_default_provider() {
    local cfg_value=""
    local cfg_file="$_DIC_PROJECT_ROOT/.orchestrator/config.yml"
    if [ -f "$cfg_file" ]; then
        # grep first, then sed to strip the `key:` prefix and surrounding
        # whitespace / quotes. Comments after the value are dropped.
        local line
        line=$(grep -E '^default_provider:[[:space:]]' "$cfg_file" 2>/dev/null | head -1) || true
        if [ -n "$line" ]; then
            cfg_value=$(printf '%s' "$line" \
                | sed -e 's/^default_provider:[[:space:]]*//' \
                      -e 's/[[:space:]]*#.*$//' \
                      -e 's/^[[:space:]]*//' \
                      -e 's/[[:space:]]*$//' \
                      -e 's/^"\(.*\)"$/\1/' \
                      -e "s/^'\(.*\)'\$/\1/")
        fi
    fi

    if [ -z "$cfg_value" ] || [ "$cfg_value" = "null" ]; then
        cfg_value="claude-code"
    fi
    printf '%s\n' "$cfg_value"
}

# --- Emit env block ---------------------------------------------------------

_DIC_RENDERER="$(_resolve_renderer)"
_DIC_EXIT_SCHEME="$(_resolve_exit_code_scheme "$_DIC_RENDERER")"
_DIC_PROVIDER="$(_resolve_default_provider)"

printf 'renderer=%s\n' "$_DIC_RENDERER"
printf 'exit_code_scheme=%s\n' "$_DIC_EXIT_SCHEME"
printf 'default_provider=%s\n' "$_DIC_PROVIDER"

exit 0
