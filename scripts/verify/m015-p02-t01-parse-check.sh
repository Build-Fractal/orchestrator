#!/usr/bin/env bash
set -eu
for s in \
  scripts/verify/m015-p02-state-tree-migrated.sh \
  scripts/verify/m015-p02-constitution-moved.sh \
  scripts/verify/m015-p02-resolver-no-bridge.sh \
  scripts/verify/m015-p02-resolver-resolves-new.sh \
  scripts/verify/m015-p02-no-stale-state-refs.sh \
  scripts/verify/m015-p02-doctor-clean.sh; do
  test -x "$s" || { echo "FAIL: $s not executable"; exit 1; }
  bash -n "$s" || { echo "FAIL: $s has syntax errors"; exit 1; }
done
echo "PASS: all 6 P02 verify scripts parse and are executable"
