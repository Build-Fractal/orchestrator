#!/usr/bin/env bash
# tools/verify/m044-p04-t01-capture-at-quick.sh
# M044/P04/T01 (FR-8/G-1/SC-8): an explicitly-supplied decision runs append-decision.sh
# at Quick intensity; the no-explicit-decision auto-pipeline is unchanged.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
IK="scripts/knowledge/intensity-knowledge.sh"

# 1. Quick dry-run, NO decision → exactly write-summary, NO append-decision (m008 guard).
out_none="$(bash "$IK" --intensity Quick --dry-run 2>/dev/null)"
if ! printf '%s' "$out_none" | grep -q 'write-summary.sh'; then
  echo "FAIL: Quick (no decision) did not plan write-summary.sh"
  fail=1
fi
if printf '%s' "$out_none" | grep -q 'append-decision.sh'; then
  echo "FAIL: Quick (no decision) planned append-decision.sh — auto-pipeline regressed"
  fail=1
fi

# 2. Quick dry-run WITH explicit decision → plans append-decision.sh.
out_dec="$(bash "$IK" --intensity Quick --dry-run \
  --decision-arg /tmp/x.md --decision-arg M044/P04 --decision-arg arch \
  --decision-arg "Q?" --decision-arg "C" --decision-arg "why" 2>/dev/null)"
if ! printf '%s' "$out_dec" | grep -q 'append-decision.sh'; then
  echo "FAIL: Quick (with --decision-arg) did not plan append-decision.sh"
  fail=1
fi

# 3. Quick LIVE explicit decision → row appended in consumer-order ($5=Scope/$6=When).
TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT
DEC="$TD/DECISIONS.md"
printf '| # | Decision | Choice | Scope | When | Rationale | Revisable? |\n' > "$DEC"
printf '|---|----------|--------|-------|------|-----------|------------|\n' >> "$DEC"
bash "$IK" --intensity Quick \
  --decision-arg "$DEC" --decision-arg M044/P04 --decision-arg arch \
  --decision-arg "Capture at Quick?" --decision-arg "Yes, always" \
  --decision-arg "Fail loud" --decision-arg No >/dev/null 2>&1 || {
  echo "FAIL: live Quick explicit-decision capture exited non-zero"
  exit 1
}
row="$(grep -E '^\|[[:space:]]*D[0-9]' "$DEC" | tail -1)"
if [ -z "$row" ]; then
  echo "FAIL: no decision row appended at Quick"
  fail=1
else
  s5="$(printf '%s' "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$5);print $5}')"
  s6="$(printf '%s' "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$6);print $6}')"
  if [ "$s5" != "arch" ] || [ "$s6" != "M044/P04" ]; then
    echo "FAIL: captured row not consumer-order (\$5='$s5' \$6='$s6'). Row: $row"
    fail=1
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: explicit decision captured at Quick; auto-pipeline unchanged without it"
  exit 0
fi
exit 1
