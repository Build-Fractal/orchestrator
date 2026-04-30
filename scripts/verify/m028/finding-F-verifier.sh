#!/usr/bin/env bash
# scripts/verify/m028/finding-F-verifier.sh -- M028/P02/T05 Finding F end-to-end gate.
#
# Finding F (in the wild): the M025 baseline adapter emitted bare command
# names ("orchestrator-post-verify", "orchestrator-before-commit") for the
# Stop-event hook command. Claude Code's hook runner resolved these against
# PATH, found nothing, and emitted "command not found" on every Stop event.
# T02 changed scripts/dispatch/adapters/runtime/claude-code.sh to emit
# absolute "bash <path>" invocations referencing ${HOME}/.claude/orchestrator-hooks/.
# T05's end-to-end gate fully exercises the resolution path: install,
# extract the Stop command from settings.json, invoke it, and assert no
# "command not found" diagnostic.
#
# Pattern:
#   1. Set up isolated HOME under ${TMPDIR}/m028-finding-F-$$.
#   2. Run installer to stage hooks payload + register hooks in settings.json.
#   3. Extract the Stop-event command string (python3 + tmp-file).
#   4. Assert command starts with "bash " and ends with ".sh".
#   5. Strip the "bash " prefix and assert the resolved file exists.
#   6. Invoke the resolved command with /dev/null stdin; assert no
#      "command not found" substring on stderr. The wrapper (after-verify-sync.sh)
#      may exit non-zero in an isolated test context (depends on M025
#      lifecycle state) -- the gate is "no command not found", not "exit 0".
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. python3
# baseline matches M025/P01/T02 + M028/P02/T03+T04. No jq.

set -u

# -----------------------------------------------------------------------------
# Resolve repo root + installer
# -----------------------------------------------------------------------------

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Isolated HOME + install
# -----------------------------------------------------------------------------

tmp_home="${TMPDIR:-/tmp}/m028-finding-F-$$"
mkdir -p "$tmp_home"

HOME="$tmp_home" CLAUDECODE=1 bash "$INSTALLER" \
  --project-dir "$tmp_home" > "${tmp_home}/install.log" 2>&1
ic=$?
if [ "$ic" -ne 0 ]; then
  echo "FAIL: installer exited rc=$ic (tmp_home=$tmp_home)" >&2
  cat "${tmp_home}/install.log" >&2
  exit 1
fi

settings="${tmp_home}/.claude/settings.json"
if [ ! -f "$settings" ]; then
  echo "FAIL: settings.json not present at $settings (tmp_home=$tmp_home)" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Extract Stop-event command string via python3 (write to tmp file).
# -----------------------------------------------------------------------------

stop_cmd_file="${tmp_home}/stop-cmd.txt"
SETTINGS_PATH="$settings" STOP_OUT="$stop_cmd_file" python3 <<'PYEOF'
import json, os, sys
settings_path = os.environ["SETTINGS_PATH"]
out_path = os.environ["STOP_OUT"]
with open(settings_path, "r") as f:
    s = json.load(f)
try:
    stop_cmd = s["hooks"]["Stop"][0]["hooks"][0]["command"]
except (KeyError, IndexError, TypeError):
    sys.stderr.write("FAIL: settings.json missing hooks.Stop[0].hooks[0].command\n")
    sys.exit(1)
with open(out_path, "w") as f:
    f.write(stop_cmd)
PYEOF
extract_rc=$?
if [ "$extract_rc" -ne 0 ]; then
  echo "FAIL: failed to extract Stop command from settings.json (tmp_home=$tmp_home)" >&2
  exit 1
fi

# Read the single-line file via plain `read`.
read -r stop_cmd < "$stop_cmd_file"

# -----------------------------------------------------------------------------
# Assertion 1: starts with "bash " (literal)
# -----------------------------------------------------------------------------

case "$stop_cmd" in
  'bash '*)
    ;;
  *)
    echo "FAIL: stop_cmd does not start with 'bash ': $stop_cmd (tmp_home=$tmp_home)" >&2
    exit 1
    ;;
esac

# -----------------------------------------------------------------------------
# Assertion 2: ends with ".sh"
# -----------------------------------------------------------------------------

case "$stop_cmd" in
  *'.sh')
    ;;
  *)
    echo "FAIL: stop_cmd does not end with '.sh': $stop_cmd (tmp_home=$tmp_home)" >&2
    exit 1
    ;;
esac

# -----------------------------------------------------------------------------
# Assertion 3: resolved command file exists
# -----------------------------------------------------------------------------

cmd_path="${stop_cmd#bash }"
if [ ! -f "$cmd_path" ]; then
  echo "FAIL: resolved Stop command file not found: $cmd_path (tmp_home=$tmp_home)" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Assertion 4: invoking the resolved command produces no "command not found"
# substring on stderr. after-verify-sync.sh may exit non-zero in an isolated
# test context (depends on M025 lifecycle state) -- the gate is the absence
# of the resolution-failure diagnostic, not exit 0.
# -----------------------------------------------------------------------------

stop_stdout="${tmp_home}/stop-stdout.txt"
stop_stderr="${tmp_home}/stop-stderr.txt"

bash "$cmd_path" < /dev/null > "$stop_stdout" 2> "$stop_stderr"
sync_rc=$?

if grep -q 'command not found' "$stop_stderr"; then
  echo "FAIL: 'command not found' diagnostic on Stop event stderr (tmp_home=$tmp_home)" >&2
  echo "--- stderr ---" >&2
  cat "$stop_stderr" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# PASS
# -----------------------------------------------------------------------------

rm -rf "$tmp_home"
echo "PASS: finding-F — Stop event resolves $cmd_path, no command-not-found diagnostic"
exit 0
