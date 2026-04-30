#!/usr/bin/env bash
# scripts/verify/m028/finding-A-verifier.sh -- M028/P02/T05 Finding A end-to-end gate.
#
# Finding A (in the wild): pre-bash-shape-guard.sh failed open in consumer
# projects whose ${CLAUDE_PROJECT_DIR} did not point at the orchestrator
# repo, because the hook resolved its classifier via project-relative paths.
# T01 fixed the resolution to be self-relative via BASH_SOURCE[0], with the
# runtime-stable install location at ~/.claude/orchestrator-hooks/. T05's
# end-to-end gate exercises the resolved hook from a non-orchestrator-repo
# CLAUDE_PROJECT_DIR and asserts the classifier loads + a known-rejected
# command emits the REJECT verdict on stderr with exit 2.
#
# Pattern:
#   1. Set up isolated HOME under ${TMPDIR}/m028-finding-A-$$.
#   2. Run the installer to stage the hooks payload.
#   3. Set CLAUDE_PROJECT_DIR to a non-orchestrator path (an empty fake
#      project dir under the same tmp tree).
#   4. Pipe a Claude Code hook event JSON for a Bash tool call whose
#      command is a bare 3-connector `&&` compound chain
#      (`echo a && echo b && echo c && echo d`). The M021 classifier
#      rejects this verbatim under AP-009 / compound-chain-gt2. The plan's
#      original choice of `bash -c 'a && b && c && d && e'` is shielded
#      from M021 by the sh-c-body wrapper (AP-014's descent is the P03
#      classifier extension, not yet live), so we use the bare-form
#      compound chain that AP-009 catches today and AP-014 catches
#      tomorrow -- stable across M028's classifier evolution.
#   5. Assert hook exit code = 2 AND stderr contains substring REJECT.
#
# Hook protocol (from scripts/hooks/pre-bash-shape-guard.sh header):
#   exit 0 -> passthrough OR rewrite (normal allow)
#   exit 2 -> hard reject; stderr carries the wrapper-pointing diagnostic
#             starting with the literal `REJECT:` prefix.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

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
# Isolated HOME
# -----------------------------------------------------------------------------

tmp_home="${TMPDIR:-/tmp}/m028-finding-A-$$"
mkdir -p "$tmp_home"

# Stage the hooks payload via the installer.
HOME="$tmp_home" CLAUDECODE=1 bash "$INSTALLER" \
  --project-dir "$tmp_home" > "${tmp_home}/install.log" 2>&1
ic=$?
if [ "$ic" -ne 0 ]; then
  echo "FAIL: installer exited rc=$ic (tmp_home=$tmp_home)" >&2
  cat "${tmp_home}/install.log" >&2
  exit 1
fi

hook="${tmp_home}/.claude/orchestrator-hooks/pre-bash-shape-guard.sh"
if [ ! -f "$hook" ]; then
  echo "FAIL: hook not staged at $hook" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Non-orchestrator CLAUDE_PROJECT_DIR -- this is the Finding A reproduction
# context. The hook is invoked from a project tree that has no on-disk
# orchestrator scripts; T01's BASH_SOURCE-based resolution must still locate
# the sibling shape-classifier.sh staged at ~/.claude/orchestrator-hooks/.
# -----------------------------------------------------------------------------

fake_project="${tmp_home}/fake-project"
mkdir -p "$fake_project"

# -----------------------------------------------------------------------------
# Hook event JSON (AP-009 4-connector compound chain -- guaranteed reject
# under both M021 and M028 classifiers).
# -----------------------------------------------------------------------------

hook_event="${tmp_home}/hook-event.json"
cat > "$hook_event" <<'JSON_EOF'
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "echo a && echo b && echo c && echo d"
  }
}
JSON_EOF

# -----------------------------------------------------------------------------
# Invoke staged hook with the JSON on stdin.
# -----------------------------------------------------------------------------

HOME="$tmp_home" CLAUDE_PROJECT_DIR="$fake_project" \
  bash "$hook" \
    < "$hook_event" \
    > "${tmp_home}/hook-stdout.txt" \
    2> "${tmp_home}/hook-stderr.txt"
hook_rc=$?

# -----------------------------------------------------------------------------
# Assertion 1: exit code = 2 (REJECT). Pre-fix Finding A behavior was exit 0
# silent passthrough because the classifier didn't load.
# -----------------------------------------------------------------------------

if [ "$hook_rc" -ne 2 ]; then
  echo "FAIL: finding-A hook exit code expected 2 (REJECT), got $hook_rc (tmp_home=$tmp_home)" >&2
  echo "--- stdout ---" >&2
  cat "${tmp_home}/hook-stdout.txt" >&2
  echo "--- stderr ---" >&2
  cat "${tmp_home}/hook-stderr.txt" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Assertion 2: stderr contains literal substring REJECT (the diagnostic prefix).
# -----------------------------------------------------------------------------

if ! grep -q 'REJECT' "${tmp_home}/hook-stderr.txt"; then
  echo "FAIL: finding-A hook stderr missing REJECT substring (tmp_home=$tmp_home)" >&2
  echo "--- stderr ---" >&2
  cat "${tmp_home}/hook-stderr.txt" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# PASS
# -----------------------------------------------------------------------------

rm -rf "$tmp_home"
echo "PASS: finding-A — self-locating hook fires in non-orchestrator-repo CLAUDE_PROJECT_DIR context, classifier loaded, REJECT verdict surfaced"
exit 0
