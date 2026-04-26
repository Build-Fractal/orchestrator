#!/usr/bin/env bash
# scripts/verify/m024-p04-config-auto-proceed-key.sh
# Verifies auto_proceed is a valid config key resolved through all four layers.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
READ="$ROOT/scripts/state/read-config.sh"
DEFAULTS="$ROOT/templates/orchestrator-config-default.yml"

[ -x "$READ" ]      || { echo "FAIL: $READ not executable"; exit 1; }
[ -f "$DEFAULTS" ]  || { echo "FAIL: $DEFAULTS not present"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Layer 4 (defaults) — must return true.
v=$(bash "$READ" auto_proceed --defaults "$DEFAULTS")
[ "$v" = "true" ] || { echo "FAIL: defaults layer returned '$v', expected 'true'"; exit 1; }

# Layer 3 (project) override — false wins.
project="$tmp/orchestrator-config.yml"
echo "auto_proceed: false" > "$project"
v=$(bash "$READ" auto_proceed --defaults "$DEFAULTS" --project "$project")
[ "$v" = "false" ] || { echo "FAIL: project layer returned '$v', expected 'false'"; exit 1; }

# Layer 2 (local) override — true wins back.
local_cfg="$tmp/orchestrator-config.local.yml"
echo "auto_proceed: true" > "$local_cfg"
v=$(bash "$READ" auto_proceed --defaults "$DEFAULTS" --project "$project" --local "$local_cfg")
[ "$v" = "true" ] || { echo "FAIL: local layer returned '$v', expected 'true'"; exit 1; }

# Layer 1 (env) override — false wins.
v=$(SPECKIT_ORCHESTRATOR_AUTO_PROCEED=false bash "$READ" auto_proceed --defaults "$DEFAULTS" --project "$project" --local "$local_cfg")
[ "$v" = "false" ] || { echo "FAIL: env layer returned '$v', expected 'false'"; exit 1; }

echo "PASS: read-config.sh — auto_proceed resolves through all four layers (defaults true; project/local/env override)"
exit 0
