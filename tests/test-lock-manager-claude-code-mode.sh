#!/usr/bin/env bash
# tests/test-lock-manager-claude-code-mode.sh — Bug FU-4 regression test
#
# Bug FU-4 (bbt-companion dogfood, M001/P01, 2026-04-24): Claude Code's Bash
# tool spawns a fresh shell per tool call. lock-manager.sh records the
# spawning shell's PID on `create`, then validates liveness on `status` via
# kill -0. The PID is dead by the next tool call, so a legitimately-held
# lock flips to LOCK:STALE within seconds — orchestrator-auto then refuses
# to enter the loop with "Stale lock detected. Run resume."
#
# Fix: under CLAUDECODE=1, treat lock-file existence as the active signal.
# Non-Claude-Code runtimes keep the existing PID-based STALE detection.
#
# Test asserts both halves of the invariant:
#   1. CLAUDECODE=1 + dead PID → LOCK:ACTIVE  (the bug fix)
#   2. CLAUDECODE unset + dead PID → LOCK:STALE (legacy path, unchanged)
#   3. No lock file → LOCK:NONE in both modes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_MGR="$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

TMPDIR_LOCK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LOCK"' EXIT

LOCK_FILE="$TMPDIR_LOCK/orchestrator.lock"

# Hand-craft a lock file with a guaranteed-dead PID. PID 999999 is far above
# typical max_pid on macOS/Linux; even if the OS rolled over, kill -0 would
# return ESRCH for a never-allocated number on a fresh boot.
cat > "$LOCK_FILE" <<'JSON'
{
  "pid": 999999,
  "startedAt": "2026-04-24T10:00:00Z",
  "unitType": "auto",
  "unitId": "M001/P01",
  "unitStartedAt": "2026-04-24T10:00:00Z",
  "completedUnits": [],
  "featureBranch": "main",
  "phase_start_tree": ""
}
JSON

# --- Test 1: CLAUDECODE=1 + dead PID → LOCK:ACTIVE ---
output=$(CLAUDECODE=1 bash "$LOCK_MGR" status "$LOCK_FILE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -eq 0 ]] && echo "$output" | grep -q '^LOCK:ACTIVE'; then
  pass "CLAUDECODE=1 + dead PID → LOCK:ACTIVE"
else
  fail "CLAUDECODE=1 + dead PID → LOCK:ACTIVE (rc=$rc, output: $output)"
fi

# --- Test 2: CLAUDECODE unset + dead PID → LOCK:STALE ---
# `env -u` ensures CLAUDECODE is removed even if the test runner inherited it.
output=$(env -u CLAUDECODE bash "$LOCK_MGR" status "$LOCK_FILE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -eq 0 ]] && echo "$output" | grep -q '^LOCK:STALE'; then
  pass "CLAUDECODE unset + dead PID → LOCK:STALE (legacy runtime unchanged)"
else
  fail "CLAUDECODE unset + dead PID → LOCK:STALE (rc=$rc, output: $output)"
fi

# --- Test 3: No lock file → LOCK:NONE in both modes ---
NONFILE="$TMPDIR_LOCK/does-not-exist.lock"
for mode in "set" "unset"; do
  if [[ "$mode" = "set" ]]; then
    output=$(CLAUDECODE=1 bash "$LOCK_MGR" status "$NONFILE" 2>&1) && rc=$? || rc=$?
  else
    output=$(env -u CLAUDECODE bash "$LOCK_MGR" status "$NONFILE" 2>&1) && rc=$? || rc=$?
  fi
  if [[ "$rc" -eq 0 ]] && echo "$output" | grep -q '^LOCK:NONE'; then
    pass "missing lock file → LOCK:NONE (CLAUDECODE $mode)"
  else
    fail "missing lock file → LOCK:NONE (CLAUDECODE $mode, rc=$rc, output: $output)"
  fi
done

# --- Test 4: end-to-end create→status→break under CLAUDECODE=1 ---
# Simulates the bbt-companion repro: create lock in one tool call, then check
# status in a separate shell (the per-tool-call shell from the create has
# already exited, so its PID is dead — but lock file still exists).
LOCK2="$TMPDIR_LOCK/e2e.lock"
(CLAUDECODE=1 bash "$LOCK_MGR" create "$LOCK2" auto "M001/P01" >/dev/null 2>&1)
# The subshell above has exited. Its PID is now dead; kill -0 would fail.
output=$(CLAUDECODE=1 bash "$LOCK_MGR" status "$LOCK2" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -eq 0 ]] && echo "$output" | grep -q '^LOCK:ACTIVE'; then
  pass "CC e2e: create-then-status across shells reports ACTIVE (the FU-4 repro)"
else
  fail "CC e2e: create-then-status across shells reports ACTIVE (rc=$rc, output: $output)"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
