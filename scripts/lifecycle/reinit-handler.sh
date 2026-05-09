#!/usr/bin/env bash
# scripts/lifecycle/reinit-handler.sh — handle re-initialization of an
# already-configured project. Called by init-project.sh when existing
# <state_root>/config.yml is detected and --force is NOT set.
#
# Usage:
#   reinit-handler.sh --project-dir PATH --state-root PATH --runtime NAME
#                     [--mode update|reset|abort] [--dry-run] [--verbose]
#
# Modes:
#   update (default when invoked with --mode update)
#          Preserve the <!-- BEGIN CUSTOM --> ... <!-- END CUSTOM --> block
#          in the instruction file and preserve user-edited top-level keys in
#          config.yml. Refresh auto-detected sections (project:, capabilities:)
#          and bump initialized_at.
#   reset  Fully regenerate both files (delegates to init-project.sh --force).
#   abort  Exit 0 with no changes.
#
# Exit codes:
#   0 success (mode ran)
#   1 generic failure (FAIL: on stderr)
#   4 no --mode specified (non-interactive default — caller must re-invoke)
#
# Bash 3.2 compatible. No associative arrays, mapfile, jq, or python.
# Security note: `eval` is used solely to pass controlled flag strings built
# from script-internal state (never user input). Placeholder substitution
# uses sed with `|` delimiter; values come only from controlled detectors
# that never emit `|`.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_DIR=""
STATE_ROOT=""
RUNTIME=""
MODE=""
DRY_RUN=0
VERBOSE=0

# --- 1. Arg parsing ---------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)
      shift
      [ $# -eq 0 ] && { echo "FAIL: --project-dir requires a path argument" >&2; exit 1; }
      PROJECT_DIR="$1"; shift ;;
    --project-dir=*) PROJECT_DIR="${1#--project-dir=}"; shift ;;
    --state-root)
      shift
      [ $# -eq 0 ] && { echo "FAIL: --state-root requires a path argument" >&2; exit 1; }
      STATE_ROOT="$1"; shift ;;
    --state-root=*) STATE_ROOT="${1#--state-root=}"; shift ;;
    --runtime)
      shift
      [ $# -eq 0 ] && { echo "FAIL: --runtime requires a name argument" >&2; exit 1; }
      RUNTIME="$1"; shift ;;
    --runtime=*) RUNTIME="${1#--runtime=}"; shift ;;
    --mode)
      shift
      [ $# -eq 0 ] && { echo "FAIL: --mode requires a value (update|reset|abort)" >&2; exit 1; }
      MODE="$1"; shift ;;
    --mode=*) MODE="${1#--mode=}"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "FAIL: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

# Required args (Bash 3.2 safe -- no bash 4+ lowercasing parameter expansion).
for req in project-dir state-root runtime; do
  case "$req" in
    project-dir) v="$PROJECT_DIR" ;;
    state-root)  v="$STATE_ROOT"  ;;
    runtime)     v="$RUNTIME"     ;;
  esac
  [ -n "$v" ] || { echo "FAIL: --$req required" >&2; exit 1; }
done

# Canonicalize PROJECT_DIR to an absolute path so downstream consumers
# (basename → project_name, sed path substitutions) don't degrade when
# callers pass "." or other relative paths.
if [ -d "$PROJECT_DIR" ]; then
  PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
fi

log() { [ $VERBOSE -eq 1 ] && echo "$@" >&2; return 0; }

# --- 2. Resolve paths -------------------------------------------------------
CONFIG_FILE="$STATE_ROOT/config.yml"
case "$RUNTIME" in
  claude-code) INSTRUCTION_FILE="$PROJECT_DIR/CLAUDE.md" ;;
  codex)       INSTRUCTION_FILE="$PROJECT_DIR/AGENTS.md" ;;
  cursor)      INSTRUCTION_FILE="$PROJECT_DIR/.cursor/rules/orchestrator.md" ;;
  *) echo "FAIL: unknown runtime '$RUNTIME'" >&2; exit 1 ;;
esac

# --- 3. Non-interactive default (no --mode) ---------------------------------
if [ -z "$MODE" ]; then
  echo "REINIT: existing config at $CONFIG_FILE"
  echo "REINIT: re-run with --mode update (preserve custom), --mode reset (overwrite), or --mode abort"
  exit 4
fi

# --- 4. Mode: abort ---------------------------------------------------------
if [ "$MODE" = "abort" ]; then
  echo "SUMMARY: mode=abort runtime=$RUNTIME config_file=$CONFIG_FILE changes=0"
  exit 0
fi

# --- 5. Mode: reset ---------------------------------------------------------
# Delegate back to init-project.sh --force (avoid duplicating render logic).
if [ "$MODE" = "reset" ]; then
  init_args="--project-dir \"$PROJECT_DIR\" --runtime \"$RUNTIME\" --force"
  [ $DRY_RUN -eq 1 ] && init_args="$init_args --dry-run"
  [ $VERBOSE -eq 1 ] && init_args="$init_args --verbose"
  # eval used intentionally: args are script-internal state only, never user input.
  eval "bash \"$REPO_ROOT/scripts/lifecycle/init-project.sh\" $init_args"
  exit $?
fi

# --- 6. Mode: update --------------------------------------------------------
if [ "$MODE" != "update" ]; then
  echo "FAIL: unknown mode '$MODE' (expected update|reset|abort)" >&2
  exit 1
fi

[ -f "$CONFIG_FILE" ] || { echo "FAIL: no existing config at $CONFIG_FILE (update mode requires one)" >&2; exit 1; }

# --- 6a. Extract custom block from existing instruction file ----------------
extract_custom_block() {
  # Emit the lines strictly between BEGIN and END markers (exclusive).
  # If markers are missing or mangled, emits nothing — lossy but predictable.
  awk '
    /^<!-- BEGIN CUSTOM -->$/ { inblock=1; next }
    /^<!-- END CUSTOM -->$/   { inblock=0; next }
    inblock == 1              { print }
  ' "$1"
}

CUSTOM_BLOCK=""
if [ -f "$INSTRUCTION_FILE" ]; then
  CUSTOM_BLOCK="$(extract_custom_block "$INSTRUCTION_FILE")"
fi

# --- 6a-bis. Extract generic sentinel blocks (# >>> orchestrator:NAME >>>) --
# The handler regenerates the file from template; any sentinel-bounded
# region the user relies on (e.g. orchestrator:recent-changes) would
# otherwise be lost. We snapshot each sentinel's body (contents between
# markers, exclusive) to a temp dir keyed by NAME, then re-inject them
# after dual-write via the same dual-write-runtime-md.sh helper.
SENTINEL_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t sentinel)"
SENTINEL_NAMES=""
if [ -f "$INSTRUCTION_FILE" ]; then
  # List distinct sentinel names present in the file.
  SENTINEL_NAMES="$(grep -E '^# >>> orchestrator:[A-Za-z0-9_-]+ >>>$' "$INSTRUCTION_FILE" 2>/dev/null \
                    | sed 's/^# >>> orchestrator:\([A-Za-z0-9_-]*\) >>>$/\1/' \
                    | sort -u)"
  for _name in $SENTINEL_NAMES; do
    awk -v n="$_name" '
      $0 == "# >>> orchestrator:" n " >>>" { inblock=1; next }
      $0 == "# <<< orchestrator:" n " <<<" { inblock=0; next }
      inblock == 1 { print }
    ' "$INSTRUCTION_FILE" > "$SENTINEL_DIR/$_name.block"
  done
fi

# --- 6b. Re-run detection + capability probe --------------------------------
PROJECT_OUT="$(bash "$REPO_ROOT/scripts/lifecycle/detect-project.sh" --project-dir "$PROJECT_DIR" 2>/dev/null)"
CAP_OUT="$(bash "$REPO_ROOT/scripts/dispatch/detect-capabilities.sh" --profile 2>/dev/null || true)"

get_p() { echo "$PROJECT_OUT" | grep "^$1=" | head -1 | cut -d= -f2- ; }
get_c() { echo "$CAP_OUT"     | grep "^$1=" | head -1 | cut -d= -f2- ; }

PROJECT_TYPE="$(get_p project_type)"
LANGUAGE="$(get_p language)"
LANGUAGES_ALL="$(get_p languages_all)"
FRAMEWORK="$(get_p framework)"
FRAMEWORKS_ALL="$(get_p frameworks_all)"
CI_SYSTEM="$(get_p ci_system)"
TOOLS_DETECTED="$(get_p tools_detected)"
HAS_GIT="$(get_p has_git)"
HAS_TESTS="$(get_p has_tests)"

CAP_EXECUTION="$(get_c cap_execution)"
CAP_GRAPH="$(get_c cap_graph)"
CAP_MCP="$(get_c cap_mcp)"
CAP_CI="$(get_c cap_ci)"
CAP_SUBAGENT="$(get_c cap_subagent)"
CAP_SCORE="$(get_c cap_score)"
[ -z "$CAP_SCORE" ] && CAP_SCORE=0

RECOMMENDED_INTENSITY="standard"
if [ "$CAP_SCORE" -le 1 ] 2>/dev/null; then
  RECOMMENDED_INTENSITY="quick"
elif [ "$CAP_SCORE" -ge 4 ] 2>/dev/null; then
  RECOMMENDED_INTENSITY="full"
fi

INITIALIZED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# Preserve the existing runtime_confidence. Config.yml doesn't currently
# persist this key, so we read it back from the instruction file where
# we originally rendered it (e.g. "- Detection confidence: `high`"). We
# only downgrade if the existing value is missing or already "unknown" —
# a previously-established "high" or "medium" is sticky.
RUNTIME_CONFIDENCE=""
if [ -f "$CONFIG_FILE" ]; then
  RUNTIME_CONFIDENCE="$(grep '^runtime_confidence:' "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/^runtime_confidence:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}.*/\1/')"
fi
if [ -z "$RUNTIME_CONFIDENCE" ] && [ -f "$INSTRUCTION_FILE" ]; then
  # Match the rendered line: "- Detection confidence: `high`"
  RUNTIME_CONFIDENCE="$(grep -i 'Detection confidence:' "$INSTRUCTION_FILE" 2>/dev/null | head -1 | sed 's/.*Detection confidence:[[:space:]]*`\{0,1\}\([^`]*\)`\{0,1\}.*/\1/' | tr -d ' ')"
fi
case "$RUNTIME_CONFIDENCE" in
  high|medium|low) ;;  # keep established value
  *) RUNTIME_CONFIDENCE="unknown" ;;
esac

# --- 6c. Dry-run short-circuit ---------------------------------------------
if [ $DRY_RUN -eq 1 ]; then
  has_block="false"
  [ -n "$CUSTOM_BLOCK" ] && has_block="true"
  echo "would_write=$INSTRUCTION_FILE (mode=update custom_block_preserved=$has_block)"
  echo "would_write=$CONFIG_FILE (mode=update preserve_user_fields=true)"
  echo "SUMMARY: mode=update runtime=$RUNTIME instruction_file=$INSTRUCTION_FILE config_file=$CONFIG_FILE dual_writes=0"
  exit 0
fi

# --- 6d. Render instruction template ---------------------------------------
# sed with `|` delimiter — values come only from controlled detectors that
# never emit `|`. Mirrors init-project.sh render_template.
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
    -e "s|{{runtime_confidence}}|$RUNTIME_CONFIDENCE|g" \
    -e "s|{{instruction_file_path}}|$INSTRUCTION_FILE|g" \
    -e "s|{{state_root}}|$STATE_ROOT|g" \
    -e "s|{{recommended_intensity}}|$RECOMMENDED_INTENSITY|g" \
    -e "s|{{initialized_at}}|$INITIALIZED_AT|g" \
    "$tpl"
}

mkdir -p "$(dirname "$INSTRUCTION_FILE")"
rendered="$(mktemp)"
render_template "$REPO_ROOT/templates/project-instruction.md" > "$rendered"

# --- 6e. Inject preserved custom block between markers ----------------------
# Portability: BSD awk does not accept multi-line values via -v. We write
# the custom block to a temp file and have awk splice it in via getline.
CUSTOM_BLOCK_PRESERVED="false"
if [ -n "$CUSTOM_BLOCK" ]; then
  block_file="$(mktemp)"
  # Preserve the block verbatim (trailing newline guaranteed by printf).
  printf '%s\n' "$CUSTOM_BLOCK" > "$block_file"

  merged="$(mktemp)"
  # Print the BEGIN marker, splice the preserved block, then suppress the
  # freshly rendered in-block lines until the END marker.
  awk -v blockfile="$block_file" '
    /^<!-- BEGIN CUSTOM -->$/ {
      print
      while ((getline line < blockfile) > 0) print line
      close(blockfile)
      inblock = 1
      next
    }
    /^<!-- END CUSTOM -->$/ { inblock = 0; print; next }
    inblock != 1            { print }
  ' "$rendered" > "$merged"

  mv -f "$merged" "$INSTRUCTION_FILE"
  rm -f "$rendered" "$block_file"
  CUSTOM_BLOCK_PRESERVED="true"
else
  mv -f "$rendered" "$INSTRUCTION_FILE"
fi
log "wrote=$INSTRUCTION_FILE (custom_block_preserved=$CUSTOM_BLOCK_PRESERVED)"

# --- Dual-write project-identity region (M014/P02 FR-12) ---
DUAL_WRITE_HELPER="$REPO_ROOT/scripts/util/dual-write-runtime-md.sh"
DUAL_WRITES=0
if [ -x "$DUAL_WRITE_HELPER" ]; then
  FRAG_FILE="$(mktemp)"
  {
    printf 'project_name=%s\n'           "$(basename "$PROJECT_DIR")"
    printf 'runtime=%s\n'                "$RUNTIME"
    printf 'cap_score=%s\n'              "${CAP_SCORE:-unknown}"
    printf 'recommended_intensity=%s\n'  "${RECOMMENDED_INTENSITY:-standard}"
    printf '# ^ Recommendation at init time. The OPERATIVE value lives in\n'
    printf '# .orchestrator/config.yml at intensity.default -- read that on\n'
    printf '# every plan-phase / dispatch / verify invocation.\n'
    printf 'initialized_at=%s\n'         "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$FRAG_FILE"

  if bash "$DUAL_WRITE_HELPER" \
      --marker project-identity \
      --content "$FRAG_FILE" \
      --root "$PROJECT_DIR" \
      --file CLAUDE.md --file AGENTS.md \
      >/dev/null 2>&1; then
    DUAL_WRITES=2
  else
    if bash "$DUAL_WRITE_HELPER" \
        --marker project-identity \
        --content "$FRAG_FILE" \
        --root "$PROJECT_DIR" \
        --file CLAUDE.md \
        >/dev/null 2>&1; then
      DUAL_WRITES=1
    else
      echo "WARN: reinit dual-write project-identity failed; continuing" >&2
    fi
  fi
  rm -f "$FRAG_FILE"
else
  echo "SKIPPED: dual-write-runtime-md.sh not executable (reinit)" >&2
fi
log "dual_writes=$DUAL_WRITES region=project-identity"

# --- 6e-bis. Re-inject preserved sentinel blocks (except project-identity) --
# dual-write-runtime-md.sh owns project-identity above; every other
# sentinel block the user had is re-splashed into the regenerated file
# using the same helper so insert/replace semantics match.
if [ -x "$DUAL_WRITE_HELPER" ] && [ -n "$SENTINEL_NAMES" ]; then
  for _name in $SENTINEL_NAMES; do
    [ "$_name" = "project-identity" ] && continue
    block_path="$SENTINEL_DIR/$_name.block"
    [ -f "$block_path" ] || continue
    if bash "$DUAL_WRITE_HELPER" \
        --marker "$_name" \
        --content "$block_path" \
        --root "$PROJECT_DIR" \
        --file "$(basename "$INSTRUCTION_FILE")" \
        >/dev/null 2>&1; then
      log "preserved_sentinel=$_name"
    else
      echo "WARN: could not re-inject sentinel '$_name' into $INSTRUCTION_FILE" >&2
    fi
  done
fi
rm -rf "$SENTINEL_DIR" 2>/dev/null || true

# --- 6f. Merge config.yml: strip project:/capabilities:, refresh, preserve rest ---
merged_cfg="$(mktemp)"

# Pass 1: strip existing project: and capabilities: blocks via awk state
# machine. A top-level key is `^[A-Za-z_][A-Za-z0-9_]*:` at column 0.
awk '
  BEGIN { skip = 0 }
  /^(project|capabilities):[[:space:]]*$/ { skip = 1; next }
  skip == 1 && /^[A-Za-z_][A-Za-z0-9_]*:/ { skip = 0 }
  skip == 1 { next }
  { print }
' "$CONFIG_FILE" > "$merged_cfg"

# Pass 2: update initialized_at in place (BSD/GNU-compatible sed -i.bak).
if grep -q '^initialized_at:' "$merged_cfg"; then
  sed -i.bak "s|^initialized_at:.*|initialized_at: \"$INITIALIZED_AT\"|" "$merged_cfg"
  rm -f "$merged_cfg.bak"
fi

# Pass 3: trim trailing blank lines, then append fresh project: +
# capabilities: blocks. We use awk to drop trailing empties to keep the
# file tidy across repeated updates.
trimmed="$(mktemp)"
awk '
  { lines[NR] = $0 }
  END {
    last = NR
    while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
    for (i = 1; i <= last; i++) print lines[i]
  }
' "$merged_cfg" > "$trimmed"
mv "$trimmed" "$merged_cfg"

cat >> "$merged_cfg" <<EOF

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

mv "$merged_cfg" "$CONFIG_FILE"
log "wrote=$CONFIG_FILE"

echo "SUMMARY: mode=update runtime=$RUNTIME instruction_file=$INSTRUCTION_FILE config_file=$CONFIG_FILE custom_block_preserved=$CUSTOM_BLOCK_PRESERVED dual_writes=$DUAL_WRITES"
exit 0
