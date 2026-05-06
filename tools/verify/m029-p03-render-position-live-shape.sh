#!/usr/bin/env bash
# tools/verify/m029-p03-render-position-live-shape.sh -- M029 P03 / T01
# render-position.sh --live shape gate verifier.
#
# Asserts scripts/diagnostics/render-position.sh exists, is executable,
# and that the P03/T01 --live extension is wired:
#   - the additive --live flag is parsed
#   - the POSIX tail -f primitive is used (CON-2; no inotify, no fswatch)
#   - the canonical compact savings marker `▽ saved` literal appears
#     (the only marker form #Q-G8 admits in v1)
#   - the forbidden verbose-suffix form `via tier1 cache reuse` is ABSENT
#     from the renderer body (negative-assertion verifier discipline:
#     this verifier names the literal in its own assertion strings, but
#     the deliverable body MUST NOT contain it)
#   - the AD-5 threshold knob `display_thresholds.compression_savings_pct`
#     is referenced
#   - `read-config.sh` is invoked as the threshold-knob source
#   - the spec references FR-7, FR-8, #Q-1, #Q-G8, AD-5 are present
#     so the renderer's contract is self-documenting
#
# Bash 3.2 compatible (MEM001). AD-19 single-script-file shape: straight-
# line bash, no inline compound chains, no plain subshells, no $() with
# pipes -- the MEM004 carve-out (renderer-body pipes) does NOT apply to
# verifier code, only to the renderer body itself.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
RENDERER="$PROJECT_ROOT/scripts/diagnostics/render-position.sh"

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
if [ -f "$RENDERER" ]; then
    check "render-position.sh exists" 0
else
    printf 'FAIL: render-position.sh missing at %s\n' "$RENDERER"
    fail=$((fail + 1))
    printf 'SUMMARY: m029-p03-render-position-live-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. File is executable.
if [ -x "$RENDERER" ]; then
    check "render-position.sh is executable" 0
else
    check "render-position.sh is executable" 1
fi

# 3. The --live flag is wired in the parser.
if grep -F -q -- '--live' "$RENDERER"; then
    check "--live flag wired" 0
else
    check "--live flag wired" 1
fi

# 4. POSIX `tail -f` primitive is the polling mechanism (CON-2).
if grep -F -q -- 'tail -f' "$RENDERER"; then
    check "tail -f primitive present" 0
else
    check "tail -f primitive present" 1
fi

# 5. Canonical compact-form marker `▽ saved` appears (the only marker form
#    #Q-G8 admits in v1).
if grep -F -q -- '▽ saved' "$RENDERER"; then
    check "▽ saved canonical form present" 0
else
    check "▽ saved canonical form present" 1
fi

# 6. The forbidden verbose-suffix form `via tier1 cache reuse` is ABSENT
#    from the renderer body (#Q-G8 invariant; verifier code names the
#    literal in this assertion string, but the deliverable body MUST NOT).
if grep -F -q -- 'via tier1 cache reuse' "$RENDERER"; then
    check "forbidden verbose form 'via tier1 cache reuse' absent" 1
else
    check "forbidden verbose form 'via tier1 cache reuse' absent" 0
fi

# 7. The AD-5 threshold knob `display_thresholds.compression_savings_pct`
#    is referenced (sourced via read-config.sh).
if grep -F -q -- 'display_thresholds.compression_savings_pct' "$RENDERER"; then
    check "display_thresholds.compression_savings_pct token present" 0
else
    check "display_thresholds.compression_savings_pct token present" 1
fi

# 8. The renderer invokes `read-config.sh` as the threshold-knob source.
if grep -F -q -- 'read-config.sh' "$RENDERER"; then
    check "read-config.sh invocation present" 0
else
    check "read-config.sh invocation present" 1
fi

# 9. Spec reference FR-7 (live-tail surface).
if grep -F -q -- 'FR-7' "$RENDERER"; then
    check "spec reference FR-7 present" 0
else
    check "spec reference FR-7 present" 1
fi

# 10. Spec reference FR-8 (savings marker).
if grep -F -q -- 'FR-8' "$RENDERER"; then
    check "spec reference FR-8 present" 0
else
    check "spec reference FR-8 present" 1
fi

# 11. Open question reference #Q-1 (full-re-render contract).
if grep -F -q -- '#Q-1' "$RENDERER"; then
    check "spec reference #Q-1 present" 0
else
    check "spec reference #Q-1 present" 1
fi

# 12. Open question reference #Q-G8 (canonical-form invariant).
if grep -F -q -- '#Q-G8' "$RENDERER"; then
    check "spec reference #Q-G8 present" 0
else
    check "spec reference #Q-G8 present" 1
fi

# 13. Architecture decision reference AD-5 (threshold knob authority).
if grep -F -q -- 'AD-5' "$RENDERER"; then
    check "spec reference AD-5 present" 0
else
    check "spec reference AD-5 present" 1
fi

# 14. WARN-fallback advisory wired (Principle XI fail-open on
#     read-config.sh non-zero rc / missing key / "null" sentinel).
if grep -F -q -- 'WARN: display_thresholds.compression_savings_pct fallback to default' "$RENDERER"; then
    check "WARN-fallback advisory wired" 0
else
    check "WARN-fallback advisory wired" 1
fi

printf 'SUMMARY: m029-p03-render-position-live-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
