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
NO_EMIT_JSONL=0

usage() {
  sed -n '2,44p' "$0"
}

# --- Multi-source resolution helpers (M035 P06 T02 / FR-13 / AD-5 / D014) ----
#
# Resolves update_source via AD-5 ordering (config first, then detection),
# persists detected non-git resolutions back to .orchestrator/config.yml.
# Bash 3.2 / POSIX-sh-safe; no compound chains; no plain subshells used as
# command-substitution-with-pipes. Helpers are inline (not separate scripts)
# to preserve AD-19 single-script-file shape for the dispatch surface.

resolve_update_source() {
  proj="$1"
  cfg="$proj/.orchestrator/config.yml"
  resolved=""
  detected=""

  # Path 1: read from config (operator wins).
  if [ -f "$cfg" ]; then
    resolved="$(grep -E '^update_source:' "$cfg" 2>/dev/null \
      | head -1 | sed -E 's/^update_source:[[:space:]]*//' \
      | tr -d '"' | tr -d "'")"
  fi

  if [ -n "$resolved" ]; then
    echo "$resolved"
    return 0
  fi

  # Path 2: AD-5 detection ordering (D014).
  # 2a: install-meta.txt runtime= field.
  meta="$proj/.orchestrator/install-meta.txt"
  if [ -f "$meta" ]; then
    runtime=""
    runtime="$(grep -E '^runtime=' "$meta" 2>/dev/null \
      | head -1 | sed -E 's/^runtime=//' \
      | tr '[:upper:]' '[:lower:]')"
    case "$runtime" in
      *npm*)      detected="npm" ;;
      *homebrew*) detected="homebrew" ;;
      *brew*)     detected="homebrew" ;;
      *curl*)     detected="npm" ;;
      *git*)      detected="git" ;;
    esac
  fi

  # 2a-bis: git-source provenance. install-meta.txt has no explicit channel
  # field; `runtime=` above is always the runtime type (claude-code), not the
  # channel, so a source-repo install matches no case there. Detect git from
  # the provenance signal that IS recorded: commit_sha is populated only when
  # the install's source_root is a git working tree (REPO_ROOT/.git exists);
  # npm/homebrew installs extract into a package dir with no .git, so it is
  # empty. Without this, every git-origin project falls through to 2b and is
  # silently captured as npm once @build-fractal/orchestrator is published
  # globally — flipping dogfood projects off their local tree onto the
  # registry build. An explicit `update_source:` in config (Path 1) still wins.
  if [ -z "$detected" ] && [ -f "$meta" ]; then
    csha="$(grep -E '^commit_sha=' "$meta" 2>/dev/null \
      | head -1 | sed -E 's/^commit_sha=//')"
    src_root="$(grep -E '^source_root=' "$meta" 2>/dev/null \
      | head -1 | sed -E 's/^source_root=//')"
    if [ -n "$csha" ] || { [ -n "$src_root" ] && [ -d "$src_root/.git" ]; }; then
      detected="git"
    fi
  fi

  # 2b: npm global presence.
  if [ -z "$detected" ]; then
    if command -v npm >/dev/null 2>&1; then
      npm_root_probe=""
      npm_root_probe="$(npm root -g 2>/dev/null)"
      if [ -n "$npm_root_probe" ] && [ -d "$npm_root_probe/@build-fractal/orchestrator" ]; then
        detected="npm"
      fi
    fi
  fi

  # 2c: homebrew formula presence.
  if [ -z "$detected" ]; then
    if command -v brew >/dev/null 2>&1; then
      brew_prefix_probe=""
      brew_prefix_probe="$(brew --prefix 2>/dev/null)"
      if [ -n "$brew_prefix_probe" ] && [ -d "$brew_prefix_probe/Cellar/orchestrator" ]; then
        detected="homebrew"
      fi
    fi
  fi

  # 2d: fallback.
  if [ -z "$detected" ]; then
    detected="git"
  fi

  # Persist non-git detections (single-resolve discipline). Git fallback is
  # NOT persisted: persisting would noise up every fresh consumer's config.
  if [ "$detected" != "git" ] && [ -d "$proj/.orchestrator" ]; then
    persist_update_source "$cfg" "$detected"
  fi

  echo "$detected"
}

persist_update_source() {
  cfg="$1"
  val="$2"
  # If config doesn't exist, write a minimal one.
  if [ ! -f "$cfg" ]; then
    printf 'schema_version: "1.0"\ntype: orchestrator-config\nupdate_source: %s\n' "$val" > "$cfg"
    return 0
  fi
  # If line exists, sed-replace; else append at EOF.
  if grep -qE '^update_source:' "$cfg" 2>/dev/null; then
    tmp="$cfg.tmp"
    sed -E "s/^update_source:.*/update_source: $val/" "$cfg" > "$tmp"
    mv "$tmp" "$cfg"
  else
    printf 'update_source: %s\n' "$val" >> "$cfg"
  fi
}

# --- update_run JSONL emission helpers (M035 P06 T03 / FR-13 / FR-15 / D013) -
#
# Emit one update_run JSONL event for non-rollback dispatch paths, honoring
# the 5-condition suppression matrix (D013):
#   1. --no-emit-jsonl flag                 -> short-circuit
#   2. ORCHESTRATOR_AUTO=1 env var          -> short-circuit
#   3. update_source=none                   -> defensive guard (never reached)
#   4. compression.efficiency_footer.enabled=false -> orthogonal, NOT bound
#   5. structural carve-out                 -> only fires post-dispatch
#
# Args: $1=source $2=target_version $3=result (success|failure)
# Side effect: appends one line to .orchestrator/observability/<date>.jsonl
# Exit: always 0 (emission failure must NOT abort the caller).
emit_update_run_event() {
  source_val="$1"
  target_version="$2"
  result_val="$3"

  # Condition 1: --no-emit-jsonl flag.
  if [ "${NO_EMIT_JSONL:-0}" = "1" ]; then
    return 0
  fi
  # Condition 2: ORCHESTRATOR_AUTO env var.
  if [ "${ORCHESTRATOR_AUTO:-0}" = "1" ]; then
    return 0
  fi
  # Condition 3: defensive guard against update_source=none.
  if [ "$source_val" = "none" ]; then
    return 0
  fi

  obs_dir="$PROJECT_DIR/.orchestrator/observability"
  mkdir -p "$obs_dir" 2>/dev/null || return 0
  today_emit=""
  today_emit="$(date -u +%Y-%m-%d)"
  jsonl_emit="$obs_dir/$today_emit.jsonl"
  ts_emit=""
  ts_emit="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"event":"update_run","op":"update","source":"%s","target_version":"%s","result":"%s","timestamp":"%s"}\n' \
    "$source_val" "$target_version" "$result_val" "$ts_emit" >> "$jsonl_emit" 2>/dev/null || return 0
  return 0
}

# Best-effort post-dispatch version resolution. Returns "unknown" when the
# channel-appropriate version probe fails. In-function pipelines are AP-009
# permitted (caller-side inline compound shapes are what trip the guard).
# Bash 3.2 + POSIX-sh-safe.
resolve_target_version() {
  source_val="$1"
  case "$source_val" in
    git)
      if [ -n "${bundle_version:-}" ]; then
        echo "$bundle_version"
      else
        echo "unknown"
      fi
      ;;
    npm)
      v_npm=""
      v_npm="$(npm view @build-fractal/orchestrator version 2>/dev/null | head -1 | tr -d '"' | tr -d "'")"
      if [ -n "$v_npm" ]; then
        echo "$v_npm"
      else
        echo "unknown"
      fi
      ;;
    homebrew)
      v_brew=""
      v_brew="$(brew info --json=v2 orchestrator 2>/dev/null | grep -E '"versions"' | head -1 | sed -E 's/.*"stable":"([^"]+)".*/\1/')"
      if [ -n "$v_brew" ]; then
        echo "$v_brew"
      else
        echo "unknown"
      fi
      ;;
    *)
      echo "unknown"
      ;;
  esac
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
    --no-emit-jsonl)
      NO_EMIT_JSONL=1; shift ;;
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

# --- Multi-source dispatch (M035 P06 T02 / FR-13 / AD-5 / D014) --------------
#
# Resolves update_source: config first (via T01's registered key), then
# AD-5 detection (install-meta.txt runtime= / npm presence / brew presence /
# git fallback). Persists detected non-git source to config for future runs.
# The four channel arms dispatch to the appropriate update command;
# --dry-run emits the would_invoke= line and exits 0.
#
# Rollback path above short-circuits before this block; the existing
# git-source dispatch (formerly the only path) is now the git arm via :
# fall-through into the source-repo validation that follows.

if [ ! -d "$PROJECT_DIR" ]; then
  echo "FAIL: project dir not found: $PROJECT_DIR" >&2
  exit 1
fi

update_source="$(resolve_update_source "$PROJECT_DIR")"

case "$update_source" in
  git)
    # Existing path — fall through to the source-repo validation and
    # install dispatch below. The git-arm dry-run emits the canonical
    # would_invoke= line in the existing dispatch block (see below).
    :
    ;;
  npm)
    if ! command -v npm >/dev/null 2>&1; then
      echo "FAIL: update_source=npm but npm not on PATH" >&2
      exit 1
    fi
    npm_root=""
    npm_root="$(npm root -g 2>/dev/null)"
    if [ -z "$npm_root" ] || [ ! -d "$npm_root/@build-fractal/orchestrator" ]; then
      echo "FAIL: @build-fractal/orchestrator not installed at npm global root: $npm_root" >&2
      exit 1
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "would_invoke=npm update -g @build-fractal/orchestrator"
      exit 0
    fi
    echo "running npm update -g @build-fractal/orchestrator..."
    npm update -g @build-fractal/orchestrator
    rc=$?
    # T03: update_run JSONL emission (npm channel).
    _tv="$(resolve_target_version npm)"
    _rv="success"
    if [ "$rc" -ne 0 ]; then _rv="failure"; fi
    emit_update_run_event "npm" "$_tv" "$_rv"
    echo "---"
    if [ "$rc" -eq 0 ]; then
      echo "orchestrator:update OK -- npm channel"
    else
      echo "FAIL: npm update exited $rc" >&2
    fi
    exit "$rc"
    ;;
  homebrew)
    if ! command -v brew >/dev/null 2>&1; then
      echo "FAIL: update_source=homebrew but brew not on PATH" >&2
      exit 1
    fi
    brew_prefix=""
    brew_prefix="$(brew --prefix 2>/dev/null)"
    if [ -z "$brew_prefix" ] || [ ! -d "$brew_prefix/Cellar/orchestrator" ]; then
      echo "FAIL: orchestrator not installed via brew at: $brew_prefix" >&2
      exit 1
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "would_invoke=brew upgrade orchestrator"
      exit 0
    fi
    echo "running brew upgrade orchestrator..."
    brew upgrade orchestrator
    rc=$?
    # T03: update_run JSONL emission (homebrew channel).
    _tv="$(resolve_target_version homebrew)"
    _rv="success"
    if [ "$rc" -ne 0 ]; then _rv="failure"; fi
    emit_update_run_event "homebrew" "$_tv" "$_rv"
    echo "---"
    if [ "$rc" -eq 0 ]; then
      echo "orchestrator:update OK -- homebrew channel"
    else
      echo "FAIL: brew upgrade exited $rc" >&2
    fi
    exit "$rc"
    ;;
  none)
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "would_invoke=<no-op: update_source=none>"
      exit 0
    fi
    echo "update_source: none — dispatch suppressed (operator opt-out)"
    exit 0
    ;;
  *)
    echo "FAIL: unknown update_source=$update_source (expected git|npm|homebrew|none)" >&2
    exit 1
    ;;
esac

# Fall-through: update_source=git. The existing source-repo validation +
# install dispatch below is now the git arm.

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
  echo "      $SOURCE_REPO does not look like an orchestrator source tree." >&2
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
  echo "would_invoke=bash $INSTALLER --project-dir $PROJECT_DIR --force"
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

# T03: update_run JSONL emission (git arm fall-through).
_tv="$(resolve_target_version git)"
_rv="success"
if [ "$rc" -ne 0 ]; then _rv="failure"; fi
emit_update_run_event "git" "$_tv" "$_rv"

exit "$rc"
