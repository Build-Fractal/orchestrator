#!/usr/bin/env bash
# scripts/dispatch/adapters/tool/corpus-gate.sh — M042/P01 corpus-exhaustion gate adapter
#
# Reusable tool adapter wrapping the deterministic corpus-exhaustion sweep
# (scripts/knowledge/corpus-exhaustion-sweep.sh). Given a questions file and a
# checkpoint, it owns the enabled/disabled + manifest-resolution + SKIPPED
# policy, runs the sweep, and maps the artifact verdict to an exit code —
# mirroring scripts/dispatch/adapters/tool/conversus.sh so callers wire against
# an identical PASS|BLOCK contract. Follows the filename-routed adapter
# auto-discovery pattern under scripts/dispatch/adapters/tool/.
#
# Subcommands:
#   check                                       Report enabled/manifest state.
#   gate [flags] <questions-file> <output-path> Run the sweep, write the
#                                               artifact, exit per verdict.
#   parse-verdict <artifact-path>               Emit verdict=PASS|BLOCK.
#
# gate flags:
#   --strict                  Treat a disabled feature / missing manifest as an
#                             error (exit 1) instead of SKIPPED+exit-0. Also via
#                             CORPUS_GATE_STRICT=1.
#   --checkpoint <name>       Checkpoint label recorded in the artifact.
#   --generated-at <iso8601>  Caller-supplied timestamp (CON-7 — reproducible).
#   --manifest <path>         Override the store manifest (else config →
#                             bundled default).
#
# Exit-code contract for `gate` (identical to conversus.sh):
#   0  PASS  (or SKIPPED when disabled / manifest absent in non-strict mode)
#   2  BLOCK (un-dispositioned corpus hits — distinct from 1)
#   1  adapter error (missing questions file, missing manifest in strict mode,
#      malformed artifact)
#
# CON-1: Bash 3.2 compatible. Graceful degradation (Principle XI fail-open):
# a project that has not opted in is never hard-blocked.

set -u

_emit_fail() { echo "FAIL: $*" >&2; }

_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# scripts/dispatch/adapters/tool/ -> repo root is four levels up.
_REPO_ROOT="$(cd "$_SCRIPT_DIR/../../../.." && pwd)"
_SWEEP="$_REPO_ROOT/scripts/knowledge/corpus-exhaustion-sweep.sh"
_READ_CONFIG="$_REPO_ROOT/scripts/state/read-config.sh"
_CONFIG_PROJECT="$_REPO_ROOT/.orchestrator/config.yml"
_CONFIG_DEFAULTS="$_REPO_ROOT/templates/orchestrator-config-default.yml"
_BUNDLED_MANIFEST="$_REPO_ROOT/templates/corpus-store-manifest.yml"

# Resolve a config key with project + defaults layering. Echoes the value, or
# "null" when absent / read-config unavailable (fail-open).
_cfg() {
  _cfg_key="$1"
  if [ ! -x "$_READ_CONFIG" ] && [ ! -f "$_READ_CONFIG" ]; then
    echo "null"; return 0
  fi
  bash "$_READ_CONFIG" "$_cfg_key" \
    --project "$_CONFIG_PROJECT" \
    --defaults "$_CONFIG_DEFAULTS" 2>/dev/null || echo "null"
}

_is_enabled() {
  _en="$(_cfg corpus_exhaustion.enabled)"
  case "$_en" in
    false|False|FALSE|0|off) return 1 ;;
    *) return 0 ;;   # null / true / anything else → enabled (opt-out, not opt-in)
  esac
}

# Resolve the manifest path: --manifest override > config store_manifest_path >
# bundled default. Config paths are resolved relative to repo root when relative.
_resolve_manifest() {
  _rm_override="$1"
  if [ -n "$_rm_override" ]; then
    echo "$_rm_override"; return 0
  fi
  _rm_cfg="$(_cfg corpus_exhaustion.store_manifest_path)"
  case "$_rm_cfg" in
    ""|null|None) echo "$_BUNDLED_MANIFEST"; return 0 ;;
  esac
  case "$_rm_cfg" in
    /*) echo "$_rm_cfg" ;;
    *)  echo "$_REPO_ROOT/$_rm_cfg" ;;
  esac
}

_parse_verdict() {
  _pv_file="$1"
  if [ ! -f "$_pv_file" ]; then
    _emit_fail "artifact not found: $_pv_file"
    return 1
  fi
  _pv_line="$(grep -E '^verdict:' "$_pv_file" | head -n 1)"
  if [ -z "$_pv_line" ]; then
    _emit_fail "malformed artifact (no verdict: line): $_pv_file"
    return 1
  fi
  _pv_v="$(printf '%s\n' "$_pv_line" | sed -E 's/^verdict:[[:space:]]*"?([^"]*)"?.*/\1/')"
  case "$_pv_v" in
    PASS|BLOCK) echo "verdict=${_pv_v}"; return 0 ;;
    *) _emit_fail "malformed verdict value: ${_pv_v}"; return 1 ;;
  esac
}

SUBCMD="${1:-}"
if [ $# -gt 0 ]; then shift; fi

case "$SUBCMD" in
  check)
    echo "available=true"
    if _is_enabled; then echo "enabled=true"; else echo "enabled=false"; fi
    _m="$(_resolve_manifest "")"
    echo "manifest=${_m}"
    if [ -f "$_m" ]; then echo "manifest_present=true"; else echo "manifest_present=false"; fi
    exit 0
    ;;

  gate)
    _strict="${CORPUS_GATE_STRICT:-0}"
    _checkpoint="unspecified"
    _generated_at="unset"
    _manifest_override=""
    while [ $# -gt 0 ]; do
      case "${1:-}" in
        --strict)        _strict=1; shift ;;
        --checkpoint)    _checkpoint="$2"; shift 2 ;;
        --generated-at)  _generated_at="$2"; shift 2 ;;
        --manifest)      _manifest_override="$2"; shift 2 ;;
        --) shift; break ;;
        -*) _emit_fail "unknown gate flag: $1"; exit 1 ;;
        *) break ;;
      esac
    done
    if [ $# -lt 2 ]; then
      _emit_fail "usage: gate [--strict] [--checkpoint <name>] [--generated-at <iso>] [--manifest <path>] <questions-file> <output-path>"
      exit 1
    fi
    _questions="$1"
    _output="$2"

    if [ ! -f "$_questions" ]; then
      _emit_fail "questions file not found: $_questions"
      exit 1
    fi

    # Policy: disabled feature.
    if ! _is_enabled; then
      if [ "$_strict" = "1" ]; then
        _emit_fail "corpus-exhaustion gate disabled (corpus_exhaustion.enabled=false) — strict mode requires it enabled"
        exit 1
      fi
      echo "SKIPPED: corpus-exhaustion gate disabled — proceeding without a gate"
      exit 0
    fi

    # Policy: manifest resolution + presence.
    _manifest="$(_resolve_manifest "$_manifest_override")"
    if [ ! -f "$_manifest" ]; then
      if [ "$_strict" = "1" ]; then
        _emit_fail "store manifest not found: $_manifest (strict mode)"
        exit 1
      fi
      echo "SKIPPED: store manifest not found ($_manifest) — proceeding without a gate"
      exit 0
    fi

    if [ ! -f "$_SWEEP" ]; then
      _emit_fail "sweep engine not found: $_SWEEP"
      exit 1
    fi

    # Run the sweep. It writes the artifact + computes the verdict.
    if [ "$_strict" = "1" ]; then
      bash "$_SWEEP" --questions "$_questions" --checkpoint "$_checkpoint" \
        --generated-at "$_generated_at" --manifest "$_manifest" \
        --repo-root "$_REPO_ROOT" --out "$_output" --strict >/dev/null
    else
      bash "$_SWEEP" --questions "$_questions" --checkpoint "$_checkpoint" \
        --generated-at "$_generated_at" --manifest "$_manifest" \
        --repo-root "$_REPO_ROOT" --out "$_output" >/dev/null
    fi
    _rc=$?
    if [ "$_rc" -ne 0 ]; then
      _emit_fail "sweep engine exited non-zero (rc=${_rc})"
      exit 1
    fi

    _v_line="$(_parse_verdict "$_output")"
    if [ $? -ne 0 ]; then
      exit 1
    fi
    echo "$_v_line"
    case "$_v_line" in
      verdict=PASS)  exit 0 ;;
      verdict=BLOCK) exit 2 ;;
      *) exit 1 ;;
    esac
    ;;

  parse-verdict)
    if [ $# -lt 1 ]; then
      _emit_fail "usage: parse-verdict <artifact-path>"
      exit 1
    fi
    _parse_verdict "$1"
    exit $?
    ;;

  ""|help|--help|-h)
    cat <<'USAGE'
corpus-gate.sh — corpus-exhaustion gate adapter (M042)

Subcommands:
  check                                          Report enabled/manifest state.
  gate [flags] <questions-file> <output-path>    Run the sweep, exit per verdict.
  parse-verdict <artifact-path>                  Emit verdict=PASS|BLOCK.

gate flags:
  --strict                  Disabled/missing-manifest → exit 1 (else SKIPPED+exit-0).
                            Also via CORPUS_GATE_STRICT=1.
  --checkpoint <name>       Checkpoint label recorded in the artifact.
  --generated-at <iso8601>  Caller-supplied timestamp (reproducible).
  --manifest <path>         Override the store manifest.

Exit codes: 0 PASS/SKIPPED · 2 BLOCK · 1 adapter error.
USAGE
    exit 0
    ;;

  *)
    _emit_fail "unknown subcommand: ${SUBCMD}"
    exit 1
    ;;
esac
