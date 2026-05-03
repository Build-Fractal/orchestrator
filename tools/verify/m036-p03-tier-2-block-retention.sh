#!/usr/bin/env bash
# tools/verify/m036-p03-tier-2-block-retention.sh -- M036 P03 T03.
# Drives the BLOCK path. Asserts block.md retained, .structured.md NOT
# in chunk-store, BLOCKED: stdout line.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-block.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
fail=0
mkdir -p "$WORK/repo"
cp -R "$ROOT/scripts" "$WORK/repo/scripts"
cp -R "$ROOT/templates" "$WORK/repo/templates"
mkdir -p "$WORK/repo/tests/fixtures/m036-p03-tier-2"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/sample.md" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
if [ -f "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md" ]; then
  cp "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
else
  echo "FAIL: canned-structured-low-fidelity.md missing -- T04 deliverable"
  echo "SUMMARY: m036-p03-tier-2-block-retention.sh fail=1"
  exit 1
fi
# Conversus stub adapter resolves _REPO_ROOT relative to its own script
# location (4 dirs up from scripts/dispatch/adapters/tool/conversus.sh =
# the workspace), so gate-result-{pass,block}.md must also be staged.
cp "$ROOT/tests/fixtures/gate-result-pass.md"  "$WORK/repo/tests/fixtures/"
cp "$ROOT/tests/fixtures/gate-result-block.md" "$WORK/repo/tests/fixtures/"
set +e
ORCHESTRATOR_ROOT="$WORK/repo" \
EXTRACT_TIER_2_DISPATCH=stub:block \
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK \
bash "$WORK/repo/scripts/knowledge/extract-reference.sh" \
  --manifest "$WORK/repo/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml" \
  --reference-root "$WORK/repo/knowledge/reference" \
  --originals-root "$WORK/repo/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "PASS: driver rc=0 on BLOCK"
else
  echo "FAIL: driver rc=$rc on BLOCK (expected 0 -- BLOCK is not a driver error)"
  cat "$WORK/stderr.txt" >&2
  fail=$((fail + 1))
fi
if grep -qF -e "BLOCKED: tier2-fixture-01" "$WORK/stdout.txt"; then
  echo "PASS: stdout BLOCKED: line"
else
  echo "FAIL: stdout missing BLOCKED: line"
  fail=$((fail + 1))
fi
BLOCK_LOG="$WORK/repo/.orchestrator/knowledge/reference/_extraction-log/tier2-fixture-01.block.md"
if [ -f "$BLOCK_LOG" ]; then
  echo "PASS: block.md present"
else
  echo "FAIL: block.md missing at $BLOCK_LOG"
  fail=$((fail + 1))
fi
STRUCT="$WORK/repo/knowledge/reference/glossary/REF-glossary-tier2-fixture-01.structured.md"
if [ -f "$STRUCT" ]; then
  echo "FAIL: .structured.md was promoted on BLOCK (FR-18 violation)"
  fail=$((fail + 1))
else
  echo "PASS: .structured.md NOT in chunk-store (FR-18 invariant)"
fi
echo "SUMMARY: m036-p03-tier-2-block-retention.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
