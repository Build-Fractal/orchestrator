#!/usr/bin/env bash
# packaging/install/install-codex.sh -- Single-command Codex CLI installer.
#
# Delegates all runtime-specific work to the P05 adapter:
#   scripts/dispatch/adapters/runtime/codex.sh
#
# Responsibilities beyond the adapter:
#   * Invoke --probe, fail fast if the runtime is unavailable.
#   * Delegate skill registration via --register [--dry-run].
#   * Capture --hook-config TOML and write it to $HOME/.codex/config.toml
#     (or emit `would_write=` under --dry-run).
#   * Stage packaging/bundle/config/orchestrator.default.yml into the project
#     orchestrator state root resolved via scripts/state/resolve-root.sh.
#   * Print a final `SUMMARY:` line with counts.
#
# Shared flag contract (see T03-PLAN):
#   --project-dir PATH   project root (default: $PWD)
#   --dry-run            no writes; emit `would_write=<path>` lines
#   --force              overwrite existing hook config and orchestrator config
#   --verbose            extra debug output on stderr
#
# Exit codes:
#   0 success
#   1 generic failure (with FAIL: on stderr)
#   2 unsafe environment (empty or '/' HOME)
#   3 runtime unavailable (probe returned available=false)
#
# Bash 3.2 compatible. No associative arrays, mapfile, jq, or python.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/runtime/codex.sh"
RESOLVE_ROOT="$REPO_ROOT/scripts/state/resolve-root.sh"
BUNDLE="$REPO_ROOT/packaging/bundle"

PROJECT_DIR="$PWD"
DRY_RUN=0
FORCE=0
VERBOSE=0
UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: --project-dir requires a path argument" >&2
        exit 1
      fi
      PROJECT_DIR="$1"
      shift ;;
    --project-dir=*)
      PROJECT_DIR="${1#--project-dir=}"
      shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --force)
      FORCE=1; shift ;;
    --verbose)
      VERBOSE=1; shift ;;
    --uninstall)
      UNINSTALL=1; shift ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0 ;;
    *)
      echo "FAIL: unknown argument '$1'" >&2
      exit 1 ;;
  esac
done

log() { [ "$VERBOSE" = "1" ] && echo "[install-codex] $*" >&2 || true; }

# --- HOME guard (matches P05 adapter) ---
if [ -z "${HOME:-}" ] || [ "${HOME}" = "/" ]; then
  echo "FAIL: unsafe HOME (empty or '/'): refusing to install" >&2
  exit 2
fi

# --- Uninstall short-circuit: remove staged runtime per manifest. ---
# Codex hook-wiring writes $HOME/.codex/config.toml wholesale; uninstalling
# that is out of scope for this installer (user may have edits). This path
# only removes project-scoped orchestrator artifacts.
if [ "$UNINSTALL" = "1" ]; then
  runtime_removed=0
  config_removed=0

  state_root=""
  if [ -x "$RESOLVE_ROOT" ]; then
    state_root="$(cd "$PROJECT_DIR" && bash "$RESOLVE_ROOT" --absolute 2>/dev/null)"
  fi
  [ -z "$state_root" ] && state_root="$PROJECT_DIR/.orchestrator"
  cfg_target="$state_root/config.yml"
  if [ -f "$cfg_target" ] && grep -q '_orchestrator_managed' "$cfg_target" 2>/dev/null; then
    if [ "$DRY_RUN" = "1" ]; then
      echo "would_remove=$cfg_target"
    else
      rm -f "$cfg_target"
      echo "removed=$cfg_target"
    fi
    config_removed=1
  fi

  manifest_file="$PROJECT_DIR/.orchestrator/installed-files.txt"
  if [ -f "$manifest_file" ]; then
    while IFS= read -r rel; do
      [ -z "$rel" ] && continue
      f="$PROJECT_DIR/$rel"
      if [ -f "$f" ]; then
        if [ "$DRY_RUN" = "1" ]; then
          echo "would_remove=$f"
        else
          rm -f "$f"
        fi
        runtime_removed=$((runtime_removed + 1))
      fi
    done < "$manifest_file"
    if [ "$DRY_RUN" = "0" ]; then
      for d in scripts templates references commands; do
        [ -d "$PROJECT_DIR/$d" ] && find "$PROJECT_DIR/$d" -type d -empty -depth -exec rmdir {} \; 2>/dev/null || true
      done
      rm -f "$manifest_file"
    fi
  elif [ "$DRY_RUN" = "0" ] && [ -d "$PROJECT_DIR/scripts" ]; then
    echo "WARN: manifest $manifest_file missing; refusing to guess removal" >&2
  fi

  echo "UNINSTALLED: runtime-removed=${runtime_removed} config-removed=${config_removed}"
  exit 0
fi

if [ ! -f "$ADAPTER" ]; then
  echo "FAIL: adapter not found at $ADAPTER" >&2
  exit 1
fi

# --- 1. Probe ---
log "probing codex runtime"
probe_out="$(bash "$ADAPTER" --probe 2>&1)"
probe_rc=$?
if [ $probe_rc -ne 0 ]; then
  echo "FAIL: probe exited $probe_rc: $probe_out" >&2
  exit 1
fi
echo "$probe_out" | grep -q '^available=true'
if [ $? -ne 0 ]; then
  echo "FAIL: codex not available" >&2
  echo "$probe_out" >&2
  exit 3
fi

# --- 2. Register skills (delegate to adapter) ---
log "registering skills via adapter --register"
skills_installed=0
if [ "$DRY_RUN" = "1" ]; then
  reg_out="$(bash "$ADAPTER" --register --dry-run 2>&1)"
  reg_rc=$?
  printf '%s\n' "$reg_out"
  if [ $reg_rc -ne 0 ]; then
    echo "FAIL: adapter --register --dry-run exited $reg_rc" >&2
    exit 1
  fi
  skills_installed="$(printf '%s\n' "$reg_out" | sed -n 's/^dry_run=true count=\([0-9][0-9]*\)$/\1/p' | head -n 1)"
  [ -z "$skills_installed" ] && skills_installed=0
else
  reg_out="$(bash "$ADAPTER" --register 2>&1)"
  reg_rc=$?
  printf '%s\n' "$reg_out"
  if [ $reg_rc -ne 0 ]; then
    echo "FAIL: adapter --register exited $reg_rc" >&2
    exit 1
  fi
  skills_installed="$(printf '%s\n' "$reg_out" | sed -n 's/^registered=true count=\([0-9][0-9]*\)$/\1/p' | head -n 1)"
  [ -z "$skills_installed" ] && skills_installed=0
fi

# --- 3. Wire hooks: capture hook-config TOML, write to config.toml ---
log "capturing hook-config"
hook_toml="$(bash "$ADAPTER" --hook-config 2>/dev/null)"
hook_target="$HOME/.codex/config.toml"
hooks_wired=0

if [ "$DRY_RUN" = "1" ]; then
  echo "would_write=$hook_target"
  hooks_wired=1
else
  if [ -e "$hook_target" ] && [ "$FORCE" = "0" ]; then
    echo "SKIP: $hook_target exists (use --force to overwrite)"
  else
    mkdir -p "$HOME/.codex"
    printf '%s\n' "$hook_toml" > "$hook_target"
    echo "wrote=$hook_target"
    hooks_wired=1
  fi
fi

# --- 4. Stage orchestrator config into project state root ---
log "resolving state root for $PROJECT_DIR"
state_root=""
if [ -x "$RESOLVE_ROOT" ]; then
  state_root="$(cd "$PROJECT_DIR" && bash "$RESOLVE_ROOT" --absolute 2>/dev/null)"
fi
if [ -z "$state_root" ]; then
  state_root="$PROJECT_DIR/.orchestrator"
fi

cfg_src="$BUNDLE/config/orchestrator.default.yml"
cfg_target="$state_root/config.yml"
config_written=0

if [ ! -f "$cfg_src" ]; then
  echo "FAIL: bundle config not found at $cfg_src" >&2
  exit 1
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "would_write=$cfg_target"
  config_written=1
elif [ -e "$cfg_target" ] && [ "$FORCE" = "0" ]; then
  echo "SKIP: $cfg_target exists (use --force to overwrite)"
else
  mkdir -p "$state_root"
  cp "$cfg_src" "$cfg_target"
  echo "wrote=$cfg_target"
  config_written=1
fi

# --- 4.5 Stage runtime (scripts/, templates/, references/, commands/) into project ---
# See install-claude-code.sh for the rationale (Direction 1 in
# installer-staging-handoff). Every commands/*.md invokes helpers via
# project-relative paths, so the runtime must live alongside the project.
# `commands/` is staged because dispatched-agent prompts reference rubric
# files like `commands/plan-phase.md` from the project root (auto.md Stage 2).
RUNTIME_DIRS="scripts templates references commands"
manifest_file="$PROJECT_DIR/.orchestrator/installed-files.txt"
runtime_staged=0

for dir in $RUNTIME_DIRS; do
  src="$REPO_ROOT/$dir"
  dst="$PROJECT_DIR/$dir"
  if [ ! -d "$src" ]; then
    echo "FAIL: runtime source missing: $src" >&2
    exit 1
  fi
  if [ "$DRY_RUN" = "1" ]; then
    find "$src" -type f | while IFS= read -r f; do
      rel="${f#$src/}"
      echo "would_write=$dst/$rel"
    done
    count=$(find "$src" -type f | wc -l | tr -d ' ')
    runtime_staged=$((runtime_staged + count))
    continue
  fi
  mkdir -p "$dst"
  cp -R "$src/." "$dst/"
  count=$(find "$src" -type f | wc -l | tr -d ' ')
  runtime_staged=$((runtime_staged + count))
done

if [ "$DRY_RUN" = "0" ]; then
  mkdir -p "$(dirname "$manifest_file")"
  : > "$manifest_file"
  for dir in $RUNTIME_DIRS; do
    if [ -d "$PROJECT_DIR/$dir" ]; then
      ( cd "$PROJECT_DIR" && find "$dir" -type f ) >> "$manifest_file"
    fi
  done
  echo "staged=$runtime_staged files manifest=$manifest_file"
fi

# --- 5. Summary line ---
echo "SUMMARY: runtime=codex skills_installed=${skills_installed} hooks_wired=${hooks_wired} config_written=${config_written} runtime_staged=${runtime_staged} dry_run=${DRY_RUN}"
exit 0
