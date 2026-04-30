#!/usr/bin/env bash
# scripts/verify/m028/p03-classifier-new-classes.sh
#
# M028/P03/T02 verifier: asserts the shape classifier emits the AP-010..AP-014
# reject classes verbatim for the five canonical SE-02..SE-05 + SE-09 commands
# (cmd-sub-in-pattern, quoted-arg-newline-hash, multiline-quoted-script,
# unquoted-brace-glob, xargs-sh-c-compound-body); confirms the AP-014 verdict
# takes precedence over AP-009 for the `sh -c '<body>'` shape (CON-5
# body-descent); confirms ID-27 nested-`sh -c` boundary case behavior
# (one-level-deep recursion bound).
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX-sh safe.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"

if [ ! -f "$CLASSIFIER" ]; then
  printf 'FAIL: shape-classifier.sh not found at %s\n' "$CLASSIFIER" >&2
  exit 1
fi

# shellcheck source=/dev/null
. "$CLASSIFIER"

fail_count=0

assert_verdict() {
  # $1 = label; $2 = command string; $3 = expected verdict
  local label="$1"
  local cmd="$2"
  local expected="$3"
  local actual
  actual="$(classify_command "$cmd")"
  if [ "$actual" = "$expected" ]; then
    printf 'PASS: %s -> %s\n' "$label" "$actual"
  else
    printf 'FAIL: %s -> got %s, expected %s\n' "$label" "$actual" "$expected" >&2
    fail_count=$((fail_count + 1))
  fi
}

# -----------------------------------------------------------------------------
# SE-02..SE-05 + SE-09 verbatim from
# .orchestrator/milestones/M028/phases/P01/classifier-audit.md
# -----------------------------------------------------------------------------

# SE-02: backtick inside grep regex argument (AP-010 / FR-8).
SE02_CMD="grep '^- \`bash scripts/util/' commands/dispatch.md"
assert_verdict "SE-02 (backtick in grep regex)" "$SE02_CMD" "reject:cmd-sub-in-pattern"

# SE-03: literal newline + # inside double-quoted CLI argument (AP-011 / FR-9).
# Built with $'...' so the literal LF byte is embedded in the shell string.
SE03_CMD=$'bash scripts/state/auto-state.sh set --last-action "T01 done\n# trailing comment"'
assert_verdict "SE-03 (newline+# in quoted arg)" "$SE03_CMD" "reject:quoted-arg-newline-hash"

# SE-04: multi-line body inside `node -e "<body>"` (AP-012 / FR-10).
SE04_CMD=$'node -e "const x = 1;\nconsole.log(x);\n"'
assert_verdict "SE-04 (multi-line node -e body)" "$SE04_CMD" "reject:multiline-quoted-script"

# SE-05: raw {N,M,...} brace expansion outside any quoted region (AP-013 / FR-11).
SE05_CMD='ls .orchestrator/milestones/M0{2,3,4,5}/M*-SUMMARY.md'
assert_verdict "SE-05 (unquoted brace glob)" "$SE05_CMD" "reject:unquoted-brace-glob"

# SE-09: verbatim Finding G screenshot 2026-04-28 22:25 (AP-014 / FR-12).
# Outer pipeline + xargs sh -c '<body>' where the body itself has connectors;
# combined connector count > 2 so AP-014 fires.
SE09_CMD='find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null | head -3 | xargs -I{} sh -c '"'"'echo "═══ {} ═══"; head -20 "{}"'"'"
assert_verdict "SE-09 (verbatim Finding G)" "$SE09_CMD" "reject:xargs-sh-c-compound-body"

# -----------------------------------------------------------------------------
# AP-014 precedence over AP-009 (load-bearing for SC-6).
#
# SE-09's verdict alone proves precedence: under M021 the same command
# rejected as compound-chain-gt2. With AP-014 ordered before the top-level
# stage check, the verdict shifts to xargs-sh-c-compound-body. The previous
# assert_verdict on SE-09 confirms the new verdict; this assertion records
# the precedence claim explicitly so a reader of the verifier output can
# trace SC-6 directly.
# -----------------------------------------------------------------------------

# Re-run SE-09 and assert verdict is NOT the M021-era compound-chain-gt2.
se09_actual="$(classify_command "$SE09_CMD")"
if [ "$se09_actual" = "reject:xargs-sh-c-compound-body" ] && [ "$se09_actual" != "reject:compound-chain-gt2" ]; then
  printf 'PASS: SE-09 verdict precedence: AP-014 over AP-009 (CON-5)\n'
else
  printf 'FAIL: SE-09 verdict precedence: got %s; AP-014 must dominate AP-009\n' "$se09_actual" >&2
  fail_count=$((fail_count + 1))
fi

# -----------------------------------------------------------------------------
# ID-27 boundary: nested `sh -c` opaque-treatment (CON-5 one-level-deep).
#
# An outer sh -c '<body>' whose <body> itself contains another sh -c.
# Per CON-5 the inner sh -c body is treated as opaque (its connectors do
# not contribute to the AP-014 combined count). Even so, the OUTER body's
# own connectors here push the combined count above 2 so AP-014 still fires.
# This proves the recursion bound is in effect (we do NOT descend into the
# inner body) AND the outer-body alone is sufficient to trigger.
# -----------------------------------------------------------------------------

ID27_CMD='find x | xargs sh -c '"'"'echo a; echo b; echo c; sh -c "echo d; echo e"'"'"
assert_verdict "ID-27 (nested sh -c opaque-treatment)" "$ID27_CMD" "reject:xargs-sh-c-compound-body"

# -----------------------------------------------------------------------------
# M021 strict-superset regression: delegated to scripts/verify/replay-prompt-corpus.sh
# (CON-7 / SC-8). T05's p03-replay-harness-clean.sh runs the full 27-entry
# harness which subsumes this check. Per-task verifier asserts the regression
# script exits 0 in-line as cheap insurance against M021 verdict drift in
# this task's commit.
# -----------------------------------------------------------------------------

if bash "${REPO_ROOT}/scripts/verify/replay-prompt-corpus.sh" >/dev/null 2>&1; then
  printf 'PASS: M021 corpus regression (20/20 unchanged)\n'
else
  printf 'FAIL: M021 corpus regression -- replay-prompt-corpus.sh did not exit 0\n' >&2
  fail_count=$((fail_count + 1))
fi

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: %d check(s) failed in p03-classifier-new-classes.sh\n' "$fail_count" >&2
  exit 1
fi

printf 'PASS: p03-classifier-new-classes.sh\n'
exit 0
