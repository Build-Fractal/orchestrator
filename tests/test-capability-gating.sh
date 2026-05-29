#!/usr/bin/env bash
# tests/test-capability-gating.sh -- §4 capability-gating contract acceptance.
#
# Covers the parallel_subagent_fanout capability probe in
# scripts/dispatch/detect-capabilities.sh and the gating contract documented
# in references/RUNTIME-ASSUMPTIONS.md "Capability Registry".
#
# This is also the forced-fallback lane (Principle VIII anti-rot): it forces
# the capability OFF and asserts the conservative default, so the serial
# fallback path stays continuously exercised even when every real user is on
# Claude Code with workflows available.
#
# Asserts:
#   (1) the flag emits in text output
#   (2) the flag emits in JSON output
#   (3) conservative default is false (no env signals)
#   (4) ORCHESTRATOR_PARALLEL_FANOUT=1 flips it true
#   (5) ORCHESTRATOR_PARALLEL_FANOUT=0 forces it false
#   (6) CLAUDE_CODE_DISABLE_WORKFLOWS=1 wins over the opt-in (hard disable)
#   (7) the Capability Registry section + both seeded rows exist in the registry doc
#   (8) the gating rule names the no-vendor-names invariant
#
# Emits BATTERY: pass=N fail=N skip=N as last stdout line. Exit 0 iff fail=0.
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
CAP="$ROOT/scripts/dispatch/detect-capabilities.sh"
REG="$ROOT/references/RUNTIME-ASSUMPTIONS.md"
pass=0
fail=0
skip=0

ok()   { pass=$((pass + 1)); echo "PASS: $1"; }
bad()  { fail=$((fail + 1)); echo "FAIL: $1"; }

test -f "$CAP" || { bad "$CAP missing"; echo "BATTERY: pass=$pass fail=$fail skip=$skip"; exit 1; }
test -f "$REG" || { bad "$REG missing"; echo "BATTERY: pass=$pass fail=$fail skip=$skip"; exit 1; }

# Run the probe under a controlled environment. We clear the three governing
# vars per-invocation so a host that already exports them can't skew results.
run_text() {
  env -u ORCHESTRATOR_PARALLEL_FANOUT -u CLAUDE_CODE_DISABLE_WORKFLOWS "$@" \
    bash "$CAP" --format text 2>/dev/null
}
run_json() {
  env -u ORCHESTRATOR_PARALLEL_FANOUT -u CLAUDE_CODE_DISABLE_WORKFLOWS "$@" \
    bash "$CAP" --format json 2>/dev/null
}

flag_text() { run_text "$@" | grep '^parallel_subagent_fanout=' | cut -d= -f2; }
flag_json() { run_json "$@" | grep '"parallel_subagent_fanout"' | grep -oE 'true|false' | head -1; }

# (1) emits in text output
if run_text | grep -q '^parallel_subagent_fanout='; then
  ok "parallel_subagent_fanout emitted in text output"
else
  bad "parallel_subagent_fanout missing from text output"
fi

# (2) emits in JSON output
if run_json | grep -q '"parallel_subagent_fanout"'; then
  ok "parallel_subagent_fanout emitted in JSON output"
else
  bad "parallel_subagent_fanout missing from JSON output"
fi

# (3) conservative default is false (no env signals)
if [ "$(flag_text)" = "false" ]; then
  ok "conservative default is false (no env signals)"
else
  bad "default should be false, got '$(flag_text)'"
fi

# (4) opt-in flips it true
if [ "$(flag_text ORCHESTRATOR_PARALLEL_FANOUT=1)" = "true" ]; then
  ok "ORCHESTRATOR_PARALLEL_FANOUT=1 flips capability true"
else
  bad "ORCHESTRATOR_PARALLEL_FANOUT=1 did not enable capability"
fi

# (5) explicit 0 forces false
if [ "$(flag_text ORCHESTRATOR_PARALLEL_FANOUT=0)" = "false" ]; then
  ok "ORCHESTRATOR_PARALLEL_FANOUT=0 forces capability false"
else
  bad "ORCHESTRATOR_PARALLEL_FANOUT=0 did not disable capability"
fi

# (6) hard disable wins over opt-in
if [ "$(flag_text ORCHESTRATOR_PARALLEL_FANOUT=1 CLAUDE_CODE_DISABLE_WORKFLOWS=1)" = "false" ]; then
  ok "CLAUDE_CODE_DISABLE_WORKFLOWS=1 wins over opt-in (hard disable)"
else
  bad "hard disable did not override opt-in"
fi

# (7) registry section + seeded rows present
if grep -q '^## Capability Registry' "$REG"; then
  ok "Capability Registry section present in RUNTIME-ASSUMPTIONS.md"
else
  bad "Capability Registry section missing from RUNTIME-ASSUMPTIONS.md"
fi
if grep -q 'parallel_subagent_fanout' "$REG" && grep -q 'git_worktree_isolation' "$REG"; then
  ok "registry seeds parallel_subagent_fanout + git_worktree_isolation rows"
else
  bad "registry missing one or both seeded capability rows"
fi

# (8) gating rule names the no-vendor-names invariant
if grep -qi 'No vendor names in control flow' "$REG"; then
  ok "gating rule documents the no-vendor-names invariant"
else
  bad "gating rule missing the no-vendor-names invariant"
fi

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
test "$fail" -eq 0
