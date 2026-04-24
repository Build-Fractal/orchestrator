#!/usr/bin/env bash
# packaging/install/install-cursor.sh -- Single-command Cursor installer.
#
# Delegates all runtime-specific work to the P05 adapter:
#   scripts/dispatch/adapters/runtime/cursor.sh
#
# Cursor is project-scoped (not HOME-scoped): it writes rules under
# <project-dir>/.cursor/rules/ and has no lifecycle-hook API. Consequently:
#   * --project-dir PATH is REQUIRED (vs optional for claude-code/codex).
#   * Hook wiring is a no-op; the installer reports hooks_wired=0.
#
# Responsibilities beyond the adapter:
#   * Invoke --probe (via --project-dir), fail fast if unavailable.
#   * Delegate skill registration via --register --project-dir [--dry-run].
#   * Emit the adapter's --hook-config fragment to stdout for transparency,
#     but do not write it anywhere (Cursor has no settings target).
#   * Stage packaging/bundle/config/orchestrator.default.yml into the project
#     orchestrator state root resolved via scripts/state/resolve-root.sh.
#   * Print a final `SUMMARY:` line with counts.
#
# Shared flag contract (see T03-PLAN):
#   --project-dir PATH   project root (REQUIRED for cursor)
#   --dry-run            no writes; emit `would_write=<path>` lines
#   --force              overwrite existing orchestrator config
#   --verbose            extra debug output on stderr
#
# Exit codes:
#   0 success
#   1 generic failure (with FAIL: on stderr) -- includes missing --project-dir
#   2 unsafe environment (HOME='/' defensive parity)
#   3 runtime unavailable (probe returned available=false)
#
# Bash 3.2 compatible. No associative arrays, mapfile, jq, or python.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/runtime/cursor.sh"
RESOLVE_ROOT="$REPO_ROOT/scripts/state/resolve-root.sh"
BUNDLE="$REPO_ROOT/packaging/bundle"

PROJECT_DIR=""
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
      sed -n '2,33p' "$0"
      exit 0 ;;
    *)
      echo "FAIL: unknown argument '$1'" >&2
      exit 1 ;;
  esac
done

log() { [ "$VERBOSE" = "1" ] && echo "[install-cursor] $*" >&2 || true; }

# --- Cursor requires --project-dir ---
if [ -z "$PROJECT_DIR" ]; then
  echo "FAIL: --project-dir is required for cursor" >&2
  exit 1
fi

# --- Project-dir guard (match adapter) ---
if [ "$PROJECT_DIR" = "/" ]; then
  echo "FAIL: unsafe --project-dir ('/'): refusing to install" >&2
  exit 2
fi

# --- HOME guard -- defensive parity with claude-code/codex installers. ---
# Cursor writes only under PROJECT_DIR, but a HOME='/' environment still
# signals a dangerously misconfigured shell. Empty HOME is tolerated.
if [ "${HOME:-}" = "/" ]; then
  echo "FAIL: unsafe HOME ('/'): refusing to install" >&2
  exit 2
fi

# --- Uninstall short-circuit: remove staged runtime per manifest. ---
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
      for d in scripts templates references; do
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

# --- 1. Probe (pass --project-dir so adapter checks for .cursor/) ---
log "probing cursor runtime with --project-dir=$PROJECT_DIR"
probe_out="$(bash "$ADAPTER" --probe --project-dir "$PROJECT_DIR" 2>&1)"
probe_rc=$?
if [ $probe_rc -ne 0 ]; then
  echo "FAIL: probe exited $probe_rc: $probe_out" >&2
  exit 1
fi
echo "$probe_out" | grep -q '^available=true'
if [ $? -ne 0 ]; then
  echo "FAIL: cursor not available" >&2
  echo "$probe_out" >&2
  exit 3
fi

# --- 2. Register skills (delegate to adapter with --project-dir) ---
log "registering skills via adapter --register --project-dir $PROJECT_DIR"
skills_installed=0
if [ "$DRY_RUN" = "1" ]; then
  reg_out="$(bash "$ADAPTER" --register --project-dir "$PROJECT_DIR" --dry-run 2>&1)"
  reg_rc=$?
  printf '%s\n' "$reg_out"
  if [ $reg_rc -ne 0 ]; then
    echo "FAIL: adapter --register --dry-run exited $reg_rc" >&2
    exit 1
  fi
  skills_installed="$(printf '%s\n' "$reg_out" | sed -n 's/^dry_run=true count=\([0-9][0-9]*\)$/\1/p' | head -n 1)"
  [ -z "$skills_installed" ] && skills_installed=0
else
  reg_out="$(bash "$ADAPTER" --register --project-dir "$PROJECT_DIR" 2>&1)"
  reg_rc=$?
  printf '%s\n' "$reg_out"
  if [ $reg_rc -ne 0 ]; then
    echo "FAIL: adapter --register exited $reg_rc" >&2
    exit 1
  fi
  skills_installed="$(printf '%s\n' "$reg_out" | sed -n 's/^registered=true count=\([0-9][0-9]*\)$/\1/p' | head -n 1)"
  [ -z "$skills_installed" ] && skills_installed=0
fi

# --- 3. Hook wiring: no-op for cursor. Emit the advisory fragment. ---
# Cursor has no lifecycle-hook API; the adapter's --hook-config returns a
# rules-only integration notice. We display it but write nothing.
log "capturing hook-config (advisory only; cursor has no hook target)"
hook_txt="$(bash "$ADAPTER" --hook-config 2>/dev/null)"
hooks_wired=0
if [ -n "$hook_txt" ]; then
  # Surface the advisory to stdout so operators see runtime=cursor hooks_supported=false.
  echo "hook_config_advisory<<<"
  printf '%s\n' "$hook_txt"
  echo ">>>"
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

# --- 4.5 Stage runtime (scripts/, templates/, references/) into project ---
# See install-claude-code.sh for the rationale (Direction 1 in
# installer-staging-handoff). Every commands/*.md invokes helpers via
# project-relative paths, so the runtime must live alongside the project.
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
echo "SUMMARY: runtime=cursor skills_installed=${skills_installed} hooks_wired=${hooks_wired} config_written=${config_written} runtime_staged=${runtime_staged} dry_run=${DRY_RUN}"
exit 0
