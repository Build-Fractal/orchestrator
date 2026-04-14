#!/usr/bin/env bash
# scripts/verify/m008-p06-install-claude-code-hermetic.sh
#
# Hermetic integration test for packaging/install/install-claude-code.sh.
# All writes go to mktemp fixture directories -- NEVER the real developer HOME.
#
# Contract:
#   1. --dry-run invocation emits `would_write=` lines for skills + hook
#      config + orchestrator config, and exits 0 without touching disk.
#   2. Real invocation creates $FIXTURE_HOME/.claude/commands/ (skills),
#      writes $FIXTURE_HOME/.claude/settings.json (hooks), stages
#      orchestrator config under $FIXTURE_PROJ/.orchestrator/config.yml,
#      and emits a SUMMARY: line.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"

FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
DRY_OUT="$(mktemp)"
REAL_OUT="$(mktemp)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"; rm -f "$DRY_OUT" "$REAL_OUT"' EXIT

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

# --- 1. Dry-run invocation ---
HOME="$FIXTURE_HOME" bash "$INSTALLER" \
  --project-dir "$FIXTURE_PROJ" --dry-run > "$DRY_OUT" 2>&1
dry_rc=$?
if [ $dry_rc -ne 0 ]; then
  echo "FAIL: dry-run exited $dry_rc" >&2
  cat "$DRY_OUT" >&2
  exit 1
fi

grep -q '^would_write=' "$DRY_OUT"
if [ $? -ne 0 ]; then
  echo "FAIL: dry-run did not emit would_write= lines" >&2
  cat "$DRY_OUT" >&2
  exit 1
fi

grep -q '^SUMMARY:' "$DRY_OUT"
if [ $? -ne 0 ]; then
  echo "FAIL: dry-run did not emit SUMMARY: line" >&2
  cat "$DRY_OUT" >&2
  exit 1
fi

# Dry-run must not create anything on disk.
if [ -d "$FIXTURE_HOME/.claude" ]; then
  echo "FAIL: dry-run created $FIXTURE_HOME/.claude" >&2
  exit 1
fi
if [ -d "$FIXTURE_PROJ/.orchestrator" ]; then
  echo "FAIL: dry-run created $FIXTURE_PROJ/.orchestrator" >&2
  exit 1
fi

# --- 2. Real invocation ---
HOME="$FIXTURE_HOME" bash "$INSTALLER" \
  --project-dir "$FIXTURE_PROJ" > "$REAL_OUT" 2>&1
real_rc=$?
if [ $real_rc -ne 0 ]; then
  echo "FAIL: real install exited $real_rc" >&2
  cat "$REAL_OUT" >&2
  exit 1
fi

grep -q '^SUMMARY:' "$REAL_OUT"
if [ $? -ne 0 ]; then
  echo "FAIL: real install did not emit SUMMARY: line" >&2
  cat "$REAL_OUT" >&2
  exit 1
fi

# Skills directory and settings.json under hermetic HOME.
if [ ! -d "$FIXTURE_HOME/.claude/commands" ]; then
  echo "FAIL: skills dir not created under hermetic HOME" >&2
  ls -la "$FIXTURE_HOME/.claude" >&2 2>/dev/null || true
  exit 1
fi
if [ ! -f "$FIXTURE_HOME/.claude/settings.json" ]; then
  echo "FAIL: settings.json not created under hermetic HOME" >&2
  exit 1
fi

# Orchestrator config under project-dir state root.
if [ ! -f "$FIXTURE_PROJ/.orchestrator/config.yml" ]; then
  echo "FAIL: orchestrator config.yml not staged under project-dir" >&2
  ls -la "$FIXTURE_PROJ" >&2 2>/dev/null || true
  exit 1
fi

# Count at least one skill file to confirm the adapter ran.
skill_count="$(ls "$FIXTURE_HOME/.claude/commands/" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$skill_count" -lt 1 ]; then
  echo "FAIL: no skills registered under hermetic HOME" >&2
  exit 1
fi

echo "PASS: claude-code installer hermetic test (skills=$skill_count)"
exit 0
