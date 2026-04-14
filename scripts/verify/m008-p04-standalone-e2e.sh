#!/usr/bin/env bash
# m008-p04-standalone-e2e.sh -- end-to-end: full P04 workflow without spec-kit
# Creates a hermetic temp project, runs every P04 script in sequence,
# and asserts each produces the expected shape. Proves SC-004.
set -u

REPO_ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fake a bare git-managed project.
mkdir -p "$TMP/.git"

cd "$TMP"
unset ORCHESTRATOR_ROOT

# 1. resolve-root: brand-new project -> .orchestrator default
root="$(bash "$REPO_ROOT/scripts/state/resolve-root.sh")"
if [[ "$root" != ".orchestrator" ]]; then
  echo "FAIL: step 1 resolve-root returned '$root', expected '.orchestrator'"
  exit 1
fi

# 2. detect-speckit: empty temp project has no spec-kit
speckit_out="$(bash "$REPO_ROOT/scripts/state/detect-speckit.sh")"
if ! echo "$speckit_out" | grep -q '^speckit_installed=false$'; then
  echo "FAIL: step 2 expected speckit_installed=false; got:"
  echo "$speckit_out"
  exit 1
fi
if ! echo "$speckit_out" | grep -q '^integration_mode=disabled$'; then
  echo "FAIL: step 2 expected integration_mode=disabled; got:"
  echo "$speckit_out"
  exit 1
fi

# 3. config-system round-trip
bash "$REPO_ROOT/scripts/state/config-system.sh" set intensity.default Full >/dev/null
got="$(bash "$REPO_ROOT/scripts/state/config-system.sh" get intensity.default)"
if [[ "$got" != "Full" ]]; then
  echo "FAIL: step 3 config round-trip got '$got', expected 'Full'"
  exit 1
fi

# 4. namespace-aliases has at least one mapping.
# This is a documentation tool that scans the orchestrator's own commands/
# directory (shipped with the extension), so it runs against REPO_ROOT,
# not the hermetic project. Proves the mapping emitter works in isolation.
aliases="$(cd "$REPO_ROOT" && bash "$REPO_ROOT/scripts/state/namespace-aliases.sh")"
if ! echo "$aliases" | grep -q 'orchestrator:'; then
  echo "FAIL: step 4 namespace-aliases produced no orchestrator: lines"
  exit 1
fi

# 5. migrate-state skips cleanly when no source
migrate_out="$(bash "$REPO_ROOT/scripts/migrate/migrate-state.sh")"
if ! echo "$migrate_out" | grep -q '^SKIP:'; then
  echo "FAIL: step 5 migrate-state expected SKIP on empty source; got:"
  echo "$migrate_out"
  exit 1
fi

# 6. Config lives under .orchestrator/ (not .specify/orchestrator/)
if [[ ! -f "$TMP/.orchestrator/config.yml" ]]; then
  echo "FAIL: step 6 config.yml not under .orchestrator/"
  exit 1
fi
if [[ -d "$TMP/.specify/orchestrator" ]]; then
  echo "FAIL: step 6 standalone run leaked state to .specify/orchestrator/"
  exit 1
fi

echo "PASS: standalone e2e workflow completed without spec-kit"
exit 0
