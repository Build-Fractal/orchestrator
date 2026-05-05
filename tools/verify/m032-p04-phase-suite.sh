#!/usr/bin/env bash
# tools/verify/m032-p04-phase-suite.sh — P04 phase-suite aggregator.
# Invokes every P04 sub-gate in literal sequence per AD-19 single-
# script-file shape (no for-loop iteration over sub-gates — each gate
# is invoked by an explicit literal `bash <path>` line so a maintainer
# collapsing this into a loop trips the AD-19 shape-detection guard).
# Exits 0 iff every gate passes; emits a single SUMMARY line.
# Bash 3.2.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

run_gate() {
  _name="$1"
  _path="$2"
  if [ ! -x "$_path" ]; then
    say_fail "$_name: verifier missing or non-executable at $_path"
    return
  fi
  _gate_out="${TMPDIR:-/tmp}/m032-p04-gate-$$.out"
  if bash "$_path" >"$_gate_out" 2>&1; then
    say_pass "$_name"
  else
    rc=$?
    _tail="$(tail -3 "$_gate_out" | tr '\n' ' ')"
    say_fail "$_name (rc=$rc): $_tail"
  fi
  rm -f "$_gate_out"
}

# Eleven P04 sub-gates in literal sequence (NOT a for-loop per AD-19).
run_gate 'FR-17/18/19 scanner-extensions' tools/verify/m032-p04-scanner-extensions.sh
run_gate 'FR-17/18/19 nav-extensions'     tools/verify/m032-p04-nav-extensions.sh
run_gate 'FR-20 decorator-shape'          tools/verify/m032-p04-decorator-shape.sh
run_gate '--with-wiki noop'               tools/verify/m032-p04-with-wiki-noop.sh
run_gate 'SC-8 acceptance-shape'          tools/verify/m032-p04-acceptance-shape-sc8.sh
run_gate 'SC-9 acceptance-shape'          tools/verify/m032-p04-acceptance-shape-sc9.sh
run_gate 'SC-11 acceptance-shape'         tools/verify/m032-p04-acceptance-shape-sc11.sh
run_gate 'SC-12 battery-shape'            tools/verify/m032-p04-acceptance-battery-shape.sh
run_gate 'SC-13 validate-milestone'       tools/verify/m032-p04-validate-milestone.sh
run_gate 'SC-14 close-ceremony'           tools/verify/m032-p04-milestone-close-ceremony.sh
run_gate 'evidence-ledger'                tools/verify/m032-p04-acceptance-evidence-ledger.sh

printf 'SUMMARY: m032-p04-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
