#!/usr/bin/env bash
# tests/m040-acceptance/p03-regen-preservation.sh — M040 follow-up
# (2026-05-09).
#
# Asserts the regen-preservation contract documented in
# specs/040-wiki-readability-decorator/spec.md FR-28:
#
#   1. `*.summary.md` siblings under wiki/docs/ survive the stale-file
#      sweep performed by wiki-generate-stubs.sh::clean_phase().
#      Repro source: PBJ-central 2026-05-09 (44 operator-curated summaries
#      deleted on a single regen).
#
#   2. Operator-authored content between `# >>> custom-nav` and
#      `# <<< custom-nav end` markers in wiki/mkdocs.yml survives the
#      yaml-merge `nav:` namespace overwrite performed by wiki-init.sh.
#      Repro source: same PBJ-central session (one nav line dropped).
#
# Both bugs are silent-data-loss-shaped: consumer notices days later when
# content is missing. This test is the regression gate.
#
# Bash 3.2 + POSIX-sh compatible. Follows the m032-acceptance test pattern
# (copy fixture + git init + git remote add origin).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_SRC="$PROJECT_ROOT/tests/fixtures/m032-fresh-project-fixture"

pass=0
fail=0

ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

if [ ! -d "$FIXTURE_SRC" ]; then
  bad "fixture missing at $FIXTURE_SRC"
  printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---------------------------------------------------------------------------
# Test 1 — wiki-generate-stubs.sh::clean_phase preserves *.summary.md
# ---------------------------------------------------------------------------
# Strategy: stage the fixture, drop a real scanner-known artifact under
# .orchestrator/ (milestone-summary.md) so the scanner emits at least one
# record and clean_phase actually fires, then assert that:
#   (a) `*.summary.md` siblings survive the sweep (the regression gate).
#   (b) An orphaned stub with no scanner counterpart IS swept (proves
#       clean_phase actually ran — guards against tautological pass when
#       the script bails before clean_phase).

TEST1_ROOT="$(mktemp -d -t m040-p03-summary.XXXXXX)"
trap 'rm -rf "$TEST1_ROOT" "$TEST2_ROOT" 2>/dev/null' EXIT INT TERM

cp -R "$FIXTURE_SRC/." "$TEST1_ROOT/"
( cd "$TEST1_ROOT" && git init -q && git remote add origin https://github.com/fixture-owner/m040-p03-summary-fixture.git ) >/dev/null 2>&1

# Symlink the canonical scripts/ tree so subprocess helpers (scanner, nav
# generator, etc.) resolve correctly under $ROOT/scripts/. Without this,
# wiki-generate-stubs.sh exits non-zero before clean_phase fires.
ln -s "$PROJECT_ROOT/scripts" "$TEST1_ROOT/scripts"

# Real scanner-known artifact so the scanner emits at least one record.
mkdir -p "$TEST1_ROOT/.orchestrator"
printf '# Milestone Summary\n\n**M001 — Test**\n' > "$TEST1_ROOT/.orchestrator/milestone-summary.md"

# Pre-populate wiki/docs/ with operator-authored summary siblings + an
# orphan stub. The wiki-generate-stubs.sh script writes its own
# wiki/docs/index.md and may also (re)write milestone-summary.md and
# milestones/index.md from scanner records. Neither of those should sweep
# the summary siblings.
mkdir -p "$TEST1_ROOT/wiki/docs/milestones/M001"
mkdir -p "$TEST1_ROOT/wiki/docs/knowledge"

echo '**What this is:** the project constitution.' > "$TEST1_ROOT/wiki/docs/constitution.summary.md"
echo '**What this is:** M001 milestone summary.' > "$TEST1_ROOT/wiki/docs/milestones/M001/M001.summary.md"
echo '**What this is:** knowledge index summary.' > "$TEST1_ROOT/wiki/docs/knowledge/index.summary.md"

# Orphaned stub: scanner knows nothing about this path; clean_phase MUST
# sweep it. This is the sentinel that proves clean_phase ran.
echo '<!-- Auto-generated, orphan -->' > "$TEST1_ROOT/wiki/docs/orphan-stub.md"

bash "$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh" --root "$TEST1_ROOT" \
  >"$TEST1_ROOT/stubs.stdout" 2>"$TEST1_ROOT/stubs.stderr" || true

# (a) Summary siblings survived the sweep.
if [ -f "$TEST1_ROOT/wiki/docs/constitution.summary.md" ]; then
  ok "constitution.summary.md preserved across regen"
else
  bad "constitution.summary.md DELETED by clean_phase (Bug 1 regressed)"
fi

if [ -f "$TEST1_ROOT/wiki/docs/milestones/M001/M001.summary.md" ]; then
  ok "milestones/M001/M001.summary.md preserved across regen"
else
  bad "milestones/M001/M001.summary.md DELETED by clean_phase (Bug 1 regressed)"
fi

if [ -f "$TEST1_ROOT/wiki/docs/knowledge/index.summary.md" ]; then
  ok "knowledge/index.summary.md preserved across regen"
else
  bad "knowledge/index.summary.md DELETED by clean_phase (Bug 1 regressed)"
fi

# (b) Orphan stub WAS swept — proves clean_phase actually ran (otherwise
# all preservation assertions would pass tautologically).
if [ ! -f "$TEST1_ROOT/wiki/docs/orphan-stub.md" ]; then
  ok "orphan stub swept (clean_phase did run)"
else
  bad "orphan stub NOT swept — clean_phase may not have fired; preservation assertions are tautological"
  echo "---- stubs.stderr ----" >&2
  sed -n '1,40p' "$TEST1_ROOT/stubs.stderr" >&2 || true
  echo "----" >&2
fi

# ---------------------------------------------------------------------------
# Test 2 — wiki-init.sh capture-restores custom-nav region across yaml-merge
# ---------------------------------------------------------------------------
# Strategy: stage fixture, init git remote, pre-stage a wiki/mkdocs.yml that
# carries operator-authored custom-nav content (the bundle's mkdocs.yml ships
# an empty custom-nav region; without the capture-restore wrapper, yaml-merge
# would silently erase the operator content). Run wiki-init.sh and assert the
# operator content survives.

TEST2_ROOT="$(mktemp -d -t m040-p03-nav.XXXXXX)"

cp -R "$FIXTURE_SRC/." "$TEST2_ROOT/"
( cd "$TEST2_ROOT" && git init -q && git remote add origin https://github.com/fixture-owner/m040-p03-nav-fixture.git ) >/dev/null 2>&1

# Symlink scripts/ so subprocess helpers resolve.
ln -s "$PROJECT_ROOT/scripts" "$TEST2_ROOT/scripts"

# Pre-stage a wiki/mkdocs.yml in the consumer-typical mid-life shape: bundle
# scalars present + operator content inside the custom-nav markers.
# wiki-init's PRE_STAGE_NO_OP gate triggers because mkdocs.yml exists, so the
# bundle staging is skipped — but the sed-substitution and yaml-merge steps
# both run, and yaml-merge is the surface under test.
mkdir -p "$TEST2_ROOT/wiki"
cat > "$TEST2_ROOT/wiki/mkdocs.yml" <<'MKDOCS_EOF'
site_name: "Test Project"
site_description: "test"
site_url: ""
repo_url: ""
docs_dir: docs
theme:
  name: material
nav:
# >>> auto-nav (auto-generated — do not edit by hand)
  - Home: index.md
# <<< auto-nav end
# >>> custom-nav
  - How to review this wiki: sme-review-guide.md
  - Operator runbook: operator-runbook.md
# <<< custom-nav end
MKDOCS_EOF

bash "$PROJECT_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$TEST2_ROOT" \
  >"$TEST2_ROOT/wiki-init.stdout" 2>"$TEST2_ROOT/wiki-init.stderr" || true

# Operator-authored custom-nav lines survived. Use grep -F + `--` to keep
# leading-dash patterns from being mistaken for flags.
if grep -qF -- '- How to review this wiki: sme-review-guide.md' "$TEST2_ROOT/wiki/mkdocs.yml"; then
  ok "custom-nav line 1 preserved across yaml-merge"
else
  bad "custom-nav line 1 ERASED by yaml-merge (Bug 2 regressed)"
  echo "---- wiki-init.stderr ----" >&2
  sed -n '1,40p' "$TEST2_ROOT/wiki-init.stderr" >&2 || true
  echo "---- mkdocs.yml ----" >&2
  cat "$TEST2_ROOT/wiki/mkdocs.yml" >&2 || true
  echo "----" >&2
fi

if grep -qF -- '- Operator runbook: operator-runbook.md' "$TEST2_ROOT/wiki/mkdocs.yml"; then
  ok "custom-nav line 2 preserved across yaml-merge"
else
  bad "custom-nav line 2 ERASED by yaml-merge (Bug 2 regressed)"
fi

# Markers themselves survived (the restore must put them back).
if grep -qF '# >>> custom-nav' "$TEST2_ROOT/wiki/mkdocs.yml"; then
  ok "custom-nav start marker preserved"
else
  bad "custom-nav start marker missing — restore did not run"
fi

if grep -qF '# <<< custom-nav end' "$TEST2_ROOT/wiki/mkdocs.yml"; then
  ok "custom-nav end marker preserved"
else
  bad "custom-nav end marker missing — restore did not run"
fi

# Sanity: yaml-merge actually ran (otherwise the test is tautological).
# Look for the yaml-merge diagnostic in stdout.
if grep -qF 'yaml-merge applied' "$TEST2_ROOT/wiki-init.stdout"; then
  ok "yaml-merge ran (the surface under test actually fired)"
else
  bad "yaml-merge did not run — preservation assertions may be tautological"
  echo "---- wiki-init.stdout ----" >&2
  sed -n '1,40p' "$TEST2_ROOT/wiki-init.stdout" >&2 || true
  echo "----" >&2
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
