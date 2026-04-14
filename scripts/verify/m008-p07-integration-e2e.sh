#!/usr/bin/env bash
# scripts/verify/m008-p07-integration-e2e.sh
# Full P07 onboarding end-to-end integration test.
#
# Story: fresh mktemp project -> init-project.sh -> verify config.yml +
# instruction file + skills installed under hermetic HOME -> inject user
# customizations -> reinit without --force returns 4 with REINIT: ->
# reinit-handler --mode update preserves custom content and user-edited
# config fields -> init --force resets the instruction file.
#
# Hermetic only: HOME and project dir are both mktemp -d fixtures; trap
# cleans up on exit (including failure). Wall-clock budget under 120s
# serves as SC-005 proxy (<5min first task) with generous margin.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

START_TS="$(date +%s)"

# --- Fixture: minimal Node project with GitHub Actions ----------------------
echo '{"name":"e2e-fixture"}' > "$FIXTURE_PROJ/package.json"
mkdir -p "$FIXTURE_PROJ/.github/workflows"
touch "$FIXTURE_PROJ/.github/workflows/ci.yml"

# --- 1. Fresh init -----------------------------------------------------------
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /tmp/p07-e2e.1.out 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: fresh init exited $rc" >&2
  cat /tmp/p07-e2e.1.out >&2
  exit 1
fi

test -f "$FIXTURE_PROJ/CLAUDE.md" \
  || { echo "FAIL: CLAUDE.md missing after fresh init" >&2; exit 1; }
test -f "$FIXTURE_PROJ/.orchestrator/config.yml" \
  || { echo "FAIL: config.yml missing after fresh init" >&2; exit 1; }
test -d "$FIXTURE_HOME/.claude/commands" \
  || { echo "FAIL: skills not registered under hermetic HOME" >&2; ls -la "$FIXTURE_HOME" >&2; exit 1; }

# Assert skills actually landed (not just an empty dir).
skill_count=$(find "$FIXTURE_HOME/.claude/commands" -type f -name '*.md' | wc -l | tr -d ' ')
if [ "$skill_count" -lt 1 ]; then
  echo "FAIL: no skill files installed under $FIXTURE_HOME/.claude/commands" >&2
  exit 1
fi

# Placeholders rendered, detectors reflected.
if grep -q '{{' "$FIXTURE_PROJ/CLAUDE.md"; then
  echo "FAIL: unrendered {{placeholders}} in CLAUDE.md" >&2
  grep '{{' "$FIXTURE_PROJ/CLAUDE.md" >&2
  exit 1
fi
grep -q 'node' "$FIXTURE_PROJ/CLAUDE.md" \
  || { echo "FAIL: detected language not rendered into CLAUDE.md" >&2; exit 1; }
grep -q 'github-actions' "$FIXTURE_PROJ/CLAUDE.md" \
  || { echo "FAIL: detected ci_system not rendered into CLAUDE.md" >&2; exit 1; }

# --- 2. Inject custom content + user-edited config field --------------------
awk '
  /^<!-- BEGIN CUSTOM -->$/ { print; print "E2E_USER_BLOCK: this must survive update."; next }
  { print }
' "$FIXTURE_PROJ/CLAUDE.md" > "$FIXTURE_PROJ/CLAUDE.md.new" \
  && mv -f "$FIXTURE_PROJ/CLAUDE.md.new" "$FIXTURE_PROJ/CLAUDE.md"

grep -q 'E2E_USER_BLOCK' "$FIXTURE_PROJ/CLAUDE.md" \
  || { echo "FAIL: could not inject E2E_USER_BLOCK into CLAUDE.md" >&2; exit 1; }

echo 'user_custom_field: "e2e-must-survive"' >> "$FIXTURE_PROJ/.orchestrator/config.yml"

# --- 3. Reinit without --force: must exit 4 with REINIT: --------------------
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /tmp/p07-e2e.2.out 2>&1
rc=$?
if [ $rc -ne 4 ]; then
  echo "FAIL: second init without --force should exit 4, got $rc" >&2
  cat /tmp/p07-e2e.2.out >&2
  exit 1
fi
grep -q '^REINIT:' /tmp/p07-e2e.2.out \
  || { echo "FAIL: no REINIT: line on second init" >&2; cat /tmp/p07-e2e.2.out >&2; exit 1; }

# --- 4. Reinit update mode: preserves custom + user config field ------------
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/reinit-handler.sh" \
  --project-dir "$FIXTURE_PROJ" --state-root "$FIXTURE_PROJ/.orchestrator" \
  --runtime claude-code --mode update > /tmp/p07-e2e.3.out 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: reinit update exited $rc" >&2
  cat /tmp/p07-e2e.3.out >&2
  exit 1
fi

grep -q 'E2E_USER_BLOCK' "$FIXTURE_PROJ/CLAUDE.md" \
  || { echo "FAIL: custom block lost after reinit update" >&2; cat "$FIXTURE_PROJ/CLAUDE.md" >&2; exit 1; }
grep -q 'user_custom_field: "e2e-must-survive"' "$FIXTURE_PROJ/.orchestrator/config.yml" \
  || { echo "FAIL: user_custom_field lost after reinit update" >&2; cat "$FIXTURE_PROJ/.orchestrator/config.yml" >&2; exit 1; }

# --- 5. --force resets the instruction file ---------------------------------
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code --force > /tmp/p07-e2e.4.out 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: --force init exited $rc" >&2
  cat /tmp/p07-e2e.4.out >&2
  exit 1
fi

if grep -q 'E2E_USER_BLOCK' "$FIXTURE_PROJ/CLAUDE.md"; then
  echo "FAIL: --force did not reset the custom block (E2E_USER_BLOCK still present)" >&2
  exit 1
fi
grep -q '^SUMMARY:' /tmp/p07-e2e.4.out \
  || { echo "FAIL: no SUMMARY line from --force init" >&2; cat /tmp/p07-e2e.4.out >&2; exit 1; }

# --- 6. Wall-clock budget ---------------------------------------------------
END_TS="$(date +%s)"
ELAPSED=$(( END_TS - START_TS ))
if [ "$ELAPSED" -gt 120 ]; then
  echo "FAIL: e2e took ${ELAPSED}s (budget: 120s)" >&2
  exit 1
fi

echo "SUMMARY: fresh-init + reinit-preserves + force-reset (elapsed=${ELAPSED}s, budget=120s, skills=${skill_count})"
echo "PASS: P07 onboarding e2e"
exit 0
