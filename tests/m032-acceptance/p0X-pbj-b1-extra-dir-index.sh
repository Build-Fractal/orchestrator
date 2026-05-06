#!/usr/bin/env bash
# tests/m032-acceptance/p0X-pbj-b1-extra-dir-index.sh
#
# PBJ-dogfood B1 regression — wiki-generate-stubs.sh extra:* arm must
# emit wiki/docs/<dn>/index.md so wiki-generate-nav.sh's `Overview:
# <dn>/index.md` leaf doesn't 404 and `mkdocs build --strict` doesn't fail.
#
# Bash 3.2 compatible. Single-script-file shape per AD-19. Throwaway
# fixture protocol — all state under /tmp, trap-EXIT cleanup.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"

FIXTURE="/tmp/m032-pbj-b1-fixture-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/wiki/docs"
mkdir -p "$FIXTURE/foo"
mkdir -p "$FIXTURE/scripts"
# Symlink the project scripts/ into the fixture — wiki-generate-stubs.sh
# resolves its sibling scanner via $ROOT/scripts/wiki/wiki-scan-sources.sh.
ln -s "$PROJECT_ROOT/scripts/wiki" "$FIXTURE/scripts/wiki"

printf '# Foo Doc 1\nbody\n' > "$FIXTURE/foo/foo-1.md"
printf '# Foo Doc 2\nbody\n' > "$FIXTURE/foo/foo-2.md"

cat > "$FIXTURE/.orchestrator/config.yml" <<'YAML'
wiki:
  extra_dirs:
    - foo/
YAML

# Run stubs generator against the fixture (it invokes the scanner itself).
bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh" --root "$FIXTURE" \
  >/dev/null 2>&1 || {
  printf 'FAIL: stubs generator returned non-zero against B1 fixture\n' >&2
  exit 1
}

pass=0
fail=0

# Assert: index.md got emitted.
if [ -f "$FIXTURE/wiki/docs/foo/index.md" ]; then
  pass=$((pass + 1))
  printf 'PASS: B1 wiki/docs/foo/index.md emitted by extra:* arm\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B1 wiki/docs/foo/index.md NOT emitted (regression)\n' >&2
fi

# Assert: index.md is non-empty (has a real header + bullet list).
if [ -s "$FIXTURE/wiki/docs/foo/index.md" ]; then
  pass=$((pass + 1))
  printf 'PASS: B1 wiki/docs/foo/index.md is non-empty\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B1 wiki/docs/foo/index.md is empty (regression)\n' >&2
fi

# Assert: per-chunk stubs still emitted.
if [ -f "$FIXTURE/wiki/docs/foo/foo-1.md" ] && [ -f "$FIXTURE/wiki/docs/foo/foo-2.md" ]; then
  pass=$((pass + 1))
  printf 'PASS: B1 per-chunk stubs still emitted alongside index.md\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B1 per-chunk stubs missing (extra:* arm broken by fix)\n' >&2
fi

# Assert: index.md links to chunk stubs (real bullet list, not blank).
if grep -q 'foo-1.md' "$FIXTURE/wiki/docs/foo/index.md" 2>/dev/null \
   && grep -q 'foo-2.md' "$FIXTURE/wiki/docs/foo/index.md" 2>/dev/null; then
  pass=$((pass + 1))
  printf 'PASS: B1 index.md links to per-chunk stubs\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B1 index.md does not link to per-chunk stubs\n' >&2
fi

printf 'SUMMARY: pbj-b1-extra-dir-index pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
