#!/usr/bin/env bash
# scripts/dispatch/adapters/runtime/codex.sh -- Codex CLI runtime adapter
#
# Uniform runtime-adapter interface (filename-registered, see P02 pattern):
#
#   --probe
#     Emits key=value lines on stdout describing whether Codex CLI is
#     available in the current environment. Exits 0 unconditionally.
#       available=true|false
#       runtime=codex
#       reason=<signal-text>
#
#     Probe signals (any one is sufficient):
#       - `codex` binary on PATH
#       - $HOME/.codex/ directory present
#       - $CODEX_HOME environment variable set
#
#   --register [--dry-run]
#     Installs orchestrator commands as user-level Codex CLI skill files
#     under $HOME/.codex/skills/orchestrator-<cmd>.md, one per
#     commands/*.md in the repo root (excluding README.md per MEM008).
#     With --dry-run: emits `would_write=<path>` lines and writes nothing.
#     Without --dry-run: mkdir -p "$HOME/.codex/skills" and copy, then
#     emit `registered=true count=<N>`.
#
#     HOME guard: refuses to run when $HOME is unset/empty or "/". Emits
#     "FAIL: unsafe HOME" on stderr and exits 2. All tests MUST use
#     HOME="$(mktemp -d)" fixtures -- never the real developer home.
#
#   --hook-config
#     Emits a TOML-shaped config.toml fragment on stdout describing the
#     orchestrator hook registrations for Codex CLI lifecycle events.
#     No python3/jq dependency.
#
# Codex conventions (cf. claude-code.sh):
#   - AGENTS.md is the Codex project-instruction file (analog of CLAUDE.md).
#   - $HOME/.codex/skills/ is the user-level skill installation directory.
#   - $HOME/.codex/config.toml is the hook/config target file.
#
# Bash 3.2 compatible. No associative arrays, no mapfile/readarray.

set -u

MODE=""
DRY_RUN=0

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
    *)
      shift ;;
  esac
done

# --- Probe mode ---

if [[ "$MODE" = "probe" ]]; then
  available="false"
  reason="no-codex-signals"
  if command -v codex >/dev/null 2>&1; then
    available="true"
    reason="codex-binary-on-path"
  elif [[ -n "${CODEX_HOME:-}" ]]; then
    available="true"
    reason="CODEX_HOME-env-set"
  elif [[ -n "${HOME:-}" ]] && [[ -d "${HOME}/.codex" ]]; then
    available="true"
    reason="home-codex-directory"
  fi
  echo "available=${available}"
  echo "runtime=codex"
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
  # scripts/dispatch/adapters/runtime/codex.sh -> repo root is 4 levels up
  repo_root="$(cd "$script_dir/../../../.." && pwd)"
  commands_dir="$repo_root/commands"

  if [[ ! -d "$commands_dir" ]]; then
    echo "FAIL: commands directory not found at $commands_dir" >&2
    exit 3
  fi

  target_dir="$HOME/.codex/skills"

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
  # Emit a TOML-shaped config.toml fragment describing the hook
  # registrations for Codex CLI lifecycle events. No external deps.
  # hook_count reflects orchestrator lifecycle hooks (5 points
  # per CLAUDE.md: before_tasks, after_tasks, before_implement,
  # after_implement, before_commit).
  target_file="${HOME:-}/.codex/config.toml"
  cat <<EOF
[orchestrator]
runtime = "codex"
hook_count = 5
target_file = "${target_file}"

[[orchestrator.hooks]]
event = "before_tasks"
command = "orchestrator-before-tasks"

[[orchestrator.hooks]]
event = "after_tasks"
command = "orchestrator-after-tasks"

[[orchestrator.hooks]]
event = "before_implement"
command = "orchestrator-before-implement"

[[orchestrator.hooks]]
event = "after_implement"
command = "orchestrator-after-implement"

[[orchestrator.hooks]]
event = "before_commit"
command = "orchestrator-before-commit"
EOF
  exit 0
fi

# --- No recognized mode ---

echo "ERROR: one of --probe, --register [--dry-run], --hook-config is required" >&2
exit 2
