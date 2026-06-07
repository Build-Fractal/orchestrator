#!/usr/bin/env bash
# tools/verify/m034-p03-runtime-assumptions.sh — M034 P03 (FR-14 / SC-9).
#
# Static verifier for the FR-14 documentation surface:
#   1. references/RUNTIME-ASSUMPTIONS.md carries the three interactive-review
#      primitive rows (RA-M034-REVIEW-01/02/03) + the tokens AskUserQuestion,
#      elicitation/create, QUESTIONS.md.
#   2. references/interactive-review-renderer.md documents a Cursor-MCP section
#      naming elicitation/create, review-gate-mcp-server.sh, interactive-cursor.
#
# Prints PASS/FAIL: m034-p03 runtime-assumptions. Exit 0 on PASS, 1 on FAIL.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

RA="$REPO_ROOT/references/RUNTIME-ASSUMPTIONS.md"
RENDERER="$REPO_ROOT/references/interactive-review-renderer.md"

_fail() {
  echo "FAIL: m034-p03 runtime-assumptions — $1"
  exit 1
}

# require_token <file> <literal-token> <label>
require_token() {
  _f="$1"; _tok="$2"; _lbl="$3"
  [ -f "$_f" ] || _fail "missing file: $_f"
  grep -qF "$_tok" "$_f" || _fail "$_lbl missing token '$_tok' in $(basename "$_f")"
}

# --- 1. RUNTIME-ASSUMPTIONS.md rows + tokens. --------------------------------
require_token "$RA" "RA-M034-REVIEW-01" "RUNTIME-ASSUMPTIONS"
require_token "$RA" "RA-M034-REVIEW-02" "RUNTIME-ASSUMPTIONS"
require_token "$RA" "RA-M034-REVIEW-03" "RUNTIME-ASSUMPTIONS"
require_token "$RA" "AskUserQuestion" "RUNTIME-ASSUMPTIONS"
require_token "$RA" "elicitation/create" "RUNTIME-ASSUMPTIONS"
require_token "$RA" "QUESTIONS.md" "RUNTIME-ASSUMPTIONS"

# --- 2. interactive-review-renderer.md Cursor-MCP section. --------------------
[ -f "$RENDERER" ] || _fail "missing file: $RENDERER"
grep -qi "Cursor-MCP renderer path" "$RENDERER" || _fail "renderer doc missing Cursor-MCP section heading"
require_token "$RENDERER" "elicitation/create" "renderer-doc"
require_token "$RENDERER" "review-gate-mcp-server.sh" "renderer-doc"
require_token "$RENDERER" "interactive-cursor" "renderer-doc"

echo "PASS: m034-p03 runtime-assumptions"
exit 0
