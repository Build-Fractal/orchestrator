#!/usr/bin/env bash
# scripts/verify/m019-p00-evaluate-preflight-additivity.sh — AD-7 byte-identical
# preservation check for write-permissions.sh sentinel-scoped overwrite.
#
# Drives a fixture re-run of evaluate-preflight.sh against a preloaded
# settings.json containing orchestrator sentinels + M021 hook + extra user
# allow-list entry, then asserts hook + user entry survive byte-identical.
#
# Exit 0 on pass, 1 on fail. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Create fixture
FIXTURE="$(mktemp -d -t m019-p00-ad7.XXXXXX)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.claude"
mkdir -p "$FIXTURE/scripts"
mkdir -p "$FIXTURE/templates"

# Copy the repo's scripts + templates into the fixture so evaluate-preflight
# can find its helpers. Use recursive copies rather than symlinks to stay
# hermetic on CI filesystems that block symlink writes.
cp -R "$REPO_ROOT/scripts/lib"       "$FIXTURE/scripts/lib"       2>/dev/null || true
cp -R "$REPO_ROOT/scripts/lifecycle" "$FIXTURE/scripts/lifecycle" 2>/dev/null || true
cp -R "$REPO_ROOT/scripts/state"     "$FIXTURE/scripts/state"     2>/dev/null || true
cp -R "$REPO_ROOT/scripts/dispatch"  "$FIXTURE/scripts/dispatch"  2>/dev/null || true
cp -R "$REPO_ROOT/scripts/hooks"     "$FIXTURE/scripts/hooks"     2>/dev/null || true
cp -R "$REPO_ROOT/scripts/util"      "$FIXTURE/scripts/util"      2>/dev/null || true
cp -R "$REPO_ROOT/scripts/knowledge" "$FIXTURE/scripts/knowledge" 2>/dev/null || true
cp -R "$REPO_ROOT/scripts/engine"    "$FIXTURE/scripts/engine"    2>/dev/null || true
cp "$REPO_ROOT/templates/autonomy-defaults.yaml" "$FIXTURE/templates/" 2>/dev/null || true

# Preload .claude/settings.json with sentinels + hook + extra allow entry
cat > "$FIXTURE/.claude/settings.json" <<'SETTINGS_EOF'
{
  "_generated_by": "speckit-orchestrator",
  "_generated_at": "2026-04-01T00:00:00Z",
  "_autonomy_mode": "full",
  "_generated_start": "# BEGIN_ORCHESTRATOR_GENERATED v1",
  "permissions": {
    "defaultMode": "acceptEdits",
    "deny": [
      "Bash(rm -rf /)"
    ],
    "allow": [
      "Read",
      "Write"
    ]
  },
  "_generated_end": "# END_ORCHESTRATOR_GENERATED v1",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash scripts/hooks/pre-bash-shape-guard.sh" }
        ]
      }
    ]
  },
  "_user_added_allow": [
    "Bash(fake-user-added-cmd *)"
  ]
}
SETTINGS_EOF

# Capture pre-run hooks block + user addition
pre_hooks="$(sed -n '/"hooks":/,/^  }/p' "$FIXTURE/.claude/settings.json")"
pre_user="$(sed -n '/"_user_added_allow":/,/^  \]/p' "$FIXTURE/.claude/settings.json")"

# Run evaluate-preflight against the fixture
bash "$FIXTURE/scripts/lifecycle/evaluate-preflight.sh" "$FIXTURE" C \
  >"$FIXTURE/preflight.stdout" 2>"$FIXTURE/preflight.stderr"
preflight_exit=$?
if [ "$preflight_exit" -ne 0 ]; then
  fail "evaluate-preflight exit" "non-zero exit ($preflight_exit); see $FIXTURE/preflight.stderr"
  echo "FAIL: m019-p00-evaluate-preflight-additivity.sh (1 failures)"
  exit 1
fi

# Capture post-run hooks block + user addition
post_hooks="$(sed -n '/"hooks":/,/^  }/p' "$FIXTURE/.claude/settings.json")"
post_user="$(sed -n '/"_user_added_allow":/,/^  \]/p' "$FIXTURE/.claude/settings.json")"

if [ "$pre_hooks" = "$post_hooks" ] && [ -n "$post_hooks" ]; then
  pass "hooks block byte-identical across re-run"
else
  fail "hooks block byte-identical" "pre/post differ or hooks disappeared"
  p_tmp="$(mktemp)"; printf '%s\n' "$pre_hooks" > "$p_tmp"
  q_tmp="$(mktemp)"; printf '%s\n' "$post_hooks" > "$q_tmp"
  diff "$p_tmp" "$q_tmp" >&2 || true
  rm -f "$p_tmp" "$q_tmp"
fi

if [ "$pre_user" = "$post_user" ] && [ -n "$post_user" ]; then
  pass "_user_added_allow byte-identical across re-run"
else
  fail "_user_added_allow byte-identical" "pre/post differ or entry disappeared"
fi

# Confirm the sentinel-scoped block still exists (regenerated, not removed)
if grep -q '_generated_start' "$FIXTURE/.claude/settings.json" && \
   grep -q '_generated_end' "$FIXTURE/.claude/settings.json"; then
  pass "sentinel markers present after re-run"
else
  fail "sentinel markers present" "one or both sentinels missing"
fi

# Confirm hook command reference survived
if grep -q 'pre-bash-shape-guard.sh' "$FIXTURE/.claude/settings.json"; then
  pass "pre-bash-shape-guard.sh hook reference preserved"
else
  fail "pre-bash-shape-guard.sh hook reference" "string missing from post-run file"
fi

# Confirm PreToolUse matcher preserved
if grep -q 'PreToolUse' "$FIXTURE/.claude/settings.json"; then
  pass "PreToolUse matcher preserved"
else
  fail "PreToolUse matcher" "string missing from post-run file"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m019-p00-evaluate-preflight-additivity.sh"
  exit 0
else
  echo "FAIL: m019-p00-evaluate-preflight-additivity.sh ($fail_count failures)"
  exit 1
fi
