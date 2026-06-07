#!/usr/bin/env bash
# tools/verify/update-runtime-aware-installer.sh
# orchestrator:update (run-update.sh) must reinstall with the SAME runtime the
# project was set up for — a Cursor/Codex project must NOT be refreshed with the
# Claude Code installer. Exercises the git/source channel (--dry-run) and asserts
# the resolved installer per runtime signal.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
SRC="$REPO_ROOT"
RU="scripts/lifecycle/run-update.sh"
fail=0

# Helper: build a project fixture pinned to the git channel, run a dry-run
# update, and return the would_invoke line.
_dry() { # $1=project-dir
  bash "$RU" --project-dir "$1" --source-repo "$SRC" --dry-run 2>&1 | grep '^would_invoke=' | head -1
}
_mkproj() { # $1=dir
  mkdir -p "$1/.orchestrator"
  printf 'update_source: git\n' > "$1/.orchestrator/config.yml"   # force source channel
}

TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT

# 1. Cursor via install-meta runtime=cursor -> install-cursor.sh
A="$TD/a"; _mkproj "$A"; printf 'runtime=cursor\n' > "$A/.orchestrator/install-meta.txt"
got="$(_dry "$A")"
if ! printf '%s' "$got" | grep -q 'install-cursor.sh'; then
  echo "FAIL: cursor project (meta) resolved to: $got"; fail=1
fi

# 2. Cursor via .cursor/ marker (no meta) -> install-cursor.sh
B="$TD/b"; _mkproj "$B"; mkdir -p "$B/.cursor/commands"
got="$(_dry "$B")"
if ! printf '%s' "$got" | grep -q 'install-cursor.sh'; then
  echo "FAIL: cursor project (marker) resolved to: $got"; fail=1
fi

# 3. Cursor via config.yml runtime: cursor -> install-cursor.sh
F="$TD/f"; mkdir -p "$F/.orchestrator"
printf 'update_source: git\nruntime: "cursor"\n' > "$F/.orchestrator/config.yml"
got="$(_dry "$F")"
if ! printf '%s' "$got" | grep -q 'install-cursor.sh'; then
  echo "FAIL: cursor project (config runtime:) resolved to: $got"; fail=1
fi

# 4. Claude Code (CLAUDE.md, no signal) -> install-claude-code.sh
C="$TD/c"; _mkproj "$C"; printf '# x\n' > "$C/CLAUDE.md"
got="$(_dry "$C")"
if ! printf '%s' "$got" | grep -q 'install-claude-code.sh'; then
  echo "FAIL: claude-code project resolved to: $got"; fail=1
fi

# 5. Codex via install-meta runtime=codex -> install-codex.sh
D="$TD/d"; _mkproj "$D"; printf 'runtime=codex\n' > "$D/.orchestrator/install-meta.txt"
got="$(_dry "$D")"
if ! printf '%s' "$got" | grep -q 'install-codex.sh'; then
  echo "FAIL: codex project resolved to: $got"; fail=1
fi

# 6. Bare project, no signal -> default claude-code
E="$TD/e"; _mkproj "$E"
got="$(_dry "$E")"
if ! printf '%s' "$got" | grep -q 'install-claude-code.sh'; then
  echo "FAIL: bare project did not default to claude-code: $got"; fail=1
fi

# 7. No hardcoded install-claude-code.sh installer assignment survives.
if grep -q 'INSTALLER="\$SOURCE_REPO/packaging/install/install-claude-code.sh"' "$RU"; then
  echo "FAIL: run-update.sh still hardcodes the claude-code installer"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: orchestrator:update selects install-<runtime>.sh per project runtime (cursor/codex/claude-code)"
  exit 0
fi
exit 1
