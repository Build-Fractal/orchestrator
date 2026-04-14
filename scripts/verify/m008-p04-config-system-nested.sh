#!/usr/bin/env bash
# m008-p04-config-system-nested.sh -- dot-notation nested keys round-trip
set -u

SCRIPT="scripts/state/config-system.sh"

if [[ ! -x "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing or not executable"
  exit 1
fi

REPO_ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.git"
cd "$TMP"
unset ORCHESTRATOR_ROOT

bash "$REPO_ROOT/$SCRIPT" set intensity.default Full >/dev/null
got="$(bash "$REPO_ROOT/$SCRIPT" get intensity.default)"

if [[ "$got" != "Full" ]]; then
  echo "FAIL: nested key round-trip returned '$got', expected 'Full'"
  exit 1
fi

# Make sure we can store multiple nested keys without cross-contamination
bash "$REPO_ROOT/$SCRIPT" set intensity.override Quick >/dev/null
a="$(bash "$REPO_ROOT/$SCRIPT" get intensity.default)"
b="$(bash "$REPO_ROOT/$SCRIPT" get intensity.override)"

if [[ "$a" != "Full" ]] || [[ "$b" != "Quick" ]]; then
  echo "FAIL: multi-nested key isolation broken; default=$a override=$b"
  exit 1
fi

echo "PASS: dot-notation nested keys store and retrieve independently"
exit 0
