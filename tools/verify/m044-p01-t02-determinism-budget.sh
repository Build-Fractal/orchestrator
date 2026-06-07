#!/usr/bin/env bash
# tools/verify/m044-p01-t02-determinism-budget.sh
# M044/P01 (FR-5/SC-6/CON-2/CON-3): the index-free grep fallback is
# deterministic (same inputs -> byte-identical) and bounded by the M036a token
# governor (over-budget entries are dropped; the at-least-one invariant holds).
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
# shellcheck source=/dev/null
. scripts/dispatch/lib/knowledge-provenance.sh

# --- Fixture: 3 entries, each ~500 tokens (~2000 chars of body) ---
FX="$(mktemp -d)"
trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/knowledge/patterns"
PAD="$(yes x 2>/dev/null | head -2000 | tr -d '\n')"
for n in 801 802 803; do
  {
    printf -- '---\n'
    printf 'id: MEM%s\n' "$n"
    printf 'scope_tags: "[project]"\n'
    printf 'category: patterns\n'
    printf -- '---\n\n'
    printf '# MEM%s: deterministic budget fixture entry\n\n' "$n"
    printf '%s\n' "$PAD"
  } > "$FX/knowledge/patterns/MEM${n}.md"
done

# --- Determinism: two runs over the identical (index-free) corpus match byte-for-byte ---
run1="$(kp_grep_fallback "$FX/knowledge" "" 2000)"
run2="$(kp_grep_fallback "$FX/knowledge" "" 2000)"
if [ "$run1" != "$run2" ]; then
  echo "FAIL: grep fallback is non-deterministic (run1 != run2)"
  fail=1
fi

# --- Budget enforcement: a small budget admits a strict subset, in id order ---
# Each entry ~500 tokens; budget 600 admits only the first (500<=600, 1000>600).
bounded="$(kp_grep_fallback "$FX/knowledge" "" 600)"
if ! printf '%s' "$bounded" | grep -q 'MEM801'; then
  echo "FAIL: at-least-one invariant broken — MEM801 absent under tight budget"
  fail=1
fi
if printf '%s' "$bounded" | grep -q 'MEM803'; then
  echo "FAIL: budget not enforced — MEM803 present though it exceeds the 600-token budget"
  fail=1
fi

# --- Determinism under the tight budget too ---
bounded2="$(kp_grep_fallback "$FX/knowledge" "" 600)"
if [ "$bounded" != "$bounded2" ]; then
  echo "FAIL: budget-bounded fallback is non-deterministic"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: grep fallback deterministic + budget-bounded (M036a governor) + at-least-one"
  exit 0
fi
exit 1
