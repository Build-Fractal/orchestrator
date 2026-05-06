#!/usr/bin/env bash
# tools/verify/m037-p01-card-grid.sh — M037 P01 T01 Truth #1 verifier (FR-1).
#
# Asserts the four card-grid surface artifacts are in place:
#   1. templates/wiki-index-cards.md.tmpl exists and contains "grid cards".
#   2. templates/orchestrator-config-default.yml contains a wiki: block with
#      landing_cards: under it.
#   3. scripts/wiki/wiki-generate-stubs.sh contains a render_landing_cards
#      function.
#   4. wiki/docs/index.md contains a `<div class="grid cards"` opening tag
#      OR the M037-LANDING-CARDS-BEGIN sentinel (post-execution proof).
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TMPL="$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl"
CONFIG_DEFAULT="$PROJECT_ROOT/templates/orchestrator-config-default.yml"
STUBS="$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh"
INDEX="$PROJECT_ROOT/wiki/docs/index.md"

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

# 1. Template exists + contains "grid cards".
if [ -f "$TMPL" ] && grep -q 'grid cards' "$TMPL"; then
  ok "templates/wiki-index-cards.md.tmpl present with grid-cards block"
else
  bad "templates/wiki-index-cards.md.tmpl missing or lacks 'grid cards' marker"
fi

# 2. Config default carries wiki.landing_cards: schema entry.
if [ -f "$CONFIG_DEFAULT" ] && grep -q '^wiki:' "$CONFIG_DEFAULT" && grep -q 'landing_cards:' "$CONFIG_DEFAULT"; then
  ok "templates/orchestrator-config-default.yml has wiki.landing_cards: schema"
else
  bad "templates/orchestrator-config-default.yml missing wiki.landing_cards: schema"
fi

# 3. Stub generator carries render_landing_cards.
if [ -f "$STUBS" ] && grep -q 'render_landing_cards' "$STUBS"; then
  ok "scripts/wiki/wiki-generate-stubs.sh contains render_landing_cards"
else
  bad "scripts/wiki/wiki-generate-stubs.sh missing render_landing_cards"
fi

# 4. Homepage carries either the rendered <div class="grid cards" tag or the
# M037-LANDING-CARDS-BEGIN sentinel (proves the renderer was invoked).
if [ -f "$INDEX" ] && (grep -F -q '<div class="grid cards"' "$INDEX" || grep -F -q 'M037-LANDING-CARDS-BEGIN' "$INDEX"); then
  ok "wiki/docs/index.md contains grid-cards block or sentinel"
else
  bad "wiki/docs/index.md missing grid-cards block AND sentinel"
fi

printf 'SUMMARY: m037-p01-card-grid pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: m037-p01-card-grid (%d/%d)\n' "$pass" "$pass"
  exit 0
fi
exit 1
