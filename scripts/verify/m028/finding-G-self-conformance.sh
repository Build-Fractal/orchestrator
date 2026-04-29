#!/usr/bin/env bash
# scripts/verify/m028/finding-G-self-conformance.sh -- M028 FR-21 / SC-9 hook self-conformance.
#
# Asserts that scripts/hooks/pre-bash-shape-guard.sh itself contains no line
# the M028-extended classifier would reject -- scoped to the lines that P02
# (T01) and P03 (T03) introduce. Per the M028/P02/T01 self-conformance
# scope precedent, the verifier asserts only on:
#
#   Scope 1 (resolution block, T01 introduction): the BASH_SOURCE-derived
#       classifier-resolution lines between the "# Locate classifier" and
#       "# Read stdin" markers. P02/T01 verified these line-by-line; T05
#       re-verifies them under the M028-extended classifier (CON-7 should
#       leave the verdicts unchanged on these lines, but we re-run as a
#       sanity gate).
#
#   Scope 2 (reject_lookup case-arm printf bodies, T03 introduction): the
#       new case arms T03 added (cmd-sub-in-pattern, quoted-arg-newline-hash,
#       multiline-quoted-script, unquoted-brace-glob, xargs-sh-c-compound-body)
#       plus the M021-baseline arms preserved unchanged. AD-19 helper-function
#       carve-out applies: case-arm bodies inside a function are NOT scanned
#       line-by-line by the inline-shape classifier in production. The
#       verifier extracts each arm's printf statement (stripping the trailing
#       `;;` case terminator) and asserts the bare printf classifies as
#       `allow`. The line-as-written contains `;;` and would classify as a
#       compound chain by inline rule -- the carve-out is what makes that
#       acceptable in the production hook.
#
# The M021 dispatch case branches (case "$CLASS" in ... esac) are immutable
# per CON-7 and are NOT gated by this verifier. They predate M028 and any
# regression on them would be caught by the existing M021 SC-1 harness, not
# this gate.
#
# Helper-function carve-out (AD-19): function bodies are NOT scanned by
# the AP-009 inline-command-shape classifier. M028/P02 dogfood codification.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
HOOK="${REPO_ROOT}/scripts/hooks/pre-bash-shape-guard.sh"
CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"

if [ ! -f "$HOOK" ]; then
  echo "FAIL: hook not found at $HOOK" >&2
  exit 1
fi
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: classifier not found at $CLASSIFIER" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$CLASSIFIER"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Helper-function carve-out (AD-19): function bodies are NOT scanned by
# the AP-009 inline-command-shape classifier. M028/P02 codified convention.
classify_one() {
  classify_command "$1" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Scope 1: resolution block (T01 introduction)
# -----------------------------------------------------------------------------
# Boundary markers are the literal comment lines T01 introduced.

START_MARKER="# Locate classifier"
END_MARKER="# Read stdin"

inside_block=0
ln=0
scope1_lines=0
scope1_fail=0

while IFS= read -r line; do
  ln=$((ln + 1))

  case "$line" in
    *"$START_MARKER"*)
      inside_block=1
      continue
      ;;
    *"$END_MARKER"*)
      inside_block=0
      continue
      ;;
  esac

  if [ "$inside_block" -ne 1 ]; then
    continue
  fi

  trimmed="${line#"${line%%[![:space:]]*}"}"
  case "$trimmed" in
    ''|\#*) continue ;;
  esac

  scope1_lines=$((scope1_lines + 1))
  verdict="$(classify_one "$line")"
  case "$verdict" in
    reject:*)
      fail "scope-1 line $ln" "verdict=$verdict line=[$line]"
      scope1_fail=$((scope1_fail + 1))
      ;;
  esac
done < "$HOOK"

if [ "$scope1_lines" -eq 0 ]; then
  fail "scope-1 resolution block" "no lines walked -- markers absent or scope empty"
elif [ "$scope1_fail" -eq 0 ]; then
  pass "resolution-block lines (T01 scope) classify as allow under M028 ($scope1_lines lines)"
fi

# -----------------------------------------------------------------------------
# Scope 2: reject_lookup case-arm printf bodies (T03 introduction)
# -----------------------------------------------------------------------------
# The case arms inside reject_lookup() {} are AD-19 carve-out-exempt at the
# inline-shape layer (function bodies). The substantive verification target
# is each arm's printf body in isolation -- strip the leading
# "    <pattern>)" prefix and the trailing "  ;;" case terminator and
# assert the bare printf classifies as `allow`.
#
# Scope: lines between "reject_lookup() {" and the matching "}" that
# contain a "printf '" substring AND a trailing ";;" -- the case-arm
# body shape T03 uses.

inside_lookup=0
scope2_lines=0
scope2_fail=0
ln=0

while IFS= read -r line; do
  ln=$((ln + 1))

  case "$line" in
    "reject_lookup() {"*)
      inside_lookup=1
      continue
      ;;
  esac

  if [ "$inside_lookup" -ne 1 ]; then
    continue
  fi

  # End of function: bare "}" at column 0 closes reject_lookup.
  case "$line" in
    "}")
      inside_lookup=0
      continue
      ;;
  esac

  # Skip lines that are not case-arm bodies. The printf-bearing arms have
  # the shape: `    <pattern>)             printf '...AP-NNN\n'   ;;`
  case "$line" in
    *"printf '"*";;")
      : # this is a case-arm printf body; classify the printf in isolation
      ;;
    *)
      continue
      ;;
  esac

  # Extract the printf statement: strip everything up to and including the
  # first `)` (the case-pattern terminator) and strip the trailing `;;`
  # plus its leading whitespace. Use bash parameter expansion for portability.
  body="${line#*)}"           # drop "    <pattern>)"
  body="${body%;;}"           # drop trailing ";;"
  # Trim leading whitespace.
  body="${body#"${body%%[![:space:]]*}"}"
  # Trim trailing whitespace.
  body="${body%"${body##*[![:space:]]}"}"

  if [ -z "$body" ]; then
    continue
  fi

  scope2_lines=$((scope2_lines + 1))
  verdict="$(classify_one "$body")"
  case "$verdict" in
    reject:*)
      fail "scope-2 reject_lookup arm (line $ln)" "verdict=$verdict body=[$body]"
      scope2_fail=$((scope2_fail + 1))
      ;;
  esac
done < "$HOOK"

if [ "$scope2_lines" -eq 0 ]; then
  fail "scope-2 reject_lookup arms" "no case-arm printf bodies found -- function shape changed?"
elif [ "$scope2_fail" -eq 0 ]; then
  pass "reject_lookup case-arm printf bodies (T03 scope) classify as allow under M028 ($scope2_lines arms)"
fi

# -----------------------------------------------------------------------------
# Sanity check: both scope markers seen
# -----------------------------------------------------------------------------

if ! grep -q "$START_MARKER" "$HOOK"; then
  fail "resolution-block start marker absent" "marker=[$START_MARKER]"
fi
if ! grep -q "$END_MARKER" "$HOOK"; then
  fail "resolution-block end marker absent" "marker=[$END_MARKER]"
fi
if ! grep -q "^reject_lookup() {" "$HOOK"; then
  fail "reject_lookup function header absent" "header=[reject_lookup() {]"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-G-self-conformance.sh"
  exit 0
fi
echo "FAIL: finding-G-self-conformance.sh ($fail_count failures)"
exit 1
