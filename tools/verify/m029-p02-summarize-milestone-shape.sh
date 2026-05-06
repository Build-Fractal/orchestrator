#!/usr/bin/env bash
# tools/verify/m029-p02-summarize-milestone-shape.sh -- M029 P02 / AD-4 helper-shape gate verifier.
#
# Asserts scripts/diagnostics/summarize-milestone.sh exists, is executable,
# declares the four canonical output keys (phase_count=, phases_complete=,
# tasks_remaining=, intensity=), carries the AD-4 / read-only / bash-3.2
# header tokens, documents both --milestone and --format flags, and emits
# the four expected keys in fixed order on stdout when run against M029.
# T03 (render-position.sh), P03 (SC-8 oracle wrapper), and T05 (phase-suite
# gate 2) all consume this helper; this verifier ensures the shape cannot
# drift silently.
#
# Bash 3.2 compatible. Straight-line, no inline compound chains, no plain
# subshells, no $() with pipes (AD-19 single-script-file shape rule for
# verifier code -- the metrics-rollup.sh MEM004 carve-out applies inside
# the helper body, not inside the verifier).

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
HELPER="$PROJECT_ROOT/scripts/diagnostics/summarize-milestone.sh"

OUT_FILE="/tmp/sm-out.$$"
trap 'rm -f "$OUT_FILE"' EXIT

pass=0
fail=0

check() {
    desc="$1"
    rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s\n' "$desc"
        fail=$((fail + 1))
    fi
}

# 1. File exists.
if [ -f "$HELPER" ]; then
    check "scripts/diagnostics/summarize-milestone.sh exists" 0
else
    printf 'FAIL: scripts/diagnostics/summarize-milestone.sh missing\n'
    fail=$((fail + 1))
    printf 'SUMMARY: m029-p02-summarize-milestone-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. File is executable.
if [ -x "$HELPER" ]; then
    check "scripts/diagnostics/summarize-milestone.sh is executable" 0
else
    check "scripts/diagnostics/summarize-milestone.sh is executable" 1
fi

# 3. The four canonical output keys are declared in the script body.
for key in 'phase_count=' 'phases_complete=' 'tasks_remaining=' 'intensity=' ; do
    if grep -F -q -- "$key" "$HELPER"; then
        check "output key declared: $key" 0
    else
        check "output key declared: $key" 1
    fi
done

# 4. AD-4 / summarize-milestone identity tokens in the header comment.
if grep -F -q -- 'AD-4' "$HELPER"; then
    check "header references AD-4" 0
else
    check "header references AD-4" 1
fi

# 5. Read-only contract token (CON-1 / FR-14 / Read-only) appears in header.
_ro=1
if grep -F -q -- 'Read-only' "$HELPER"; then _ro=0
elif grep -F -q -- 'CON-1' "$HELPER"; then _ro=0
elif grep -F -q -- 'FR-14' "$HELPER"; then _ro=0
fi
check "header declares read-only contract (Read-only / CON-1 / FR-14)" "$_ro"

# 6. Bash 3.2 token (Bash 3.2 / MEM001) appears in header.
_b32=1
if grep -F -q -- 'Bash 3.2' "$HELPER"; then _b32=0
elif grep -F -q -- 'MEM001' "$HELPER"; then _b32=0
fi
check "header declares bash 3.2 compatibility (Bash 3.2 / MEM001)" "$_b32"

# 7. Both --milestone and --format flags are documented in the help text.
if grep -F -q -- '--milestone' "$HELPER"; then
    check "flag documented: --milestone" 0
else
    check "flag documented: --milestone" 1
fi
if grep -F -q -- '--format' "$HELPER"; then
    check "flag documented: --format" 0
else
    check "flag documented: --format" 1
fi

# 8. Behavioral spot-check: invoke against M029 and verify the four keys
#    appear in fixed order on stdout. AD-19: capture to a file, then run
#    separate grep / awk invocations against the file -- no $(cmd | grep).
bash "$HELPER" --milestone M029 --format=keys > "$OUT_FILE" 2>/dev/null
_inv_rc=$?
if [ "$_inv_rc" -eq 0 ]; then
    check "behavioral: --milestone M029 --format=keys exits 0" 0
else
    check "behavioral: --milestone M029 --format=keys exits 0" 1
fi

# 8a. Each of the four keys appears as a line prefix.
if grep -E -q '^phase_count=[0-9]+$' "$OUT_FILE"; then
    check "behavioral: stdout line phase_count=<int>" 0
else
    check "behavioral: stdout line phase_count=<int>" 1
fi
if grep -E -q '^phases_complete=[0-9]+$' "$OUT_FILE"; then
    check "behavioral: stdout line phases_complete=<int>" 0
else
    check "behavioral: stdout line phases_complete=<int>" 1
fi
if grep -E -q '^tasks_remaining=[0-9]+$' "$OUT_FILE"; then
    check "behavioral: stdout line tasks_remaining=<int>" 0
else
    check "behavioral: stdout line tasks_remaining=<int>" 1
fi
if grep -E -q '^intensity=(quick|standard|full|unknown)$' "$OUT_FILE"; then
    check "behavioral: stdout line intensity=<enum>" 0
else
    check "behavioral: stdout line intensity=<enum>" 1
fi

# 8b. Fixed-order assertion: lines 1-4 must be the four keys in order.
_order_ok=1
LINE1=""
LINE2=""
LINE3=""
LINE4=""
{
    IFS= read -r LINE1 || true
    IFS= read -r LINE2 || true
    IFS= read -r LINE3 || true
    IFS= read -r LINE4 || true
} < "$OUT_FILE"
case "$LINE1" in phase_count=*) ;; *) _order_ok=0 ;; esac
case "$LINE2" in phases_complete=*) ;; *) _order_ok=0 ;; esac
case "$LINE3" in tasks_remaining=*) ;; *) _order_ok=0 ;; esac
case "$LINE4" in intensity=*) ;; *) _order_ok=0 ;; esac
if [ "$_order_ok" -eq 1 ]; then
    check "behavioral: stdout lines 1-4 in fixed order" 0
else
    check "behavioral: stdout lines 1-4 in fixed order" 1
fi

printf 'SUMMARY: m029-p02-summarize-milestone-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
