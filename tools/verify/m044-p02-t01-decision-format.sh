#!/usr/bin/env bash
# tools/verify/m044-p02-t01-decision-format.sh
# M044/P02/T01 (FR-1/SC-1/CON-6/#Q-1): the producer (append-decision.sh) and the
# init-time header (scaffold.sh) emit canonical consumer-order so that the
# consumer's `awk -F'|'` $5=Scope / $6=When indices land on the intended fields.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
APPEND="scripts/knowledge/append-decision.sh"
SCAFFOLD="scripts/lifecycle/scaffold.sh"
SCOPE_FILTER="scripts/dispatch/scope-filter.sh"

# 1. append-decision.sh emits a row whose awk $5=Scope-arg and $6=When-arg.
TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT
DEC="$TD/DECISIONS.md"
printf '| # | Decision | Choice | Scope | When | Rationale | Revisable? |\n' > "$DEC"
printf '|---|----------|--------|-------|------|-----------|------------|\n' >> "$DEC"

WHEN="M044/P01"
SCOPE="arch"
bash "$APPEND" "$DEC" "$WHEN" "$SCOPE" "State derivation?" "File-presence" "Crash recovery" "No" >/dev/null 2>&1 || {
  echo "FAIL: append-decision.sh exited non-zero"
  exit 1
}

row="$(grep -E '^\|[[:space:]]*D[0-9]' "$DEC" | tail -1)"
f5="$(printf '%s\n' "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5); print $5}')"
f6="$(printf '%s\n' "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $6); print $6}')"
if [ "$f5" != "$SCOPE" ]; then
  echo "FAIL: producer row awk \$5='$f5' (expected Scope='$SCOPE'). Row: $row"
  fail=1
fi
if [ "$f6" != "$WHEN" ]; then
  echo "FAIL: producer row awk \$6='$f6' (expected When='$WHEN'). Row: $row"
  fail=1
fi

# 2. scaffold.sh init header is canonical consumer-order.
if ! grep -qF '| # | Decision | Choice | Scope | When | Rationale | Revisable? |' "$SCAFFOLD"; then
  echo "FAIL: scaffold.sh init header is not canonical consumer-order"
  fail=1
fi
# No stale producer-order header survives.
if grep -qF '| # | When | Scope | Decision | Choice | Rationale | Revisable? |' "$SCAFFOLD"; then
  echo "FAIL: scaffold.sh still carries a producer-order header"
  fail=1
fi

# 3. scope-filter.sh awk still reads $5 (scope) / $6 (when) — unchanged.
if ! grep -q 'gsub(/\^\[\[:space:\]\]+|\[\[:space:\]\]+\$/, "", \$5)' "$SCOPE_FILTER"; then
  # Looser check: the awk references $5 and $6 for scope/when extraction.
  if ! grep -qF 'print $5' "$SCOPE_FILTER" || ! grep -qF 'print $6' "$SCOPE_FILTER"; then
    echo "FAIL: scope-filter.sh awk no longer reads \$5/\$6"
    fail=1
  fi
fi

# 4. No producer-order row shape survives in append-decision.sh's echo.
if grep -qF 'echo "| $next_id | $WHEN | $SCOPE | $DECISION | $CHOICE' "$APPEND"; then
  echo "FAIL: append-decision.sh still emits producer-order"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: producer + init-header emit canonical consumer-order; awk \$5=Scope/\$6=When holds"
  exit 0
fi
exit 1
