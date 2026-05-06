#!/usr/bin/env bash
# tests/m037-acceptance/p01-card-grid-homepage.sh — M037 P01 SC-1 acceptance.
#
# Exercises the FR-1 + FR-2 + FR-3 card-grid rendering pipeline against three
# synthetic fixtures:
#   Case A — operator config with three explicit landing_cards entries
#            -> exactly three cards rendered with the configured icon, title,
#               blurb, and section href.
#   Case B — empty landing_cards: []; nav: has Constitution + Decisions +
#            Knowledge top-level entries; DEFAULT_BLURBS lookup yields one
#            card per intersection (3 cards expected).
#   Case C — empty landing_cards: []; nav: has only `Home: index.md`; no
#            DEFAULT_BLURBS intersection -> 0 cards rendered, index.md
#            unchanged from baseline.
#
# Spec references: FR-1, FR-2, FR-3, US-1 AS-1..AS-4, SC-1.
# Pipeline under test: scripts/wiki/wiki-generate-stubs.sh --cards-only.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STUBS="$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh"
TMPL="$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl"

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

if [ ! -f "$STUBS" ]; then
  bad "stub generator missing at $STUBS"
  printf 'SC-1: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -f "$TMPL" ]; then
  bad "card template missing at $TMPL"
  printf 'SC-1: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

TMPDIR_LOCAL="$(mktemp -d -t m037-p01-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

# ---- helper: build a fixture rooted at $1 ----------------------------------
# Each fixture mirrors what the renderer expects: $ROOT/.orchestrator/config.yml,
# $ROOT/wiki/mkdocs.yml, $ROOT/wiki/docs/, $ROOT/templates/wiki-index-cards.md.tmpl,
# $ROOT/scripts/wiki/wiki-generate-stubs.sh.
build_fixture_skeleton() {
  _root="$1"
  mkdir -p "$_root/.orchestrator"
  mkdir -p "$_root/wiki/docs/knowledge"
  mkdir -p "$_root/templates"
  mkdir -p "$_root/scripts/wiki"
  # Materialize the template via copy (renderer reads $ROOT/templates/wiki-index-cards.md.tmpl).
  cp "$TMPL" "$_root/templates/wiki-index-cards.md.tmpl"
  # The stub generator script lives at $ROOT/scripts/wiki/wiki-generate-stubs.sh.
  cp "$STUBS" "$_root/scripts/wiki/wiki-generate-stubs.sh"
  # Touch the section files so existence checks pass.
  : > "$_root/wiki/docs/constitution.md"
  : > "$_root/wiki/docs/decisions.md"
  : > "$_root/wiki/docs/knowledge.md"
  : > "$_root/wiki/docs/glossary.md"
  : > "$_root/wiki/docs/knowledge/index.md"
}

# ============================================================================
# Case A — explicit operator config with three landing_cards entries.
# ============================================================================
CASE_A="$TMPDIR_LOCAL/case-a"
build_fixture_skeleton "$CASE_A"

cat > "$CASE_A/wiki/mkdocs.yml" <<'EOF'
site_name: "case-a"
docs_dir: "docs"
nav:
  - Home: index.md
  - Constitution: constitution.md
  - Decisions: decisions.md
  - Knowledge: knowledge.md
EOF

cat > "$CASE_A/.orchestrator/config.yml" <<'EOF'
wiki:
  landing_cards:
    - section: constitution.md
      icon: fontawesome-solid-scale-balanced
      title: Constitution
      blurb: Test blurb for the constitution card.
    - section: decisions.md
      icon: fontawesome-solid-list-check
      title: Decisions
      blurb: Test blurb for decisions.
    - section: knowledge.md
      icon: fontawesome-solid-lightbulb
      title: Knowledge
      blurb: Test blurb for knowledge.
EOF

bash "$STUBS" --root "$CASE_A" --cards-only > "$TMPDIR_LOCAL/case-a.log" 2>&1
case_a_rc=$?

if [ "$case_a_rc" -eq 0 ]; then
  ok "case-a: --cards-only exits 0"
else
  bad "case-a: --cards-only exited rc=$case_a_rc"
  sed 's/^/    | /' "$TMPDIR_LOCAL/case-a.log" >&2
fi

case_a_index="$CASE_A/wiki/docs/index.md"
if [ -f "$case_a_index" ]; then
  ok "case-a: index.md created"
else
  bad "case-a: index.md not created"
fi

if grep -F -q '<div class="grid cards"' "$case_a_index"; then
  ok "case-a: grid-cards block present"
else
  bad "case-a: grid-cards block missing"
fi

# Each card emits one anchor of the form `[:octicons-arrow-right-24: TITLE](path)`.
# Count anchors to verify exactly three cards rendered.
case_a_card_count=$(grep -c -F ':octicons-arrow-right-24:' "$case_a_index" 2>/dev/null || printf '0')
if [ "$case_a_card_count" -eq 3 ]; then
  ok "case-a: exactly 3 cards rendered (octicons-arrow-right-24 anchors)"
else
  bad "case-a: expected 3 cards, found $case_a_card_count"
fi

# Each configured (icon, title, blurb) triple should be substring-present.
if grep -F -q ':fontawesome-solid-scale-balanced:' "$case_a_index" \
   && grep -F -q ':fontawesome-solid-list-check:' "$case_a_index" \
   && grep -F -q ':fontawesome-solid-lightbulb:' "$case_a_index"; then
  ok "case-a: all three configured icons present"
else
  bad "case-a: configured icons missing"
fi

if grep -F -q 'Test blurb for the constitution card.' "$case_a_index" \
   && grep -F -q 'Test blurb for decisions.' "$case_a_index" \
   && grep -F -q 'Test blurb for knowledge.' "$case_a_index"; then
  ok "case-a: all three configured blurbs present"
else
  bad "case-a: configured blurbs missing"
fi

if grep -F -q '](constitution.md)' "$case_a_index" \
   && grep -F -q '](decisions.md)' "$case_a_index" \
   && grep -F -q '](knowledge.md)' "$case_a_index"; then
  ok "case-a: all three section hrefs present"
else
  bad "case-a: section hrefs missing"
fi

if grep -F -q '<!-- M037-LANDING-CARDS-BEGIN -->' "$case_a_index" \
   && grep -F -q '<!-- M037-LANDING-CARDS-END -->' "$case_a_index"; then
  ok "case-a: sentinel markers present"
else
  bad "case-a: sentinel markers missing"
fi

# ============================================================================
# Case B — empty landing_cards: []; FR-3 fallback via DEFAULT_BLURBS x nav.
# ============================================================================
CASE_B="$TMPDIR_LOCAL/case-b"
build_fixture_skeleton "$CASE_B"

cat > "$CASE_B/wiki/mkdocs.yml" <<'EOF'
site_name: "case-b"
docs_dir: "docs"
nav:
  - Home: index.md
  - Constitution: constitution.md
  - Decisions: decisions.md
  - Knowledge: knowledge.md
EOF

cat > "$CASE_B/.orchestrator/config.yml" <<'EOF'
wiki:
  landing_cards: []
EOF

bash "$STUBS" --root "$CASE_B" --cards-only > "$TMPDIR_LOCAL/case-b.log" 2>&1
case_b_rc=$?

if [ "$case_b_rc" -eq 0 ]; then
  ok "case-b: --cards-only exits 0"
else
  bad "case-b: --cards-only exited rc=$case_b_rc"
  sed 's/^/    | /' "$TMPDIR_LOCAL/case-b.log" >&2
fi

case_b_index="$CASE_B/wiki/docs/index.md"
if grep -F -q '<div class="grid cards"' "$case_b_index"; then
  ok "case-b: fallback grid-cards block present"
else
  bad "case-b: fallback grid-cards block missing"
fi

# Three nav sections (Home is excluded) all have DEFAULT_BLURBS entries
# -> 3 cards expected.
case_b_card_count=$(grep -c -F ':octicons-arrow-right-24:' "$case_b_index" 2>/dev/null || printf '0')
if [ "$case_b_card_count" -eq 3 ]; then
  ok "case-b: exactly 3 default cards rendered"
else
  bad "case-b: expected 3 default cards, found $case_b_card_count"
fi

# DEFAULT_BLURBS title strings should appear in the rendered output.
if grep -F -q '**Constitution**' "$case_b_index" \
   && grep -F -q '**Decisions**' "$case_b_index" \
   && grep -F -q '**Knowledge**' "$case_b_index"; then
  ok "case-b: default Constitution/Decisions/Knowledge titles present"
else
  bad "case-b: default titles missing"
fi

# ============================================================================
# Case C — empty landing_cards: []; nav: has only Home -> 0 cards.
# ============================================================================
CASE_C="$TMPDIR_LOCAL/case-c"
build_fixture_skeleton "$CASE_C"

cat > "$CASE_C/wiki/mkdocs.yml" <<'EOF'
site_name: "case-c"
docs_dir: "docs"
nav:
  - Home: index.md
EOF

cat > "$CASE_C/.orchestrator/config.yml" <<'EOF'
wiki:
  landing_cards: []
EOF

# Pre-existing index with known content; should NOT be touched (zero cards).
cat > "$CASE_C/wiki/docs/index.md" <<'EOF'
---
title: "case-c"
---

# case-c baseline content
EOF
case_c_baseline_hash=$(shasum "$CASE_C/wiki/docs/index.md" | awk '{print $1}')

bash "$STUBS" --root "$CASE_C" --cards-only > "$TMPDIR_LOCAL/case-c.log" 2>&1
case_c_rc=$?

if [ "$case_c_rc" -eq 0 ]; then
  ok "case-c: --cards-only exits 0 (zero-cards path)"
else
  bad "case-c: --cards-only exited rc=$case_c_rc"
  sed 's/^/    | /' "$TMPDIR_LOCAL/case-c.log" >&2
fi

case_c_after_hash=$(shasum "$CASE_C/wiki/docs/index.md" | awk '{print $1}')
if [ "$case_c_baseline_hash" = "$case_c_after_hash" ]; then
  ok "case-c: index.md unchanged (zero-cards leaves file byte-identical)"
else
  bad "case-c: index.md modified despite zero-cards path"
fi

# ============================================================================
# Idempotency check — re-running case-a should produce byte-identical output.
# ============================================================================
case_a_first_hash=$(shasum "$case_a_index" | awk '{print $1}')
bash "$STUBS" --root "$CASE_A" --cards-only > "$TMPDIR_LOCAL/case-a-rerun.log" 2>&1
case_a_second_hash=$(shasum "$case_a_index" | awk '{print $1}')
if [ "$case_a_first_hash" = "$case_a_second_hash" ]; then
  ok "case-a: idempotent re-run produces byte-identical index.md"
else
  bad "case-a: idempotent re-run drifted (hash mismatch)"
fi

# ---- final summary ----------------------------------------------------------
printf 'SC-1: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: p01-card-grid-homepage\n'
  exit 0
fi
printf 'FAIL: p01-card-grid-homepage\n'
exit 1
