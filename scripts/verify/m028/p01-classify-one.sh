#!/usr/bin/env bash
# scripts/verify/m028/p01-classify-one.sh -- Throwaway T01 shim.
#
# Sources scripts/verify/lib/shape-classifier.sh and dispatches a single
# command string through classify_command, printing the verdict verbatim.
#
# Usage: bash scripts/verify/m028/p01-classify-one.sh "<verbatim command>"
#
# This script is intentionally trivial. It exists so that T01 can capture
# the existing M021 classifier verdict for each M028 source event without
# inlining heredocs or compound chains in the calling agent's bash. AD-19
# single-script-file shape: flat file, no nested helpers, no compound
# chains in the body.
#
# Bash 3.2 compatible. POSIX-sh-safe argv handling.

set -u

if [ $# -lt 1 ]; then
  echo "usage: p01-classify-one.sh <verbatim command>" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"

if [ ! -f "$CLASSIFIER" ]; then
  echo "p01-classify-one.sh: classifier missing at ${CLASSIFIER}" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$CLASSIFIER"

classify_command "$1"
