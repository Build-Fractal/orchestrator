#!/usr/bin/env bash
# scripts/util/bump-version.sh — single-source version sync for releases.
#
# The orchestrator carries its version in three machine-read places that MUST
# agree for a release to publish cleanly:
#   1. VERSION                          — canonical source; read by build-bundle.sh
#   2. package.json "version"           — checked against the git tag by .github/workflows/release.yml
#   3. packaging/bundle/manifest.yml    — shipped in the npm tarball; surfaced by orchestrator:status
#
# This script is the release SOP: bump all three atomically, or verify they
# agree (--check, for CI / pre-tag pre-flight).
#
# Usage:
#   bump-version.sh <X.Y.Z[-pre]>   Set the version across all three files.
#   bump-version.sh --check          Verify all three agree; exit 1 on drift.
#   bump-version.sh --show           Print the current canonical version.
#
# Bash 3.2 compatible. Idempotent. No network.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

VERSION_FILE="$REPO_ROOT/VERSION"
PKG_JSON="$REPO_ROOT/package.json"
MANIFEST="$REPO_ROOT/packaging/bundle/manifest.yml"

_pkg_version() {
  [ -f "$PKG_JSON" ] || { echo ""; return 0; }
  grep -E '^[[:space:]]*"version"[[:space:]]*:' "$PKG_JSON" | head -1 \
    | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/'
}
_manifest_version() {
  [ -f "$MANIFEST" ] || { echo ""; return 0; }
  grep -E '^version:' "$MANIFEST" | head -1 \
    | sed -E 's/^version:[[:space:]]*"?([^"]*)"?.*/\1/'
}
_version_file() {
  [ -f "$VERSION_FILE" ] || { echo ""; return 0; }
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$VERSION_FILE" | head -n1
}

cmd_show() {
  _version_file
}

cmd_check() {
  local v_file v_pkg v_manifest errors=0
  v_file="$(_version_file)"
  v_pkg="$(_pkg_version)"
  v_manifest="$(_manifest_version)"
  echo "VERSION:      ${v_file:-<missing>}"
  echo "package.json: ${v_pkg:-<missing>}"
  echo "manifest.yml: ${v_manifest:-<missing>}"
  if [ -z "$v_file" ]; then echo "DRIFT: VERSION file missing" >&2; errors=$((errors+1)); fi
  if [ "$v_pkg" != "$v_file" ]; then echo "DRIFT: package.json ($v_pkg) != VERSION ($v_file)" >&2; errors=$((errors+1)); fi
  if [ "$v_manifest" != "$v_file" ]; then echo "DRIFT: manifest.yml ($v_manifest) != VERSION ($v_file)" >&2; errors=$((errors+1)); fi
  if [ "$errors" -gt 0 ]; then
    echo "VERSION-CHECK: FAIL (drift across $errors source(s))" >&2
    return 1
  fi
  echo "VERSION-CHECK: PASS (all three agree: $v_file)"
  return 0
}

cmd_set() {
  local new="$1"
  # Validate X.Y.Z with optional -prerelease suffix.
  if ! printf '%s' "$new" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'; then
    echo "bump-version.sh: '$new' is not a valid semver (expected X.Y.Z or X.Y.Z-pre)" >&2
    return 1
  fi

  # 1. VERSION
  printf '%s\n' "$new" > "$VERSION_FILE"

  # 2. package.json — replace the top-level "version": "..." line. This file
  # has exactly one such line (no dependencies block), so a plain substitution
  # is safe and portable (BSD sed lacks the GNU `0,/re/` address form).
  if [ -f "$PKG_JSON" ]; then
    local tmp="$PKG_JSON.tmp.$$"
    sed -E 's/^([[:space:]]*"version"[[:space:]]*:[[:space:]]*)"[^"]*"/\1"'"$new"'"/' "$PKG_JSON" > "$tmp"
    mv "$tmp" "$PKG_JSON"
  fi

  # 3. manifest.yml — replace the version: line.
  if [ -f "$MANIFEST" ]; then
    local tmp="$MANIFEST.tmp.$$"
    sed -E 's/^version:[[:space:]]*.*/version: "'"$new"'"/' "$MANIFEST" > "$tmp"
    mv "$tmp" "$MANIFEST"
  fi

  echo "bumped to $new:"
  cmd_check
}

case "${1:-}" in
  --check) cmd_check ;;
  --show)  cmd_show ;;
  -h|--help|"")
    grep -E '^# ' "$0" | sed -E 's/^# ?//'
    ;;
  --*) echo "bump-version.sh: unknown flag '$1'" >&2; exit 2 ;;
  *)   cmd_set "$1" ;;
esac
