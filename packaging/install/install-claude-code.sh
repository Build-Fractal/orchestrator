#!/usr/bin/env bash
# packaging/install/install-claude-code.sh -- Single-command Claude Code installer.
#
# Delegates all runtime-specific work to the P05 adapter:
#   scripts/dispatch/adapters/runtime/claude-code.sh
#
# Responsibilities beyond the adapter:
#   * Invoke --probe, fail fast if the runtime is unavailable.
#   * Delegate skill registration via --register [--dry-run].
#   * Capture --hook-config output and write it to $HOME/.claude/settings.json
#     (or emit `would_write=` under --dry-run).
#   * Stage packaging/bundle/config/orchestrator.default.yml into the project
#     orchestrator state root resolved via scripts/state/resolve-root.sh.
#   * Print a final `SUMMARY:` line with counts.
#
# Shared flag contract (see T03-PLAN):
#   --project-dir PATH   project root (default: $PWD)
#   --dry-run            no writes; emit `would_write=<path>` lines
#   --force              overwrite existing hook config and orchestrator config
#   --verbose            extra debug output on stderr
#   --mode copy|symlink (also: --mode=copy|symlink)
#                        User-facing (M035 P01): selects asset-staging mode.
#                        symlink mode links the runtime tree directly into
#                        the orchestrator source repo so `git pull` in the
#                        source repo updates every consumer immediately
#                        (developer dogfood-velocity contract).
#                        See references/installation.md
#                        § Symlink-mode caveats for Unix-only / source-path
#                        stability / cross-machine fragility constraints.
#   --asset-mode-override copy|symlink
#                        TEST-ONLY backward-compat alias for --mode.
#                        Recognised but undocumented in --help; used by
#                        M032 P01 acceptance scripts. Routes into the
#                        same internal ASSET_MODE_OVERRIDE variable.
#
# Exit codes:
#   0 success
#   1 generic failure (with FAIL: on stderr)
#   2 unsafe environment (empty or '/' HOME)
#   3 runtime unavailable (probe returned available=false)
#
# Bash 3.2 compatible. No associative arrays, mapfile, jq, or python.

set -u

# Resolve installer paths relative to this file so it works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# packaging/install/install-claude-code.sh -> repo root is 2 levels up
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/runtime/claude-code.sh"
RESOLVE_ROOT="$REPO_ROOT/scripts/state/resolve-root.sh"
BUNDLE="$REPO_ROOT/packaging/bundle"

PROJECT_DIR="$PWD"
DRY_RUN=0
FORCE=0
VERBOSE=0
UNINSTALL=0
REPAIR=0
# Skip the §4.5 project-asset staging stage (register skills + wire hooks
# only). Used by the npm postinstall for global installs (`npm install -g`),
# where there is no project to stage into and dumping the runtime payload
# into the invocation cwd would be wrong. Skill registration (§2) and hook
# wiring still run so `/orchestrator-*` commands become available machine-wide.
SKIP_PROJECT_ASSETS=0
# Asset-staging mode override (M035 P01 T01). Both --mode (user-facing)
# and --asset-mode-override (TEST-ONLY backward-compat alias) route here.
# Allowed values: `copy` or `symlink`. Empty default means manifest mode
# wins (i.e. `copy` per packaging/bundle/manifest.yml, CON-7).
ASSET_MODE_OVERRIDE=""

# --- Argument parsing (while-case, bash 3.2 safe) ---
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: --project-dir requires a path argument" >&2
        exit 1
      fi
      PROJECT_DIR="$1"
      shift ;;
    --project-dir=*)
      PROJECT_DIR="${1#--project-dir=}"
      shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --force)
      FORCE=1; shift ;;
    --verbose)
      VERBOSE=1; shift ;;
    --uninstall)
      UNINSTALL=1; shift ;;
    --repair)
      REPAIR=1; shift ;;
    --skip-project-assets)
      SKIP_PROJECT_ASSETS=1; shift ;;
    # M035 P01 T01: --mode is the user-facing surface; routes to the same
    # ASSET_MODE_OVERRIDE variable as the TEST-ONLY --asset-mode-override
    # alias below (preserved for M032 P01 acceptance-script compatibility).
    --mode)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: --mode requires copy|symlink" >&2
        exit 1
      fi
      case "$1" in
        copy|symlink) ASSET_MODE_OVERRIDE="$1" ;;
        *) echo "FAIL: --mode requires copy|symlink" >&2; exit 1 ;;
      esac
      shift ;;
    --mode=*)
      _mode_val="${1#--mode=}"
      case "$_mode_val" in
        copy|symlink) ASSET_MODE_OVERRIDE="$_mode_val" ;;
        *) echo "FAIL: --mode requires copy|symlink" >&2; exit 1 ;;
      esac
      shift ;;
    --asset-mode-override)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: --asset-mode-override requires copy|symlink" >&2
        exit 1
      fi
      case "$1" in
        copy|symlink) ASSET_MODE_OVERRIDE="$1" ;;
        *) echo "FAIL: --asset-mode-override requires copy|symlink" >&2; exit 1 ;;
      esac
      shift ;;
    --asset-mode-override=*)
      _amo="${1#--asset-mode-override=}"
      case "$_amo" in
        copy|symlink) ASSET_MODE_OVERRIDE="$_amo" ;;
        *) echo "FAIL: --asset-mode-override requires copy|symlink" >&2; exit 1 ;;
      esac
      shift ;;
    -h|--help)
      sed -n '2,42p' "$0"
      exit 0 ;;
    *)
      echo "FAIL: unknown argument '$1'" >&2
      exit 1 ;;
  esac
done

log() { [ "$VERBOSE" = "1" ] && echo "[install-claude-code] $*" >&2 || true; }

# --- HOME guard (matches P05 adapter) ---
if [ -z "${HOME:-}" ] || [ "${HOME}" = "/" ]; then
  echo "FAIL: unsafe HOME (empty or '/'): refusing to install" >&2
  exit 2
fi

MERGE_HELPER="$REPO_ROOT/scripts/util/settings-merge.sh"

# --- Uninstall short-circuit (M025/P01/T02) ---
# When --uninstall is set, skip probe/register/config-stage and only remove
# orchestrator-tagged entries from ~/.claude/settings.json plus any
# orchestrator-written config.yml (gated by a marker comment).
if [ "$UNINSTALL" = "1" ]; then
  hook_target="$HOME/.claude/settings.json"
  hooks_removed=0
  hooks_removed_p02=0
  config_removed=0
  runtime_removed=0

  # --- M028/P02/T03: remove staged hooks payload BEFORE settings-merge.sh uninstall ---
  # Walk MANIFEST only; never `find ... -delete`. User-authored siblings (if any)
  # are preserved. `rmdir` (POSIX) fails when the dir is non-empty -- exactly the
  # right behavior when user-authored siblings remain.
  HOOKS_DIR="$HOME/.claude/orchestrator-hooks"
  if [ -f "$HOOKS_DIR/MANIFEST" ]; then
    while IFS= read -r staged_name; do
      [ -z "$staged_name" ] && continue
      target="$HOOKS_DIR/$staged_name"
      if [ -f "$target" ]; then
        if [ "$DRY_RUN" = "1" ]; then
          echo "would_remove=$target"
        else
          rm -f "$target"
        fi
        hooks_removed_p02=$((hooks_removed_p02 + 1))
      fi
    done < "$HOOKS_DIR/MANIFEST"
    if [ "$DRY_RUN" = "0" ] && [ -d "$HOOKS_DIR" ]; then
      rmdir "$HOOKS_DIR" 2>/dev/null || true
    fi
  fi

  if [ -f "$MERGE_HELPER" ] && [ -e "$hook_target" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      un_out="$(bash "$MERGE_HELPER" uninstall --target "$hook_target" --dry-run 2>&1)"
    else
      un_out="$(bash "$MERGE_HELPER" uninstall --target "$hook_target" 2>&1)"
    fi
    un_rc=$?
    printf '%s\n' "$un_out"
    if [ $un_rc -ne 0 ]; then
      echo "FAIL: settings-merge.sh uninstall exited $un_rc" >&2
      exit 1
    fi
    hooks_removed="$(printf '%s\n' "$un_out" | sed -n 's/^removed=\([0-9][0-9]*\)$/\1/p' | head -n 1)"
    [ -z "$hooks_removed" ] && hooks_removed=0
  fi

  # M028/P02/T05: reversibility-normalization -- if settings-merge.sh's uninstall
  # path emptied the target (no orchestrator keys remain AND the user added none
  # before install), the file persists as a literal `{}` JSON object. Pre-install
  # canonical state for an unmanaged HOME is FILE-ABSENT, not `{}` -- the
  # install-roundtrip verifier's snapshot 0 == snapshot 3 invariant requires
  # that an unmanaged HOME with only orchestrator hooks installed returns to
  # its pre-install file-absent state on uninstall. Detect "empty object" (the
  # serializer always emits literal `{}\n` via json.dumps(..., indent=2,
  # sort_keys=True) when target is empty) and unlink. User-authored
  # non-orchestrator keys survive uninstall via settings-merge's preservation
  # path, so the file would be non-empty in that case and stay on disk.
  if [ "$DRY_RUN" = "0" ] && [ -f "$hook_target" ]; then
    contents="$(tr -d ' \t\n\r' < "$hook_target")"
    if [ "$contents" = "{}" ]; then
      rm -f "$hook_target"
    fi
  fi

  # Resolve state root to locate a possibly-staged config.yml.
  state_root=""
  if [ -x "$RESOLVE_ROOT" ]; then
    state_root="$(cd "$PROJECT_DIR" && bash "$RESOLVE_ROOT" --absolute 2>/dev/null)"
  fi
  [ -z "$state_root" ] && state_root="$PROJECT_DIR/.orchestrator"
  cfg_target="$state_root/config.yml"
  if [ -f "$cfg_target" ]; then
    if grep -q '_orchestrator_managed' "$cfg_target" 2>/dev/null; then
      if [ "$DRY_RUN" = "1" ]; then
        echo "would_remove=$cfg_target"
      else
        rm -f "$cfg_target"
        echo "removed=$cfg_target"
      fi
      config_removed=1
    fi
  fi

  # Remove runtime files recorded in the install manifest.
  # FR-4: installed-files.txt now carries per-line `<rel>\tmode:<copy|symlink>`.
  # Column 1 (tab-delimited) is the canonical path-of-record per the
  # install-collision-check.sh FILE FORMAT INVARIANT. Strip any trailing
  # `\tmode:*` token before resolving the path.
  manifest_file="$PROJECT_DIR/.orchestrator/installed-files.txt"
  if [ -f "$manifest_file" ]; then
    # M035/P01/T02: branch on the `mode:` token. symlink-mode entries refer to
    # a single symlink at <PROJECT_DIR>/<rel> (target inside the orchestrator
    # source repo); uninstall must remove only the symlink, never the source.
    # copy-mode entries are regular files (per-file rows); uninstall removes
    # the staged file as today.
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      rel=$(printf '%s\n' "$line" | awk -F'\t' '{print $1}')
      mode_tok=$(printf '%s\n' "$line" | awk -F'\t' '{print $2}')
      [ -z "$rel" ] && continue
      f="$PROJECT_DIR/$rel"
      case "$mode_tok" in
        mode:symlink)
          if [ -L "$f" ]; then
            if [ "$DRY_RUN" = "1" ]; then
              echo "would_remove=$f"
            else
              rm -f "$f"
            fi
            runtime_removed=$((runtime_removed + 1))
          fi
          ;;
        mode:copy|*)
          if [ -f "$f" ]; then
            if [ "$DRY_RUN" = "1" ]; then
              echo "would_remove=$f"
            else
              rm -f "$f"
            fi
            runtime_removed=$((runtime_removed + 1))
          fi
          ;;
      esac
    done < "$manifest_file"
    # Prune empty runtime directories bottom-up.
    if [ "$DRY_RUN" = "0" ]; then
      for d in scripts templates references commands; do
        [ -d "$PROJECT_DIR/$d" ] && find "$PROJECT_DIR/$d" -type d -empty -depth -exec rmdir {} \; 2>/dev/null || true
      done
      rm -f "$manifest_file"
      rm -f "$PROJECT_DIR/.orchestrator/install-meta.txt"
    fi
  elif [ "$DRY_RUN" = "0" ] && [ -d "$PROJECT_DIR/scripts" ]; then
    echo "WARN: manifest $manifest_file missing; refusing to guess removal" >&2
  fi

  echo "UNINSTALLED: hooks-removed=${hooks_removed} hooks-payload-removed=${hooks_removed_p02} config-removed=${config_removed} runtime-removed=${runtime_removed}"
  exit 0
fi

# --- 2'. --repair: remove flag-less M025 orphans by exact-tuple match (M028/P02/T04, FR-7) ---
# The repair pass walks ~/.claude/settings.json and removes hook entries
# whose (event, matcher, command) tuple matches a known M025 pattern but
# which lack the _orchestrator_managed: true flag -- exactly the manual
# cleanup performed for the operator during M018 close. Strict-tuple
# match: never structural-shape match; user-authored entries with extra
# fields are preserved. --dry-run emits the diff without mutating
# settings.json. Repair is a one-shot cleanup that short-circuits the
# rest of the installer flow (no probe, no payload staging, no runtime
# staging).
if [ "$REPAIR" = "1" ]; then
  hook_target="$HOME/.claude/settings.json"
  if [ ! -f "$hook_target" ]; then
    echo "SKIP: $hook_target not present, nothing to repair"
    exit 0
  fi

  if [ ! -f "$MERGE_HELPER" ]; then
    echo "FAIL: settings-merge helper not found at $MERGE_HELPER" >&2
    exit 1
  fi

  if [ "$DRY_RUN" = "1" ]; then
    bash "$MERGE_HELPER" repair --target "$hook_target" --dry-run
    rep_rc=$?
  else
    bash "$MERGE_HELPER" repair --target "$hook_target"
    rep_rc=$?
  fi

  if [ "$rep_rc" -ne 0 ]; then
    echo "FAIL: settings-merge.sh repair exited $rep_rc" >&2
    exit 1
  fi

  exit 0
fi

# --- Sanity: adapter exists ---
if [ ! -f "$ADAPTER" ]; then
  echo "FAIL: adapter not found at $ADAPTER" >&2
  exit 1
fi

# --- 1. Probe ---
log "probing claude-code runtime"
probe_out="$(bash "$ADAPTER" --probe 2>&1)"
probe_rc=$?
if [ $probe_rc -ne 0 ]; then
  echo "FAIL: probe exited $probe_rc: $probe_out" >&2
  exit 1
fi
echo "$probe_out" | grep -q '^available=true'
if [ $? -ne 0 ]; then
  echo "FAIL: claude-code not available" >&2
  echo "$probe_out" >&2
  exit 3
fi

# --- 2. Register skills (delegate to adapter) ---
log "registering skills via adapter --register"
skills_installed=0
if [ "$DRY_RUN" = "1" ]; then
  reg_out="$(bash "$ADAPTER" --register --dry-run 2>&1)"
  reg_rc=$?
  printf '%s\n' "$reg_out"
  if [ $reg_rc -ne 0 ]; then
    echo "FAIL: adapter --register --dry-run exited $reg_rc" >&2
    exit 1
  fi
  # Extract count from `dry_run=true count=<N> agents=<M>` (agents may be 0 or absent on older adapters).
  skills_installed="$(printf '%s\n' "$reg_out" | sed -n 's/^dry_run=true count=\([0-9][0-9]*\).*$/\1/p' | head -n 1)"
  [ -z "$skills_installed" ] && skills_installed=0
  agents_installed="$(printf '%s\n' "$reg_out" | sed -n 's/^dry_run=true count=[0-9][0-9]* agents=\([0-9][0-9]*\)$/\1/p' | head -n 1)"
  [ -z "$agents_installed" ] && agents_installed=0
else
  reg_out="$(bash "$ADAPTER" --register 2>&1)"
  reg_rc=$?
  printf '%s\n' "$reg_out"
  if [ $reg_rc -ne 0 ]; then
    echo "FAIL: adapter --register exited $reg_rc" >&2
    exit 1
  fi
  skills_installed="$(printf '%s\n' "$reg_out" | sed -n 's/^registered=true count=\([0-9][0-9]*\).*$/\1/p' | head -n 1)"
  [ -z "$skills_installed" ] && skills_installed=0
  agents_installed="$(printf '%s\n' "$reg_out" | sed -n 's/^registered=true count=[0-9][0-9]* agents=\([0-9][0-9]*\)$/\1/p' | head -n 1)"
  [ -z "$agents_installed" ] && agents_installed=0
fi

# --- 2.5 Stage hooks payload into runtime-stable hooks dir (M028/P02/T03) ---
# CON-9: ${HOME}/.claude/orchestrator-hooks/ is the runtime-stable contract.
# The directory holds:
#   pre-bash-shape-guard.sh  -- T01 self-locating hook (resolves classifier
#                                as ${HOOK_DIR}/shape-classifier.sh)
#   shape-classifier.sh      -- M021 classifier library (sibling of hook)
#   before-commit.sh         -- M025 lifecycle script (PreToolUse Bash)
#   after-verify-sync.sh     -- M025 lifecycle script (Stop)
#   MANIFEST                 -- text file listing staged set (used by --uninstall)
#
# Repeat-install is idempotent: cp -f overwrites in place. The MANIFEST format
# is one filename per line; --uninstall walks it instead of `find ... -delete`
# so user-authored siblings (if any) are preserved.
HOOKS_DIR="$HOME/.claude/orchestrator-hooks"
HOOKS_PAYLOAD=""
HOOKS_PAYLOAD="${HOOKS_PAYLOAD} ${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"
HOOKS_PAYLOAD="${HOOKS_PAYLOAD} ${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"
HOOKS_PAYLOAD="${HOOKS_PAYLOAD} ${REPO_ROOT}/scripts/lifecycle/before-commit.sh"
HOOKS_PAYLOAD="${HOOKS_PAYLOAD} ${REPO_ROOT}/scripts/lifecycle/after-verify-sync.sh"

hooks_staged=0
if [ "$DRY_RUN" = "1" ]; then
  for src in $HOOKS_PAYLOAD; do
    echo "would_write=${HOOKS_DIR}/$(basename "$src")"
    hooks_staged=$((hooks_staged + 1))
  done
  echo "would_write=${HOOKS_DIR}/MANIFEST"
else
  mkdir -p "$HOOKS_DIR"
  for src in $HOOKS_PAYLOAD; do
    if [ ! -f "$src" ]; then
      echo "FAIL: hooks payload source missing: $src" >&2
      exit 1
    fi
    cp -f "$src" "${HOOKS_DIR}/$(basename "$src")"
    hooks_staged=$((hooks_staged + 1))
  done
  : > "${HOOKS_DIR}/MANIFEST"
  for src in $HOOKS_PAYLOAD; do
    echo "$(basename "$src")" >> "${HOOKS_DIR}/MANIFEST"
  done
  echo "MANIFEST" >> "${HOOKS_DIR}/MANIFEST"
  echo "hooks_staged=${hooks_staged} dir=${HOOKS_DIR}"
fi

# --- 3. Wire hooks: merge-not-overwrite into settings.json (M025/P01/T02) ---
# The adapter emits a Claude Code hooks fragment tagged with
# "_orchestrator_managed": true on every leaf. The merge helper
# (scripts/util/settings-merge.sh) preserves any pre-existing user-authored
# keys byte-identically and only appends orchestrator entries that are not
# already present (idempotent on repeat install). --force bypasses the
# idempotency guard so manual edits that stripped the managed tag can be
# recovered. Writes via temp-file-then-rename.
log "capturing hook-config"
hook_json="$(bash "$ADAPTER" --hook-config 2>/dev/null)"
hook_target="$HOME/.claude/settings.json"
hooks_wired=0

if [ ! -f "$MERGE_HELPER" ]; then
  echo "FAIL: settings-merge helper not found at $MERGE_HELPER" >&2
  exit 1
fi

mkdir -p "$HOME/.claude"

merge_args="merge --target $hook_target"
if [ "$DRY_RUN" = "1" ]; then
  if [ "$FORCE" = "1" ]; then
    bash "$MERGE_HELPER" merge --target "$hook_target" --fragment "$hook_json" --force --dry-run
  else
    bash "$MERGE_HELPER" merge --target "$hook_target" --fragment "$hook_json" --dry-run
  fi
  merge_rc=$?
else
  if [ "$FORCE" = "1" ]; then
    bash "$MERGE_HELPER" merge --target "$hook_target" --fragment "$hook_json" --force
  else
    bash "$MERGE_HELPER" merge --target "$hook_target" --fragment "$hook_json"
  fi
  merge_rc=$?
fi
if [ $merge_rc -ne 0 ]; then
  echo "FAIL: settings-merge.sh merge exited $merge_rc" >&2
  exit 1
fi
hooks_wired=1

# --- 4. Stage orchestrator config into project state root ---
log "resolving state root for $PROJECT_DIR"
state_root=""
if [ -x "$RESOLVE_ROOT" ]; then
  # Invoke resolve-root.sh from the project dir so it walks the correct tree.
  state_root="$(cd "$PROJECT_DIR" && bash "$RESOLVE_ROOT" --absolute 2>/dev/null)"
fi
if [ -z "$state_root" ]; then
  state_root="$PROJECT_DIR/.orchestrator"
fi

cfg_src="$BUNDLE/config/orchestrator.default.yml"
cfg_target="$state_root/config.yml"
config_written=0

if [ ! -f "$cfg_src" ]; then
  echo "FAIL: bundle config not found at $cfg_src" >&2
  exit 1
fi

# M037 P01 T06 (FR-10/FR-11/CON-3) — config emit via shared yaml-merge primitive.
# Replaces the pre-T06 "skip if exists / overwrite with --force" logic that
# clobbered operator customizations. The merge primitive preserves operator-
# authored top-level keys byte-identical, applies new orchestrator-managed
# defaults under managed namespaces, and fails closed on malformed YAML.
YAML_MERGE="$REPO_ROOT/scripts/lib/yaml-merge.sh"
MANAGED_NAMESPACES="default_tier,verification_commands,context_verbosity,git_isolation,dispatch_budget,duration_budget,budget_enforcement,auto_proceed,autonomy,compression,quick_knowledge_token_budget,entry_routing_confidence_floor,tier_a_plus_prompt_summary_lines,display_thresholds,wiki"
if [ "$DRY_RUN" = "1" ]; then
  bash "$YAML_MERGE" merge --target "$cfg_target" --framework-default "$cfg_src" --managed-namespaces "$MANAGED_NAMESPACES" --dry-run >/dev/null
  echo "would_write=$cfg_target"
  config_written=1
else
  mkdir -p "$state_root"
  bash "$YAML_MERGE" merge --target "$cfg_target" --framework-default "$cfg_src" --managed-namespaces "$MANAGED_NAMESPACES"
  merge_rc=$?
  if [ "$merge_rc" -ne 0 ]; then
    echo "FAIL: yaml-merge.sh exited $merge_rc against $cfg_target" >&2
    exit 1
  fi
  echo "wrote=$cfg_target"
  config_written=1
fi

# --- 4.4 install-meta.txt sidecar (early write, robust to staging failure) ---
# Records the orchestrator source repo path so staged scripts (e.g.
# scripts/lifecycle/wiki-init.sh) can resolve packaging/bundle/manifest.yml
# from a consumer project. Sidecar (not interleaved into installed-files.txt)
# because the latter is a flat `<rel>\tmode:<copy|symlink>` list consumed
# positionally by the uninstall path.
#
# Written BEFORE Stage 4.5 (asset staging) so an FR-22 staged-dirs-collision
# on a re-install (e.g. wiki/ pre-staged by wiki-init.sh on a prior run)
# does not lose the metadata. The sidecar reflects the install ATTEMPT, not
# successful completion of every asset.
meta_file="$PROJECT_DIR/.orchestrator/install-meta.txt"
# M035 P01 T01 (#Q-9): two new fields — `commit_sha=` (empty when .git
# absent) and `version=` (top-line `## [X.Y.Z]` heading from CHANGELOG.md
# per CON-4). Both lines are always emitted; empty values are explicit
# (e.g. `commit_sha=`) so the M035 P01 drift helper can distinguish
# "field absent (pre-M035 install)" from "field present but empty".
commit_sha_val=""
if [ -d "$REPO_ROOT/.git" ]; then
  commit_sha_val="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
fi
version_val="$(awk '/^## \[/{print; exit}' "$REPO_ROOT/CHANGELOG.md" 2>/dev/null | sed -E 's/^## \[([^]]+)\].*/\1/')"
if [ "$DRY_RUN" = "1" ]; then
  echo "would_write=$meta_file"
else
  mkdir -p "$(dirname "$meta_file")"
  {
    printf 'source_root=%s\n' "$REPO_ROOT"
    printf 'runtime=%s\n' "claude-code"
    printf 'installed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'commit_sha=%s\n' "$commit_sha_val"
    printf 'version=%s\n' "$version_val"
  } > "$meta_file"
fi

# --- 4.4.6 Rollback marker (M035 P05 T01, FR-12 / D005) ---
# Snapshots the prior install's manifest and writes the
# .orchestrator/.previous-version marker BEFORE the new manifest is
# staged at Stage 4.5. Greenfield installs (no prior installed-files.txt)
# are a no-op via the writer's internal greenfield check.
#
# The writer is idempotent: re-installs at the same version overwrite
# both the marker and the snapshot in place.
if [ "$DRY_RUN" = "1" ]; then
  bash "$REPO_ROOT/scripts/lifecycle/write-rollback-marker.sh" \
    --project-dir "$PROJECT_DIR" --dry-run
  _wrm_rc=$?
else
  bash "$REPO_ROOT/scripts/lifecycle/write-rollback-marker.sh" \
    --project-dir "$PROJECT_DIR"
  _wrm_rc=$?
fi
if [ "$_wrm_rc" -ne 0 ]; then
  echo "FAIL: write-rollback-marker.sh exited $_wrm_rc" >&2
  exit "$_wrm_rc"
fi

# --- 4.4.5 Managed .gitignore block (M035 P00 T02, FR-6 / SC-6) ---
# Append/replace the orchestrator-managed marker block in
# <PROJECT_DIR>/.gitignore covering installer-owned sidecars (currently only
# .orchestrator/install-meta.txt). Idempotent: re-runs leave exactly one
# block. Skipped on --uninstall and --repair (those paths short-circuit
# before this stage). Helper is identical across all three installers.
if [ "$DRY_RUN" = "1" ]; then
  bash "$REPO_ROOT/scripts/lifecycle/emit-managed-gitignore.sh" --project-dir "$PROJECT_DIR" --dry-run
  _emit_rc=$?
else
  bash "$REPO_ROOT/scripts/lifecycle/emit-managed-gitignore.sh" --project-dir "$PROJECT_DIR"
  _emit_rc=$?
fi
if [ "$_emit_rc" -ne 0 ]; then
  echo "FAIL: emit-managed-gitignore.sh exited $_emit_rc" >&2
  exit "$_emit_rc"
fi

# --- 4.5 Stage runtime payload via project_assets: manifest schema (FR-2 + FR-3 + FR-4 + FR-22) ---
# The pre-M032 hardcoded loop is fully replaced by the project_assets:
# schema in packaging/bundle/manifest.yml. Each tuple from
# read-project-assets.sh is dispatched through:
#   1. install-collision-check.sh (FR-22 dual-oracle hierarchy)
#   2. install-asset-mode.sh      (FR-3 per-mode handler)
# At mode: copy the per-target file-tree is byte-identical to the pre-M032
# behavior (CON-4 reference: tools/verify/fixtures/m032-pre-m032-golden.txt).
# --asset-mode-override flag (TEST-ONLY) lets P01 acceptance scripts
# exercise mode: symlink without re-authoring the manifest.
manifest_file="$PROJECT_DIR/.orchestrator/installed-files.txt"
runtime_staged=0
project_assets_targets=""

# --skip-project-assets (global npm install): register skills + hooks only,
# stage nothing into a project. The body below is intentionally left at its
# original indentation to keep this guard a minimal, reviewable diff.
if [ "${SKIP_PROJECT_ASSETS:-0}" = "1" ]; then
  echo "skipped=project-asset staging (--skip-project-assets)"
else

# First pass: collect the project-assets target list (needed by collision check
# for the bootstrapping oracle's "in the project_assets target list" check).
#
# M035 P00 T01: bash-3.2 exit-status capture. Process-substitution-fed
# `while read` loops (`done < <(bash ...)`) silently mask the producer's
# non-zero exit on macOS bash 3.2, so a malformed manifest or a missing
# producer is invisible to the installer. We write the producer's stdout to
# a temp file, capture rc explicitly, then iterate the temp file.
_collect_tmp="$(mktemp -t orch-install-collect.XXXXXX)"
bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/" > "$_collect_tmp"
_producer_rc=$?
if [ "$_producer_rc" -ne 0 ]; then
  rm -f "$_collect_tmp"
  echo "FAIL: read-project-assets.sh exited $_producer_rc (collect pass)" >&2
  exit 1
fi
while IFS= read -r tuple; do
  tgt=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
  project_assets_targets="${project_assets_targets}${tgt}\n"
done < "$_collect_tmp"
rm -f "$_collect_tmp"

# Second pass: dispatch each tuple through collision check + mode handler.
_dispatch_tmp="$(mktemp -t orch-install-dispatch.XXXXXX)"
bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/" > "$_dispatch_tmp"
_producer_rc=$?
if [ "$_producer_rc" -ne 0 ]; then
  rm -f "$_dispatch_tmp"
  echo "FAIL: read-project-assets.sh exited $_producer_rc (dispatch pass)" >&2
  exit 1
fi
_inner_rc=0
while IFS= read -r tuple; do
  src_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^source=/){sub(/^source=/, "", $i); print $i}}}')
  tgt_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
  mode_val=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^mode=/){sub(/^mode=/, "", $i); print $i}}}')

  # Wiki is staged on-demand by wiki-init.sh (orchestrator:wiki-init), never
  # at base install: it is intentionally absent from the distributed tarball
  # (tools/verify/m035-p02-npm-pack-contents.sh asserts check_absent "wiki"),
  # so staging it here would fail on every package-manager install. Skip the
  # entry before the missing-source check; the manifest keeps it for wiki-init.
  case "${tgt_rel%/}" in
    wiki) continue ;;
  esac

  # --asset-mode-override (TEST-ONLY) takes precedence over manifest mode.
  [ -n "${ASSET_MODE_OVERRIDE:-}" ] && mode_val="$ASSET_MODE_OVERRIDE"

  src_abs="$REPO_ROOT/${src_rel%/}"
  dst_abs="$PROJECT_DIR/${tgt_rel%/}"

  if [ ! -d "$src_abs" ]; then
    echo "FAIL: project_assets source missing: $src_abs" >&2
    exit 1
  fi

  # FR-22 collision check. PBJ-2026-05-08: operator-owned is soft-skip in the
  # project_assets loop — wiki/ on a re-install is the canonical case. The
  # default fail-closed semantic stays intact for direct callers (SC-10).
  set +e
  bash "$REPO_ROOT/scripts/lifecycle/install-collision-check.sh" \
    --on-operator-owned=skip \
    "$dst_abs" "$PROJECT_DIR" "$(printf '%b' "$project_assets_targets")"
  rc=$?
  set -e
  case "$rc" in
    0) : ;;
    5) continue ;;
    4)
      echo "FAIL: staged-dirs-collision: project_assets entry $src_rel collides with operator-owned $tgt_rel" >&2
      exit "$rc" ;;
    *) exit "$rc" ;;
  esac

  # FR-3 mode dispatch (copy or symlink).
  if [ "$DRY_RUN" = "1" ]; then
    find "$src_abs" -type f | while IFS= read -r f; do
      rel="${f#$src_abs/}"
      echo "would_write=$dst_abs/$rel"
    done
    cnt=$(find "$src_abs" -type f | wc -l | tr -d ' ')
    runtime_staged=$((runtime_staged + cnt))
  else
    bash "$REPO_ROOT/scripts/lifecycle/install-asset-mode.sh" \
      "$src_abs" "$dst_abs" "$mode_val" "$PROJECT_DIR"
    handler_rc=$?
    _inner_step_rc=$handler_rc
    if [ "$handler_rc" -ne 0 ]; then
      # FR-3 fail-closed propagation (e.g. M032_FORCE_WINDOWS=1, exit 3
      # for POSIX-only-in-v1; exit 2 for invalid mode).
      echo "FAIL: install-asset-mode.sh exited $handler_rc for $src_rel ($mode_val)" >&2
      rm -f "$_dispatch_tmp"
      exit "$handler_rc"
    fi
    cnt=$(find "$src_abs" -type f | wc -l | tr -d ' ')
    runtime_staged=$((runtime_staged + cnt))
  fi
  if [ "${_inner_step_rc:-0}" -ne 0 ]; then _inner_rc=$_inner_step_rc; fi
done < "$_dispatch_tmp"
rm -f "$_dispatch_tmp"
if [ "$_inner_rc" -ne 0 ]; then
  echo "FAIL: dispatch pass had inner failure rc=$_inner_rc" >&2
  exit "$_inner_rc"
fi

# FR-4: write installed-files.txt with per-asset mode: field.
if [ "$DRY_RUN" = "0" ]; then
  mkdir -p "$(dirname "$manifest_file")"
  : > "$manifest_file"
  _manifest_tmp="$(mktemp -t orch-install-manifest.XXXXXX)"
  bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/" > "$_manifest_tmp"
  _producer_rc=$?
  if [ "$_producer_rc" -ne 0 ]; then
    rm -f "$_manifest_tmp"
    echo "FAIL: read-project-assets.sh exited $_producer_rc (manifest pass)" >&2
    exit 1
  fi
  while IFS= read -r tuple; do
    tgt_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
    mode_val=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^mode=/){sub(/^mode=/, "", $i); print $i}}}')
    [ -n "${ASSET_MODE_OVERRIDE:-}" ] && mode_val="$ASSET_MODE_OVERRIDE"
    case "$mode_val" in
      symlink)
        # M035/P01/T02: symlink-mode records the symlink path itself, NOT the
        # files beneath the linked directory. uninstall removes only the
        # symlink, leaving the orchestrator source repo untouched (CON-1).
        if [ -L "$PROJECT_DIR/${tgt_rel%/}" ] || [ -e "$PROJECT_DIR/${tgt_rel%/}" ]; then
          printf '%s\tmode:symlink\n' "${tgt_rel%/}" >> "$manifest_file"
        fi
        ;;
      copy|*)
        if [ -d "$PROJECT_DIR/${tgt_rel%/}" ]; then
          ( cd "$PROJECT_DIR" && find "${tgt_rel%/}" -type f ) | \
            awk -v m="$mode_val" '{printf "%s\tmode:%s\n", $0, m}' >> "$manifest_file"
        fi
        ;;
    esac
  done < "$_manifest_tmp"
  rm -f "$_manifest_tmp"
  echo "staged=$runtime_staged files manifest=$manifest_file"
fi

fi  # end --skip-project-assets guard

# --- 5. Summary line ---
echo "SUMMARY: runtime=claude-code skills_installed=${skills_installed} agents_installed=${agents_installed} hooks_wired=${hooks_wired} hooks_staged=${hooks_staged} config_written=${config_written} runtime_staged=${runtime_staged} dry_run=${DRY_RUN}"

# --- 6. Optional sister-project hint (purely informational; never alters exit) ---
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/conversus-detect.sh"
emit_conversus_note

exit 0
