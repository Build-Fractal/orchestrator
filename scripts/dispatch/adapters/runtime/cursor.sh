#!/usr/bin/env bash
# scripts/dispatch/adapters/runtime/cursor.sh -- Cursor runtime adapter (best-effort)
#
# Uniform runtime-adapter interface (filename-registered, see P02 pattern):
#
#   --probe
#     Emits key=value lines on stdout describing whether Cursor is
#     available in the current environment. Exits 0 unconditionally.
#       available=true|false
#       runtime=cursor
#       reason=<signal-text>
#
#     Probe signals (any one is sufficient):
#       - $PROJECT_DIR/.cursor/ directory present
#       - $CURSOR_TRACE_ID environment variable set
#       - $CURSOR_SESSION_ID environment variable set
#       - $CURSOR_USER environment variable set
#
#   --register [--dry-run]
#     Installs orchestrator commands as project-level Cursor rule files
#     under $PROJECT_DIR/.cursor/rules/orchestrator-<cmd>.md, one per
#     commands/*.md in the repo root (excluding README.md per MEM008).
#     With --dry-run: emits `would_write=<path>` lines and writes nothing.
#     Without --dry-run: mkdir -p "$PROJECT_DIR/.cursor/rules" and copy,
#     then emit `registered=true count=<N>`.
#
#     Cursor scopes rules per-project (not HOME-scoped like Claude Code
#     or Codex CLI). `--project-dir <path>` overrides $PWD for hermetic
#     tests.
#
#     PROJECT_DIR guard: refuses to run when PROJECT_DIR is empty or "/".
#     HOME guard: additionally refuses when HOME is "/" (defensive parity
#     with claude-code.sh / codex.sh, even though no HOME writes occur).
#     Emits "FAIL: unsafe ..." on stderr and exits 2.
#
#   --hook-config
#     Emits a minimal TOML-shaped fragment on stdout. Cursor has no
#     lifecycle-hook API comparable to Claude Code or Codex CLI, so this
#     adapter advertises rules-only integration. No python3/jq dependency.
#
# Cursor conventions (cf. claude-code.sh, codex.sh):
#   - .cursor/rules/ is the per-project rules directory.
#   - No user-level ~/.cursor/skills/ equivalent exists.
#   - No lifecycle hooks; integration is via rules the agent reads.
#
# Bash 3.2 compatible. No associative arrays, no mapfile/readarray.

set -u

MODE=""
DRY_RUN=0
PROJECT_DIR=""

# --- Argument parsing (while-case loop, matching claude-code.sh style) ---

while [[ $# -gt 0 ]]; do
  case "$1" in
    --probe)
      MODE="probe"; shift ;;
    --register)
      MODE="register"; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --hook-config)
      MODE="hook-config"; shift ;;
    --project-dir)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --project-dir requires a path argument" >&2
        exit 2
      fi
      PROJECT_DIR="$1"
      shift ;;
    --project-dir=*)
      PROJECT_DIR="${1#--project-dir=}"
      shift ;;
    *)
      shift ;;
  esac
done

# Default PROJECT_DIR to $PWD when not supplied.
if [[ -z "$PROJECT_DIR" ]]; then
  PROJECT_DIR="$PWD"
fi

# --- Probe mode ---

if [[ "$MODE" = "probe" ]]; then
  available="false"
  reason="no-cursor-signals"
  if [[ -n "${PROJECT_DIR:-}" ]] && [[ -d "${PROJECT_DIR}/.cursor" ]]; then
    available="true"
    reason="project-cursor-directory"
  elif [[ -n "${CURSOR_TRACE_ID:-}" ]]; then
    available="true"
    reason="CURSOR_TRACE_ID-env-set"
  elif [[ -n "${CURSOR_SESSION_ID:-}" ]]; then
    available="true"
    reason="CURSOR_SESSION_ID-env-set"
  elif [[ -n "${CURSOR_USER:-}" ]]; then
    available="true"
    reason="CURSOR_USER-env-set"
  fi
  echo "available=${available}"
  echo "runtime=cursor"
  echo "reason=${reason}"
  exit 0
fi

# --- Register mode ---

if [[ "$MODE" = "register" ]]; then
  # PROJECT_DIR guard -- refuse empty or root-directory PROJECT_DIR.
  if [[ -z "${PROJECT_DIR}" ]] || [[ "${PROJECT_DIR}" = "/" ]]; then
    echo "FAIL: unsafe PROJECT_DIR (empty or '/'): refusing to write" >&2
    exit 2
  fi

  # HOME guard -- defensive parity with T02/T03 adapters. Cursor writes
  # only under PROJECT_DIR, but refuse HOME="/" to match sibling shape
  # so pipelines that sanity-check HOME can trust every adapter.
  if [[ "${HOME:-}" = "/" ]]; then
    echo "FAIL: unsafe HOME ('/'): refusing to write" >&2
    exit 2
  fi

  # Resolve the repo root relative to this script so the adapter can be
  # invoked from any cwd (tests cd into mktemp fixtures).
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  # scripts/dispatch/adapters/runtime/cursor.sh -> repo root is 4 levels up
  repo_root="$(cd "$script_dir/../../../.." && pwd)"
  commands_dir="$repo_root/commands"

  if [[ ! -d "$commands_dir" ]]; then
    echo "FAIL: commands directory not found at $commands_dir" >&2
    exit 3
  fi

  target_dir="$PROJECT_DIR/.cursor/rules"

  count=0
  if [[ "$DRY_RUN" = "1" ]]; then
    # Dry-run: list what would be written, write nothing.
    for src in "$commands_dir"/*.md; do
      [[ -f "$src" ]] || continue
      base="$(basename "$src")"
      [[ "$base" = "README.md" ]] && continue
      stem="${base%.md}"
      echo "would_write=${target_dir}/orchestrator-${stem}.md"
      count=$((count + 1))
    done
    echo "dry_run=true count=${count}"
    exit 0
  fi

  # Real register: mkdir target dir + copy each command.
  mkdir -p "$target_dir"
  for src in "$commands_dir"/*.md; do
    [[ -f "$src" ]] || continue
    base="$(basename "$src")"
    [[ "$base" = "README.md" ]] && continue
    stem="${base%.md}"
    cp "$src" "${target_dir}/orchestrator-${stem}.md"
    count=$((count + 1))
  done
  echo "registered=true count=${count}"
  exit 0
fi

# --- Hook-config mode ---

if [[ "$MODE" = "hook-config" ]]; then
  # Cursor has no lifecycle-hook API; emit a minimal fragment that
  # advertises rules-only integration. Shape mirrors codex.sh so
  # downstream tooling can key off `runtime = "..."`.
  cat <<EOF
# cursor hook-config
runtime = "cursor"
hooks_supported = "false"
hook_count = "0"
note = "Cursor uses rule-based integration; no lifecycle hooks."
EOF
  exit 0
fi

# --- No recognized mode ---

echo "ERROR: one of --probe, --register [--dry-run] [--project-dir <path>], --hook-config is required" >&2
exit 2
