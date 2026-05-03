#!/usr/bin/env bash
# tools/verify/m036-p04-tier-2-block-not-promoted.sh -- M036 P04 T03.
# FR-18 BLOCK-retention contract verifier: drives ingest-reference.sh
# against a workspace containing only the BLOCK-verdict fixture (staged
# under cms-rule/ so it's actually walked). Asserts:
#   - stdout contains "BLOCKED: <chunk_id> reason=tier-2-fidelity-gate"
#   - stdout does NOT contain "CREATED: <chunk_id>"
#   - no .structured.md sibling exists in the workspace
#   - driver exits 0 (BLOCK is a verdict, not an error)
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/ingest-reference.sh"
FX="$ROOT/tests/fixtures/m036-p04-reference-corpus/_negative/tier-2-block/REF-cms-rule-blocked.md"
fail=0
if [ ! -f "$DRV" ] || [ ! -f "$FX" ]; then
  echo "FAIL: prerequisite missing (DRV=$DRV FX=$FX)"
  echo "SUMMARY: m036-p04-tier-2-block-not-promoted.sh fail=1"
  exit 1
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p04-block.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/cms-rule"
cp "$FX" "$WORK/cms-rule/"
OUT="$(mktemp "${TMPDIR:-/tmp}/m036-p04-block-out.XXXXXX.txt")"
ORCHESTRATOR_ROOT="$ROOT" bash "$DRV" --reference-root "$WORK" --no-index-rebuild > "$OUT" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "PASS: driver exit 0"
else
  echo "FAIL: driver exit $rc (expected 0; BLOCK is verdict not error)"
  fail=$((fail + 1))
fi
if grep -qF -e "BLOCKED:" "$OUT"; then
  if grep -qF -e "reason=tier-2-fidelity-gate" "$OUT"; then
    echo "PASS: stdout contains BLOCKED with tier-2-fidelity-gate reason"
  else
    echo "FAIL: BLOCKED line missing tier-2-fidelity-gate reason"
    fail=$((fail + 1))
  fi
else
  echo "FAIL: stdout missing BLOCKED line"
  fail=$((fail + 1))
fi
if grep -qF -e "CREATED: REF-cms-rule-blocked" "$OUT"; then
  echo "FAIL: stdout contains CREATED for BLOCK-verdict chunk (FR-18 violation)"
  fail=$((fail + 1))
else
  echo "PASS: no CREATED emitted for BLOCK-verdict chunk"
fi
# .structured.md sibling absence (FR-18 invariant).
STRUCT="$WORK/cms-rule/REF-cms-rule-blocked.structured.md"
if [ -f "$STRUCT" ]; then
  echo "FAIL: .structured.md sibling promoted (FR-18 violation): $STRUCT"
  fail=$((fail + 1))
else
  echo "PASS: no .structured.md sibling for BLOCK-verdict chunk"
fi
rm -f "$OUT"
trap - EXIT
rm -rf "$WORK"
echo "SUMMARY: m036-p04-tier-2-block-not-promoted.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
