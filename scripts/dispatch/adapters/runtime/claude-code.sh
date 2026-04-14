#!/usr/bin/env bash
# scripts/dispatch/adapters/runtime/claude-code.sh -- Claude Code runtime adapter
#
# Uniform runtime-adapter interface (filename-registered, see P02 pattern):
#
#   --probe
#     Emits key=value lines on stdout describing whether Claude Code is
#     available in the current environment. Exits 0 unconditionally.
#       available=true|false
#       runtime=claude-code
#       reason=<signal-text>
#
#   --register [--dry-run]
#     Installs orchestrator commands as user-level Claude Code skill files
#     under $HOME/.claude/commands/orchestrator-<cmd>.md, one per
#     commands/*.md in the repo root (excluding README.md per MEM008).
#     With --dry-run: emits `would_write=<path>` lines and writes nothing.
#     Without --dry-run: mkdir -p "$HOME/.claude/commands" and copy, then
#     emit `registered=true count=<N>`.
#
#     HOME guard: refuses to run when $HOME is unset/empty or "/". Emits
#     "FAIL: unsafe HOME" on stderr and exits 2. All tests MUST use
#     HOME="$(mktemp -d)" fixtures -- never the real developer home.
#
#   --hook-config
#     Emits a JSON-shaped settings.json fragment on stdout describing the
#     orchestrator hook registrations for Claude Code lifecycle events.
#     No jq dependency.
#
# Bash 3.2 compatible. No associative arrays, no mapfile/readarray.

set -u

MODE=""
DRY_RUN=0

# --- Argument parsing (while-case loop, matching P02 adapter style) ---

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
    *)
      shift ;;
  esac
done

# --- Probe mode ---

if [[ "$MODE" = "probe" ]]; then
  available="false"
  reason="no-claude-code-signals"
  if [[ "${CLAUDECODE:-0}" = "1" ]]; then
    available="true"
    reason="CLAUDECODE=1"
  elif [[ -n "${HOME:-}" ]] && [[ -d "${HOME}/.claude" ]]; then
    available="true"
    reason="home-claude-directory"
  fi
  echo "available=${available}"
  echo "runtime=claude-code"
  echo "reason=${reason}"
  exit 0
fi

# --- Register mode ---

if [[ "$MODE" = "register" ]]; then
  # HOME guard -- refuse empty or root-directory HOME.
  if [[ -z "${HOME:-}" ]] || [[ "${HOME}" = "/" ]]; then
    echo "FAIL: unsafe HOME (empty or '/'): refusing to write" >&2
    exit 2
  fi

  # Resolve the repo root relative to this script so the adapter can be
  # invoked from any cwd (tests cd into mktemp fixtures).
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  # scripts/dispatch/adapters/runtime/claude-code.sh -> repo root is 4 levels up
  repo_root="$(cd "$script_dir/../../../.." && pwd)"
  commands_dir="$repo_root/commands"

  if [[ ! -d "$commands_dir" ]]; then
    echo "FAIL: commands directory not found at $commands_dir" >&2
    exit 3
  fi

  target_dir="$HOME/.claude/commands"

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
  # Emit a JSON-shaped settings.json fragment describing the hook
  # registrations for Claude Code lifecycle events. No jq dependency.
  # hook_count reflects spec-kit orchestrator lifecycle hooks (5 points
  # per CLAUDE.md: before_tasks, after_tasks, before_implement,
  # after_implement, before_commit).
  target_file="${HOME:-}/.claude/settings.json"
  cat <<EOF
{
  "runtime": "claude-code",
  "hook_count": 5,
  "target_file": "${target_file}",
  "hooks": [
    { "event": "before_tasks", "command": "orchestrator-before-tasks" },
    { "event": "after_tasks", "command": "orchestrator-after-tasks" },
    { "event": "before_implement", "command": "orchestrator-before-implement" },
    { "event": "after_implement", "command": "orchestrator-after-implement" },
    { "event": "before_commit", "command": "orchestrator-before-commit" }
  ]
}
EOF
  exit 0
fi

# --- No recognized mode ---

echo "ERROR: one of --probe, --register [--dry-run], --hook-config is required" >&2
exit 2
