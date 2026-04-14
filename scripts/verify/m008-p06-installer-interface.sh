#!/usr/bin/env bash
# scripts/verify/m008-p06-installer-interface.sh
#
# Interface-level checks across all three installers. Confirms:
#   * Each installer text contains --dry-run and --force flag parsers.
#   * claude-code and codex exit 2 when HOME is '/'.
#   * cursor exits 1 when --project-dir is omitted.
#   * Each installer emits a SUMMARY: line under --dry-run.
#
# All tests are hermetic: mktemp fixtures for HOME/project-dir, no real HOME
# writes.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CC="$REPO_ROOT/packaging/install/install-claude-code.sh"
CX="$REPO_ROOT/packaging/install/install-codex.sh"
CR="$REPO_ROOT/packaging/install/install-cursor.sh"

FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
OUT="$(mktemp)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"; rm -f "$OUT"' EXIT

fail=0
report_fail() {
  echo "FAIL: $*" >&2
  fail=$((fail + 1))
}

# --- 1. Presence + required-flag text checks ---
for installer in "$CC" "$CX" "$CR"; do
  if [ ! -f "$installer" ]; then
    report_fail "installer missing: $installer"
    continue
  fi
  grep -q -- '--dry-run' "$installer" || report_fail "installer $installer missing --dry-run parser"
  grep -q -- '--force' "$installer" || report_fail "installer $installer missing --force parser"
done

# Cursor additionally needs --project-dir.
grep -q -- '--project-dir' "$CR" || report_fail "install-cursor.sh missing --project-dir parser"

# --- 2. HOME='/' must exit 2 for claude-code and codex ---
# Pre-create .cursor/.codex hints are not needed -- we never get past the HOME guard.
HOME=/ bash "$CC" --project-dir "$FIXTURE_PROJ" --dry-run > "$OUT" 2>&1
rc=$?
if [ "$rc" != "2" ]; then
  report_fail "install-claude-code.sh: HOME='/' expected exit 2, got $rc"
fi

HOME=/ bash "$CX" --project-dir "$FIXTURE_PROJ" --dry-run > "$OUT" 2>&1
rc=$?
if [ "$rc" != "2" ]; then
  report_fail "install-codex.sh: HOME='/' expected exit 2, got $rc"
fi

# Cursor defensive HOME='/' guard also exits 2 (when --project-dir is supplied).
HOME=/ bash "$CR" --project-dir "$FIXTURE_PROJ" --dry-run > "$OUT" 2>&1
rc=$?
if [ "$rc" != "2" ]; then
  report_fail "install-cursor.sh: HOME='/' expected exit 2, got $rc"
fi

# --- 3. Cursor exits 1 when --project-dir omitted ---
HOME="$FIXTURE_HOME" bash "$CR" --dry-run > "$OUT" 2>&1
rc=$?
if [ "$rc" != "1" ]; then
  report_fail "install-cursor.sh: missing --project-dir expected exit 1, got $rc"
fi
grep -q 'FAIL: --project-dir is required' "$OUT" || report_fail "cursor missing --project-dir should surface actionable FAIL: line"

# --- 4. --dry-run must emit SUMMARY: for every installer ---
# Claude Code (uses ~/.claude existence as probe signal).
mkdir -p "$FIXTURE_HOME/.claude"
HOME="$FIXTURE_HOME" bash "$CC" --project-dir "$FIXTURE_PROJ" --dry-run > "$OUT" 2>&1
if [ $? -ne 0 ]; then
  report_fail "install-claude-code.sh --dry-run exited non-zero"
  cat "$OUT" >&2
fi
grep -q '^SUMMARY:' "$OUT" || report_fail "install-claude-code.sh --dry-run missing SUMMARY: line"

# Codex (pre-create ~/.codex so probe passes).
mkdir -p "$FIXTURE_HOME/.codex"
HOME="$FIXTURE_HOME" bash "$CX" --project-dir "$FIXTURE_PROJ" --dry-run > "$OUT" 2>&1
if [ $? -ne 0 ]; then
  report_fail "install-codex.sh --dry-run exited non-zero"
  cat "$OUT" >&2
fi
grep -q '^SUMMARY:' "$OUT" || report_fail "install-codex.sh --dry-run missing SUMMARY: line"

# Cursor (pre-create project .cursor/ for probe).
mkdir -p "$FIXTURE_PROJ/.cursor"
HOME="$FIXTURE_HOME" bash "$CR" --project-dir "$FIXTURE_PROJ" --dry-run > "$OUT" 2>&1
if [ $? -ne 0 ]; then
  report_fail "install-cursor.sh --dry-run exited non-zero"
  cat "$OUT" >&2
fi
grep -q '^SUMMARY:' "$OUT" || report_fail "install-cursor.sh --dry-run missing SUMMARY: line"

# --- Verify no writes leaked to the fixture dirs during dry-runs ---
# Skills should only ever materialize during a real install, not dry-run.
if [ -d "$FIXTURE_HOME/.claude/commands" ]; then
  report_fail "dry-run leaked skills into $FIXTURE_HOME/.claude/commands"
fi
if [ -d "$FIXTURE_HOME/.codex/skills" ]; then
  report_fail "dry-run leaked skills into $FIXTURE_HOME/.codex/skills"
fi
if [ -d "$FIXTURE_PROJ/.cursor/rules" ]; then
  report_fail "dry-run leaked rules into $FIXTURE_PROJ/.cursor/rules"
fi

if [ "$fail" -gt 0 ]; then
  echo "FAIL: installer interface check ($fail failures)" >&2
  exit 1
fi

echo "PASS: installer interface check (flags + exit codes + SUMMARY + hermetic)"
exit 0
