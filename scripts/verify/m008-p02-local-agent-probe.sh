#!/usr/bin/env bash
# Verifies local-agent.sh --probe works and emits available= key.
set -u

f="scripts/dispatch/adapters/backend/local-agent.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Check --probe flag handling exists
grep -q '\-\-probe' "$f" || { echo "FAIL: $f does not handle --probe"; exit 1; }
grep -q 'backend=local-agent' "$f" || { echo "FAIL: $f missing backend=local-agent identifier"; exit 1; }

# Run probe with SPECKIT_AGENT_TOOL=1 — must emit available=true
probe_on="$(SPECKIT_AGENT_TOOL=1 bash "$f" --probe 2>/dev/null)"
echo "$probe_on" | grep -q '^available=true' || { echo "FAIL: probe with SPECKIT_AGENT_TOOL=1 did not emit available=true: $probe_on"; exit 1; }

# Run probe with explicit env disabled and no .claude directory in a scratch dir
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
probe_off="$(cd "$tmp" && SPECKIT_AGENT_TOOL=0 bash "${OLDPWD}/$f" --probe 2>/dev/null || true)"
echo "$probe_off" | grep -q '^available=' || { echo "FAIL: probe in empty dir did not emit available= key"; exit 1; }

echo "PASS: local-agent.sh --probe emits available= and backend=local-agent"
