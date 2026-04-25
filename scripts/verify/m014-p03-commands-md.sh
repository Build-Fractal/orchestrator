#!/usr/bin/env bash
# scripts/verify/m014-p03-commands-md.sh
# Verifies M014/P03/T03: commands/comments.md shape and content.
#
# Cases:
#   A) commands/comments.md exists.
#   B) Documents all six subcommands: classify, status, apply, reject,
#      triage, reclassify.
#   C) References D023 (regex/heuristic v1 baseline pin).
#   D) References the FR-19 dry-run JSONL manifest shape.
#   E) Documents the spec-amendment human-gate invariant
#      (CON-5 / SC-5 / never auto-applied).
#   F) Cites planning-inputs/inbox-dogfood.md as SSOT for retune trigger.
#
# AD-19: single-script-file shape; no inline compounds beyond &&/|| of two
# commands. CON-6 / MEM001 Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="${REPO_ROOT}/commands/comments.md"

pass=0
fail=0
_pass() { pass=$((pass + 1)); echo "PASS: $1"; }
_fail() { fail=$((fail + 1)); echo "FAIL: $1"; }

# Case A: file exists.
if [ -f "$DOC" ]; then
  _pass "Case A: commands/comments.md exists"
else
  _fail "Case A: missing $DOC"
  echo "----"
  echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
  exit 1
fi

# Case B: six subcommands documented as section headers.
_missing_sub=""
for sub in classify status apply reject triage reclassify; do
  if ! grep -qE "^### ${sub}$" "$DOC"; then
    _missing_sub="${_missing_sub} ${sub}"
  fi
done
if [ -z "$_missing_sub" ]; then
  _pass "Case B: all six subcommands documented (classify status apply reject triage reclassify)"
else
  _fail "Case B: missing subcommand headers:${_missing_sub}"
fi

# Case C: D023 referenced.
if grep -q 'D023' "$DOC"; then
  _pass "Case C: D023 retune-trigger pin referenced"
else
  _fail "Case C: D023 not referenced"
fi

# Case D: FR-19 dry-run manifest shape documented.
if grep -q 'FR-19' "$DOC"; then
  if grep -q 'action_type' "$DOC"; then
    _pass "Case D: FR-19 dry-run manifest shape documented"
  else
    _fail "Case D: FR-19 mentioned but action_type field absent"
  fi
else
  _fail "Case D: FR-19 dry-run manifest not documented"
fi

# Case E: human-gate invariant. Verifier self-exempts because this very
# verifier embeds the literal patterns it scans for; only the doc file is
# scanned.
if grep -qE 'CON-5|SC-5|human-gate|never auto-applied|NEVER auto-applied' "$DOC"; then
  _pass "Case E: spec-amendment human-gate invariant documented"
else
  _fail "Case E: human-gate invariant missing from doc"
fi

# Case F: dogfood SSOT cited.
if grep -q 'inbox-dogfood.md' "$DOC"; then
  _pass "Case F: planning-inputs/inbox-dogfood.md cited as SSOT"
else
  _fail "Case F: inbox-dogfood.md SSOT citation missing"
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "PASS: $(basename "$0")"
exit 0
