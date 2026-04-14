#!/usr/bin/env bash
# generate-skills.sh — thin forwarder to scripts/packaging/generate-skills.sh
#
# The real generator lives at scripts/packaging/generate-skills.sh (so it is
# grouped with all other project scripts under scripts/). A forwarder is kept
# here because the packaging/skills/ directory is the natural discovery
# location alongside the skill files themselves, and the P06 plan and T05
# integration test both invoke `packaging/skills/generate-skills.sh`.

set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
exec "$REPO_ROOT/scripts/packaging/generate-skills.sh" "$@"
