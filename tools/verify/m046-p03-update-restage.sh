#!/usr/bin/env bash
# tools/verify/m046-p03-update-restage.sh
# M046/P03/T05 -- FR-4: the orchestrator:update re-stage path re-installs the
# orchestrator-do deprecation shim skill.
#
# The `orchestrator:update` command re-stages the bundle from the mutually
# consistent packaging source of truth (manifest.yml skills list +
# build-bundle.sh EXPECTED_SKILLS/EXPECTED_SKILL_NAMES + the staged
# packaging/bundle/skills/ tree). Because orchestrator-do.md is wired into all
# three, a consumer who runs the re-stage path gets the shim skill re-installed
# -- so a not-yet-migrated consumer invoking `orchestrator:do` sees the
# deprecation notice, NOT a missing-command error.
#
# This verifier asserts the shim skill's presence across the three wiring
# surfaces and confirms the bundle is internally consistent via the NON-MUTATING
# `build-bundle.sh --check` gate. It deliberately does NOT run the full
# `build-bundle.sh` build (blanket-copy + manifest version rewrite), because the
# outer auto loop shares this working tree and the build path would touch
# git-tracked packaging state. `--check` validates the same consistency the
# re-stage relies on without mutating anything. (T04 finding: packaging/skills
# vs packaging/bundle/skills is kept in sync by build-bundle.sh's blanket copy;
# --check is the drift detector for that invariant.)
#
# Output: PASS: / FAIL: lines + a final
#   SUMMARY: m046-p03-update-restage.sh pass=N fail=M
# Exit 0 iff fail=0.
#
# Bash 3.2 compatible (MEM001): no declare -A, no process substitution.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$PROJECT_ROOT"

MANIFEST="packaging/bundle/manifest.yml"
SKILL_SRC="packaging/skills/orchestrator-do.md"
BUILD_BUNDLE="packaging/bundle/build-bundle.sh"

pass=0
fail=0
pass() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
fail() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

# --- 1. manifest.yml skills list contains orchestrator-do.md ----------------
if grep -qE '^[[:space:]]*-[[:space:]]*orchestrator-do\.md[[:space:]]*$' "$MANIFEST"; then
  pass "manifest.yml skills list contains orchestrator-do.md"
else
  fail "manifest.yml skills list missing orchestrator-do.md"
fi

# --- 2. source skill exists + is a deprecation shim -------------------------
if [ -f "$SKILL_SRC" ]; then
  pass "source skill exists: $SKILL_SRC"
else
  fail "source skill missing: $SKILL_SRC"
fi
if [ -f "$SKILL_SRC" ] && grep -qi 'deprecat' "$SKILL_SRC"; then
  pass "source skill declares deprecation (contains 'deprecat')"
else
  fail "source skill does not contain 'deprecat'"
fi

# --- 3. build-bundle.sh wires orchestrator-do.md + EXPECTED_SKILLS=14 -------
if grep -q 'orchestrator-do\.md' "$BUILD_BUNDLE"; then
  pass "build-bundle.sh expected-skill set contains orchestrator-do.md"
else
  fail "build-bundle.sh expected-skill set missing orchestrator-do.md"
fi
if grep -qE '^EXPECTED_SKILLS=14$' "$BUILD_BUNDLE"; then
  pass "build-bundle.sh EXPECTED_SKILLS=14"
else
  fail "build-bundle.sh EXPECTED_SKILLS is not 14"
fi

# --- 4. staged bundle skill is present (the re-stage source of truth) -------
if [ -f "packaging/bundle/skills/orchestrator-do.md" ]; then
  pass "staged bundle skill present: packaging/bundle/skills/orchestrator-do.md"
else
  fail "staged bundle skill missing: packaging/bundle/skills/orchestrator-do.md"
fi

# --- 5. NON-MUTATING consistency gate: build-bundle.sh --check exits 0 -------
check_out="$( mktemp -t m046-p03-restage-check.XXXXXX )"
bash "$BUILD_BUNDLE" --check > "$check_out" 2>&1
rc_check=$?
if [ "$rc_check" -eq 0 ]; then
  pass "build-bundle.sh --check exits 0 (manifest / expected-set / staged skills mutually consistent -- re-stage source of truth is coherent)"
else
  fail "build-bundle.sh --check exited $rc_check -- bundle drift would break the update re-stage:"
  sed 's/^/    /' "$check_out"
fi
rm -f "$check_out"

# --- Aggregate --------------------------------------------------------------
printf 'SUMMARY: m046-p03-update-restage.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
