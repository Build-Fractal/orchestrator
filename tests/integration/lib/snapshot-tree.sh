#!/usr/bin/env bash
# tests/integration/lib/snapshot-tree.sh -- Reproducible directory tree fingerprint
#
# Emits a stable fingerprint (mtime + size + path, sorted) of every regular
# file under <dir>. Used by the M003/P08 integration test to assert that the
# source fixture is never mutated by the migration pipeline.
#
# Usage: snapshot-tree.sh <dir>
# Stdout: sorted lines of "<mtime> <size> <path>"
# Exit 0 always (empty output when dir is absent).
#
# Bash 3.2 compatible (MEM001).

set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "snapshot-tree.sh: missing <dir> argument" >&2
  exit 1
fi

target="$1"

if [ ! -d "$target" ]; then
  # Return empty fingerprint; caller treats missing dirs as "unchanged".
  exit 0
fi

# macOS stat: -f '%m %z %N' -> mtime(epoch) size(bytes) path
# Sorted for deterministic comparison across runs.
find "$target" -type f -print0 2>/dev/null \
  | xargs -0 stat -f '%m %z %N' 2>/dev/null \
  | sort
