#!/usr/bin/env bash
# run-install-matrix.sh -- M046/P01/T01 THROWAWAY SPIKE install-shape matrix.
#
# Answers the install half of #Q-1: does a NEW PreToolUse hook (the
# unattended-deny-probe) ride the M028 consumer path -- staged hooks dir
# (~/.claude/orchestrator-hooks/) + managed settings-merge fragment --
# on both real install shapes, coexisting with the already-registered
# shape-guard entry, WITHOUT installer changes?
#
#   Shape A (symlink/source): run packaging/install/install-claude-code.sh
#     straight from the repo tree.
#   Shape B (packaged-bundle): copy the distributable subtrees into a
#     scratch stage dir, run that stage's packaging/bundle/build-bundle.sh
#     (which also applies the M035 bundle-hygiene filter), then run the
#     STAGED installer.
#
# For each shape (isolated scratch HOME + scratch project dir -- the real
# $HOME/.claude is NEVER touched):
#   1. Run the installer (stages shape-guard payload + merges its fragment).
#   2. Manually cp the probe hook into $HOME/.claude/orchestrator-hooks/
#      (mirrors what P05 will add to HOOKS_PAYLOAD).
#   3. Merge the probe's PreToolUse fragment via settings-merge.sh
#      (matcher "Write|Edit|Bash|mcp__.*", _orchestrator_managed: true).
#   4. Assert: staged+executable; probe entry merged; shape-guard entry
#      coexists; re-merge is a no-op (leaf-line count unchanged);
#      settings-merge.sh uninstall removes all managed entries cleanly.
#   5. Append one log line:
#      shape=<A|B> staged=<0|1> merged=<0|1> coexists=<0|1> idempotent=<0|1> uninstall_clean=<0|1>
#
# Scratch root: /private/tmp (override with M046_SPIKE_SCRATCH).
# Bash 3.2 compatible. No jq (settings-merge.sh itself uses python3).

set -u

SPIKE_DIR="$(cd "$(dirname "$0")" && pwd)"
# spike/hook -> spike -> P01 -> phases -> M046 -> milestones -> .orchestrator -> repo root
REPO_ROOT="$(cd "$SPIKE_DIR/../../../../../../.." && pwd)"
LOG="$SPIKE_DIR/install-matrix.log"

SCRATCH_BASE="${M046_SPIKE_SCRATCH:-/private/tmp/m046-p01-hook-spike}"
rm -rf "$SCRATCH_BASE"
mkdir -p "$SCRATCH_BASE"

{
  echo "# M046/P01/T01 install-shape matrix (throwaway spike)"
  echo "# scratch_base=$SCRATCH_BASE"
  echo "# columns: staged merged coexists idempotent uninstall_clean (1=verified)"
} > "$LOG"

OVERALL_FAIL=0

run_shape() {
  # $1 = shape label (A|B), $2 = tree root holding packaging/ + scripts/
  _shape="$1"
  _src_root="$2"
  _home="$SCRATCH_BASE/home-$_shape"
  _proj="$SCRATCH_BASE/project-$_shape"
  # Pre-create .claude so the adapter probe sees home-claude-directory
  # (deterministic regardless of CLAUDECODE env).
  mkdir -p "$_home/.claude"
  mkdir -p "$_proj"

  _staged=0
  _merged=0
  _coexists=0
  _idempotent=0
  _uninstall_clean=0

  _settings="$_home/.claude/settings.json"
  _hooks_dir="$_home/.claude/orchestrator-hooks"
  _probe_cmd="bash $_hooks_dir/unattended-deny-probe.sh"
  _guard_cmd="bash $_hooks_dir/pre-bash-shape-guard.sh"

  # --- 1. Installer run (isolated HOME + scratch project dir) ---
  HOME="$_home" bash "$_src_root/packaging/install/install-claude-code.sh" \
    --project-dir "$_proj" > "$SCRATCH_BASE/install-$_shape.out" 2>&1
  _install_rc=$?
  echo "# shape $_shape installer_rc=$_install_rc log=$SCRATCH_BASE/install-$_shape.out" >> "$LOG"

  if [ "$_install_rc" -ne 0 ]; then
    echo "shape=$_shape staged=0 merged=0 coexists=0 idempotent=0 uninstall_clean=0" >> "$LOG"
    OVERALL_FAIL=1
    return 0
  fi

  # --- 2. Stage the probe hook exactly as P05's HOOKS_PAYLOAD addition would ---
  cp "$SPIKE_DIR/unattended-deny-probe.sh" "$_hooks_dir/unattended-deny-probe.sh"
  chmod +x "$_hooks_dir/unattended-deny-probe.sh"
  if [ -f "$_hooks_dir/unattended-deny-probe.sh" ] && [ -x "$_hooks_dir/unattended-deny-probe.sh" ]; then
    _staged=1
  fi

  # --- 3. Merge the probe's PreToolUse fragment (managed-tagged) ---
  _fragment='{"hooks":{"PreToolUse":[{"matcher":"Write|Edit|Bash|mcp__.*","hooks":[{"type":"command","command":"'"$_probe_cmd"'","_orchestrator_managed":true}]}]}}'
  bash "$_src_root/scripts/util/settings-merge.sh" merge \
    --target "$_settings" --fragment "$_fragment" >> "$SCRATCH_BASE/install-$_shape.out" 2>&1
  _merge_rc=$?

  if [ "$_merge_rc" -eq 0 ] && [ -f "$_settings" ]; then
    _probe_hits="$(grep -F -c "$_probe_cmd" "$_settings")"
    if [ "$_probe_hits" -ge 1 ]; then
      _merged=1
    fi
    _guard_hits="$(grep -F -c "$_guard_cmd" "$_settings")"
    if [ "$_guard_hits" -ge 1 ] && [ "$_probe_hits" -ge 1 ]; then
      _coexists=1
    fi
  fi

  # --- 4. Idempotency: re-merge must be a no-op (leaf-line count stable) ---
  _leaves_before="$(grep -c '"command"' "$_settings")"
  bash "$_src_root/scripts/util/settings-merge.sh" merge \
    --target "$_settings" --fragment "$_fragment" >> "$SCRATCH_BASE/install-$_shape.out" 2>&1
  _remerge_rc=$?
  _leaves_after="$(grep -c '"command"' "$_settings")"
  if [ "$_remerge_rc" -eq 0 ] && [ "$_leaves_before" = "$_leaves_after" ]; then
    _idempotent=1
  fi
  echo "# shape $_shape leaf_lines_before=$_leaves_before leaf_lines_after=$_leaves_after" >> "$LOG"

  # --- 5. Uninstall: managed entries (guard + probe) removed cleanly ---
  bash "$_src_root/scripts/util/settings-merge.sh" uninstall \
    --target "$_settings" >> "$SCRATCH_BASE/install-$_shape.out" 2>&1
  _un_rc=$?
  _probe_left="$(grep -F -c "$_probe_cmd" "$_settings")"
  _managed_left="$(grep -c '_orchestrator_managed' "$_settings")"
  if [ "$_un_rc" -eq 0 ] && [ "$_probe_left" = "0" ] && [ "$_managed_left" = "0" ]; then
    _uninstall_clean=1
  fi

  echo "shape=$_shape staged=$_staged merged=$_merged coexists=$_coexists idempotent=$_idempotent uninstall_clean=$_uninstall_clean" >> "$LOG"

  if [ "$_staged$_merged$_coexists$_idempotent$_uninstall_clean" != "11111" ]; then
    OVERALL_FAIL=1
  fi
}

# --- Shape A: symlink/source -- installer runs from the repo tree ---
run_shape A "$REPO_ROOT"

# --- Shape B: packaged bundle -- distributable subtrees staged + bundle built ---
STAGE_B="$SCRATCH_BASE/stage-B"
mkdir -p "$STAGE_B"
for d in commands scripts references templates packaging; do
  cp -R "$REPO_ROOT/$d" "$STAGE_B/$d"
done
cp "$REPO_ROOT/CHANGELOG.md" "$STAGE_B/CHANGELOG.md"
if [ -f "$REPO_ROOT/VERSION" ]; then
  cp "$REPO_ROOT/VERSION" "$STAGE_B/VERSION"
fi
bash "$STAGE_B/packaging/bundle/build-bundle.sh" > "$SCRATCH_BASE/bundle-build.out" 2>&1
_bundle_rc=$?
echo "# shape B bundle_build_rc=$_bundle_rc log=$SCRATCH_BASE/bundle-build.out" >> "$LOG"
if [ "$_bundle_rc" -ne 0 ]; then
  echo "shape=B staged=0 merged=0 coexists=0 idempotent=0 uninstall_clean=0" >> "$LOG"
  OVERALL_FAIL=1
else
  run_shape B "$STAGE_B"
fi

echo "MATRIX: log=$LOG"
grep 'shape=' "$LOG"
if [ "$OVERALL_FAIL" -eq 0 ]; then
  echo "MATRIX: both shapes all-1s"
  exit 0
fi
echo "MATRIX: at least one field failed -- see $LOG and $SCRATCH_BASE" >&2
exit 1
