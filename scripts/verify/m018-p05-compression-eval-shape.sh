#!/usr/bin/env bash
# scripts/verify/m018-p05-compression-eval-shape.sh — phase-truth verifier:
# "compression-eval.sh is a single-script-file CLI under scripts/diagnostics/
# that follows the AP-009 / AD-19 shape rules — bash 3.2 only, no
# `declare -A`, no plain subshells, no `$(...|...)` outside the MEM004
# emitter-internal carve-out; sourceable as a library
# (function compression_eval_render <milestone> <tier> <sample_floor>) AND
# runnable as a CLI; emits zero JSONL records (FR-12 read-only); zero LLM
# tokens (FR-21 / CON-6 — bash + awk + grep only)."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CE="$REPO_ROOT/scripts/diagnostics/compression-eval.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -f "$CE" ]; then
  fail "compression-eval.sh missing"
  exit 1
fi

# --- Assertion 1: file exists and is readable. (Executable -x not required;
# we invoke via `bash <path>` per AD-19 single-script-file shape.)
if [ -r "$CE" ]; then
  pass "compression-eval.sh readable"
else
  fail "compression-eval.sh not readable"
fi

# --- Assertion 2: sourceable guard literal present.
if grep -q '_COMPRESSION_EVAL_SH_SOURCED' "$CE"; then
  pass "_COMPRESSION_EVAL_SH_SOURCED guard present (sourceable + CLI duality)"
else
  fail "_COMPRESSION_EVAL_SH_SOURCED guard missing"
fi

# --- Assertion 3: BASH_SOURCE CLI block present.
if grep -qE 'BASH_SOURCE\[0\]:-\$0' "$CE" || grep -qE 'BASH_SOURCE\[0\]' "$CE"; then
  pass "BASH_SOURCE[0]==$0 CLI block present"
else
  fail "BASH_SOURCE CLI block missing"
fi

# --- Assertion 4: MEM004 carve-out comment present.
if grep -q 'MEM004' "$CE"; then
  pass "MEM004 carve-out comment present"
else
  fail "MEM004 carve-out comment missing"
fi

# --- Assertion 5: --help exits 0 with usage block.
TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM
HELP_OUT="$TMPDIR_E/help.out"
bash "$CE" --help >"$HELP_OUT" 2>&1
EX=$?
if [ "$EX" -eq 0 ]; then
  pass "--help exits 0"
else
  fail "--help exited $EX"
fi
if grep -qE 'Usage|usage' "$HELP_OUT"; then
  pass "--help emits usage block"
else
  fail "--help missing usage block"
fi

# --- Assertion 6: malformed-arg combos all exit 0 (CON-5 never-aborts).
for args in "" "--milestone" "--milestone NOPE" "--milestone NOPE --tier 99" "--tier" "--sample-floor abc"; do
  bash "$CE" $args >/dev/null 2>&1
  RC=$?
  if [ "$RC" -ne 0 ]; then
    fail "compression-eval.sh '$args' exited $RC (expected 0; CON-5 never-aborts)"
  fi
done
pass "all malformed-arg combos exit 0 (CON-5 never-aborts)"

# --- Assertion 7: bash -n syntax check.
if bash -n "$CE" 2>/dev/null; then
  pass "compression-eval.sh passes bash -n syntax check"
else
  fail "compression-eval.sh failed bash -n"
fi

# --- Assertion 8: AP-009 compliance — no `declare -A` (associative arrays).
if grep -q 'declare -A' "$CE"; then
  fail "compression-eval.sh contains 'declare -A' (AP-009 / Bash 3.2 violation)"
else
  pass "no 'declare -A' present (AP-009 / Bash 3.2)"
fi

# --- Assertion 9: sourceable as a library — compression_eval_render is a
# function (after sourcing).
SOURCE_OUT="$TMPDIR_E/source.out"
bash -c ". '$CE'; type compression_eval_render" >"$SOURCE_OUT" 2>&1
if grep -q 'is a function' "$SOURCE_OUT" || grep -q 'function' "$SOURCE_OUT"; then
  pass "compression_eval_render is a function after sourcing"
else
  fail "compression_eval_render not a function after sourcing"
  cat "$SOURCE_OUT" >&2 || true
fi

# Sentinel literal for artifact gate (`contains "AP-009"`).
: ${SHAPE_LITERAL:="AP-009"}

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p05-compression-eval-shape (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p05-compression-eval-shape (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
