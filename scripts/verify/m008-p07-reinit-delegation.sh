#!/usr/bin/env bash
# m008-p07-reinit-delegation.sh — verifies init-project.sh correctly delegates
# to reinit-handler.sh on re-invocation (exit 4 default), and that --force
# fully regenerates (exit 0). Also exercises abort mode.
#
# Hermetic: uses mktemp -d for HOME and project dir.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
STATE_ROOT="$FIXTURE_PROJ/.orchestrator"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

echo '{"name":"fixture"}' > "$FIXTURE_PROJ/package.json"

# --- 1. Initial init --------------------------------------------------------
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /tmp/p07-del-init.out 2>&1 || {
    echo "FAIL: initial init failed" >&2
    cat /tmp/p07-del-init.out >&2
    exit 1
  }

# --- 2. Second invocation without --force: expect exit 4 + REINIT: ---------
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /tmp/p07-del.out 2>&1
rc=$?
if [ $rc -ne 4 ]; then
  echo "FAIL: expected exit 4 on delegation, got $rc" >&2
  cat /tmp/p07-del.out >&2
  exit 1
fi
grep -q '^REINIT:' /tmp/p07-del.out || {
  echo "FAIL: no REINIT: line on delegation" >&2
  cat /tmp/p07-del.out >&2
  exit 1
}

# --- 3. --force path: must succeed and regenerate --------------------------
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code --force > /tmp/p07-del-force.out 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: --force init exited $rc" >&2
  cat /tmp/p07-del-force.out >&2
  exit 1
fi
grep -q '^SUMMARY:' /tmp/p07-del-force.out || {
  echo "FAIL: no SUMMARY: line from --force init" >&2
  cat /tmp/p07-del-force.out >&2
  exit 1
}

# --- 4. Abort mode: exits 0, no file churn ---------------------------------
INSTR="$FIXTURE_PROJ/CLAUDE.md"
CFG="$STATE_ROOT/config.yml"
instr_before="$(wc -c < "$INSTR")"
cfg_before="$(wc -c < "$CFG")"

HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/reinit-handler.sh" \
  --project-dir "$FIXTURE_PROJ" --state-root "$STATE_ROOT" \
  --runtime claude-code --mode abort > /tmp/p07-abort.out 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: abort mode exited $rc" >&2
  cat /tmp/p07-abort.out >&2
  exit 1
fi
grep -q '^SUMMARY: mode=abort' /tmp/p07-abort.out || {
  echo "FAIL: no SUMMARY: mode=abort line" >&2
  cat /tmp/p07-abort.out >&2
  exit 1
}
instr_after="$(wc -c < "$INSTR")"
cfg_after="$(wc -c < "$CFG")"
if [ "$instr_before" != "$instr_after" ] || [ "$cfg_before" != "$cfg_after" ]; then
  echo "FAIL: abort mode changed files (instr $instr_before->$instr_after, cfg $cfg_before->$cfg_after)" >&2
  exit 1
fi

# --- 5. Dry-run update: exits 0, emits would_write, no file churn ----------
instr_before="$(wc -c < "$INSTR")"
cfg_before="$(wc -c < "$CFG")"
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/reinit-handler.sh" \
  --project-dir "$FIXTURE_PROJ" --state-root "$STATE_ROOT" \
  --runtime claude-code --mode update --dry-run > /tmp/p07-dry.out 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: dry-run update exited $rc" >&2
  cat /tmp/p07-dry.out >&2
  exit 1
fi
grep -q '^would_write=' /tmp/p07-dry.out || {
  echo "FAIL: no would_write= line from dry-run" >&2
  cat /tmp/p07-dry.out >&2
  exit 1
}
instr_after="$(wc -c < "$INSTR")"
cfg_after="$(wc -c < "$CFG")"
if [ "$instr_before" != "$instr_after" ] || [ "$cfg_before" != "$cfg_after" ]; then
  echo "FAIL: dry-run changed files" >&2
  exit 1
fi

# --- 6. Unknown mode: exit 1 with FAIL: ------------------------------------
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/reinit-handler.sh" \
  --project-dir "$FIXTURE_PROJ" --state-root "$STATE_ROOT" \
  --runtime claude-code --mode bogus > /tmp/p07-bogus.out 2>&1
rc=$?
if [ $rc -eq 0 ]; then
  echo "FAIL: unknown mode should not exit 0" >&2
  exit 1
fi
grep -q '^FAIL:' /tmp/p07-bogus.out || {
  echo "FAIL: no FAIL: line for unknown mode" >&2
  cat /tmp/p07-bogus.out >&2
  exit 1
}

echo "PASS: reinit delegation (exit 4 default, 0 with --force, abort/dry-run inert, bogus rejected)"
exit 0
