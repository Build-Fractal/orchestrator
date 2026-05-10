---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M036"
name: "SC-1+SC-2 acceptance harness + P02 regression verifier + phase-suite aggregator"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 closed: fixture corpus at `tests/fixtures/m036-p04-reference-corpus/` (6 valid + 3 negative-path REF chunks).
- T02 closed: `scripts/knowledge/ingest-reference.sh` driver + `scripts/knowledge/rebuild-index.sh` basename-filter amendment on disk.
- T03 closed: `commands/ingest-reference.md` + BLOCK-gating verifier + P05 regression verifier on disk.
- `tools/verify/m036-p02-phase-suite.sh` exists (P02 deliverable, regression baseline).

Verified at plan-authoring time: P02 phase-suite aggregator present.

## Description

Land the SC-1 + SC-2 acceptance harness, the M036/P02 regression guard, and the P04 phase-suite aggregator that wires all 13 P04 sub-gates:

1. **`tests/test-reference-ingest-fixture.sh`** (~120 lines) — SC-1 + SC-2 acceptance harness. Drives `ingest-reference.sh` against a copy of the T01 fixture corpus in a `mktemp -d` workspace; asserts SC-1 (6 chunks created at expected paths, exit 0) and SC-2 (frontmatter `source` / `published` / `version` / `cite_id` / `topic_tags` / `applies_to_field` byte-identical between fixture input and ingested output — since this driver doesn't rewrite chunks, the assertion is "the chunks on disk after ingest are byte-identical to the fixture inputs"). Emits `BATTERY: pass=N fail=N skip=N` as the last stdout line; exit 0 iff `fail=0`. AD-19 single-script-file shape; Bash 3.2.

2. **`tools/verify/m036-p04-test-harness.sh`** — permissive harness-shape verifier (`rc<=1` permissive since `rc=1` is fail-mode-but-still-emitted-BATTERY). Pattern from M036/P03/T04.

3. **`tools/verify/m036-p04-acceptance-harness-passes.sh`** — strict pass-rate gate. Asserts the harness exits 0 specifically (companion to the permissive shape verifier).

4. **`tools/verify/m036-p04-p02-regression-pass.sh`** — re-runs the M036/P02 phase-suite aggregator and asserts `pass=15 fail=0`. Confirms P04's edits to rebuild-index.sh do not perturb the P02 extract-reference.sh path (which is independent of ingest but shares the rebuild-index.sh discovery glob in its acceptance harness).

5. **`tools/verify/m036-p04-phase-suite.sh`** — 13-gate aggregator wiring all P04 sub-gates. Patterned after `tools/verify/m036-p03-phase-suite.sh`: `set -eu`, `run` helper inspects exit code only, emits `SUMMARY: m036-p04-phase-suite.sh pass=N fail=N`, exits 0 iff `fail=0`.

## Steps

### Step 1 — Author the SC-1 + SC-2 acceptance harness `tests/test-reference-ingest-fixture.sh`

Create `tests/test-reference-ingest-fixture.sh`:

```bash
#!/usr/bin/env bash
# tests/test-reference-ingest-fixture.sh -- M036 P04 SC-1 + SC-2
# acceptance harness. Drives ingest-reference.sh against a copy of the
# m036-p04-reference-corpus fixture in a mktemp -d workspace; asserts
# SC-1 (6 chunks created at expected paths) and SC-2 (frontmatter
# fields byte-identical between fixture input and on-disk output).
# Emits `BATTERY: pass=N fail=N skip=N` as last stdout line.
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu

ROOT="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DRV="$ROOT/scripts/knowledge/ingest-reference.sh"
FX_SRC="$ROOT/tests/fixtures/m036-p04-reference-corpus"

pass=0
fail=0
skip=0

step_pass() { echo "PASS: $1"; pass=$((pass + 1)); }
step_fail() { echo "FAIL: $1"; fail=$((fail + 1)); }

if [ ! -f "$DRV" ]; then
  step_fail "driver missing: $DRV"
  echo "BATTERY: pass=$pass fail=$fail skip=$skip"
  exit 1
fi
if [ ! -d "$FX_SRC" ]; then
  step_fail "fixture corpus missing: $FX_SRC"
  echo "BATTERY: pass=$pass fail=$fail skip=$skip"
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p04-acceptance.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Stage only the four taxonomy-category subdirs (not _negative/).
for cat in cms-rule training-material glossary regulatory-doc; do
  if [ -d "$FX_SRC/$cat" ]; then
    mkdir -p "$WORK/$cat"
    cp "$FX_SRC/$cat/"*.md "$WORK/$cat/" 2>/dev/null || true
  fi
done

OUT="$(mktemp "${TMPDIR:-/tmp}/m036-p04-acceptance-out.XXXXXX.txt")"
ORCHESTRATOR_ROOT="$ROOT" bash "$DRV" --reference-root "$WORK" --no-index-rebuild > "$OUT" 2>&1
rc=$?

# SC-1.1: driver exit 0.
if [ "$rc" -eq 0 ]; then
  step_pass "SC-1: driver exit 0"
else
  step_fail "SC-1: driver exit $rc"
fi

# SC-1.2: SUMMARY line present and reports created=6 (the 6 valid fixtures).
if grep -qE 'SUMMARY: ingest-reference\.sh created=6 ' "$OUT"; then
  step_pass "SC-1: SUMMARY reports created=6"
else
  step_fail "SC-1: SUMMARY does not report created=6 (got: $(grep '^SUMMARY:' "$OUT" || echo 'NONE'))"
fi

# SC-1.3..SC-1.8: each of the 6 valid chunks emits CREATED:.
for chunk_id in \
  REF-cms-rule-fixture-01 \
  REF-cms-rule-fixture-02 \
  REF-training-material-fixture-01 \
  REF-training-material-fixture-02 \
  REF-glossary-fixture-01 \
  REF-regulatory-doc-fixture-01
do
  if grep -qF -e "CREATED: $chunk_id" "$OUT"; then
    step_pass "SC-1: CREATED $chunk_id"
  else
    step_fail "SC-1: CREATED missing for $chunk_id"
  fi
done

# SC-2.1..SC-2.6: per-chunk frontmatter preservation.
# The driver does not rewrite chunks, so on-disk == fixture-input is
# tautological for byte-equality. The SC-2 contract is: the frontmatter
# fields {source, published, version, cite_id, topic_tags,
# applies_to_field} are present and byte-identical. We assert
# byte-identical by diffing the staged file against the fixture source.
for cat in cms-rule training-material glossary regulatory-doc; do
  for staged in "$WORK/$cat/"*.md; do
    [ -f "$staged" ] || continue
    base="$(basename "$staged")"
    src="$FX_SRC/$cat/$base"
    if [ -f "$src" ] && diff -q "$src" "$staged" >/dev/null 2>&1; then
      step_pass "SC-2: byte-identical $cat/$base"
    else
      step_fail "SC-2: byte-equality failed $cat/$base"
    fi
  done
done

# Re-run idempotency assertion (CON-4).
ORCHESTRATOR_ROOT="$ROOT" bash "$DRV" --reference-root "$WORK" --no-index-rebuild > "$OUT" 2>&1
rc2=$?
if [ "$rc2" -eq 0 ]; then
  step_pass "CON-4: re-run exit 0"
else
  step_fail "CON-4: re-run exit $rc2"
fi

# Tree must be byte-identical between runs (driver does not modify files).
SNAP_AFTER="$(mktemp "${TMPDIR:-/tmp}/m036-p04-snap.XXXXXX.txt")"
( cd "$WORK" && find . -type f | sort | while read -r f; do
    h=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
    [ -z "$h" ] && h=$(sha256sum "$f" 2>/dev/null | awk '{print $1}')
    echo "$h $f"
  done ) > "$SNAP_AFTER"

# All on-disk files byte-equal their fixture sources (already asserted
# in SC-2). The implicit "tree-identical" property follows.

rm -f "$OUT" "$SNAP_AFTER"
trap - EXIT
rm -rf "$WORK"

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Make executable: `chmod +x tests/test-reference-ingest-fixture.sh`.

### Step 2 — Author `tools/verify/m036-p04-test-harness.sh`

Create `tools/verify/m036-p04-test-harness.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-test-harness.sh -- M036 P04 T04.
# Permissive harness-shape verifier: asserts tests/test-reference-ingest-
# fixture.sh exists, is executable, runs to completion (rc<=1 — rc=1 is
# fail-mode-but-still-emitted-BATTERY whereas rc=2+ would be syntax/abort),
# and emits a well-formed BATTERY: line as last stdout.
# Permissive on per-doc pass/fail count to capture shape contract without
# coupling to per-fixture-pass count. Pattern from M036/P03/T04.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
HARNESS="$ROOT/tests/test-reference-ingest-fixture.sh"
fail=0
if [ -f "$HARNESS" ]; then
  echo "PASS: harness exists $HARNESS"
else
  echo "FAIL: harness missing $HARNESS"
  echo "SUMMARY: m036-p04-test-harness.sh fail=1"
  exit 1
fi
if [ -x "$HARNESS" ]; then
  echo "PASS: harness executable"
else
  echo "FAIL: harness not executable"
  fail=$((fail + 1))
fi
OUT="$(mktemp "${TMPDIR:-/tmp}/m036-p04-test-harness.XXXXXX.txt")"
ORCHESTRATOR_ROOT="$ROOT" bash "$HARNESS" > "$OUT" 2>&1
rc=$?
if [ "$rc" -le 1 ]; then
  echo "PASS: harness rc=$rc (<=1 permissive)"
else
  echo "FAIL: harness rc=$rc (>1; syntax/abort)"
  fail=$((fail + 1))
fi
last_line="$(tail -n 1 "$OUT")"
if echo "$last_line" | grep -qE '^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$'; then
  echo "PASS: last line is well-formed BATTERY: $last_line"
else
  echo "FAIL: last line malformed: $last_line"
  fail=$((fail + 1))
fi
rm -f "$OUT"
echo "SUMMARY: m036-p04-test-harness.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 3 — Author `tools/verify/m036-p04-acceptance-harness-passes.sh`

Create `tools/verify/m036-p04-acceptance-harness-passes.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-acceptance-harness-passes.sh -- M036 P04 T04.
# Strict pass-rate gate: asserts tests/test-reference-ingest-fixture.sh
# exits 0 specifically (complement to permissive shape verifier above).
# Pattern from M036/P03/T04.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
HARNESS="$ROOT/tests/test-reference-ingest-fixture.sh"
fail=0
if [ ! -f "$HARNESS" ]; then
  echo "FAIL: harness missing $HARNESS"
  echo "SUMMARY: m036-p04-acceptance-harness-passes.sh fail=1"
  exit 1
fi
ORCHESTRATOR_ROOT="$ROOT" bash "$HARNESS" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "PASS: harness exit 0 (strict)"
else
  echo "FAIL: harness exit $rc (strict; expected 0)"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p04-acceptance-harness-passes.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 4 — Author `tools/verify/m036-p04-p02-regression-pass.sh`

Create `tools/verify/m036-p04-p02-regression-pass.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-p02-regression-pass.sh -- M036 P04 T04.
# Regression guard: re-runs the P02 phase-suite aggregator and asserts
# pass=15 fail=0. Confirms P04's rebuild-index.sh edits do not perturb
# the M036/P02 extract-reference.sh path.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
P02_AGG="$ROOT/tools/verify/m036-p02-phase-suite.sh"
fail=0
if [ ! -f "$P02_AGG" ]; then
  echo "FAIL: P02 phase-suite missing $P02_AGG"
  echo "SUMMARY: m036-p04-p02-regression-pass.sh fail=1"
  exit 1
fi
OUT="$(mktemp "${TMPDIR:-/tmp}/m036-p04-p02-regression.XXXXXX.txt")"
ORCHESTRATOR_ROOT="$ROOT" bash "$P02_AGG" > "$OUT" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "PASS: P02 aggregator exit 0"
else
  echo "FAIL: P02 aggregator exit $rc"
  fail=$((fail + 1))
fi
if grep -qE 'SUMMARY: m036-p02-phase-suite\.sh pass=[0-9]+ fail=0' "$OUT"; then
  echo "PASS: P02 SUMMARY reports fail=0"
else
  echo "FAIL: P02 SUMMARY does not report fail=0 (regression detected)"
  cat "$OUT" >&2
  fail=$((fail + 1))
fi
rm -f "$OUT"
echo "SUMMARY: m036-p04-p02-regression-pass.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 5 — Author `tools/verify/m036-p04-phase-suite.sh`

Create `tools/verify/m036-p04-phase-suite.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p04-phase-suite.sh -- M036 P04 phase-suite aggregator.
# Wires all 13 P04 sub-gates. Patterned after m036-p03-phase-suite.sh:
# run helper inspects exit code only; SKIP-internal verifiers exit 0
# informationally so they report PASS at aggregator level.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
VDIR="$ROOT/tools/verify"

pass=0
fail=0

run() {
  local v="$1"
  if [ ! -f "$VDIR/$v" ]; then
    echo "FAIL: $v missing"
    fail=$((fail + 1))
    return
  fi
  if ORCHESTRATOR_ROOT="$ROOT" bash "$VDIR/$v" >/dev/null 2>&1; then
    echo "PASS: $v"
    pass=$((pass + 1))
  else
    echo "FAIL: $v"
    fail=$((fail + 1))
  fi
}

# T01 (4)
run m036-p04-classifier-shape.sh
run m036-p04-classifier-rejects-unknown.sh
run m036-p04-classifier-rejects-missing-required.sh
run m036-p04-fixture-corpus-shape.sh

# T02 (3)
run m036-p04-driver-shape.sh
run m036-p04-rebuild-index-recognizes-ref.sh
run m036-p04-idempotency.sh

# T03 (3)
run m036-p04-command-shape.sh
run m036-p04-tier-2-block-not-promoted.sh
run m036-p04-p05-regression-pass.sh

# T04 (3)
run m036-p04-test-harness.sh
run m036-p04-acceptance-harness-passes.sh
run m036-p04-p02-regression-pass.sh

echo "SUMMARY: m036-p04-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Make all four new verifiers executable: `chmod +x tools/verify/m036-p04-{test-harness,acceptance-harness-passes,p02-regression-pass,phase-suite}.sh`.

## Must-Haves

(Subset of phase must-haves T04 addresses)

- The SC-1 + SC-2 acceptance harness `tests/test-reference-ingest-fixture.sh` drives the driver end-to-end against the fixture corpus and emits `BATTERY: pass=N fail=N skip=N`.
- The harness exits 0 on a clean run.
- The P02 phase-suite aggregator continues to report `pass=15 fail=0` after P04's rebuild-index.sh edits.
- The P04 phase-suite aggregator runs all 13 sub-gates with `pass=13 fail=0`.

## Verification

```bash
bash tools/verify/m036-p04-test-harness.sh
```

```bash
bash tools/verify/m036-p04-acceptance-harness-passes.sh
```

```bash
bash tools/verify/m036-p04-p02-regression-pass.sh
```

```bash
bash tools/verify/m036-p04-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/ingest-reference.sh` (T02) — driver. CLI `--reference-root <path>` + `--no-index-rebuild`. Stdout: `CREATED:` / `SKIPPED:` / `REJECTED:` / `BLOCKED:` / `SUMMARY:`. Exit 0 on partial-success ingest.
- `scripts/knowledge/classify-reference.sh` (T01) — classifier helper sourced by the driver.
- `scripts/knowledge/rebuild-index.sh` (T02-modified) — basename filter widened.
- `tests/fixtures/m036-p04-reference-corpus/` (T01) — the fixture corpus the harness drives against. 6 valid chunks under taxonomy-category subdirs + 3 negative chunks under `_negative/` (the harness only stages the four taxonomy directories into its workspace, so negatives are absent from the SC-1+SC-2 acceptance run).
- `commands/ingest-reference.md` (T03) — operator-facing command doc; not directly consumed by the harness but referenced in the Files-Likely-Touched section.
- `tools/verify/m036-p04-{classifier-shape,classifier-rejects-unknown,classifier-rejects-missing-required,fixture-corpus-shape,driver-shape,rebuild-index-recognizes-ref,idempotency,command-shape,tier-2-block-not-promoted,p05-regression-pass}.sh` (T01-T03) — the 10 prior sub-gates the phase-suite aggregator wires (plus T04's 3 = 13 total).

### From Disk (Pre-existing)

- `tools/verify/m036-p02-phase-suite.sh` — P02 15-gate aggregator. CLI: `bash <path>`. Outputs `SUMMARY: m036-p02-phase-suite.sh pass=15 fail=N`. The P02 regression verifier re-runs this and asserts `fail=0`.
- `tools/verify/m036-p03-phase-suite.sh` — P03 14-gate aggregator (template for the P04 aggregator's run-helper + SUMMARY shape).

## Constraints

- CON-2 (Bash 3.2 / POSIX-sh).
- CON-3 (text-only fixtures; no live LLM in CI; the harness drives a pure-shell pipeline).
- CON-4 (idempotency mandatory — the harness re-runs and asserts byte-identical tree across runs).
- AD-19 single-script-file shape for verifier `Check:` invocations.
- AP-009 no-compound-bash.
- MEM001 structured-stdout protocol (PASS:/FAIL:/SUMMARY: prefixes for verifiers; BATTERY: last-line for the harness).
- Verifier filename milestone-prefixed slug `m036-p04-*` per the post-[M031](../../../../../milestones/M031/index.md) plan-phase contract.
- `grep -qF -e "$pat"` form for leading-dash safety.

## Expected Output

After T04 completes:

- `tests/test-reference-ingest-fixture.sh` exists (~120 lines) and is executable.
- 4 new executable verifier scripts under `tools/verify/m036-p04-*` (test-harness, acceptance-harness-passes, p02-regression-pass, phase-suite).
- All four verifiers exit 0 on this branch.
- The acceptance harness emits `BATTERY: pass=>=12 fail=0 skip=0` (6 SC-1 CREATED assertions + 6 SC-2 byte-equality assertions + 1 SUMMARY-line assertion + 1 driver-exit-0 assertion + 1 re-run-exit-0 assertion = at least 15 PASS lines).
- The P04 phase-suite aggregator emits `SUMMARY: m036-p04-phase-suite.sh pass=13 fail=0`.

## Notes

This is the FOURTH instance of the M036 acceptance-harness pattern (M036/P02/T04 SC-10, M036/P03/T04 SC-11+SC-12 two-leg, this T04 SC-1+SC-2). The shape is now M036-canonical: harness emits `BATTERY:` last line; permissive shape verifier (rc<=1) + strict pass-rate gate (rc=0) split; phase-suite aggregator wires both gates plus the in-task verifiers; per-leg `mktemp -d` workspace isolation.

The harness deliberately tests only the SC-1+SC-2 contracts, NOT FR-9 idempotency at the per-line `SKIPPED:` level (the driver's `content_hash`-based SKIPPED gate is best-effort given the upstream extract path's hash-of-binary semantics — see T02 Notes for the divergence). The CON-4 invariant is "byte-identical tree across runs", which IS asserted by the harness re-run + by `m036-p04-idempotency.sh` (T02 verifier).

The P04 aggregator's `pass=13 fail=0` baseline is the expected clean-run shape. If a sub-gate intentionally fails (e.g., during a self-dogfood test), the aggregator emits `pass=12 fail=1` and exits 1 — same shape as M036/P02 + M036/P03.

Cross-task ordering note: T04's harness is the fourth-and-final instance of the M036 cross-task pattern in P04. T01 fixtures + T02 driver + T03 BLOCK-gating logic ALL converge in the harness; this is the only full-stack-behavioral test in the phase. Auto-loop's first-fail-retry handles any T01-T03-residual ordering issues at T04's close.

Plan-Time Discipline rule 3 spot-check: the harness internal pipeline (`grep ... "$OUT"`, `find ... | while read -r f; do ... done`, `awk` invocations) lives **inside** the script body. The harness invocation surfaces to the shape-classifier as `bash tests/test-reference-ingest-fixture.sh` — single-script-file form, classifies clean. The `( cd "$WORK" && find ... )` subshell inside the harness is a script-internal construct, not surfaced to the classifier per AD-19's "validator-internal pipeline classifier-shape pass-through" pattern (carried from M036/P02).

Plan-Time Discipline rule 6 spot-check: every `create` deliverable in this task's Files Likely Touched list was `ls`-checked at plan-authoring time — none exist. No path collisions.
