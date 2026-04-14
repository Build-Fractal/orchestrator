#!/usr/bin/env bash
# scripts/lifecycle/init-project.sh — orchestrator:init entry point.
#
# Pipeline: detect (runtime + project) -> probe (capabilities) -> generate
# (config + instruction file) -> verify (delegate installer).
#
# Usage:
#   init-project.sh [--project-dir PATH] [--runtime NAME] [--dry-run] [--force] [--verbose]
#
# Exit codes:
#   0 success
#   1 generic failure (with FAIL: on stderr)
#   2 unsafe environment (empty or '/' HOME on claude-code/codex)
#   3 runtime unavailable / unsupported
#   4 already initialized (delegated to reinit-handler.sh when present)
#
# Bash 3.2 compatible. No associative arrays, mapfile, jq, or python.
# Security note: `eval` is used solely to pass controlled flag strings built
# from script-internal state (never user input). Placeholder substitution
# uses sed with `|` delimiter; values come only from controlled detectors
# that never emit `|`.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_DIR="$PWD"
RUNTIME="auto"
RUNTIME_CONFIDENCE=""
DRY_RUN=0
FORCE=0
VERBOSE=0

# --- 1. Arg parsing ---------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)
      shift
      [ $# -eq 0 ] && { echo "FAIL: --project-dir requires a path argument" >&2; exit 1; }
      PROJECT_DIR="$1"; shift ;;
    --project-dir=*) PROJECT_DIR="${1#--project-dir=}"; shift ;;
    --runtime)
      shift
      [ $# -eq 0 ] && { echo "FAIL: --runtime requires a name argument" >&2; exit 1; }
      RUNTIME="$1"; shift ;;
    --runtime=*) RUNTIME="${1#--runtime=}"; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --force)     FORCE=1;   shift ;;
    --verbose)   VERBOSE=1; shift ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "FAIL: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

[ -d "$PROJECT_DIR" ] || { echo "FAIL: not a directory: $PROJECT_DIR" >&2; exit 1; }

log() { [ $VERBOSE -eq 1 ] && echo "$@" >&2; return 0; }

# --- 2. Runtime detection ---------------------------------------------------
if [ "$RUNTIME" = "auto" ]; then
  RUNTIME_OUT="$(bash "$REPO_ROOT/scripts/dispatch/detect-runtime.sh" 2>/dev/null || true)"
  RUNTIME="$(echo "$RUNTIME_OUT" | grep '^runtime=' | head -1 | cut -d= -f2)"
  RUNTIME_CONFIDENCE="$(echo "$RUNTIME_OUT" | grep '^confidence=' | head -1 | cut -d= -f2)"
  log "detected runtime=$RUNTIME confidence=$RUNTIME_CONFIDENCE"
fi

case "$RUNTIME" in
  claude-code|codex|cursor) ;;
  unknown|"")
    echo "FAIL: could not auto-detect runtime. Supported: claude-code, codex, cursor." >&2
    echo "Re-run with --runtime <name> to override." >&2
    exit 3 ;;
  *)
    echo "FAIL: unsupported runtime '$RUNTIME'" >&2
    exit 3 ;;
esac

# --- 3. HOME guard (claude-code/codex only) ---------------------------------
case "$RUNTIME" in
  claude-code|codex)
    if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ]; then
      echo "FAIL: unsafe HOME (empty or '/') for runtime $RUNTIME" >&2
      exit 2
    fi ;;
esac

# --- 4. Resolve state root --------------------------------------------------
STATE_ROOT_ABS="$(cd "$PROJECT_DIR" && bash "$REPO_ROOT/scripts/state/resolve-root.sh" --absolute 2>/dev/null)"
[ -n "$STATE_ROOT_ABS" ] || STATE_ROOT_ABS="$PROJECT_DIR/.orchestrator"
CONFIG_FILE="$STATE_ROOT_ABS/config.yml"

# --- 5. Reinit delegation ---------------------------------------------------
if [ -f "$CONFIG_FILE" ] && [ $FORCE -eq 0 ]; then
  echo "REINIT: existing config at $CONFIG_FILE" >&2
  if [ -x "$REPO_ROOT/scripts/lifecycle/reinit-handler.sh" ]; then
    # Delegate, propagate --dry-run/--verbose.
    reinit_args="--project-dir \"$PROJECT_DIR\" --state-root \"$STATE_ROOT_ABS\" --runtime \"$RUNTIME\""
    [ $DRY_RUN -eq 1 ] && reinit_args="$reinit_args --dry-run"
    [ $VERBOSE -eq 1 ] && reinit_args="$reinit_args --verbose"
    # eval used intentionally to preserve quoted paths; args are script-internal state only.
    eval "bash \"$REPO_ROOT/scripts/lifecycle/reinit-handler.sh\" $reinit_args"
    rc=$?
    exit $rc
  else
    echo "FAIL: existing config detected but reinit-handler.sh missing. Use --force to overwrite." >&2
    exit 4
  fi
fi

# --- 6. Project detection ---------------------------------------------------
PROJECT_OUT="$(bash "$REPO_ROOT/scripts/lifecycle/detect-project.sh" --project-dir "$PROJECT_DIR" 2>/dev/null)"
get() { echo "$PROJECT_OUT" | grep "^$1=" | head -1 | cut -d= -f2- ; }
PROJECT_TYPE="$(get project_type)"
LANGUAGE="$(get language)"
LANGUAGES_ALL="$(get languages_all)"
FRAMEWORK="$(get framework)"
FRAMEWORKS_ALL="$(get frameworks_all)"
CI_SYSTEM="$(get ci_system)"
TOOLS_DETECTED="$(get tools_detected)"
HAS_GIT="$(get has_git)"
HAS_TESTS="$(get has_tests)"

# --- 7. Capability probe ----------------------------------------------------
CAP_OUT="$(bash "$REPO_ROOT/scripts/dispatch/detect-capabilities.sh" --profile 2>/dev/null)"
cap() { echo "$CAP_OUT" | grep "^$1=" | head -1 | cut -d= -f2- ; }
CAP_EXECUTION="$(cap cap_execution)"
CAP_GRAPH="$(cap cap_graph)"
CAP_MCP="$(cap cap_mcp)"
CAP_CI="$(cap cap_ci)"
CAP_SUBAGENT="$(cap cap_subagent)"
CAP_SCORE="$(cap cap_score)"
[ -z "$CAP_SCORE" ] && CAP_SCORE=0

# --- 8. Default intensity from capability score -----------------------------
RECOMMENDED_INTENSITY="standard"
if [ "$CAP_SCORE" -le 1 ] 2>/dev/null; then
  RECOMMENDED_INTENSITY="quick"
elif [ "$CAP_SCORE" -ge 4 ] 2>/dev/null; then
  RECOMMENDED_INTENSITY="full"
fi

# --- 9. Compute instruction file path per runtime ---------------------------
case "$RUNTIME" in
  claude-code) INSTRUCTION_FILE="$PROJECT_DIR/CLAUDE.md" ;;
  codex)       INSTRUCTION_FILE="$PROJECT_DIR/AGENTS.md" ;;
  cursor)      INSTRUCTION_FILE="$PROJECT_DIR/.cursor/rules/orchestrator.md" ;;
esac

PROJECT_NAME="$(basename "$PROJECT_DIR")"
INITIALIZED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- 10. Dry-run short-circuit ----------------------------------------------
if [ $DRY_RUN -eq 1 ]; then
  echo "would_write=$CONFIG_FILE"
  echo "would_write=$INSTRUCTION_FILE"
  echo "would_invoke=$REPO_ROOT/packaging/install/install-$RUNTIME.sh --project-dir $PROJECT_DIR --dry-run"
  echo "SUMMARY: project_type=$PROJECT_TYPE runtime=$RUNTIME instruction_file=$INSTRUCTION_FILE config_file=$CONFIG_FILE cap_score=$CAP_SCORE recommended_intensity=$RECOMMENDED_INTENSITY next_step=run_orchestrator_evaluate"
  exit 0
fi

# --- 11. Render template ----------------------------------------------------
# sed with `|` delimiter — values are sourced only from controlled detectors
# (detect-project, detect-capabilities, detect-runtime) which never emit `|`.
render_template() {
  local tpl="$1"
  sed \
    -e "s|{{project_name}}|$PROJECT_NAME|g" \
    -e "s|{{project_type}}|$PROJECT_TYPE|g" \
    -e "s|{{language}}|$LANGUAGE|g" \
    -e "s|{{languages_all}}|$LANGUAGES_ALL|g" \
    -e "s|{{framework}}|$FRAMEWORK|g" \
    -e "s|{{frameworks_all}}|$FRAMEWORKS_ALL|g" \
    -e "s|{{ci_system}}|$CI_SYSTEM|g" \
    -e "s|{{tools_detected}}|$TOOLS_DETECTED|g" \
    -e "s|{{has_git}}|$HAS_GIT|g" \
    -e "s|{{has_tests}}|$HAS_TESTS|g" \
    -e "s|{{cap_execution}}|$CAP_EXECUTION|g" \
    -e "s|{{cap_graph}}|$CAP_GRAPH|g" \
    -e "s|{{cap_mcp}}|$CAP_MCP|g" \
    -e "s|{{cap_ci}}|$CAP_CI|g" \
    -e "s|{{cap_subagent}}|$CAP_SUBAGENT|g" \
    -e "s|{{cap_score}}|$CAP_SCORE|g" \
    -e "s|{{runtime}}|$RUNTIME|g" \
    -e "s|{{runtime_confidence}}|${RUNTIME_CONFIDENCE:-unknown}|g" \
    -e "s|{{instruction_file_path}}|$INSTRUCTION_FILE|g" \
    -e "s|{{state_root}}|$STATE_ROOT_ABS|g" \
    -e "s|{{recommended_intensity}}|$RECOMMENDED_INTENSITY|g" \
    -e "s|{{initialized_at}}|$INITIALIZED_AT|g" \
    "$tpl"
}

# --- 12. Write instruction file ---------------------------------------------
mkdir -p "$(dirname "$INSTRUCTION_FILE")"
render_template "$REPO_ROOT/templates/project-instruction.md" > "$INSTRUCTION_FILE"
log "wrote=$INSTRUCTION_FILE"

# --- 13. Write config.yml ---------------------------------------------------
mkdir -p "$STATE_ROOT_ABS"
cat > "$CONFIG_FILE" <<EOF
# Generated by orchestrator:init on $INITIALIZED_AT
schema_version: "1.0"
state_root: "$STATE_ROOT_ABS"
runtime: "$RUNTIME"
default_intensity: "$RECOMMENDED_INTENSITY"
initialized_at: "$INITIALIZED_AT"
project:
  type: "$PROJECT_TYPE"
  language: "$LANGUAGE"
  framework: "$FRAMEWORK"
  ci_system: "$CI_SYSTEM"
  tools_detected: "$TOOLS_DETECTED"
capabilities:
  execution: "$CAP_EXECUTION"
  graph: $CAP_GRAPH
  mcp: $CAP_MCP
  ci: $CAP_CI
  subagent: $CAP_SUBAGENT
  score: $CAP_SCORE
EOF
log "wrote=$CONFIG_FILE"

# --- 14. Delegate installer -------------------------------------------------
# Per-runtime installers: packaging/install/install-claude-code.sh,
# packaging/install/install-codex.sh, packaging/install/install-cursor.sh.
INSTALLER="$REPO_ROOT/packaging/install/install-$RUNTIME.sh"
if [ ! -x "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

install_args="--project-dir \"$PROJECT_DIR\""
[ $FORCE -eq 1 ]   && install_args="$install_args --force"
[ $VERBOSE -eq 1 ] && install_args="$install_args --verbose"

# eval used intentionally with script-internal args only (no user input).
INSTALL_OUT="$(eval "bash \"$INSTALLER\" $install_args" 2>&1)"
INSTALL_RC=$?
[ $VERBOSE -eq 1 ] && printf '%s\n' "$INSTALL_OUT" >&2

SKILLS_INSTALLED="$(echo "$INSTALL_OUT" | grep 'skills_installed=' | head -1 | sed 's/.*skills_installed=\([0-9]*\).*/\1/')"
[ -z "$SKILLS_INSTALLED" ] && SKILLS_INSTALLED=0

if [ "$INSTALL_RC" -ne 0 ]; then
  echo "FAIL: installer exited $INSTALL_RC" >&2
  printf '%s\n' "$INSTALL_OUT" >&2
  exit 1
fi

# --- 15. Summary ------------------------------------------------------------
echo "SUMMARY: project_type=$PROJECT_TYPE runtime=$RUNTIME instruction_file=$INSTRUCTION_FILE config_file=$CONFIG_FILE cap_score=$CAP_SCORE recommended_intensity=$RECOMMENDED_INTENSITY skills_installed=$SKILLS_INSTALLED next_step=run_orchestrator_evaluate"
exit 0
