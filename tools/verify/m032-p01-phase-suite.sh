#!/usr/bin/env bash
# tools/verify/m032-p01-phase-suite.sh -- M032 P01 T04 phase-suite aggregator.
#
# Chains all eleven P01 verifiers under tools/verify/ in deterministic order,
# captures per-verifier output to a per-run log dir, increments fail counter
# on any sub-gate's non-zero exit, and emits a SUMMARY: line at end.
#
# Per AD-19 single-script-file shape: each sub-gate is invoked as
# `bash tools/verify/<name>.sh` -- never inline compound bash, never sourced.
#
# Output:
#   <per-sub-gate output passed through to stdout>
#   SUMMARY: m032-p01-phase-suite.sh pass=N fail=M
#
# Exit code: 0 if all sub-gates pass; otherwise the count of failed sub-gates.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
VERIFY_DIR="$PROJECT_ROOT/tools/verify"

SUB_GATES="
m032-p01-manifest-schema-shape.sh
m032-p01-reader-emits-tuples.sh
m032-p01-install-cc-byte-identical.sh
m032-p01-installers-parity.sh
m032-p01-mode-handler-symlink.sh
m032-p01-installed-files-format.sh
m032-p01-collision-oracle.sh
m032-p01-fixture-shape.sh
m032-p01-acceptance-shape-sc1.sh
m032-p01-acceptance-shape-sc2.sh
m032-p01-acceptance-shape-sc10.sh
"

LOG_DIR="${TMPDIR:-/tmp}/m032-p01-phase-suite-$$"
mkdir -p "$LOG_DIR"

cleanup() {
    rm -rf "$LOG_DIR"
}
trap cleanup EXIT

pass_count=0
fail_count=0

for gate in $SUB_GATES; do
    gate_path="$VERIFY_DIR/$gate"
    if [ ! -f "$gate_path" ]; then
        printf 'FAIL: phase-suite sub-gate missing: %s\n' "$gate_path"
        fail_count=$((fail_count + 1))
        continue
    fi
    log_file="$LOG_DIR/${gate%.sh}.log"
    bash "$gate_path" > "$log_file" 2>&1
    rc=$?
    cat "$log_file"
    if [ "$rc" -eq 0 ]; then
        pass_count=$((pass_count + 1))
    else
        fail_count=$((fail_count + 1))
        printf 'FAIL: sub-gate %s exited %s\n' "$gate" "$rc"
    fi
done

printf 'SUMMARY: m032-p01-phase-suite.sh pass=%d fail=%d\n' "$pass_count" "$fail_count"
if [ "$fail_count" -eq 0 ]; then
    exit 0
fi
exit "$fail_count"
