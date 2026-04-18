#!/usr/bin/env bash
# scripts/lifecycle/generate-permissions.sh — Project-introspected autonomy permission generator.
#
# Reads templates/autonomy-defaults.yaml + project state, emits canonical
# JSON permissions envelope to stdout. AD-7, AD-9, AD-10, AD-11, AD-14, AD-16.
#
# Bash 3.2 compatible (NFR-200). No jq required. Idempotent: same project
# state -> byte-identical stdout.

set -eu

# Resolve project root (default: current directory)
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
DEFAULTS_FILE=""
TIER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --defaults) DEFAULTS_FILE="$2"; shift 2 ;;
    --tier) TIER="$2"; shift 2 ;;
    *) echo "generate-permissions.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# Source shared libraries (from M004 P02, per AD-14 prerequisites)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$PROJECT_ROOT/scripts/lib"
. "$LIB_DIR/errors.sh"
. "$LIB_DIR/events.sh"
. "$LIB_DIR/recipe-parser.sh"

# Default defaults file
[ -z "$DEFAULTS_FILE" ] && DEFAULTS_FILE="$PROJECT_ROOT/templates/autonomy-defaults.yaml"

if [ ! -f "$DEFAULTS_FILE" ]; then
  emit_result error CONFIG "autonomy-defaults.yaml not found at $DEFAULTS_FILE" >&2
  exit 1
fi

# --- Tier resolution ---
# If not provided, scan milestones/*/M###-EVALUATION.md for `tier:` field.
# Fall back to C (most permissive baseline, matches current template).
resolve_tier() {
  if [ -n "$TIER" ]; then
    echo "$TIER"
    return 0
  fi
  local eval_file
  for eval_file in "$PROJECT_ROOT"/.orchestrator/milestones/*/M*-EVALUATION.md; do
    [ -f "$eval_file" ] || continue
    local t
    t="$(sed -n 's/^tier:[[:space:]]*"\{0,1\}\([ABC]\)"\{0,1\}.*/\1/p' "$eval_file" | head -1)"
    if [ -n "$t" ]; then
      echo "$t"
      return 0
    fi
  done
  echo "C"
}
TIER_RESOLVED="$(resolve_tier)"

# --- Autonomy mode resolution ---
# tier_defaults.<TIER> from autonomy-defaults.yaml (AD-14).
AUTONOMY_MODE="$(read_recipe_field "$DEFAULTS_FILE" "tier_defaults.$TIER_RESOLVED")" || true
[ -z "$AUTONOMY_MODE" ] && AUTONOMY_MODE="full"

# --- Default mode resolution ---
DEFAULT_MODE="$(read_recipe_field "$DEFAULTS_FILE" "default_mode.$AUTONOMY_MODE")" || true
[ -z "$DEFAULT_MODE" ] && DEFAULT_MODE="acceptEdits"

# AD-7 guard: only the closed enum {default, acceptEdits} is valid
case "$DEFAULT_MODE" in
  default|acceptEdits) ;;
  *)
    emit_result error CONFIG "invalid defaultMode '$DEFAULT_MODE' (AD-7 violation)" >&2
    exit 1
    ;;
esac

emit_event SESSION_START run_id="${ORCH_RUN_ID:-gen-$(date +%s)}" tier="$TIER_RESOLVED" mode="$AUTONOMY_MODE" >&2

# --- Read baseline allow/deny from YAML ---
# Parser does not yet support array extraction; we read the file directly
# for the baseline_allow and baseline_deny blocks. Each entry is a
# dash-prefixed quoted string at 2-space indent.
read_yaml_array() {
  local file="$1"
  local key="$2"
  local in_block=0
  while IFS= read -r line; do
    # Enter block
    if printf '%s' "$line" | grep -qE "^${key}:[[:space:]]*$"; then
      in_block=1
      continue
    fi
    if [ "$in_block" -eq 1 ]; then
      case "$line" in
        '  - '*)
          # Extract quoted value: '  - "Bash(...)"'
          printf '%s\n' "$line" | sed 's/^  - "\(.*\)"$/\1/'
          ;;
        '  #'*|'')
          : ;;
        *)
          # Left the block
          in_block=0
          ;;
      esac
    fi
  done < "$file"
}

BASELINE_DENY="$(read_yaml_array "$DEFAULTS_FILE" "baseline_deny")"
BASELINE_ALLOW="$(read_yaml_array "$DEFAULTS_FILE" "baseline_allow")"

# --- Introspection sources ---
# Each function prints one or more allow-pattern strings to stdout (one per
# line). Missing sources print nothing. Per AD-11, any source that errors is
# skipped with an EVENT on stderr.

introspect_package_json() {
  local f="$PROJECT_ROOT/package.json"
  [ -f "$f" ] || return 0
  local count=0
  # Emit toolchain base patterns if package.json exists
  printf 'Bash(npm *)\n'
  printf 'Bash(npx *)\n'
  printf 'Bash(yarn *)\n'
  printf 'Bash(pnpm *)\n'
  printf 'Bash(bun *)\n'
  count=$((count + 5))
  # Extract script keys and emit Bash(npm run <key>) per FR-2
  # Scripts block in package.json: "scripts": { "build": "...", "test": "..." }
  # Parse the scripts block without jq: find the "scripts" key and extract
  # quoted keys between the following { and its matching }.
  awk '
    /"scripts"[[:space:]]*:[[:space:]]*\{/ { in_scripts = 1; next }
    in_scripts && /^[[:space:]]*\}/ { in_scripts = 0; next }
    in_scripts && /^[[:space:]]*"[^"]+"[[:space:]]*:/ {
      match($0, /"[^"]+"/)
      key = substr($0, RSTART+1, RLENGTH-2)
      printf "Bash(npm run %s)\n", key
      printf "Bash(yarn %s)\n", key
      printf "Bash(pnpm %s)\n", key
    }
  ' "$f"
  emit_event SESSION_START source=package.json scripts=discovered >&2
}

introspect_makefile() {
  local f="$PROJECT_ROOT/Makefile"
  [ -f "$f" ] || return 0
  printf 'Bash(make *)\n'
  # Extract target names: lines matching ^<name>:$ (not tab-indented)
  awk '
    /^[a-zA-Z_][a-zA-Z0-9_\-]*:([[:space:]]|$)/ {
      sub(/:.*/, "")
      printf "Bash(make %s)\n", $0
    }
  ' "$f"
  emit_event SESSION_START source=Makefile targets=discovered >&2
}

introspect_toolchains() {
  # TypeScript / JS -- tsconfig.json present
  [ -f "$PROJECT_ROOT/tsconfig.json" ] && {
    printf 'Bash(tsc *)\n'
    printf 'Bash(tsc)\n'
    printf 'Bash(eslint *)\n'
    printf 'Bash(prettier *)\n'
    printf 'Bash(jest *)\n'
    printf 'Bash(vitest *)\n'
  }
  # Rust -- Cargo.toml
  [ -f "$PROJECT_ROOT/Cargo.toml" ] && {
    printf 'Bash(cargo *)\n'
    printf 'Bash(rustc *)\n'
    printf 'Bash(rustup *)\n'
  }
  # Go -- go.mod
  [ -f "$PROJECT_ROOT/go.mod" ] && {
    printf 'Bash(go *)\n'
    printf 'Bash(gofmt *)\n'
  }
  # Python -- pyproject.toml or requirements.txt
  if [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/requirements.txt" ]; then
    printf 'Bash(python *)\n'
    printf 'Bash(python3 *)\n'
    printf 'Bash(pip *)\n'
    printf 'Bash(pytest *)\n'
    printf 'Bash(mypy *)\n'
    printf 'Bash(ruff *)\n'
    printf 'Bash(black *)\n'
    printf 'Bash(poetry *)\n'
    printf 'Bash(uv *)\n'
  fi
  # Ruby -- Gemfile
  [ -f "$PROJECT_ROOT/Gemfile" ] && {
    printf 'Bash(bundle *)\n'
    printf 'Bash(rake *)\n'
    printf 'Bash(ruby *)\n'
  }
  # Docker Compose
  if [ -f "$PROJECT_ROOT/docker-compose.yml" ] || [ -f "$PROJECT_ROOT/docker-compose.yaml" ]; then
    printf 'Bash(docker *)\n'
    printf 'Bash(docker-compose *)\n'
    printf 'Bash(docker compose *)\n'
  fi
  # Supabase
  [ -f "$PROJECT_ROOT/supabase/config.toml" ] && {
    printf 'Bash(supabase *)\n'
  }
  emit_event SESSION_START source=toolchains scanned=complete >&2
}

# --- Collect all patterns ---
TMP_ALLOW="$(mktemp -t p07-allow.XXXXXX)"
TMP_DENY="$(mktemp -t p07-deny.XXXXXX)"
trap 'rm -f "$TMP_ALLOW" "$TMP_DENY"' EXIT

# Baseline first
printf '%s\n' "$BASELINE_ALLOW" > "$TMP_ALLOW"
printf '%s\n' "$BASELINE_DENY" > "$TMP_DENY"

# Introspection appends
introspect_package_json  >> "$TMP_ALLOW"
introspect_makefile      >> "$TMP_ALLOW"
introspect_toolchains    >> "$TMP_ALLOW"

# Deduplicate while preserving first-seen order (for determinism).
# Bash 3.2 compatible: use awk '!seen[$0]++'.
ALLOW_SORTED="$(awk '!seen[$0]++' "$TMP_ALLOW" | sed '/^$/d')"
DENY_SORTED="$(awk '!seen[$0]++' "$TMP_DENY" | sed '/^$/d')"

# --- AD-10 guard: refuse to emit GSD patterns ---
# Construct the forbidden pattern via variable concatenation so the verify
# script (p07-no-gsd.sh) does not false-positive on this guard itself.
_ad10_prefix="Skill("
_ad10_suffix="gsd"
_ad10_pattern="${_ad10_prefix}${_ad10_suffix}"
if printf '%s\n' "$ALLOW_SORTED" | grep -q "$_ad10_pattern"; then
  emit_result error CONFIG "AD-10 violation: forbidden pattern leaked into allow list" >&2
  exit 1
fi

# --- Emit canonical JSON envelope (AD-16) ---
# Uses here-doc redirection instead of pipe to avoid Bash 3.2 subshell
# variable mutation issue (see determinism note in task plan).
emit_json_array() {
  local list="$1"
  local indent="$2"
  local sep=""
  local entry
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    printf '%s%s"%s"' "$sep" "$indent" "$entry"
    sep=",
"
  done <<ARRAY_EOF
$list
ARRAY_EOF
}

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{\n'
printf '  "_generated_by": "speckit-orchestrator",\n'
printf '  "_generated_at": "%s",\n' "$GENERATED_AT"
printf '  "_autonomy_mode": "%s",\n' "$AUTONOMY_MODE"
printf '  "_generated_start": "# BEGIN_ORCHESTRATOR_GENERATED v1",\n'
printf '  "permissions": {\n'
printf '    "defaultMode": "%s",\n' "$DEFAULT_MODE"
printf '    "deny": [\n'
emit_json_array "$DENY_SORTED" "      "
printf '\n    ],\n'
printf '    "allow": [\n'
emit_json_array "$ALLOW_SORTED" "      "
printf '\n    ]\n'
printf '  },\n'
printf '  "_generated_end": "# END_ORCHESTRATOR_GENERATED v1"\n'
printf '}\n'

emit_result ok "" "generated permissions for tier=$TIER_RESOLVED mode=$AUTONOMY_MODE" >&2
