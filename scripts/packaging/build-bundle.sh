#!/usr/bin/env bash
# scripts/packaging/build-bundle.sh — thin wrapper around packaging/bundle/build-bundle.sh.
#
# The canonical bundle builder lives at packaging/bundle/build-bundle.sh so
# the assembler ships inside the bundle itself. This wrapper is provided
# for scripts/packaging/ parity with generate-skills.sh. All arguments are
# forwarded unchanged.
#
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
exec bash "$REPO_ROOT/packaging/bundle/build-bundle.sh" "$@"
