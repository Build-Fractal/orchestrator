---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M043"
name: "giscus byte-stability assertion + phase-suite aggregator"
depends_on: ["T01", "T02"]
---

## Prerequisites

- `wiki/overrides/partials/comments.html` exists on disk (the Material-theme
  giscus partial, ≈82 lines). M043 touches no giscus file, so this partial is
  byte-stable across the milestone and across both deploy targets.
- T01's verifiers exist on disk: `tools/verify/m043-p03-warning-matrix.sh`,
  `tools/verify/m043-p03-doctor-wiring.sh`.
- T02's verifier exists on disk: `tools/verify/m043-p03-installation-anchors.sh`.

## Description

Capture the byte-exact golden of the giscus partial and author the SC-8
byte-stability verifier (the partial is target-independent, so the Cloudflare
build introduces no change — diff exit 0). Then author the P03 phase-suite
aggregator that runs all four P03 gates and emits the canonical
`SUMMARY: ... pass=N fail=N` line, mirroring the P02 suite.

## Steps

### Step 1 — Capture the giscus golden

Copy `wiki/overrides/partials/comments.html` byte-for-byte to
`tests/fixtures/m043-p03/giscus-comments.golden.html`:

```bash
cp wiki/overrides/partials/comments.html tests/fixtures/m043-p03/giscus-comments.golden.html
```

This snapshot is the M043-scoped baseline. The assertion proves M043 introduced
no giscus change; if a FUTURE milestone legitimately changes the partial, that
milestone re-baselines this golden (the assertion is intentionally M043-scoped,
not a permanent freeze).

### Step 2 — Author `tools/verify/m043-p03-giscus-bytestable.sh` (SC-8)

```bash
#!/usr/bin/env bash
# m043-p03-giscus-bytestable.sh — SC-8 (FR-12). The giscus partial is byte-stable
# on both deploy targets; M043 introduces no giscus change. Diffs the live
# wiki/overrides/partials/comments.html against the captured golden (exit 0).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
LIVE="wiki/overrides/partials/comments.html"
GOLD="tests/fixtures/m043-p03/giscus-comments.golden.html"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

[ -f "$LIVE" ]; check "giscus partial exists" $?
[ -f "$GOLD" ]; check "giscus golden exists" $?

if diff -u "$GOLD" "$LIVE" >/dev/null 2>&1; then d=0; else d=1; fi
[ "$d" -eq 0 ]
check "comments.html is byte-identical to the golden (no M043 giscus change)" $?

echo "SUMMARY: m043-p03-giscus-bytestable.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

### Step 3 — Author `tools/verify/m043-p03-phase-suite.sh`

Aggregator over all four P03 gates, mirroring `tools/verify/m043-p02-phase-suite.sh`
(`run_gate` helper, one `SUMMARY: ... pass=N fail=N` line, excludes itself — no
recursion).

```bash
#!/usr/bin/env bash
# m043-p03-phase-suite.sh — P03 phase-suite aggregator. Runs all four P03 gates
# in order, exits 0 iff all pass, emits one SUMMARY line.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

pass=0
fail=0
run_gate() {
  if bash "$1"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
}

run_gate "tools/verify/m043-p03-warning-matrix.sh"
run_gate "tools/verify/m043-p03-doctor-wiring.sh"
run_gate "tools/verify/m043-p03-installation-anchors.sh"
run_gate "tools/verify/m043-p03-giscus-bytestable.sh"

echo "SUMMARY: m043-p03-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

## Must-Haves

- Truth: `wiki/overrides/partials/comments.html` is byte-identical to its golden.
  - Check: `bash tools/verify/m043-p03-giscus-bytestable.sh`
- Truth: the phase suite aggregates all four P03 gates and reports `fail=0`.
  - Check: `bash tools/verify/m043-p03-phase-suite.sh`
- Artifact: `tests/fixtures/m043-p03/giscus-comments.golden.html`
- Artifact: `tools/verify/m043-p03-giscus-bytestable.sh`, `tools/verify/m043-p03-phase-suite.sh`

## Verification

```bash
bash tools/verify/m043-p03-giscus-bytestable.sh
bash tools/verify/m043-p03-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `tools/verify/m043-p03-warning-matrix.sh` (from T01) — run by the phase suite.
  Contract: exits 0 on the SC-6 fallback matrix; prints `SUMMARY: ... fail=0`.
- `tools/verify/m043-p03-doctor-wiring.sh` (from T01) — run by the phase suite.
  Contract: exits 0 when both surfaces are wired with no plan probe.
- `tools/verify/m043-p03-installation-anchors.sh` (from T02) — run by the phase
  suite. Contract: exits 0 when all FR-11 anchors are present.

### From Disk (Pre-existing)

- `wiki/overrides/partials/comments.html` — the giscus partial; copied to the
  golden and diffed against it.
- `tools/verify/m043-p02-phase-suite.sh` — the shape this aggregator mirrors
  (`run_gate` helper + `SUMMARY: <name> pass=N fail=N`).

## Constraints

- **SC-8 is M043-scoped** — the byte-stability assertion proves M043 changed no
  giscus file; it is not a permanent freeze on the partial.
- **Suite excludes itself** — the aggregator must NOT run
  `m043-p03-phase-suite.sh` (no recursion), only the four leaf gates.
- **Phase-suite SUMMARY line** — emit exactly
  `SUMMARY: m043-p03-phase-suite.sh pass=N fail=N` (the observability surface the
  P03 summary records, matching the P01/P02 convention).
- **Single-script-file Check (AD-19)** — every verifier invoked as
  `bash tools/verify/m043-p03-*.sh`.

## Expected Output

`bash tools/verify/m043-p03-giscus-bytestable.sh` prints three `PASS:` lines and
`SUMMARY: m043-p03-giscus-bytestable.sh fail=0`.
`bash tools/verify/m043-p03-phase-suite.sh` runs the four gates and prints
`SUMMARY: m043-p03-phase-suite.sh pass=4 fail=0`.
