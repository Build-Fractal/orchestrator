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
#   3. $HOME/Sites/orchestrator (default)
#
# Usage:
#   bash scripts/lifecycle/run-update.sh
#                                       [--source-repo PATH]
#                                       [--project-dir PATH]
#                                       [--dry-run]
#                                       [--verbose]
#                                       [--rollback]
#
# --rollback (M035 P05 T02 / FR-12): revert the runtime to the prior
# installed version using the .orchestrator/.previous-version marker +
# .orchestrator/.rollback/manifest-<X>.txt snapshot authored by
# scripts/lifecycle/write-rollback-marker.sh. Symlink-mode and mixed-mode
# installs refuse with the spec-amendment advisory pointing the operator
# to `git checkout <prior-sha>` in the source repo (#Q-G8).
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

SOURCE_REPO="${ORCHESTRATOR_SOURCE_REPO:-$HOME/Sites/orchestrator}"
PROJECT_DIR="$PWD"
DRY_RUN=0
VERBOSE=0
ROLLBACK=0

usage() {
  sed -n '2,44p' "$0"
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
    --rollback)
      ROLLBACK=1; shift ;;
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

# --- Rollback dispatch (FR-12 / D005 / #Q-G8) --------------------------------
#
# Hooks BEFORE the source-resolution + install logic below. Reads the
# .orchestrator/.previous-version marker authored by T01's
# scripts/lifecycle/write-rollback-marker.sh and replays the snapshotted
# manifest at .orchestrator/.rollback/manifest-<prior-version>.txt.
#
# Refusal branches (all exit non-zero):
#   - missing marker: "no prior version recorded — rollback unavailable"
#   - prior_install_mode=symlink|mixed: spec-amendment verbatim advisory
#     pointing operator to `git checkout <prior-sha>` in source repo (#Q-G8)
#   - missing snapshot file: "prior manifest snapshot missing at <path> ..."
#   - update_source=npm|homebrew|curl: SKIP stub (lands when P03/P04/P06 close)
#
# T05 acceptance test exercises the full byte-equivalence cycle; T02
# verifier (m035-p05-rollback-driver-shape.sh) covers only the four
# refusal/error branches.

if [ "$ROLLBACK" = "1" ]; then
  if [ ! -d "$PROJECT_DIR" ]; then
    echo "FAIL: project dir not found: $PROJECT_DIR" >&2
    exit 1
  fi

  marker="$PROJECT_DIR/.orchestrator/.previous-version"
  if [ ! -f "$marker" ]; then
    echo "FAIL: no prior version recorded — rollback unavailable" >&2
    exit 1
  fi

  # Read fields from marker (one var per field; bash 3.2 safe).
  prior_version=""
  prior_commit_sha=""
  prior_manifest_path=""
  prior_install_mode=""
  while IFS= read -r line; do
    case "$line" in
      prior_version=*)        prior_version="${line#prior_version=}" ;;
      prior_commit_sha=*)     prior_commit_sha="${line#prior_commit_sha=}" ;;
      prior_manifest_path=*)  prior_manifest_path="${line#prior_manifest_path=}" ;;
      prior_install_mode=*)   prior_install_mode="${line#prior_install_mode=}" ;;
    esac
  done < "$marker"

  # #Q-G8 — symlink-mode + mixed-mode refusal.
  case "$prior_install_mode" in
    symlink|mixed)
      sha_display="${prior_commit_sha:-<prior-sha>}"
      # Verbatim advisory from spec amendment. Bash 3.2 honors backslash
      # newline-continuation inside double-quoted strings.
      echo "rollback not available for symlink-mode installs — \
symlink-mode consumers are always at HEAD; to revert, run \
\`git checkout $sha_display\` in the orchestrator source repo." >&2
      exit 1
      ;;
  esac

  # Snapshot validation.
  if [ -z "$prior_manifest_path" ]; then
    echo "FAIL: prior manifest snapshot missing at <unset> — rollback unavailable" >&2
    exit 1
  fi
  snapshot_full="$PROJECT_DIR/$prior_manifest_path"
  if [ ! -f "$snapshot_full" ]; then
    echo "FAIL: prior manifest snapshot missing at $snapshot_full — rollback unavailable" >&2
    exit 1
  fi

  # Source dispatch — read update_source from .orchestrator/config.yml.
  config_yml="$PROJECT_DIR/.orchestrator/config.yml"
  update_source=""
  if [ -f "$config_yml" ]; then
    update_source="$(grep -E '^update_source:' "$config_yml" 2>/dev/null \
      | head -1 | sed -E 's/^update_source:[[:space:]]*//' | tr -d '"' | tr -d "'")"
  fi
  if [ -z "$update_source" ]; then
    update_source="git"  # default per FR-13 / #Q-6 detect-by-install
  fi

  case "$update_source" in
    git)
      # Resolve source repo (reuse the cascade already configured at top).
      if [ ! -d "$SOURCE_REPO" ]; then
        echo "FAIL: orchestrator source repo not found: $SOURCE_REPO" >&2
        exit 1
      fi
      if [ ! -d "$SOURCE_REPO/.git" ]; then
        echo "FAIL: source repo at $SOURCE_REPO is not a git repository" >&2
        exit 1
      fi
      # Validate prior_commit_sha is reachable.
      if [ -z "$prior_commit_sha" ]; then
        echo "FAIL: prior_commit_sha is empty — cannot pin rollback target" >&2
        exit 1
      fi
      if ! git -C "$SOURCE_REPO" cat-file -e "${prior_commit_sha}^{commit}" 2>/dev/null; then
        echo "FAIL: prior commit $prior_commit_sha not reachable in $SOURCE_REPO" >&2
        exit 1
      fi
      # Save current HEAD to restore later.
      orig_head="$(git -C "$SOURCE_REPO" rev-parse HEAD)"
      # Checkout prior version (detached HEAD; non-destructive).
      git -C "$SOURCE_REPO" checkout --quiet "$prior_commit_sha"
      # Replay each asset from snapshot. Format: <rel-path>\tmode:<copy|symlink>.
      # Symlink-mode was refused above, so every line here is mode:copy.
      while IFS= read -r asset_line; do
        if [ -z "$asset_line" ]; then
          continue
        fi
        # Strip everything from the first tab onward; the leading text is
        # the relative path. Bash 3.2: parameter expansion only.
        rel="${asset_line%%	*}"
        if [ -z "$rel" ]; then
          continue
        fi
        src="$SOURCE_REPO/$rel"
        dst="$PROJECT_DIR/$rel"
        if [ -f "$src" ]; then
          dst_dir="$(dirname "$dst")"
          mkdir -p "$dst_dir"
          cp "$src" "$dst"
        elif [ -d "$src" ]; then
          mkdir -p "$dst"
          cp -R "$src/." "$dst/"
        fi
      done < "$snapshot_full"
      # Restore source-repo HEAD.
      git -C "$SOURCE_REPO" checkout --quiet "$orig_head"
      ;;
    npm|homebrew|curl)
      echo "SKIP: rollback not yet implemented for source=$update_source" >&2
      exit 1
      ;;
    *)
      echo "FAIL: unknown update_source=$update_source" >&2
      exit 1
      ;;
  esac

  # --- Common post-replay path -------------------------------------------------

  # Swap installed-files.txt for snapshot byte-for-byte.
  cp "$snapshot_full" "$PROJECT_DIR/.orchestrator/installed-files.txt"

  # Update marker rolled_at field with current ISO 8601 timestamp.
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp_marker="$marker.tmp"
  sed -E "s/^rolled_at=.*/rolled_at=$ts/" "$marker" > "$tmp_marker"
  mv "$tmp_marker" "$marker"

  # Emit one update_run JSONL event (FR-13 / FR-15 — M027 convention).
  obs_dir="$PROJECT_DIR/.orchestrator/observability"
  mkdir -p "$obs_dir"
  today="$(date -u +%Y-%m-%d)"
  jsonl="$obs_dir/$today.jsonl"
  printf '{"event":"update_run","op":"rollback","target_version":"%s","source":"%s","result":"success","timestamp":"%s"}\n' \
    "$prior_version" "$update_source" "$ts" >> "$jsonl"

  echo "orchestrator:update --rollback OK -- runtime in $PROJECT_DIR reverted to $prior_version"
  exit 0
fi

# --- Source-repo validation --------------------------------------------------

if [ ! -d "$SOURCE_REPO" ]; then
  echo "FAIL: orchestrator source repo not found: $SOURCE_REPO" >&2
  echo "" >&2
  echo "Resolution: set ORCHESTRATOR_SOURCE_REPO env var, pass --source-repo PATH," >&2
  echo "or symlink the source at \$HOME/Sites/orchestrator." >&2
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
