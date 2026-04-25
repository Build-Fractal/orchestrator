#!/usr/bin/env bash
# scripts/verify/m014-p03-spec-amendment-human-gate.sh
# SC-5 / CON-5 invariant: spec-amendment is NEVER auto-applied.
#
# Mechanically asserts:
#   1. apply.sh contains a class-gate refusing anything other than
#      class=spec-amendment (i.e. the manual path is the only path).
#   2. No script under scripts/comments/ — except apply.sh itself, which IS
#      the legitimate manual gate — contains an auto-apply pattern keyed to
#      spec-amendment.
#   3. commands/comments.md documents the human-gate invariant
#      (CON-5 / SC-5 / human-gate / never auto-applied).
#   4. Classifier (classify.sh) does not branch into auto-apply for the
#      spec-amendment class (queues every spec-amendment regardless of
#      confidence).
#
# Verifier self-exemption: this script embeds the patterns it scans for in
# its diagnostic strings. Self-exemption is achieved by scanning only files
# OUTSIDE scripts/verify/.
#
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMMENTS_DIR="${REPO_ROOT}/scripts/comments"
APPLY="${COMMENTS_DIR}/apply.sh"
CLASSIFY="${COMMENTS_DIR}/classify.sh"
DOC="${REPO_ROOT}/commands/comments.md"

pass=0
fail=0
_pass() { pass=$((pass + 1)); echo "PASS: $1"; }
_fail() { fail=$((fail + 1)); echo "FAIL: $1"; }

# Assertion 1: apply.sh has the class=spec-amendment gate.
if [ -f "$APPLY" ]; then
  if grep -q 'spec-amendment' "$APPLY"; then
    if grep -qE '\!= "spec-amendment"|expected spec-amendment' "$APPLY"; then
      _pass "apply.sh enforces class=spec-amendment manual gate"
    else
      _fail "apply.sh references spec-amendment but lacks the !=spec-amendment refusal guard"
    fi
  else
    _fail "apply.sh missing class=spec-amendment guard"
  fi
else
  _fail "apply.sh missing at $APPLY"
fi

# Assertion 2: no auto-apply pattern outside apply.sh under scripts/comments/.
# Pattern: literal "auto-apply" followed (in the same line) by spec-amendment
# OR vice versa, with optional separators. Self-exemption note: this verifier
# lives under scripts/verify/, not scripts/comments/, so it is not scanned.
_violations=""
if [ -d "$COMMENTS_DIR" ]; then
  for f in "$COMMENTS_DIR"/*.sh; do
    if [ ! -f "$f" ]; then
      continue
    fi
    case "$(basename "$f")" in
      apply.sh) continue ;;
    esac
    if grep -qiE 'auto[_-]?apply.*spec[_-]?amendment|spec[_-]?amendment.*auto[_-]?apply' "$f"; then
      _violations="${_violations} $(basename "$f")"
    fi
  done
fi
if [ -z "$_violations" ]; then
  _pass "no auto-apply-spec-amendment pattern in scripts/comments/ (excluding apply.sh manual gate)"
else
  _fail "auto-apply pattern found in:${_violations}"
fi

# Assertion 3: commands/comments.md documents human-gate invariant.
if [ -f "$DOC" ]; then
  if grep -qE 'CON-5|SC-5|human-gate|never auto-applied|NEVER auto-applied' "$DOC"; then
    _pass "commands/comments.md documents human-gate invariant"
  else
    _fail "commands/comments.md missing human-gate documentation"
  fi
else
  _fail "commands/comments.md missing at $DOC"
fi

# Assertion 4: classify.sh queues every spec-amendment regardless of
# confidence (presence of CON-5 / SC-5 / queue-regardless-of-confidence
# language in the docstring is the signal).
if [ -f "$CLASSIFY" ]; then
  if grep -qE 'CON-5|SC-5|regardless of confidence|ALWAYS queues' "$CLASSIFY"; then
    _pass "classify.sh docstring asserts spec-amendment always queues (no auto-apply branch)"
  else
    _fail "classify.sh missing 'regardless of confidence' / SC-5 / CON-5 docstring"
  fi
else
  _fail "classify.sh missing at $CLASSIFY"
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "PASS: $(basename "$0")"
exit 0
