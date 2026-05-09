#!/usr/bin/env bash
# tools/verify/m035-p05-phase-suite.sh
# M035 P05 — phase-suite aggregator.
# Chains every P05 per-truth verifier; emits BATTERY rollup that sums
# each verifier's own pass/fail/skip counts.
#
# Mirrors the m029/m030/m032/m037/m035-P01.5/m035-P02 phase-suite
# convention so consolidate-time grep aggregation is consistent across
# milestone batteries. Differs from the P02 aggregator in that it sums
# each verifier's BATTERY line counts (rather than counting verifiers
# as units) so the rollup carries skip-awareness — T05's
# m035-p05-signature-verification.sh ships pass=7 fail=0 skip=1.
set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
cd "$REPO_ROOT"

total_pass=0
total_fail=0
total_skip=0

# Verifier list — milestone-prefixed slug per AD-19 naming.
# Order: T01 → T05 (parallels the task-plan dependency tree).
VERIFIERS=(
    "tools/verify/m035-p05-rollback-marker-shape.sh"
    "tools/verify/m035-p05-rollback-snapshot-presence.sh"
    "tools/verify/m035-p05-rollback-driver-shape.sh"
    "tools/verify/m035-p05-update-skill-doc-shape.sh"
    "tools/verify/m035-p05-release-workflow-signing-shape.sh"
    "tools/verify/m035-p05-installation-doc-verifying-integrity.sh"
    "tools/verify/m035-p05-signature-verification.sh"
    "tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh"
)

for v in "${VERIFIERS[@]}"; do
    if [ ! -x "$v" ] && [ ! -f "$v" ]; then
        echo "FAIL: verifier missing: $v" >&2
        total_fail=$((total_fail + 1))
        continue
    fi
    err_log="$(mktemp -t m035-p05-suite.XXXXXX)"
    out_log="$(mktemp -t m035-p05-suite-out.XXXXXX)"
    bash "$v" >"$out_log" 2>"$err_log"
    rc=$?
    # Extract BATTERY line from verifier output (last one is canonical).
    battery_line="$(grep -E '^BATTERY:' "$out_log" | tail -1)"
    if [ -z "$battery_line" ]; then
        echo "FAIL: $v emitted no BATTERY line (rc=$rc)" >&2
        total_fail=$((total_fail + 1))
        cat "$err_log" >&2 || true
    else
        # Parse BATTERY: pass=N fail=M [skip=K]
        p="$(echo "$battery_line" | sed -E 's/.*pass=([0-9]+).*/\1/')"
        f="$(echo "$battery_line" | sed -E 's/.*fail=([0-9]+).*/\1/')"
        # If skip= absent in line, treat as 0; else parse it.
        case "$battery_line" in
            *skip=*)
                k="$(echo "$battery_line" | sed -E 's/.*skip=([0-9]+).*/\1/')"
                ;;
            *)
                k=0
                ;;
        esac
        total_pass=$((total_pass + p))
        total_fail=$((total_fail + f))
        total_skip=$((total_skip + k))
        if [ "$f" -eq 0 ]; then
            echo "PASS: $v ($battery_line)"
        else
            echo "FAIL: $v ($battery_line)"
            cat "$err_log" >&2 || true
        fi
    fi
    rm -f "$err_log" "$out_log" 2>/dev/null || true
done

echo "BATTERY: pass=$total_pass fail=$total_fail skip=$total_skip"
[ "$total_fail" -eq 0 ] || exit 1
