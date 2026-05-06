#!/usr/bin/env bash
# tests/m032-acceptance/p0X-pbj-b5-fragment-only-passthrough.sh
#
# PBJ-dogfood B5 regression — wiki-generate-stubs.sh must emit
# `rewrite-relative-urls=false` for top:* singleton stubs (constitution,
# decisions, knowledge, milestone-summary, glossary), knowledge-flat,
# and proposals:*. Fragment-only intra-doc anchors (`[link](#foo)`) in
# these self-contained singletons must pass through include-markdown
# untouched — without this, the plugin rewrites them to source-relative
# (`../../.orchestrator#foo`) and silent 404s break intra-doc nav.
#
# Bash 3.2 compatible. Single-script-file shape per AD-19. Throwaway
# fixture protocol — all state under /tmp, trap-EXIT cleanup.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"

FIXTURE="/tmp/m032-pbj-b5-fixture-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM

mkdir -p "$FIXTURE/.orchestrator/memory"
mkdir -p "$FIXTURE/.orchestrator/proposals"
mkdir -p "$FIXTURE/.orchestrator/knowledge"
mkdir -p "$FIXTURE/.orchestrator/milestones/M001"
mkdir -p "$FIXTURE/wiki/docs"
mkdir -p "$FIXTURE/wiki"
mkdir -p "$FIXTURE/scripts"
ln -s "$PROJECT_ROOT/scripts/wiki" "$FIXTURE/scripts/wiki"

# Top:* singletons — each contains a fragment-only anchor link.
printf '# Constitution\n\n[See process](#process-and-cycle).\n\n## Process and cycle\nbody\n' \
  > "$FIXTURE/.orchestrator/memory/constitution.md"
printf '# Decisions\n\n[D004](#d004-foo).\n\n## D004 — Foo\nbody\n' \
  > "$FIXTURE/.orchestrator/DECISIONS.md"
printf '# Knowledge\n\n[Patterns](#patterns).\n\n## Patterns\nbody\n' \
  > "$FIXTURE/.orchestrator/KNOWLEDGE.md"
printf '# Milestones\nbody\n' \
  > "$FIXTURE/.orchestrator/milestone-summary.md"
printf '# Glossary\n\n[Term A](#term-a).\n\n## Term A\nbody\n' \
  > "$FIXTURE/wiki/glossary.md"
printf '# Knowledge-flat-doc\n\n[Section](#section-1).\n\n## Section 1\nbody\n' \
  > "$FIXTURE/.orchestrator/knowledge/PRIMER.md"
printf '# Proposal Foo\n\n[Decision](#decision).\n\n## Decision\nbody\n' \
  > "$FIXTURE/.orchestrator/proposals/proposal-foo.md"

# Milestone artifact — control: must KEEP rewrite-relative-urls=true
# (sibling-doc cross-refs in milestone summaries depend on rewriting).
printf '# M001 Summary\n\n[Phase](phases/P01/index.md).\nbody\n' \
  > "$FIXTURE/.orchestrator/milestones/M001/M001-SUMMARY.md"

bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh" --root "$FIXTURE" \
  >/dev/null 2>&1 || {
  printf 'FAIL: stubs generator returned non-zero against B5 fixture\n' >&2
  exit 1
}

pass=0
fail=0

# Helper: assert <stub-file> has rewrite-relative-urls=<expected>.
assert_rrl() {
  _label="$1"
  _file="$2"
  _expected="$3"
  if [ ! -f "$_file" ]; then
    fail=$((fail + 1))
    printf 'FAIL: B5 %s — stub not generated: %s\n' "$_label" "$_file" >&2
    return
  fi
  if grep -q "rewrite-relative-urls=${_expected}" "$_file" 2>/dev/null; then
    pass=$((pass + 1))
    printf 'PASS: B5 %s emits rewrite-relative-urls=%s\n' "$_label" "$_expected"
  else
    fail=$((fail + 1))
    printf 'FAIL: B5 %s does NOT emit rewrite-relative-urls=%s\n' "$_label" "$_expected" >&2
    grep 'rewrite-relative-urls' "$_file" >&2 || true
  fi
}

assert_rrl "constitution"        "$FIXTURE/wiki/docs/constitution.md"        "false"
assert_rrl "decisions"            "$FIXTURE/wiki/docs/decisions.md"           "false"
assert_rrl "knowledge.md"         "$FIXTURE/wiki/docs/knowledge.md"           "false"
assert_rrl "milestone-summary"    "$FIXTURE/wiki/docs/milestone-summary.md"   "false"
assert_rrl "glossary"             "$FIXTURE/wiki/docs/glossary.md"            "false"
assert_rrl "knowledge-flat PRIMER" "$FIXTURE/wiki/docs/knowledge/PRIMER.md"   "false"
assert_rrl "proposals"            "$FIXTURE/wiki/docs/proposals/proposal-foo.md" "false"
# Control: milestone summary keeps rewriting on (sibling-doc references).
assert_rrl "milestone control"    "$FIXTURE/wiki/docs/milestones/M001/M001-SUMMARY.md" "true"

printf 'SUMMARY: pbj-b5-fragment-only-passthrough pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
