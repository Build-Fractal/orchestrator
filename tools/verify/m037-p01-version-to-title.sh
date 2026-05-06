#!/usr/bin/env bash
# tools/verify/m037-p01-version-to-title.sh — M037 P01 T02 Truth #2 verifier
# (FR-5: stub generator reads source `version:` and emits stub `title:`).
#
# Static check that scripts/wiki/wiki-generate-stubs.sh contains the
# version-reading + title-writing logic. Does NOT invoke the generator —
# the acceptance test (tests/m037-acceptance/p01-version-to-nav-title.sh)
# exercises behavior end-to-end.
#
# Asserts:
#   1. wiki-generate-stubs.sh defines derive_stub_title.
#   2. wiki-generate-stubs.sh defines read_frontmatter_field.
#   3. derive_stub_title reads frontmatter field "version".
#   4. write_stub call path consults derive_stub_title (title-projection
#      is wired into the emit path, not just defined-but-unused).
#   5. Nav generator (wiki-generate-nav.sh) defines emit_leaf_prefer_stub_title
#      so FR-6 stub-title-honoring is wired end-to-end.
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STUBS="$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh"
NAV="$PROJECT_ROOT/scripts/wiki/wiki-generate-nav.sh"

pass=0
fail=0

ok() {
  printf 'PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

# 1. derive_stub_title is defined.
if [ -f "$STUBS" ] && grep -q '^derive_stub_title()' "$STUBS"; then
  ok "wiki-generate-stubs.sh defines derive_stub_title()"
else
  bad "wiki-generate-stubs.sh missing derive_stub_title() definition"
fi

# 2. read_frontmatter_field is defined.
if [ -f "$STUBS" ] && grep -q '^read_frontmatter_field()' "$STUBS"; then
  ok "wiki-generate-stubs.sh defines read_frontmatter_field()"
else
  bad "wiki-generate-stubs.sh missing read_frontmatter_field() definition"
fi

# 3. derive_stub_title reads the "version" field.
if [ -f "$STUBS" ] && grep -q 'read_frontmatter_field "\$_canon" "version"' "$STUBS"; then
  ok "derive_stub_title reads frontmatter field \"version\""
else
  bad "derive_stub_title does not read frontmatter field \"version\""
fi

# 4. write_stub call path invokes derive_stub_title (wired-into-emit, not
#    dead code). The presence of the call inside write_stub() — not just
#    helper-definition — is what FR-5 actually requires.
if [ -f "$STUBS" ] && grep -q '_title=\$(derive_stub_title' "$STUBS"; then
  ok "write_stub invokes derive_stub_title to project version: into title:"
else
  bad "write_stub does not invoke derive_stub_title (projection not wired)"
fi

# 5. Nav generator carries the FR-6 stub-title-preferring leaf emitter.
if [ -f "$NAV" ] && grep -q '^emit_leaf_prefer_stub_title()' "$NAV"; then
  ok "wiki-generate-nav.sh defines emit_leaf_prefer_stub_title() (FR-6)"
else
  bad "wiki-generate-nav.sh missing emit_leaf_prefer_stub_title() (FR-6)"
fi

printf 'SUMMARY: m037-p01-version-to-title pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: m037-p01-version-to-title\n'
  exit 0
fi
exit 1
