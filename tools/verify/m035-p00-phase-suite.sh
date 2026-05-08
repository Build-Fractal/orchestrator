#!/usr/bin/env bash
# tools/verify/m035-p00-phase-suite.sh -- M035 P00 phase-suite aggregator.
#
# Filename embeds `m035-p00-` per AD-19 path discipline (unprefixed
# `p00-phase-suite.sh` shape silently clobbered prior milestones M030/M031
# and is forbidden).
#
# Aggregates the five M035 P00 task-grain verifiers and emits a
# `BATTERY: pass=<N> fail=<M>` summary. Exits 0 iff fail=0.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

VERIFIERS="
m035-p00-bash32-collision.sh
m035-p00-managed-gitignore.sh
m035-p00-wiki-stubs-fresh.sh
m035-p00-wiki-deploy-stage.sh
m035-p00-npm-collision-evidence.sh
"

pass=0
fail=0

printf '=== m035-p00-phase-suite (M035/P00 aggregator) ===\n'
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
