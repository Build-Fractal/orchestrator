#!/usr/bin/env bash
# tests/m032-acceptance/p0X-pbj-b4-extra-dir-labels.sh
#
# PBJ-dogfood B4 regression — wiki.extra_dir_labels sibling-map config
# overrides the default Title-Case projection in both nav-section labels
# and section index titles. Backwards compat: a bare-string extra_dirs
# entry without a corresponding label still falls back to Title-Case.
#
# Bash 3.2 compatible. Single-script-file. Throwaway fixture.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"

FIXTURE="/tmp/m032-pbj-b4-fixture-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/wiki/docs"
mkdir -p "$FIXTURE/scripts"
ln -s "$PROJECT_ROOT/scripts/wiki" "$FIXTURE/scripts/wiki"

mkdir -p "$FIXTURE/foo"
mkdir -p "$FIXTURE/bar"
printf '# Foo Doc\nbody\n' > "$FIXTURE/foo/foo-1.md"
printf '# Bar Doc\nbody\n' > "$FIXTURE/bar/bar-1.md"

cat > "$FIXTURE/.orchestrator/config.yml" <<'YAML'
wiki:
  extra_dirs:
    - foo/
    - bar/
  extra_dir_labels:
    foo: "Foo — Custom Label"
YAML

# Minimal mkdocs.yml with the auto-nav region marker so wiki-generate-nav.sh
# has somewhere to splice the auto-nav into.
cat > "$FIXTURE/wiki/mkdocs.yml" <<'YAML'
site_name: Test Wiki
docs_dir: docs

plugins:
  - search
YAML

pass=0
fail=0

# Run scanner — confirm extra-label record is emitted.
SCAN_OUT="/tmp/m032-pbj-b4-scan-$$.txt"
bash "$PROJECT_ROOT/scripts/wiki/wiki-scan-sources.sh" --root "$FIXTURE" \
  > "$SCAN_OUT" 2>/dev/null

if grep -q '^extra-label:foo||Foo — Custom Label$' "$SCAN_OUT"; then
  pass=$((pass + 1))
  printf 'PASS: B4 scanner emits extra-label:foo record\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B4 scanner missing extra-label:foo record\n' >&2
  grep -E '^extra(-|:)' "$SCAN_OUT" >&2 || true
fi

# Run nav generator — confirm "Foo — Custom Label" appears in the auto-nav
# block, NOT "Foo".
bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-nav.sh" --root "$FIXTURE" \
  >/dev/null 2>&1 || true

if grep -q 'Foo — Custom Label' "$FIXTURE/wiki/mkdocs.yml" 2>/dev/null; then
  pass=$((pass + 1))
  printf 'PASS: B4 nav uses configured label for foo/\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B4 nav missing configured label "Foo — Custom Label"\n' >&2
fi

# Backwards-compat: bar/ has no label override, must still fall back to
# Title-Case "Bar".
if grep -qE '^[[:space:]]*-[[:space:]]+Bar:' "$FIXTURE/wiki/mkdocs.yml" 2>/dev/null \
   || grep -qE 'Bar' "$FIXTURE/wiki/mkdocs.yml" 2>/dev/null; then
  pass=$((pass + 1))
  printf 'PASS: B4 bar/ falls back to Title-Case (backwards compat)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B4 backwards-compat broken — bar/ default label missing\n' >&2
fi

# Run stub generator — confirm wiki/docs/foo/index.md uses configured label
# in its title (or at least doesn't use the wrong default).
bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh" --root "$FIXTURE" \
  >/dev/null 2>&1 || true

if [ -f "$FIXTURE/wiki/docs/foo/index.md" ]; then
  if grep -q 'Foo — Custom Label' "$FIXTURE/wiki/docs/foo/index.md" 2>/dev/null; then
    pass=$((pass + 1))
    printf 'PASS: B4 stub index.md uses configured label\n'
  else
    fail=$((fail + 1))
    printf 'FAIL: B4 stub index.md missing configured label\n' >&2
    head -5 "$FIXTURE/wiki/docs/foo/index.md" >&2
  fi
else
  fail=$((fail + 1))
  printf 'FAIL: B4 stub index.md not created (B1 regression?)\n' >&2
fi

rm -f "$SCAN_OUT"

printf 'SUMMARY: pbj-b4-extra-dir-labels pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
