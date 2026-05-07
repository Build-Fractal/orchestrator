#!/usr/bin/env bash
# scripts/verify/m028/p02-repair-legacy-bloat.sh -- papercut-pre-M030 follow-up
# verifier for the extended `--repair` behavior in scripts/util/settings-merge.sh.
#
# Asserts that running `bash packaging/install/install-claude-code.sh --repair`
# against a synthesized pre-repair file containing legacy-installer bloat:
#   1. Drops unmanaged leaves whose command starts with
#      `bash $HOME/.claude/orchestrator-hooks/...sh` (path-prefix legacy match).
#   2. Collapses identical (event, matcher, command) tuples among
#      _orchestrator_managed:true leaves to a single occurrence.
#   3. Is idempotent: a second --repair run produces byte-identical output.
#
# The pre-repair file is synthesized at test time (rather than committed as a
# fixture) because the LEGACY_HOOKS_PREFIX rule keys off the runtime $HOME --
# a committed fixture with a hard-coded /Users/<USER>/... path would only match
# in one specific dev environment.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.
# set -u; no set -e.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

tmp_home="${TMPDIR:-/tmp}/p02-repair-legacy-bloat-$$"
mkdir -p "${tmp_home}/.claude"
target="${tmp_home}/.claude/settings.json"

# Synthesize a pre-repair file via python3 (matches settings-merge.sh baseline).
# Shape:
#   PreToolUse:
#     - 5 unmanaged wrappers, each with a flag-less leaf pointing at
#       bash <tmp_home>/.claude/orchestrator-hooks/pre-bash-shape-guard.sh
#       and bash <tmp_home>/.claude/orchestrator-hooks/before-commit.sh
#       (the path-prefix legacy shape we want collapsed)
#     - 4 managed wrappers, each with the same _orchestrator_managed:true
#       pair (the within-managed-scope duplicate shape we want collapsed
#       to a single wrapper)
#     - 1 user-authored wrapper with a leaf carrying a `timeout: 30` field
#       (must survive: extra_keys guard preserves anything non-minimal)
#   Stop:
#     - 6 unmanaged wrappers with after-verify-sync.sh path-prefix shape
#     - 3 managed wrappers with the same _orchestrator_managed:true entry
#   PostToolUse, SessionStart: single user-authored wrappers (must survive)
TMP_HOME="$tmp_home" TARGET="$target" python3 <<'PYEOF'
import json, os
home = os.environ["TMP_HOME"]
target = os.environ["TARGET"]
hooks_dir = home + "/.claude/orchestrator-hooks"
pre_bash_guard = "bash " + hooks_dir + "/pre-bash-shape-guard.sh"
before_commit = "bash " + hooks_dir + "/before-commit.sh"
after_verify_sync = "bash " + hooks_dir + "/after-verify-sync.sh"

unmanaged_pretool = {
    "matcher": "Bash",
    "hooks": [
        {"type": "command", "command": pre_bash_guard},
        {"type": "command", "command": before_commit},
    ],
}
managed_pretool = {
    "matcher": "Bash",
    "hooks": [
        {"_orchestrator_managed": True, "type": "command",
         "command": pre_bash_guard},
        {"_orchestrator_managed": True, "type": "command",
         "command": before_commit},
    ],
}
user_pretool = {
    "matcher": "Bash",
    "hooks": [
        {"type": "command", "command": "echo hi", "timeout": 30},
    ],
}
unmanaged_stop = {
    "hooks": [
        {"type": "command", "command": after_verify_sync},
    ],
}
managed_stop = {
    "hooks": [
        {"_orchestrator_managed": True, "type": "command",
         "command": after_verify_sync},
    ],
}

settings = {
    "$schema": "https://json.schemastore.org/claude-code-settings.json",
    "model": "claude-opus-4-7",
    "theme": "dark",
    "hooks": {
        "PostToolUse": [
            {"hooks": [{"type": "command", "command": "node /tmp/x.js"}]},
        ],
        "SessionStart": [
            {"hooks": [{"type": "command", "command": "node /tmp/y.js"}]},
        ],
        "PreToolUse": (
            [unmanaged_pretool] * 5
            + [managed_pretool] * 4
            + [user_pretool]
        ),
        "Stop": (
            [unmanaged_stop] * 6
            + [managed_stop] * 3
        ),
    },
}

with open(target, "w") as f:
    json.dump(settings, f, indent=2, sort_keys=True)
    f.write("\n")
PYEOF

if [ ! -f "$target" ]; then
  echo "FAIL: synthesis step did not produce $target" >&2
  exit 1
fi

run_log="${tmp_home}/repair.log"
HOME="$tmp_home" bash "$INSTALLER" --repair >"$run_log" 2>&1
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: installer --repair exited rc=$rc" >&2
  cat "$run_log" >&2
  exit 1
fi

# Assertions on post-repair shape.
assert_log="${tmp_home}/asserts.log"
TARGET="$target" python3 <<'PYEOF' >"$assert_log" 2>&1
import json, os, sys
target = os.environ["TARGET"]
with open(target, "r") as f:
    s = json.load(f)
hooks = s.get("hooks", {})

errors = []

# 1. PostToolUse + SessionStart untouched (single user-authored wrappers).
for ev in ("PostToolUse", "SessionStart"):
    arr = hooks.get(ev, [])
    if len(arr) != 1:
        errors.append("expected %s len=1, got %d" % (ev, len(arr)))

# 2. PreToolUse: should have exactly 2 wrappers surviving:
#    - the collapsed managed wrapper (1)
#    - the user-authored wrapper with timeout=30 (preserved)
pretool = hooks.get("PreToolUse", [])
if len(pretool) != 2:
    errors.append("expected PreToolUse len=2, got %d" % len(pretool))
else:
    managed_wrappers = [w for w in pretool
                        if any(l.get("_orchestrator_managed") is True
                               for l in w.get("hooks", []))]
    if len(managed_wrappers) != 1:
        errors.append("expected exactly 1 managed PreToolUse wrapper, got %d"
                      % len(managed_wrappers))
    else:
        leaves = managed_wrappers[0].get("hooks", [])
        cmds = sorted(l.get("command", "") for l in leaves)
        if len(leaves) != 2:
            errors.append("expected 2 managed leaves in collapsed wrapper, got %d"
                          % len(leaves))
        for c in cmds:
            if "/orchestrator-hooks/" not in c:
                errors.append("managed leaf has unexpected command: %r" % c)

    user_wrappers = [w for w in pretool
                     if any(l.get("timeout") == 30 for l in w.get("hooks", []))]
    if len(user_wrappers) != 1:
        errors.append("expected user-authored wrapper with timeout=30 to survive")

# 3. Stop: should have exactly 1 wrapper (collapsed managed). All unmanaged
#    legacy entries should be gone.
stop = hooks.get("Stop", [])
if len(stop) != 1:
    errors.append("expected Stop len=1, got %d" % len(stop))
else:
    leaves = stop[0].get("hooks", [])
    if len(leaves) != 1:
        errors.append("expected 1 leaf in collapsed Stop wrapper, got %d"
                      % len(leaves))
    elif leaves[0].get("_orchestrator_managed") is not True:
        errors.append("surviving Stop leaf is not managed: %r" % leaves[0])

if errors:
    for e in errors:
        sys.stderr.write("ASSERT_FAIL: %s\n" % e)
    sys.exit(1)
print("ASSERT_OK")
PYEOF

assert_rc=$?
if [ "$assert_rc" -ne 0 ]; then
  echo "FAIL: post-repair shape assertions failed" >&2
  cat "$assert_log" >&2
  echo "DIFF: settings.json kept at $target for inspection" >&2
  exit 1
fi

# Idempotency: a second --repair should leave the file byte-identical.
shasum -a 256 "$target" > "${tmp_home}/sha1"
sha1="$(awk '{print $1}' "${tmp_home}/sha1")"

HOME="$tmp_home" bash "$INSTALLER" --repair >"${tmp_home}/repair2.log" 2>&1
rc2=$?
if [ "$rc2" -ne 0 ]; then
  echo "FAIL: second --repair run exited rc=$rc2 (idempotency violation)" >&2
  cat "${tmp_home}/repair2.log" >&2
  exit 1
fi
shasum -a 256 "$target" > "${tmp_home}/sha2"
sha2="$(awk '{print $1}' "${tmp_home}/sha2")"
if [ "$sha1" != "$sha2" ]; then
  echo "FAIL: --repair is not idempotent: sha1=$sha1 sha2=$sha2" >&2
  exit 1
fi

# Cleanup on PASS only -- on FAIL the tmp dir is left for inspection.
rm -rf "$tmp_home"

sha_short="${sha1%${sha1#????????????}}"
echo "PASS: --repair collapses legacy-bloat (path-prefix + within-managed dedup), idempotent (sha=${sha_short}...)"
exit 0
