#!/usr/bin/env bash
# scripts/verify/m008-p06-install-cursor-hermetic.sh
#
# Hermetic integration test for packaging/install/install-cursor.sh.
# All writes go to mktemp fixture directories. Cursor is project-scoped.
#
# Contract:
#   1. --dry-run invocation emits `would_write=` lines and exits 0 without
#      touching disk.
#   2. Real invocation creates $FIXTURE_PROJ/.cursor/rules/ (skills), does
#      NOT create any hook settings file (cursor has no hook API), stages
#      orchestrator config under $FIXTURE_PROJ/.orchestrator/config.yml,
#      and emits a SUMMARY: line.
#   3. Probe passes once $FIXTURE_PROJ/.cursor/ exists; we create it to
#      satisfy the adapter's filesystem signal without requiring Cursor
#      env vars.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/packaging/install/install-cursor.sh"

FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
DRY_OUT="$(mktemp)"
REAL_OUT="$(mktemp)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"; rm -f "$DRY_OUT" "$REAL_OUT"' EXIT

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

# Pre-create .cursor/ inside the fixture project so the adapter's probe
# reports available=true without touching the developer's real environment.
mkdir -p "$FIXTURE_PROJ/.cursor"

# --- 0. Missing --project-dir must fail with exit 1 ---
HOME="$FIXTURE_HOME" bash "$INSTALLER" --dry-run > /dev/null 2>&1
rc=$?
if [ $rc -ne 1 ]; then
  echo "FAIL: cursor installer should exit 1 when --project-dir missing (got $rc)" >&2
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

# Dry-run must not create rules dir or orchestrator config.
if [ -d "$FIXTURE_PROJ/.cursor/rules" ]; then
  echo "FAIL: dry-run created $FIXTURE_PROJ/.cursor/rules" >&2
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

# Cursor writes invocable commands + an always-on rule under project-dir (FR-4).
if [ ! -d "$FIXTURE_PROJ/.cursor/commands" ]; then
  echo "FAIL: .cursor/commands dir not created under project-dir (M009 FR-4)" >&2
  ls -la "$FIXTURE_PROJ/.cursor" >&2 2>/dev/null || true
  exit 1
fi
if [ ! -f "$FIXTURE_PROJ/.cursor/rules/orchestrator.md" ]; then
  echo "FAIL: .cursor/rules/orchestrator.md always-on rule not created (M009 FR-4)" >&2
  exit 1
fi
if [ ! -f "$FIXTURE_PROJ/.orchestrator/config.yml" ]; then
  echo "FAIL: orchestrator config.yml not staged under project-dir" >&2
  exit 1
fi

# Cursor MUST NOT touch HOME for hook wiring.
if [ -f "$FIXTURE_HOME/.claude/settings.json" ]; then
  echo "FAIL: cursor installer wrote claude settings.json" >&2
  exit 1
fi
if [ -f "$FIXTURE_HOME/.codex/config.toml" ]; then
  echo "FAIL: cursor installer wrote codex config.toml" >&2
  exit 1
fi

# M009 FR-3: Cursor Hooks v1.7+ are real, so the installer now wires
# beforeShellExecution. Summary must declare hooks_wired=1 and the
# .cursor/hooks.json must reference the staged shape-guard wrapper.
grep -q 'hooks_wired=1' "$REAL_OUT"
if [ $? -ne 0 ]; then
  echo "FAIL: cursor SUMMARY should declare hooks_wired=1 (M009 FR-3)" >&2
  cat "$REAL_OUT" >&2
  exit 1
fi
if [ ! -f "$FIXTURE_PROJ/.cursor/hooks.json" ]; then
  echo "FAIL: .cursor/hooks.json not written (M009 FR-3)" >&2
  exit 1
fi
grep -q 'beforeShellExecution' "$FIXTURE_PROJ/.cursor/hooks.json"
if [ $? -ne 0 ]; then
  echo "FAIL: .cursor/hooks.json missing beforeShellExecution wiring" >&2
  cat "$FIXTURE_PROJ/.cursor/hooks.json" >&2
  exit 1
fi
grep -q 'cursor-before-shell-shape-guard.sh' "$FIXTURE_PROJ/.cursor/hooks.json"
if [ $? -ne 0 ]; then
  echo "FAIL: .cursor/hooks.json does not reference the shape-guard wrapper" >&2
  exit 1
fi

skill_count="$(find "$FIXTURE_PROJ/.cursor/commands" -type f -name 'orchestrator-*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$skill_count" -lt 1 ]; then
  echo "FAIL: no orchestrator commands registered under .cursor/commands/" >&2
  exit 1
fi

echo "PASS: cursor installer hermetic test (skills=$skill_count)"
exit 0
