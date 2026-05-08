#!/usr/bin/env bash
# tools/verify/m035-p01-phase-suite.sh -- M035 P01 phase-suite aggregator.
#
# Filename embeds `m035-p01-` per AD-19 path discipline (unprefixed
# `p01-phase-suite.sh` shape silently clobbered prior milestones'
# aggregators in the M030/M031/M036 observed regression series,
# 2026-05-01) and is forbidden.
#
# Aggregates the seven M035 P01 task-grain verifiers and emits a
# `BATTERY: pass=<N> fail=<M>` summary. Exits 0 iff fail=0.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

VERIFIERS="
m035-p01-mode-flag.sh
m035-p01-symlink-source-target.sh
m035-p01-mode-aware-uninstall.sh
m035-p01-drift-detection.sh
m035-p01-drift-detection-sha-absent.sh
m035-p01-drift-line-in-status.sh
m035-p01-drift-line-suppressed.sh
"

pass=0
fail=0

printf '=== m035-p01-phase-suite (M035/P01 aggregator) ===\n'
printf 'bash_version=%s\n' "${BASH_VERSION:-unknown}"
printf '\n'

for v in $VERIFIERS; do
    verifier="$SCRIPT_DIR/$v"
    if [ ! -f "$verifier" ]; then
        printf 'FAIL: %s (verifier missing)\n' "$v"
        fail=$((fail + 1))
        continue
    fi

    set +e
    bash "$verifier" >/dev/null 2>&1
    rc=$?
    set -e

    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$v"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s (rc=%d)\n' "$v" "$rc"
        fail=$((fail + 1))
    fi
done

printf '\n'
printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi
