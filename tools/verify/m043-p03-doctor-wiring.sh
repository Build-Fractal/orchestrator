#!/usr/bin/env bash
# m043-p03-doctor-wiring.sh — FR-10 wiring + AD-2 no-plan-detection boundary.
# Asserts: (a) run-doctor.sh registers the emitter as an advisory sub-check;
# (b) the emitter prints a DOCTOR: line in doctor mode; (c) commands/status.md
# references the emitter; (d) the emitter contains NO plan-detection probe.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
EMIT="scripts/diagnostics/check-wiki-pages-exposure.sh"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

[ -f "$EMIT" ]; check "emitter exists" $?

# (a) run-doctor registers it, advisory (trailing "1" arg)
grep -q 'check-wiki-pages-exposure.sh' scripts/diagnostics/run-doctor.sh
check "run-doctor.sh registers the emitter" $?
grep -E 'run_check "Wiki Pages Exposure".*check-wiki-pages-exposure.sh.*"1"' scripts/diagnostics/run-doctor.sh >/dev/null
check "emitter is registered as an advisory check (trailing \"1\")" $?

# (b) doctor mode prints a DOCTOR: line (ok on a silent run)
ORCH_WIKI_REPO_VISIBILITY=public bash "$EMIT" --mode doctor --root . 2>/dev/null | grep -q '^DOCTOR: name=wiki_pages_exposure status=ok'
check "doctor mode prints DOCTOR: ... status=ok when silent" $?

# (c) status.md references it
grep -q 'check-wiki-pages-exposure.sh' commands/status.md
check "commands/status.md references the emitter (status surface)" $?

# (d) AD-2: no plan-detection logic in the emitter's EXECUTABLE lines.
# Strip full-line comments first — the emitter's own header documents that it
# has "no gh api plan probe" / "NO plan-detection logic", and those explanatory
# comment tokens must not trip this check. Match only a real plan/billing probe
# in code: a `gh api` call, a `--json plan|billing` field, or an Enterprise-plan
# parse. The legitimate `gh repo view --json visibility` (visibility != plan
# detection, AD-2) and the "GitHub Enterprise Cloud" warning text are NOT matched.
code="$(grep -v '^[[:space:]]*#' "$EMIT")"
if printf '%s\n' "$code" | grep -Eq 'gh api|--json (plan|billing)|plan_name|isEnterprise'; then p=1; else p=0; fi
[ "$p" -eq 0 ]
check "emitter executable lines contain NO plan/billing probe (AD-2)" $?

echo "SUMMARY: m043-p03-doctor-wiring.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
