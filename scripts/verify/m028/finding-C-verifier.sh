#!/usr/bin/env bash
# scripts/verify/m028/finding-C-verifier.sh -- M028 Finding C / E end-to-end gate.
#
# Finding C / E (in the wild): agents construct
#   grep ... ; echo "---" ; grep ...
# investigation-compound shells when no canonical investigation example
# covers the shape. AP-009 (compound-chain-gt2) already rejects this shape
# under M021; this verifier proves that the M028-extended classifier
# preserves the AP-009 reject (CON-7 strict-superset). Catches a regression
# where AP-014 descent or any new AP-010..AP-013 detector accidentally
# subsumes the AP-009 case for compound-chain shapes.
#
# Helper-function carve-out (AD-19): function bodies are NOT scanned by the
# AP-009 inline-command-shape classifier. M028/P02/T05 codified.
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
# SE-06 verbatim: 3-stage compound chain
# -----------------------------------------------------------------------------
# `grep ... ; echo "---" ; grep ...` is 3 ;-separated stages -- one over the
# AP-009 threshold. Must reject as compound-chain-gt2 under M028 just as it
# did under M021 (CON-7 strict-superset).
assert_reject "SE-06 investigation-compound" \
  'grep -n classify_command scripts/verify/lib/shape-classifier.sh; echo "---"; grep -n reject_lookup scripts/hooks/pre-bash-shape-guard.sh' \
  "compound-chain-gt2" "AP-009"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-C-verifier.sh"
  exit 0
fi
echo "FAIL: finding-C-verifier.sh ($fail_count failures)"
exit 1
