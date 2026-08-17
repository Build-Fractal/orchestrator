#!/usr/bin/env bash
# tools/verify/m046-p05-install-wiring.sh -- M046/P05/T02 install-wiring verifier.
#
# Productionizes the M046/P01/T01 throwaway install-matrix spike
# (.orchestrator/milestones/M046/phases/P01/spike/hook/run-install-matrix.sh)
# into a durable verifier that targets the REAL production hook
# (scripts/hooks/unattended-scope-guard.sh) and the REAL adapter fragment
# (scripts/dispatch/adapters/runtime/claude-code.sh --hook-config), NOT a
# hand-built probe + hand-merged fragment.
#
# Answers the install half of FR-9/FR-20 as shipped: does the NEW default-DENY
# PreToolUse scope-guard ride the M028 consumer path -- staged into
# ~/.claude/orchestrator-hooks/ via HOOKS_PAYLOAD + merged into settings.json
# via the adapter's --hook-config wrapper -- on both real install shapes,
# coexisting with the already-wired shape-guard (pre-bash-shape-guard.sh),
# idempotent on re-install, and clean on uninstall?
#
#   Shape A (symlink/source): run packaging/install/install-claude-code.sh
#     straight from the repo tree.
#   Shape B (packaged bundle): copy the distributable subtrees into a scratch
#     stage dir, run that stage's packaging/bundle/build-bundle.sh (which also
#     applies the M035 bundle-hygiene filter -- the production hook + manifest
#     survive because they live under scripts/hooks/, not scripts/verify/ /
#     tools/verify/ / templates/conversus-presets/, and carry no
#     `bundle: dogfood-only` magic comment), then run the STAGED installer.
#
# For each shape, in an ISOLATED scratch HOME + scratch project dir (the
# operator's real ~/.claude is NEVER touched -- see the self-check below):
#   1. Run the installer (stages the whole HOOKS_PAYLOAD incl. the scope-guard
#      hook + its protected-surface manifest, then merges the adapter fragment
#      which now carries BOTH PreToolUse wrappers).
#   2. Assert the scope-guard hook is staged + executable and the manifest .txt
#      is staged.
#   3. Assert settings.json carries the scope-guard command AND the shape-guard
#      command (coexistence) AND the literal matcher `Write|Edit|Bash|mcp__.*`.
#   4. Idempotency: re-run the installer; the `"command"` leaf count is stable.
#   5. Uninstall: run the installer --uninstall; assert no `_orchestrator_managed`
#      entry and no scope-guard command remain.
#   6. Emit one structured line per shape:
#      shape=<A|B> staged=<0|1> merged=<0|1> coexists=<0|1> matcher=<0|1> \
#        idempotent=<0|1> uninstall_clean=<0|1>
#
# Bash 3.2 compatible. No jq (settings-merge.sh itself uses python3). Repo-
# resident verifier, invoked directly (no run-probe.sh wrapper).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/m046-p05-install.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0

run_shape() {
  # $1 = shape label (A|B); $2 = src-tree root holding packaging/ + scripts/
  _shape="$1"
  _src="$2"
  _home="$SCRATCH/home-$_shape"
  _proj="$SCRATCH/project-$_shape"

  # --- Safety self-check: HOME must be a scratch dir (SCRATCH prefix) BEFORE
  #     any installer run. A deny-hook must NEVER land in the operator's live
  #     ~/.claude. Refuse to proceed otherwise. ---
  case "$_home" in
    "$SCRATCH"/*) : ;;
    *)
      echo "FAIL: shape=$_shape refusing to run installer -- HOME '$_home' is not under scratch '$SCRATCH'" >&2
      FAIL=$((FAIL + 1))
      return 0 ;;
  esac

  mkdir -p "$_home/.claude"
  mkdir -p "$_proj"

  _staged=0
  _merged=0
  _coexists=0
  _matcher=0
  _idempotent=0
  _uninstall_clean=0

  _settings="$_home/.claude/settings.json"
  _hooks_dir="$_home/.claude/orchestrator-hooks"
  _guard_cmd="bash $_hooks_dir/unattended-scope-guard.sh"
  _shape_cmd="bash $_hooks_dir/pre-bash-shape-guard.sh"

  # --- 1. Installer run (isolated HOME + scratch project dir) ---
  HOME="$_home" bash "$_src/packaging/install/install-claude-code.sh" \
    --project-dir "$_proj" > "$SCRATCH/install-$_shape.out" 2>&1
  _install_rc=$?
  if [ "$_install_rc" -ne 0 ]; then
    echo "# shape $_shape installer_rc=$_install_rc log=$SCRATCH/install-$_shape.out" >&2
    echo "shape=$_shape staged=0 merged=0 coexists=0 matcher=0 idempotent=0 uninstall_clean=0"
    FAIL=$((FAIL + 1))
    return 0
  fi

  # --- 2. Staged production hook + manifest (rode HOOKS_PAYLOAD) ---
  if [ -f "$_hooks_dir/unattended-scope-guard.sh" ] && [ -x "$_hooks_dir/unattended-scope-guard.sh" ] \
     && [ -f "$_hooks_dir/unattended-protected-surface.txt" ]; then
    _staged=1
  fi

  # --- 3. Merged scope-guard command + coexistence + literal matcher ---
  if [ -f "$_settings" ]; then
    _guard_hits="$(grep -F -c "$_guard_cmd" "$_settings")"
    _shape_hits="$(grep -F -c "$_shape_cmd" "$_settings")"
    _matcher_hits="$(grep -F -c 'Write|Edit|Bash|mcp__.*' "$_settings")"
    if [ "$_guard_hits" -ge 1 ]; then
      _merged=1
    fi
    if [ "$_guard_hits" -ge 1 ] && [ "$_shape_hits" -ge 1 ]; then
      _coexists=1
    fi
    if [ "$_matcher_hits" -ge 1 ]; then
      _matcher=1
    fi
  fi

  # --- 4. Idempotency: re-install must not accrete leaves ---
  _leaves_before="$(grep -c '"command"' "$_settings" 2>/dev/null || echo 0)"
  HOME="$_home" bash "$_src/packaging/install/install-claude-code.sh" \
    --project-dir "$_proj" >> "$SCRATCH/install-$_shape.out" 2>&1
  _reinstall_rc=$?
  _leaves_after="$(grep -c '"command"' "$_settings" 2>/dev/null || echo 0)"
  if [ "$_reinstall_rc" -eq 0 ] && [ "$_leaves_before" = "$_leaves_after" ]; then
    _idempotent=1
  fi
  echo "# shape $_shape leaf_lines_before=$_leaves_before leaf_lines_after=$_leaves_after" >&2

  # --- 5. Uninstall: managed entries removed cleanly ---
  HOME="$_home" bash "$_src/packaging/install/install-claude-code.sh" \
    --uninstall --project-dir "$_proj" >> "$SCRATCH/install-$_shape.out" 2>&1
  _un_rc=$?
  # The installer's uninstall path may unlink settings.json entirely when it
  # normalizes to an empty object -- a file-absent settings.json is clean.
  if [ -f "$_settings" ]; then
    _guard_left="$(grep -F -c "$_guard_cmd" "$_settings")"
    _managed_left="$(grep -c '_orchestrator_managed' "$_settings")"
  else
    _guard_left=0
    _managed_left=0
  fi
  if [ "$_un_rc" -eq 0 ] && [ "$_guard_left" = "0" ] && [ "$_managed_left" = "0" ]; then
    _uninstall_clean=1
  fi

  echo "shape=$_shape staged=$_staged merged=$_merged coexists=$_coexists matcher=$_matcher idempotent=$_idempotent uninstall_clean=$_uninstall_clean"

  if [ "$_staged$_merged$_coexists$_matcher$_idempotent$_uninstall_clean" = "111111" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
}

# --- Shape A: symlink/source -- installer runs from the repo tree ---
run_shape A "$REPO_ROOT"

# --- Shape B: packaged bundle -- distributable subtrees staged + bundle built ---
STAGE_B="$SCRATCH/stage-B"
mkdir -p "$STAGE_B"
for d in commands scripts references templates packaging; do
  cp -R "$REPO_ROOT/$d" "$STAGE_B/$d"
done
cp "$REPO_ROOT/CHANGELOG.md" "$STAGE_B/CHANGELOG.md"
if [ -f "$REPO_ROOT/VERSION" ]; then
  cp "$REPO_ROOT/VERSION" "$STAGE_B/VERSION"
fi
bash "$STAGE_B/packaging/bundle/build-bundle.sh" > "$SCRATCH/bundle-build.out" 2>&1
_bundle_rc=$?
echo "# shape B bundle_build_rc=$_bundle_rc log=$SCRATCH/bundle-build.out" >&2
# Bundle-hygiene survival check: the production hook + manifest must still be
# present in the staged tree after build-bundle.sh runs its M035 filter.
if [ -f "$STAGE_B/scripts/hooks/unattended-scope-guard.sh" ] \
   && [ -f "$STAGE_B/scripts/hooks/unattended-protected-surface.txt" ]; then
  echo "# shape B bundle_hygiene_survival=1 (scope-guard hook + manifest present post-filter)" >&2
else
  echo "FAIL: shape B bundle-hygiene stripped the scope-guard hook or manifest" >&2
  FAIL=$((FAIL + 1))
fi
if [ "$_bundle_rc" -ne 0 ]; then
  echo "shape=B staged=0 merged=0 coexists=0 matcher=0 idempotent=0 uninstall_clean=0"
  FAIL=$((FAIL + 1))
else
  run_shape B "$STAGE_B"
fi

echo "SUMMARY: pass=$PASS fail=$FAIL"
if [ "$FAIL" -eq 0 ] && [ "$PASS" -eq 2 ]; then
  exit 0
fi
exit 1
