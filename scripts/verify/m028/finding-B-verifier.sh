#!/usr/bin/env bash
# scripts/verify/m028/finding-B-verifier.sh -- M028 Finding B end-to-end gate.
#
# Finding B (in the wild): four shape classes outside M021's matrix that
# agents reach for during normal task execution:
#   B#1 cmd-sub-in-pattern (AP-010)      -- backtick / cmd-sub in grep regex
#   B#2 quoted-arg-newline-hash (AP-011) -- newline + # in quoted CLI arg
#   B#3 multiline-quoted-script (AP-012) -- multi-line node -e body
#   B#4 unquoted-brace-glob (AP-013)     -- raw {N,M,...} outside quotes
#
# Each shape exercises the M028-extended classifier + hook end-to-end.
# Asserts hook exit 2 + literal "REJECT:" prefix + the expected pattern-class
# label on stderr. AP-IDs are surfaced via the diagnostic's
# "ANTIPATTERNS.md#AP-NNN" reference (per scripts/hooks/pre-bash-shape-guard.sh
# line 191's printf format), so the AP-ID assertion is a substring check on
# the same error line.
#
# Helper-function carve-out (AD-19): function bodies are NOT scanned by the
# AP-009 inline-command-shape classifier. M028/P02/T05 codified this as a
# convention; finding-B-verifier.sh inherits the pattern.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

if [ ! -f "$HOOK" ]; then
  echo "FAIL: hook not found at $HOOK" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Helper: invoke hook with synthetic stdin JSON; assert exit 2, the
# "REJECT: <class>" prefix on stderr, and the AP-ID substring (carried by
# the "ANTIPATTERNS.md#AP-NNN" tail of the diagnostic line).
assert_reject() {
  label="$1"
  cmd="$2"
  class="$3"
  ap_id="$4"

  _esc="${cmd//\\/\\\\}"
  _esc="${_esc//\"/\\\"}"
  _esc="${_esc//$'\n'/\\n}"
  _stdin='{"tool_name":"Bash","tool_input":{"command":"'"$_esc"'"}}'

  _err="$(mktemp)"
  printf '%s' "$_stdin" | bash "$HOOK" > /dev/null 2> "$_err"
  _rc=$?
  _err_text="$(cat "$_err")"
  rm -f "$_err"

  if [ "$_rc" -ne 2 ]; then
    fail "$label -> reject:$class" "rc=$_rc stderr=[$_err_text]"
    return
  fi
  if ! printf '%s' "$_err_text" | grep -qF "REJECT: $class"; then
    fail "$label -> reject:$class (REJECT prefix)" "stderr=[$_err_text]"
    return
  fi
  if ! printf '%s' "$_err_text" | grep -qF "$ap_id"; then
    fail "$label -> reject:$class ($ap_id substring)" "stderr=[$_err_text]"
    return
  fi
  pass "$label -> reject:$class (#$ap_id)"
}

# -----------------------------------------------------------------------------
# B#1: backtick command-substitution in grep regex (AP-010)
# -----------------------------------------------------------------------------
# Verbatim Finding B#1 in the wild: agents grep for the literal pattern
# "- `bash scripts/util/" in command docs, which embeds a backtick that
# the shell interprets as command substitution. Classifier catches the
# unbalanced backtick inside the quoted argument as cmd-sub-in-pattern.
assert_reject "B#1 cmd-sub-in-pattern" \
  "grep '^- \`bash scripts/util/' commands/dispatch.md" \
  "cmd-sub-in-pattern" "AP-010"

# -----------------------------------------------------------------------------
# B#2: newline + # in quoted argument (AP-011)
# -----------------------------------------------------------------------------
# Verbatim Finding B#2: agents pass a multi-line quoted last-action string
# whose body contains a literal newline followed by '# trailing comment'.
# Classifier rejects this as quoted-arg-newline-hash because the
# embedded newline + leading-# could be re-parsed by some shells as a
# comment that swallows trailing args. Use bash's $'...' ANSI-C quoting
# in this verifier to embed the literal newline at authoring time.
assert_reject "B#2 quoted-arg-newline-hash" \
  $'bash scripts/state/auto-state.sh set --last-action "T01 done\n# trailing comment"' \
  "quoted-arg-newline-hash" "AP-011"

# -----------------------------------------------------------------------------
# B#3: multi-line node -e body (AP-012)
# -----------------------------------------------------------------------------
# Verbatim Finding B#3: agents write a multi-line node -e "..." body when
# trying to run a snippet of JavaScript inline. Classifier rejects as
# multiline-quoted-script because line-continuations inside a quoted -e
# argument hide compound semantics from line-by-line tooling.
assert_reject "B#3 multiline-quoted-script" \
  $'node -e "const x = 1;\nconsole.log(x);\n"' \
  "multiline-quoted-script" "AP-012"

# -----------------------------------------------------------------------------
# B#4: unquoted brace glob (AP-013)
# -----------------------------------------------------------------------------
# Verbatim Finding B#4: agents reach for `ls foo/M0{2,3,4,5}/...` to
# enumerate a fixed set of milestone dirs. Brace expansion is shell-only
# (not POSIX glob) so this fails on `sh` and surprises users running the
# orchestrator under a strict POSIX shell. Classifier rejects as
# unquoted-brace-glob; the canonical replacement is peek-files.sh.
assert_reject "B#4 unquoted-brace-glob" \
  "ls .orchestrator/milestones/M0{2,3,4,5}/M*-SUMMARY.md" \
  "unquoted-brace-glob" "AP-013"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-B-verifier.sh"
  exit 0
fi
echo "FAIL: finding-B-verifier.sh ($fail_count failures)"
exit 1
