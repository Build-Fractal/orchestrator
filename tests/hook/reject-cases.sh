#!/usr/bin/env bash
# tests/hook/reject-cases.sh -- Drives scripts/hooks/pre-bash-shape-guard.sh
# with four synthetic stdin-JSON payloads (one per reject pattern) and asserts
# exit 2 with the exact REJECT diagnostic on stderr.
#
# Exit 0 on all-pass, 1 on any failure.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

# U+2014 em dash as literal UTF-8 bytes (0xE2 0x80 0x94).
EMDASH=$'\xe2\x80\x94'

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

json_escape() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk 'BEGIN{ORS=""} NR>1{printf "\\n"} {printf "%s", $0}'
}

drive_hook_stderr() {
  # $1 = raw bash command; stdout = captured stderr text from the hook.
  # The hook's exit code is written on the LAST line as `__EXIT__=<n>`.
  local raw="$1"
  local escaped
  escaped="$(json_escape "$raw")"
  local payload
  payload="$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$escaped")"
  local err rc
  err="$(printf '%s' "$payload" | bash "$HOOK" 2>&1 1>/dev/null)"
  rc=$?
  printf '%s\n__EXIT__=%s\n' "$err" "$rc"
}

assert_reject() {
  local label="$1" input="$2" expected_line="$3"
  local combined rc err
  combined="$(drive_hook_stderr "$input")"
  rc="$(printf '%s' "$combined" | awk -F= '/^__EXIT__=/{print $2}' | tail -1)"
  err="$(printf '%s' "$combined" | awk '/^__EXIT__=/{exit} {print}')"
  if [ "${rc:-0}" -ne 2 ]; then
    fail "$label" "hook exited ${rc:-0} (expected 2)"
    return
  fi
  if printf '%s' "$err" | grep -qF "$expected_line"; then
    pass "$label"
  else
    fail "$label" "stderr missing expected line; got [$err]"
  fi
}

# --- Four reject cases ---

assert_reject "J1 nested-cmd-sub" \
  'echo $(date $(hostname))' \
  "REJECT: nested-cmd-sub ${EMDASH} use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-009."

assert_reject "J2 compound-chain-gt2" \
  'bash a.sh | bash b.sh | bash c.sh | bash d.sh' \
  "REJECT: compound-chain-gt2 ${EMDASH} use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-009."

assert_reject "J3 heredoc-with-expansion" \
  'cat <<EOF
echo $HOME
EOF' \
  "REJECT: heredoc-with-expansion ${EMDASH} use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-008."

assert_reject "J4 quoted-brace" \
  'awk "BEGIN{print 42}" /dev/null' \
  "REJECT: quoted-brace ${EMDASH} use scripts/util/read-range.sh instead. See ANTIPATTERNS.md#AP-007."

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: reject-cases.sh"
  exit 0
fi
echo "FAIL: reject-cases.sh ($fail_count failures)"
exit 1
