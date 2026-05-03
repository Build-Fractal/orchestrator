#!/usr/bin/env bash
# tests/test-tier-2-extraction-with-gate.sh -- M036 P03 SC-11+SC-12
# acceptance harness. Drives the Tier 2 extraction PASS path and BLOCK
# path against the P03 fixture manifest in a mktemp -d workspace using
# stub-mocked LLM (EXTRACT_TIER_2_DISPATCH) + stub-mocked conversus
# (CONVERSUS_STUB=1 + CONVERSUS_STUB_VERDICT). No live LLM in CI per
# CON-3.
#
# Asserts:
#   PASS leg — .structured.md in chunk-store + pass.md in _extraction-log
#              + unit_close JSONL with task_type=extraction.
#   BLOCK leg — block.md in _extraction-log + .structured.md NOT in
#               chunk-store + BLOCKED: stdout line.
#
# Emits BATTERY: pass=N fail=N skip=N as the last stdout line.
# Exit 0 iff fail=0. Single-script-file shape per AD-19. Bash 3.2.

set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-sc11.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml"

pass=0
fail=0
skip=0
ap() { echo "PASS: $1"; pass=$((pass + 1)); }
af() { echo "FAIL: $1"; fail=$((fail + 1)); }
as() { echo "SKIP: $1"; skip=$((skip + 1)); }

# Sanity: required fixtures present.
for f in canned-structured.md canned-structured-low-fidelity.md sample.md extract-manifest.yaml; do
  if [ -f "$ROOT/tests/fixtures/m036-p03-tier-2/$f" ]; then
    ap "fixture present: $f"
  else
    af "fixture missing: $f"
    echo "BATTERY: pass=$pass fail=$fail skip=$skip"
    exit 1
  fi
done

# ---- PASS leg ----
PASS_REPO="$WORK/pass-repo"
mkdir -p "$PASS_REPO"
cp -R "$ROOT/scripts" "$PASS_REPO/scripts"
cp -R "$ROOT/templates" "$PASS_REPO/templates"
mkdir -p "$PASS_REPO/tests/fixtures/m036-p03-tier-2"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/sample.md"                       "$PASS_REPO/tests/fixtures/m036-p03-tier-2/"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml"           "$PASS_REPO/tests/fixtures/m036-p03-tier-2/"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured.md"            "$PASS_REPO/tests/fixtures/m036-p03-tier-2/"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md" "$PASS_REPO/tests/fixtures/m036-p03-tier-2/"
# Conversus stub adapter resolves _REPO_ROOT relative to its own script
# location (scripts/dispatch/adapters/tool/conversus.sh -> 4 dirs up =
# the workspace), so the gate-result-{pass,block}.md fixtures must also
# be staged in the workspace's tests/fixtures/ for the stub mode lookup
# (see scripts/dispatch/adapters/tool/conversus.sh:354,357).
cp "$ROOT/tests/fixtures/gate-result-pass.md"  "$PASS_REPO/tests/fixtures/"
cp "$ROOT/tests/fixtures/gate-result-block.md" "$PASS_REPO/tests/fixtures/"

set +e
ORCHESTRATOR_ROOT="$PASS_REPO" \
EXTRACT_TIER_2_DISPATCH=stub:pass \
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS \
bash "$PASS_REPO/scripts/knowledge/extract-reference.sh" \
  --manifest "$PASS_REPO/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml" \
  --reference-root "$PASS_REPO/knowledge/reference" \
  --originals-root "$PASS_REPO/_originals" \
  >"$WORK/pass.stdout" 2>"$WORK/pass.stderr"
pass_rc=$?
set -e
if [ "$pass_rc" -eq 0 ]; then ap "PASS leg: driver rc=0"; else af "PASS leg: driver rc=$pass_rc"; fi
if grep -qF -e "EXTRACTED: tier2-fixture-01" "$WORK/pass.stdout"; then ap "PASS leg: stdout EXTRACTED"; else af "PASS leg: stdout missing EXTRACTED"; fi
if grep -qF -e "verdict=PASS" "$WORK/pass.stdout"; then ap "PASS leg: stdout verdict=PASS"; else af "PASS leg: stdout missing verdict=PASS"; fi
if [ -f "$PASS_REPO/knowledge/reference/glossary/REF-glossary-tier2-fixture-01.structured.md" ]; then ap "PASS leg: .structured.md present"; else af "PASS leg: .structured.md missing"; fi
if [ -f "$PASS_REPO/.orchestrator/knowledge/reference/_extraction-log/tier2-fixture-01.pass.md" ]; then ap "PASS leg: pass.md present"; else af "PASS leg: pass.md missing"; fi
JSONL="$PASS_REPO/.orchestrator/execution-log.jsonl"
if [ -f "$JSONL" ] && grep -qF -e '"task_type":"extraction"' "$JSONL"; then ap "PASS leg: unit_close extraction record"; else af "PASS leg: unit_close missing"; fi
if [ -f "$JSONL" ] && grep -qF -e '"cost_usd":' "$JSONL"; then ap "PASS leg: unit_close has cost_usd"; else af "PASS leg: unit_close missing cost_usd"; fi
if [ -f "$JSONL" ] && grep -qF -e '"model":"' "$JSONL"; then ap "PASS leg: unit_close has model"; else af "PASS leg: unit_close missing model"; fi

# ---- BLOCK leg ----
BLOCK_REPO="$WORK/block-repo"
mkdir -p "$BLOCK_REPO"
cp -R "$ROOT/scripts" "$BLOCK_REPO/scripts"
cp -R "$ROOT/templates" "$BLOCK_REPO/templates"
mkdir -p "$BLOCK_REPO/tests/fixtures/m036-p03-tier-2"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/sample.md"                       "$BLOCK_REPO/tests/fixtures/m036-p03-tier-2/"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml"           "$BLOCK_REPO/tests/fixtures/m036-p03-tier-2/"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured.md"            "$BLOCK_REPO/tests/fixtures/m036-p03-tier-2/"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md" "$BLOCK_REPO/tests/fixtures/m036-p03-tier-2/"
# See PASS-leg comment above re: gate-result-{pass,block}.md staging.
cp "$ROOT/tests/fixtures/gate-result-pass.md"  "$BLOCK_REPO/tests/fixtures/"
cp "$ROOT/tests/fixtures/gate-result-block.md" "$BLOCK_REPO/tests/fixtures/"

set +e
ORCHESTRATOR_ROOT="$BLOCK_REPO" \
EXTRACT_TIER_2_DISPATCH=stub:block \
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK \
bash "$BLOCK_REPO/scripts/knowledge/extract-reference.sh" \
  --manifest "$BLOCK_REPO/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml" \
  --reference-root "$BLOCK_REPO/knowledge/reference" \
  --originals-root "$BLOCK_REPO/_originals" \
  >"$WORK/block.stdout" 2>"$WORK/block.stderr"
block_rc=$?
set -e
if [ "$block_rc" -eq 0 ]; then ap "BLOCK leg: driver rc=0"; else af "BLOCK leg: driver rc=$block_rc"; fi
if grep -qF -e "BLOCKED: tier2-fixture-01" "$WORK/block.stdout"; then ap "BLOCK leg: stdout BLOCKED"; else af "BLOCK leg: stdout missing BLOCKED"; fi
if [ -f "$BLOCK_REPO/.orchestrator/knowledge/reference/_extraction-log/tier2-fixture-01.block.md" ]; then ap "BLOCK leg: block.md present"; else af "BLOCK leg: block.md missing"; fi
if [ ! -f "$BLOCK_REPO/knowledge/reference/glossary/REF-glossary-tier2-fixture-01.structured.md" ]; then ap "BLOCK leg: .structured.md NOT in chunk-store"; else af "BLOCK leg: .structured.md was promoted (FR-18 violation)"; fi

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
