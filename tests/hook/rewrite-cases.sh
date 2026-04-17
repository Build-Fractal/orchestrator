#!/usr/bin/env bash
# tests/hook/rewrite-cases.sh -- Drives scripts/hooks/pre-bash-shape-guard.sh
# with six synthetic stdin-JSON payloads (one per rewrite pattern) and asserts
# the hook's stdout contains the expected `updatedInput.command` string.
#
# Exit 0 on all-pass, 1 on any failure.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# JSON-escape a raw bash command into a single-line JSON string value:
#   backslash -> \\, double-quote -> \", newline -> \n
json_escape() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk 'BEGIN{ORS=""} NR>1{printf "\\n"} {printf "%s", $0}'
}

drive_hook() {
  # $1 = raw bash command; stdout = hook stdout followed by __EXIT__=<n> line.
  # Caller parses the trailing __EXIT__ marker to recover the exit code
  # (subshell exit codes do not propagate to parent via var assignment).
  local raw="$1"
  local escaped
  escaped="$(json_escape "$raw")"
  local payload
  payload="$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$escaped")"
  local out rc
  out="$(printf '%s' "$payload" | bash "$HOOK" 2>/dev/null)"
  rc=$?
  printf '%s\n__EXIT__=%s\n' "$out" "$rc"
}

# Extract updatedInput.command from hook stdout; unescape \\, \", \n, \t.
# Uses sed -E (ERE) with the same regex shape the hook emits.
extract_updated_command() {
  printf '%s' "$1" \
    | tr '\n' ' ' \
    | sed -E -n 's/.*"updatedInput"[[:space:]]*:[[:space:]]*\{[[:space:]]*"command"[[:space:]]*:[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' \
    | head -1 \
    | sed -e 's/\\"/"/g' -e 's/\\n/\
/g' -e 's/\\t/	/g' -e 's/\\\\/\\/g'
}

assert_rewrite() {
  local label="$1" input="$2" expected="$3"
  local combined rc out actual
  combined="$(drive_hook "$input")"
  rc="$(printf '%s' "$combined" | awk -F= '/^__EXIT__=/{print $2}' | tail -1)"
  out="$(printf '%s' "$combined" | awk '/^__EXIT__=/{exit} {print}')"
  if [ "${rc:-1}" -ne 0 ]; then
    fail "$label" "hook exited ${rc:-?} (expected 0)"
    return
  fi
  actual="$(extract_updated_command "$out")"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label" "got [$actual] expected [$expected]"
  fi
}

# --- Six rewrite cases ---

assert_rewrite "R1 trailing-rc-echo" \
  'bash scripts/verify/run-suite.sh m021 P03 ; echo "RC=$?"' \
  'bash scripts/verify/run-suite.sh m021 P03'

assert_rewrite "R2 sed-n-range" \
  "sed -n '10,20p' file.md" \
  'bash scripts/util/read-range.sh file.md 10 20'

assert_rewrite "R3 cat-heredoc-exec" \
  'cat > /tmp/probe.sh <<EOF
echo hello
EOF
bash /tmp/probe.sh' \
  'bash scripts/util/run-probe.sh /tmp/probe.sh'

assert_rewrite "R4 cd-and-bash" \
  'cd .orchestrator && bash scripts/foo.sh arg1 arg2' \
  'bash scripts/foo.sh arg1 arg2'

assert_rewrite "R5 var-inline-bash" \
  'ORCH_REPO=/tmp/repo LOG=/tmp/x.log bash scripts/foo.sh --flag' \
  'bash scripts/util/with-env.sh ORCH_REPO=/tmp/repo LOG=/tmp/x.log -- bash scripts/foo.sh --flag'

assert_rewrite "R6 redirect-cmd-sub" \
  'bash scripts/foo.sh > "$(mktemp)" 2>&1' \
  'bash scripts/util/read-range.sh'

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: rewrite-cases.sh"
  exit 0
fi
echo "FAIL: rewrite-cases.sh ($fail_count failures)"
exit 1
