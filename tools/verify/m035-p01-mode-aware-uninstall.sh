#!/usr/bin/env bash
# tools/verify/m035-p01-mode-aware-uninstall.sh
# M035 P01 T02 must-have: assert CON-1 (M025 reversibility-gate) holds for
# both --mode=symlink and --mode=copy installs:
#
#   - symlink-mode: install --> uninstall removes only the staged symlinks
#     at <fixture>/<rel>, leaving the orchestrator source repo at $REPO_ROOT
#     untouched.
#   - copy-mode: install --> uninstall removes the staged regular-file tree
#     under <fixture>, leaving $REPO_ROOT and other unrelated PROJECT_DIR
#     siblings untouched (existing M025 behaviour preserved).
#
# POSIX SKIP: if `ln -s` is unavailable in the test host, the symlink-mode
# round-trip is skipped (rc=77) for that branch; the copy-mode round-trip
# still runs. If both branches skip, exit 77 with SKIP_REASON.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

TMP_BASE="$(mktemp -d -t m035-p01-uninstall.XXXXXX)"
TMP_HOME="$TMP_BASE/home"
mkdir -p "$TMP_HOME/.claude"

cleanup() {
  rm -rf "$TMP_BASE"
}
trap cleanup EXIT

fail=0
sym_skipped=0

# Probe `ln -s` availability so we can decide whether to exercise the
# symlink-mode round-trip.
ln_probe="$TMP_BASE/.lntest"
if ! ln -s /dev/null "$ln_probe" 2>/dev/null; then
  sym_skipped=1
fi
rm -f "$ln_probe"

# Snapshot source-repo state before running any installer round-trip; the
# CON-1 invariant says neither mode's uninstall may disturb $REPO_ROOT/scripts.
snap_pre_scripts="$(ls "$REPO_ROOT/scripts" 2>/dev/null | head -n 1 || true)"
snap_pre_commands="$(ls "$REPO_ROOT/commands" 2>/dev/null | head -n 1 || true)"

# --- symlink-mode round-trip ---
if [ "$sym_skipped" -eq 0 ]; then
  SYM_FIX="$TMP_BASE/sym"
  mkdir -p "$SYM_FIX"

  HOME="$TMP_HOME" bash "$INSTALLER" --mode=symlink --project-dir "$SYM_FIX" \
    > "$TMP_BASE/sym-install.log" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: symlink-mode install exited $rc" >&2
    echo "----- sym-install.log -----" >&2
    cat "$TMP_BASE/sym-install.log" >&2
    fail=1
  fi
  if ! [ -L "$SYM_FIX/scripts" ]; then
    echo "FAIL: symlink-mode install did not produce a symlink at <fixture>/scripts" >&2
    fail=1
  fi

  # Confirm the manifest carries mode:symlink rows (T02 contract).
  sym_manifest="$SYM_FIX/.orchestrator/installed-files.txt"
  if [ -f "$sym_manifest" ]; then
    if ! grep -q 'mode:symlink' "$sym_manifest"; then
      echo "FAIL: symlink-mode manifest missing mode:symlink rows" >&2
      echo "----- $sym_manifest -----" >&2
      cat "$sym_manifest" >&2
      fail=1
    fi
    # Also ensure no per-file expansion under a linked dir slipped in.
    if grep -q '^scripts/.*mode:symlink' "$sym_manifest"; then
      echo "FAIL: symlink-mode manifest expanded into per-file rows under scripts/" >&2
      cat "$sym_manifest" >&2
      fail=1
    fi
  else
    echo "FAIL: symlink-mode manifest missing at $sym_manifest" >&2
    fail=1
  fi

  HOME="$TMP_HOME" bash "$INSTALLER" --project-dir "$SYM_FIX" --uninstall \
    > "$TMP_BASE/sym-uninstall.log" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: symlink-mode uninstall exited $rc" >&2
    echo "----- sym-uninstall.log -----" >&2
    cat "$TMP_BASE/sym-uninstall.log" >&2
    fail=1
  fi
  if [ -L "$SYM_FIX/scripts" ]; then
    echo "FAIL: symlink-mode uninstall did not remove the symlink at <fixture>/scripts" >&2
    fail=1
  fi

  # CON-1 source-repo invariant: $REPO_ROOT/scripts must be undisturbed.
  snap_post_scripts="$(ls "$REPO_ROOT/scripts" 2>/dev/null | head -n 1 || true)"
  if [ "$snap_pre_scripts" != "$snap_post_scripts" ]; then
    echo "FAIL: \$REPO_ROOT/scripts disturbed by symlink-mode uninstall (pre=$snap_pre_scripts post=$snap_post_scripts)" >&2
    fail=1
  fi
fi

# --- copy-mode round-trip (existing behaviour preserved) ---
COPY_FIX="$TMP_BASE/copy"
mkdir -p "$COPY_FIX"

HOME="$TMP_HOME" bash "$INSTALLER" --mode=copy --project-dir "$COPY_FIX" \
  > "$TMP_BASE/copy-install.log" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: copy-mode install exited $rc" >&2
  echo "----- copy-install.log -----" >&2
  cat "$TMP_BASE/copy-install.log" >&2
  fail=1
fi
if [ ! -d "$COPY_FIX/scripts" ] || [ -L "$COPY_FIX/scripts" ]; then
  echo "FAIL: copy-mode install did not produce a regular dir at <fixture>/scripts" >&2
  fail=1
fi

# Confirm the manifest carries mode:copy rows AND per-file expansion.
copy_manifest="$COPY_FIX/.orchestrator/installed-files.txt"
if [ -f "$copy_manifest" ]; then
  if ! grep -q 'mode:copy' "$copy_manifest"; then
    echo "FAIL: copy-mode manifest missing mode:copy rows" >&2
    fail=1
  fi
  if ! grep -q '^scripts/.*mode:copy' "$copy_manifest"; then
    echo "FAIL: copy-mode manifest missing per-file rows under scripts/" >&2
    fail=1
  fi
else
  echo "FAIL: copy-mode manifest missing at $copy_manifest" >&2
  fail=1
fi

HOME="$TMP_HOME" bash "$INSTALLER" --project-dir "$COPY_FIX" --uninstall \
  > "$TMP_BASE/copy-uninstall.log" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: copy-mode uninstall exited $rc" >&2
  echo "----- copy-uninstall.log -----" >&2
  cat "$TMP_BASE/copy-uninstall.log" >&2
  fail=1
fi
if [ -d "$COPY_FIX/scripts" ]; then
  echo "FAIL: copy-mode uninstall did not remove the staged scripts/ tree" >&2
  fail=1
fi

# CON-1 source-repo invariant for copy mode (it never touches the source repo,
# but a symmetric check guards future regressions).
snap_post_scripts="$(ls "$REPO_ROOT/scripts" 2>/dev/null | head -n 1 || true)"
snap_post_commands="$(ls "$REPO_ROOT/commands" 2>/dev/null | head -n 1 || true)"
if [ "$snap_pre_scripts" != "$snap_post_scripts" ]; then
  echo "FAIL: \$REPO_ROOT/scripts disturbed by copy-mode uninstall (pre=$snap_pre_scripts post=$snap_post_scripts)" >&2
  fail=1
fi
if [ "$snap_pre_commands" != "$snap_post_commands" ]; then
  echo "FAIL: \$REPO_ROOT/commands disturbed by uninstall (pre=$snap_pre_commands post=$snap_post_commands)" >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  if [ "$sym_skipped" -eq 1 ]; then
    echo "PASS: m035-p01-mode-aware-uninstall (copy-mode only; symlink branch skipped: ln -s unavailable)"
  else
    echo "PASS: m035-p01-mode-aware-uninstall"
  fi
  exit 0
fi
exit 1
