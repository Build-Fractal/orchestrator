#!/usr/bin/env bash
# tools/verify/m037-p01-auto-generated-escape-hatch.sh
#   — M037 P01 T02 Truth #3 verifier (MIT-01 P0 conditional-overwrite).
#
# Static check that scripts/wiki/wiki-generate-stubs.sh preserves stubs
# carrying `auto_generated: false` in their frontmatter — the operator's
# escape hatch (US-2 Acceptance Scenario 4). Does NOT invoke the
# generator — the acceptance test exercises behavior end-to-end.
#
# Asserts:
#   1. wiki-generate-stubs.sh defines existing_stub_is_protected.
#   2. The protected-stub gate fires on the literal string
#      `auto_generated: false` (matches via regex per
#      auto_generated[ ]*:[ ]*false).
#   3. write_stub() is gated on existing_stub_is_protected
#      (overwrite path is preserved, not unconditional).
#   4. clean_phase() is gated on existing_stub_is_protected
#      (clean does not wipe operator-edited stubs before the
#      write-time gate fires).
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STUBS="$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh"

pass=0
fail=0

ok() {
  printf 'PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

# 1. existing_stub_is_protected is defined.
if [ -f "$STUBS" ] && grep -q '^existing_stub_is_protected()' "$STUBS"; then
  ok "wiki-generate-stubs.sh defines existing_stub_is_protected()"
else
  bad "wiki-generate-stubs.sh missing existing_stub_is_protected() definition"
fi

# 2. The literal `auto_generated: false` regex appears (MIT-01 P0 marker).
if [ -f "$STUBS" ] && grep -E -q 'auto_generated[ ]*:[ ]*false' "$STUBS"; then
  ok "wiki-generate-stubs.sh references auto_generated: false marker"
else
  bad "wiki-generate-stubs.sh missing auto_generated: false marker reference"
fi

# 3. write_stub() body invokes existing_stub_is_protected. Approximate test:
#    look for the gate pattern `if existing_stub_is_protected` inside the file.
#    It must appear at least 3 times — once for write_stub, once for
#    write_stub_extra_with_sibling, once for write_stub_extra_metadata_only —
#    so the escape hatch covers every emit path.
gate_count=$(grep -c 'if existing_stub_is_protected' "$STUBS" 2>/dev/null || printf '0')
if [ -f "$STUBS" ] && [ "$gate_count" -ge 3 ]; then
  ok "write_stub* paths gated on existing_stub_is_protected (count=$gate_count)"
else
  bad "write_stub* paths not gated on existing_stub_is_protected (count=$gate_count, expected >=3)"
fi

# 4. clean_phase() preserves protected stubs (must skip them, not unlink).
#    Look for the gate pattern in the clean_phase region — file-level grep
#    is sufficient since we already counted >=3 above; here we additionally
#    require an explicit STUB-PRESERVED log line tagged with clean_phase to
#    confirm the clean-time branch is wired (not just write-time).
if [ -f "$STUBS" ] && grep -q 'STUB-PRESERVED.*clean_phase' "$STUBS"; then
  ok "clean_phase() preserves auto_generated: false stubs across re-runs"
else
  bad "clean_phase() does not preserve auto_generated: false stubs"
fi

printf 'SUMMARY: m037-p01-auto-generated-escape-hatch pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: m037-p01-auto-generated-escape-hatch\n'
  exit 0
fi
exit 1
