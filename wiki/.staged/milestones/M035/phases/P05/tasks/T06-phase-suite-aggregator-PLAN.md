---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P05"
milestone: "M035"
name: "Phase-suite aggregator — `tools/verify/m035-p05-phase-suite.sh` (BATTERY rollup across all P05 verifiers)"
depends_on: ["T01", "T02", "T03", "T04", "T05"]
---

## Prerequisites

- **T01–T05 all closed** with their per-truth verifiers on disk:
  - `tools/verify/m035-p05-rollback-marker-shape.sh` (T01)
  - `tools/verify/m035-p05-rollback-snapshot-presence.sh` (T01)
  - `tools/verify/m035-p05-rollback-driver-shape.sh` (T02)
  - `tools/verify/m035-p05-update-skill-doc-shape.sh` (T02)
  - `tools/verify/m035-p05-release-workflow-signing-shape.sh` (T03)
  - `tools/verify/m035-p05-installation-doc-verifying-integrity.sh` (T04)
  - `tools/verify/m035-p05-signature-verification.sh` (T05)
  - `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` (T05)
- **Pattern reference**: `tools/verify/m035-p02-phase-suite.sh` (P02 T05)
  is the canonical aggregator shape this task mirrors. T06 reads it at
  execution time.
- **`scripts/lib/errors.sh`** exports `emit_result`. Used by the
  aggregator.
- No `tools/verify/m035-p05-phase-suite.sh` exists at plan-authoring
  time.

## Description

T06 ships the phase-suite aggregator that chains every P05 per-truth
verifier and emits a single `BATTERY: pass=N fail=N skip=M` summary
line. The aggregator is the load-bearing entry point for:

1. **Phase-close verification** — `validate-milestone.sh M035` invokes
   every phase's aggregator; T06's aggregator reports P05's status.
2. **Acceptance-battery rollup** — the M035 acceptance battery (when
   it lands at milestone close) greps for `BATTERY:` lines across
   phase aggregators.
3. **Auto-loop verification** — `auto-loop.sh --step=V` invokes the
   phase-suite aggregator at phase close.

The aggregator's contract:

1. Run each verifier sequentially.
2. Capture each verifier's BATTERY line.
3. Sum pass/fail/skip across all verifiers.
4. Emit individual verifier `PASS:` / `FAIL:` decisions to stdout.
5. Emit `BATTERY: pass=<sum> fail=<sum> skip=<sum>` final line.
6. Exit 0 if `fail=0`, else exit 1.

The aggregator does NOT re-run the verifiers' internal assertions;
each verifier is a black box that the aggregator trusts to emit a
single BATTERY line. This mirrors the P02 T05 pattern.

## Steps

1. **Read `tools/verify/m035-p02-phase-suite.sh`** to confirm the
   exact aggregation shape (BATTERY-line parsing, exit code policy,
   error redirection, per-verifier output policy). T06 mirrors
   P02's idioms verbatim where they apply.

2. **Author `tools/verify/m035-p05-phase-suite.sh`**. ~80 lines.
   Single-script-file shape, AD-19. Bash 3.2 compatible (the
   verifier runs from local dispatch as well as CI).

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p05-phase-suite.sh
   # M035 P05 — phase-suite aggregator.
   # Chains every P05 per-truth verifier; emits BATTERY rollup.
   set -u
   REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
   cd "$REPO_ROOT"

   total_pass=0
   total_fail=0
   total_skip=0

   # Verifier list — milestone-prefixed slug per AD-19 naming.
   # Order: T01 → T05 (parallels the task-plan dependency tree).
   verifiers=(
     "tools/verify/m035-p05-rollback-marker-shape.sh"
     "tools/verify/m035-p05-rollback-snapshot-presence.sh"
     "tools/verify/m035-p05-rollback-driver-shape.sh"
     "tools/verify/m035-p05-update-skill-doc-shape.sh"
     "tools/verify/m035-p05-release-workflow-signing-shape.sh"
     "tools/verify/m035-p05-installation-doc-verifying-integrity.sh"
     "tools/verify/m035-p05-signature-verification.sh"
     "tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh"
   )

   for v in "${verifiers[@]}"; do
     if [ ! -x "$v" ] && [ ! -f "$v" ]; then
       echo "FAIL: verifier missing: $v" >&2
       total_fail=$((total_fail + 1))
       continue
     fi
     err_log="$(mktemp -t m035-p05-suite.XXXXXX)"
     out_log="$(mktemp -t m035-p05-suite-out.XXXXXX)"
     bash "$v" >"$out_log" 2>"$err_log"
     rc=$?
     # Extract BATTERY line from verifier output (last line is canonical)
     battery_line="$(grep -E '^BATTERY:' "$out_log" | tail -1)"
     if [ -z "$battery_line" ]; then
       echo "FAIL: $v emitted no BATTERY line (rc=$rc)" >&2
       total_fail=$((total_fail + 1))
       cat "$err_log" >&2
     else
       # Parse BATTERY: pass=N fail=M skip=K
       p="$(echo "$battery_line" | sed -E 's/.*pass=([0-9]+).*/\1/')"
       f="$(echo "$battery_line" | sed -E 's/.*fail=([0-9]+).*/\1/')"
       k="$(echo "$battery_line" | sed -E 's/.*skip=([0-9]+).*/\1/')"
       # If skip= absent in line, treat as 0
       case "$battery_line" in
         *skip=*) ;;
         *) k=0 ;;
       esac
       total_pass=$((total_pass + p))
       total_fail=$((total_fail + f))
       total_skip=$((total_skip + k))
       if [ "$f" -eq 0 ]; then
         echo "PASS: $v ($battery_line)"
       else
         echo "FAIL: $v ($battery_line)"
         cat "$err_log" >&2
       fi
     fi
     rm -f "$err_log" "$out_log"
   done

   echo "BATTERY: pass=$total_pass fail=$total_fail skip=$total_skip"
   [ "$total_fail" -eq 0 ] || exit 1
   ```

3. **Make the aggregator executable**:

   ```bash
   chmod +x tools/verify/m035-p05-phase-suite.sh
   ```

4. **Self-check**: run the aggregator end-to-end:

   ```bash
   bash tools/verify/m035-p05-phase-suite.sh
   ```

   Expected: every per-truth verifier reports `PASS:` (with their own
   BATTERY: lines parsed and accumulated), and the final line is
   `BATTERY: pass=N fail=0 skip=M` where N sums all per-verifier
   passes and M sums all per-verifier skips (currently exactly 1
   from T05's cosign-live skip).

## Must-Haves

- `tools/verify/m035-p05-phase-suite.sh` exists, is executable, ~80
  lines, contains `BATTERY:` literal AND each of the eight per-truth
  verifier paths.
- Running the aggregator emits `BATTERY: pass=N fail=0 skip=K` where
  `N >= 30` (sum of expected verifier passes per the per-task plans:
  T01 = 6+3, T02 = 4+5, T03 = 10, T04 = 9, T05 = 7+6 = 50; aggregator
  carries an additional `BATTERY:` of its own that is the rollup, not
  a per-verifier check).

## Verification

```bash
bash tools/verify/m035-p05-phase-suite.sh
```

## Inputs

### From Previous Tasks

- All eight per-truth verifiers from T01–T05. Each emits a single
  `BATTERY: pass=N fail=N [skip=M]` line on stdout per the AD-19
  acceptance-battery line-shape convention.
  - T01: `m035-p05-rollback-marker-shape.sh` (BATTERY: pass=6 fail=0)
  - T01: `m035-p05-rollback-snapshot-presence.sh` (BATTERY: pass=3 fail=0)
  - T02: `m035-p05-rollback-driver-shape.sh` (BATTERY: pass=4 fail=0)
  - T02: `m035-p05-update-skill-doc-shape.sh` (BATTERY: pass=5 fail=0)
  - T03: `m035-p05-release-workflow-signing-shape.sh` (BATTERY: pass=10 fail=0)
  - T04: `m035-p05-installation-doc-verifying-integrity.sh` (BATTERY: pass=9 fail=0)
  - T05: `m035-p05-signature-verification.sh` (BATTERY: pass=7 fail=0 skip=1)
  - T05: `m035-p05-rollback-byte-equivalence.sh` (BATTERY: pass=6 fail=0)

### From Disk (Pre-existing)

- `tools/verify/m035-p02-phase-suite.sh` (P02 T05) — pattern reference
  for the aggregator shape. T06 mirrors the BATTERY-line parsing
  idiom verbatim.
- `scripts/lib/errors.sh` — sourceable, but T06 aggregator does NOT
  source it (the aggregator emits plain `PASS:` / `FAIL:` lines
  directly via `echo`, mirroring the P02 T05 convention).

## Constraints

- **AD-19 single-script-file shape** — every verifier invocation in
  the aggregator's loop is `bash "$v"` (single-script). No compound
  chains. The `for v in ...; do ...; done` is a single shell
  construct.
- **Bash 3.2 compatibility** — `${verifiers[@]}` array iteration,
  `$((... + ...))` arithmetic, `case` patterns are all bash 3.2
  safe. The `mktemp -t` flag is portable across BSD and GNU mktemp.
- **No process substitution** — `> "$out_log" 2> "$err_log"` is
  plain redirection, not process substitution. The grep on the
  captured log file is a single command.
- **No `<()` or `>()`** — output capture goes to tempfiles which are
  read with grep. This survives both AP-009 shape-guard and AD-19.
- **CON-5 alignment** — the aggregator's BATTERY rollup is one of
  the inputs the M035 acceptance battery will grep at milestone
  close. Consistent line-shape across all phase aggregators is
  required for the rollup to work.
- **Plan-Time Discipline Rule 6** — `tools/verify/m035-p05-phase-suite.sh`
  is absent at plan-authoring time. New file, milestone-prefixed
  slug per the M001 P00 convention amendment (the missing-prefix
  collision pattern that lost [M030](../../../../../milestones/M030/index.md)'s aggregator).
- **Plan-Time Discipline Rule 2 (Verifier-availability cross-check)** —
  every verifier path the aggregator references is a deliverable of
  T01–T05. The aggregator's missing-verifier branch (`if [ ! -x "$v"
  ] && [ ! -f "$v" ]; then ...`) is defensive, not a substitute for
  T01–T05 actually shipping their verifiers.

## Expected Output

Stdout from `bash tools/verify/m035-p05-phase-suite.sh` (with all
T01–T05 deliverables on disk):

```
PASS: tools/verify/m035-p05-rollback-marker-shape.sh (BATTERY: pass=6 fail=0)
PASS: tools/verify/m035-p05-rollback-snapshot-presence.sh (BATTERY: pass=3 fail=0)
PASS: tools/verify/m035-p05-rollback-driver-shape.sh (BATTERY: pass=4 fail=0)
PASS: tools/verify/m035-p05-update-skill-doc-shape.sh (BATTERY: pass=5 fail=0)
PASS: tools/verify/m035-p05-release-workflow-signing-shape.sh (BATTERY: pass=10 fail=0)
PASS: tools/verify/m035-p05-installation-doc-verifying-integrity.sh (BATTERY: pass=9 fail=0)
PASS: tools/verify/m035-p05-signature-verification.sh (BATTERY: pass=7 fail=0 skip=1)
PASS: tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh (BATTERY: pass=6 fail=0)
BATTERY: pass=50 fail=0 skip=1
```

Exit code: 0.
