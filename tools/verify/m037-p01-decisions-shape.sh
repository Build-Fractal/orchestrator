#!/usr/bin/env bash
# m037-p01-decisions-shape.sh — phase-suite wrapper around the framework-owned
# decisions-shape-lint verifier. Lets the M037/P01 phase-suite aggregator invoke
# the lint with one fixed call instead of duplicating the path argument across
# every phase that consumes it.
#
# Wraps: scripts/verify/decisions-shape-lint.sh (M037/P01/T03 deliverable).
# Target: .orchestrator/DECISIONS.md (this repo's decision register).
#
# Constraints: MEM001 bash 3.2 + POSIX sh; AD-19 single-script wrapper shape.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERIFIER="$REPO_ROOT/scripts/verify/decisions-shape-lint.sh"
TARGET="$REPO_ROOT/.orchestrator/DECISIONS.md"

if [ ! -x "$VERIFIER" ]; then
    if [ ! -f "$VERIFIER" ]; then
        printf 'FAIL: m037-p01-decisions-shape: verifier not found at %s\n' "$VERIFIER" >&2
        exit 2
    fi
fi

if [ ! -f "$TARGET" ]; then
    printf 'FAIL: m037-p01-decisions-shape: target not found at %s\n' "$TARGET" >&2
    exit 2
fi

bash "$VERIFIER" "$TARGET"
