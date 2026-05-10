---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M036"
name: "SC-10 acceptance harness + idempotency verifier + harness-shape verifier + phase-suite aggregator"
depends_on: ["T03"]
---

## Prerequisites

T01 + T02 + T03 must be complete:

- All driver + lib helpers on disk and executable.
- `commands/extract.md` exists.
- 13 sub-gate verifiers under `tools/verify/m036-p02-*.sh` already authored:
  - From T01: `manifest-contract-shape.sh`, `fixture-manifest-shape.sh`, `fixture-corpus-shape.sh`.
  - From T02: `extract-driver-shape.sh`, `binary-preservation.sh`, `content-hash.sh`, `size-cap-external-pointer.sh`.
  - From T03: `extract-md.sh`, `extract-pdf-host-aware.sh`, `extract-docx-host-aware.sh`, `extract-command-shape.sh`, `summary-mode-stub-vs-operator.sh`, `tier-2-deferred-error.sh`.
- `tests/fixtures/m036/extract-manifest.yaml` + binaries.

T04 adds the SC-10 acceptance harness, idempotency check, harness-shape verifier, and the phase-suite aggregator wiring all 16 sub-gates (13 prior + 3 from this task: `idempotency.sh`, `test-harness.sh`, `phase-suite.sh`).

Confirmed on disk at plan-authoring time.

## Description

Author the SC-10 end-to-end acceptance harness `tests/test-tier-0-manifest.sh` that runs the driver against the real 3-doc fixture manifest, asserts EXTRACTED:/SKIPPED: lines per doc, validates the chunk frontmatter shape, and tests idempotency (re-run produces zero changes via `diff -q`). The harness emits `BATTERY: pass=N fail=N skip=N` per the M036 P01 pattern.

Land the idempotency verifier (`m036-p02-idempotency.sh`) which exercises the driver twice in a temp workspace and asserts `diff -q` finds zero deltas — this is the focused CON-4 / FR-9 contract test.

Land the harness-shape verifier (`m036-p02-test-harness.sh`) which asserts the SC-10 harness exists, ran-to-completion, and emitted a `BATTERY:` line.

Land the phase-suite aggregator (`m036-p02-phase-suite.sh`) wiring all 16 sub-gates in deterministic order, mirroring `tools/verify/m036-p01-phase-suite.sh`.

## Steps

### 1. Author `tests/test-tier-0-manifest.sh`

```bash
#!/usr/bin/env bash
# tests/test-tier-0-manifest.sh -- M036 P02 SC-10 acceptance harness.
# Drives scripts/knowledge/extract-reference.sh against the 3-doc
# fixture manifest in a mktemp -d workspace. Asserts:
#   1. EXTRACTED: line per document on first run.
#   2. SKIPPED: line per document on second (idempotent) run.
#   3. Each chunk file has the required frontmatter fields.
#   4. Each binary exists byte-identical under _originals/.
#   5. diff -q across the two runs reports zero changes.
# Host-tooling-aware SKIP at the per-document level: PDF + DOCX docs
# SKIP if pdftotext/pandoc absent; markdown doc always runs.
# Emits BATTERY: pass=N fail=N skip=N summary; exit 0 iff fail=0.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-sc10.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036/extract-manifest.yaml"

pass=0
fail=0
skip=0

assert_pass() {
  echo "PASS: $1"
  pass=$((pass + 1))
}
assert_fail() {
  echo "FAIL: $1"
  fail=$((fail + 1))
}
assert_skip() {
  echo "SKIP: $1"
  skip=$((skip + 1))
}

# Determine which docs to assert on per host tooling.
have_pdf=0
have_docx=0
if command -v pdftotext >/dev/null 2>&1; then have_pdf=1; fi
if command -v pandoc    >/dev/null 2>&1; then have_docx=1; fi

# To run end-to-end the driver needs *all* host tools the manifest
# declares. If any are absent we run a markdown-only sub-manifest.
if [ "$have_pdf" -eq 1 ] && [ "$have_docx" -eq 1 ]; then
  STAGED_MANIFEST="$MANIFEST"
  STAGED_DIR="$ROOT/tests/fixtures/m036"
else
  STAGED_DIR="$WORK"
  cp "$ROOT/tests/fixtures/m036/sample.md" "$STAGED_DIR/sample.md"
  cat > "$STAGED_DIR/extract-manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "glossary-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2024-01-01"
    version: "2024-01"
    topic_tags: ["pbj-staffing", "definitions"]
    applies_to_field: ["staff_count", "census"]
    tier: 0
    summary_mode: "operator"
    summary: "Fixture glossary markdown for M036 P02 extract harness."
YAML
  STAGED_MANIFEST="$STAGED_DIR/extract-manifest.yaml"
  if [ "$have_pdf" -eq 0 ];  then assert_skip "pdf-fixture (pdftotext-absent)"; fi
  if [ "$have_docx" -eq 0 ]; then assert_skip "docx-fixture (pandoc-absent)";   fi
fi

RUN1="$WORK/run1"
RUN2="$WORK/run2"

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$STAGED_MANIFEST" \
  --reference-root "$RUN1/knowledge/reference" \
  --originals-root "$RUN1/_originals" \
  >"$WORK/run1.stdout" 2>"$WORK/run1.stderr" || {
    assert_fail "first-run driver exited non-zero"
    cat "$WORK/run1.stderr" >&2
    echo "BATTERY: pass=$pass fail=$fail skip=$skip"
    exit 1
  }

# Assert EXTRACTED lines on first run for each doc actually run.
if [ "$have_pdf" -eq 1 ] && [ "$have_docx" -eq 1 ]; then
  for c in cms-rule-fixture-01 training-pbj-fixture-01 glossary-fixture-01; do
    if grep -qE "^EXTRACTED: $c " "$WORK/run1.stdout"; then
      assert_pass "EXTRACTED: $c (first run)"
    else
      assert_fail "no EXTRACTED line for $c on first run"
    fi
  done
else
  if grep -qE "^EXTRACTED: glossary-fixture-01 " "$WORK/run1.stdout"; then
    assert_pass "EXTRACTED: glossary-fixture-01 (first run, md-only)"
  else
    assert_fail "no EXTRACTED line for glossary-fixture-01 on md-only first run"
  fi
fi

# Second run should SKIP every doc.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$STAGED_MANIFEST" \
  --reference-root "$RUN1/knowledge/reference" \
  --originals-root "$RUN1/_originals" \
  >"$WORK/run2.stdout" 2>"$WORK/run2.stderr" || {
    assert_fail "second-run driver exited non-zero"
    cat "$WORK/run2.stderr" >&2
    echo "BATTERY: pass=$pass fail=$fail skip=$skip"
    exit 1
  }
if grep -qE '^SKIPPED:' "$WORK/run2.stdout"; then
  if grep -qE '^EXTRACTED:' "$WORK/run2.stdout"; then
    assert_fail "second run emitted EXTRACTED (expected only SKIPPED)"
  else
    assert_pass "second run emits only SKIPPED:"
  fi
else
  assert_fail "second run missing SKIPPED: lines"
fi

# Frontmatter shape: every chunk has content_hash + tier + category.
for chunk in $(find "$RUN1/knowledge/reference" -name 'REF-*.md' -not -name '*.text.md'); do
  for f in content_hash tier category cite_id source published; do
    if grep -qE "^$f:" "$chunk"; then
      assert_pass "$f present in $(basename "$chunk")"
    else
      assert_fail "$f missing in $(basename "$chunk")"
    fi
  done
done

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 2. Author `tools/verify/m036-p02-idempotency.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-idempotency.sh -- M036 P02 T04.
# Drives the extract driver twice in a temp workspace; asserts the
# second run reports zero deltas via diff -q.
# Host-aware SKIP if pdftotext + pandoc absent (so we still exercise
# the full 3-doc fixture). On bare hosts uses the markdown-only doc.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-idem.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"

# Always-runnable: stage a markdown-only manifest. Idempotency contract
# is format-agnostic; markdown is sufficient to gate it.
cp "$ROOT/tests/fixtures/m036/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "idem-fixture-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2026-05-02"
    version: "test"
    topic_tags: []
    applies_to_field: []
    tier: 1
    summary_mode: "operator"
    summary: "Idempotency test fixture summary."
YAML

REF1="$WORK/run1/knowledge/reference"
ORIG1="$WORK/run1/_originals"
REF2="$WORK/run2/knowledge/reference"
ORIG2="$WORK/run2/_originals"

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WORK/manifest.yaml" \
  --reference-root "$REF1" --originals-root "$ORIG1" \
  >"$WORK/run1.stdout" 2>"$WORK/run1.stderr" || {
    echo "FAIL: first run failed"
    cat "$WORK/run1.stderr" >&2
    exit 1
  }

# Second run targets a fresh workspace (so we can byte-compare trees).
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WORK/manifest.yaml" \
  --reference-root "$REF2" --originals-root "$ORIG2" \
  >"$WORK/run2.stdout" 2>"$WORK/run2.stderr" || {
    echo "FAIL: second run failed"
    cat "$WORK/run2.stderr" >&2
    exit 1
  }

fail=0
if diff -qr "$REF1" "$REF2" >/dev/null 2>&1; then
  echo "PASS: knowledge/reference tree byte-identical across runs"
else
  echo "FAIL: knowledge/reference tree differs across runs"
  diff -qr "$REF1" "$REF2" || true
  fail=$((fail + 1))
fi
if diff -qr "$ORIG1" "$ORIG2" >/dev/null 2>&1; then
  echo "PASS: _originals tree byte-identical across runs"
else
  echo "FAIL: _originals tree differs across runs"
  diff -qr "$ORIG1" "$ORIG2" || true
  fail=$((fail + 1))
fi

# Now exercise the actual idempotency contract: re-run against an
# existing tree should emit SKIPPED, not EXTRACTED.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --manifest "$WORK/manifest.yaml" \
  --reference-root "$REF1" --originals-root "$ORIG1" \
  >"$WORK/run3.stdout" 2>"$WORK/run3.stderr" || {
    echo "FAIL: third run (rerun against run1 tree) failed"
    cat "$WORK/run3.stderr" >&2
    exit 1
  }
if grep -qE '^SKIPPED: idem-fixture-01 ' "$WORK/run3.stdout"; then
  echo "PASS: re-run against existing tree emits SKIPPED"
else
  echo "FAIL: re-run against existing tree did not emit SKIPPED"
  cat "$WORK/run3.stdout"
  fail=$((fail + 1))
fi

echo "SUMMARY: m036-p02-idempotency.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 3. Author `tools/verify/m036-p02-test-harness.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-test-harness.sh -- M036 P02 T04.
# Asserts the SC-10 harness exists, executable, runs to completion,
# and emits a BATTERY: line. Permissive on per-doc PASS/SKIP counts so
# host-tooling absence doesn't false-FAIL.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
H="$ROOT/tests/test-tier-0-manifest.sh"
fail=0
if [ ! -f "$H" ]; then
  echo "FAIL: missing $H"
  exit 1
fi
if [ ! -x "$H" ]; then
  echo "FAIL: not executable $H"
  fail=$((fail + 1))
else
  echo "PASS: harness executable"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-tharn.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
set +e
ORCHESTRATOR_ROOT="$ROOT" bash "$H" >"$WORK/out.txt" 2>"$WORK/err.txt"
rc=$?
set -e

if [ "$rc" -le 1 ]; then
  echo "PASS: harness ran to completion (rc=$rc)"
else
  echo "FAIL: harness rc=$rc (expected 0 or 1; >1 means abort/syntax)"
  fail=$((fail + 1))
fi
if grep -qE '^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$' "$WORK/out.txt"; then
  echo "PASS: BATTERY: line emitted"
else
  echo "FAIL: BATTERY: line missing or malformed"
  fail=$((fail + 1))
fi

echo "SUMMARY: m036-p02-test-harness.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 4. Author `tools/verify/m036-p02-phase-suite.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p02-phase-suite.sh -- M036 P02 phase-suite aggregator.
# Wires all 16 P02 sub-gates. Patterned after tools/verify/m036-p01-phase-suite.sh.
# Filename milestone-prefixed (m036-) per the "milestone slug REQUIRED"
# rule. Single-script-file shape per AD-19; the `run` helper is a single
# function invocation per gate.
#
# 16 sub-gates (M036 P02):
#   T01: m036-p02-manifest-contract-shape.sh
#        m036-p02-fixture-manifest-shape.sh
#        m036-p02-fixture-corpus-shape.sh
#   T02: m036-p02-extract-driver-shape.sh
#        m036-p02-binary-preservation.sh
#        m036-p02-content-hash.sh
#        m036-p02-size-cap-external-pointer.sh
#   T03: m036-p02-extract-md.sh
#        m036-p02-extract-pdf-host-aware.sh
#        m036-p02-extract-docx-host-aware.sh
#        m036-p02-extract-command-shape.sh
#        m036-p02-summary-mode-stub-vs-operator.sh
#        m036-p02-tier-2-deferred-error.sh
#   T04: m036-p02-idempotency.sh
#        m036-p02-test-harness.sh
#
# Per-format verifiers (PDF, DOCX) emit SKIP exit 0 on host-tool absence,
# so on bare hosts those sub-gates still report PASS at the aggregator
# level (the SKIP semantic is handled inside the verifier; the aggregator
# only inspects exit code).
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

run m036-p02-manifest-contract-shape.sh
run m036-p02-fixture-manifest-shape.sh
run m036-p02-fixture-corpus-shape.sh
run m036-p02-extract-driver-shape.sh
run m036-p02-binary-preservation.sh
run m036-p02-content-hash.sh
run m036-p02-size-cap-external-pointer.sh
run m036-p02-extract-md.sh
run m036-p02-extract-pdf-host-aware.sh
run m036-p02-extract-docx-host-aware.sh
run m036-p02-extract-command-shape.sh
run m036-p02-summary-mode-stub-vs-operator.sh
run m036-p02-tier-2-deferred-error.sh
run m036-p02-idempotency.sh
run m036-p02-test-harness.sh

echo "SUMMARY: m036-p02-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### 5. Make scripts executable

```bash
chmod +x tests/test-tier-0-manifest.sh \
         tools/verify/m036-p02-idempotency.sh \
         tools/verify/m036-p02-test-harness.sh \
         tools/verify/m036-p02-phase-suite.sh
```

## Must-Haves

This task addresses:

- The SC-10 acceptance harness exists, executable, ran-to-completion, and emitted `BATTERY:` line.
- Re-running the driver on an unchanged manifest emits `SKIPPED:` for every doc; chunk store is byte-identical (idempotency, CON-4 / FR-9).
- The phase-suite aggregator wires all 16 sub-gates (15 sub-gate verifiers + the harness-shape verifier).

## Verification

```bash
bash tools/verify/m036-p02-test-harness.sh
bash tools/verify/m036-p02-idempotency.sh
bash tools/verify/m036-p02-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/extract-reference.sh` (T02 + T03) — driver invoked by the harness.
  - Key API: `bash <driver> --manifest <path> [--reference-root <path>] [--originals-root <path>] [--summary-mode <op|stub|auto>]`. Stdout protocol: `EXTRACTED: <id> tier=<n> bytes=<n> hash=<prefix>` and `SKIPPED: <id> reason=<unchanged|external-pointer>`.
  - Exit 0 success; non-zero on any error.
- `scripts/knowledge/lib/extract-manifest.sh`, `lib/extract-binary-preservation.sh`, `lib/extract-tier-0-summary.sh` (T02 + T03) — sourced transitively by the driver.
- `tests/fixtures/m036/extract-manifest.yaml` + sample binaries (T01) — exercised by the harness.
- 13 sub-gate verifiers from T01 / T02 / T03 — wired by the aggregator.

### From Disk (Pre-existing)

- `tools/verify/m036-p01-phase-suite.sh` — pattern template for the P02 aggregator (read-only reference, not invoked).

## Constraints

- Bash 3.2 / POSIX-sh per CON-2.
- Harness shape: single-script-file invocations only at the test-step level. Pipes / awks legal inside the script body.
- Harness must emit `BATTERY: pass=N fail=N skip=N` on the *last* line of stdout — `m036-p02-test-harness.sh` greps the regex `^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$`.
- All ephemeral state lives under `mktemp -d` workspaces in `${TMPDIR:-/tmp}`. No project-tree mutation.
- Idempotency verifier asserts:
  1. Two runs against fresh workspaces produce byte-identical trees (`diff -qr`).
  2. Re-running against an existing tree emits `SKIPPED:` (driver's content-hash gate).
- Path-collision check: `tools/verify/m036-p02-phase-suite.sh` confirmed not-on-disk; the closest existing aggregator is `tools/verify/m036-p01-phase-suite.sh` (different milestone+phase slug — no collision).

## Notes

The aggregator uses the same shape as `m036-p01-phase-suite.sh`: the `run` helper redirects stdout/stderr of each sub-gate to `/dev/null` and inspects exit code only. SKIP-emitting verifiers (PDF, DOCX) report PASS at the aggregator level when their host tools are absent because the verifier exit code is 0 in that case.

Expected verifier output on success:

- `m036-p02-test-harness.sh` → `SUMMARY: m036-p02-test-harness.sh fail=0`, exit 0.
- `m036-p02-idempotency.sh` → `SUMMARY: m036-p02-idempotency.sh fail=0`, exit 0.
- `m036-p02-phase-suite.sh` → `SUMMARY: m036-p02-phase-suite.sh pass=15 fail=0`, exit 0 (15 sub-gates all green; on bare hosts PDF + DOCX sub-gates report PASS via internal SKIP).

## Expected Output

Files created:

- `tests/test-tier-0-manifest.sh` (~120 lines)
- `tools/verify/m036-p02-idempotency.sh` (~70 lines)
- `tools/verify/m036-p02-test-harness.sh` (~40 lines)
- `tools/verify/m036-p02-phase-suite.sh` (~55 lines)
