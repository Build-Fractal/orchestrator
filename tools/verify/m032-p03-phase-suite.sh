#!/usr/bin/env bash
# tools/verify/m032-p03-phase-suite.sh — P03 phase-suite aggregator.
# Invokes every P03 sub-gate in dependency order, exits 0 iff every gate
# passes, emits a single SUMMARY line. Single-script-file shape per AD-19.
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
  if bash "$_path" >/tmp/m032-p03-gate-$$.out 2>&1; then
    say_pass "$_name"
  else
    rc=$?
    say_fail "$_name (rc=$rc): $(tail -3 /tmp/m032-p03-gate-$$.out | tr '\n' ' ')"
  fi
  rm -f /tmp/m032-p03-gate-$$.out
}

run_gate 'FR-7 giscus-templating'              tools/verify/m032-p03-giscus-templating.sh
run_gate 'FR-8 with-giscus-scope'              tools/verify/m032-p03-with-giscus-scope.sh
run_gate 'FR-9 deploy-scope'                   tools/verify/m032-p03-deploy-scope.sh
run_gate 'FR-10 wiki-deploy-cwd-gate'          tools/verify/m032-p03-wiki-deploy-cwd-gate.sh
run_gate 'FR-14 custom-nav-region'             tools/verify/m032-p03-custom-nav-region.sh
run_gate 'FR-13 with-feature-pattern-doc'      tools/verify/m032-p03-with-feature-pattern-doc.sh
run_gate 'AD-7 throwaway-protocol-shape'       tools/verify/m032-p03-throwaway-protocol-shape.sh
run_gate 'SC-4 acceptance-shape'               tools/verify/m032-p03-acceptance-shape-sc4.sh
run_gate 'SC-5 acceptance-shape'               tools/verify/m032-p03-acceptance-shape-sc5.sh
run_gate 'SC-6 acceptance-shape'               tools/verify/m032-p03-acceptance-shape-sc6.sh

printf 'SUMMARY: m032-p03-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
