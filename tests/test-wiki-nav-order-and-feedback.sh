#!/usr/bin/env bash
# tests/test-wiki-nav-order-and-feedback.sh — PBJ-2026-05-08 acceptance.
#
# Two upstream gaps surfaced by PBJ-central after adopting the
# .orchestrator/spec/ + .orchestrator/decisions/ conventions (commit 78d27e02):
#
#   A+B  Section ordering hint — flat-list nav sections (spec, decisions-extra,
#        proposals, extras, feedback, knowledge-flat) should sort by source
#        frontmatter `nav_order:` integer (asc) with alphabetical tiebreak.
#        Files without nav_order: default to 9999 (sort after declared items).
#        Backward compat: existing files unchanged → all alphabetical.
#
#   E    Feedback nav-arm — wiki-generate-stubs.sh emits feedback:* stubs and
#        registers a section index, but wiki-generate-nav.sh had no feedback:*
#        arm; PBJ's 13 .orchestrator/feedback/ stubs orphaned with mkdocs
#        "not included in nav" warnings on every build.
#
# Test cases:
#   Case 1: nav_order asc with alphabetical tiebreak (spec/ section)
#   Case 2: missing nav_order: defaults to 9999 (mixed declared/undeclared)
#   Case 3: feedback section appears in nav with feedback:* arm
#   Case 4: backward compat — no nav_order declared anywhere ⇒ alphabetical
#
# Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NAV_GEN="$PROJECT_ROOT/scripts/wiki/wiki-generate-nav.sh"
SCANNER="$PROJECT_ROOT/scripts/wiki/wiki-scan-sources.sh"
STUBS="$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh"
TITLES="$PROJECT_ROOT/scripts/wiki/wiki-milestone-titles.sh"

pass=0
fail=0

ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

for required in "$NAV_GEN" "$SCANNER" "$STUBS"; do
  if [ ! -f "$required" ]; then
    bad "required script missing: $required"
    printf 'SUMMARY: test-wiki-nav-order-and-feedback pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
  fi
done

TMPDIR_LOCAL="$(mktemp -d -t pbj-2026-05-08-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

# stage_project <root> — minimal project layout for the wiki tooling.
stage_project() {
  _root="$1"
  mkdir -p "$_root/.orchestrator/spec"
  mkdir -p "$_root/.orchestrator/decisions"
  mkdir -p "$_root/.orchestrator/feedback"
  mkdir -p "$_root/.orchestrator/proposals"
  mkdir -p "$_root/scripts/wiki"
  mkdir -p "$_root/wiki/docs"
  mkdir -p "$_root/templates"

  ln -s "$NAV_GEN"  "$_root/scripts/wiki/wiki-generate-nav.sh"
  ln -s "$SCANNER" "$_root/scripts/wiki/wiki-scan-sources.sh"
  ln -s "$STUBS"   "$_root/scripts/wiki/wiki-generate-stubs.sh"
  if [ -f "$TITLES" ]; then
    ln -s "$TITLES" "$_root/scripts/wiki/wiki-milestone-titles.sh"
  fi
  if [ -f "$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl" ]; then
    cp "$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl" \
       "$_root/templates/wiki-index-cards.md.tmpl"
  fi

  cat > "$_root/.orchestrator/config.yml" <<'CFG'
schema_version: "1.0"
type: orchestrator-config
CFG
  cat > "$_root/wiki/mkdocs.yml" <<'MK'
site_name: Test Fixture
docs_dir: docs
nav:
  - Home: index.md
MK
}

# write_md <path> <nav_order or empty> <h1>
write_md() {
  _p="$1"
  _no="$2"
  _h1="$3"
  if [ -n "$_no" ]; then
    cat > "$_p" <<MD
---
nav_order: $_no
---
# $_h1
body content.
MD
  else
    cat > "$_p" <<MD
# $_h1
body content.
MD
  fi
}

# nav_position <basename> <mkdocs.yml> — prints the line-number where
# basename.md appears in the nav block; empty if absent.
nav_position() {
  grep -n "$1\\.md" "$2" | head -n 1 | cut -d: -f1
}

# ---- Case 1: spec section sorts by nav_order asc ---------------------------
# Three spec docs: tier-1 (nav_order: 10), tier-2 (nav_order: 20), tier-3
# (nav_order: 30). Filenames are intentionally REVERSE-alphabetical of the
# desired order to prove nav_order overrides the alphabetical default.

ROOT1="$TMPDIR_LOCAL/case1"
stage_project "$ROOT1"
write_md "$ROOT1/.orchestrator/spec/zebra-tier-1.md"  10 "Zebra Tier 1 (most-authoritative)"
write_md "$ROOT1/.orchestrator/spec/yankee-tier-2.md" 20 "Yankee Tier 2"
write_md "$ROOT1/.orchestrator/spec/xray-tier-3.md"   30 "Xray Tier 3 (least-authoritative)"

if bash "$NAV_GEN" --root "$ROOT1" >"$TMPDIR_LOCAL/case1.log" 2>&1; then
  POS_Z=$(nav_position "zebra-tier-1" "$ROOT1/wiki/mkdocs.yml")
  POS_Y=$(nav_position "yankee-tier-2" "$ROOT1/wiki/mkdocs.yml")
  POS_X=$(nav_position "xray-tier-3"   "$ROOT1/wiki/mkdocs.yml")
  if [ -n "$POS_Z" ] && [ -n "$POS_Y" ] && [ -n "$POS_X" ] \
     && [ "$POS_Z" -lt "$POS_Y" ] && [ "$POS_Y" -lt "$POS_X" ]; then
    ok "Case 1: spec section ordered by nav_order asc (zebra→yankee→xray, reversing alphabetical)"
  else
    bad "Case 1: spec nav order wrong — zebra@$POS_Z yankee@$POS_Y xray@$POS_X"
    sed -n "/spec\\/index\\.md/,/^[a-zA-Z]/p" "$ROOT1/wiki/mkdocs.yml" >&2
  fi
else
  bad "Case 1: nav-gen exited non-zero (log: $TMPDIR_LOCAL/case1.log)"
fi

# ---- Case 2: mixed declared + undeclared (undeclared sorts last) -----------
# Three docs: alpha-doc (nav_order: 10), beta-doc (no nav_order), zulu-doc
# (nav_order: 20). Expected: alpha (10) → zulu (20) → beta (9999, fallback).

ROOT2="$TMPDIR_LOCAL/case2"
stage_project "$ROOT2"
write_md "$ROOT2/.orchestrator/spec/alpha-doc.md" 10 "Alpha Doc"
write_md "$ROOT2/.orchestrator/spec/beta-doc.md"  ""  "Beta Doc"
write_md "$ROOT2/.orchestrator/spec/zulu-doc.md"  20 "Zulu Doc"

if bash "$NAV_GEN" --root "$ROOT2" >"$TMPDIR_LOCAL/case2.log" 2>&1; then
  POS_A=$(nav_position "alpha-doc" "$ROOT2/wiki/mkdocs.yml")
  POS_B=$(nav_position "beta-doc"  "$ROOT2/wiki/mkdocs.yml")
  POS_Z=$(nav_position "zulu-doc"  "$ROOT2/wiki/mkdocs.yml")
  if [ -n "$POS_A" ] && [ -n "$POS_B" ] && [ -n "$POS_Z" ] \
     && [ "$POS_A" -lt "$POS_Z" ] && [ "$POS_Z" -lt "$POS_B" ]; then
    ok "Case 2: undeclared nav_order sorts after declared (alpha→zulu→beta)"
  else
    bad "Case 2: mixed sort wrong — alpha@$POS_A zulu@$POS_Z beta@$POS_B"
  fi
else
  bad "Case 2: nav-gen exited non-zero (log: $TMPDIR_LOCAL/case2.log)"
fi

# ---- Case 3: feedback section appears in nav -------------------------------
# Drop two .orchestrator/feedback/*.md files. Verify the Feedback section
# emits with both children in nav. Pre-fix: nav-gen had no feedback:* arm,
# and these files would orphan with mkdocs warnings.

ROOT3="$TMPDIR_LOCAL/case3"
stage_project "$ROOT3"
write_md "$ROOT3/.orchestrator/feedback/round-1.md" "" "Round 1 SME Feedback"
write_md "$ROOT3/.orchestrator/feedback/round-2.md" "" "Round 2 SME Feedback"

if bash "$NAV_GEN" --root "$ROOT3" >"$TMPDIR_LOCAL/case3.log" 2>&1; then
  if grep -q "^  - Feedback:" "$ROOT3/wiki/mkdocs.yml"; then
    ok "Case 3a: Feedback section emitted in nav"
  else
    bad "Case 3a: Feedback section MISSING from nav (the Item E bug)"
    grep -A 5 "^nav:" "$ROOT3/wiki/mkdocs.yml" >&2
  fi
  if grep -q "feedback/round-1.md" "$ROOT3/wiki/mkdocs.yml" \
     && grep -q "feedback/round-2.md" "$ROOT3/wiki/mkdocs.yml"; then
    ok "Case 3b: both feedback files included in nav"
  else
    bad "Case 3b: feedback file leaves missing from nav"
  fi
else
  bad "Case 3: nav-gen exited non-zero (log: $TMPDIR_LOCAL/case3.log)"
fi

# ---- Case 4: INCLUDE_FEEDBACK=0 still suppresses the section ---------------
# Confirms the env opt-out remains the documented escape hatch for projects
# that want feedback off-nav.

ROOT4="$TMPDIR_LOCAL/case4"
stage_project "$ROOT4"
write_md "$ROOT4/.orchestrator/feedback/round-1.md" "" "Round 1 SME Feedback"

if INCLUDE_FEEDBACK=0 bash "$NAV_GEN" --root "$ROOT4" >"$TMPDIR_LOCAL/case4.log" 2>&1; then
  if grep -q "^  - Feedback:" "$ROOT4/wiki/mkdocs.yml"; then
    bad "Case 4: INCLUDE_FEEDBACK=0 did NOT suppress Feedback section"
  else
    ok "Case 4: INCLUDE_FEEDBACK=0 suppresses Feedback section as documented"
  fi
else
  bad "Case 4: nav-gen exited non-zero (log: $TMPDIR_LOCAL/case4.log)"
fi

# ---- Case 5: backward compat — no nav_order declared, alphabetical sort ----
# Spec section with three docs, all without nav_order. Should sort alphabetical
# by basename (matching pre-2026-05-08 behavior).

ROOT5="$TMPDIR_LOCAL/case5"
stage_project "$ROOT5"
write_md "$ROOT5/.orchestrator/spec/charlie.md" "" "Charlie"
write_md "$ROOT5/.orchestrator/spec/alpha.md"   "" "Alpha"
write_md "$ROOT5/.orchestrator/spec/bravo.md"   "" "Bravo"

if bash "$NAV_GEN" --root "$ROOT5" >"$TMPDIR_LOCAL/case5.log" 2>&1; then
  POS_A=$(nav_position "alpha"   "$ROOT5/wiki/mkdocs.yml")
  POS_B=$(nav_position "bravo"   "$ROOT5/wiki/mkdocs.yml")
  POS_C=$(nav_position "charlie" "$ROOT5/wiki/mkdocs.yml")
  if [ -n "$POS_A" ] && [ -n "$POS_B" ] && [ -n "$POS_C" ] \
     && [ "$POS_A" -lt "$POS_B" ] && [ "$POS_B" -lt "$POS_C" ]; then
    ok "Case 5: backward compat — undeclared nav_order falls back to alphabetical"
  else
    bad "Case 5: alphabetical fallback broken — alpha@$POS_A bravo@$POS_B charlie@$POS_C"
  fi
else
  bad "Case 5: nav-gen exited non-zero (log: $TMPDIR_LOCAL/case5.log)"
fi

printf 'SUMMARY: test-wiki-nav-order-and-feedback pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: test-wiki-nav-order-and-feedback\n'
  exit 0
fi
exit 1
