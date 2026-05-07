#!/usr/bin/env bash
# packaging/install/install-cursor.sh -- Single-command Cursor installer.
#
# Delegates all runtime-specific work to the P05 adapter:
#   scripts/dispatch/adapters/runtime/cursor.sh
#
# Cursor is project-scoped (not HOME-scoped): it writes rules under
# <project-dir>/.cursor/rules/ and has no lifecycle-hook API. Consequently:
#   * --project-dir PATH is REQUIRED (vs optional for claude-code/codex).
#   * Hook wiring is a no-op; the installer reports hooks_wired=0.
#
# Responsibilities beyond the adapter:
#   * Invoke --probe (via --project-dir), fail fast if unavailable.
#   * Delegate skill registration via --register --project-dir [--dry-run].
#   * Emit the adapter's --hook-config fragment to stdout for transparency,
#     but do not write it anywhere (Cursor has no settings target).
#   * Stage packaging/bundle/config/orchestrator.default.yml into the project
#     orchestrator state root resolved via scripts/state/resolve-root.sh.
#   * Print a final `SUMMARY:` line with counts.
#
# Shared flag contract (see T03-PLAN):
#   --project-dir PATH   project root (REQUIRED for cursor)
#   --dry-run            no writes; emit `would_write=<path>` lines
#   --force              overwrite existing orchestrator config
#   --verbose            extra debug output on stderr
#   --asset-mode-override copy|symlink
#                        TEST-ONLY (M032 P01): overrides per-asset `mode:`
#                        from packaging/bundle/manifest.yml's project_assets:
#                        list. Used by P01 acceptance scripts to exercise
#                        mode: symlink without re-authoring the manifest.
#                        Will be replaced by manifest-declarable symlink
#                        mode in P02+.
#
# Exit codes:
#   0 success
#   1 generic failure (with FAIL: on stderr) -- includes missing --project-dir
#   2 unsafe environment (HOME='/' defensive parity)
#   3 runtime unavailable (probe returned available=false)
#
# Bash 3.2 compatible. No associative arrays, mapfile, jq, or python.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/runtime/cursor.sh"
RESOLVE_ROOT="$REPO_ROOT/scripts/state/resolve-root.sh"
BUNDLE="$REPO_ROOT/packaging/bundle"

PROJECT_DIR=""
DRY_RUN=0
FORCE=0
VERBOSE=0
UNINSTALL=0
# --asset-mode-override (TEST-ONLY, P01 surface; FR-3). Allowed values:
# `copy` or `symlink`. Empty default means manifest mode (`mode: copy`)
# wins. Will be replaced by manifest-declarable symlink mode in P02+.
ASSET_MODE_OVERRIDE=""

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
      sed -n '2,33p' "$0"
      exit 0 ;;
    *)
      echo "FAIL: unknown argument '$1'" >&2
      exit 1 ;;
  esac
done

log() { [ "$VERBOSE" = "1" ] && echo "[install-cursor] $*" >&2 || true; }

# --- Cursor requires --project-dir ---
if [ -z "$PROJECT_DIR" ]; then
  echo "FAIL: --project-dir is required for cursor" >&2
  exit 1
fi

# --- Project-dir guard (match adapter) ---
if [ "$PROJECT_DIR" = "/" ]; then
  echo "FAIL: unsafe --project-dir ('/'): refusing to install" >&2
  exit 2
fi

# --- HOME guard -- defensive parity with claude-code/codex installers. ---
# Cursor writes only under PROJECT_DIR, but a HOME='/' environment still
# signals a dangerously misconfigured shell. Empty HOME is tolerated.
if [ "${HOME:-}" = "/" ]; then
  echo "FAIL: unsafe HOME ('/'): refusing to install" >&2
  exit 2
fi

# --- Uninstall short-circuit: remove staged runtime per manifest. ---
if [ "$UNINSTALL" = "1" ]; then
  runtime_removed=0
  config_removed=0

  state_root=""
  if [ -x "$RESOLVE_ROOT" ]; then
    state_root="$(cd "$PROJECT_DIR" && bash "$RESOLVE_ROOT" --absolute 2>/dev/null)"
  fi
  [ -z "$state_root" ] && state_root="$PROJECT_DIR/.orchestrator"
  cfg_target="$state_root/config.yml"
  if [ -f "$cfg_target" ] && grep -q '_orchestrator_managed' "$cfg_target" 2>/dev/null; then
    if [ "$DRY_RUN" = "1" ]; then
      echo "would_remove=$cfg_target"
    else
      rm -f "$cfg_target"
      echo "removed=$cfg_target"
    fi
    config_removed=1
  fi

  manifest_file="$PROJECT_DIR/.orchestrator/installed-files.txt"
  if [ -f "$manifest_file" ]; then
    while IFS= read -r rel; do
      [ -z "$rel" ] && continue
      f="$PROJECT_DIR/$rel"
      if [ -f "$f" ]; then
        if [ "$DRY_RUN" = "1" ]; then
          echo "would_remove=$f"
        else
          rm -f "$f"
        fi
        runtime_removed=$((runtime_removed + 1))
      fi
    done < "$manifest_file"
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

  echo "UNINSTALLED: runtime-removed=${runtime_removed} config-removed=${config_removed}"
  exit 0
fi

if [ ! -f "$ADAPTER" ]; then
  echo "FAIL: adapter not found at $ADAPTER" >&2
  exit 1
fi

# --- 1. Probe (pass --project-dir so adapter checks for .cursor/) ---
log "probing cursor runtime with --project-dir=$PROJECT_DIR"
probe_out="$(bash "$ADAPTER" --probe --project-dir "$PROJECT_DIR" 2>&1)"
probe_rc=$?
if [ $probe_rc -ne 0 ]; then
  echo "FAIL: probe exited $probe_rc: $probe_out" >&2
  exit 1
fi
echo "$probe_out" | grep -q '^available=true'
if [ $? -ne 0 ]; then
  echo "FAIL: cursor not available" >&2
  echo "$probe_out" >&2
  exit 3
fi

# --- 2. Register skills (delegate to adapter with --project-dir) ---
log "registering skills via adapter --register --project-dir $PROJECT_DIR"
skills_installed=0
if [ "$DRY_RUN" = "1" ]; then
  reg_out="$(bash "$ADAPTER" --register --project-dir "$PROJECT_DIR" --dry-run 2>&1)"
  reg_rc=$?
  printf '%s\n' "$reg_out"
  if [ $reg_rc -ne 0 ]; then
    echo "FAIL: adapter --register --dry-run exited $reg_rc" >&2
    exit 1
  fi
  skills_installed="$(printf '%s\n' "$reg_out" | sed -n 's/^dry_run=true count=\([0-9][0-9]*\)$/\1/p' | head -n 1)"
  [ -z "$skills_installed" ] && skills_installed=0
else
  reg_out="$(bash "$ADAPTER" --register --project-dir "$PROJECT_DIR" 2>&1)"
  reg_rc=$?
  printf '%s\n' "$reg_out"
  if [ $reg_rc -ne 0 ]; then
    echo "FAIL: adapter --register exited $reg_rc" >&2
    exit 1
  fi
  skills_installed="$(printf '%s\n' "$reg_out" | sed -n 's/^registered=true count=\([0-9][0-9]*\)$/\1/p' | head -n 1)"
  [ -z "$skills_installed" ] && skills_installed=0
fi

# --- 3. Hook wiring: no-op for cursor. Emit the advisory fragment. ---
# Cursor has no lifecycle-hook API; the adapter's --hook-config returns a
# rules-only integration notice. We display it but write nothing.
log "capturing hook-config (advisory only; cursor has no hook target)"
hook_txt="$(bash "$ADAPTER" --hook-config 2>/dev/null)"
hooks_wired=0
if [ -n "$hook_txt" ]; then
  # Surface the advisory to stdout so operators see runtime=cursor hooks_supported=false.
  echo "hook_config_advisory<<<"
  printf '%s\n' "$hook_txt"
  echo ">>>"
fi

# --- 4. Stage orchestrator config into project state root ---
log "resolving state root for $PROJECT_DIR"
state_root=""
if [ -x "$RESOLVE_ROOT" ]; then
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
# Mirrors install-claude-code.sh — see that file for the full rationale.
# Written BEFORE Stage 4.5 so an FR-22 staged-dirs-collision on a re-install
# does not lose the metadata.
meta_file="$PROJECT_DIR/.orchestrator/install-meta.txt"
if [ "$DRY_RUN" = "1" ]; then
  echo "would_write=$meta_file"
else
  mkdir -p "$(dirname "$meta_file")"
  {
    printf 'source_root=%s\n' "$REPO_ROOT"
    printf 'runtime=%s\n' "cursor"
    printf 'installed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$meta_file"
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

# First pass: collect the project-assets target list (needed by collision check
# for the bootstrapping oracle's "in the project_assets target list" check).
while IFS= read -r tuple; do
  tgt=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
  project_assets_targets="${project_assets_targets}${tgt}\n"
done < <(bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/")

# Second pass: dispatch each tuple through collision check + mode handler.
while IFS= read -r tuple; do
  src_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^source=/){sub(/^source=/, "", $i); print $i}}}')
  tgt_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
  mode_val=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^mode=/){sub(/^mode=/, "", $i); print $i}}}')

  # --asset-mode-override (TEST-ONLY) takes precedence over manifest mode.
  [ -n "${ASSET_MODE_OVERRIDE:-}" ] && mode_val="$ASSET_MODE_OVERRIDE"

  src_abs="$REPO_ROOT/${src_rel%/}"
  dst_abs="$PROJECT_DIR/${tgt_rel%/}"

  if [ ! -d "$src_abs" ]; then
    echo "FAIL: project_assets source missing: $src_abs" >&2
    exit 1
  fi

  # FR-22 collision check (skips on collision-clean cases).
  if ! bash "$REPO_ROOT/scripts/lifecycle/install-collision-check.sh" \
    "$dst_abs" "$PROJECT_DIR" "$(printf '%b' "$project_assets_targets")"; then
    rc=$?
    if [ "$rc" = "4" ]; then
      echo "FAIL: staged-dirs-collision: project_assets entry $src_rel collides with operator-owned $tgt_rel" >&2
    fi
    exit "$rc"
  fi

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
    if [ "$handler_rc" -ne 0 ]; then
      # FR-3 fail-closed propagation (e.g. M032_FORCE_WINDOWS=1, exit 3
      # for POSIX-only-in-v1; exit 2 for invalid mode).
      echo "FAIL: install-asset-mode.sh exited $handler_rc for $src_rel ($mode_val)" >&2
      exit "$handler_rc"
    fi
    cnt=$(find "$src_abs" -type f | wc -l | tr -d ' ')
    runtime_staged=$((runtime_staged + cnt))
  fi
done < <(bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/")

# FR-4: write installed-files.txt with per-asset mode: field.
if [ "$DRY_RUN" = "0" ]; then
  mkdir -p "$(dirname "$manifest_file")"
  : > "$manifest_file"
  while IFS= read -r tuple; do
    tgt_rel=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^target=/){sub(/^target=/, "", $i); print $i}}}')
    mode_val=$(printf '%s\n' "$tuple" | awk -F'\t' '{for(i=1;i<=NF;i++){if($i ~ /^mode=/){sub(/^mode=/, "", $i); print $i}}}')
    [ -n "${ASSET_MODE_OVERRIDE:-}" ] && mode_val="$ASSET_MODE_OVERRIDE"
    if [ -d "$PROJECT_DIR/${tgt_rel%/}" ]; then
      ( cd "$PROJECT_DIR" && find "${tgt_rel%/}" -type f ) | \
        awk -v m="$mode_val" '{printf "%s\tmode:%s\n", $0, m}' >> "$manifest_file"
    fi
  done < <(bash "$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$REPO_ROOT/packaging/bundle/")
  echo "staged=$runtime_staged files manifest=$manifest_file"
fi

# --- 5. Summary line ---
echo "SUMMARY: runtime=cursor skills_installed=${skills_installed} hooks_wired=${hooks_wired} config_written=${config_written} runtime_staged=${runtime_staged} dry_run=${DRY_RUN}"
exit 0
