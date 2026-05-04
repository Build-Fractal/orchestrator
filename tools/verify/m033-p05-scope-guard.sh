#!/usr/bin/env bash
# tools/verify/m033-p05-scope-guard.sh
# Bidirectional scope-guard for M033/P05: both forbidden-presence
# (out-of-scope surfaces MUST NOT be touched) and allowed-presence
# (every P05 deliverable MUST be on disk).
#
# Catches both overflow (forbidden write) and underflow (missing
# deliverable). Modeled on the P01/P02/P03/P04 scope-guard pattern.
#
# Bash 3.2 compatible (MEM001) -- no `declare -A`, no process
# substitution.

set -u
PASS=0
FAIL=0

# --- Forbidden-presence: out-of-scope surfaces MUST NOT be authored by P05 ---
# (M032 paired-launch internals, M013 internals, M015 internals, M020 schema.)
#
# DEVIATION FROM PLAN: the payload literal listed `wiki/mkdocs.yml` and
# `wiki/overrides` as forbidden-presence tokens, but those paths predate
# M033/P05 in this repo (committed by the M026 wiki publishing surface,
# d97ca0d 2026-04-28 — months before M033/P05 even started). The
# forbidden semantics is "MUST NOT have been authored by P05". We use
# the M032 paired-launch entry-point file `scripts/lifecycle/wiki-init.sh`
# as the load-bearing M032-internals presence check (per A-1 conditional-
# invocation contract: this file MUST be absent until M032/P02 closes).
FORBIDDEN="
scripts/lifecycle/wiki-init.sh
packaging/bundle/manifest.yml.M032-edit
scripts/migrate/migrate.sh.M033-edit
scripts/lifecycle/github-init.sh.M033-edit
knowledge/spec/MEM-NEW-KIND.md
"

OLDIFS="$IFS"
IFS='
'
for f in $FORBIDDEN; do
    [ -z "$f" ] && continue
    if [ -e "$f" ]; then
        FAIL=$((FAIL + 1))
        printf 'FAIL: forbidden-presence: %s exists (out-of-scope write)\n' "$f"
    else
        PASS=$((PASS + 1))
        printf 'PASS: forbidden-presence: %s absent\n' "$f"
    fi
done
IFS="$OLDIFS"

# --- Allowed-presence: every P05 deliverable MUST be on disk ---
ALLOWED="
commands/customblock-draft.md
scripts/lifecycle/customblock-draft.sh
references/customblock-format.md
scripts/lifecycle/start.sh
tests/m033-acceptance/p06-customblock-draft.sh
tests/m033-acceptance/p08-with-wiki-passthrough.sh
tests/m033-acceptance/p08-with-github-passthrough.sh
tests/m033-acceptance/run-acceptance-battery.sh
tools/verify/m033-p05-customblock-draft-md-shape.sh
tools/verify/m033-p05-customblock-draft-sh-shape.sh
tools/verify/m033-p05-customblock-format-ref-shape.sh
tools/verify/m033-p05-with-wiki-passthrough-shape.sh
tools/verify/m033-p05-with-github-passthrough-shape.sh
tools/verify/m033-p05-acceptance-shape-sc7.sh
tools/verify/m033-p05-acceptance-shape-sc9.sh
tools/verify/m033-p05-acceptance-shape-sc10.sh
tools/verify/m033-p05-acceptance-battery-shape.sh
tools/verify/m033-p05-phase-suite.sh
tools/verify/m033-p05-cross-phase-regression.sh
tools/verify/m033-p05-scope-guard.sh
tools/verify/m033-p05-validated-marker-shape.sh
tools/verify/m033-p05-summary-md-shape.sh
tools/verify/m033-p05-unit-close-jsonl-shape.sh
"

IFS='
'
for f in $ALLOWED; do
    [ -z "$f" ] && continue
    if [ -e "$f" ]; then
        PASS=$((PASS + 1))
        printf 'PASS: allowed-presence: %s exists\n' "$f"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL: allowed-presence: %s missing (P05 deliverable)\n' "$f"
    fi
done
IFS="$OLDIFS"

# --- M020 schema overreach negative-grep ---
# customblock-draft.sh must additively-extend, not over-author M020 schema
# (no new knowledge/<kind>/ directory creation, no `kind:` enum extension).
NONCOMMENT=""
if [ -f scripts/lifecycle/customblock-draft.sh ]; then
    NONCOMMENT=$(grep -Ev '^[[:space:]]*#' scripts/lifecycle/customblock-draft.sh 2>/dev/null || true)
fi
for forbidden_kind in 'mkdir.*knowledge/[a-z]*kind' 'kind:.*new'; do
    if printf '%s' "$NONCOMMENT" | grep -qE -- "$forbidden_kind"; then
        FAIL=$((FAIL + 1))
        printf 'FAIL: M020 schema overreach: %s\n' "$forbidden_kind"
    else
        PASS=$((PASS + 1))
        printf 'PASS: no M020 schema overreach: %s\n' "$forbidden_kind"
    fi
done

printf 'SUMMARY: m033-p05-scope-guard.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
