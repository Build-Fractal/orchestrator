#!/usr/bin/env bash
# scripts/lifecycle/run-update.sh -- pre-M035 interim orchestrator:update driver.
#
# Reinstalls the orchestrator runtime into the current project from a
# locally-resolved source repo. Mechanizes the M035 Finding D shell-
# function recipe as a discoverable first-class skill, ahead of M035
# P02-P06's package-manager publishing pipeline.
#
# Source-repo resolution (first match wins):
#   1. --source-repo PATH      (explicit override)
#   2. $ORCHESTRATOR_SOURCE_REPO env var
#   3. $HOME/Sites/spec-kit-orchestrator (default)
#
# Usage:
#   bash scripts/lifecycle/run-update.sh
#                                       [--source-repo PATH]
#                                       [--project-dir PATH]
#                                       [--dry-run]
#                                       [--verbose]
#
# Output (stdout):
#   source repo:      <path>
#   source HEAD:      <short-sha> <subject>
#   source state:     dirty (uncommitted changes will be staged)   # only if dirty
#   bundle version:   <version>
#   project dir:      <path>
#   ---
#   running install...
#   <installer pass-through output>
#   ---
#   orchestrator:update OK -- runtime in <project> refreshed from <src> (<sha>)
#
# Exit codes:
#   0 success
#   1 source repo / installer / project-dir validation failed; or installer failed
#   2 invalid arguments
#
# Bash 3.2 compatible. AD-19 single-script-file shape.
# Pre-M035 interim: M035 P06 evolves this driver to dispatch by source
# (git/npm/homebrew); for now, git-as-only-source is the v1 contract.

set -u

SOURCE_REPO="${ORCHESTRATOR_SOURCE_REPO:-$HOME/Sites/spec-kit-orchestrator}"
PROJECT_DIR="$PWD"
DRY_RUN=0
VERBOSE=0

usage() {
  sed -n '2,33p' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --source-repo)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: --source-repo requires a path argument" >&2
        exit 2
      fi
      SOURCE_REPO="$1"
      shift ;;
    --source-repo=*)
      SOURCE_REPO="${1#--source-repo=}"
      shift ;;
    --project-dir)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: --project-dir requires a path argument" >&2
        exit 2
      fi
      PROJECT_DIR="$1"
      shift ;;
    --project-dir=*)
      PROJECT_DIR="${1#--project-dir=}"
      shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --verbose)
      VERBOSE=1; shift ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "FAIL: unknown flag: $1" >&2
      echo "Run with --help for usage." >&2
      exit 2
      ;;
  esac
done

# --- Source-repo validation --------------------------------------------------

if [ ! -d "$SOURCE_REPO" ]; then
  echo "FAIL: orchestrator source repo not found: $SOURCE_REPO" >&2
  echo "" >&2
  echo "Resolution: set ORCHESTRATOR_SOURCE_REPO env var, pass --source-repo PATH," >&2
  echo "or symlink the source at \$HOME/Sites/spec-kit-orchestrator." >&2
  echo "" >&2
  echo "Pre-M035 interim: this skill assumes the orchestrator source lives" >&2
  echo "locally. M035 P02-P06 will add npm / homebrew / curl-pipe-bash sources." >&2
  exit 1
fi

INSTALLER="$SOURCE_REPO/packaging/install/install-claude-code.sh"
if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found: $INSTALLER" >&2
  echo "      $SOURCE_REPO does not look like a spec-kit-orchestrator source tree." >&2
  exit 1
fi

# --- Project-dir validation --------------------------------------------------

if [ ! -d "$PROJECT_DIR" ]; then
  echo "FAIL: project dir not found: $PROJECT_DIR" >&2
  exit 1
fi

if [ ! -d "$PROJECT_DIR/.orchestrator" ]; then
  echo "FAIL: $PROJECT_DIR has no .orchestrator/ directory." >&2
  echo "      Run \`orchestrator:init\` first to scaffold this project." >&2
  exit 1
fi

# --- Source-state visibility -------------------------------------------------

src_head="(not a git repo)"
src_dirty=""
if [ -d "$SOURCE_REPO/.git" ]; then
  if command -v git >/dev/null 2>&1; then
    src_head=$(git -C "$SOURCE_REPO" log -1 --format='%h %s' 2>/dev/null || echo "unknown")
    src_dirty=$(git -C "$SOURCE_REPO" status --short 2>/dev/null | head -1 || echo "")
  fi
fi

bundle_version="unknown"
manifest="$SOURCE_REPO/packaging/bundle/manifest.yml"
if [ -f "$manifest" ]; then
  bundle_version=$(grep -E '^version:' "$manifest" 2>/dev/null | head -1 \
    | sed -E 's/^version:[[:space:]]*//' | tr -d '"' \
    || echo "unknown")
fi

# --- Pre-install summary -----------------------------------------------------

echo "source repo:      $SOURCE_REPO"
echo "source HEAD:      $src_head"
if [ -n "$src_dirty" ]; then
  echo "source state:     dirty (uncommitted changes will be staged)"
fi
echo "bundle version:   $bundle_version"
echo "project dir:      $PROJECT_DIR"
echo "---"

# --- Install dispatch --------------------------------------------------------

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: would invoke:"
  echo "  bash $INSTALLER --project-dir $PROJECT_DIR --force"
  exit 0
fi

echo "running install..."
verbose_flag=""
if [ "$VERBOSE" -eq 1 ]; then
  verbose_flag="--verbose"
fi

# Pass-through to the existing installer. Force is the standard upgrade
# semantics today (M035 Finding A documents this); no wrapping logic.
if [ -n "$verbose_flag" ]; then
  bash "$INSTALLER" --project-dir "$PROJECT_DIR" --force "$verbose_flag"
else
  bash "$INSTALLER" --project-dir "$PROJECT_DIR" --force
fi
rc=$?

echo "---"
if [ "$rc" -eq 0 ]; then
  echo "orchestrator:update OK -- runtime in $PROJECT_DIR refreshed from $SOURCE_REPO ($src_head)"
else
  echo "FAIL: installer exited $rc -- runtime may be in a partial state" >&2
fi
exit "$rc"
