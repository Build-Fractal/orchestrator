#!/usr/bin/env bash
# scripts/verify/m028/p02-adapter-absolute-paths.sh -- M028/P02/T02 verifier.
#
# Asserts that scripts/dispatch/adapters/runtime/claude-code.sh --hook-config
# emits, for every leaf hook object, a `command` field of the literal shape
# `bash <hooks-dir>/<name>.sh` (absolute path, never a bare command name) and
# that every leaf object carries `_orchestrator_managed: true`. This gates
# the phase Truth: the runtime adapter emits absolute-path hook commands.
#
# Background: Finding F (adapter half) -- the M025 baseline emitted bare
# command names (`orchestrator-post-verify`, `orchestrator-before-commit`)
# which Claude Code's hook runner resolved against PATH, found nothing, and
# emitted `command not found` on every Stop event. T02 changed the adapter
# to emit absolute `bash <abs-path>` invocations referencing the
# runtime-stable hooks dir ${HOME}/.claude/orchestrator-hooks/.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.
# Asserts on substring shape, not parsed JSON structure.

set -u

# Resolve repo root from the script's own location so this verifier runs
# from any cwd.
script_dir="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$script_dir/../../.." && pwd)"

ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/runtime/claude-code.sh"
if [ ! -f "$ADAPTER" ]; then
  echo "FAIL: adapter not found at $ADAPTER" >&2
  exit 1
fi

tmp="${TMPDIR:-/tmp}/p02-adapter-absolute-paths-$$.json"

# Capture adapter emission via redirect (no pipe inside command sub).
bash "$ADAPTER" --hook-config > "$tmp" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: adapter --hook-config exited rc=$rc" >&2
  rm -f "$tmp"
  exit 1
fi

# Assertion 1: at least 3 "command": fields present.
cmd_count="$(grep -c '"command":' "$tmp")"
if [ "$cmd_count" -lt 3 ]; then
  echo "FAIL: expected >= 3 command fields, got $cmd_count" >&2
  cat "$tmp" >&2
  rm -f "$tmp"
  exit 1
fi

# Assertion 2: every command starts with `bash ` and ends with `.sh`.
# Extract command lines via grep (no pipe in command sub).
cmd_lines="${tmp}.cmds"
grep '"command":' "$tmp" > "$cmd_lines"

while IFS= read -r line; do
  # Each command line carries the JSON shape:
  #   { "type": "command", "command": "bash /abs/path/foo.sh", "_orchestrator_managed": true }
  # Assert the command value opens with `"bash ` (literal double-quote, then
  # `bash`, then space) and contains `.sh"` (extension followed by JSON
  # closing quote).
  if ! echo "$line" | grep -q '"command": "bash '; then
    echo "FAIL: command field does not start with \"bash <space>: $line" >&2
    rm -f "$tmp" "$cmd_lines"
    exit 1
  fi
  if ! echo "$line" | grep -q '\.sh"'; then
    echo "FAIL: command field does not end with .sh\": $line" >&2
    rm -f "$tmp" "$cmd_lines"
    exit 1
  fi
done < "$cmd_lines"

# Assertion 3: _orchestrator_managed substring count equals "command":
# substring count -- every leaf carries the flag.
flag_count="$(grep -c '_orchestrator_managed' "$tmp")"
if [ "$flag_count" != "$cmd_count" ]; then
  echo "FAIL: _orchestrator_managed count ($flag_count) != command count ($cmd_count)" >&2
  rm -f "$tmp" "$cmd_lines"
  exit 1
fi

# Assertion 4: fragment contains the literal substring `orchestrator-hooks`
# (proves absolute paths reference the runtime-stable dir).
if ! grep -q 'orchestrator-hooks' "$tmp"; then
  echo "FAIL: fragment missing 'orchestrator-hooks' substring" >&2
  rm -f "$tmp" "$cmd_lines"
  exit 1
fi

rm -f "$tmp" "$cmd_lines"
echo "PASS: adapter emits $cmd_count absolute-path hook commands, each tagged _orchestrator_managed: true"
exit 0
