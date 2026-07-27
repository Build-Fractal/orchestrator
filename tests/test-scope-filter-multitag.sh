#!/usr/bin/env bash
# tests/test-scope-filter-multitag.sh — knowledge-activation regression
#
# Bug: scope-filter.sh compared the ENTIRE field-2 scope string against a single
# tag value (`[[ "$scope_tag" = "[project]" ]]`, `grep -qE '^\[milestone:'`).
# An entry bearing more than one tag — the shape rebuild-index.sh actually
# writes, e.g. `[project], [milestone:M005]` — matched no branch and fell
# through to `include=false`. 22 of this repo's 31 MEMs carry that shape, so the
# flat (no-SQLite) path silently dropped 71% of the corpus.
#
# It failed silently by construction: the index was present and non-empty, so
# build-context.sh's grep-fallback never fired and no degradation warning was
# emitted. `knowledge.db` is gitignored, so every fresh clone took the flat path.
#
# Fix: `_sf_scope_field_includes` splits the field into bracketed tokens and
# includes the entry when ANY token is in scope. `_sf_tag_includes` (flat
# KNOWLEDGE.md path) and `filter_knowledge_index` (index path) now share it —
# previously each carried its own divergent copy of the rule.
#
# Asserts, on a synthetic index:
#   1. multi-tag entries whose FIRST tag matches are included
#   2. multi-tag entries whose SECOND tag matches are included
#   3. single-tag out-of-scope entries are still EXCLUDED (no blanket-include)
#   4. multi-tag entries where NO tag matches are still EXCLUDED
#   5. an unrecognised namespace alone (`[concern:...]`) is not in scope
#   6. --depends widening still reaches sibling phases
#   7. --tag literal mode is unaffected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCOPE_FILTER="$PROJECT_ROOT/scripts/dispatch/scope-filter.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

TMPDIR_FX="$(mktemp -d -t scope-filter-multitag.XXXXXX)"
trap 'rm -rf "$TMPDIR_FX"' EXIT

IDX="$TMPDIR_FX/KNOWLEDGE-INDEX.md"
cat >"$IDX" <<'INDEX'
# Knowledge Index
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
MEM001 | [project] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:0 | bare project tag
MEM002 | [project], [milestone:M005] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:0 | multi-tag, project first
MEM003 | [milestone:M005] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:0 | other milestone only
MEM004 | [milestone:M046] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:0 | this milestone only
MEM005 | [phase:M046/P03] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:0 | this phase
MEM006 | [phase:M046/P99] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:0 | sibling phase
MEM007 | [concern:bash-compat] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:0 | orphan namespace alone
MEM008 | [milestone:M005], [concern:bash-compat] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:0 | no tag in scope
MEM009 | [phase:M005/P01], [milestone:M046] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:0 | multi-tag, match is second
INDEX

ids_for() {
  bash "$SCOPE_FILTER" "$IDX" "$@" | grep -oE '^MEM[0-9]+' | tr '\n' ' ' | sed 's/ $//'
}

# --- Baseline scope: M046/P03, no depends ---
GOT="$(ids_for M046/P03 --type knowledge)"
WANT="MEM001 MEM002 MEM004 MEM005 MEM009"
if [ "$GOT" = "$WANT" ]; then
  pass "multi-tag scope match → expected inclusion set"
else
  fail "multi-tag scope match → want [$WANT], got [$GOT]"
fi

# Targeted assertions so a regression names the specific broken rule.
case " $GOT " in
  *" MEM002 "*) pass "multi-tag entry included when FIRST tag matches ([project], [milestone:M005])" ;;
  *)            fail "multi-tag entry with matching FIRST tag was dropped (the 71%-corpus-loss bug)" ;;
esac

case " $GOT " in
  *" MEM009 "*) pass "multi-tag entry included when SECOND tag matches ([phase:M005/P01], [milestone:M046])" ;;
  *)            fail "multi-tag ANY-token semantics not applied to non-leading tag" ;;
esac

# Negative controls — a filter that includes everything is the same defect.
for excluded in MEM003 MEM006 MEM007 MEM008; do
  case " $GOT " in
    *" $excluded "*) fail "$excluded is out of scope but was included (filter over-matching)" ;;
    *)               pass "$excluded correctly excluded" ;;
  esac
done

# --- --depends widening still works ---
GOT_DEP="$(ids_for M046/P03 --type knowledge --depends P99)"
case " $GOT_DEP " in
  *" MEM006 "*) pass "--depends P99 pulls in sibling-phase entry" ;;
  *)            fail "--depends P99 failed to widen scope to [phase:M046/P99]" ;;
esac

# --- literal --tag mode unaffected by the split ---
GOT_TAG="$(ids_for M046/P03 --type knowledge --tag '[concern:bash-compat]')"
if [ "$GOT_TAG" = "MEM007 MEM008" ]; then
  pass "--tag literal mode returns exactly the tagged entries"
else
  fail "--tag literal mode changed → want [MEM007 MEM008], got [$GOT_TAG]"
fi

# --- Flat KNOWLEDGE.md path shares the same rule ---
FLAT="$TMPDIR_FX/KNOWLEDGE.md"
cat >"$FLAT" <<'FLATDOC'
# Knowledge

## K001: Multi-tag entry [project] [milestone:M005]
Body of the multi-tag entry.

## K002: Out-of-scope entry [milestone:M005]
Body of the out-of-scope entry.
FLATDOC

FLAT_OUT="$(bash "$SCOPE_FILTER" "$FLAT" M046/P03 --type knowledge)"
if printf '%s' "$FLAT_OUT" | grep -q 'K001'; then
  pass "flat path: multi-tag entry included"
else
  fail "flat path: multi-tag entry dropped"
fi
if printf '%s' "$FLAT_OUT" | grep -q 'K002'; then
  fail "flat path: out-of-scope entry included (over-matching)"
else
  pass "flat path: out-of-scope entry excluded"
fi

echo ""
echo "$PASS_COUNT/$((PASS_COUNT + FAIL_COUNT)) checks passed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "$FAIL_COUNT checks FAILED"
  exit 1
fi
