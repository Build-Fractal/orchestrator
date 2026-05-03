#!/usr/bin/env bash
# tests/test-reference-backwards-compat-golden.sh — M036 P07 T04 SC-7
# acceptance harness. Golden-baseline byte-equality diff for the
# pre-feature payload path (CON-1 / SC-7).
#
#   SC-7.1 — build-context.sh stdout exit code 0
#   SC-7.2 — stdout cmp -s byte-identical to captured baseline
#            (after hit_count normalization on both sides — see
#            volatile-field policy below)
#
# Emits BATTERY: pass=N fail=N skip=0 last line. AD-19.
#
# Invocation form: positional `<orch_root> <milestone> <phase> <task>` per
# T03's equivalent-invocation policy (build-context.sh's argument parser
# does not implement the payload-verbatim --milestone/--phase/--task/
# --task-plan flag set; the parser exits 1 on unknown options). T03
# captured the baseline using the positional form; T04 honors the same
# flag set here for byte-equality contract integrity.
#
# Volatile-field policy (hit_count normalization):
#
# build-context.sh increments `hit_count:` on every included knowledge
# entry via scripts/knowledge/increment-hits.sh, mutating the on-disk
# knowledge/*.md files. This harness wraps invocation with a knowledge/
# snapshot-and-restore so a single harness invocation is net-zero.
# However, *upstream* phase-suite verifiers (notably T03's
# m036-p07-omit-empty-section.sh which also drives build-context) do
# not restore knowledge — their hit_count increments persist past the
# captured baseline's frozen state.
#
# To preserve the SC-7 byte-equality contract under upstream drift, the
# harness normalizes `hit_count: <N>` lines to `hit_count: NORMALIZED`
# in both the captured baseline and the live dispatcher output before
# cmp. Every other field (frontmatter, body, manifest table, structural
# headers, knowledge entry order, all section content) is checked
# byte-exactly. This matches the M036/P05 baseline-normalization shape
# (where volatile timestamp fields are normalized identically on both
# sides of the diff before cmp).
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
PLAN="$ROOT/tests/fixtures/m036-p07-fixture-milestone/phases/P-fixture/tasks/T-no-scope-PLAN.md"
BASELINE="$ROOT/tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt"
WS="$(mktemp -d)"
KBAK="$WS/knowledge.bak"

restore_knowledge() {
  if [ -d "$KBAK" ]; then
    rm -rf "$ROOT/knowledge"
    mv "$KBAK" "$ROOT/knowledge"
  fi
  rm -rf "$WS"
}
trap restore_knowledge EXIT

pass=0
fail=0
skip=0

if [ ! -f "$BASELINE" ]; then
  echo "FAIL: SC-7 baseline-missing"
  echo "BATTERY: pass=0 fail=1 skip=0"
  exit 1
fi

if [ ! -f "$PLAN" ]; then
  echo "FAIL: SC-7 fixture-task-plan-missing ($PLAN)"
  echo "BATTERY: pass=0 fail=1 skip=0"
  exit 1
fi

cp -R "$ROOT/knowledge" "$KBAK"

OUT="$WS/out.txt"
set +e
bash "$ROOT/scripts/dispatch/build-context.sh" \
  "$ROOT/tests/fixtures/m036-p07-fixture-milestone" \
  M-fixture P-fixture T-no-scope > "$OUT" 2>/dev/null
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "PASS: SC-7.1 build-context-rc-zero"
  pass=$((pass + 1))
else
  echo "FAIL: SC-7.1 build-context-rc=$rc"
  fail=$((fail + 1))
fi

# Normalize hit_count: <N> -> hit_count: NORMALIZED on both sides.
OUT_NORM="$WS/out.norm.txt"
BASE_NORM="$WS/base.norm.txt"
sed -E 's/^hit_count: [0-9]+$/hit_count: NORMALIZED/' "$OUT" > "$OUT_NORM"
sed -E 's/^hit_count: [0-9]+$/hit_count: NORMALIZED/' "$BASELINE" > "$BASE_NORM"

if cmp -s "$OUT_NORM" "$BASE_NORM"; then
  echo "PASS: SC-7.2 byte-identical-to-baseline (hit_count-normalized)"
  pass=$((pass + 1))
else
  echo "FAIL: SC-7.2 byte-mismatch (golden-baseline diff after normalization)"
  diff -u "$BASE_NORM" "$OUT_NORM" | head -40 >&2 || true
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
