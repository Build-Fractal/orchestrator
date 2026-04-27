#!/usr/bin/env bash
# scripts/verify/m027-p00-zero-llm-token.sh — M027/P00 FR-21 / CON-6 / SC-16.
#
# Greps the M027/P00 script set for forbidden patterns that would imply
# LLM/dispatch coupling. Forbidden tokens:
#   - claude_chat
#   - anthropic
#   - dispatch-interface.sh
#   - dispatch_task
#   - subagent
#
# Self-application: the verifier scans itself, so the literal forbidden
# tokens MUST be assembled at runtime via split string literals. The
# scanned set is:
#   - scripts/diagnostics/metrics-rollup.sh
#   - every scripts/verify/m027-p00-*.sh (this file included)
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-zero-llm-token.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
VERIFY_GLOB="$PROJECT_ROOT/scripts/verify/m027-p00-*.sh"

# Split-literal forbidden tokens so this scanner does not self-match. The
# documentation comment above lists the literal forms for human readers.
FORBID_A='claude''_chat'
FORBID_B='anth''ropic'
FORBID_C='dispatch''-interface.sh'
FORBID_D='dispatch''_task'
FORBID_E='sub''agent'

if [ ! -r "$ROLLUP" ]; then
  printf 'FAIL: %s rollup-missing at=%s\n' "$NAME" "$ROLLUP" >&2
  exit 1
fi

# Build the file list — rollup + every m027-p00-*.sh.
files=""
files="$files $ROLLUP"
for f in $VERIFY_GLOB; do
  [ -f "$f" ] || continue
  files="$files $f"
done

violations=0
scanned=0
for f in $files; do
  [ -f "$f" ] || continue
  scanned=$((scanned + 1))
  for needle in "$FORBID_A" "$FORBID_B" "$FORBID_C" "$FORBID_D" "$FORBID_E"; do
    # Strip comment-only lines first so docstrings explaining the forbidden
    # tokens don't trip the gate.
    hit="$(grep -v '^[[:space:]]*#' "$f" | grep -nF "$needle" || true)"
    if [ -n "$hit" ]; then
      printf 'FAIL: %s %s contains forbidden token [%s]\n' "$NAME" "$f" "$needle" >&2
      printf '%s\n' "$hit" >&2
      violations=$((violations + 1))
    fi
  done
done

if [ "$violations" -ne 0 ]; then
  printf 'FAIL: %s %d violation(s) across %d file(s)\n' "$NAME" "$violations" "$scanned" >&2
  exit 1
fi

printf 'PASS: %s scanned=%d files clean\n' "$NAME" "$scanned"
exit 0
