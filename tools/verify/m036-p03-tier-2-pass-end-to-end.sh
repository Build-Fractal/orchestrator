#!/usr/bin/env bash
# tools/verify/m036-p03-tier-2-pass-end-to-end.sh -- M036 P03 T03.
# Drives the PASS path: stub:pass dispatch + CONVERSUS_STUB_VERDICT=PASS.
# Asserts: .structured.md present in chunk-store, pass.md present in
# _extraction-log, unit_close JSONL appended.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-pass.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml"
fail=0
# Use a per-run ORCHESTRATOR_ROOT so the unit_close lands in WORK, not repo.
mkdir -p "$WORK/repo"
cp -R "$ROOT/scripts" "$WORK/repo/scripts"
cp -R "$ROOT/templates" "$WORK/repo/templates"
mkdir -p "$WORK/repo/tests/fixtures/m036-p03-tier-2"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/sample.md" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
# canned-structured.md authored in T04; check before copying.
if [ -f "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured.md" ]; then
  cp "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured.md" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
else
  echo "FAIL: canned-structured.md missing -- T04 deliverable"
  echo "SUMMARY: m036-p03-tier-2-pass-end-to-end.sh fail=1"
  exit 1
fi
# Conversus stub adapter resolves _REPO_ROOT relative to its own script
# location (4 dirs up from scripts/dispatch/adapters/tool/conversus.sh =
# the workspace), so gate-result-{pass,block}.md must also be staged.
cp "$ROOT/tests/fixtures/gate-result-pass.md"  "$WORK/repo/tests/fixtures/"
cp "$ROOT/tests/fixtures/gate-result-block.md" "$WORK/repo/tests/fixtures/"
set +e
ORCHESTRATOR_ROOT="$WORK/repo" \
EXTRACT_TIER_2_DISPATCH=stub:pass \
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS \
bash "$WORK/repo/scripts/knowledge/extract-reference.sh" \
  --manifest "$WORK/repo/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml" \
  --reference-root "$WORK/repo/knowledge/reference" \
  --originals-root "$WORK/repo/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "FAIL: driver rc=$rc"
  cat "$WORK/stderr.txt" >&2
  fail=$((fail + 1))
else
  echo "PASS: driver rc=0"
fi
STRUCT="$WORK/repo/knowledge/reference/glossary/REF-glossary-tier2-fixture-01.structured.md"
if [ -f "$STRUCT" ]; then
  echo "PASS: structured-md present"
else
  echo "FAIL: structured-md missing at $STRUCT"
  fail=$((fail + 1))
fi
PASS_LOG="$WORK/repo/.orchestrator/knowledge/reference/_extraction-log/tier2-fixture-01.pass.md"
if [ -f "$PASS_LOG" ]; then
  echo "PASS: pass.md present"
else
  echo "FAIL: pass.md missing at $PASS_LOG"
  fail=$((fail + 1))
fi
JSONL="$WORK/repo/.orchestrator/execution-log.jsonl"
if [ -f "$JSONL" ] && grep -qF -e '"task_type":"extraction"' "$JSONL"; then
  echo "PASS: unit_close extraction record appended"
else
  echo "FAIL: unit_close extraction record missing in $JSONL"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p03-tier-2-pass-end-to-end.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
