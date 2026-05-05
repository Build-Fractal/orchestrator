#!/usr/bin/env bash
# tools/verify/m032-p04-acceptance-battery-shape.sh — SC-12 acceptance
# battery runner shape verifier. Asserts that
# tests/m032-acceptance/run-acceptance-battery.sh:
#   - exists and is executable;
#   - inherits the M030/M031 shape (`set -uo pipefail` + run_sc helper +
#     final BATTERY: envelope);
#   - implements the MIT-001 three-category exit-code contract
#     (pass++/skip++/fail++ on rc==0/77/other);
#   - chains all eleven SC labels (SC-1..SC-11) in literal sequence per
#     AD-19 single-script-file shape;
#   - emits BATTERY-PASS / BATTERY-SKIP / BATTERY-FAIL line shapes;
#   - exposes the M032_ACCEPTANCE_BATTERY_DRY=1 test-only env-var that
#     emits exactly `BATTERY: pass=0 skip=11 fail=0` for shape
#     verification without exercising real SCs.
#
# Bash 3.2 compatible. Single-script-file shape (AD-19).
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$REPO_ROOT/tests/m032-acceptance/run-acceptance-battery.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -f "$RUNNER" ]; then
  say_fail "$RUNNER absent"
  printf 'SUMMARY: m032-p04-acceptance-battery-shape pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -x "$RUNNER" ]; then
  say_fail "$RUNNER not executable"
  printf 'SUMMARY: m032-p04-acceptance-battery-shape pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
say_pass "runner exists and is executable"

# M030/M031 inheritance — top-line invariants.
if grep -qF -- 'set -uo pipefail' "$RUNNER"; then
  say_pass "runner uses 'set -uo pipefail'"
else
  say_fail "runner missing 'set -uo pipefail'"
fi

if grep -qE '^run_sc\(\)' "$RUNNER"; then
  say_pass "runner defines run_sc() helper"
else
  say_fail "runner missing run_sc() helper definition"
fi

# Final summary envelope.
if grep -qF -- 'BATTERY: pass=' "$RUNNER"; then
  say_pass "runner emits 'BATTERY: pass=' summary line"
else
  say_fail "runner missing 'BATTERY: pass=' summary line"
fi

# MIT-001 three-category contract surface.
if grep -qF -- 'MIT-001' "$RUNNER"; then
  say_pass "runner cites MIT-001"
else
  say_fail "runner missing MIT-001 citation"
fi

if grep -qF -- 'SKIP_REASON' "$RUNNER"; then
  say_pass "runner emits SKIP_REASON"
else
  say_fail "runner missing SKIP_REASON"
fi

# rc==77 skip branch (either `rc -eq 77` arithmetic-test or a literal
# `exit 77` would do; the runner uses the former; accept either).
if grep -qE 'rc.*-eq[[:space:]]+77' "$RUNNER"; then
  say_pass "runner has rc -eq 77 skip branch"
elif grep -qF -- 'exit 77' "$RUNNER"; then
  say_pass "runner has exit 77 skip branch"
else
  say_fail "runner missing rc==77 skip branch"
fi

# Three counter names.
for tok in 'pass=' 'skip=' 'fail='; do
  if grep -qF -- "$tok" "$RUNNER"; then
    say_pass "runner has counter token: $tok"
  else
    say_fail "runner missing counter token: $tok"
  fi
done

# Three battery line shapes.
for tok in 'BATTERY-PASS' 'BATTERY-SKIP' 'BATTERY-FAIL'; do
  if grep -qF -- "$tok" "$RUNNER"; then
    say_pass "runner emits $tok line"
  else
    say_fail "runner missing $tok line"
  fi
done

# All eleven SC labels in literal sequence.
for sc in SC-1 SC-2 SC-3 SC-4 SC-5 SC-6 SC-7 SC-8 SC-9 SC-10 SC-11; do
  if grep -qF -- "\"$sc\"" "$RUNNER"; then
    say_pass "runner contains SC label: $sc"
  else
    say_fail "runner missing SC label: $sc"
  fi
done

# AD-19 single-script-file shape: literal-sequence run_sc invocations,
# not a for-loop over the SC list. Assert the script does NOT contain a
# loop construct iterating over SC labels.
if grep -qE '^[[:space:]]*for[[:space:]]+.*[Ss][Cc]-' "$RUNNER"; then
  say_fail "runner uses a for-loop over SC labels (violates AD-19 literal-sequence)"
else
  say_pass "runner uses literal-sequence run_sc invocations (no for-loop over SCs)"
fi

# Dry-mode escape hatch.
if grep -qF -- 'M032_ACCEPTANCE_BATTERY_DRY' "$RUNNER"; then
  say_pass "runner exposes M032_ACCEPTANCE_BATTERY_DRY env-var"
else
  say_fail "runner missing M032_ACCEPTANCE_BATTERY_DRY env-var"
fi

# Dry-mode runtime check: invoking the runner with the env-var must
# emit exactly `BATTERY: pass=0 skip=11 fail=0` and exit 0.
DRY_OUT="$(M032_ACCEPTANCE_BATTERY_DRY=1 bash "$RUNNER" 2>/dev/null)"
DRY_RC=$?
if [ "$DRY_RC" -eq 0 ]; then
  say_pass "dry-mode runner exits 0"
else
  say_fail "dry-mode runner exited $DRY_RC (expected 0)"
fi

DRY_FINAL="$(printf '%s\n' "$DRY_OUT" | grep -E '^BATTERY: ' | tail -n 1)"
if [ "$DRY_FINAL" = 'BATTERY: pass=0 skip=11 fail=0' ]; then
  say_pass "dry-mode emits 'BATTERY: pass=0 skip=11 fail=0'"
else
  say_fail "dry-mode final line was '$DRY_FINAL' (expected 'BATTERY: pass=0 skip=11 fail=0')"
fi

# Confirm the dry-mode emitted exactly 11 BATTERY-SKIP lines (one per SC).
DRY_SKIP_COUNT="$(printf '%s\n' "$DRY_OUT" | grep -c '^BATTERY-SKIP: ' || true)"
if [ "$DRY_SKIP_COUNT" = '11' ]; then
  say_pass "dry-mode emits 11 BATTERY-SKIP lines (one per SC)"
else
  say_fail "dry-mode emitted $DRY_SKIP_COUNT BATTERY-SKIP lines (expected 11)"
fi

printf 'SUMMARY: m032-p04-acceptance-battery-shape pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
