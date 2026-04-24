#!/usr/bin/env bash
# packaging/install/install-claude-code.sh -- Single-command Claude Code installer.
#
# Delegates all runtime-specific work to the P05 adapter:
#   scripts/dispatch/adapters/runtime/claude-code.sh
#
# Responsibilities beyond the adapter:
#   * Invoke --probe, fail fast if the runtime is unavailable.
#   * Delegate skill registration via --register [--dry-run].
#   * Capture --hook-config output and write it to $HOME/.claude/settings.json
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

# Resolve installer paths relative to this file so it works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# packaging/install/install-claude-code.sh -> repo root is 2 levels up
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/runtime/claude-code.sh"
RESOLVE_ROOT="$REPO_ROOT/scripts/state/resolve-root.sh"
BUNDLE="$REPO_ROOT/packaging/bundle"

PROJECT_DIR="$PWD"
DRY_RUN=0
FORCE=0
VERBOSE=0
UNINSTALL=0

# --- Argument parsing (while-case, bash 3.2 safe) ---
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
      sed -n '2,32p' "$0"
      exit 0 ;;
    *)
      echo "FAIL: unknown argument '$1'" >&2
      exit 1 ;;
  esac
done

log() { [ "$VERBOSE" = "1" ] && echo "[install-claude-code] $*" >&2 || true; }

# --- HOME guard (matches P05 adapter) ---
if [ -z "${HOME:-}" ] || [ "${HOME}" = "/" ]; then
  echo "FAIL: unsafe HOME (empty or '/'): refusing to install" >&2
  exit 2
fi

MERGE_HELPER="$REPO_ROOT/scripts/util/settings-merge.sh"

# --- Uninstall short-circuit (M025/P01/T02) ---
# When --uninstall is set, skip probe/register/config-stage and only remove
# orchestrator-tagged entries from ~/.claude/settings.json plus any
# orchestrator-written config.yml (gated by a marker comment).
if [ "$UNINSTALL" = "1" ]; then
  hook_target="$HOME/.claude/settings.json"
  hooks_removed=0
  config_removed=0
  runtime_removed=0

  if [ -f "$MERGE_HELPER" ] && [ -e "$hook_target" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      un_out="$(bash "$MERGE_HELPER" uninstall --target "$hook_target" --dry-run 2>&1)"
    else
      un_out="$(bash "$MERGE_HELPER" uninstall --target "$hook_target" 2>&1)"
    fi
    un_rc=$?
    printf '%s\n' "$un_out"
    if [ $un_rc -ne 0 ]; then
      echo "FAIL: settings-merge.sh uninstall exited $un_rc" >&2
      exit 1
    fi
    hooks_removed="$(printf '%s\n' "$un_out" | sed -n 's/^removed=\([0-9][0-9]*\)$/\1/p' | head -n 1)"
    [ -z "$hooks_removed" ] && hooks_removed=0
  fi

  # Resolve state root to locate a possibly-staged config.yml.
  state_root=""
  if [ -x "$RESOLVE_ROOT" ]; then
    state_root="$(cd "$PROJECT_DIR" && bash "$RESOLVE_ROOT" --absolute 2>/dev/null)"
  fi
  [ -z "$state_root" ] && state_root="$PROJECT_DIR/.orchestrator"
  cfg_target="$state_root/config.yml"
  if [ -f "$cfg_target" ]; then
    if grep -q '_orchestrator_managed' "$cfg_target" 2>/dev/null; then
      if [ "$DRY_RUN" = "1" ]; then
        echo "would_remove=$cfg_target"
      else
        rm -f "$cfg_target"
        echo "removed=$cfg_target"
      fi
      config_removed=1
    fi
  fi

  # Remove runtime files recorded in the install manifest.
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
    # Prune empty runtime directories bottom-up.
    if [ "$DRY_RUN" = "0" ]; then
      for d in scripts templates references; do
        [ -d "$PROJECT_DIR/$d" ] && find "$PROJECT_DIR/$d" -type d -empty -depth -exec rmdir {} \; 2>/dev/null || true
      done
      rm -f "$manifest_file"
    fi
  elif [ "$DRY_RUN" = "0" ] && [ -d "$PROJECT_DIR/scripts" ]; then
    echo "WARN: manifest $manifest_file missing; refusing to guess removal" >&2
  fi

  echo "UNINSTALLED: hooks-removed=${hooks_removed} config-removed=${config_removed} runtime-removed=${runtime_removed}"
  exit 0
fi

# --- Sanity: adapter exists ---
if [ ! -f "$ADAPTER" ]; then
  echo "FAIL: adapter not found at $ADAPTER" >&2
  exit 1
fi

# --- 1. Probe ---
log "probing claude-code runtime"
probe_out="$(bash "$ADAPTER" --probe 2>&1)"
probe_rc=$?
if [ $probe_rc -ne 0 ]; then
  echo "FAIL: probe exited $probe_rc: $probe_out" >&2
  exit 1
fi
echo "$probe_out" | grep -q '^available=true'
if [ $? -ne 0 ]; then
  echo "FAIL: claude-code not available" >&2
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
  # Extract count from `dry_run=true count=<N>` or `would_write=` lines.
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

# --- 3. Wire hooks: merge-not-overwrite into settings.json (M025/P01/T02) ---
# The adapter emits a Claude Code hooks fragment tagged with
# "_orchestrator_managed": true on every leaf. The merge helper
# (scripts/util/settings-merge.sh) preserves any pre-existing user-authored
# keys byte-identically and only appends orchestrator entries that are not
# already present (idempotent on repeat install). --force bypasses the
# idempotency guard so manual edits that stripped the managed tag can be
# recovered. Writes via temp-file-then-rename.
log "capturing hook-config"
hook_json="$(bash "$ADAPTER" --hook-config 2>/dev/null)"
hook_target="$HOME/.claude/settings.json"
hooks_wired=0

if [ ! -f "$MERGE_HELPER" ]; then
  echo "FAIL: settings-merge helper not found at $MERGE_HELPER" >&2
  exit 1
fi

mkdir -p "$HOME/.claude"

merge_args="merge --target $hook_target"
if [ "$DRY_RUN" = "1" ]; then
  if [ "$FORCE" = "1" ]; then
    bash "$MERGE_HELPER" merge --target "$hook_target" --fragment "$hook_json" --force --dry-run
  else
    bash "$MERGE_HELPER" merge --target "$hook_target" --fragment "$hook_json" --dry-run
  fi
  merge_rc=$?
else
  if [ "$FORCE" = "1" ]; then
    bash "$MERGE_HELPER" merge --target "$hook_target" --fragment "$hook_json" --force
  else
    bash "$MERGE_HELPER" merge --target "$hook_target" --fragment "$hook_json"
  fi
  merge_rc=$?
fi
if [ $merge_rc -ne 0 ]; then
  echo "FAIL: settings-merge.sh merge exited $merge_rc" >&2
  exit 1
fi
hooks_wired=1

# --- 4. Stage orchestrator config into project state root ---
log "resolving state root for $PROJECT_DIR"
state_root=""
if [ -x "$RESOLVE_ROOT" ]; then
  # Invoke resolve-root.sh from the project dir so it walks the correct tree.
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

# --- 4.5 Stage runtime (scripts/, templates/, references/) into project ---
# Every commands/*.md invokes helpers via project-relative paths (e.g.
# `bash scripts/state/find-active-milestone.sh`). Without this stage, the
# first command after orchestrator:init dies with No such file or directory.
# Direction 1 from installer-staging-handoff: stage source trees directly
# from $REPO_ROOT. Runtime is orchestrator-owned; copy is always unconditional.
RUNTIME_DIRS="scripts templates references"
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
echo "SUMMARY: runtime=claude-code skills_installed=${skills_installed} hooks_wired=${hooks_wired} config_written=${config_written} runtime_staged=${runtime_staged} dry_run=${DRY_RUN}"
exit 0
