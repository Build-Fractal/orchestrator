#!/usr/bin/env bash
# scripts/verify/m028/finding-G-classifier-verifier.sh -- M028 Finding G classifier gate.
#
# Finding G (in the wild): `find ... | head | xargs -I{} sh -c 'echo; head'`
# shape hides a compound chain inside the sh -c body. Under M021 the
# top-level pipe count was 3 so AP-009 (compound-chain-gt2) caught it as a
# side effect. M028 must reject this verdict more specifically as
# xargs-sh-c-compound-body -- the targeted descent verdict that reflects
# CON-5 body-descent and takes the bypass surface (the "don't ask again"
# allowlist rule on the literal `sh -c '...'` bytes) off the table.
#
# This verifier asserts AP-014 takes precedence over AP-009 for the
# sh -c '<body>' shape (per CON-5 in the M028 spec).
#
# Helper-function carve-out (AD-19): function bodies are NOT scanned by the
# AP-009 inline-command-shape classifier. M028/P02/T05 codified.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"

if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: classifier not found at $CLASSIFIER" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$CLASSIFIER"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Helper-function carve-out wrapper around classify_command so this
# verifier's source itself stays AP-009-clean (function bodies are not
# scanned line-by-line by the inline-shape classifier).
classify_one() {
  classify_command "$1" 2>/dev/null
}

# -----------------------------------------------------------------------------
# SE-09 verbatim: Finding G command
# -----------------------------------------------------------------------------
# This is the literal in-the-wild Finding G shape. Under M028 the AP-014
# detector descends into the sh -c body, sees the compound chain
# (echo "..."; head -20 "{}"), and emits the more-specific verdict.
SE09_CMD='find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null | head -3 | xargs -I{} sh -c '"'"'echo "═══ {} ═══"; head -20 "{}"'"'"

actual_se09="$(classify_one "$SE09_CMD")"
if [ "$actual_se09" = "reject:xargs-sh-c-compound-body" ]; then
  pass "SE-09 verdict: $actual_se09 (AP-014 precedence over AP-009; CON-5)"
else
  fail "SE-09 verdict" "expected [reject:xargs-sh-c-compound-body] got [$actual_se09]"
fi

# -----------------------------------------------------------------------------
# CON-5 boundary: nested sh -c (one-level-deep recursion bound)
# -----------------------------------------------------------------------------
# CON-5 specifies that the sh -c body-descent recurses exactly one level;
# inner `sh -c "..."` bodies are opaque. The outer body still classifies
# as a compound chain (echo + head separated by ;), so the verdict stays
# reject:xargs-sh-c-compound-body.
# ID-27 INPUT verbatim from tests/fixtures/m021-prompt-corpus.txt entry 27;
# outer sh -c body is a compound chain (echo a; echo b; echo c; nested sh -c).
# AP-014 sees the outer chain and emits the descent verdict. The inner
# nested sh -c "..." body is left opaque per CON-5's one-level-deep bound.
ID27_CMD='find x | xargs sh -c '"'"'echo a; echo b; echo c; sh -c "echo d; echo e"'"'"
actual_id27="$(classify_one "$ID27_CMD")"
if [ "$actual_id27" = "reject:xargs-sh-c-compound-body" ]; then
  pass "ID-27 nested sh -c opaque-treatment: $actual_id27 (CON-5 one-level-deep)"
else
  fail "ID-27 boundary" "expected [reject:xargs-sh-c-compound-body] got [$actual_id27]"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-G-classifier-verifier.sh"
  exit 0
fi
echo "FAIL: finding-G-classifier-verifier.sh ($fail_count failures)"
exit 1
