#!/usr/bin/env bash
# tools/verify/m035-p06-phase-suite.sh
# M035 P06 — phase-suite aggregator.
# Chains every P06 per-truth verifier; emits BATTERY rollup that sums
# each verifier's own pass/fail/skip counts.
#
# Mirrors the m035-p05-phase-suite.sh summing-counters form so
# consolidate-time grep aggregation is consistent with the rest of the
# milestone batteries. Each P06 verifier ships heterogeneous BATTERY
# counts (T01 pass=7 / T02 pass=13 / T03 pass=12 / T04 pass=12 / T05
# pass=16 / T06 pass=9), so summing per-verifier counters is the right
# rollup shape.
set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
cd "$REPO_ROOT"

total_pass=0
total_fail=0
total_skip=0

# Verifier list — milestone-prefixed slug per AD-19 naming.
# Order: T01 → T05 task-grain + T06 milestone-close-shape.
VERIFIERS=(
    "tools/verify/m035-p06-config-schema-shape.sh"
    "tools/verify/m035-p06-multi-source-dispatch-shape.sh"
    "tools/verify/m035-p06-update-run-jsonl-emission-shape.sh"
    "tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh"
    "tools/verify/m035-p06-acceptance-battery-shape.sh"
    "tools/verify/m035-p06-milestone-close-shape.sh"
)

for v in "${VERIFIERS[@]}"; do
    if [ ! -x "$v" ] && [ ! -f "$v" ]; then
        echo "SKIP: verifier not found: $v"
        total_skip=$((total_skip + 1))
        continue
    fi
    err_log="$(mktemp -t m035-p06-suite.XXXXXX)"
    out_log="$(mktemp -t m035-p06-suite-out.XXXXXX)"
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
        case "$p" in ''|*[!0-9]*) p=0 ;; esac
        case "$f" in ''|*[!0-9]*) f=0 ;; esac
        case "$k" in ''|*[!0-9]*) k=0 ;; esac
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
