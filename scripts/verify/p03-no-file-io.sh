#!/usr/bin/env bash
set -eu
for f in scripts/lib/payload-transforms.sh scripts/lib/manifest-builder.sh; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
echo "PASS: no obvious file I/O in pure transform functions"
