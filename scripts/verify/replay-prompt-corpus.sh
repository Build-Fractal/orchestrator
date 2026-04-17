#!/usr/bin/env bash
# scripts/verify/replay-prompt-corpus.sh -- M021 SC-1 regression gate.
#
# Parses tests/fixtures/m021-prompt-corpus.txt (20 entries), invokes the
# shape-classifier library + the pre-bash-shape-guard hook on each INPUT,
# asserts 20/20 decisions match EXPECTED_OUTCOME, and prints the canonical
# final line: WOULD_PROMPT=N/20 where N=0 under the hardened configuration.
#
# Exit: 0 on all-pass (N=0 and 20/20 EXPECTED_OUTCOME matches), 1 otherwise.
#
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORPUS="${REPO_ROOT}/tests/fixtures/m021-prompt-corpus.txt"
CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"

fail_count=0
would_prompt=0
entry_count=0
EXPECTED_TOTAL=20

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# --- Preconditions ---
if [ ! -f "$CORPUS" ]; then
  echo "FAIL: corpus fixture not found at $CORPUS" >&2
  echo "WOULD_PROMPT=N/A"
  exit 1
fi
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: classifier library not found at $CLASSIFIER" >&2
  echo "WOULD_PROMPT=N/A"
  exit 1
fi
if [ ! -f "$HOOK" ]; then
  echo "FAIL: hook not found at $HOOK" >&2
  echo "WOULD_PROMPT=N/A"
  exit 1
fi

# shellcheck disable=SC1090
. "$CLASSIFIER"

# --- Parse corpus into a tempfile of tab-separated records ---
# Each output line: id<TAB>input<TAB>expected
# The SCREENSHOT line is ignored for gate purposes.

_tmp="$(mktemp)"
awk '
  /^#/ { next }
  /^---$/ {
    if (id != "" && input != "" && expected != "") {
      gsub(/\t/, " ", input)
      gsub(/\t/, " ", expected)
      printf "%s\t%s\t%s\n", id, input, expected
    }
    id=""; input=""; expected=""; next
  }
  /^ID: / { id = substr($0, 5); next }
  /^INPUT: / { input = substr($0, 8); next }
  /^EXPECTED_OUTCOME: / { expected = substr($0, 19); next }
' "$CORPUS" > "$_tmp"

# Flush any trailing entry that did not end with ---
# (awk above only prints on separators, but corpus ends with --- so safe.)

# --- Per-entry assertions ---
while IFS=$'\t' read -r eid einput eexpected; do
  entry_count=$((entry_count + 1))

  # Decode literal \n sequences into real newlines for classification.
  decoded="$(printf '%b' "$einput")"

  # --- Layer 1: Classifier decision ---
  actual="$(classify_command "$decoded" 2>/dev/null)"

  case "$actual" in
    allow|rewrite:*|reject:*)
      : # legal grammar
      ;;
    *)
      would_prompt=$((would_prompt + 1))
      fail "entry $eid classifier grammar" "unexpected output [$actual]"
      continue
      ;;
  esac

  if [ "$actual" = "$eexpected" ]; then
    pass "entry $eid classifier: $actual"
  else
    fail "entry $eid classifier" "expected [$eexpected] got [$actual]"
  fi

  # --- Layer 2: Hook end-to-end ---
  # Build synthetic stdin JSON. Escape backslashes and quotes in decoded.
  _esc="${decoded//\\/\\\\}"
  _esc="${_esc//\"/\\\"}"
  # Encode real newlines as JSON \n.
  _esc="${_esc//$'\n'/\\n}"

  _stdin_json='{"tool_name":"Bash","tool_input":{"command":"'"$_esc"'"}}'

  _tmp_out="$(mktemp)"
  _tmp_err="$(mktemp)"
  printf '%s' "$_stdin_json" | bash "$HOOK" > "$_tmp_out" 2> "$_tmp_err"
  _rc=$?

  case "$actual" in
    allow)
      if [ "$_rc" -eq 0 ] && [ ! -s "$_tmp_out" ]; then
        pass "entry $eid hook: allow passthrough"
      else
        _out_contents="$(cat "$_tmp_out")"
        fail "entry $eid hook: allow passthrough" "rc=$_rc stdout=[$_out_contents]"
      fi
      ;;
    rewrite:*)
      _expected_rewrite="${actual#rewrite:}"
      if [ "$_rc" -eq 0 ] && grep -qF "$_expected_rewrite" "$_tmp_out"; then
        pass "entry $eid hook: rewrite emits updatedInput"
      else
        _out_contents="$(cat "$_tmp_out")"
        fail "entry $eid hook: rewrite" "rc=$_rc stdout=[$_out_contents]"
      fi
      ;;
    reject:*)
      _expected_class="${actual#reject:}"
      if [ "$_rc" -eq 2 ] && grep -qF "REJECT: ${_expected_class}" "$_tmp_err"; then
        pass "entry $eid hook: reject emits diagnostic"
      else
        _err_contents="$(cat "$_tmp_err")"
        fail "entry $eid hook: reject" "rc=$_rc stderr=[$_err_contents]"
      fi
      ;;
  esac

  rm -f "$_tmp_out" "$_tmp_err"
done < "$_tmp"

rm -f "$_tmp"

# --- Entry count assertion ---
if [ "$entry_count" -eq "$EXPECTED_TOTAL" ]; then
  pass "corpus entry count: $entry_count"
else
  fail "corpus entry count" "expected $EXPECTED_TOTAL got $entry_count"
fi

# --- Final WOULD_PROMPT line (the SC-1 headline metric) ---
echo "WOULD_PROMPT=${would_prompt}/${EXPECTED_TOTAL}"

if [ "$would_prompt" -eq 0 ] && [ "$fail_count" -eq 0 ]; then
  echo "PASS: replay-prompt-corpus.sh"
  exit 0
fi
echo "FAIL: replay-prompt-corpus.sh ($fail_count failures)"
exit 1
