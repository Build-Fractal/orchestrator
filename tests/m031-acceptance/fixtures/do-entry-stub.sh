#!/usr/bin/env bash
# tests/m031-acceptance/fixtures/do-entry-stub.sh
#
# M031/P03/T02 -- canned dispatch stub for the SC-7 (trivial) and SC-8
# (low-confidence) acceptance tests of scripts/intake/do-entry.sh.
#
# Mirrors the P02 SC-6 stub shape. The entry script invokes this stub
# on the Tier A degenerate fast-path with positional arguments:
#
#     do-entry-stub.sh <branch> <task> <payload-path> <sidecar-path>
#
# The stub appends one line per invocation to ${ORCH_DO_ENTRY_STUB_LOG}
# (default /dev/null) so the test can count dispatches with `wc -l` /
# `grep -c`.
#
# Bash 3.2 compatible (MEM001). No state writes, no scaffold-placeholder
# bracket-TODO byte pattern (CON-7 / D020).

set -u

branch="${1:-unknown}"
task="${2:-unknown}"
payload="${3:-unknown}"
sidecar="${4:-unknown}"

_log="${ORCH_DO_ENTRY_STUB_LOG:-/dev/null}"
printf 'stub-invocation: branch=%s task=%s payload=%s sidecar=%s\n' \
    "$branch" "$task" "$payload" "$sidecar" >> "$_log"

exit 0
