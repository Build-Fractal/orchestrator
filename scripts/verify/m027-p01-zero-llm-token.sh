#!/usr/bin/env bash
# scripts/verify/m027-p01-zero-llm-token.sh — M027/P01 Truth #5
# (FR-21, CON-6, SC-16).
#
# Asserts the predictive script set + the P01 verifier set contain no
# LLM-invocation tokens. Verifier files are listed explicitly to avoid
# globbing-pulls-in-self issues — but this verifier itself contains the
# regex literal, so the scan list excludes the verifier file by name.
#
# Forbidden tokens (built from split string fragments below so the
# scanner does not self-match on its own source):
#   claude_chat, anthropic, dispatch-interface.sh, dispatch_task, subagent
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out.

set -u

NAME="m027-p01-zero-llm-token.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Split-literal forbidden tokens — keep them out of the scanner's own
# matchable source.
TOK_A='claude'_'chat'
TOK_B='anthro''pic'
TOK_C='dispatch-''interface.sh'
TOK_D='dispatch'_'task'
TOK_E='sub''agent'

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# Explicit file list (no globbing of the verifier set so we can exclude
# this verifier deterministically).
files=""
[ -f "$PROJECT_ROOT/scripts/engine/cost-estimate.sh" ] && files="$files $PROJECT_ROOT/scripts/engine/cost-estimate.sh"
[ -f "$PROJECT_ROOT/scripts/engine/intensity-recommend.sh" ] && files="$files $PROJECT_ROOT/scripts/engine/intensity-recommend.sh"

# P01 verifier set, explicit (excluding self).
verifier_list="
m027-p01-suite.sh
m027-p01-cost-command-shape.sh
m027-p01-cost-retro-default.sh
m027-p01-cost-estimate-table.sh
m027-p01-predictive-goodhart-pairing.sh
m027-p01-predictive-latency.sh
m027-p01-pricing-degradation.sh
m027-p01-intensity-text-back-compat.sh
m027-p01-intensity-json-cost-estimates.sh
m027-p01-read-only.sh
m027-p01-runtime-adapter-registration.sh
m027-p01-bash32-compat.sh
"
for v in $verifier_list; do
  vp="$PROJECT_ROOT/scripts/verify/$v"
  [ -f "$vp" ] || continue
  files="$files $vp"
done

if [ -z "$files" ]; then
  fail "no files in scan set"
fi

violations=0
scanned=0
for f in $files; do
  scanned=$((scanned + 1))
  # Strip comment-only lines so token-mention-in-comment is allowed.
  body="$(grep -v '^[[:space:]]*#' "$f")"
  for needle in "$TOK_A" "$TOK_B" "$TOK_C" "$TOK_D" "$TOK_E"; do
    if printf '%s' "$body" | grep -qF "$needle"; then
      printf 'FAIL: %s %s contains LLM token [%s]\n' "$NAME" "$f" "$needle" >&2
      violations=$((violations + 1))
    fi
  done
done

if [ "$violations" -ne 0 ]; then
  fail "$violations LLM-token violation(s) across $scanned file(s)"
fi

printf 'PASS: %s scanned=%d files clean of LLM tokens\n' "$NAME" "$scanned"
exit 0
