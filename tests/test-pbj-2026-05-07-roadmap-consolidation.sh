#!/usr/bin/env bash
# tests/test-pbj-2026-05-07-roadmap-consolidation.sh
#
# PBJ-2026-05-07 wiki forward-roadmap consolidation regression suite.
#
# Verifies the consolidation predicate
# (`milestone-summary.md` AND >=1 milestone:* record) triggers correctly
# across four shapes:
#
#   (1) Both inputs present  -> consolidation triggers:
#         - wiki/docs/milestone-summary.md NOT emitted
#         - wiki/docs/milestones/index.md leads with include-markdown
#           of .orchestrator/milestone-summary.md
#         - wiki/mkdocs.yml nav block has NO top-level "Milestone Summary"
#           leaf
#
#   (2) Forward roadmap only -> no consolidation:
#         - wiki/docs/milestone-summary.md IS emitted
#         - nav block has top-level "Milestone Summary" leaf
#         - no Milestones group emitted (there are no milestones)
#
#   (3) Phase tree only      -> no consolidation:
#         - no wiki/docs/milestone-summary.md
#         - wiki/docs/milestones/index.md is bullet-list-only (no
#           include-markdown of milestone-summary.md)
#         - no top-level "Milestone Summary" leaf
#
#   (4) Scope-only milestone -> renders as nav leaf:
#         - M002 with only M002-CONTEXT.md (no ROADMAP, no phases/) appears
#           in nav under Milestones
#         - state-machine sees M002 as state=planning tier=none
#           (auto-skipped — not auto-eligible)
#
# Bash 3.2 compatible. Throwaway fixture protocol — all state under /tmp,
# trap-EXIT cleanup.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

FIXTURE_BOTH="/tmp/pbj-2026-05-07-both-$$"
FIXTURE_SUM="/tmp/pbj-2026-05-07-sum-$$"
FIXTURE_TREE="/tmp/pbj-2026-05-07-tree-$$"
FIXTURE_SCOPED="/tmp/pbj-2026-05-07-scoped-$$"
FIXTURE_SORT="/tmp/pbj-2026-05-08-sort-$$"
trap 'rm -rf "$FIXTURE_BOTH" "$FIXTURE_SUM" "$FIXTURE_TREE" "$FIXTURE_SCOPED" "$FIXTURE_SORT"' EXIT INT TERM

STUBS="$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh"
NAV="$PROJECT_ROOT/scripts/wiki/wiki-generate-nav.sh"
DERIVE="$PROJECT_ROOT/scripts/state/derive-phase.sh"
FIND_ACTIVE="$PROJECT_ROOT/scripts/state/find-active-milestone.sh"

[ -f "$STUBS" ] || { printf 'FAIL: stubs generator missing: %s\n' "$STUBS" >&2; exit 1; }
[ -f "$NAV" ] || { printf 'FAIL: nav generator missing: %s\n' "$NAV" >&2; exit 1; }

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# ---- shared fixture helpers ------------------------------------------------

# scaffold_fixture <fixture-dir>
#   Makes <fixture-dir>/.orchestrator/, <fixture-dir>/wiki/docs/, and a
#   minimal wiki/mkdocs.yml so the nav generator can splice into it. No
#   milestone content yet — caller adds whichever shape is under test.
scaffold_fixture() {
  _f="$1"
  mkdir -p "$_f/.orchestrator" "$_f/wiki/docs" "$_f/scripts" "$_f/templates"
  # Both generators expect $ROOT/scripts/wiki/* to exist alongside the
  # fixture (they invoke the scanner via $ROOT-relative paths). Symlinks
  # mirror the existing M032 PBJ-dogfood test pattern.
  ln -s "$PROJECT_ROOT/scripts/wiki" "$_f/scripts/wiki"
  ln -s "$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl" \
        "$_f/templates/wiki-index-cards.md.tmpl"
  cat > "$_f/wiki/mkdocs.yml" <<'YAML'
site_name: Test Wiki
docs_dir: docs

# >>> auto-nav (auto-generated — do not edit by hand)
# <<< auto-nav end
# >>> custom-nav
# <<< custom-nav end
YAML
}

write_milestone_summary() {
  _f="$1"
  cat > "$_f/.orchestrator/milestone-summary.md" <<'EOF'
# Forward Roadmap

This is the canonical forward-roadmap content authored by the project.

## Closed milestones

- **M001** — initial scaffold

## Upcoming milestones

- **M002** — feature work
- **M003** — polish
EOF
}

write_milestone_tree() {
  _f="$1"
  _mid="$2"
  mkdir -p "$_f/.orchestrator/milestones/$_mid"
  cat > "$_f/.orchestrator/milestones/$_mid/${_mid}-CONTEXT.md" <<EOF
---
status: locked
---

# ${_mid} Context

Scope notes for ${_mid}.
EOF
  cat > "$_f/.orchestrator/milestones/$_mid/${_mid}-ROADMAP.md" <<EOF
# ${_mid} Roadmap

tier: C

## Phases

- [ ] **P01**: phase one
EOF
  mkdir -p "$_f/.orchestrator/milestones/$_mid/phases/P01"
  cat > "$_f/.orchestrator/milestones/$_mid/phases/P01/P01-PLAN.md" <<'EOF'
# P01 Plan

placeholder
EOF
}

write_scope_only_milestone() {
  _f="$1"
  _mid="$2"
  mkdir -p "$_f/.orchestrator/milestones/$_mid"
  cat > "$_f/.orchestrator/milestones/$_mid/${_mid}-CONTEXT.md" <<EOF
---
status: locked
---

# ${_mid} Context

Scope locked but not yet phase-decomposed. No ROADMAP, no phases/.
EOF
}

# ---- (1) Both inputs present — consolidation triggers ---------------------

scaffold_fixture "$FIXTURE_BOTH"
write_milestone_summary "$FIXTURE_BOTH"
write_milestone_tree "$FIXTURE_BOTH" "M001"

bash "$STUBS" --root "$FIXTURE_BOTH" >/dev/null 2>&1 || {
  say_fail "scenario 1: stubs generator returned non-zero"
}
bash "$NAV" --root "$FIXTURE_BOTH" >/dev/null 2>&1 || {
  say_fail "scenario 1: nav generator returned non-zero"
}

if [ ! -f "$FIXTURE_BOTH/wiki/docs/milestone-summary.md" ]; then
  say_pass "scenario 1: top-level milestone-summary.md stub suppressed"
else
  say_fail "scenario 1: wiki/docs/milestone-summary.md still emitted under consolidation (regression)"
fi

if [ -f "$FIXTURE_BOTH/wiki/docs/milestones/index.md" ]; then
  if grep -q 'include-markdown.*milestone-summary.md' \
       "$FIXTURE_BOTH/wiki/docs/milestones/index.md"; then
    say_pass "scenario 1: milestones/index.md includes milestone-summary.md"
  else
    say_fail "scenario 1: milestones/index.md does NOT include milestone-summary.md (consolidation broken)"
  fi
else
  say_fail "scenario 1: milestones/index.md not emitted at all"
fi

if grep -qE '^\s*- "?Milestone Summary"?:' "$FIXTURE_BOTH/wiki/mkdocs.yml"; then
  say_fail "scenario 1: top-level 'Milestone Summary' leaf still in nav (regression)"
else
  say_pass "scenario 1: top-level 'Milestone Summary' leaf suppressed in nav"
fi

if grep -qE '^\s*- Milestones:' "$FIXTURE_BOTH/wiki/mkdocs.yml"; then
  say_pass "scenario 1: 'Milestones' section group still emitted in nav"
else
  say_fail "scenario 1: 'Milestones' section group missing from nav (regression)"
fi

# ---- (2) Forward roadmap only — no consolidation --------------------------

scaffold_fixture "$FIXTURE_SUM"
write_milestone_summary "$FIXTURE_SUM"
# No milestones tree.

bash "$STUBS" --root "$FIXTURE_SUM" >/dev/null 2>&1 || {
  say_fail "scenario 2: stubs generator returned non-zero"
}
bash "$NAV" --root "$FIXTURE_SUM" >/dev/null 2>&1 || {
  say_fail "scenario 2: nav generator returned non-zero"
}

if [ -f "$FIXTURE_SUM/wiki/docs/milestone-summary.md" ]; then
  say_pass "scenario 2: forward-roadmap-only keeps milestone-summary.md stub"
else
  say_fail "scenario 2: milestone-summary.md stub missing (greenfield broken)"
fi

if grep -qE '^\s*- "?Milestone Summary"?:' "$FIXTURE_SUM/wiki/mkdocs.yml"; then
  say_pass "scenario 2: top-level 'Milestone Summary' leaf preserved"
else
  say_fail "scenario 2: top-level 'Milestone Summary' leaf missing (greenfield projects orphan their roadmap)"
fi

# ---- (3) Phase tree only — no consolidation -------------------------------

scaffold_fixture "$FIXTURE_TREE"
write_milestone_tree "$FIXTURE_TREE" "M001"
# No milestone-summary.md.

bash "$STUBS" --root "$FIXTURE_TREE" >/dev/null 2>&1 || {
  say_fail "scenario 3: stubs generator returned non-zero"
}
bash "$NAV" --root "$FIXTURE_TREE" >/dev/null 2>&1 || {
  say_fail "scenario 3: nav generator returned non-zero"
}

if [ ! -f "$FIXTURE_TREE/wiki/docs/milestone-summary.md" ]; then
  say_pass "scenario 3: no milestone-summary.md stub when source absent"
else
  say_fail "scenario 3: stranded milestone-summary.md stub emitted"
fi

if [ -f "$FIXTURE_TREE/wiki/docs/milestones/index.md" ]; then
  if grep -q 'include-markdown.*milestone-summary.md' \
       "$FIXTURE_TREE/wiki/docs/milestones/index.md"; then
    say_fail "scenario 3: milestones/index.md tries to include nonexistent milestone-summary.md"
  else
    say_pass "scenario 3: milestones/index.md is bullet-list-only when no milestone-summary.md"
  fi
else
  say_fail "scenario 3: milestones/index.md not emitted at all"
fi

# ---- (4) Scope-only milestone — renders as nav leaf -----------------------

scaffold_fixture "$FIXTURE_SCOPED"
write_milestone_tree "$FIXTURE_SCOPED" "M001"
write_scope_only_milestone "$FIXTURE_SCOPED" "M002"

bash "$STUBS" --root "$FIXTURE_SCOPED" >/dev/null 2>&1 || {
  say_fail "scenario 4: stubs generator returned non-zero"
}
bash "$NAV" --root "$FIXTURE_SCOPED" >/dev/null 2>&1 || {
  say_fail "scenario 4: nav generator returned non-zero"
}

if [ -f "$FIXTURE_SCOPED/wiki/docs/milestones/M002/M002-CONTEXT.md" ]; then
  say_pass "scenario 4: scope-only M002 CONTEXT stub emitted"
else
  say_fail "scenario 4: scope-only M002 CONTEXT stub missing"
fi

if grep -qE 'milestones/M002/M002-CONTEXT\.md$' "$FIXTURE_SCOPED/wiki/mkdocs.yml"; then
  say_pass "scenario 4: scope-only M002 appears in nav"
else
  say_fail "scenario 4: scope-only M002 not present in nav block"
fi

# State-machine: scope-only milestone should resolve to state=planning.
M002_STATE=$(bash "$DERIVE" "$FIXTURE_SCOPED/.orchestrator/milestones/M002" 2>/dev/null)
if [ "$M002_STATE" = "planning" ]; then
  say_pass "scenario 4: derive-phase.sh returns 'planning' for scope-only M002"
else
  say_fail "scenario 4: derive-phase.sh returned '$M002_STATE' (expected 'planning')"
fi

# State-machine: --milestone M002 should reject as tier none (not Tier C).
if bash "$FIND_ACTIVE" "$FIXTURE_SCOPED/.orchestrator" --milestone M002 >/dev/null 2>&1; then
  say_fail "scenario 4: find-active-milestone.sh accepted scope-only M002 (auto loop would pick it up)"
else
  say_pass "scenario 4: find-active-milestone.sh rejects scope-only M002 (correctly auto-skipped)"
fi

# ---- (5) Mixed numeric + dash-prefixed milestone IDs sort numeric-first ----
#
# PBJ-2026-05-08: when a project introduces a non-numeric milestone ID (e.g.
# `M-Spike-A` for a parallel low-priority track), the lexical sort in
# wiki-generate-nav.sh used to put it ahead of `M001` because `-` (0x2D)
# precedes `0` (0x30). Two-bucket fix: numeric-prefixed IDs (^M[0-9]) sort
# first by version-compare; non-numeric IDs sort lex after.

scaffold_fixture "$FIXTURE_SORT"
write_milestone_tree "$FIXTURE_SORT" "M001"
write_milestone_tree "$FIXTURE_SORT" "M002"
write_scope_only_milestone "$FIXTURE_SORT" "M-Spike-A"
write_scope_only_milestone "$FIXTURE_SORT" "M-Spike-B"

bash "$STUBS" --root "$FIXTURE_SORT" >/dev/null 2>&1 || {
  say_fail "scenario 5: stubs generator returned non-zero"
}
bash "$NAV" --root "$FIXTURE_SORT" >/dev/null 2>&1 || {
  say_fail "scenario 5: nav generator returned non-zero"
}

# Extract the leaf order under the Milestones group from the rendered nav.
# Each milestone surfaces a line like `      - M001 — title: milestones/M001/...`
# (or just the ID for scope-only milestones). The first id-token after each
# `      - ` under the Milestones group is what we want to compare.
ORDER=$(awk '
  /^  - Milestones:/ { in_ms = 1; next }
  in_ms && /^  - [A-Z]/ { exit }                                # next top-level group
  in_ms && /^    - / {
    sub(/^    - "?/, "")
    sub(/[":].*$/, "")
    sub(/ —.*$/, "")
    sub(/[ \t]+$/, "")
    if ($0 != "") print $0
  }
' "$FIXTURE_SORT/wiki/mkdocs.yml" | tr '\n' ' ' | sed 's/ *$//')

EXPECTED="Overview M001 M002 M-Spike-A M-Spike-B"
if [ "$ORDER" = "$EXPECTED" ]; then
  say_pass "scenario 5: numeric IDs sort ahead of dash-prefixed IDs in nav"
else
  say_fail "scenario 5: nav order mismatch — got [$ORDER], expected [$EXPECTED]"
fi

# Also assert a bucket-B-with-one-entry case doesn't break the awk pipeline:
# scenario 4 (M001 numeric + M002 numeric scope-only) covers numeric-only;
# scenario 5 above covers mixed; this assertion confirms a single non-numeric
# entry alone still renders. (Reuses FIXTURE_SORT — re-running on a subset
# would require a sixth fixture; instead we just assert M-Spike-A's nav leaf
# was actually emitted, not just that ordering is correct.)
if grep -qE 'milestones/M-Spike-A/M-Spike-A-CONTEXT\.md$' "$FIXTURE_SORT/wiki/mkdocs.yml"; then
  say_pass "scenario 5: dash-prefixed M-Spike-A renders as nav leaf"
else
  say_fail "scenario 5: dash-prefixed M-Spike-A missing from nav (pipeline broken on non-numeric ID)"
fi

# ---- summary ---------------------------------------------------------------

printf 'SUMMARY: pbj-2026-05-07-roadmap-consolidation pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
