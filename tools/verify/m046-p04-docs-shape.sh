#!/usr/bin/env sh
# tools/verify/m046-p04-docs-shape.sh — M046 P04 docs-shape gate.
#
# Asserts that commands/auto.md documents the unattended-envelope contract:
# every load-bearing flag/terminal/ledger token the shipped driver emits is
# named in the operator-facing prose (phase Truth 9). Then runs a bidirectional
# docs-vs-code DRIFT GUARD: each unattended terminal token and each cap flag
# must appear in BOTH commands/auto.md AND the authoritative driver
# scripts/lifecycle/self-continue-drive.sh — the docs may not claim a
# terminal/flag the driver does not emit, and the driver's unattended terminals
# may not go undocumented (vice versa). Emits PASS/FAIL lines + a SUMMARY line;
# exit 0 iff zero failures. POSIX sh, bash-3.2-safe, straight-line (AD-19).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

DOC="commands/auto.md"
DRIVER="scripts/lifecycle/self-continue-drive.sh"

pass=0
fail=0

# has <file> <literal-token>  -> 0 iff token present (fixed-string, dash-safe).
has() {
  grep -qF -e "$2" "$1"
}

# want <label> <file> <literal-token>  -> presence assertion.
want() {
  if has "$2" "$3"; then
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$1"
  else
    fail=$(( fail + 1 ))
    printf 'FAIL: %s — token %s absent from %s\n' "$1" "$3" "$2"
  fi
}

# drift <label> <token>  -> the token must appear in BOTH the docs and the
# driver (bidirectional: no aspirational docs, no undocumented terminal/flag).
drift() {
  if has "$DOC" "$2" && has "$DRIVER" "$2"; then
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$1"
  else
    fail=$(( fail + 1 ))
    printf 'FAIL: %s — %s not present in both %s and %s (docs-vs-code drift)\n' \
      "$1" "$2" "$DOC" "$DRIVER"
    if ! has "$DOC" "$2"; then printf '  missing from docs: %s\n' "$2"; fi
    if ! has "$DRIVER" "$2"; then printf '  missing from driver: %s\n' "$2"; fi
  fi
}

# --- Presence: the doc names every load-bearing token (one check per token) ---

want "doc names --unattended flag"           "$DOC" "--unattended"
want "doc names --max-budget-usd flag"        "$DOC" "--max-budget-usd"
want "doc names --max-wall-clock-s flag"      "$DOC" "--max-wall-clock-s"
want "doc names --max-continuations flag"     "$DOC" "--max-continuations"
want "doc names SELF_CONTINUE:REFUSE"         "$DOC" "SELF_CONTINUE:REFUSE"
want "doc names BUDGET_EXCEEDED terminal"     "$DOC" "BUDGET_EXCEEDED"
want "doc names WALL_CLOCK_EXCEEDED terminal" "$DOC" "WALL_CLOCK_EXCEEDED"
want "doc names SELF_CONTINUE:THRASH"         "$DOC" "SELF_CONTINUE:THRASH"
want "doc names budget-ledger dotfile"        "$DOC" ".self-continue-budget-ledger"
want "doc names kill-reason dotfile"          "$DOC" ".self-continue-kill-reason"
want "doc names total_cost_usd true-up"       "$DOC" "total_cost_usd"
want "doc names unattended-envelope.sh seam"  "$DOC" "unattended-envelope.sh"

# --- Drift guard: unattended terminals present in BOTH docs and driver ---

drift "drift-guard REFUSE terminal"             "SELF_CONTINUE:REFUSE"
drift "drift-guard BUDGET_EXCEEDED terminal"    "SELF_CONTINUE:BUDGET_EXCEEDED"
drift "drift-guard WALL_CLOCK_EXCEEDED terminal" "SELF_CONTINUE:WALL_CLOCK_EXCEEDED"
drift "drift-guard THRASH terminal"             "SELF_CONTINUE:THRASH"

# --- Drift guard: cap flags present in BOTH docs and driver ---

drift "drift-guard --unattended flag"        "--unattended"
drift "drift-guard --max-budget-usd flag"    "--max-budget-usd"
drift "drift-guard --max-continuations flag" "--max-continuations"
drift "drift-guard --max-wall-clock-s flag"  "--max-wall-clock-s"

printf 'SUMMARY: pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
