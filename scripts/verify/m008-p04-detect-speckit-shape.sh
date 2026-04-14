#!/usr/bin/env bash
# m008-p04-detect-speckit-shape.sh -- detect-speckit.sh emits the required two key=value lines
set -u

SCRIPT="scripts/state/detect-speckit.sh"

if [[ ! -x "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing or not executable"
  exit 1
fi

REPO_ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.git"
cd "$TMP"

out="$(bash "$REPO_ROOT/$SCRIPT")"

line1="$(echo "$out" | sed -n '1p')"
line2="$(echo "$out" | sed -n '2p')"

case "$line1" in
  speckit_installed=true|speckit_installed=false) ;;
  *)
    echo "FAIL: first line '$line1' not speckit_installed=<true|false>"
    exit 1 ;;
esac

case "$line2" in
  integration_mode=enabled|integration_mode=disabled) ;;
  *)
    echo "FAIL: second line '$line2' not integration_mode=<enabled|disabled>"
    exit 1 ;;
esac

echo "PASS: detect-speckit.sh emits canonical two-line key=value output"
exit 0
