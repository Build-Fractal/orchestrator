#!/usr/bin/env bash
# tools/verify/m044-p04-t03-capture-roundtrip.sh
# M044/P04/T03 (SC-8/SC-9): capture-by-default round-trip at Quick. An explicitly
# captured decision lands in the system-of-record DECISIONS.md, survives a rebuild,
# and is resolved by the SAME digest function build-context.sh injects with — so it
# appears in the next Quick inject's ## Decisions section.
#
# build-context.sh hardcodes PROJECT_ROOT to its own repo location (no override),
# so the live inject cannot be fixture-rooted. We therefore compose the round-trip
# through dd_decisions_digest (build-context's ACTUAL inject source, asserted wired
# in m044-p04-t02) against the fixture's DECISIONS.md. The live `## Decisions` emit
# over the real repo is covered by m044-p04-t02's live lane.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT
mkdir -p "$TD/.orchestrator" "$TD/knowledge/conventions"

# Fixture system-of-record DECISIONS.md (consumer-order header, mirrors scaffold.sh).
DEC="$TD/.orchestrator/DECISIONS.md"
printf '| # | Decision | Choice | Scope | When | Rationale | Revisable? |\n' > "$DEC"
printf '|---|----------|--------|-------|------|-----------|------------|\n' >> "$DEC"

# 1. CAPTURE at Quick via the intensity gate's explicit-decision path (FR-8/G-1).
bash scripts/knowledge/intensity-knowledge.sh --intensity Quick \
  --decision-arg "$DEC" --decision-arg M044/P04 --decision-arg arch \
  --decision-arg "Capture loop closed at Quick?" --decision-arg "Yes — fail loud" \
  --decision-arg "Silent degradation is the enemy" --decision-arg No >/dev/null 2>&1 || {
  echo "FAIL: explicit-decision capture at Quick exited non-zero"; exit 1; }

# 2. lands in DECISIONS.md, consumer-order ($5=Scope/$6=When — composes P02).
row="$(grep -E '^\|[[:space:]]*D[0-9]' "$DEC" | tail -1)"
if [ -z "$row" ]; then
  echo "FAIL: captured decision not written to DECISIONS.md"; fail=1
else
  s5="$(printf '%s' "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$5);print $5}')"
  s6="$(printf '%s' "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$6);print $6}')"
  if [ "$s5" != "arch" ] || [ "$s6" != "M044/P04" ]; then
    echo "FAIL: captured row not consumer-order (\$5='$s5' \$6='$s6')"; fail=1
  fi
fi

# 3. rebuild-index.sh is no-op-safe for the append register (proves it doesn't break).
if ! bash scripts/knowledge/rebuild-index.sh --root "$TD" >/dev/null 2>&1; then
  echo "FAIL: rebuild-index.sh errored over the fixture"; fail=1
fi
# The decision must still be on disk after the rebuild.
if ! grep -qF 'Capture loop closed at Quick?' "$DEC"; then
  echo "FAIL: captured decision lost after rebuild-index.sh"; fail=1
fi

# 4. The SAME digest function build-context injects with resolves the captured
#    decision → it appears in the next Quick inject's ## Decisions section.
. scripts/dispatch/lib/decisions-digest.sh
digest="$(dd_decisions_digest "$DEC" 2000 10)"
if ! printf '%s' "$digest" | grep -qF 'Capture loop closed at Quick?'; then
  echo "FAIL: captured decision not present in the Decisions digest (inject source)"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: capture→DECISIONS.md→rebuild→digest round-trip closed at Quick (SC-8/SC-9)"
  exit 0
fi
exit 1
