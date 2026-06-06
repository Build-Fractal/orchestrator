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
#     M009 FR-4 split registration to the Cursor-native surfaces:
#       - invocable commands -> $PROJECT_DIR/.cursor/commands/orchestrator-<cmd>.md
#         (one per commands/*.md in the repo root, excluding README.md per
#         MEM008; the true analog of Claude Code slash skills, since v1.6)
#       - always-on operating instructions -> $PROJECT_DIR/.cursor/rules/
#         orchestrator.md (alwaysApply rule: orchestrator-managed declaration
#         + generated command index)
#     With --dry-run: emits `would_write=<path>` lines and writes nothing.
#     Without --dry-run: writes both surfaces, then emits
#     `registered=true count=<N>` + `rules=1` (count = command files).
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
# Cursor conventions (cf. claude-code.sh, codex.sh), corrected M009:
#   - .cursor/commands/ holds invocable slash commands (v1.6+).
#   - .cursor/rules/ holds always-on rules the agent reads.
#   - .cursor/hooks.json provides lifecycle hooks (v1.7+) — beforeShellExecution
#     is wired to the orchestrator shape-guard (FR-3).
#   - Registration is per-project (no user-level ~/.cursor/skills/ equivalent).
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
  if [[ "${CURSOR_AGENT:-}" = "1" ]]; then
    # Strongest signal: cursor-agent (headless CLI) exports CURSOR_AGENT=1 to
    # every shell it spawns (verified live 2026-06-06, M009). The older IDE
    # signals below do NOT cover the headless runtime — this branch closes
    # that gap.
    available="true"
    reason="CURSOR_AGENT-env-set"
  elif [[ "${CURSOR_INVOKED_AS:-}" = "cursor-agent" ]]; then
    available="true"
    reason="CURSOR_INVOKED_AS-cursor-agent"
  elif [[ -n "${PROJECT_DIR:-}" ]] && [[ -d "${PROJECT_DIR}/.cursor" ]]; then
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

  # M009 FR-4: split registration to the Cursor-native surfaces.
  #   - Invocable commands -> .cursor/commands/orchestrator-<cmd>.md
  #     (true analog of Claude Code slash skills, since Cursor v1.6). These
  #     are invoked on demand as /orchestrator-<cmd>.
  #   - Always-on operating instructions -> .cursor/rules/orchestrator.md
  #     (an alwaysApply rule that declares the project orchestrator-managed
  #     and lists the available commands). This replaces the pre-FR-4 behavior
  #     that dumped every command's full body into .cursor/rules/ (always
  #     loaded — context-heavy and not how Cursor models invocable commands).
  commands_target="$PROJECT_DIR/.cursor/commands"
  rules_target="$PROJECT_DIR/.cursor/rules"
  rule_file="${rules_target}/orchestrator.md"

  # Build the command-name list (sorted by glob order) for both the dry-run
  # listing and the always-on rule body.
  cmd_count=0
  cmd_names=""
  for src in "$commands_dir"/*.md; do
    [[ -f "$src" ]] || continue
    base="$(basename "$src")"
    [[ "$base" = "README.md" ]] && continue
    stem="${base%.md}"
    cmd_names="${cmd_names}${stem}\n"
    cmd_count=$((cmd_count + 1))
  done

  if [[ "$DRY_RUN" = "1" ]]; then
    # Dry-run: list what would be written, write nothing.
    printf '%b' "$cmd_names" | while IFS= read -r stem; do
      [ -z "$stem" ] && continue
      echo "would_write=${commands_target}/orchestrator-${stem}.md"
    done
    echo "would_write=${rule_file}"
    echo "dry_run=true count=${cmd_count}"
    echo "rules=1"
    exit 0
  fi

  # Real register: commands -> .cursor/commands/, always-on rule -> .cursor/rules/.
  mkdir -p "$commands_target" "$rules_target"
  for src in "$commands_dir"/*.md; do
    [[ -f "$src" ]] || continue
    base="$(basename "$src")"
    [[ "$base" = "README.md" ]] && continue
    stem="${base%.md}"
    cp "$src" "${commands_target}/orchestrator-${stem}.md"
  done

  # Always-on rule: alwaysApply frontmatter + a generated command index.
  {
    echo "---"
    echo "alwaysApply: true"
    echo "description: Orchestrator operating model and command index (auto-generated)."
    echo "---"
    echo ""
    echo "# Orchestrator (orchestrator-managed project)"
    echo ""
    echo "This project is managed by the orchestrator. Multi-phase work flows"
    echo "through the \`/orchestrator-*\` commands below (invoke them as Cursor"
    echo "slash commands; their full definitions live in \`.cursor/commands/\`)."
    echo ""
    echo "Shell commands are shape-guarded by \`.cursor/hooks.json\`"
    echo "(beforeShellExecution): compound chains, heredoc-with-expansion, and"
    echo "other flagged shapes are denied with a pointer to the correct wrapper."
    echo ""
    echo "## Available commands"
    echo ""
    printf '%b' "$cmd_names" | while IFS= read -r stem; do
      [ -z "$stem" ] && continue
      echo "- \`/orchestrator-${stem}\`"
    done
  } > "$rule_file"

  echo "registered=true count=${cmd_count}"
  echo "rules=1"
  exit 0
fi

# --- Hook-config mode ---

if [[ "$MODE" = "hook-config" ]]; then
  # Cursor Hooks v1.7+ DO provide a lifecycle-hook API (corrected M009 FR-3,
  # verified live 2026-06-06: headless cursor-agent honors
  # `.cursor/hooks.json` beforeShellExecution and blocks on deny). Emit a real
  # hooks.json document wiring beforeShellExecution -> the orchestrator's
  # Cursor shape-guard wrapper, so install-cursor.sh can write it verbatim to
  # <project>/.cursor/hooks.json.
  #
  # The wrapper path resolves to the staged copy under the project's scripts/
  # tree (installers stage scripts/ intact, so the wrapper + its sibling
  # shape-classifier travel together). When --project-dir is given we emit an
  # absolute path (the form proven in the live probe); otherwise a
  # project-relative path as a portable default.
  if [[ -n "${PROJECT_DIR:-}" ]] && [[ "${PROJECT_DIR}" != "/" ]]; then
    guard_path="${PROJECT_DIR}/scripts/hooks/cursor-before-shell-shape-guard.sh"
  else
    guard_path="./scripts/hooks/cursor-before-shell-shape-guard.sh"
  fi
  # failClosed:false is deliberate (diverges from the M009 brief's
  # failClosed:true): the shape-guard is a shape-CORRECTOR, not a security
  # boundary, and the wrapper fails OPEN on infra errors — matching the
  # established Claude-Code guard philosophy (M028 Finding A). A failClosed
  # guard would deny ALL shell commands if the hook script broke, bricking
  # autonomous runs.
  cat <<EOF
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      { "command": "${guard_path}", "failClosed": false }
    ]
  }
}
EOF
  exit 0
fi

# --- No recognized mode ---

echo "ERROR: one of --probe, --register [--dry-run] [--project-dir <path>], --hook-config is required" >&2
exit 2
