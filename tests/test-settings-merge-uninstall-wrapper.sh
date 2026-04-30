#!/usr/bin/env bash
# tests/test-settings-merge-uninstall-wrapper.sh — Group 6 / paper-cut sweep
#
# Bug: scripts/util/settings-merge.sh `uninstall` arm checked `any_managed`
# at the leaf level only, ignoring wrapper-level `_orchestrator_managed: true`
# flags. The repair subcommand correctly handles wrapper-OR-leaf via its
# wrapper_is_managed() helper; uninstall did not. A pre-T02-installed user
# running `--uninstall` against a wrapper-flagged settings.json today
# silently leaves wrapper-flagged entries behind (uninstall-incomplete).
#
# Fix: extend uninstall's any_managed check to also accept wrapper-level
# flags, mirroring the existing wrapper_is_managed() helper.
#
# This test stages two fixtures:
#   1. wrapper-level flag only (no leaf flags) → entire wrapper removed.
#   2. mixed (wrapper-level + leaf-level flags + user-authored leaf) →
#      managed surfaces removed; user-authored leaf preserved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETTINGS_MERGE="$PROJECT_ROOT/scripts/util/settings-merge.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

TMPDIR_FX="$(mktemp -d -t papercut-uninstall-wrapper.XXXXXX)"
trap 'rm -rf "$TMPDIR_FX"' EXIT

# --- Test 1: wrapper-level flag only → entire wrapper removed ---
TARGET1="$TMPDIR_FX/settings-wrapper-only.json"
cat >"$TARGET1" <<'JSON'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "Stop": [
      {
        "_orchestrator_managed": true,
        "hooks": [
          { "type": "command", "command": "orchestrator-post-verify" }
        ]
      }
    ]
  }
}
JSON

bash "$SETTINGS_MERGE" uninstall --target "$TARGET1" >/dev/null 2>&1
result1="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps(d, sort_keys=True))' "$TARGET1")"
if printf '%s\n' "$result1" | grep -qE '"hooks"' ; then
  fail "wrapper-level flag: hooks key should be removed (result: $result1)"
else
  pass "wrapper-level flag: entire wrapper + hooks key removed"
fi

# --- Test 2: mixed wrapper-flag + leaf-flag + user-authored → preserve user ---
TARGET2="$TMPDIR_FX/settings-mixed.json"
cat >"$TARGET2" <<'JSON'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "Stop": [
      {
        "_orchestrator_managed": true,
        "hooks": [
          { "type": "command", "command": "orchestrator-post-verify-old" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash /Users/u/.claude/orchestrator-hooks/before-commit.sh", "_orchestrator_managed": true },
          { "type": "command", "command": "user-authored-script.sh" }
        ]
      }
    ]
  }
}
JSON

bash "$SETTINGS_MERGE" uninstall --target "$TARGET2" >/dev/null 2>&1
# Stop key should be gone (wrapper-level flag → entire wrapper removed).
# PreToolUse should still exist with the user-authored leaf only.
present_check="$(python3 - "$TARGET2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
hooks = d.get("hooks", {})
stop = hooks.get("Stop")
pre = hooks.get("PreToolUse", [])
# Stop must be gone.
if stop is not None:
    print("FAIL_STOP_PRESENT")
    sys.exit(0)
# PreToolUse should have one wrapper with one leaf, the user-authored one.
if not pre or len(pre) != 1:
    print("FAIL_PRE_WRAPPER_COUNT")
    sys.exit(0)
leaves = pre[0].get("hooks", [])
if len(leaves) != 1:
    print("FAIL_PRE_LEAF_COUNT=%d" % len(leaves))
    sys.exit(0)
if leaves[0].get("command") != "user-authored-script.sh":
    print("FAIL_PRE_LEAF_CMD=%r" % leaves[0].get("command"))
    sys.exit(0)
if leaves[0].get("_orchestrator_managed") is True:
    print("FAIL_USER_LEAF_TAGGED")
    sys.exit(0)
print("OK")
PY
)"
if [[ "$present_check" = "OK" ]]; then
  pass "mixed fixture: managed wrapper + managed leaf removed; user-authored leaf preserved"
else
  fail "mixed fixture preservation check failed: $present_check"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
