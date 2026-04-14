#!/usr/bin/env bash
# m008-p04-migrate-state-skip.sh -- migrate refuses to overwrite populated .orchestrator
set -u

SCRIPT="scripts/migrate/migrate-state.sh"

if [[ ! -x "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing or not executable"
  exit 1
fi

REPO_ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.git"
mkdir -p "$TMP/.specify/orchestrator"
echo "src" > "$TMP/.specify/orchestrator/foo.md"

mkdir -p "$TMP/.orchestrator"
echo "dst" > "$TMP/.orchestrator/bar.md"

cd "$TMP"
out="$(bash "$REPO_ROOT/$SCRIPT")"

if ! echo "$out" | grep -q '^SKIP:'; then
  echo "FAIL: expected SKIP: line; got:"
  echo "$out"
  exit 1
fi

# Both dirs must still be intact
if [[ ! -f "$TMP/.specify/orchestrator/foo.md" ]]; then
  echo "FAIL: source disturbed despite SKIP"
  exit 1
fi
if [[ ! -f "$TMP/.orchestrator/bar.md" ]]; then
  echo "FAIL: destination disturbed despite SKIP"
  exit 1
fi

# Also covers "no source" skip path
TMP2="$(mktemp -d)"
mkdir -p "$TMP2/.git"
cd "$TMP2"
out2="$(bash "$REPO_ROOT/$SCRIPT")"
rm -rf "$TMP2"
if ! echo "$out2" | grep -q '^SKIP:'; then
  echo "FAIL: missing-source case did not emit SKIP:; got:"
  echo "$out2"
  exit 1
fi

echo "PASS: migrate-state.sh skips safely on populated dst and missing src"
exit 0
