#!/usr/bin/env bash
# scripts/verify/m025-p01-hook-schema.sh -- M025/P01/T01 gate:
# validates the Claude Code runtime adapter's --hook-config mode emits
# a valid Claude Code settings.json hooks fragment.
#
# Assertions:
#   1. Adapter emits valid JSON.
#   2. Root keys are exactly {"hooks"}.
#   3. hooks keys are exactly {"Stop","PreToolUse"}.
#   4. hooks.Stop[0].hooks[0].command starts with "bash " and ends with
#      "after-verify-sync.sh" (M028/P02/T02 -- Finding F adapter half:
#      absolute-path emission replaces the M025 baseline bare-name
#      "orchestrator-post-verify"; M025 invariant of "exactly one Stop
#      leaf, _orchestrator_managed-tagged" is preserved).
#   5. hooks.PreToolUse[0].matcher == "Bash".
#   6. PreToolUse Bash matcher carries leaf objects whose commands all
#      start with "bash " and end with ".sh"; the set of basenames includes
#      "before-commit.sh" (M025 baseline, renamed from
#      "orchestrator-before-commit") and "pre-bash-shape-guard.sh"
#      (M028/P02/T02 addition for the runtime-stable shape-guard).
#   7. Every leaf hook object carries "_orchestrator_managed": true.
#   8. Adapter source contains the four TODO(M025+) deferral markers.
#
# Bash 3.2 compatible. Uses python3 (baseline per m013-p04-*.sh precedent).
# No jq dependency. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/runtime/claude-code.sh"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Capture emission. Use a safe HOME so the HOME guard passes in CI.
HC_OUT="$(mktemp -t m025-p01-hc.XXXXXX)"
HOME="${HOME:-/tmp}" bash "$ADAPTER" --hook-config >"$HC_OUT" 2>/dev/null
rc=$?

# --- Assertion 1: adapter exits 0
if [ "$rc" -eq 0 ]; then
  pass "adapter --hook-config exits 0"
else
  fail "adapter --hook-config exited rc=${rc}"
fi

# --- Assertion 2: emission parses as JSON
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$HC_OUT" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "emission parses as valid JSON"
else
  fail "emission is not valid JSON"
fi

# --- Assertion 3: root keys are exactly {"hooks"}
python3 -c "
import json,sys
d = json.load(open(sys.argv[1]))
assert set(d.keys()) == {'hooks'}, 'root keys=%r' % sorted(d.keys())
" "$HC_OUT" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "root keys are exactly {\"hooks\"}"
else
  fail "root keys are not exactly {\"hooks\"}"
fi

# --- Assertion 4: hooks keys are exactly {"Stop","PreToolUse"}
python3 -c "
import json,sys
d = json.load(open(sys.argv[1]))
assert set(d['hooks'].keys()) == {'Stop','PreToolUse'}, 'hooks keys=%r' % sorted(d['hooks'].keys())
" "$HC_OUT" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "hooks keys are exactly {Stop, PreToolUse}"
else
  fail "hooks keys are not exactly {Stop, PreToolUse}"
fi

# --- Assertion 5: Stop leaf command shape (M028/P02/T02 absolute-path)
python3 -c "
import json,sys,os
d = json.load(open(sys.argv[1]))
stop_leaves = d['hooks']['Stop'][0]['hooks']
assert len(stop_leaves) == 1, 'expected exactly 1 Stop leaf, got %d' % len(stop_leaves)
cmd = stop_leaves[0]['command']
assert cmd.startswith('bash '), 'Stop command does not start with bash: %r' % cmd
assert cmd.endswith('.sh'), 'Stop command does not end with .sh: %r' % cmd
assert os.path.basename(cmd.split(' ', 1)[1]) == 'after-verify-sync.sh', 'Stop basename != after-verify-sync.sh: %r' % cmd
" "$HC_OUT" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "hooks.Stop[0] leaf is absolute bash <path>/after-verify-sync.sh"
else
  fail "Stop leaf command wrong (expected absolute bash <path>/after-verify-sync.sh)"
fi

# --- Assertion 6: PreToolUse Bash matcher carries shape-guard + before-commit
python3 -c "
import json,sys,os
d = json.load(open(sys.argv[1]))
# Aggregate all leaves under any PreToolUse Bash-matcher wrapper.
basenames = []
for w in d['hooks']['PreToolUse']:
    if w.get('matcher') != 'Bash':
        continue
    for leaf in w.get('hooks', []):
        cmd = leaf['command']
        assert cmd.startswith('bash '), 'PreToolUse Bash command does not start with bash: %r' % cmd
        assert cmd.endswith('.sh'), 'PreToolUse Bash command does not end with .sh: %r' % cmd
        basenames.append(os.path.basename(cmd.split(' ', 1)[1]))
assert d['hooks']['PreToolUse'][0]['matcher'] == 'Bash'
required = {'before-commit.sh', 'pre-bash-shape-guard.sh'}
missing = required - set(basenames)
assert not missing, 'missing required PreToolUse Bash leaves: %r (have %r)' % (sorted(missing), basenames)
" "$HC_OUT" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "hooks.PreToolUse Bash matcher carries before-commit.sh + pre-bash-shape-guard.sh as absolute bash <path>"
else
  fail "PreToolUse Bash matcher missing expected absolute-path leaves"
fi

# --- Assertion 7: every leaf hook object has _orchestrator_managed: true
python3 -c "
import json,sys
d = json.load(open(sys.argv[1]))
leaves = []
for ev_key, ev_arr in d['hooks'].items():
    for wrapper in ev_arr:
        for leaf in wrapper.get('hooks', []):
            leaves.append(leaf)
assert len(leaves) >= 2, 'expected >=2 leaves, got %d' % len(leaves)
for leaf in leaves:
    assert leaf.get('_orchestrator_managed') is True, 'leaf missing tag: %r' % leaf
" "$HC_OUT" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  pass "every leaf hook object carries _orchestrator_managed: true"
else
  fail "one or more leaf hook objects missing _orchestrator_managed: true"
fi

# --- Assertion 8: adapter source contains 4 TODO(M025+) markers
todo_count="$(grep -c 'TODO(M025+)' "$ADAPTER" 2>/dev/null || echo 0)"
if [ "$todo_count" -ge 4 ]; then
  pass "adapter source contains >=4 TODO(M025+) markers (found ${todo_count})"
else
  fail "adapter source missing TODO(M025+) markers (found ${todo_count}, need 4)"
fi

rm -f "$HC_OUT"

echo "SUMMARY: m025-p01-hook-schema.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-hook-schema.sh"
  exit 0
fi
echo "FAIL: m025-p01-hook-schema.sh" >&2
exit 1
