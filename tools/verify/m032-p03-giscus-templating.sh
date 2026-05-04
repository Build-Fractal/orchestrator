#!/usr/bin/env bash
# tools/verify/m032-p03-giscus-templating.sh — M032/P03/T01 FR-7 verifier.
#
# Asserts the four M032 {{giscus_*}} placeholder tokens are interleaved
# with the existing Jinja {{ config.extra.giscus.* }} interpolations in
# the bundle-staged Giscus partial at wiki/overrides/partials/comments.html.
# The two interpolation paths coexist by design:
#   - {{giscus_*}}                  is sed-substituted by wiki-init.sh
#                                   --with-giscus at install time.
#   - {{ config.extra.giscus.* }}   is Jinja+!ENV-interpolated at mkdocs
#                                   build time from mkdocs.yml.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible (MEM001).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PARTIAL="$REPO_ROOT/wiki/overrides/partials/comments.html"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -f "$PARTIAL" ]; then
  say_fail "missing $PARTIAL"
  printf 'SUMMARY: m032-p03-giscus-templating pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

for tok in '{{giscus_repo}}' '{{giscus_repo_id}}' '{{giscus_category}}' '{{giscus_category_id}}'; do
  if grep -qF "$tok" "$PARTIAL"; then
    say_pass "placeholder token present: $tok"
  else
    say_fail "placeholder token absent: $tok"
  fi
done

# Coexistence: the existing Jinja interpolations must STILL be present.
for jinja in 'config.extra.giscus.repo' 'config.extra.giscus.repo_id' 'config.extra.giscus.category' 'config.extra.giscus.category_id'; do
  if grep -qF "$jinja" "$PARTIAL"; then
    say_pass "jinja interpolation preserved: $jinja"
  else
    say_fail "jinja interpolation missing: $jinja (FR-7 coexistence model violated)"
  fi
done

# FR-7 documentation comment block.
if grep -qF 'M032/P03/T01' "$PARTIAL" && grep -qF 'FR-7' "$PARTIAL"; then
  say_pass "FR-7 comment block present"
else
  say_fail "FR-7 comment block missing (expected 'M032/P03/T01' + 'FR-7' markers)"
fi

printf 'SUMMARY: m032-p03-giscus-templating pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
