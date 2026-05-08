#!/usr/bin/env bash
# packaging/npm/postinstall.sh -- npm postinstall driver for
# @build-fractal/orchestrator (M035 P02 T02).
#
# Runs automatically after `npm install -g @build-fractal/orchestrator`.
# Wraps the existing M025 installers (install-claude-code.sh) with:
#   * Windows fail-closed guard (MIT-9 / D003 belt-and-suspenders)
#   * DRY_RUN=1 honor (D002 test-fixture contract)
#   * INIT_CWD-aware project-dir resolution (npm convention)
#   * Runtime detection: Claude Code at v1; Codex/Cursor stubbed
#
# Exit codes:
#   0 success (or runtime_unavailable advisory — non-blocking)
#   1 Windows refused, or Unix delegate failed
#
# Bash 3.2 compatible. No declare -A, no jq, no python.

set -u

# --- 1. Windows fail-closed guard (#Q-G9 / MIT-9) -------------------

uname_s="$(uname -s 2>/dev/null || echo unknown)"
case "$uname_s" in
  MINGW*|CYGWIN*|MSYS*|Windows_NT|WindowsNT)
    echo "FAIL: @build-fractal/orchestrator postinstall does not run on Windows." >&2
    echo "      Windows symlink-mode and runtime parity are deferred to" >&2
    echo "      post-launch milestone M009 (multi-runtime parity audit)." >&2
    echo "      The package.json os field should have caught this on npm's" >&2
    echo "      side; if you see this message, please file an issue at" >&2
    echo "      https://github.com/Build-Fractal/orchestrator/issues" >&2
    exit 1
    ;;
esac

# --- 2. Resolve REPO_ROOT (where the npm package extracted) -------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# packaging/npm/postinstall.sh -> repo root is 2 levels up
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"

# --- 3. Resolve INIT_CWD (npm convention) -------------------------

# npm sets INIT_CWD to the directory `npm install` was run from.
# When `npm install -g` runs without a project context, INIT_CWD
# may be unset or point at the global npm prefix — in that case
# the postinstall is a "package present, project not yet chosen"
# event and we skip skill registration entirely.
PROJECT_DIR="${INIT_CWD:-${PWD:-}}"

# If PROJECT_DIR is empty or matches the npm global prefix, treat
# this as a "global install, no project" event — emit advisory only.
NPM_PREFIX="$(npm config get prefix 2>/dev/null || echo "")"
if [ -z "$PROJECT_DIR" ] || [ "$PROJECT_DIR" = "$NPM_PREFIX" ] || \
   [ "$PROJECT_DIR" = "$NPM_PREFIX/lib/node_modules" ]; then
  echo "ADVISORY: @build-fractal/orchestrator installed globally; no project context." >&2
  echo "          Run \`orchestrator --help\` for next steps. Per-project skill" >&2
  echo "          registration happens when you run /orchestrator-init inside a" >&2
  echo "          Claude Code project." >&2
  exit 0
fi

# --- 4. Honor DRY_RUN=1 (D002 test-fixture contract) --------------

DRY_RUN="${DRY_RUN:-0}"
if [ "$DRY_RUN" = "1" ]; then
  echo "would_invoke=$INSTALLER --project-dir $PROJECT_DIR"
  echo "would_check=~/.claude/ runtime presence"
  echo "would_delegate=install-claude-code.sh"
  exit 0
fi

# --- 5. Detect Claude Code runtime --------------------------------

if [ ! -d "$HOME/.claude" ]; then
  echo "runtime_unavailable=true" >&2
  echo "ADVISORY: @build-fractal/orchestrator installed, but Claude Code is" >&2
  echo "          not detected at \$HOME/.claude. Skill registration deferred." >&2
  echo "          Install Claude Code (https://claude.com/claude-code) and" >&2
  echo "          re-run \`bash $INSTALLER --project-dir <path>\` to register" >&2
  echo "          skills, OR run /orchestrator-init inside any Claude Code" >&2
  echo "          project to register on first use." >&2
  exit 0
fi

# --- 6. Delegate to install-claude-code.sh ------------------------

if [ ! -x "$INSTALLER" ]; then
  echo "FAIL: installer not found or not executable at $INSTALLER" >&2
  exit 1
fi

echo "delegating=$INSTALLER --project-dir $PROJECT_DIR"
"$INSTALLER" --project-dir "$PROJECT_DIR"
