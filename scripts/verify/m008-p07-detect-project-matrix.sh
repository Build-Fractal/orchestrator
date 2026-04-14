#!/usr/bin/env bash
# scripts/verify/m008-p07-detect-project-matrix.sh
# Matrix check for detect-project.sh across Node, Python, Rust, and GitHub Actions fixtures.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/lifecycle/detect-project.sh"

CLEANUP_DIRS=""
cleanup() {
  for d in $CLEANUP_DIRS; do
    [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT

assert_key_value() {
  # $1 = fixture path, $2 = expected key, $3 = expected value
  out="$(bash "$SCRIPT" --project-dir "$1")"
  line="$(echo "$out" | grep "^$2=")"
  if [ "$line" != "$2=$3" ]; then
    echo "FAIL: expected $2=$3, got: $line" >&2
    echo "$out" >&2
    exit 1
  fi
}

# Node fixture
F1="$(mktemp -d)"; CLEANUP_DIRS="$CLEANUP_DIRS $F1"
echo '{}' > "$F1/package.json"
assert_key_value "$F1" "language" "node"

# Python fixture
F2="$(mktemp -d)"; CLEANUP_DIRS="$CLEANUP_DIRS $F2"
echo '[project]' > "$F2/pyproject.toml"
assert_key_value "$F2" "language" "python"

# Rust fixture
F3="$(mktemp -d)"; CLEANUP_DIRS="$CLEANUP_DIRS $F3"
echo '[package]' > "$F3/Cargo.toml"
assert_key_value "$F3" "language" "rust"

# GitHub Actions fixture
F4="$(mktemp -d)"; CLEANUP_DIRS="$CLEANUP_DIRS $F4"
mkdir -p "$F4/.github/workflows"
touch "$F4/.github/workflows/ci.yml"
assert_key_value "$F4" "ci_system" "github-actions"

echo "PASS: detect-project.sh matrix (node/python/rust/gh-actions)"
