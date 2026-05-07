#!/usr/bin/env bash
# tests/m037-acceptance/p01-feedback-routing.sh — M037 P02 SC-13 acceptance.
#
# Exercises the FR-18 feedback:* routing arm against the fixture corpus
# under tests/fixtures/m037-feedback-routing/. The acceptance battery
# auto-globs `p01-*.sh`; named with the `p01-` prefix to ride the existing
# aggregator without modifying it.
#
#   Case 1 (round-3-sme-feedback) — `# Round 3 SME Feedback` H1 present
#     -> stub title: derives from H1.
#   Case 2 (round-4-no-h1) — no H1 heading
#     -> stub title: falls back to humanized basename (non-empty).
#   Case 3 (will-be-removed) — idempotent removal: create source, run
#     generator, remove source, re-run, assert stub disappears.
#   Case 4 (MIT-01/02 escape-hatch) — pre-existing stub with
#     auto_generated: false MUST survive byte-identical across re-runs.
#
# Spec references: FR-18, US-10, SC-13, MIT-01/02 inheritance from P01/T02.
# Pipeline under test: scripts/wiki/wiki-scan-sources.sh + scripts/wiki/wiki-generate-stubs.sh.
#
# Phase artifact contract: this file contains the literal string
# "auto_generated: false" (M037 P02 plan must-have).
# Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STUBS="$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh"
SCANNER="$PROJECT_ROOT/scripts/wiki/wiki-scan-sources.sh"
FIXTURE_SRC="$PROJECT_ROOT/tests/fixtures/m037-feedback-routing"

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
  printf 'SUMMARY: p01-feedback-routing pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -f "$SCANNER" ]; then
  bad "scanner missing at $SCANNER"
  printf 'SUMMARY: p01-feedback-routing pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -d "$FIXTURE_SRC" ]; then
  bad "fixture corpus missing at $FIXTURE_SRC"
  printf 'SUMMARY: p01-feedback-routing pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

TMPDIR_LOCAL="$(mktemp -d -t m037-p02-t01-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

# ---- stage a synthetic project root ----------------------------------------
# Project layout the stub generator expects:
#   $ROOT/.orchestrator/feedback/*.md       (source files for feedback:* arm)
#   $ROOT/.orchestrator/config.yml          (presence-only, no extra_dirs)
#   $ROOT/scripts/wiki/wiki-generate-stubs.sh (symlinked from project)
#   $ROOT/scripts/wiki/wiki-scan-sources.sh   (symlinked from project)
#   $ROOT/wiki/docs/                        (output target)
#   $ROOT/wiki/mkdocs.yml                   (presence-only stub)

ROOT="$TMPDIR_LOCAL/project"
mkdir -p "$ROOT/.orchestrator/feedback"
mkdir -p "$ROOT/scripts/wiki"
mkdir -p "$ROOT/wiki/docs"
mkdir -p "$ROOT/templates"

# Symlink the scripts so the generator's --root resolution lands them.
ln -s "$STUBS"   "$ROOT/scripts/wiki/wiki-generate-stubs.sh"
ln -s "$SCANNER" "$ROOT/scripts/wiki/wiki-scan-sources.sh"

# Copy the milestone-titles helper (called by the generator; missing-file
# is non-fatal but stage it to keep the smoke clean).
if [ -f "$PROJECT_ROOT/scripts/wiki/wiki-milestone-titles.sh" ]; then
  ln -s "$PROJECT_ROOT/scripts/wiki/wiki-milestone-titles.sh" \
        "$ROOT/scripts/wiki/wiki-milestone-titles.sh"
fi

# Copy the index-cards template so render_landing_cards's nav-fallback path
# does not WARN out (harmless but keeps stderr clean).
if [ -f "$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl" ]; then
  cp "$PROJECT_ROOT/templates/wiki-index-cards.md.tmpl" \
     "$ROOT/templates/wiki-index-cards.md.tmpl"
fi

# Copy fixture feedback files into .orchestrator/feedback/.
cp "$FIXTURE_SRC/round-3-sme-feedback.md" "$ROOT/.orchestrator/feedback/round-3-sme-feedback.md"
cp "$FIXTURE_SRC/round-4-no-h1.md"        "$ROOT/.orchestrator/feedback/round-4-no-h1.md"
cp "$FIXTURE_SRC/will-be-removed.md"      "$ROOT/.orchestrator/feedback/will-be-removed.md"

# Minimal config.yml — required for ORCH dir presence + scanner startup.
cat > "$ROOT/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
type: orchestrator-config
EOF

# wiki/mkdocs.yml — presence-only.
cat > "$ROOT/wiki/mkdocs.yml" <<'EOF'
site_name: Test Fixture
docs_dir: docs
nav:
  - Home: index.md
EOF

# ---- exercise the scanner directly first -----------------------------------
# Asserts the scanner emits feedback:<basename> records for each source file.
SCAN_LOG="$TMPDIR_LOCAL/scan.out"
if bash "$SCANNER" --root "$ROOT" >"$SCAN_LOG" 2>"$TMPDIR_LOCAL/scan.err"; then
  ok "wiki-scan-sources.sh exited 0"
else
  bad "wiki-scan-sources.sh exited non-zero (stderr: $TMPDIR_LOCAL/scan.err)"
fi

if grep -q '^feedback:round-3-sme-feedback|feedback/round-3-sme-feedback.md|' "$SCAN_LOG"; then
  ok "scanner emits feedback:round-3-sme-feedback record"
else
  bad "scanner missing feedback:round-3-sme-feedback record (scan log: $SCAN_LOG)"
fi
if grep -q '^feedback:round-4-no-h1|feedback/round-4-no-h1.md|' "$SCAN_LOG"; then
  ok "scanner emits feedback:round-4-no-h1 record"
else
  bad "scanner missing feedback:round-4-no-h1 record (scan log: $SCAN_LOG)"
fi
if grep -q '^feedback:will-be-removed|feedback/will-be-removed.md|' "$SCAN_LOG"; then
  ok "scanner emits feedback:will-be-removed record"
else
  bad "scanner missing feedback:will-be-removed record (scan log: $SCAN_LOG)"
fi

# ---- run #1 of the stub generator ------------------------------------------
RUN1_LOG="$TMPDIR_LOCAL/run1.log"
if bash "$STUBS" --root "$ROOT" >"$RUN1_LOG" 2>&1; then
  ok "wiki-generate-stubs.sh run #1 exited 0"
else
  bad "wiki-generate-stubs.sh run #1 exited non-zero (log: $RUN1_LOG)"
fi

# ---- assertions on emitted stubs -------------------------------------------
read_stub_title_raw() {
  _f="$1"
  awk '
    BEGIN { state="pre" }
    NR == 1 && $0 == "---" { state="fm"; next }
    state == "fm" && $0 == "---" { exit }
    state == "fm" && $0 ~ /^[[:space:]]*title[[:space:]]*:/ { print; exit }
  ' "$_f" 2>/dev/null
}

# Case 1 — H1-derived title.
STUB_1="$ROOT/wiki/docs/feedback/round-3-sme-feedback.md"
if [ -f "$STUB_1" ]; then
  T_1=$(read_stub_title_raw "$STUB_1")
  case "$T_1" in
    *'Round 3 SME Feedback'*) ok "Case 1: round-3-sme-feedback stub title derives from H1" ;;
    *) bad "Case 1: round-3-sme-feedback stub title is wrong: $T_1" ;;
  esac
else
  bad "Case 1: round-3-sme-feedback stub not emitted at $STUB_1"
fi

# Case 2 — humanized-basename fallback (non-empty title).
STUB_2="$ROOT/wiki/docs/feedback/round-4-no-h1.md"
if [ -f "$STUB_2" ]; then
  T_2=$(read_stub_title_raw "$STUB_2")
  case "$T_2" in
    *'title:'*'""'*|"")
      bad "Case 2: round-4-no-h1 stub title is empty: $T_2" ;;
    *)
      ok "Case 2: round-4-no-h1 stub title falls back to non-empty value: $T_2" ;;
  esac
else
  bad "Case 2: round-4-no-h1 stub not emitted at $STUB_2"
fi

# Case 3 setup — assert will-be-removed stub exists after run #1.
STUB_3="$ROOT/wiki/docs/feedback/will-be-removed.md"
if [ -f "$STUB_3" ]; then
  ok "Case 3 setup: will-be-removed stub emitted on run #1"
else
  bad "Case 3 setup: will-be-removed stub not emitted on run #1"
fi

# ---- Case 4 setup: stage operator-edited stub for MIT-01/02 ----------------
# Replace the auto-generated round-3 stub with the operator-edited fixture
# carrying auto_generated: false. This file MUST survive byte-identical
# across the next generator run.
PROTECTED_STUB="$ROOT/wiki/docs/feedback/round-3-sme-feedback.md"
cp "$FIXTURE_SRC/preexisting-stub.md" "$PROTECTED_STUB"
PROTECTED_BEFORE=$(shasum "$PROTECTED_STUB" | awk '{print $1}')

# ---- Case 3 trigger: remove the source for will-be-removed -----------------
rm -f "$ROOT/.orchestrator/feedback/will-be-removed.md"

# ---- run #2 of the stub generator ------------------------------------------
RUN2_LOG="$TMPDIR_LOCAL/run2.log"
if bash "$STUBS" --root "$ROOT" >"$RUN2_LOG" 2>&1; then
  ok "wiki-generate-stubs.sh run #2 exited 0"
else
  bad "wiki-generate-stubs.sh run #2 exited non-zero (log: $RUN2_LOG)"
fi

# Case 3 — idempotent removal: stub MUST be gone after re-run.
if [ ! -f "$STUB_3" ]; then
  ok "Case 3: will-be-removed stub removed after source deletion + re-run"
else
  bad "Case 3: will-be-removed stub still present after source deletion: $STUB_3"
fi

# Case 4 — protected stub MUST survive byte-identical.
if [ -f "$PROTECTED_STUB" ]; then
  PROTECTED_AFTER=$(shasum "$PROTECTED_STUB" | awk '{print $1}')
  if [ "$PROTECTED_BEFORE" = "$PROTECTED_AFTER" ]; then
    ok "Case 4: auto_generated: false feedback stub preserved byte-identical"
  else
    bad "Case 4: protected feedback stub mutated: before=$PROTECTED_BEFORE after=$PROTECTED_AFTER"
  fi
else
  bad "Case 4: protected feedback stub disappeared from $PROTECTED_STUB"
fi

printf 'SUMMARY: p01-feedback-routing pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: p01-feedback-routing\n'
  exit 0
fi
exit 1
