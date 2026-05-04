#!/usr/bin/env bash
# tools/verify/m033-p05-acceptance-battery-shape.sh
# Asserts tests/m033-acceptance/run-acceptance-battery.sh shape.
#
# - File exists and is executable.
# - All 13 explicit-enumeration script names appear (MIT-002).
# - SC-14 skip=0 invariant: no `EXIT 77` / `exit 77` / `SKIP:` token in
#   non-comment lines (per CON-1 / MIT-001).
# - Functional run with stub-mode env vars set produces `BATTERY: pass=13
#   fail=0` and rc=0.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

BATTERY="tests/m033-acceptance/run-acceptance-battery.sh"
if [ -f "$BATTERY" ]; then
    pass "battery exists"
else
    fail "battery missing"
fi
if [ -x "$BATTERY" ]; then
    pass "battery executable"
else
    fail "battery not executable"
fi

# Token-presence shape check.
for tok in 'BATTERY:' 'BATTERY-PASS:' 'BATTERY-FAIL:' 'MIT-002' \
           'p01-start-branch-routing.sh' 'p02-constitution-author.sh' 'p03-ingest-codebase.sh' \
           'p04-materials-intake.sh' 'p04-ideation.sh' 'p05-migrate-routing.sh' \
           'p06-customblock-draft.sh' 'p07-friendly-tester-protocol.sh' \
           'p07-grilling-shell.sh' 'p07-resume-on-partial-state.sh' 'p07-observability-records.sh' \
           'p08-with-wiki-passthrough.sh' 'p08-with-github-passthrough.sh' \
           'M033_FR15_STUB' 'M033_GHINIT_STUB'; do
    if grep -qF -- "$tok" "$BATTERY"; then
        pass "token present: $tok"
    else
        fail "token absent: $tok"
    fi
done

# Negative grep: SC-14 skip=0 invariant -- NO EXIT 77 / SKIP token in
# non-comment lines. Comments document the contract (e.g., "no skip
# mechanism") and would otherwise trip a literal-token grep.
NONCOMMENT=$(grep -Ev '^[[:space:]]*#' "$BATTERY" || true)
if printf '%s' "$NONCOMMENT" | grep -qE '(EXIT 77|exit 77|SKIP:)'; then
    fail "SC-14 invariant violated: SKIP path detected"
else
    pass "no SKIP path (SC-14 skip=0 invariant)"
fi

LINES=$(wc -l < "$BATTERY")
if [ "$LINES" -ge 80 ]; then
    pass "min 80 lines (got $LINES)"
else
    fail "below 80 lines (got $LINES)"
fi

# Functional run with stub-mode env vars set.
M033_FR15_STUB=1 M033_GHINIT_STUB=1 bash "$BATTERY" > /tmp/m033-battery-out.txt 2>&1
RC=$?
if grep -qF 'BATTERY: pass=13 fail=0' /tmp/m033-battery-out.txt; then
    pass "battery emits BATTERY: pass=13 fail=0"
else
    fail "battery did not emit pass=13 fail=0 final line"
fi
if [ "$RC" -eq 0 ]; then
    pass "battery rc=0"
else
    fail "battery rc=$RC"
fi

rm -f /tmp/m033-battery-out.txt

printf 'SUMMARY: m033-p05-acceptance-battery-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
