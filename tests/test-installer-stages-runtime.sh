#!/usr/bin/env bash
# tests/test-installer-stages-runtime.sh
#
# Verifies the installer-staging fix: packaging/install/install-*.sh must
# copy scripts/, templates/, references/ into the target project so that
# commands/*.md (which invoke helpers via project-relative paths) actually
# work after orchestrator:init.
#
# Exercises the cursor installer because it has no HOME-side hook target
# and no runtime binary to probe (adapter checks for .cursor/ which we
# create in the throwaway project). claude-code + codex share the same
# Stage 4.5 + manifest code, so cursor coverage exercises the common
# staging path without requiring a Claude Code or Codex binary on the
# test host.
#
# Bash 3.2 compatible. No jq/python.

set -u

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$REPO_ROOT/packaging/install/install-cursor.sh"

if [ ! -f "$INSTALLER" ]; then
  fail "installer missing at $INSTALLER"
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PROJECT="$TMP/proj"
mkdir -p "$PROJECT/.cursor"  # cursor adapter probes for .cursor/
mkdir -p "$PROJECT/.orchestrator/milestones"  # find-active-milestone.sh needs this dir to return NONE vs error

# ------------------------------------------------------------------
# 1. --dry-run writes nothing, emits would_write= for representative files
# ------------------------------------------------------------------
before_count="$(find "$PROJECT" -type f | wc -l | tr -d ' ')"
dr_out="$(bash "$INSTALLER" --project-dir "$PROJECT" --dry-run 2>&1)"
dr_rc=$?
after_count="$(find "$PROJECT" -type f | wc -l | tr -d ' ')"

if [ $dr_rc -eq 0 ]; then
  pass "dry-run exits 0"
else
  fail "dry-run exit=$dr_rc; output: $dr_out"
fi

if [ "$before_count" = "$after_count" ]; then
  pass "dry-run writes nothing (file count unchanged: $before_count)"
else
  fail "dry-run wrote files (before=$before_count after=$after_count)"
fi

for f in \
  "scripts/state/find-active-milestone.sh" \
  "templates/continue-file.md" \
  "references/state-machine.md"
do
  if echo "$dr_out" | grep -q "would_write=$PROJECT/$f"; then
    pass "dry-run emits would_write= for $f"
  else
    fail "dry-run missing would_write= for $f"
  fi
done

# ------------------------------------------------------------------
# 2. Real install stages runtime + writes manifest + helper runs
# ------------------------------------------------------------------
real_out="$(bash "$INSTALLER" --project-dir "$PROJECT" 2>&1)"
real_rc=$?

if [ $real_rc -eq 0 ]; then
  pass "real install exits 0"
else
  fail "real install exit=$real_rc; output: $real_out"
fi

for f in \
  "$PROJECT/scripts/state/find-active-milestone.sh" \
  "$PROJECT/templates/continue-file.md" \
  "$PROJECT/references/state-machine.md"
do
  if [ -f "$f" ]; then
    pass "staged $f"
  else
    fail "missing $f after install"
  fi
done

manifest="$PROJECT/.orchestrator/installed-files.txt"
if [ -f "$manifest" ]; then
  pass "manifest written at $manifest"
  for rel in \
    "scripts/state/find-active-milestone.sh" \
    "templates/continue-file.md" \
    "references/state-machine.md"
  do
    if grep -q "^$rel$" "$manifest"; then
      pass "manifest lists $rel"
    else
      fail "manifest missing $rel"
    fi
  done
else
  fail "manifest not created at $manifest"
fi

# Helper script actually runnable from the project dir:
# find-active-milestone.sh should exit 1 with output "NONE" on empty state.
helper_out="$(cd "$PROJECT" && bash scripts/state/find-active-milestone.sh .orchestrator 2>&1)"
helper_rc=$?
if [ $helper_rc -eq 1 ] && echo "$helper_out" | grep -q "NONE"; then
  pass "find-active-milestone.sh runs from staged install (exit=1, NONE)"
else
  fail "find-active-milestone.sh: exit=$helper_rc output=$helper_out"
fi

# SUMMARY line exposes runtime_staged count.
if echo "$real_out" | grep -q "runtime_staged=[0-9][0-9]*"; then
  pass "SUMMARY includes runtime_staged= count"
else
  fail "SUMMARY missing runtime_staged= count; got: $(echo "$real_out" | tail -1)"
fi

# ------------------------------------------------------------------
# 3. Re-install is idempotent (no errors, manifest still present)
# ------------------------------------------------------------------
# Drop a user file; confirm it survives.
user_file="$PROJECT/CLAUDE.md"
echo "user content" > "$user_file"

reinstall_out="$(bash "$INSTALLER" --project-dir "$PROJECT" 2>&1)"
reinstall_rc=$?

if [ $reinstall_rc -eq 0 ]; then
  pass "re-install exits 0"
else
  fail "re-install exit=$reinstall_rc; output: $reinstall_out"
fi

if [ -f "$manifest" ]; then
  pass "manifest survives re-install"
else
  fail "manifest lost on re-install"
fi

if [ "$(cat "$user_file")" = "user content" ]; then
  pass "re-install leaves user CLAUDE.md untouched"
else
  fail "re-install modified user CLAUDE.md"
fi

# ------------------------------------------------------------------
# 4. --uninstall removes staged files + manifest, keeps user file
# ------------------------------------------------------------------
un_out="$(bash "$INSTALLER" --project-dir "$PROJECT" --uninstall 2>&1)"
un_rc=$?

if [ $un_rc -eq 0 ]; then
  pass "uninstall exits 0"
else
  fail "uninstall exit=$un_rc; output: $un_out"
fi

for f in \
  "$PROJECT/scripts/state/find-active-milestone.sh" \
  "$PROJECT/templates/continue-file.md" \
  "$PROJECT/references/state-machine.md"
do
  if [ ! -f "$f" ]; then
    pass "uninstalled $f"
  else
    fail "$f still exists after uninstall"
  fi
done

if [ ! -f "$manifest" ]; then
  pass "manifest removed on uninstall"
else
  fail "manifest still present after uninstall"
fi

if [ -f "$user_file" ] && [ "$(cat "$user_file")" = "user content" ]; then
  pass "uninstall preserves user CLAUDE.md"
else
  fail "uninstall damaged or removed user CLAUDE.md"
fi

# ------------------------------------------------------------------
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
exit 0
