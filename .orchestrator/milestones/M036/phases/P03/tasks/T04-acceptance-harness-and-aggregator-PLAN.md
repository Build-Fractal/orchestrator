---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M036"
name: "SC-11 + SC-12 acceptance harness + canned-structured fixtures + phase-suite aggregator"
depends_on: ["T03"]
---

## Prerequisites

- T01 closed: preset + M030 amendment + base fixture corpus.
- T02 closed: Tier 2 LLM helper + unit_close emitter.
- T03 closed: Gate helper + driver auto-branch + 6 verifiers.

Verified at plan-authoring time: `scripts/knowledge/lib/extract-tier-2-llm.sh`, `scripts/knowledge/lib/extract-tier-2-gate.sh`, modified `scripts/knowledge/extract-reference.sh`, modified `scripts/knowledge/lib/extract-tier-0-summary.sh`, all 6 T03 verifiers all on disk after T03 close.

## Description

Land the SC-11 + SC-12 acceptance harness `tests/test-tier-2-extraction-with-gate.sh` (mocked LLM + mocked conversus per CON-3), the two canned-structured fixtures referenced by `EXTRACT_TIER_2_DISPATCH=stub:*`, and the P03 phase-suite aggregator `tools/verify/m036-p03-phase-suite.sh` wiring all 14 sub-gates.

## Steps

### Step 1 — Author the canned-structured fixtures

Create `tests/fixtures/m036-p03-tier-2/canned-structured.md` (the **PASS** stub — preserves all section structure from `sample.md`):

```markdown
---
schema_version: "1.0"
type: tier-2-structured-extraction
source: "tests/fixtures/m036-p03-tier-2/sample.md"
extracted_at: "fixture"
---

# Tier 2 Fixture — PBJ Staffing Sample

This is a fixture markdown file used by M036 P03's Tier 2 acceptance
harness. The structured-extraction stub treats this content as if it
were a regulatory document with multiple headings.

## Section 1 — Definitions

- `staff_count`: the number of nursing staff on duty in a measurement window.
- `census`: the number of residents in a facility at a measurement instant.

## Section 2 — Calculation

The hours-per-resident-day metric divides total nursing hours by the
resident census, summed across the measurement window.
```

Create `tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md` (the **BLOCK** stub — drops `Section 1` heading entirely; the conversus stub returns BLOCK for this artifact regardless of content because `CONVERSUS_STUB_VERDICT=BLOCK` is set in the test, but the file is intentionally low-fidelity to make the artifact-level decision auditable):

```markdown
---
schema_version: "1.0"
type: tier-2-structured-extraction
source: "tests/fixtures/m036-p03-tier-2/sample.md"
extracted_at: "fixture-low-fidelity"
---

# Tier 2 Fixture — PBJ Staffing Sample

This is a fixture markdown file (low-fidelity stub for BLOCK-path
testing). Section 1 has been dropped; Section 2's calculation has been
paraphrased rather than preserved verbatim.

## Section 2 (paraphrased)

A staffing metric is computed by dividing nursing hours by census.
```

### Step 2 — Author `tests/test-tier-2-extraction-with-gate.sh`

```bash
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
```

Make it executable: `chmod +x tests/test-tier-2-extraction-with-gate.sh`.

### Step 3 — Author `tools/verify/m036-p03-test-harness.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-test-harness.sh -- M036 P03 T04.
# Asserts the SC-11 acceptance harness exists, executes (rc<=1
# permissive: rc=1 still emits BATTERY in fail mode), and emits a
# well-formed BATTERY: line.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
HARNESS="$ROOT/tests/test-tier-2-extraction-with-gate.sh"
fail=0
if [ -f "$HARNESS" ] && [ -x "$HARNESS" ]; then
  echo "PASS: harness exists+executable"
else
  echo "FAIL: harness missing or non-executable at $HARNESS"
  echo "SUMMARY: m036-p03-test-harness.sh fail=1"
  exit 1
fi
TMP="$(mktemp "${TMPDIR:-/tmp}/m036-p03-harness.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
set +e
bash "$HARNESS" >"$TMP" 2>/dev/null
rc=$?
set -e
if [ "$rc" -le 1 ]; then
  echo "PASS: harness rc=$rc (<=1 permissive)"
else
  echo "FAIL: harness rc=$rc (expected <=1)"
  fail=$((fail + 1))
fi
last="$(tail -n 1 "$TMP")"
case "$last" in
  "BATTERY: pass="*" fail="*" skip="*)
    echo "PASS: BATTERY line shape: $last"
    ;;
  *)
    echo "FAIL: BATTERY line shape unexpected: $last"
    fail=$((fail + 1))
    ;;
esac
echo "SUMMARY: m036-p03-test-harness.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 4 — Author `tools/verify/m036-p03-acceptance-harness-passes.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-acceptance-harness-passes.sh -- M036 P03 T04.
# Asserts the SC-11 acceptance harness exits 0 (fail=0). This is the
# strict pass-rate gate — the test-harness shape verifier above is
# permissive on rc<=1 (covers the rc=1 in-progress shape).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
HARNESS="$ROOT/tests/test-tier-2-extraction-with-gate.sh"
TMP="$(mktemp "${TMPDIR:-/tmp}/m036-p03-acceptance.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
set +e
bash "$HARNESS" >"$TMP" 2>/dev/null
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "PASS: SC-11 + SC-12 acceptance harness rc=0"
  echo "SUMMARY: m036-p03-acceptance-harness-passes.sh fail=0"
  exit 0
fi
echo "FAIL: SC-11 + SC-12 acceptance harness rc=$rc"
tail -n 5 "$TMP" >&2
echo "SUMMARY: m036-p03-acceptance-harness-passes.sh fail=1"
exit 1
```

### Step 5 — Author `tools/verify/m036-p03-phase-suite.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-phase-suite.sh -- M036 P03 phase-suite aggregator.
# Wires all 14 P03 sub-gates. Patterned after tools/verify/m036-p02-phase-suite.sh.
# Filename milestone-prefixed (m036-) per the post-M031 plan-phase contract.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
#
# 14 sub-gates (M036 P03):
#   T01: m036-p03-conversus-preset-shape.sh
#        m036-p03-m030-task-type-extraction.sh
#        m036-p03-fixture-corpus-shape.sh
#   T02: m036-p03-driver-tier-2-shape.sh
#        m036-p03-tier-2-llm-helper-shape.sh
#        m036-p03-unit-close-extraction-shape.sh
#   T03: m036-p03-gate-helper-shape.sh
#        m036-p03-tier-2-deferred-error-removed.sh
#        m036-p03-tier-2-pass-end-to-end.sh
#        m036-p03-tier-2-block-retention.sh
#        m036-p03-p02-regression-pass.sh
#   T04: m036-p03-fixture-canned-structured-shape.sh
#        m036-p03-test-harness.sh
#        m036-p03-acceptance-harness-passes.sh
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
pass=0
fail=0

run() {
  local gate="$1"
  if bash "$ROOT/tools/verify/$gate" >/dev/null 2>&1; then
    echo "PASS: $gate"
    pass=$((pass + 1))
  else
    echo "FAIL: $gate"
    fail=$((fail + 1))
  fi
}

run m036-p03-conversus-preset-shape.sh
run m036-p03-m030-task-type-extraction.sh
run m036-p03-fixture-corpus-shape.sh
run m036-p03-driver-tier-2-shape.sh
run m036-p03-tier-2-llm-helper-shape.sh
run m036-p03-unit-close-extraction-shape.sh
run m036-p03-gate-helper-shape.sh
run m036-p03-tier-2-deferred-error-removed.sh
run m036-p03-tier-2-pass-end-to-end.sh
run m036-p03-tier-2-block-retention.sh
run m036-p03-p02-regression-pass.sh
run m036-p03-fixture-canned-structured-shape.sh
run m036-p03-test-harness.sh
run m036-p03-acceptance-harness-passes.sh

echo "SUMMARY: m036-p03-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Make all three new verifiers + the harness executable.

## Must-Haves

- The SC-11 + SC-12 acceptance harness `tests/test-tier-2-extraction-with-gate.sh` runs end-to-end on a bare host and emits `BATTERY: pass=<n> fail=<n> skip=<n>` as its last stdout line.
- The two canned-structured fixtures exist (consumed by the stub LLM dispatch).
- The phase-suite aggregator exists at `tools/verify/m036-p03-phase-suite.sh` and reports `SUMMARY: m036-p03-phase-suite.sh pass=14 fail=0` on a clean run.

## Verification

```bash
bash tools/verify/m036-p03-fixture-canned-structured-shape.sh
```

```bash
bash tools/verify/m036-p03-test-harness.sh
```

```bash
bash tools/verify/m036-p03-acceptance-harness-passes.sh
```

```bash
bash tools/verify/m036-p03-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/extract-reference.sh` (modified in T03) — driver dispatches Tier 2 helper chain on `summary_mode: auto + tier: 2`. EXTRACTED stdout shape: `EXTRACTED: <cite_id> tier=<n> bytes=<n> hash=<prefix> verdict=<PASS>` on PASS; `BLOCKED: <cite_id> reason=fidelity-gate` on BLOCK.
- `scripts/knowledge/lib/extract-tier-2-llm.sh` (T02) — `extract_tier_2_dispatch` honours `EXTRACT_TIER_2_DISPATCH=stub:pass|stub:block` by copying `tests/fixtures/m036-p03-tier-2/canned-structured*.md` to the out path.
- `scripts/knowledge/lib/extract-tier-2-gate.sh` (T03) — `extract_tier_2_invoke_gate` calls `conversus.sh gate tier-2-fidelity ...`; honours `CONVERSUS_STUB=1` + `CONVERSUS_STUB_VERDICT=PASS|BLOCK` to deterministically emit verdict.
- `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml` (T01) — single tier-2 doc, `cite_id: tier2-fixture-01`, `category: glossary`, `summary_mode: auto`.
- All 11 T01–T03 verifiers under `tools/verify/m036-p03-*` (consumed by the phase-suite aggregator).

### From Disk (Pre-existing)

- `tools/verify/m036-p02-phase-suite.sh` — structural template for the P03 aggregator (`set -eu`, `run` helper inspecting only exit code, `SUMMARY:` line format).
- `scripts/dispatch/adapters/tool/conversus.sh` — stub-mode contract: `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS|BLOCK` produces canned verdicts deterministically.
- `tests/fixtures/gate-result-pass.md` + `tests/fixtures/gate-result-block.md` — referenced by the conversus stub; already on disk from M026 work.

## Constraints

- CON-2 (Bash 3.2 / POSIX-sh).
- CON-3 (no live LLM — only stub paths exercised).
- AD-19 single-script-file shape for verifier `Check:` invocations.
- Verifier filename milestone-prefixed slug `m036-p03-*` per the post-M031 plan-phase contract.
- The SC-11 harness emits the `BATTERY:` line as the LAST stdout line, regardless of pass/fail count (machine-parseable; consumers grep `^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$`; exit 0 iff `fail=0` regardless of `skip`).
- The aggregator `run` helper inspects exit code ONLY (sub-gates that emit `SKIP:` lines internally still exit 0 informationally and report PASS at aggregator level — pattern carried verbatim from M036/P02 phase-suite).
- The SC-11 harness does NOT depend on any host tooling beyond bash + grep + sed + awk + cp + mv + mkdir + mktemp (no `pdftotext`, `pandoc`, etc.; the markdown source + canned-structured fixtures bypass the Tier 1 adapter chain entirely for the Tier 2 acceptance path).

## Expected Output

After T04 completes:

- `tests/fixtures/m036-p03-tier-2/canned-structured.md` (~17 lines).
- `tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md` (~12 lines).
- `tests/test-tier-2-extraction-with-gate.sh` exists, executable, ~120 lines.
- `tools/verify/m036-p03-fixture-canned-structured-shape.sh` (authored T03) now exits 0 because the canned files are on disk.
- `tools/verify/m036-p03-test-harness.sh` exists, executable, exits 0.
- `tools/verify/m036-p03-acceptance-harness-passes.sh` exists, executable, exits 0.
- `tools/verify/m036-p03-phase-suite.sh` exists, executable, runs all 14 sub-gates; emits `SUMMARY: m036-p03-phase-suite.sh pass=14 fail=0`.
- The PASS leg of the harness asserts 9 PASS lines; the BLOCK leg asserts 4 PASS lines; plus 4 fixture-presence sanity assertions = `BATTERY: pass=17 fail=0 skip=0` on a clean run.

## Notes

The SC-11 acceptance harness deliberately copies `scripts/` and `templates/` into a per-leg mktemp workspace before driving the driver. This:
- Isolates `.orchestrator/execution-log.jsonl` writes (the unit_close emitter writes to `${ORCHESTRATOR_ROOT}/.orchestrator/execution-log.jsonl`; the harness sets `ORCHESTRATOR_ROOT` to the per-leg workspace so the repo's real execution log is never touched).
- Lets the harness assert on a known-empty log file (every assertion against `_extraction-log` and `execution-log.jsonl` starts from zero state).
- Mirrors the M036/P02 SC-10 harness pattern (which also stages a per-run repo copy under `mktemp -d`).

The PASS-leg + BLOCK-leg run sequentially in the same harness (rather than as two independent test files) so that:
- A single `BATTERY:` line summarises the entire SC-11 + SC-12 acceptance.
- Cross-leg invariants (e.g., "no leakage of PASS-leg artifacts into the BLOCK-leg workspace") are verifiable in one process.
- The phase-suite aggregator consumes one `acceptance-harness-passes.sh` gate, not two.
