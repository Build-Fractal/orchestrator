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
#   gate [--strict] <preset> <artifact> <output>
#                                           Run the fidelity gate, write
#                                           gate-result.md to <output>.
#   parse-verdict <gate-result-path>        Emit `verdict=PASS|BLOCK` from a
#                                           gate-result.md frontmatter.
#
# Resolver order for the conversus binary:
#   1. CONVERSUS_STUB=1                            — stub (test-only)
#   2. command -v conversus                        — PATH
#   3. $CONVERSUS_HOME/bin/conversus               — explicit env var
#   4. $HOME/Sites/conversus-oss/bin/conversus     — user-local OSS
#   5. $HOME/Sites/conversus/bin/conversus         — user-local paid
#
# Edition detection (M026/P02): `check` emits `edition=<oss|paid|unknown>`
# and `reason=<env-override|metadata-probe|metadata-probe-failed|stub|
# home|command-v|fallback>`. Primary: `CONVERSUS_EDITION=oss|paid`.
# Fallback: `pip show conversus` Home-page probe. Single-venv reality
# (see M026-CONVERSUS-PARITY.md) makes path-based detection infeasible.
#
# Graceful degradation (roadmap directive): when the binary is missing,
# `gate` emits a `SKIPPED:` line and exits 0 so the calling pipeline can
# proceed without a gate. Conversus is an optional external dependency,
# not a hard blocker.
#
# Strict mode (`--strict` flag or CONVERSUS_STRICT=1): callers that require
# the adapter to be present (e.g., M013 pre-merge gate, US-6 AS-4) can
# flip graceful degradation off. In strict mode, a missing binary emits
# `FAIL: conversus binary not available` on stderr and exits 1 instead of
# SKIPPED+exit-0. PASS/BLOCK verdict behavior is unchanged.
#
# Provider selection:
#   The model provider passed to `conversus run` is read from
#   `CONVERSUS_PROVIDER` (default: `anthropic`). See the assignment at
#   `_provider="${CONVERSUS_PROVIDER:-anthropic}"` below.
#   - Default `anthropic` — direct Anthropic API calls in parallel. Fast
#     (~6 min for a 5-phase gate) but REQUIRES `ANTHROPIC_API_KEY`.
#   - On Anthropic OAuth (Claude Max/subscription) auth, callers MUST
#     set `CONVERSUS_PROVIDER=claude-code` before invoking this adapter.
#     The default path hits a server-side concurrency policy gate that
#     429s instantly on parallel requests — this is NOT a transient
#     rate limit; retrying won't help.
#   - `claude-code` spawns a `claude -p` subprocess per agent (which is
#     what OAuth is designed for). Wall time ~3-4x slower but reliable.
#   - M026/P02/T04 auto-preflight: when CONVERSUS_PROVIDER is unset AND
#     ANTHROPIC_API_KEY is not exported AND ~/.conversus/auth.json shows
#     an OAuth marker (access_token / oauth / subscription), the adapter
#     auto-sets CONVERSUS_PROVIDER=claude-code and emits a `note:` line
#     to stderr. Any explicit CONVERSUS_PROVIDER value (including empty)
#     wins — the operator's setting is never overridden.
#   See `references/architecture.md` ("Conversus Adapter — Operator
#   Notes") for the full operator runbook.
#
# Exit-code contract for `gate`:
#   0  PASS  (or SKIPPED when binary missing in non-strict mode — both are "proceed")
#   2  BLOCK (distinct from 1 so callers can distinguish verdict from error)
#   1  adapter error (missing preset, missing artifact, malformed output,
#      or missing binary in strict mode)
#
# Bash 3.2 compatible (MEM001): no declare -A, no mapfile/readarray, no
# process substitution.

set -u

# --- helpers ---

_emit_fail() {
  echo "FAIL: $*" >&2
}

_resolve_binary() {
  # Emits structured lines to stdout. On success:
  #   available=true
  #   conversus_path=<path>
  #   edition=<oss|paid|unknown>
  #   reason=<env-override|metadata-probe|metadata-probe-failed|stub|home|command-v|fallback>
  # On not-found:
  #   available=false
  #   reason=<text>
  # Exits 0 always — "not found" is a valid state, not an error.
  if [ "${CONVERSUS_STUB:-0}" = "1" ]; then
    echo "available=true"
    echo "conversus_path=stub"
    _resolve_edition "" stub
    return 0
  fi
  _which_path=""
  if command -v conversus >/dev/null 2>&1; then
    _which_path="$(command -v conversus)"
    echo "available=true"
    echo "conversus_path=${_which_path}"
    _rb_venv_py="$(head -n 1 "$_which_path" 2>/dev/null | sed -E 's|^#!([^[:space:]]+).*|\1|')"
    _resolve_edition "$_rb_venv_py" command-v
    return 0
  fi
  if [ -n "${CONVERSUS_HOME:-}" ] && [ -x "${CONVERSUS_HOME}/bin/conversus" ]; then
    echo "available=true"
    echo "conversus_path=${CONVERSUS_HOME}/bin/conversus"
    _rb_venv_py="$(head -n 1 "${CONVERSUS_HOME}/bin/conversus" 2>/dev/null | sed -E 's|^#!([^[:space:]]+).*|\1|')"
    _resolve_edition "$_rb_venv_py" home
    return 0
  fi
  if [ -x "${HOME:-}/Sites/conversus-oss/bin/conversus" ]; then
    echo "available=true"
    echo "conversus_path=${HOME}/Sites/conversus-oss/bin/conversus"
    _rb_venv_py="$(head -n 1 "${HOME}/Sites/conversus-oss/bin/conversus" 2>/dev/null | sed -E 's|^#!([^[:space:]]+).*|\1|')"
    _resolve_edition "$_rb_venv_py" fallback
    return 0
  fi
  if [ -x "${HOME:-}/Sites/conversus/bin/conversus" ]; then
    echo "available=true"
    echo "conversus_path=${HOME}/Sites/conversus/bin/conversus"
    _rb_venv_py="$(head -n 1 "${HOME}/Sites/conversus/bin/conversus" 2>/dev/null | sed -E 's|^#!([^[:space:]]+).*|\1|')"
    _resolve_edition "$_rb_venv_py" fallback
    return 0
  fi
  echo "available=false"
  echo "reason=conversus binary not found on PATH, CONVERSUS_HOME, ~/Sites/conversus-oss, or ~/Sites/conversus"
  return 0
}

_resolve_edition() {
  # _resolve_edition <venv-python-path> <resolved-via-tag>
  # Emits `edition=<oss|paid|unknown>` + `reason=<tag>` to stdout.
  # Tags: env-override|metadata-probe|metadata-probe-failed|stub|home|command-v|fallback.
  _ve_venv_py="$1"
  _ve_via="$2"
  case "${CONVERSUS_EDITION:-}" in
    oss|paid)
      echo "edition=${CONVERSUS_EDITION}"
      echo "reason=env-override"
      return 0
      ;;
    "") : ;;
    *)
      echo "warn: CONVERSUS_EDITION=${CONVERSUS_EDITION} is not oss|paid; falling through to metadata probe" >&2
      ;;
  esac
  if [ "${CONVERSUS_STUB:-0}" = "1" ] || [ "$_ve_via" = "stub" ]; then
    echo "edition=unknown"
    echo "reason=stub"
    return 0
  fi
  if [ -n "$_ve_venv_py" ] && [ -x "$_ve_venv_py" ]; then
    _ve_pip_out="$("$_ve_venv_py" -m pip show conversus 2>/dev/null)"
    _ve_home_line="$(printf '%s\n' "$_ve_pip_out" | grep -E '^Home-page:' | head -n 1)"
    _ve_home="$(printf '%s\n' "$_ve_home_line" | sed -E 's/^Home-page:[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -n "$_ve_home" ]; then
      case "$_ve_home" in
        *conversus-oss*)
          echo "edition=oss"
          echo "reason=metadata-probe"
          return 0
          ;;
        *)
          echo "edition=paid"
          echo "reason=metadata-probe"
          return 0
          ;;
      esac
    fi
    echo "edition=unknown"
    echo "reason=metadata-probe-failed"
    return 0
  fi
  echo "edition=unknown"
  echo "reason=${_ve_via}"
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
    # gate [--strict] <preset-name> <artifact-path> <output-path>
    _strict="${CONVERSUS_STRICT:-0}"
    if [ "${1:-}" = "--strict" ]; then
      _strict=1
      shift
    fi
    if [ $# -lt 3 ]; then
      _emit_fail "usage: gate [--strict] <preset-name> <artifact-path> <output-path>"
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

    # Pre-flight: refuse to gate artifacts that still contain `<TODO:`
    # section placeholders. Running adversarial deliberation against a
    # half-authored scaffold produces nonsense findings — the gate only
    # earns its cost on a body that's been through the author pass. See
    # D019 + specs/025-knowledge-layer-maturation/conversus/PRESSURE-TEST-FINDINGS.md.
    #
    # Threshold (env `CONVERSUS_GATE_TODO_THRESHOLD`, default 1): any
    # artifact with >= threshold `<TODO:` markers is refused. Tests and
    # intentional "gate a stub" callers can bypass via
    # `CONVERSUS_GATE_SKIP_TODO_CHECK=1`.
    if [ "${CONVERSUS_GATE_SKIP_TODO_CHECK:-0}" != "1" ]; then
      _todo_threshold="${CONVERSUS_GATE_TODO_THRESHOLD:-1}"
      _todo_count="$(grep -cE '<TODO:' "$_artifact" 2>/dev/null | head -n 1)"
      _todo_count="${_todo_count// /}"
      : "${_todo_count:=0}"
      if [ "$_todo_count" -ge "$_todo_threshold" ]; then
        _emit_fail "artifact contains ${_todo_count} <TODO: marker(s); gate refuses unauthored drafts. Run the author pass first (see commands/specify.md three-pass flow) or set CONVERSUS_GATE_SKIP_TODO_CHECK=1 to bypass."
        exit 1
      fi
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

    # Real mode: resolve binary. On missing, graceful degradation (or
    # strict fail if --strict / CONVERSUS_STRICT=1).
    _probe="$(_resolve_binary)"
    echo "$_probe"
    case "$_probe" in
      *available=false*)
        if [ "$_strict" = "1" ]; then
          _emit_fail "conversus binary not available — strict mode requires present adapter"
          exit 1
        fi
        echo "SKIPPED: conversus binary not available — fidelity gate bypassed"
        exit 0
        ;;
    esac

    _bin_path="$(printf '%s\n' "$_probe" | grep -E '^conversus_path=' | head -n 1 | sed -E 's/^conversus_path=//')"
    if [ -z "$_bin_path" ]; then
      _emit_fail "resolver reported available=true but no path"
      exit 1
    fi

    # --- Shim: conversus has no native `gate` subcommand (upstream spec 998
    # parked). We bridge by synthesizing a conversus.yml from the preset +
    # artifact, invoking `conversus run`, and deriving PASS/BLOCK from the
    # surviving-dispute count in the synthesis output.
    #
    # The conversus pipx/venv Python is reused for both YAML synth
    # (PyYAML is a conversus dep) and output parsing (`python -m
    # linter.output_contract`), avoiding a second Python dependency on
    # the orchestrator side.

    # Extract venv python from the conversus launcher shebang.
    _venv_py="$(head -n 1 "$_bin_path" | sed -E 's|^#!([^[:space:]]+).*|\1|')"
    if [ -z "$_venv_py" ] || [ ! -x "$_venv_py" ]; then
      _emit_fail "could not resolve conversus venv python from ${_bin_path}"
      exit 1
    fi

    # Derive the conversus run output dir. Default: the directory
    # containing the gate-result.md output path. Callers who want a
    # different tree (e.g., specs/NNN-slug/conversus/) set
    # CONVERSUS_RUN_OUTPUT_DIR explicitly.
    _run_output_dir="${CONVERSUS_RUN_OUTPUT_DIR:-$(dirname "$_output")}"
    mkdir -p "$_run_output_dir"

    # Synthesize conversus.yml in a TEMP dir, NOT in the run output dir.
    # Rationale: conversus walks upward from the config file looking
    # for a `templates/` directory (engine/templates.py:find_templates_dir),
    # and if it finds one before reaching the installed conversus
    # package's own templates, it uses that. Putting the config inside
    # this orchestrator repo makes conversus pick up the orchestrator's
    # `templates/` (which has no red-blue/review.md etc.) and fail.
    # A temp-dir config sidesteps that by having no ancestor `templates/`.
    _conv_tmp="$(mktemp -d -t conversus-gate.XXXXXX)"
    trap 'rm -rf "$_conv_tmp"' EXIT
    _conv_config="${_conv_tmp}/conversus.yml"
    "$_venv_py" "${_SCRIPT_DIR}/conversus-synth.py" \
      --preset "$_preset_file" \
      --artifact "$_artifact" \
      --output-dir "$_run_output_dir" \
      --out "$_conv_config"
    _rc=$?
    if [ $_rc -ne 0 ]; then
      _emit_fail "conversus-synth.py failed (rc=${_rc})"
      exit 1
    fi

    # Invoke conversus run.
    # F3 (M026/P02/T04): auto-preflight CONVERSUS_PROVIDER=claude-code
    # under Anthropic OAuth. Only fires when CONVERSUS_PROVIDER is unset.
    # See references/architecture.md "Conversus Adapter — Operator Notes".
    if [ -z "${CONVERSUS_PROVIDER+set}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$HOME/.conversus/auth.json" ]; then
      if grep -qE '"(access_token|oauth|subscription)"' "$HOME/.conversus/auth.json" 2>/dev/null; then
        echo "note: detected Anthropic OAuth auth with no ANTHROPIC_API_KEY; auto-setting CONVERSUS_PROVIDER=claude-code (see references/architecture.md)" >&2
        CONVERSUS_PROVIDER=claude-code
        export CONVERSUS_PROVIDER
      fi
    fi
    _provider="${CONVERSUS_PROVIDER:-anthropic}"
    "$_bin_path" run "$_conv_config" --provider "$_provider"
    _rc=$?
    if [ $_rc -ne 0 ]; then
      _emit_fail "conversus run exited non-zero (rc=${_rc})"
      exit 1
    fi

    # Preserve the synthesized config in the run output dir for audit
    # (the tmp dir is disposable; the repo-side copy is the record).
    _conv_config_preserved="${_run_output_dir}/conversus.yml"
    cp "$_conv_config" "$_conv_config_preserved" 2>/dev/null || true

    _synthesis="${_run_output_dir}/summary/final.md"
    if [ ! -f "$_synthesis" ]; then
      _emit_fail "conversus produced no synthesis at ${_synthesis}"
      exit 1
    fi

    # Parse using conversus's canonical output contract. Do the whole
    # extract-fields-from-JSON dance inside a single venv-python process
    # so JSON values don't have to survive a bash heredoc.
    _mode="$(grep -E '^mode:' "$_conv_config" | head -n 1 | sed -E 's/^mode:[[:space:]]*//;s/[[:space:]]*$//')"
    _extract_py='
import json, subprocess, sys
path, mode = sys.argv[1], sys.argv[2]
res = subprocess.run([sys.executable, "-m", "linter.output_contract", path, "--mode", mode], capture_output=True, text=True)
if res.returncode != 0:
    sys.stderr.write(res.stderr)
    sys.exit(res.returncode)
data = json.loads(res.stdout)
qi = data.get("quality_indicators", {})
print("SURVIVING=%d" % qi.get("genuine_disagreements_surviving", -1))
print("HEADLINE=%s" % data.get("headline", "").replace("\n", " "))
print("SUMMARY=%s" % data.get("summary", "").replace("\n", " "))
'
    _extracted="$("$_venv_py" -c "$_extract_py" "$_synthesis" "${_mode:-cooperative}" 2>&1)"
    _rc=$?
    if [ $_rc -ne 0 ]; then
      _emit_fail "output parser failed (rc=${_rc}): ${_extracted}"
      exit 1
    fi

    _surviving="$(printf '%s\n' "$_extracted" | grep -E '^SURVIVING=' | head -n 1 | sed -E 's/^SURVIVING=//')"
    _headline="$(printf '%s\n' "$_extracted" | grep -E '^HEADLINE=' | head -n 1 | sed -E 's/^HEADLINE=//')"
    _summary="$(printf '%s\n' "$_extracted" | grep -E '^SUMMARY=' | head -n 1 | sed -E 's/^SUMMARY=//')"

    if [ -z "$_surviving" ] || [ "$_surviving" = "-1" ]; then
      _emit_fail "could not extract surviving-dispute count from parser output"
      exit 1
    fi

    if [ "$_surviving" = "0" ]; then
      _verdict="PASS"
    else
      _verdict="BLOCK"
    fi

    # Source hash for the audit trail.
    if command -v shasum >/dev/null 2>&1; then
      _source_hash="$(shasum -a 256 "$_artifact" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
      _source_hash="$(sha256sum "$_artifact" | awk '{print $1}')"
    else
      _source_hash="unavailable"
    fi

    _preset_name="$(basename "$_preset_file" .yml)"
    # Rationale is synthesized from load-bearing extracted fields only
    # (verdict + surviving_disputes + mode). The linter's `summary`
    # string was previously copied verbatim, but its agent_count and
    # phases_completed heuristics don't match the Risk Register
    # synthesizer format and produced misleading rationales. Only the
    # surviving-dispute count is reliable, and it's already surfaced
    # in the `disputes:` field — the rationale here just names what
    # the verdict derives from. Operators wanting the full synthesis
    # read `summary/final.md` via the "Full deliberation" link below.
    #
    # F1/F2 (M026/P02/T04): prefer the `## Verdict` paragraph from
    # arbiter/resolution.md (if present) else summary/final.md; fall
    # back to the synthesized formula when no Verdict section exists.
    _rationale_text=""
    _arbiter_file="${_run_output_dir}/arbiter/resolution.md"
    if [ -f "$_arbiter_file" ]; then
      _verdict_source="$_arbiter_file"
    else
      _verdict_source="$_synthesis"
    fi
    _rationale_text="$(awk '
      /^## Verdict/ { capture=1; next }
      /^## / && capture { exit }
      capture && NF { out = out (out=="" ? "" : " ") $0 }
      END { print out }
    ' "$_verdict_source" 2>/dev/null)"
    _rationale_text="$(printf '%s\n' "$_rationale_text" | sed -E 's/"/\x27/g; s/[[:space:]]+/ /g; s/^ *//; s/ *$//')"
    _mode_label="${_mode:-cooperative}"
    if [ -n "$_rationale_text" ]; then
      _rationale="$_rationale_text"
    else
      _rationale="verdict=${_verdict} derived from surviving_disputes=${_surviving} in ${_mode_label} deliberation"
    fi
    mkdir -p "$(dirname "$_output")"
    cat > "$_output" <<EOF
---
verdict: "${_verdict}"
disputes: ${_surviving}
rationale: "${_rationale}"
source_hash: "${_source_hash}"
preset: "${_preset_name}"
artifact: "${_artifact}"
conversus_output_dir: "${_run_output_dir}"
conversus_config: "${_conv_config_preserved}"
---
# Gate Result: ${_preset_name}

**Verdict:** ${_verdict}
**Surviving disputes:** ${_surviving}
**Headline:** ${_headline}

## Rationale

${_rationale}

## Full deliberation

See: \`${_run_output_dir}/summary/final.md\`
EOF

    echo "verdict=${_verdict}"
    case "$_verdict" in
      PASS) exit 0 ;;
      BLOCK) exit 2 ;;
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
  check                                          Probe for the conversus binary.
  gate [--strict] <preset> <artifact> <output>   Run the fidelity gate.
  parse-verdict <gate-result-path>               Emit verdict=PASS|BLOCK.

Flags:
  --strict        Treat missing binary as FAIL (exit 1) instead of SKIPPED+exit-0.
                  Also enabled via CONVERSUS_STRICT=1.

Resolver order: CONVERSUS_STUB, PATH, CONVERSUS_HOME, ~/Sites/conversus.
USAGE
    exit 0
    ;;

  *)
    _emit_fail "unknown subcommand: ${SUBCMD}"
    exit 1
    ;;
esac
