#!/usr/bin/env bash
# scripts/verify/m018-p07-runtime-assumptions-and-dual-write.sh — phase-truth
# verifier (Truth #3): "references/RUNTIME-ASSUMPTIONS.md exists with a
# # Compression (M018) block carrying at least one RA-M018-NN row (or an
# explicit no-divergences-observed line); CLAUDE.md and AGENTS.md
# orchestrator:recent-changes regions both name M018/P07 and runtime-parity
# (phase-close dual-write via scripts/util/dual-write-runtime-md.sh)."
#
# Mirrors scripts/verify/m018-p06-dual-write-recent.sh (M018/P06 -> M018/P07)
# and adds the RUNTIME-ASSUMPTIONS.md assertions.
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001),
# pass()/fail() per MEM002.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ASSUMPTIONS="$REPO_ROOT/references/RUNTIME-ASSUMPTIONS.md"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# --- Assertion 1: references/RUNTIME-ASSUMPTIONS.md exists.
if [ -f "$ASSUMPTIONS" ]; then
  pass "references/RUNTIME-ASSUMPTIONS.md exists"
else
  fail "references/RUNTIME-ASSUMPTIONS.md missing"
  printf 'FAIL: m018-p07-runtime-assumptions-and-dual-write (cannot continue)\n' >&2
  exit 1
fi

# --- Assertion 2: file contains the literal '# Compression (M018)' header.
if grep -qF "# Compression (M018)" "$ASSUMPTIONS"; then
  pass "RUNTIME-ASSUMPTIONS.md contains '# Compression (M018)' block header"
else
  fail "RUNTIME-ASSUMPTIONS.md missing '# Compression (M018)' block header"
fi

# --- Assertion 3: file contains at least one RA-M018-NN row OR an explicit
# 'no divergences observed' line in the bash-only tier parity block.
if grep -qE "RA-M018-[0-9]+" "$ASSUMPTIONS"; then
  pass "RUNTIME-ASSUMPTIONS.md carries at least one RA-M018-NN row"
elif grep -qiE "no divergence(s)? (was )?observed" "$ASSUMPTIONS"; then
  pass "RUNTIME-ASSUMPTIONS.md explicitly states 'no divergences observed'"
else
  fail "RUNTIME-ASSUMPTIONS.md has no RA-M018-NN row and no 'no divergences observed' statement"
fi

# --- Iterate over CLAUDE.md and AGENTS.md.
for f in "$REPO_ROOT/CLAUDE.md" "$REPO_ROOT/AGENTS.md"; do
  fname="$(basename "$f")"
  if [ ! -f "$f" ]; then
    fail "missing $fname"
    continue
  fi
  pass "$fname exists"

  block="$(awk '
    /^# >>> orchestrator:recent-changes >>>/ { in_blk=1; next }
    /^# <<< orchestrator:recent-changes <<</ { in_blk=0 }
    in_blk { print }
  ' "$f")"

  if [ -z "$block" ]; then
    fail "$fname has empty/missing orchestrator:recent-changes region"
    continue
  fi
  pass "$fname has orchestrator:recent-changes region"

  if printf '%s\n' "$block" | grep -qF 'M018/P07'; then
    pass "$fname recent-changes block names M018/P07"
  else
    fail "$fname recent-changes block missing M018/P07 marker"
  fi

  if printf '%s\n' "$block" | grep -qF 'runtime-parity'; then
    pass "$fname recent-changes block names runtime-parity"
  else
    fail "$fname recent-changes block missing runtime-parity marker"
  fi
done

# --- Final result. M018/P07 literal in this verifier (artifact contains check).
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p07-runtime-assumptions-and-dual-write (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p07-runtime-assumptions-and-dual-write (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
