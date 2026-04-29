#!/usr/bin/env bash
# tests/run-downstream-fixture.sh -- M028/P05/T02 autonomous-loop replay harness.
#
# Stages the installer payload into an isolated HOME, replays a sequence of
# synthetic Bash hook events (Finding A + corpus IDs 21..25, 27 + a benign
# allow-form negative control) plus a Stop event, and emits a final
# WOULD_PROMPT=0/<N> summary line. Exits 0 only when every assertion
# passes.
#
# The harness is consumed by:
#   - scripts/verify/m028/p05-downstream-fixture-clean.sh (Truth-Check)
#   - scripts/verify/m028/p05-regression-gate.sh           (close-out gate sub-leaf)
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.
#
# Helper-function carve-out (per M028/P02/T05 codification): function bodies
# are NOT scanned by the AP-009 inline-shape classifier; the extraction +
# invocation helpers below contain $(...) substitutions and grep/awk
# pipelines that classify cleanly only because they live inside function
# bodies.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/.." && pwd -P)"
INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"
CORPUS="${REPO_ROOT}/tests/fixtures/m021-prompt-corpus.txt"
FIXTURE_DIR="${REPO_ROOT}/tests/fixtures/downstream-project"

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  echo "WOULD_PROMPT=N/A"
  exit 1
fi
if [ ! -f "$CORPUS" ]; then
  echo "FAIL: corpus not found at $CORPUS" >&2
  echo "WOULD_PROMPT=N/A"
  exit 1
fi
if [ ! -d "$FIXTURE_DIR" ]; then
  echo "FAIL: downstream fixture not found at $FIXTURE_DIR" >&2
  echo "WOULD_PROMPT=N/A"
  exit 1
fi

tmp_home="${TMPDIR:-/tmp}/m028-p05-replay-$$"
mkdir -p "$tmp_home"
trap 'rm -rf "$tmp_home"' EXIT

total=0
would_prompt=0
fail_count=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

# Stage installer.
HOME="$tmp_home" CLAUDECODE=1 bash "$INSTALLER" \
  --project-dir "$tmp_home" > "${tmp_home}/install.log" 2>&1
ic=$?
if [ "$ic" -ne 0 ]; then
  echo "FAIL: installer exited rc=$ic" >&2
  cat "${tmp_home}/install.log" >&2
  echo "WOULD_PROMPT=N/A"
  exit 1
fi
pass "installer staged hooks payload at ${tmp_home}/.claude/orchestrator-hooks/"

hook="${tmp_home}/.claude/orchestrator-hooks/pre-bash-shape-guard.sh"
if [ ! -f "$hook" ]; then
  fail "hook staged" "missing $hook"
  echo "WOULD_PROMPT=N/A"
  exit 1
fi

stop_script="${tmp_home}/.claude/orchestrator-hooks/after-verify-sync.sh"
if [ ! -f "$stop_script" ]; then
  fail "stop script staged" "missing $stop_script"
  echo "WOULD_PROMPT=N/A"
  exit 1
fi

fake_project="${tmp_home}/fake-project"
mkdir -p "$fake_project"

# invoke_hook: route a single command string through the staged hook and
# assert the expected outcome. arg1=label, arg2=command, arg3=expected
# ('reject' or 'allow').
#
# The JSON payload is authored via printf rather than heredoc to avoid the
# AP-008 heredoc-with-expansion shape. Newline-bearing commands (ID 22's
# AP-011 evidence entry) require re-encoding LFs back to JSON \n sequences
# before stdin emission -- mirrors tests/run-prompt-corpus-replay.sh:101-107.
invoke_hook() {
  local label="$1"
  local cmd="$2"
  local expected="$3"
  total=$((total + 1))
  local event="${tmp_home}/event-${total}.json"

  # Escape backslashes and double-quotes for JSON, then encode real newlines
  # as the two-byte JSON \n sequence.
  local safe="$cmd"
  safe="${safe//\\/\\\\}"
  safe="${safe//\"/\\\"}"
  safe="${safe//$'\n'/\\n}"

  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}\n' "$safe" > "$event"

  local out_tmp="${tmp_home}/hook-stdout-${total}.txt"
  local err_tmp="${tmp_home}/hook-stderr-${total}.txt"
  HOME="$tmp_home" CLAUDE_PROJECT_DIR="$fake_project" \
    bash "$hook" < "$event" > "$out_tmp" 2> "$err_tmp"
  local rc=$?

  if [ "$expected" = "reject" ]; then
    if [ "$rc" -eq 2 ] && grep -q 'REJECT' "$err_tmp"; then
      pass "${label} -> REJECT (rc=2 + REJECT on stderr)"
    else
      fail "${label}" "expected REJECT (rc=2 + REJECT) got rc=$rc"
      would_prompt=$((would_prompt + 1))
    fi
  else
    if [ "$rc" -eq 0 ] && ! grep -q 'REJECT' "$err_tmp"; then
      pass "${label} -> ALLOW (rc=0 no REJECT)"
    else
      fail "${label}" "expected ALLOW (rc=0 no REJECT) got rc=$rc"
      would_prompt=$((would_prompt + 1))
    fi
  fi
}

# extract_corpus_input: extract the INPUT bytes for a given corpus ID.
# The corpus grammar is the M028/P03/T04 4-line entry:
#   ID: NN
#   SCREENSHOT: ...
#   INPUT: <verbatim>
#   EXPECTED_OUTCOME: <verdict>
#   ---
# Same awk shape tests/run-prompt-corpus-replay.sh:58-71 uses (CON-7
# stable parsing). The caller is responsible for `printf %b` decoding of
# literal-backslash-n escape sequences before injection.
extract_corpus_input() {
  awk -v id="$1" '
    /^ID: / { current = substr($0, 5); next }
    current == id && /^INPUT: / {
      print substr($0, 8)
      exit
    }
  ' "$CORPUS"
}

# Finding A: bare 4-connector AP-009 compound chain (matches the
# finding-A-verifier.sh canonical assertion).
invoke_hook "Finding-A AP-009 4-connector compound" \
  "echo a && echo b && echo c && echo d" \
  "reject"

# Corpus IDs 21..25, 27 (AP-010..AP-014 evidence entries + AP-014 boundary).
for cid in 21 22 23 24 25 27; do
  raw="$(extract_corpus_input "$cid")"
  if [ -z "$raw" ]; then
    fail "corpus ID $cid extraction" "empty INPUT"
    continue
  fi
  # Decode literal backslash-n -> real LF (M028/P03/T04 + M021 corpus
  # convention preserves newlines as the two-byte escape \n).
  decoded="$(printf '%b' "$raw")"
  invoke_hook "Corpus ID-${cid}" "$decoded" "reject"
done

# Negative control: a benign single-stage allow-form command.
invoke_hook "Negative-control echo hello" "echo hello" "allow"

# Stop event: directly invoke after-verify-sync.sh and assert exit 0
# + no `command not found`.
stop_out="${tmp_home}/stop-stdout.txt"
stop_err="${tmp_home}/stop-stderr.txt"
HOME="$tmp_home" bash "$stop_script" > "$stop_out" 2> "$stop_err"
sc=$?
total=$((total + 1))
if [ "$sc" -eq 0 ] && ! grep -q 'command not found' "$stop_err"; then
  pass "Stop event after-verify-sync.sh -> exit 0 (clean stderr)"
else
  fail "Stop event" "rc=$sc"
  would_prompt=$((would_prompt + 1))
fi

# Aggregate.
echo "WOULD_PROMPT=${would_prompt}/${total}"
if [ "$fail_count" -eq 0 ] && [ "$would_prompt" -eq 0 ]; then
  echo "PASS: tests/run-downstream-fixture.sh"
  exit 0
fi
echo "FAIL: tests/run-downstream-fixture.sh ($fail_count failures)"
exit 1
