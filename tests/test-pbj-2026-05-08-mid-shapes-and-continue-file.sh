#!/usr/bin/env bash
# tests/test-pbj-2026-05-08-mid-shapes-and-continue-file.sh
#
# PBJ-2026-05-08 wiki regressions surfaced by PBJ-central:
#
#   (A) Forward milestones M2a / M2b / M3 / M-Spike-A render in the wiki nav
#       as bare IDs even though their H1 titles are perfect. Root cause:
#       wiki-milestone-titles.sh's bulk-collect pass filtered by `M[0-9]{3}`
#       in three sites — only 3-digit numeric IDs survived collection. The
#       --get path worked correctly, masking the gap.
#
#       Fix: broaden the ID-shape regex to match the same spec used by the
#       nav-sort two-bucket invariant (commit 9570e71e):
#         numeric:     ^M[0-9]+[a-z]*    (M001, M2a, M3, ...)
#         dash-prefix: ^M-[A-Za-z0-9-]+  (M-Spike-A, ...)
#
#       Same broadening required in wiki-generate-stubs.sh (section_title_for,
#       section_include_for, MILESTONES_SEEN/ARCHIVE_SEEN awk regex) and
#       wiki-generate-nav.sh (milestone_artifact_label).
#
#   (B) Orchestrator-internal `continue.md` (frontmatter `type: continue-file`)
#       leaks into the wiki tree because the scanner walks every .md under
#       .orchestrator/milestones/<MID>/. Same exclusion class as the d6dcf2d8
#       feedback nav-arm fix — the orchestrator owns its runtime artifacts;
#       the wiki must not project them.
#
#       Fix: wiki-scan-sources.sh excludes basename `continue.md` (fast path)
#       AND any frontmatter `type: continue-file` (durable contract).
#
# Test cases:
#   1. wiki-milestone-titles.sh bulk lookup includes M001, M2a, M-Spike-A
#   2. strip_title cleans both numeric and dash-prefix shapes (verified via
#      end-to-end output: M001 — Architectural ..., M2a — Risk surfacing ...,
#      M-Spike-A — Automation ...)
#   3. M2a-CONTEXT.md renders in nav as "Context" (not "M2a-CONTEXT")
#   4. continue.md is excluded from stubs/nav (basename arm)
#   5. A foo.md with frontmatter `type: continue-file` is also excluded
#      (frontmatter arm — durable contract)
#
# Bash 3.2 + POSIX sh compatible. Throwaway fixture protocol.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NAV_GEN="$PROJECT_ROOT/scripts/wiki/wiki-generate-nav.sh"
STUBS="$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh"
TITLES="$PROJECT_ROOT/scripts/wiki/wiki-milestone-titles.sh"
SCANNER="$PROJECT_ROOT/scripts/wiki/wiki-scan-sources.sh"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

for required in "$NAV_GEN" "$STUBS" "$TITLES" "$SCANNER"; do
  if [ ! -f "$required" ]; then
    say_fail "required script missing: $required"
    printf 'SUMMARY: pbj-2026-05-08-mid-shapes pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
  fi
done

FIXTURE="/tmp/pbj-2026-05-08-mid-shapes-$$"
trap 'rm -rf "$FIXTURE"' EXIT INT TERM

scaffold() {
  _f="$1"
  mkdir -p "$_f/.orchestrator" "$_f/wiki/docs" "$_f/scripts" "$_f/templates"
  ln -s "$PROJECT_ROOT/scripts/wiki" "$_f/scripts/wiki"
  if [ -f "$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl" ]; then
    ln -s "$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl" \
          "$_f/templates/wiki-index-cards.md.tmpl"
  fi
  cat > "$_f/wiki/mkdocs.yml" <<'YAML'
site_name: Test Wiki
docs_dir: docs

# >>> auto-nav (auto-generated — do not edit by hand)
# <<< auto-nav end
# >>> custom-nav
# <<< custom-nav end
YAML
}

write_milestone_with_h1() {
  _f="$1"
  _mid="$2"
  _h1="$3"
  mkdir -p "$_f/.orchestrator/milestones/$_mid"
  cat > "$_f/.orchestrator/milestones/$_mid/${_mid}-CONTEXT.md" <<EOF
---
status: locked
---

# $_h1

Scope notes for ${_mid}.
EOF
}

write_continue_file() {
  _f="$1"
  _mid="$2"
  cat > "$_f/.orchestrator/milestones/$_mid/continue.md" <<EOF
---
schema_version: "1.0"
type: continue-file
milestone: "$_mid"
phase: "P01"
task: "T01"
step: 1
saved_at: "2026-04-29T19:35:00Z"
reason: "human_gate_pending_BG-002_signoff"
pause_count: 2
---

placeholder body — orchestrator runtime state.
EOF
}

# A file with a non-standard basename that nonetheless declares `type:
# continue-file` in its frontmatter. Tests the durable frontmatter arm.
write_runtime_typed_file() {
  _f="$1"
  _mid="$2"
  cat > "$_f/.orchestrator/milestones/$_mid/notes-runtime.md" <<EOF
---
schema_version: "1.0"
type: continue-file
milestone: "$_mid"
---

# Some notes

This file has a non-standard basename but declares the runtime type
in its frontmatter. The wiki must NOT project it.
EOF
}

# ---- scaffold + populate ---------------------------------------------------

scaffold "$FIXTURE"
write_milestone_with_h1 "$FIXTURE" "M001"      "M001 — Architectural Context"
write_milestone_with_h1 "$FIXTURE" "M2a"       "M2a — Risk surfacing (validation + risk/fix UX)"
write_milestone_with_h1 "$FIXTURE" "M-Spike-A" "M-Spike-A: Automation reconciliation discovery"

# Drop a continue.md and a runtime-typed file under M001 to test exclusion.
write_continue_file "$FIXTURE" "M001"
write_runtime_typed_file "$FIXTURE" "M001"

# ---- Case 1: bulk lookup includes all three IDs ----------------------------

LOOKUP="/tmp/pbj-2026-05-08-titles-$$.tsv"
trap 'rm -rf "$FIXTURE" "$LOOKUP"' EXIT INT TERM
bash "$TITLES" --root "$FIXTURE" > "$LOOKUP" 2>/dev/null || true

LINES=$(wc -l < "$LOOKUP" | tr -d ' ')
if [ "$LINES" -ge 3 ]; then
  say_pass "Case 1a: bulk lookup emits >= 3 lines (got $LINES)"
else
  say_fail "Case 1a: bulk lookup emits only $LINES lines (expected >= 3)"
  cat "$LOOKUP" >&2
fi

for _id in M001 M2a M-Spike-A; do
  if grep -qE "^${_id}	" "$LOOKUP"; then
    say_pass "Case 1b: $_id present in bulk lookup"
  else
    say_fail "Case 1b: $_id MISSING from bulk lookup (collection regex too narrow)"
  fi
done

# ---- Case 2: strip_title cleans both numeric + dash-prefix shapes ---------
# strip_title is exercised end-to-end through the lookup output. The H1s
# include the MID prefix; after strip_title the lookup column 2 must be the
# clean title.

EXPECTED_M001='Architectural Context'
EXPECTED_M2A='Risk surfacing (validation + risk/fix UX)'
EXPECTED_MSPIKE='Automation reconciliation discovery'

GOT_M001=$(awk -F'\t' '$1 == "M001" { print $2; exit }' "$LOOKUP")
GOT_M2A=$(awk -F'\t' '$1 == "M2a" { print $2; exit }' "$LOOKUP")
GOT_MSPIKE=$(awk -F'\t' '$1 == "M-Spike-A" { print $2; exit }' "$LOOKUP")

if [ "$GOT_M001" = "$EXPECTED_M001" ]; then
  say_pass "Case 2a: strip_title cleans 3-digit numeric shape (M001 — ... -> '$EXPECTED_M001')"
else
  say_fail "Case 2a: M001 strip wrong — got '$GOT_M001' expected '$EXPECTED_M001'"
fi

if [ "$GOT_M2A" = "$EXPECTED_M2A" ]; then
  say_pass "Case 2b: strip_title cleans short numeric+suffix shape (M2a — ... -> '$EXPECTED_M2A')"
else
  say_fail "Case 2b: M2a strip wrong — got '$GOT_M2A' expected '$EXPECTED_M2A'"
fi

if [ "$GOT_MSPIKE" = "$EXPECTED_MSPIKE" ]; then
  say_pass "Case 2c: strip_title cleans dash-prefix shape (M-Spike-A: ... -> '$EXPECTED_MSPIKE')"
else
  say_fail "Case 2c: M-Spike-A strip wrong — got '$GOT_MSPIKE' expected '$EXPECTED_MSPIKE'"
fi

# ---- Case 3: M2a-CONTEXT.md renders in nav as "Context" -------------------

bash "$STUBS" --root "$FIXTURE" >/tmp/pbj-2026-05-08-stubs-$$.log 2>&1 || {
  say_fail "Case 3 prep: stubs generator returned non-zero"
  cat /tmp/pbj-2026-05-08-stubs-$$.log >&2
}
bash "$NAV_GEN" --root "$FIXTURE" >/tmp/pbj-2026-05-08-nav-$$.log 2>&1 || {
  say_fail "Case 3 prep: nav generator returned non-zero"
  cat /tmp/pbj-2026-05-08-nav-$$.log >&2
}
rm -f /tmp/pbj-2026-05-08-stubs-$$.log /tmp/pbj-2026-05-08-nav-$$.log

MKDOCS="$FIXTURE/wiki/mkdocs.yml"

# Look for `- Context: milestones/M2a/M2a-CONTEXT.md` in the nav block.
if grep -qE '^[[:space:]]+-[[:space:]]+Context:[[:space:]]+milestones/M2a/M2a-CONTEXT\.md$' "$MKDOCS"; then
  say_pass "Case 3a: M2a-CONTEXT.md renders as 'Context' in nav (not 'M2a-CONTEXT')"
else
  say_fail "Case 3a: M2a child label not 'Context' — milestone_artifact_label regex too narrow"
  grep -nE 'M2a' "$MKDOCS" >&2 || true
fi

# Same for M-Spike-A.
if grep -qE '^[[:space:]]+-[[:space:]]+Context:[[:space:]]+milestones/M-Spike-A/M-Spike-A-CONTEXT\.md$' "$MKDOCS"; then
  say_pass "Case 3b: M-Spike-A-CONTEXT.md renders as 'Context' in nav"
else
  say_fail "Case 3b: M-Spike-A child label not 'Context' — dash-prefix shape unhandled"
  grep -nE 'M-Spike-A' "$MKDOCS" >&2 || true
fi

# Bonus: the milestone group label should be "M2a — Risk surfacing ..." not bare "M2a".
if grep -qE '^[[:space:]]+-[[:space:]]+"?M2a — Risk surfacing' "$MKDOCS"; then
  say_pass "Case 3c: M2a milestone group renders with resolved title (not bare ID)"
else
  say_fail "Case 3c: M2a group renders as bare ID — wiki-milestone-titles bulk lookup not consulted"
  grep -nE 'M2a' "$MKDOCS" >&2 || true
fi

# ---- Case 4: continue.md excluded from stubs and nav ----------------------

if [ ! -f "$FIXTURE/wiki/docs/milestones/M001/continue.md" ]; then
  say_pass "Case 4a: continue.md NOT projected to wiki/docs/ tree"
else
  say_fail "Case 4a: orchestrator-internal continue.md leaked into wiki tree"
fi

if grep -qE 'continue\.md' "$MKDOCS"; then
  say_fail "Case 4b: continue.md leaked into nav"
  grep -nE 'continue' "$MKDOCS" >&2
else
  say_pass "Case 4b: continue.md NOT in nav"
fi

# Also confirm the scanner suppresses it at source.
SCAN_OUT="/tmp/pbj-2026-05-08-scan-$$.out"
bash "$SCANNER" --root "$FIXTURE" > "$SCAN_OUT" 2>/dev/null || true
if grep -qE 'continue\.md' "$SCAN_OUT"; then
  say_fail "Case 4c: scanner emitted record for continue.md (basename arm broken)"
else
  say_pass "Case 4c: scanner suppresses continue.md at source (basename arm)"
fi

# ---- Case 5: frontmatter `type: continue-file` excluded regardless of basename --

if grep -qE 'notes-runtime\.md' "$SCAN_OUT"; then
  say_fail "Case 5: scanner emitted record for type:continue-file file (frontmatter arm broken)"
  grep -nE 'notes-runtime' "$SCAN_OUT" >&2
else
  say_pass "Case 5: scanner suppresses type:continue-file file regardless of basename"
fi

if [ ! -f "$FIXTURE/wiki/docs/milestones/M001/notes-runtime.md" ]; then
  say_pass "Case 5b: type:continue-file file NOT projected to wiki/docs/"
else
  say_fail "Case 5b: type:continue-file file leaked to wiki/docs/"
fi

rm -f "$SCAN_OUT"

# ---- summary --------------------------------------------------------------

printf 'SUMMARY: pbj-2026-05-08-mid-shapes-and-continue-file pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
