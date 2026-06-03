#!/usr/bin/env bash
# tools/verify/m035-p02-bin-entry.sh
# Asserts bin/orchestrator exists, is executable, --version emits the
# package.json version, and the no-args banner names the cohort prefix.
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BIN="$REPO/bin/orchestrator"

pass=0
fail=0

if [ ! -f "$BIN" ]; then
  echo "FAIL: $BIN not found"
  fail=$((fail + 1))
elif [ ! -x "$BIN" ]; then
  echo "FAIL: $BIN not executable"
  fail=$((fail + 1))
else
  echo "PASS: bin/orchestrator exists and is executable"
  pass=$((pass + 1))
fi

# Compare bin --version output to package.json version field.
PKG_VERSION="$(grep -E '^[[:space:]]*"version"[[:space:]]*:' "$REPO/package.json" \
  | head -1 \
  | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"

BIN_VERSION="$(bash "$BIN" --version 2>/dev/null || true)"

if [ "$BIN_VERSION" = "$PKG_VERSION" ] && [ -n "$BIN_VERSION" ]; then
  echo "PASS: bin --version matches package.json version ($BIN_VERSION)"
  pass=$((pass + 1))
else
  echo "FAIL: bin --version='$BIN_VERSION' != package.json version='$PKG_VERSION'"
  fail=$((fail + 1))
fi

# No-args banner names the cohort prefix.
if bash "$BIN" 2>&1 | grep -q 'orchestrator:<cmd>'; then
  echo "PASS: no-args banner names orchestrator:<cmd> cohort prefix (D-RN-3)"
  pass=$((pass + 1))
else
  echo "FAIL: no-args banner missing 'orchestrator:<cmd>' cohort reference"
  fail=$((fail + 1))
fi

# Regression guard (v0.9.4): every package manager installs the bin as a
# SYMLINK (npm node_modules/.bin, Homebrew bin/). The bin must resolve its
# own real path to locate package.json — invoking through a symlink must
# still emit the version. Caught a 0.9.3 defect where $0 was not deref'd.
SYMLINK_TMP="$(mktemp -d)"
ln -s "$BIN" "$SYMLINK_TMP/orchestrator"
SYMLINK_VERSION="$("$SYMLINK_TMP/orchestrator" --version 2>/dev/null || true)"
rm -rf "$SYMLINK_TMP"
if [ "$SYMLINK_VERSION" = "$PKG_VERSION" ] && [ -n "$SYMLINK_VERSION" ]; then
  echo "PASS: bin --version works through a symlink ($SYMLINK_VERSION)"
  pass=$((pass + 1))
else
  echo "FAIL: bin --version through symlink='$SYMLINK_VERSION' != '$PKG_VERSION'"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
