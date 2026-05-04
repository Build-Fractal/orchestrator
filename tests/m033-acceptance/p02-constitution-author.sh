#!/usr/bin/env bash
# tests/m033-acceptance/p02-constitution-author.sh
#
# SC-2 acceptance — exercises the FR-3 / FR-4 / FR-5 / FR-6 surface of
# scripts/lifecycle/constitution-author.sh end-to-end across the three
# v1 stacks (web-saas, cli-tool, library) under mktemp -d staging.
#
# References:
#   - SC-2 (acceptance: constitution-author across stacks)
#   - FR-3 (driver: stack-aware starter + grilling-protocol flow)
#   - FR-4 (placeholder vocabulary substitution)
#   - FR-5 (constitution-shape-lint gate)
#   - FR-6 (standalone-gate: zero speckit.* references)
#   - US-2 AS-2 (idempotent re-run without --force)
#   - US-2 AS-3 (--force regen warns about discarded edits)
#   - US-2 AS-4 (unknown stack rejected with closed-enum echo)
#
# Bash 3.2 compatible (MEM001). No declare -A, no process substitution,
# no $(...) containing pipes.
#
# Usage:
#   bash tests/m033-acceptance/p02-constitution-author.sh
#
# Output:
#   stdout per-test PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DRIVER="$PROJECT_ROOT/scripts/lifecycle/constitution-author.sh"
LINT="$PROJECT_ROOT/scripts/verify/constitution-shape-lint.sh"
GATE="$PROJECT_ROOT/scripts/verify/standalone-gate.sh"

pass=0
fail=0

check_pass() {
    pass=$((pass + 1))
    echo "PASS: $1"
}

check_fail() {
    fail=$((fail + 1))
    echo "FAIL: $1"
}

# Track all staging dirs for trap cleanup.
STAGING_LIST=""
register_staging() {
    STAGING_LIST="$STAGING_LIST $1"
}
cleanup() {
    for d in $STAGING_LIST; do
        if [ -n "$d" ] && [ -d "$d" ]; then
            rm -rf "$d"
        fi
    done
}
trap cleanup EXIT

# Sanity: driver + lint + gate must exist.
if [ ! -f "$DRIVER" ]; then
    check_fail "driver missing: $DRIVER"
    echo "SUMMARY: p02-constitution-author.sh pass=$pass fail=$fail"
    exit 1
fi
if [ ! -f "$LINT" ]; then
    check_fail "lint missing: $LINT"
    echo "SUMMARY: p02-constitution-author.sh pass=$pass fail=$fail"
    exit 1
fi
if [ ! -f "$GATE" ]; then
    check_fail "standalone-gate missing: $GATE"
    echo "SUMMARY: p02-constitution-author.sh pass=$pass fail=$fail"
    exit 1
fi

# ---------------------------------------------------------------------------
# Three-stack iteration. Parallel indexed arrays (Bash 3.2 — no declare -A).
# stack[i] -> token1[i], token2[i] (load-bearing tokens from each starter).
# ---------------------------------------------------------------------------
stacks=(web-saas cli-tool library)
tok1=("Idempotent Deploys" "Composable Default Exit Codes" "Stable API Surface")
tok2=("User Data Privacy" "POSIX Convention Adherence" "Semantic Versioning Discipline")

i=0
WEB_SAAS_STAGING=""
while [ "$i" -lt 3 ]; do
    stack="${stacks[$i]}"
    t1="${tok1[$i]}"
    t2="${tok2[$i]}"

    staging=$(mktemp -d)
    register_staging "$staging"
    if [ "$stack" = "web-saas" ]; then
        WEB_SAAS_STAGING="$staging"
    fi
    mkdir -p "$staging/.orchestrator"

    # Drive constitution-author with 8 'y' answers (covers the worst-case
    # 5-8 question count in the FR-3 grilling-protocol flow).
    rc=0
    printf 'y\ny\ny\ny\ny\ny\ny\ny\n' \
        | EDITOR=cat bash "$DRIVER" --stack "$stack" --project-dir "$staging" --yes \
        > "$staging/.driver.stdout" 2> "$staging/.driver.stderr" || rc=$?

    if [ "$rc" -eq 0 ]; then
        check_pass "[$stack] driver exited 0"
    else
        check_fail "[$stack] driver exited $rc"
    fi

    constitution="$staging/.orchestrator/memory/constitution.md"
    if [ -f "$constitution" ]; then
        check_pass "[$stack] constitution.md authored at $constitution"
    else
        check_fail "[$stack] constitution.md missing at $constitution"
        i=$((i + 1))
        continue
    fi

    # Stack-specific tokens.
    if grep -F -q "$t1" "$constitution"; then
        check_pass "[$stack] constitution carries '$t1'"
    else
        check_fail "[$stack] constitution missing '$t1'"
    fi
    if grep -F -q "$t2" "$constitution"; then
        check_pass "[$stack] constitution carries '$t2'"
    else
        check_fail "[$stack] constitution missing '$t2'"
    fi

    # Zero literal {{ placeholders remain (FR-4 substitution).
    placeholder_count=$(grep -cF '{{' "$constitution" || true)
    if [ "$placeholder_count" = "0" ]; then
        check_pass "[$stack] zero {{ placeholder strings remain"
    else
        check_fail "[$stack] $placeholder_count {{ placeholder strings remain"
    fi

    # Constitution-shape-lint passes (FR-5).
    if bash "$LINT" "$constitution" >/dev/null 2>&1; then
        check_pass "[$stack] constitution-shape-lint.sh exits 0"
    else
        check_fail "[$stack] constitution-shape-lint.sh failed"
    fi

    # FR-20 marker file present.
    marker="$staging/.orchestrator/start-state/constitution-authored.complete"
    if [ -f "$marker" ]; then
        check_pass "[$stack] FR-20 marker present at start-state/constitution-authored.complete"
    else
        check_fail "[$stack] FR-20 marker missing at $marker"
    fi

    # FR-22 JSONL event emitted.
    log="$staging/.orchestrator/execution-log.jsonl"
    if [ -f "$log" ]; then
        if grep -F -q 'constitution_authored' "$log"; then
            check_pass "[$stack] FR-22 event 'constitution_authored' present in execution-log.jsonl"
        else
            check_fail "[$stack] FR-22 event 'constitution_authored' missing in execution-log.jsonl"
        fi
    else
        check_fail "[$stack] FR-22 execution-log.jsonl missing at $log"
    fi

    i=$((i + 1))
done

# ---------------------------------------------------------------------------
# Idempotency assertion (US-2 AS-2). Re-run web-saas without --force —
# expect 'no changes' and identical mtime preservation.
# ---------------------------------------------------------------------------
if [ -n "$WEB_SAAS_STAGING" ] && [ -d "$WEB_SAAS_STAGING" ]; then
    constitution="$WEB_SAAS_STAGING/.orchestrator/memory/constitution.md"

    # Capture mtime before re-run. Detect stat shape (darwin vs linux).
    pre_mtime=""
    if stat -f %m "$constitution" >/dev/null 2>&1; then
        pre_mtime=$(stat -f %m "$constitution")
    elif stat -c %Y "$constitution" >/dev/null 2>&1; then
        pre_mtime=$(stat -c %Y "$constitution")
    fi

    rerun_out="$WEB_SAAS_STAGING/.rerun.stdout"
    rerun_err="$WEB_SAAS_STAGING/.rerun.stderr"
    rc=0
    printf 'y\ny\ny\ny\ny\ny\ny\ny\n' \
        | EDITOR=cat bash "$DRIVER" --stack web-saas --project-dir "$WEB_SAAS_STAGING" --yes \
        > "$rerun_out" 2> "$rerun_err" || rc=$?

    if [ "$rc" -eq 0 ]; then
        check_pass "[idempotency] re-run without --force exited 0"
    else
        check_fail "[idempotency] re-run without --force exited $rc"
    fi

    if grep -F -q 'no changes' "$rerun_out"; then
        check_pass "[idempotency] re-run stdout contains 'no changes'"
    else
        check_fail "[idempotency] re-run stdout missing 'no changes'"
    fi

    post_mtime=""
    if stat -f %m "$constitution" >/dev/null 2>&1; then
        post_mtime=$(stat -f %m "$constitution")
    elif stat -c %Y "$constitution" >/dev/null 2>&1; then
        post_mtime=$(stat -c %Y "$constitution")
    fi

    if [ -n "$pre_mtime" ] && [ "$pre_mtime" = "$post_mtime" ]; then
        check_pass "[idempotency] mtime preserved (pre=$pre_mtime, post=$post_mtime)"
    else
        check_fail "[idempotency] mtime drifted (pre=$pre_mtime, post=$post_mtime)"
    fi

    # ---------------------------------------------------------------------
    # --force regen assertion (US-2 AS-3). Warning to stderr names --force.
    # ---------------------------------------------------------------------
    force_out="$WEB_SAAS_STAGING/.force.stdout"
    force_err="$WEB_SAAS_STAGING/.force.stderr"
    rc=0
    printf 'y\ny\ny\ny\ny\ny\ny\ny\n' \
        | EDITOR=cat bash "$DRIVER" --stack web-saas --project-dir "$WEB_SAAS_STAGING" --yes --force \
        > "$force_out" 2> "$force_err" || rc=$?

    if [ "$rc" -eq 0 ]; then
        check_pass "[force] --force re-run exited 0"
    else
        check_fail "[force] --force re-run exited $rc"
    fi

    # Stderr carries WARN about discarded edits referencing --force.
    if grep -F -q 'WARN' "$force_err"; then
        if grep -F -q -- '--force' "$force_err"; then
            check_pass "[force] stderr WARN names --force discarding prior edits"
        else
            check_fail "[force] stderr WARN missing --force token"
        fi
    else
        check_fail "[force] stderr missing WARN about discarded edits"
    fi
else
    check_fail "[idempotency] web-saas staging not preserved for re-run assertion"
fi

# ---------------------------------------------------------------------------
# Unknown-stack assertion (US-2 AS-4). Closed-enum rejection echoes the
# v1 list AND references the #Q-2 expansion path.
# ---------------------------------------------------------------------------
unk_staging=$(mktemp -d)
register_staging "$unk_staging"
mkdir -p "$unk_staging/.orchestrator"
unk_out="$unk_staging/.unk.stdout"
unk_err="$unk_staging/.unk.stderr"
rc=0
bash "$DRIVER" --stack quantum-mainframe --project-dir "$unk_staging" --yes \
    > "$unk_out" 2> "$unk_err" || rc=$?

if [ "$rc" -ne 0 ]; then
    check_pass "[unknown-stack] exits non-zero (rc=$rc)"
else
    check_fail "[unknown-stack] expected non-zero, got 0"
fi

if grep -F -q 'web-saas' "$unk_err"; then
    check_pass "[unknown-stack] stderr names 'web-saas' (closed-enum echo)"
else
    check_fail "[unknown-stack] stderr missing 'web-saas'"
fi
if grep -F -q 'cli-tool' "$unk_err"; then
    check_pass "[unknown-stack] stderr names 'cli-tool' (closed-enum echo)"
else
    check_fail "[unknown-stack] stderr missing 'cli-tool'"
fi
if grep -F -q 'library' "$unk_err"; then
    check_pass "[unknown-stack] stderr names 'library' (closed-enum echo)"
else
    check_fail "[unknown-stack] stderr missing 'library'"
fi
if grep -F -q '#Q-2' "$unk_err"; then
    check_pass "[unknown-stack] stderr names '#Q-2' expansion-path reference"
else
    check_fail "[unknown-stack] stderr missing '#Q-2' expansion-path reference"
fi

# ---------------------------------------------------------------------------
# Standalone-gate assertion (FR-6 / CON-3 / Principle XVI). Zero
# speckit.* references in the M033-shipped constitution surface.
# ---------------------------------------------------------------------------
gate_out=$(mktemp)
register_staging "$gate_out"
rc=0
bash "$GATE" constitution > "$gate_out" 2>&1 || rc=$?

if [ "$rc" -eq 0 ]; then
    check_pass "[standalone-gate] standalone-gate.sh constitution exited 0"
else
    check_fail "[standalone-gate] standalone-gate.sh constitution exited $rc"
fi
if grep -F -q 'PASS:' "$gate_out"; then
    check_pass "[standalone-gate] stdout contains 'PASS:' (zero speckit.* references)"
else
    check_fail "[standalone-gate] stdout missing 'PASS:' line"
fi

# ---------------------------------------------------------------------------
# Final summary.
# ---------------------------------------------------------------------------
echo ""
echo "SUMMARY: p02-constitution-author.sh pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
