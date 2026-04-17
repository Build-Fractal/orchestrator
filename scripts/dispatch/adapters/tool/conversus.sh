#!/usr/bin/env bash
# scripts/dispatch/adapters/tool/conversus.sh — Conversus cooperative-deliberation tool adapter
#
# Reusable tool adapter bridging the orchestrator to the external
# `conversus` binary for two-agent cooperative deliberation (source-advocate
# vs target-advocate with a constitution-grounded arbiter). Follows the
# filename-routed adapter auto-discovery pattern (MEM008, MEM018) under
# scripts/dispatch/adapters/tool/.
#
# Subcommands:
#   check                                   Probe for the conversus binary.
#   gate <preset> <artifact> <output>       Run the fidelity gate, write
#                                           gate-result.md to <output>.
#   parse-verdict <gate-result-path>        Emit `verdict=PASS|BLOCK` from a
#                                           gate-result.md frontmatter.
#
# Resolver order for the conversus binary:
#   1. CONVERSUS_STUB=1                      — stub mode (test-only)
#   2. command -v conversus                  — PATH
#   3. $CONVERSUS_HOME/bin/conversus         — explicit env var
#   4. $HOME/Sites/conversus/bin/conversus   — user-local convention
#
# Graceful degradation (roadmap directive): when the binary is missing,
# `gate` emits a `SKIPPED:` line and exits 0 so the calling pipeline can
# proceed without a gate. Conversus is an optional external dependency,
# not a hard blocker.
#
# Exit-code contract for `gate`:
#   0  PASS  (or SKIPPED when binary missing — both are "proceed")
#   2  BLOCK (distinct from 1 so callers can distinguish verdict from error)
#   1  adapter error (missing preset, missing artifact, malformed output)
#
# Bash 3.2 compatible (MEM001): no declare -A, no mapfile/readarray, no
# process substitution.

set -u

# --- helpers ---

_emit_fail() {
  echo "FAIL: $*" >&2
}

_resolve_binary() {
  # Emits `available=<bool>` and optionally `conversus_path=<path>` /
  # `reason=<text>` lines to stdout. Exits 0 always — "not found" is a
  # valid state, not an error.
  if [ "${CONVERSUS_STUB:-0}" = "1" ]; then
    echo "available=true"
    echo "conversus_path=stub"
    echo "reason=CONVERSUS_STUB=1"
    return 0
  fi
  _which_path=""
  if command -v conversus >/dev/null 2>&1; then
    _which_path="$(command -v conversus)"
    echo "available=true"
    echo "conversus_path=${_which_path}"
    return 0
  fi
  if [ -n "${CONVERSUS_HOME:-}" ] && [ -x "${CONVERSUS_HOME}/bin/conversus" ]; then
    echo "available=true"
    echo "conversus_path=${CONVERSUS_HOME}/bin/conversus"
    return 0
  fi
  if [ -x "${HOME:-}/Sites/conversus/bin/conversus" ]; then
    echo "available=true"
    echo "conversus_path=${HOME}/Sites/conversus/bin/conversus"
    return 0
  fi
  echo "available=false"
  echo "reason=conversus binary not found on PATH, CONVERSUS_HOME, or ~/Sites/conversus"
  return 0
}

_parse_verdict() {
  _gr="$1"
  if [ ! -f "$_gr" ]; then
    _emit_fail "gate-result not found: $_gr"
    return 1
  fi
  _line="$(grep -E '^verdict:' "$_gr" | head -n 1)"
  if [ -z "$_line" ]; then
    _emit_fail "malformed gate-result (no verdict: line): $_gr"
    return 1
  fi
  _v="$(printf '%s\n' "$_line" | sed -E 's/^verdict:[[:space:]]*"?([^"]*)"?.*/\1/')"
  case "$_v" in
    PASS|BLOCK)
      echo "verdict=${_v}"
      return 0
      ;;
    *)
      _emit_fail "malformed verdict value: ${_v}"
      return 1
      ;;
  esac
}

# Locate this script's repo root (two levels up from scripts/dispatch/adapters/tool/).
_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
_REPO_ROOT="$(cd "$_SCRIPT_DIR/../../../.." && pwd)"

# --- subcommand dispatch ---

SUBCMD="${1:-}"
if [ $# -gt 0 ]; then
  shift
fi

case "$SUBCMD" in
  check)
    _resolve_binary
    exit 0
    ;;

  gate)
    # gate <preset-name> <artifact-path> <output-path>
    if [ $# -lt 3 ]; then
      _emit_fail "usage: gate <preset-name> <artifact-path> <output-path>"
      exit 1
    fi
    _preset_name="$1"
    _artifact="$2"
    _output="$3"

    _preset_file="${_REPO_ROOT}/templates/conversus-presets/${_preset_name}.yml"
    if [ ! -f "$_preset_file" ]; then
      _emit_fail "preset not found: ${_preset_file}"
      exit 1
    fi
    if [ ! -r "$_artifact" ]; then
      _emit_fail "artifact not found: ${_artifact}"
      exit 1
    fi

    # Stub mode: use canned fixtures for deterministic testing.
    if [ "${CONVERSUS_STUB:-0}" = "1" ]; then
      _stub_verdict="${CONVERSUS_STUB_VERDICT:-PASS}"
      case "$_stub_verdict" in
        PASS)
          _fixture="${_REPO_ROOT}/tests/fixtures/gate-result-pass.md"
          ;;
        BLOCK)
          _fixture="${_REPO_ROOT}/tests/fixtures/gate-result-block.md"
          ;;
        *)
          _emit_fail "CONVERSUS_STUB_VERDICT must be PASS or BLOCK, got: ${_stub_verdict}"
          exit 1
          ;;
      esac
      if [ ! -f "$_fixture" ]; then
        _emit_fail "stub fixture not found: ${_fixture}"
        exit 1
      fi
      cp "$_fixture" "$_output"
      _v_line="$(_parse_verdict "$_output")"
      _pv_rc=$?
      if [ $_pv_rc -ne 0 ]; then
        exit 1
      fi
      echo "$_v_line"
      case "$_v_line" in
        verdict=PASS) exit 0 ;;
        verdict=BLOCK) exit 2 ;;
        *) exit 1 ;;
      esac
    fi

    # Real mode: resolve binary. On missing, graceful degradation.
    _probe="$(_resolve_binary)"
    echo "$_probe"
    case "$_probe" in
      *available=false*)
        echo "SKIPPED: conversus binary not available — fidelity gate bypassed"
        exit 0
        ;;
    esac

    _bin_path="$(printf '%s\n' "$_probe" | grep -E '^conversus_path=' | head -n 1 | sed -E 's/^conversus_path=//')"
    if [ -z "$_bin_path" ]; then
      _emit_fail "resolver reported available=true but no path"
      exit 1
    fi

    "$_bin_path" gate --preset "$_preset_file" --artifact "$_artifact" --output "$_output"
    _rc=$?
    if [ $_rc -ne 0 ]; then
      _emit_fail "conversus exited non-zero (rc=${_rc})"
      exit 1
    fi

    _v_line="$(_parse_verdict "$_output")"
    _pv_rc=$?
    if [ $_pv_rc -ne 0 ]; then
      exit 1
    fi
    echo "$_v_line"
    case "$_v_line" in
      verdict=PASS) exit 0 ;;
      verdict=BLOCK) exit 2 ;;
      *) exit 1 ;;
    esac
    ;;

  parse-verdict)
    if [ $# -lt 1 ]; then
      _emit_fail "usage: parse-verdict <gate-result-path>"
      exit 1
    fi
    _parse_verdict "$1"
    exit $?
    ;;

  ""|help|--help|-h)
    cat <<'USAGE'
conversus.sh — Conversus cooperative-deliberation tool adapter

Subcommands:
  check                                 Probe for the conversus binary.
  gate <preset> <artifact> <output>     Run the fidelity gate.
  parse-verdict <gate-result-path>      Emit verdict=PASS|BLOCK.

Resolver order: CONVERSUS_STUB, PATH, CONVERSUS_HOME, ~/Sites/conversus.
USAGE
    exit 0
    ;;

  *)
    _emit_fail "unknown subcommand: ${SUBCMD}"
    exit 1
    ;;
esac
