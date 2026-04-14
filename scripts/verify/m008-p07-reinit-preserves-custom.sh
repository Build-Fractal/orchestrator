#!/usr/bin/env bash
# m008-p07-reinit-preserves-custom.sh — verifies reinit-handler.sh update mode
# preserves the <!-- BEGIN CUSTOM --> block in the instruction file and any
# user-added top-level fields in config.yml.
#
# Hermetic: uses mktemp -d for both HOME and project dir; no writes outside
# the fixture trees.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
STATE_ROOT="$FIXTURE_PROJ/.orchestrator"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

# Minimal fixture: a package.json so detect-project has something to chew on.
echo '{"name":"fixture"}' > "$FIXTURE_PROJ/package.json"

# --- 1. Initial init ---------------------------------------------------------
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /tmp/p07-reinit-init.out 2>&1 || {
    echo "FAIL: initial init failed" >&2
    cat /tmp/p07-reinit-init.out >&2
    exit 1
  }

INSTR="$FIXTURE_PROJ/CLAUDE.md"
CFG="$STATE_ROOT/config.yml"
[ -f "$INSTR" ] || { echo "FAIL: initial init did not write $INSTR" >&2; exit 1; }
[ -f "$CFG"   ] || { echo "FAIL: initial init did not write $CFG" >&2; exit 1; }

# --- 2. Inject a user mark inside the BEGIN CUSTOM block --------------------
awk '
  /^<!-- BEGIN CUSTOM -->$/ { print; print "USER_MARK: this must survive reinit."; next }
  { print }
' "$INSTR" > "$INSTR.new" && mv -f "$INSTR.new" "$INSTR"

grep -q 'USER_MARK: this must survive reinit.' "$INSTR" || {
  echo "FAIL: test setup — USER_MARK not injected" >&2
  exit 1
}

# --- 3. Add a user-edited top-level config field ----------------------------
echo 'user_custom_field: "must survive"' >> "$CFG"

# --- 4. Delegated path: init without --force should exit 4 with REINIT: -----
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /tmp/p07-reinit-del.out 2>&1
rc=$?

if [ $rc -ne 4 ]; then
  echo "FAIL: init without --force should exit 4 (delegated), got $rc" >&2
  cat /tmp/p07-reinit-del.out >&2
  exit 1
fi

# REINIT: line may appear on stdout or stderr depending on handler; the init
# wrapper also emits its own on stderr. Check either stream.
grep -q '^REINIT:' /tmp/p07-reinit-del.out || {
  echo "FAIL: no REINIT: line on delegated invocation" >&2
  cat /tmp/p07-reinit-del.out >&2
  exit 1
}

# --- 5. Invoke reinit-handler directly in update mode -----------------------
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/reinit-handler.sh" \
  --project-dir "$FIXTURE_PROJ" --state-root "$STATE_ROOT" \
  --runtime claude-code --mode update > /tmp/p07-reinit-update.out 2>&1
rc=$?

if [ $rc -ne 0 ]; then
  echo "FAIL: reinit update exited $rc" >&2
  cat /tmp/p07-reinit-update.out >&2
  exit 1
fi

grep -q '^SUMMARY: mode=update' /tmp/p07-reinit-update.out || {
  echo "FAIL: no SUMMARY: mode=update line from update run" >&2
  cat /tmp/p07-reinit-update.out >&2
  exit 1
}

# --- 6. Assert custom block survived ----------------------------------------
grep -q 'USER_MARK: this must survive reinit.' "$INSTR" || {
  echo "FAIL: custom block lost after reinit update" >&2
  echo "--- $INSTR ---" >&2
  cat "$INSTR" >&2
  exit 1
}

# --- 7. Assert user-added top-level field survived --------------------------
grep -q '^user_custom_field: "must survive"' "$CFG" || {
  echo "FAIL: user_custom_field lost after reinit update" >&2
  echo "--- $CFG ---" >&2
  cat "$CFG" >&2
  exit 1
}

# --- 8. Assert freshly detected capabilities: block is present --------------
grep -q '^capabilities:' "$CFG" || {
  echo "FAIL: capabilities: block missing after update" >&2
  cat "$CFG" >&2
  exit 1
}

# --- 9. Assert project: block is present (refreshed) ------------------------
grep -q '^project:' "$CFG" || {
  echo "FAIL: project: block missing after update" >&2
  cat "$CFG" >&2
  exit 1
}

# --- 10. Assert only one capabilities: and one project: block ---------------
cap_count=$(grep -c '^capabilities:' "$CFG")
proj_count=$(grep -c '^project:' "$CFG")
if [ "$cap_count" -ne 1 ] || [ "$proj_count" -ne 1 ]; then
  echo "FAIL: duplicate blocks after update (project=$proj_count capabilities=$cap_count)" >&2
  cat "$CFG" >&2
  exit 1
fi

echo "PASS: reinit update preserves custom block and user-added config fields"
exit 0
