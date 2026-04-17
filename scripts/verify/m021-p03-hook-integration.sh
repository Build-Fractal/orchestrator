#!/usr/bin/env bash
# scripts/verify/m021-p03-hook-integration.sh -- Integration gate for P03.
#
# Assertion groups:
#   1. Classifier library (scripts/verify/lib/shape-classifier.sh)
#   2. Hook protocol (scripts/hooks/pre-bash-shape-guard.sh)
#   3. Settings registration (.claude/settings.json)
#   4. Dispatch section (scripts/dispatch/lib/section-handlers.sh)
#   5. Test harness (tests/hook/{rewrite,reject}-cases.sh)
#   6. Bash 3.2 compatibility (all five P03 new files)
#
# Exit 0 on all-pass; 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"
SETTINGS="${REPO_ROOT}/.claude/settings.json"
SECTION_HANDLERS="${REPO_ROOT}/scripts/dispatch/lib/section-handlers.sh"
REWRITE_CASES="${REPO_ROOT}/tests/hook/rewrite-cases.sh"
REJECT_CASES="${REPO_ROOT}/tests/hook/reject-cases.sh"
GATE_SELF="${BASH_SOURCE[0]}"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# --- Group 1: Classifier library ---
if [ -f "$CLASSIFIER" ]; then
  # shellcheck disable=SC1090
  . "$CLASSIFIER"

  assert_classify() {
    local label="$1" input="$2" expected="$3"
    local actual
    actual="$(classify_command "$input" 2>/dev/null)"
    if [ "$actual" = "$expected" ]; then
      pass "classify: $label"
    else
      fail "classify: $label" "got [$actual] expected [$expected]"
    fi
  }

  # Allow cases
  assert_classify "allow: run-suite" 'bash scripts/verify/run-suite.sh m021 P03' 'allow'
  assert_classify "allow: ls" 'ls scripts/' 'allow'
  assert_classify "allow: cat tmp" 'cat /tmp/foo.txt' 'allow'
  assert_classify "allow: 2-stage &&" 'bash a.sh && bash b.sh' 'allow'

  # Rewrite cases
  assert_classify "rewrite: trailing-rc-echo" 'bash a.sh ; echo "RC=$?"' \
    'rewrite:bash a.sh'
  assert_classify "rewrite: sed-n-range" "sed -n '10,20p' file.md" \
    'rewrite:bash scripts/util/read-range.sh file.md 10 20'
  _input_r3="$(printf 'cat > /tmp/p.sh <<EOF\necho hi\nEOF\nbash /tmp/p.sh')"
  assert_classify "rewrite: cat-heredoc-exec" "$_input_r3" \
    'rewrite:bash scripts/util/run-probe.sh /tmp/p.sh'
  assert_classify "rewrite: cd-and-bash" 'cd .orchestrator && bash scripts/foo.sh a b' \
    'rewrite:bash scripts/foo.sh a b'
  assert_classify "rewrite: var-inline-bash" 'K=v bash scripts/foo.sh --flag' \
    'rewrite:bash scripts/util/with-env.sh K=v -- bash scripts/foo.sh --flag'
  assert_classify "rewrite: redirect-cmd-sub" 'bash x.sh > "$(mktemp)"' \
    'rewrite:bash scripts/util/read-range.sh'

  # Reject cases
  assert_classify "reject: nested-cmd-sub" 'echo $(date $(hostname))' \
    'reject:nested-cmd-sub'
  assert_classify "reject: compound-chain-gt2" 'bash a.sh | bash b.sh | bash c.sh' \
    'reject:compound-chain-gt2'
  _input_j3="$(printf 'cat <<EOF\necho $HOME\nEOF')"
  assert_classify "reject: heredoc-with-expansion" "$_input_j3" \
    'reject:heredoc-with-expansion'
  assert_classify "reject: quoted-brace" 'awk "BEGIN{print 42}" /dev/null' \
    'reject:quoted-brace'
else
  fail "classifier library present" "not found at $CLASSIFIER"
fi

# --- Group 2: Hook protocol smoke test ---
if [ -x "$HOOK" ] || [ -f "$HOOK" ]; then
  _out="$(printf '{"tool_name":"Bash","tool_input":{"command":"bash scripts/verify/run-suite.sh m021 P03"}}' \
    | bash "$HOOK" 2>/dev/null)"
  _rc=$?
  if [ "$_rc" -eq 0 ] && [ -z "$_out" ]; then
    pass "hook: allow passthrough yields empty stdout + exit 0"
  else
    fail "hook: allow passthrough" "rc=$_rc stdout=[$_out]"
  fi

  _out="$(printf '{"tool_name":"Bash","tool_input":{"command":"sed -n %s10,20p%s file.md"}}' "'" "'" \
    | bash "$HOOK" 2>/dev/null)"
  _rc=$?
  if [ "$_rc" -eq 0 ] && printf '%s' "$_out" | grep -qF 'read-range.sh file.md 10 20'; then
    pass "hook: rewrite emits updatedInput JSON"
  else
    fail "hook: rewrite" "rc=$_rc stdout=[$_out]"
  fi

  _err="$(printf '{"tool_name":"Bash","tool_input":{"command":"echo $(date $(hostname))"}}' \
    | bash "$HOOK" 2>&1 1>/dev/null)"
  _rc=$?
  if [ "$_rc" -eq 2 ] && printf '%s' "$_err" | grep -qF 'REJECT: nested-cmd-sub'; then
    pass "hook: reject emits stderr diagnostic + exit 2"
  else
    fail "hook: reject" "rc=$_rc stderr=[$_err]"
  fi
else
  fail "hook present" "not found at $HOOK"
fi

# --- Group 3: Settings registration ---
if [ -f "$SETTINGS" ]; then
  _valid=0
  if command -v jq >/dev/null 2>&1; then
    jq . "$SETTINGS" >/dev/null 2>&1 && _valid=1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$SETTINGS" >/dev/null 2>&1 && _valid=1
  else
    _valid=1
  fi
  if [ "$_valid" -eq 1 ]; then
    pass "settings: JSON parses"
  else
    fail "settings: JSON parses" "parser error"
  fi

  for entry in \
    'Read(/var/folders/**)' \
    'Bash(bash /tmp/*.sh)' \
    'Bash(bash /var/folders/**/*.sh)' \
    'Bash(ls tmp/**)' \
    'Bash(cat tmp/**)' \
    'Bash(sed -n *)' \
    'Bash(head *)' \
    'Bash(tail *)' \
    'Bash(stat *)'
  do
    if grep -qF "\"$entry\"" "$SETTINGS"; then
      pass "settings: allow contains $entry"
    else
      fail "settings: allow contains $entry" "missing"
    fi
  done

  if grep -qF '"PreToolUse"' "$SETTINGS" && grep -qF 'scripts/hooks/pre-bash-shape-guard.sh' "$SETTINGS"; then
    pass "settings: PreToolUse hook registered"
  else
    fail "settings: PreToolUse hook registered" "missing"
  fi
else
  fail "settings present" "not found at $SETTINGS"
fi

# --- Group 4: Dispatch section ---
if [ -f "$SECTION_HANDLERS" ]; then
  _out="$( . "$SECTION_HANDLERS" && SH_VERIFICATION_CRITERIA=test SH_DURATION_BUDGET=1h SH_DISPATCH_BUDGET=3 SH_BUDGET_ENFORCEMENT=warn handle_template _ _ _ _ constraints )"
  for needle in \
    '### Allowed invocation shapes' \
    'scripts/util/with-env.sh' \
    'scripts/util/read-range.sh' \
    'scripts/util/run-probe.sh' \
    'scripts/hooks/pre-bash-shape-guard.sh' \
    'AP-005..AP-009'
  do
    if printf '%s' "$_out" | grep -qF "$needle"; then
      pass "dispatch: constraints contains $needle"
    else
      fail "dispatch: constraints contains $needle" "missing"
    fi
  done
else
  fail "section-handlers present" "not found at $SECTION_HANDLERS"
fi

# --- Group 5: Test harness ---
for harness in "$REWRITE_CASES" "$REJECT_CASES"; do
  if [ -f "$harness" ]; then
    _out="$(bash "$harness" 2>&1)"
    _rc=$?
    _name="$(basename "$harness")"
    if [ "$_rc" -eq 0 ] && printf '%s' "$_out" | grep -qF "PASS: $_name"; then
      pass "harness: $_name"
    else
      fail "harness: $_name" "rc=$_rc"
    fi
  else
    fail "harness present" "not found at $harness"
  fi
done

# --- Group 6: Bash 3.2 compatibility ---
for f in "$CLASSIFIER" "$HOOK" "$REWRITE_CASES" "$REJECT_CASES" "$GATE_SELF"; do
  if [ ! -f "$f" ]; then
    continue
  fi
  if bash -n "$f" 2>/dev/null; then
    pass "bash32: $(basename "$f") parses clean"
  else
    fail "bash32: $(basename "$f") parses clean" "bash -n failed"
  fi
  _forbidden_hit=0
  # Build the forbidden-construct list at runtime via concatenation so this
  # gate's own source does not contain the literal patterns it is grepping for
  # (otherwise Group 6 would false-positive when scanning GATE_SELF).
  _fb1="declare"" -A"
  _fb2="m""apfile"
  _fb3="read""array"
  _fb4='${'"var,,""}"
  _fb5='${'"var^^""}"
  _fb6='${'"!prefix""*}"
  _fb7="<""("
  # Strip pure-comment lines (leading-# lines, optionally indented) before
  # scanning so documentation mentions of forbidden constructs don't trip
  # the check. Inline trailing comments are left alone to avoid mangling
  # strings that legitimately contain #.
  _stripped="$(grep -v '^[[:space:]]*#' "$f")"
  for forbidden in "$_fb1" "$_fb2" "$_fb3" "$_fb4" "$_fb5" "$_fb6" "$_fb7"; do
    if printf '%s' "$_stripped" | grep -qF "$forbidden"; then
      fail "bash32: $(basename "$f") has forbidden [$forbidden]" "found"
      _forbidden_hit=1
    fi
  done
  if [ "$_forbidden_hit" -eq 0 ]; then
    pass "bash32: $(basename "$f") no forbidden constructs"
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p03-hook-integration.sh"
  exit 0
fi
echo "FAIL: m021-p03-hook-integration.sh ($fail_count failures)"
exit 1
