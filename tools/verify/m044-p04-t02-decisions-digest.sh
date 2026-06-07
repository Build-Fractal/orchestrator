#!/usr/bin/env bash
# tools/verify/m044-p04-t02-decisions-digest.sh
# M044/P04/T02 (FR-6/SC-8/CON-2/CON-3): the Quick inject carries a bounded,
# budget-bounded, deterministic Decisions digest. Lib-level fixture tests +
# integration-wiring greps + a live build-context assertion.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
LIB="scripts/dispatch/lib/decisions-digest.sh"
BC="scripts/dispatch/build-context.sh"

if [ ! -f "$LIB" ]; then
  echo "FAIL: $LIB not found"
  exit 1
fi
# shellcheck source=/dev/null
. "$LIB"

# --- Lib-level fixture tests ---
TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT
DEC="$TD/DECISIONS.md"
printf '| # | Decision | Choice | Scope | When | Rationale | Revisable? |\n' > "$DEC"
printf '|---|----------|--------|-------|------|-----------|------------|\n' >> "$DEC"
printf '| D001 | First decision | choice A | arch | M044/P01 | because | No |\n' >> "$DEC"
printf '| D002 | Second decision | choice B | pattern | M044/P02 | reasons | Yes |\n' >> "$DEC"

dig="$(dd_decisions_digest "$DEC" 2000 10)"
# Both rows present, newest-first (D002 before D001).
if ! printf '%s' "$dig" | grep -qF 'D002 | Second decision'; then
  echo "FAIL: digest missing D002"; fail=1
fi
if ! printf '%s' "$dig" | grep -qF 'D001 | First decision'; then
  echo "FAIL: digest missing D001"; fail=1
fi
first_id="$(printf '%s\n' "$dig" | grep -oE 'D00[0-9]' | head -1)"
if [ "$first_id" != "D002" ]; then
  echo "FAIL: digest not newest-first (first id='$first_id', expected D002)"; fail=1
fi

# Determinism (CON-3): two runs byte-identical.
a="$(dd_decisions_digest "$DEC" 2000 10)"
b="$(dd_decisions_digest "$DEC" 2000 10)"
if [ "$a" != "$b" ]; then
  echo "FAIL: digest not deterministic across identical runs"; fail=1
fi

# Budget (CON-2): a tiny budget still emits exactly one row (governor at-least-one).
tiny="$(dd_decisions_digest "$DEC" 1 10)"
tiny_rows="$(printf '%s\n' "$tiny" | grep -cE '^\|[[:space:]]*D[0-9]')"
if [ "$tiny_rows" -ne 1 ]; then
  echo "FAIL: tiny-budget digest emitted $tiny_rows rows (expected 1 — governor at-least-one)"; fail=1
fi

# Empty corpus → nothing.
printf '| # | Decision |\n' > "$TD/empty.md"
empty="$(dd_decisions_digest "$TD/empty.md" 2000 10)"
if [ -n "$empty" ]; then
  echo "FAIL: digest over a row-less file emitted output: [$empty]"; fail=1
fi

# --- Integration-wiring greps ---
if ! grep -q 'decisions-digest.sh' "$BC"; then
  echo "FAIL: build-context.sh does not source decisions-digest.sh"; fail=1
fi
if ! grep -q 'dd_decisions_digest' "$BC"; then
  echo "FAIL: build-context.sh does not call dd_decisions_digest"; fail=1
fi
# The `## Decisions` section is no longer omitted under the Quick profile.
if grep -q 'if \[ "\$PROFILE" != "quick" \]; then' "$BC" && grep -A1 'if \[ "\$PROFILE" != "quick" \]; then' "$BC" | grep -q '## Decisions'; then
  echo "FAIL: build-context.sh still gates the ## Decisions block behind != quick"; fail=1
fi
if ! grep -qF 'reference_apply_budget' "$LIB"; then
  echo "FAIL: decisions-digest.sh does not route through the M036a governor"; fail=1
fi

# --- Live assertion: real build-context --profile quick emits ## Decisions ---
OUT="$(mktemp)"
bash "$BC" --task-plan "$BC" --profile quick --out "$OUT" >/dev/null 2>&1 || true
if ! grep -q '^## Decisions' "$OUT"; then
  echo "FAIL: live Quick payload missing ## Decisions section"; fail=1
fi
if grep -qF 'decisions section assembled by full-mode positional flow' "$OUT"; then
  echo "FAIL: live Quick payload still carries the old marker, not a digest"; fail=1
fi
rm -f "$OUT"

if [ "$fail" -eq 0 ]; then
  echo "PASS: bounded, budget-bounded, deterministic Decisions digest emitted at Quick"
  exit 0
fi
exit 1
