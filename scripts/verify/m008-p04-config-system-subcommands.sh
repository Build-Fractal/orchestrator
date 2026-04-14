#!/usr/bin/env bash
# m008-p04-config-system-subcommands.sh -- get/set/list round-trip
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

# set
bash "$REPO_ROOT/$SCRIPT" set foo bar >/dev/null

# get
got="$(bash "$REPO_ROOT/$SCRIPT" get foo)"
if [[ "$got" != "bar" ]]; then
  echo "FAIL: get after set returned '$got', expected 'bar'"
  exit 1
fi

# list
listed="$(bash "$REPO_ROOT/$SCRIPT" list)"
if ! echo "$listed" | grep -q '^foo=bar$'; then
  echo "FAIL: list did not include 'foo=bar'; got:"
  echo "$listed"
  exit 1
fi

# Idempotent set
bash "$REPO_ROOT/$SCRIPT" set foo bar >/dev/null
listed_again="$(bash "$REPO_ROOT/$SCRIPT" list)"
count="$(echo "$listed_again" | grep -c '^foo=' || true)"
if [[ "$count" != "1" ]]; then
  echo "FAIL: set is not idempotent; foo appears $count times"
  exit 1
fi

echo "PASS: config-system get/set/list round-trip works and set is idempotent"
exit 0
