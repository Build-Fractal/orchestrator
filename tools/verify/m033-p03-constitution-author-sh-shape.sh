#!/usr/bin/env bash
# m033-p03-constitution-author-sh-shape.sh
#
# T02 verifier: shape + functional smoke for
# scripts/lifecycle/constitution-author.sh (FR-3).
#
# Asserts:
#   - Script exists and is executable.
#   - Body contains the load-bearing tokens via `grep -F`.
#   - Standalone-gate dogfood: `bash scripts/verify/standalone-gate.sh
#     constitution` exits 0 against the M033 working tree (T02's
#     surfaces present; no speckit matches).
#   - Negative grep: zero literal `speckit` matches in
#     `commands/constitution.md` AND `scripts/lifecycle/constitution-author.sh`.
#
# Bash 3.2 compatible (MEM001). Single-script invocation shape (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/lifecycle/constitution-author.sh"
cmd_md="$PROJECT_ROOT/commands/constitution.md"
gate="$PROJECT_ROOT/scripts/verify/standalone-gate.sh"

pass=0
fail=0

if [ -f "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: constitution-author.sh exists at $target"
else
    fail=$((fail + 1))
    echo "FAIL: constitution-author.sh missing at $target" >&2
    echo "SUMMARY: m033-p03-constitution-author-sh-shape.sh pass=$pass fail=$fail"
    exit 1
fi

if [ -x "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: constitution-author.sh executable"
else
    fail=$((fail + 1))
    echo "FAIL: constitution-author.sh not executable" >&2
fi

# Load-bearing tokens (per T02 plan).
for tok in \
    "--stack" \
    "--project-dir" \
    "--force" \
    "--yes" \
    "web-saas" \
    "cli-tool" \
    "library" \
    "templates/constitution-starters" \
    "grilling-shell.sh" \
    "ask_one" \
    "constitution-shape-lint.sh" \
    "EDITOR" \
    ".orchestrator/memory/constitution.md" \
    "start-state-markers.sh" \
    "constitution-authored" \
    "jsonl-event-emitter.sh" \
    "constitution_authored" \
    "dual-write-runtime-md.sh" \
    "036-project-onboarding-experience"
do
    if grep -F -q -- "$tok" "$target"; then
        pass=$((pass + 1))
        echo "PASS: token present: $tok"
    else
        fail=$((fail + 1))
        echo "FAIL: token missing: $tok" >&2
    fi
done

# --- Standalone-gate dogfood: invoke with both T02 surfaces in place.
gate_out=""
gate_out="$(mktemp 2>/dev/null || mktemp -t std-gate-out)"
gate_err=""
gate_err="$(mktemp 2>/dev/null || mktemp -t std-gate-err)"
bash "$gate" constitution >"$gate_out" 2>"$gate_err"
gate_rc=$?

if [ "$gate_rc" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS: standalone-gate.sh constitution exits 0"
else
    fail=$((fail + 1))
    echo "FAIL: standalone-gate.sh constitution exited $gate_rc" >&2
    cat "$gate_err" >&2
fi

# Assert SKIP=0 in the gate's SUMMARY (T02 closes co-authored-not-yet-landed).
if grep -E -q 'SUMMARY: standalone-gate\.sh.*skip=0' "$gate_out"; then
    pass=$((pass + 1))
    echo "PASS: standalone-gate skip=0 (no co-authored-not-yet-landed surfaces)"
else
    fail=$((fail + 1))
    echo "FAIL: standalone-gate did NOT report skip=0" >&2
    cat "$gate_out" >&2
fi

if grep -F -q "FAIL:" "$gate_err"; then
    fail=$((fail + 1))
    echo "FAIL: standalone-gate emitted FAIL: lines (speckit reference detected)" >&2
else
    pass=$((pass + 1))
    echo "PASS: standalone-gate emitted no FAIL: lines"
fi

rm -f "$gate_out" "$gate_err"

# --- Negative grep: zero `speckit` matches case-insensitively.
md_count=0
md_count=$(grep -ic 'speckit' "$cmd_md" || true)
if [ "$md_count" = "0" ]; then
    pass=$((pass + 1))
    echo "PASS: zero case-insensitive speckit matches in commands/constitution.md"
else
    fail=$((fail + 1))
    echo "FAIL: $md_count case-insensitive speckit matches in commands/constitution.md" >&2
fi

sh_count=0
sh_count=$(grep -ic 'speckit' "$target" || true)
if [ "$sh_count" = "0" ]; then
    pass=$((pass + 1))
    echo "PASS: zero case-insensitive speckit matches in scripts/lifecycle/constitution-author.sh"
else
    fail=$((fail + 1))
    echo "FAIL: $sh_count case-insensitive speckit matches in scripts/lifecycle/constitution-author.sh" >&2
fi

echo "SUMMARY: m033-p03-constitution-author-sh-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
