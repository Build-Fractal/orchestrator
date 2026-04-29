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
#     Also installs orchestrator agents under $HOME/.claude/agents/, one per
#     packaging/agents/*.md (currently: orchestrator-agent.md). The agent
#     surface is the FU-7 fix: dispatched units pick `subagent_type=
#     orchestrator-agent` so discovery does not surface gsd-* / framework
#     agents whose system prompts impose incompatible conventions.
#     With --dry-run: emits `would_write=<path>` lines and writes nothing.
#     Without --dry-run: mkdir -p both target dirs and copy.
#     Final line: `registered=true count=<N> agents=<M>` (or
#     `dry_run=true count=<N> agents=<M>`).
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
# Bash 3.2 compatible. No assoc-arrays, no array-from-stdin builtins.

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
  agents_dir="$repo_root/packaging/agents"

  if [[ ! -d "$commands_dir" ]]; then
    echo "FAIL: commands directory not found at $commands_dir" >&2
    exit 3
  fi

  target_dir="$HOME/.claude/commands"
  agents_target_dir="$HOME/.claude/agents"

  count=0
  agents_count=0
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
    if [[ -d "$agents_dir" ]]; then
      for src in "$agents_dir"/*.md; do
        [[ -f "$src" ]] || continue
        base="$(basename "$src")"
        echo "would_write=${agents_target_dir}/${base}"
        agents_count=$((agents_count + 1))
      done
    fi
    echo "dry_run=true count=${count} agents=${agents_count}"
    exit 0
  fi

  # Real register: mkdir target dirs + copy each command and agent.
  mkdir -p "$target_dir"
  for src in "$commands_dir"/*.md; do
    [[ -f "$src" ]] || continue
    base="$(basename "$src")"
    [[ "$base" = "README.md" ]] && continue
    stem="${base%.md}"
    cp "$src" "${target_dir}/orchestrator-${stem}.md"
    count=$((count + 1))
  done
  if [[ -d "$agents_dir" ]]; then
    mkdir -p "$agents_target_dir"
    for src in "$agents_dir"/*.md; do
      [[ -f "$src" ]] || continue
      base="$(basename "$src")"
      cp "$src" "${agents_target_dir}/${base}"
      agents_count=$((agents_count + 1))
    done
  fi
  echo "registered=true count=${count} agents=${agents_count}"
  exit 0
fi

# --- Hook-config mode ---

if [[ "$MODE" = "hook-config" ]]; then
  # M028/P02 (T02): emit a valid Claude Code `settings.json` hooks fragment.
  # Every command is an absolute `bash <path>` invocation referencing the
  # runtime-stable hooks dir at ${HOME}/.claude/orchestrator-hooks/. This
  # closes Finding F (adapter half): bare command names like
  # `orchestrator-post-verify` were resolved against PATH by Claude Code's
  # hook runner, found nothing, and emitted `command not found` on every
  # Stop event. Absolute `bash <path>` invocations resolve unconditionally
  # regardless of consumer-project PATH configuration.
  #
  # Event mapping (M025/P01 baseline + M028/P02 shape-guard addition):
  #   post_verify       -> Stop         (terminal; no matcher)
  #                        -> after-verify-sync.sh (renamed from
  #                           orchestrator-post-verify; the bare name was a
  #                           misalignment between the emitted hook string
  #                           and the actual on-disk lifecycle script)
  #   pre_bash          -> PreToolUse   (matcher: Bash; shape-guard NEW T02)
  #                        -> pre-bash-shape-guard.sh
  #   before_commit     -> PreToolUse   (matcher: Bash; git-commit filter
  #                                      in wrapper)
  #                        -> before-commit.sh (renamed from bare
  #                           orchestrator-before-commit)
  #
  # Two PreToolUse Bash leaves coexist because settings-merge.sh's dedup key
  # is (event, matcher, command), not wrapper identity -- distinct command
  # strings produce distinct dedup-key tuples.
  #
  # Deferred orchestrator events (no CC equivalent at M025):
  #   TODO(M025+): before_tasks     -- revisit if CC gains a task-start event
  #   TODO(M025+): after_tasks      -- revisit if CC gains a task-end event
  #   TODO(M025+): before_implement -- revisit if CC gains an implement-start event
  #   TODO(M025+): after_implement  -- revisit if CC gains an implement-end event
  #
  # Every leaf hook object carries "_orchestrator_managed": true so the
  # installer's --uninstall path (FR-7) can remove only orchestrator entries
  # without touching user-authored hooks (M025 invariant; uninstall-cascade
  # key). HOME guard required because HOME_HOOKS expands at adapter-emit
  # time -- the JSON fragment carries the resolved absolute path, not a
  # ${HOME} placeholder. Heredoc terminator is unquoted (<<EOF) so the
  # variable expands; re-quoting (<<'EOF') would break the absolute-path
  # contract by writing literal ${HOME_HOOKS} to disk.
  if [[ -z "${HOME:-}" ]] || [[ "${HOME}" = "/" ]]; then
    echo "FAIL: unsafe HOME (empty or '/'): refusing to emit" >&2
    exit 2
  fi
  HOME_HOOKS="${HOME}/.claude/orchestrator-hooks"
  cat <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash ${HOME_HOOKS}/after-verify-sync.sh", "_orchestrator_managed": true }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash ${HOME_HOOKS}/pre-bash-shape-guard.sh", "_orchestrator_managed": true },
          { "type": "command", "command": "bash ${HOME_HOOKS}/before-commit.sh", "_orchestrator_managed": true }
        ]
      }
    ]
  }
}
EOF
  exit 0
fi

# --- No recognized mode ---

echo "ERROR: one of --probe, --register [--dry-run], --hook-config is required" >&2
exit 2
