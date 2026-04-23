#!/usr/bin/env bash
# Gate: T05 — split subcommand full body + FR-7 RUNTIME-ASSUMPTIONS entry.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPECIFY="${PROJECT_ROOT}/scripts/specify/specify.sh"
REG="${PROJECT_ROOT}/RUNTIME-ASSUMPTIONS.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$SPECIFY" ] || fail "specify.sh not executable"
[ -f "$REG" ]     || fail "RUNTIME-ASSUMPTIONS.md missing"

# P01 stub language is gone.
grep -qF 'decomposition flow lands in P04 per M014 roadmap' "$SPECIFY" \
  && fail "P01 split stub message still present in specify.sh"

# Full body markers present.
grep -qF 'propose-decomposition' "$SPECIFY"            || fail "propose-decomposition action_type missing"
grep -qF 'spec-splitter-prompt.md' "$SPECIFY"          || fail "splitter prompt reference missing"
grep -qF 'decomposition/' "$SPECIFY"                   || fail "decomposition manifest path missing"

# Runtime gate: under non-CC, split exits 3.
SCRATCH="$(mktemp -d)"
mkdir -p "${SCRATCH}/.orchestrator"
mkdir -p "${SCRATCH}/specs/000-stub"
touch "${SCRATCH}/specs/000-stub/spec.md"
CLAUDE_CODE_RUNTIME=0 bash "$SPECIFY" split "${SCRATCH}/specs/000-stub/spec.md" >/dev/null 2>&1
RC=$?
if [ "$RC" -ne 3 ]; then
  rm -rf "$SCRATCH"
  fail "non-CC split expected exit 3, got $RC"
fi

# No-arg case.
bash "$SPECIFY" split >/dev/null 2>&1
if [ $? -eq 0 ]; then rm -rf "$SCRATCH"; fail "split with no arg exited 0"; fi

# Missing-path case.
bash "$SPECIFY" split "${SCRATCH}/does-not-exist.md" >/dev/null 2>&1
if [ $? -eq 0 ]; then rm -rf "$SCRATCH"; fail "split with missing path exited 0"; fi

rm -rf "$SCRATCH"

# RUNTIME-ASSUMPTIONS FR-7 entry shape.
grep -qE '^### FR-7: LLM-assisted spec decomposition' "$REG" || fail "FR-7 heading missing"
# Each required subsection present (search anywhere in file — all three entries share these subheadings).
grep -qF 'Claude Code assumption' "$REG" || fail "Claude Code assumption subsection missing"
grep -qF 'Codex/Cursor fallback' "$REG"  || fail "Codex/Cursor fallback subsection missing"
grep -qF 'M009 obligation' "$REG"        || fail "M009 obligation subsection missing"

# FR-7 entry is positioned between FR-5 and the end-of-file sentinel.
# Use grep -n and numeric comparison.
L_FR5="$(grep -nE '^### FR-5:' "$REG" | head -n 1 | awk -F: '{print $1}')"
L_FR7="$(grep -nE '^### FR-7:' "$REG" | head -n 1 | awk -F: '{print $1}')"
L_END="$(grep -n 'Future entries land below this line' "$REG" | head -n 1 | awk -F: '{print $1}')"
[ -n "$L_FR5" ] && [ -n "$L_FR7" ] && [ -n "$L_END" ] || fail "could not locate FR-5/FR-7/sentinel line numbers"
if [ "$L_FR7" -le "$L_FR5" ]; then fail "FR-7 appears before FR-5"; fi
if [ "$L_FR7" -ge "$L_END" ]; then fail "FR-7 appears below sentinel"; fi

echo "PASS: split subcommand + FR-7 registry entry verified"
exit 0
