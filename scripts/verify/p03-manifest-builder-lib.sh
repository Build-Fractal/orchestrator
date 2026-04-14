#!/usr/bin/env bash
set -eu
f="scripts/lib/manifest-builder.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '_MANIFEST_BUILDER_SOURCED' "$f" || { echo "FAIL: double-sourcing guard missing"; exit 1; }
grep -q 'build_manifest_header' "$f" || { echo "FAIL: build_manifest_header missing"; exit 1; }
grep -q 'compute_section_tokens' "$f" || { echo "FAIL: compute_section_tokens missing"; exit 1; }
grep -q 'format_manifest_row' "$f" || { echo "FAIL: format_manifest_row missing"; exit 1; }
echo "PASS: manifest-builder.sh exists with guard and all functions"
