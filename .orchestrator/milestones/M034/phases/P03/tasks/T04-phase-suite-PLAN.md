---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M034"
name: "Phase-suite aggregator (m034-p03-phase-suite.sh)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- `tools/verify/m034-p03-mcp-stub.sh` exists (T01).
- `tools/verify/m034-p03-registration.sh` exists (T02).
- `tools/verify/m034-p03-runtime-assumptions.sh` exists (T03).
- `tools/verify/m034-p03-byte-parity.sh` exists (T03).
- `tools/verify/m034-p02-phase-suite.sh` exists — the structural model for this aggregator.

## Description

Author the P03 phase-suite aggregator — the single entry point
`orchestrator:verify P03` and the phase Must-Have `Check:` commands resolve to.
It runs the four P03 slice verifiers in order and is green only when every slice
passes. Mirrors `tools/verify/m034-p02-phase-suite.sh` exactly (minus the FR-6
surface assertion, which P03 doesn't add).

## Steps

### Author `tools/verify/m034-p03-phase-suite.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m034-p03-phase-suite.sh — M034 P03 T04 phase-suite aggregator.
#
# The single entry point orchestrator:verify P03 (and the phase Must-Have
# `Check:` commands) resolve to. Runs the four P03 slice verifiers in order
# (plain `bash <path>` — never run-probe, per plan-time discipline rule 4),
# printing each one's output.
#
# Prints "PASS: m034-p03 phase-suite (4/4 slices)" + exit 0 iff every slice
# exited 0. Otherwise "FAIL: m034-p03 phase-suite — <which failed>" + exit 1.
# Bash 3.2 / POSIX-sh single file (CON-1 / AD-19).

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

FAILED=""

for slice in mcp-stub registration runtime-assumptions byte-parity; do
  verifier="$REPO_ROOT/tools/verify/m034-p03-$slice.sh"
  echo "--- m034-p03-$slice ---"
  if [ ! -f "$verifier" ]; then
    echo "slice verifier missing: $verifier"
    FAILED="$FAILED slice:$slice(missing)"
    continue
  fi
  bash "$verifier"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    FAILED="$FAILED slice:$slice(exit $rc)"
  fi
done

if [ -z "$FAILED" ]; then
  echo "PASS: m034-p03 phase-suite (4/4 slices)"
  exit 0
fi

echo "FAIL: m034-p03 phase-suite —$FAILED"
exit 1
```

## Must-Haves

- `tools/verify/m034-p03-phase-suite.sh` runs the four P03 slice verifiers (mcp-stub, registration, runtime-assumptions, byte-parity) and is green only when every slice passes.

## Verification

```bash
bash tools/verify/m034-p03-phase-suite.sh
```

## Inputs

### From Disk (Pre-existing)
- `tools/verify/m034-p02-phase-suite.sh` — the structural model (the `for slice in … do bash "$verifier"; done` loop + the FAILED-accumulator + the PASS/FAIL print).
- The four P03 slice verifiers (T01-T03), each printing `PASS: m034-p03 <slice>` + exit 0 on success.

## Constraints

- CON-1: bash 3.2 / POSIX-sh single file.
- Invoke slice verifiers via `bash <path>` directly (never `run-probe.sh` — plan-time discipline rule 4: repo-resident verifiers run directly).
- The aggregator only RUNS the slices; it adds no new assertions of its own (each slice owns its assertions).

## Expected Output

See `## Notes`.

## Notes

`bash tools/verify/m034-p03-phase-suite.sh` prints each slice's output then
`PASS: m034-p03 phase-suite (4/4 slices)` + exit 0 when all four pass; otherwise
`FAIL: m034-p03 phase-suite — <which failed>` + exit 1.
