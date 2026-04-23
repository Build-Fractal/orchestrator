#!/usr/bin/env bash
# scripts/verify/m025-p01-merge-preservation.sh -- M025/P01/T02 gate:
# validates that install-claude-code.sh merges (not overwrites) a
# pre-existing GSD-shaped ~/.claude/settings.json. T03 will introduce the
# canonical fixture tree at tests/fixtures/m025-p01/gsd-baseline/; for now
# this gate inlines a minimal GSD-shaped seed so it stands alone.
#
# Assertions (via python3 structural comparison):
#   1. All pre-existing top-level keys survive ($schema, statusLine,
#      permissions).
#   2. hooks.SessionStart and hooks.PostToolUse from the seed are unchanged.
#   3. hooks.Stop and hooks.PreToolUse are appended with orchestrator
#      entries (tagged _orchestrator_managed: true).
#
# Uses gsd-baseline fragment inline (minimal stand-alone seed).
# Bash 3.2 compatible. AD-19 single-script-file shape. python3 baseline.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

TMPHOME="$(mktemp -d -t m025-p01-merge-prsv-home.XXXXXX)"
TMPPRJ="$(mktemp -d -t m025-p01-merge-prsv-prj.XXXXXX)"

cleanup() { rm -rf "$TMPHOME" "$TMPPRJ"; }
trap cleanup EXIT

mkdir -p "$TMPHOME/.claude"

# Inline GSD-shaped seed (T02's gsd-baseline stand-in; T03 replaces with fixture).
cat >"$TMPHOME/.claude/settings.json" <<'SEED'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "statusLine": { "type": "command", "command": "echo gsd-statusline" },
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "~/.claude/hooks/gsd-session-start.sh" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "~/.claude/hooks/gsd-post-edit.sh" } ] }
    ]
  },
  "permissions": { "allow": ["Bash(git status)"] }
}
SEED

# Run installer against the seeded fake HOME + tmp project dir.
CLAUDECODE=1 HOME="$TMPHOME" bash "$INSTALLER" --project-dir "$TMPPRJ" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "installer exits 0 against seeded HOME"
else
  fail "installer exited rc=${rc}"
fi

# Structural checks via python3.
RESULT="$TMPHOME/.claude/settings.json"

python3 - "$RESULT" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
# 1. original top-level keys preserved
for k in ("$schema", "statusLine", "permissions", "hooks"):
    assert k in d, "missing top-level key: %s" % k
assert d["statusLine"]["command"] == "echo gsd-statusline"
assert d["permissions"]["allow"] == ["Bash(git status)"]
# 2. seed hooks untouched
h = d["hooks"]
assert "SessionStart" in h and len(h["SessionStart"]) >= 1
assert h["SessionStart"][0]["hooks"][0]["command"] == "~/.claude/hooks/gsd-session-start.sh"
assert "PostToolUse" in h and h["PostToolUse"][0]["matcher"] == "Edit|Write"
assert h["PostToolUse"][0]["hooks"][0]["command"] == "~/.claude/hooks/gsd-post-edit.sh"
# 3. orchestrator hooks appended
assert "Stop" in h, "Stop not appended"
assert "PreToolUse" in h, "PreToolUse not appended"
stop_cmds = [leaf["command"] for w in h["Stop"] for leaf in w.get("hooks", [])
             if leaf.get("_orchestrator_managed") is True]
assert "orchestrator-post-verify" in stop_cmds
pre_cmds = [leaf["command"] for w in h["PreToolUse"] for leaf in w.get("hooks", [])
            if leaf.get("_orchestrator_managed") is True]
assert "orchestrator-before-commit" in pre_cmds
# 4. No wrapper metadata at root (regression guard: runtime/hook_count/target_file)
for bad in ("runtime", "hook_count", "target_file"):
    assert bad not in d, "root leaked wrapper key: %s" % bad
PYEOF
if [ $? -eq 0 ]; then
  pass "structural merge preservation + orchestrator append verified"
else
  fail "structural merge preservation check failed"
fi

echo "SUMMARY: m025-p01-merge-preservation.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-merge-preservation.sh"
  exit 0
fi
echo "FAIL: m025-p01-merge-preservation.sh" >&2
exit 1
