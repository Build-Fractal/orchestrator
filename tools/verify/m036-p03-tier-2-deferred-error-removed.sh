#!/usr/bin/env bash
# tools/verify/m036-p03-tier-2-deferred-error-removed.sh -- M036 P03 T03.
# Drives the driver against a manifest declaring tier:2 + summary_mode:
# auto with EXTRACT_TIER_2_DISPATCH=stub:pass + CONVERSUS_STUB=1 +
# CONVERSUS_STUB_VERDICT=PASS, asserts exit 0 and stdout EXTRACTED:
# (NOT the P02 'P03 not implemented' hard-error). Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-deferred.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
fail=0
cp "$ROOT/tests/fixtures/m036-p03-tier-2/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "tier2-deferred-removed-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2026-05-02"
    version: "test"
    tier: 2
    summary_mode: "auto"
YAML
set +e
ORCHESTRATOR_ROOT="$ROOT" \
EXTRACT_TIER_2_DISPATCH=stub:pass \
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS \
bash "$DRV" --manifest "$WORK/manifest.yaml" \
  --reference-root "$WORK/reference" \
  --originals-root "$WORK/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "PASS: driver exited 0 on tier:2+auto"
else
  echo "FAIL: driver exited $rc on tier:2+auto (expected 0)"
  cat "$WORK/stderr.txt" >&2
  fail=$((fail + 1))
fi
if grep -qF -e "EXTRACTED:" "$WORK/stdout.txt"; then
  echo "PASS: stdout contains EXTRACTED:"
else
  echo "FAIL: stdout missing EXTRACTED:"
  fail=$((fail + 1))
fi
if grep -qF -e "P03 not implemented" "$WORK/stderr.txt"; then
  echo "FAIL: stderr still carries the P02 'P03 not implemented' string"
  fail=$((fail + 1))
else
  echo "PASS: P02 deferred-error string is gone"
fi
echo "SUMMARY: m036-p03-tier-2-deferred-error-removed.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
