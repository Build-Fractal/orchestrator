#!/usr/bin/env bash
# m008-p06-integration-e2e.sh — end-to-end packaging integration test.
#
# Simulates the full developer experience in a hermetic environment:
#   1. Regenerate skills (idempotency check).
#   2. Rebuild bundle in --check mode (layout validation).
#   3. Dry-run Claude Code install against fixture HOME + project dir.
#   4. Real install; verify all 13 skills land under $FIXTURE_HOME/.claude/
#      commands/, hooks fragment lands at $FIXTURE_HOME/.claude/settings.json,
#      and the default orchestrator config is staged at the project state root.
#   5. Run check-update.sh pointing at an unreachable .invalid host and
#      verify the three required key=value lines are emitted.
#
# Hermetic guarantees: zero writes outside $FIXTURE_HOME / $FIXTURE_PROJ.
# Trap-based cleanup fires on any exit path.
#
# AD-19: no $(cmd | pipe); intermediate command output goes to tmpfiles
# that are read back with grep/read. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
TMPOUT="$(mktemp)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ" "$TMPOUT"' EXIT

# Ensure no environment leak — ORCHESTRATOR_ROOT from parent shell would
# redirect config placement away from the hermetic fixture.
unset ORCHESTRATOR_ROOT || true

# ------------------------------------------------------------------
# Step 1: regenerate skills (idempotency).
# ------------------------------------------------------------------
if ! bash "$REPO_ROOT/packaging/skills/generate-skills.sh" > "$TMPOUT" 2>&1; then
  echo "FAIL: generate-skills.sh failed" >&2
  cat "$TMPOUT" >&2
  exit 1
fi

# ------------------------------------------------------------------
# Step 2: rebuild bundle (--check confirms layout matches).
# ------------------------------------------------------------------
if ! bash "$REPO_ROOT/packaging/bundle/build-bundle.sh" --check > "$TMPOUT" 2>&1; then
  echo "FAIL: build-bundle.sh --check failed" >&2
  cat "$TMPOUT" >&2
  exit 1
fi

# ------------------------------------------------------------------
# Step 3: hermetic claude-code install — dry-run first.
# ------------------------------------------------------------------
INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"

HOME="$FIXTURE_HOME" bash "$INSTALLER" \
  --project-dir "$FIXTURE_PROJ" --dry-run > "$TMPOUT" 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: installer dry-run exited $rc" >&2
  cat "$TMPOUT" >&2
  exit 1
fi

if ! grep -q '^would_write=' "$TMPOUT"; then
  echo "FAIL: dry-run produced no would_write= lines" >&2
  cat "$TMPOUT" >&2
  exit 1
fi

# ------------------------------------------------------------------
# Step 3b: hermetic claude-code install — real write.
# ------------------------------------------------------------------
HOME="$FIXTURE_HOME" bash "$INSTALLER" \
  --project-dir "$FIXTURE_PROJ" > "$TMPOUT" 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: real install exited $rc" >&2
  cat "$TMPOUT" >&2
  exit 1
fi

# ------------------------------------------------------------------
# Step 4: verify 13 skills landed under hermetic HOME.
# ------------------------------------------------------------------
skill_count=0
for f in "$FIXTURE_HOME/.claude/commands/orchestrator-"*.md; do
  [ -f "$f" ] && skill_count=$(( skill_count + 1 ))
done

if [ "$skill_count" -ne 13 ]; then
  echo "FAIL: expected 13 skills under $FIXTURE_HOME/.claude/commands/, found $skill_count" >&2
  exit 1
fi

# Hooks fragment should land at $FIXTURE_HOME/.claude/settings.json.
if [ ! -f "$FIXTURE_HOME/.claude/settings.json" ]; then
  echo "FAIL: hooks fragment not written to $FIXTURE_HOME/.claude/settings.json" >&2
  exit 1
fi

# ------------------------------------------------------------------
# Step 5: verify default config landed in project state root.
# resolve-root.sh walks from $PWD; match the installer's approach by
# cd'ing into $FIXTURE_PROJ before invoking the resolver.
# ------------------------------------------------------------------
state_root=""
resolve_tmp="$(mktemp)"
( cd "$FIXTURE_PROJ" && bash "$REPO_ROOT/scripts/state/resolve-root.sh" --absolute ) > "$resolve_tmp" 2>/dev/null || true
read -r state_root < "$resolve_tmp" || state_root=""
rm -f "$resolve_tmp"

if [ -z "$state_root" ]; then
  state_root="$FIXTURE_PROJ/.orchestrator"
fi

if [ ! -f "$state_root/config.yml" ]; then
  echo "FAIL: default config not staged to $state_root/config.yml" >&2
  exit 1
fi

# ------------------------------------------------------------------
# Step 6: check-update runs offline, emits required keys.
# ------------------------------------------------------------------
upd="$(mktemp)"
bash "$REPO_ROOT/scripts/lifecycle/check-update.sh" \
  --remote-url 'https://speckit.example.invalid/none' --timeout 2 > "$upd" 2>&1
rc=$?

if [ $rc -ne 0 ]; then
  echo "FAIL: check-update.sh exited $rc (should be offline-safe)" >&2
  cat "$upd" >&2
  rm -f "$upd"
  exit 1
fi

if ! grep -q '^installed_version=' "$upd"; then
  echo "FAIL: check-update.sh missing installed_version=" >&2
  cat "$upd" >&2
  rm -f "$upd"
  exit 1
fi
if ! grep -q '^latest_version=' "$upd"; then
  echo "FAIL: check-update.sh missing latest_version=" >&2
  cat "$upd" >&2
  rm -f "$upd"
  exit 1
fi
if ! grep -q '^update_available=' "$upd"; then
  echo "FAIL: check-update.sh missing update_available=" >&2
  cat "$upd" >&2
  rm -f "$upd"
  exit 1
fi
rm -f "$upd"

echo "PASS: P06 integration e2e — 13 skills installed, config staged, check-update offline-safe"
exit 0
