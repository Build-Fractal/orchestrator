#!/usr/bin/env bash
# scripts/verify/m008-p06-install-codex-hermetic.sh
#
# Hermetic integration test for packaging/install/install-codex.sh.
# All writes go to mktemp fixture directories -- NEVER the real developer HOME.
#
# Contract:
#   1. --dry-run invocation emits `would_write=` lines and exits 0 without
#      touching disk.
#   2. Real invocation creates $FIXTURE_HOME/.codex/skills/ (skills),
#      writes $FIXTURE_HOME/.codex/config.toml (hooks), stages
#      orchestrator config under $FIXTURE_PROJ/.orchestrator/config.yml,
#      and emits a SUMMARY: line.
#
# Probe relies on ~/.codex presence; we pre-create it inside the fixture HOME
# so the adapter's --probe reports available=true without touching the real
# system.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/packaging/install/install-codex.sh"

FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
DRY_OUT="$(mktemp)"
REAL_OUT="$(mktemp)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"; rm -f "$DRY_OUT" "$REAL_OUT"' EXIT

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

# Pre-create ~/.codex inside the fixture so the adapter's probe passes
# without requiring the `codex` binary on PATH or CODEX_HOME set.
mkdir -p "$FIXTURE_HOME/.codex"

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

# Dry-run must not create anything new in the fixture project.
if [ -d "$FIXTURE_PROJ/.orchestrator" ]; then
  echo "FAIL: dry-run created $FIXTURE_PROJ/.orchestrator" >&2
  exit 1
fi
# Skills dir + config.toml must not exist after dry-run.
if [ -d "$FIXTURE_HOME/.codex/skills" ]; then
  echo "FAIL: dry-run created $FIXTURE_HOME/.codex/skills" >&2
  exit 1
fi
if [ -f "$FIXTURE_HOME/.codex/config.toml" ]; then
  echo "FAIL: dry-run wrote $FIXTURE_HOME/.codex/config.toml" >&2
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

if [ ! -d "$FIXTURE_HOME/.codex/skills" ]; then
  echo "FAIL: codex skills dir not created under hermetic HOME" >&2
  ls -la "$FIXTURE_HOME/.codex" >&2 2>/dev/null || true
  exit 1
fi
if [ ! -f "$FIXTURE_HOME/.codex/config.toml" ]; then
  echo "FAIL: config.toml not written under hermetic HOME" >&2
  exit 1
fi
if [ ! -f "$FIXTURE_PROJ/.orchestrator/config.yml" ]; then
  echo "FAIL: orchestrator config.yml not staged under project-dir" >&2
  ls -la "$FIXTURE_PROJ" >&2 2>/dev/null || true
  exit 1
fi

skill_count="$(ls "$FIXTURE_HOME/.codex/skills/" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$skill_count" -lt 1 ]; then
  echo "FAIL: no skills registered under hermetic HOME" >&2
  exit 1
fi

echo "PASS: codex installer hermetic test (skills=$skill_count)"
exit 0
