#!/usr/bin/env bash
# m043-p03-warning-matrix.sh — SC-6 (FR-10 / AD-2 fallback branch). The warning
# fires on exactly (private + github-pages) regardless of plan, carries the
# "ignore if Enterprise Cloud" note, and is silent on every other combination.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
EMIT="scripts/diagnostics/check-wiki-pages-exposure.sh"
FX="tests/fixtures/m043-p03"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

# run_emit <visibility> <fixture-subdir> -> echoes status-mode stdout
run_emit() {
  ORCH_WIKI_REPO_VISIBILITY="$1" bash "$EMIT" --mode status --root "$FX/$2" 2>/dev/null
}

# --- FIRE rows ---
out="$(run_emit private private-github-pages)"
[ -n "$out" ]; check "private + github-pages FIRES" $?
printf '%s' "$out" | grep -qi 'Enterprise Cloud'
check "fired text carries the 'ignore if Enterprise Cloud' note" $?
printf '%s' "$out" | grep -q 'cloudflare-access'
check "fired text points to the cloudflare-access target" $?

out="$(run_emit private private-default)"
[ -n "$out" ]; check "private + absent-key (default github-pages) FIRES" $?

# --- SILENT rows ---
out="$(run_emit private private-cloudflare)"
[ -z "$out" ]; check "private + cloudflare-access is SILENT" $?

out="$(run_emit public public-github-pages)"
[ -z "$out" ]; check "public + github-pages is SILENT" $?

out="$(run_emit public public-cloudflare)"
[ -z "$out" ]; check "public + cloudflare-access is SILENT" $?

# --- unknown visibility degrades to SILENT even on github-pages ---
out="$(run_emit unknown private-github-pages)"
[ -z "$out" ]; check "unknown visibility + github-pages degrades to SILENT" $?

echo "SUMMARY: m043-p03-warning-matrix.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
