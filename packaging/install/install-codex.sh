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

# --- 5. Summary line ---
echo "SUMMARY: runtime=codex skills_installed=${skills_installed} hooks_wired=${hooks_wired} config_written=${config_written} dry_run=${DRY_RUN}"
exit 0
