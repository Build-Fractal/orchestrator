#!/usr/bin/env bash
# tools/verify/m044-p02-t03-roundtrip-oracle.sh
# M044/P02/T03 — AC-1 acceptance oracle (SC-1/SC-7). The capture→resolve
# round-trip proves the producer (append-decision.sh / append-knowledge.sh) writes
# exactly what the consumer (filter_decisions / filter_knowledge) reads.
#   - Dynamic decision lane: runtime-appended row resolves; awk $5/$6 = Scope/When.
#   - Dynamic knowledge lane: a flat ## K### entry + an append-knowledge bullet
#     resolve in-scope; an out-of-scope entry is excluded.
#   - Static byte-equality lane: frozen fixture → filter_decisions byte-equals the
#     frozen golden output (no runtime append into a frozen file).
#   - SC-7: a flat ## K### entry passes kf_filter_stream (no "(no qualifying...)").
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

FIX=".orchestrator/milestones/M044/phases/P02/fixtures"
fail=0
TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT

# ---------------------------------------------------------------------------
# Lane 1 — DYNAMIC decision round-trip (capture → resolve → byte-assert $5/$6).
# ---------------------------------------------------------------------------
DEC="$TD/DECISIONS.md"
printf '| # | Decision | Choice | Scope | When | Rationale | Revisable? |\n' > "$DEC"
printf '|---|----------|--------|-------|------|-----------|------------|\n' >> "$DEC"
bash scripts/knowledge/append-decision.sh "$DEC" "M044/P01" "arch" \
  "Index demoted to cache?" "Grep is the guarantee" "Fail loud" "No" >/dev/null 2>&1 || {
  echo "FAIL: append-decision.sh failed"; exit 1; }

resolved="$(bash scripts/dispatch/scope-filter.sh "$DEC" "M044/P01" --type decisions 2>/dev/null)"
row="$(printf '%s\n' "$resolved" | grep -E '^\|[[:space:]]*D[0-9]')"
if [ -z "$row" ]; then
  echo "FAIL: captured decision did not resolve through filter_decisions"
  fail=1
else
  d5="$(printf '%s\n' "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$5);print $5}')"
  d6="$(printf '%s\n' "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$6);print $6}')"
  if [ "$d5" != "arch" ]; then
    echo "FAIL: round-trip awk \$5='$d5' (expected Scope='arch')"; fail=1
  fi
  if [ "$d6" != "M044/P01" ]; then
    echo "FAIL: round-trip awk \$6='$d6' (expected When='M044/P01')"; fail=1
  fi
fi

# ---------------------------------------------------------------------------
# Lane 2 — DYNAMIC knowledge round-trip (flat ## K### + append-knowledge bullet).
# ---------------------------------------------------------------------------
KF="$TD/KNOWLEDGE.md"
cp "$FIX/knowledge-flat.md" "$KF"
bash scripts/knowledge/append-knowledge.sh "$KF" "Ambient grep note" "milestone:M044" >/dev/null 2>&1 || {
  echo "FAIL: append-knowledge.sh failed"; exit 1; }
kout="$(bash scripts/dispatch/scope-filter.sh "$KF" "M044/P02" --type knowledge 2>/dev/null)"
if ! printf '%s' "$kout" | grep -qF '## K001: Index is a cache'; then
  echo "FAIL: flat ## K001 [milestone:M044] not resolved for M044"; fail=1
fi
if ! printf '%s' "$kout" | grep -qF '## K003: Project-wide convention'; then
  echo "FAIL: [project] ## K003 not resolved project-wide"; fail=1
fi
if ! printf '%s' "$kout" | grep -qF 'Ambient grep note'; then
  echo "FAIL: append-knowledge [milestone:M044] bullet not resolved"; fail=1
fi
if printf '%s' "$kout" | grep -qF '## K002: Out-of-scope'; then
  echo "FAIL: out-of-scope ## K002 [milestone:M099] leaked into M044 resolve"; fail=1
fi

# ---------------------------------------------------------------------------
# Lane 3 — STATIC byte-equality (frozen fixture → frozen golden output).
# ---------------------------------------------------------------------------
static_out="$(bash scripts/dispatch/scope-filter.sh "$FIX/decisions-consumer-order.md" "M044/P01" --type decisions 2>/dev/null)"
expected="$(cat "$FIX/decisions-M044-P01.expected.txt")"
if [ "$static_out" != "$expected" ]; then
  echo "FAIL: static filter_decisions output drifted from golden fixture"
  printf '  --- got ---\n%s\n  --- expected ---\n%s\n' "$static_out" "$expected"
  fail=1
fi

# ---------------------------------------------------------------------------
# Lane 4 — SC-7: flat ## K### passes kf_filter_stream (no sentinel nulling).
# ---------------------------------------------------------------------------
source scripts/lib/knowledge-filter.sh
DL="$TD/dl.txt"; ST="$TD/st.txt"
printf 'superseded\n' > "$DL"
sc7_out="$(printf -- '## K001: Flat survives [project]\nbody\n' | kf_filter_stream "$DL" "$ST")"
if ! printf '%s' "$sc7_out" | grep -qF '## K001: Flat survives [project]'; then
  echo "FAIL: SC-7 flat entry did not pass kf_filter_stream"; fail=1
fi
if printf '%s' "$sc7_out" | grep -qF '(no qualifying knowledge entries)'; then
  echo "FAIL: SC-7 flat entry nulled to the no-qualifying sentinel"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: round-trip oracle — dynamic decision+knowledge lanes, static byte-equality, SC-7 flat passes"
  exit 0
fi
exit 1
