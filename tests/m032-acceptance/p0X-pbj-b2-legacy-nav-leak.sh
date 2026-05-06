#!/usr/bin/env bash
# tests/m032-acceptance/p0X-pbj-b2-legacy-nav-leak.sh
#
# PBJ-dogfood B2 regression — wiki-generate-nav.sh's legacy-nav migration
# (branch 3b, extract_between_markers) must NOT leak a duplicate `nav:`
# YAML key into the custom-nav region. The M012-P01 baseline emitted
# legacy nav blocks with a literal `nav:` header line; if that header
# leaks through into the custom-nav region, mkdocs's last-key-wins YAML
# semantics silently override the freshly-regenerated auto-nav block.
#
# Bash 3.2 compatible. Single-script-file. Throwaway fixture protocol.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"

FIXTURE="/tmp/m032-pbj-b2-fixture-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/wiki/docs"
mkdir -p "$FIXTURE/scripts"
ln -s "$PROJECT_ROOT/scripts/wiki" "$FIXTURE/scripts/wiki"

# Synthetic mkdocs.yml shaped exactly like an M012-P01-baseline project
# pre-MIT-005-region-split: legacy markers wrap a literal `nav:` header
# plus a couple of operator-authored leaf entries.
cat > "$FIXTURE/wiki/mkdocs.yml" <<'YAML'
site_name: Test Wiki
docs_dir: docs

plugins:
  - search

# >>> M012-P01 nav (auto-generated — do not edit by hand)
nav:
  - Custom Page: custom.md
  - Another: another.md
# <<< M012-P01 nav end
YAML

# Empty .orchestrator/ — scanner has nothing to enumerate beyond zero
# top-level records, but that's fine: the migration branch fires off the
# legacy markers' presence regardless of scanner output.
bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-nav.sh" --root "$FIXTURE" \
  >/dev/null 2>&1 || true   # exit code irrelevant; check output shape

pass=0
fail=0

# Assert: exactly one top-level `nav:` line in the regenerated mkdocs.yml.
N_NAV=$(grep -c '^nav:[[:space:]]*$' "$FIXTURE/wiki/mkdocs.yml" 2>/dev/null || printf '0')
if [ "$N_NAV" = "1" ]; then
  pass=$((pass + 1))
  printf 'PASS: B2 exactly one top-level nav: key (got %s)\n' "$N_NAV"
else
  fail=$((fail + 1))
  printf 'FAIL: B2 expected exactly 1 top-level nav: key, got %s (regression)\n' "$N_NAV" >&2
  printf '----- mkdocs.yml -----\n' >&2
  cat "$FIXTURE/wiki/mkdocs.yml" >&2
  printf '----------------------\n' >&2
fi

# Assert: the operator-authored leaves were preserved in the custom-nav
# region (i.e., the migration didn't drop them entirely).
if grep -q 'Custom Page: custom.md' "$FIXTURE/wiki/mkdocs.yml" 2>/dev/null \
   && grep -q 'Another: another.md' "$FIXTURE/wiki/mkdocs.yml" 2>/dev/null; then
  pass=$((pass + 1))
  printf 'PASS: B2 operator-authored leaves preserved through migration\n'
else
  fail=$((fail + 1))
  printf 'FAIL: B2 operator-authored leaves dropped (regression)\n' >&2
fi

# Assert: legacy markers were stripped (FR-14 region-split contract).
if grep -qF '# >>> M012-P01 nav' "$FIXTURE/wiki/mkdocs.yml" 2>/dev/null; then
  fail=$((fail + 1))
  printf 'FAIL: B2 legacy markers still present after migration (regression)\n' >&2
else
  pass=$((pass + 1))
  printf 'PASS: B2 legacy markers stripped after migration\n'
fi

printf 'SUMMARY: pbj-b2-legacy-nav-leak pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
