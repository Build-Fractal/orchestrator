#!/usr/bin/env bash
# scripts/verify/m027-p00-rollup-cli-contract.sh — M027/P00 FR-1 / FR-2 / FR-3.
#
# Asserts that scripts/diagnostics/metrics-rollup.sh exposes the documented
# CLI surface: --help exits 0 and advertises every flag (--granularity,
# --milestone, --phase, --task, --source, --log); an unknown flag
# (--bogus-flag) exits with code 2 (usage / unknown flag).
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted internally.
# AD-19 script-file shape applies at phase-plan Check level (this file is the
# single script invoked).

set -u

NAME="m027-p00-rollup-cli-contract.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"

if [ ! -x "$ROLLUP" ] && [ ! -r "$ROLLUP" ]; then
  printf 'FAIL: %s rollup-missing at=%s\n' "$NAME" "$ROLLUP" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

# --- (1) --help exits 0 and lists every documented flag ------------------
help_out="$tmp/help.out"
help_err="$tmp/help.err"
bash "$ROLLUP" --help >"$help_out" 2>"$help_err"
help_rc=$?

if [ "$help_rc" -ne 0 ]; then
  printf 'FAIL: %s --help exited %d (expected 0)\n' "$NAME" "$help_rc" >&2
  exit 1
fi

# Combined stream — usage may print to either stdout or stderr depending on
# how the caller invokes --help. We check the union.
help_all="$tmp/help.all"
cat "$help_out" "$help_err" > "$help_all"

missing=""
for flag in --granularity --milestone --phase --task --source --log; do
  if ! grep -qF -- "$flag" "$help_all"; then
    missing="$missing $flag"
  fi
done

if [ -n "$missing" ]; then
  printf 'FAIL: %s --help missing flags:%s\n' "$NAME" "$missing" >&2
  exit 1
fi

# --- (2) bogus flag exits with code 2 -----------------------------------
bash "$ROLLUP" --bogus-flag >/dev/null 2>"$tmp/bogus.err"
bogus_rc=$?

if [ "$bogus_rc" -ne 2 ]; then
  printf 'FAIL: %s --bogus-flag exited %d (expected 2)\n' "$NAME" "$bogus_rc" >&2
  exit 1
fi

printf 'PASS: %s help-rc=0 flags-present=6 bogus-rc=2\n' "$NAME"
exit 0
