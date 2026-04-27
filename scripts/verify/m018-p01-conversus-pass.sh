#!/usr/bin/env bash
# scripts/verify/m018-p01-conversus-pass.sh — phase-truth verifier:
# "the conversus --strict gate against the compression-grammar contract
#  produced a PASS verdict before P01 close".
#
# Reads the gate-result.md frontmatter and asserts verdict: PASS.
# AD-19 single-script-file shape, bash 3.2, MEM001 PASS/FAIL, exit 0/1.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE_RESULT="$REPO_ROOT/.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md"

if [ ! -f "$GATE_RESULT" ]; then
  printf 'FAIL: gate-result missing: %s\n' "$GATE_RESULT" >&2
  printf '  Run: bash scripts/dispatch/adapters/tool/conversus.sh gate --strict compression-grammar references/compression-grammar.md %s\n' "$GATE_RESULT" >&2
  exit 1
fi

# Parse the frontmatter verdict line. Shape: `verdict: "PASS"` or `verdict: PASS`.
VERDICT_LINE="$(grep -E '^verdict:' "$GATE_RESULT" | head -n 1 || true)"

if [ -z "$VERDICT_LINE" ]; then
  printf 'FAIL: no verdict field in gate-result frontmatter: %s\n' "$GATE_RESULT" >&2
  exit 1
fi

# Strip key, quotes, whitespace.
VERDICT="$(printf '%s\n' "$VERDICT_LINE" | sed -E 's/^verdict:[[:space:]]*"?([A-Z]+)"?.*$/\1/')"

if [ "$VERDICT" != "PASS" ]; then
  printf 'FAIL: conversus gate verdict is %s (required: PASS): %s\n' "$VERDICT" "$GATE_RESULT" >&2
  exit 1
fi

# Optional sanity: confirm preset and source_hash fields exist (audit-trail completeness).
if ! grep -qE '^preset:' "$GATE_RESULT"; then
  printf 'FAIL: gate-result missing preset field (audit-trail incomplete): %s\n' "$GATE_RESULT" >&2
  exit 1
fi

if ! grep -qE '^source_hash:' "$GATE_RESULT"; then
  printf 'FAIL: gate-result missing source_hash field (audit-trail incomplete): %s\n' "$GATE_RESULT" >&2
  exit 1
fi

PRESET="$(grep -E '^preset:' "$GATE_RESULT" | head -n 1 | sed -E 's/^preset:[[:space:]]*"?([^"]+)"?.*$/\1/')"

printf 'PASS: m018-p01-conversus-pass.sh verdict=PASS preset=%s gate-result=%s\n' "$PRESET" "$GATE_RESULT"
exit 0
