#!/usr/bin/env bash
# tools/verify/m036-p02-tier-2-deferred-error.sh -- M036 P02 T03.
# Drives the driver against a manifest declaring tier:2 + summary_mode:auto.
# Asserts non-zero exit with stderr message naming "P03" + "not implemented".
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-tier2.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

cp "$ROOT/tests/fixtures/m036/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "tier2-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2026-05-02"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 2
    summary_mode: "auto"
YAML

set +e
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WORK/manifest.yaml" \
  --reference-root "$WORK/reference" \
  --originals-root "$WORK/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
rc=$?
set -e

fail=0
if [ "$rc" -eq 0 ]; then
  echo "FAIL: driver exited 0 (expected non-zero for tier:2 + summary_mode:auto)"
  fail=$((fail + 1))
else
  echo "PASS: driver exited non-zero (rc=$rc)"
fi
if grep -qF "P03" "$WORK/stderr.txt"; then
  echo "PASS: stderr names 'P03'"
else
  echo "FAIL: stderr missing 'P03'"
  fail=$((fail + 1))
fi
if grep -qF "not implemented" "$WORK/stderr.txt"; then
  echo "PASS: stderr names 'not implemented'"
else
  echo "FAIL: stderr missing 'not implemented'"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p02-tier-2-deferred-error.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
