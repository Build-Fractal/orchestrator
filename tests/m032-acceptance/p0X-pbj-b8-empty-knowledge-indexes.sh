#!/usr/bin/env bash
# tests/m032-acceptance/p0X-pbj-b8-empty-knowledge-indexes.sh
#
# PBJ-dogfood B8 regression — wiki-generate-stubs.sh must NOT auto-emit
# wiki/docs/knowledge/{patterns,conventions,lessons}/index.md or the
# top-level wiki/docs/knowledge/index.md when the project's
# knowledge/<cat>/ subtrees are empty (or absent). Without this gate the
# script writes title-only pages that mkdocs flags as orphan, polluting
# the strict-build verdict for projects that don't yet have a populated
# knowledge graph.
#
# Bash 3.2 compatible. Single-script-file shape per AD-19. Throwaway
# fixture protocol — all state under /tmp, trap-EXIT cleanup.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"

FIXTURE="/tmp/m032-pbj-b8-fixture-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM

mkdir -p "$FIXTURE/.orchestrator/memory"
mkdir -p "$FIXTURE/wiki/docs"
mkdir -p "$FIXTURE/scripts"
ln -s "$PROJECT_ROOT/scripts/wiki" "$FIXTURE/scripts/wiki"

# Minimal corpus — constitution only. No knowledge/<cat>/ trees.
printf '# Constitution\nbody\n' > "$FIXTURE/.orchestrator/memory/constitution.md"

bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh" --root "$FIXTURE" \
  >/dev/null 2>&1 || {
  printf 'FAIL: B8 stubs generator returned non-zero against fixture\n' >&2
  exit 1
}

pass=0
fail=0

# Assert: per-category indexes are NOT emitted (empty source trees).
for sub in patterns conventions lessons; do
  if [ -f "$FIXTURE/wiki/docs/knowledge/${sub}/index.md" ]; then
    fail=$((fail + 1))
    printf 'FAIL: B8 wiki/docs/knowledge/%s/index.md emitted (regression — empty subdir orphan)\n' "$sub" >&2
  else
    pass=$((pass + 1))
    printf 'PASS: B8 wiki/docs/knowledge/%s/index.md gated off (empty source)\n' "$sub"
  fi
done

# Assert: top-level knowledge/index.md is NOT emitted when no category has content.
if [ -f "$FIXTURE/wiki/docs/knowledge/index.md" ]; then
  fail=$((fail + 1))
  printf 'FAIL: B8 wiki/docs/knowledge/index.md emitted (regression — no MEM stubs exist)\n' >&2
else
  pass=$((pass + 1))
  printf 'PASS: B8 wiki/docs/knowledge/index.md gated off (no MEM stubs)\n'
fi

# Control case: when at least one MEM stub exists, indexes MUST emit.
mkdir -p "$FIXTURE/knowledge/patterns"
cat > "$FIXTURE/knowledge/patterns/MEM001.md" <<'EOF'
---
mem_id: MEM001
title: "Test Pattern"
---

# Test Pattern

body
EOF

bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh" --root "$FIXTURE" \
  >/dev/null 2>&1 || {
  printf 'FAIL: B8 stubs generator returned non-zero on populated control\n' >&2
  exit 1
}

if [ -f "$FIXTURE/wiki/docs/knowledge/patterns/index.md" ]; then
  pass=$((pass + 1))
  printf 'PASS: B8 control — patterns index emits when MEM exists\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B8 control — patterns index missing despite MEM existing\n' >&2
fi

if [ -f "$FIXTURE/wiki/docs/knowledge/index.md" ]; then
  pass=$((pass + 1))
  printf 'PASS: B8 control — top knowledge index emits when at least one MEM exists\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B8 control — top knowledge index missing\n' >&2
fi

# Empty siblings (conventions, lessons) still gated off in populated control.
for sub in conventions lessons; do
  if [ -f "$FIXTURE/wiki/docs/knowledge/${sub}/index.md" ]; then
    fail=$((fail + 1))
    printf 'FAIL: B8 control — %s index emitted despite empty source (over-trigger)\n' "$sub" >&2
  else
    pass=$((pass + 1))
    printf 'PASS: B8 control — empty %s index still gated off\n' "$sub"
  fi
done

printf 'SUMMARY: pbj-b8-empty-knowledge-indexes pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
