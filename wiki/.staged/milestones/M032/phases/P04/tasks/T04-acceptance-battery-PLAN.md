---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M032"
name: "SC-12 three-category acceptance battery aggregator"
depends_on: ["T03"]
---

## Prerequisites

- T03 closed (SC-11 acceptance script at
  `tests/m032-acceptance/sc11-doctor-no-warnings.sh` is on disk so the
  battery's allowlist references an existing path). Verified by:
  - `[ -x tests/m032-acceptance/sc11-doctor-no-warnings.sh ]`
- T01 closed (SC-8 script). Verified by:
  - `[ -x tests/m032-acceptance/p0X-scanner-extensions.sh ]`
- T02 closed (SC-9 script). Verified by:
  - `[ -x tests/m032-acceptance/p0X-code-decorator.sh ]`
- All P01..P03 acceptance scripts on disk (the battery references them).
  Verified by:
  - `[ -x tests/m032-acceptance/p01-managed-bundle-shape.sh ]` (SC-1)
  - `[ -x tests/m032-acceptance/p01-symlink-mode.sh ]` (SC-2)
  - `[ -x tests/m032-acceptance/p02-wiki-init-default-scope.sh ]` (SC-3)
  - `[ -x tests/m032-acceptance/p02-wiki-init-with-giscus.sh ]` (SC-4)
  - `[ -x tests/m032-acceptance/p03-wiki-init-deploy-live.sh ]` (SC-5)
  - `[ -x tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh ]` (SC-6)
  - `[ -x tests/m032-acceptance/p02-glossary-surface.sh ]` (SC-7)
  - `[ -x tests/m032-acceptance/p01-staged-dirs-collision.sh ]` (SC-10)
- Reference precedent files for the battery shape:
  - `[ -f tests/m030-acceptance/run-acceptance-battery.sh ]`
  - `[ -f tests/m031-acceptance/run-acceptance-battery.sh ]`

## Description

T04 lands `tests/m032-acceptance/run-acceptance-battery.sh` — the
SC-12 milestone-grain acceptance battery aggregator. It chains the
eleven SC verifiers (SC-1..SC-11) in literal sequence and emits the
three-category MIT-001 summary `BATTERY: pass=N skip=M fail=K`.

The aggregator inherits the M030/[M031](../../../../../milestones/M031/index.md) shape (`set -uo pipefail` +
`run_sc()` helper + `bash <path>` literal-sequence invocation + final
`BATTERY:` envelope) and extends with the MIT-001 three-category
exit-code mapping:

- `rc == 0` → `pass++` (with `BATTERY-PASS: <label> (<path>)` line)
- `rc == 77` → `skip++` (with `BATTERY-SKIP: <label> (<path>) SKIP_REASON: <reason>` line)
- `rc != 0 && rc != 77` → `fail++` (with `BATTERY-FAIL: <label> (<path>) exited <rc>` line)

The runner exits 0 iff `fail == 0` (skip>=0 acceptable). The
`skip == 1` case (SC-5 unauthenticated CI) is acceptable for
milestone close ONLY with the M032-SUMMARY.md signed-attestation
block declaring "SC-5 was executed in an authenticated environment
and produced pass" — that gate is enforced by T05's
`m032-p04-milestone-close-ceremony.sh` verifier, not by the battery
itself.

T04 also ships the verifier
`tools/verify/m032-p04-acceptance-battery-shape.sh` asserting the
aggregator's shape (file present, executable, contains the three-
category mapping, contains all eleven SC labels, runs in dry-mode).

## Steps

1. **Author `tests/m032-acceptance/run-acceptance-battery.sh`**.
   Single-script-file shape per AD-19; bash 3.2 compatible per MEM001.
   Skeleton:

   ```bash
   #!/usr/bin/env bash
   # tests/m032-acceptance/run-acceptance-battery.sh
   # M032/P04/T04 — SC-12 acceptance battery runner.
   #
   # Invokes every M032 SC verifier in literal sequence per AD-19
   # single-script-file shape (each verifier invoked as bash <path>
   # with rc captured per-call; no compound chains, no loops over the
   # invocations, no eval).
   #
   # MIT-001 three-category exit-code semantics:
   #   rc == 0   → pass++   (BATTERY-PASS line)
   #   rc == 77  → skip++   (BATTERY-SKIP line; POSIX skip-code per MIT-001)
   #   other     → fail++   (BATTERY-FAIL line)
   #
   # Final stdout line: `BATTERY: pass=N skip=M fail=K`.
   # Exits 0 iff fail==0; non-zero if fail>0.
   #
   # The skip=1 case (SC-5 unauthenticated CI) is acceptable for
   # milestone close ONLY with the M032-SUMMARY.md signed-attestation
   # block (that gate enforced by T05's milestone-close-ceremony
   # verifier, not by this script).
   #
   # Sub-gate inventory (11 entries):
   #   SC-1, SC-2, SC-3, SC-4, SC-5, SC-6, SC-7, SC-8, SC-9, SC-10, SC-11
   #
   # Bash 3.2 compatible (parallel scalars, local inside helper, no
   # associative arrays, no process substitution).

   set -uo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

   pass=0
   skip=0
   fail=0

   run_sc() {
     # $1 SC label  $2 verifier path  $3 (optional) trailing flags
     local label="$1"
     local path="$2"
     local extra="${3:-}"

     # Test-only dry-mode escape hatch: when M032_ACCEPTANCE_BATTERY_DRY=1,
     # emit a synthetic skip without invoking the verifier (used by
     # m032-p04-acceptance-battery-shape.sh for shape verification
     # without exercising every real SC).
     if [ -n "${M032_ACCEPTANCE_BATTERY_DRY:-}" ]; then
       skip=$((skip + 1))
       printf 'BATTERY-SKIP: %s (%s) SKIP_REASON: dry-mode\n' "$label" "$path"
       return
     fi

     if [ ! -x "$path" ]; then
       fail=$((fail + 1))
       printf 'BATTERY-FAIL: %s (%s) verifier missing or non-executable\n' "$label" "$path"
       return
     fi

     if [ -n "$extra" ]; then
       bash "$path" $extra
     else
       bash "$path"
     fi
     local rc=$?

     if [ "$rc" -eq 0 ]; then
       pass=$((pass + 1))
       printf 'BATTERY-PASS: %s (%s)\n' "$label" "$path"
     elif [ "$rc" -eq 77 ]; then
       skip=$((skip + 1))
       printf 'BATTERY-SKIP: %s (%s) SKIP_REASON: exit 77\n' "$label" "$path"
     else
       fail=$((fail + 1))
       printf 'BATTERY-FAIL: %s (%s) exited %d\n' "$label" "$path" "$rc"
     fi
   }

   # ---------- P01 SCs ----------
   run_sc "SC-1"  "$PROJECT_ROOT/tests/m032-acceptance/p01-managed-bundle-shape.sh"
   run_sc "SC-2"  "$PROJECT_ROOT/tests/m032-acceptance/p01-symlink-mode.sh"
   run_sc "SC-10" "$PROJECT_ROOT/tests/m032-acceptance/p01-staged-dirs-collision.sh"

   # ---------- P02 SCs ----------
   run_sc "SC-3"  "$PROJECT_ROOT/tests/m032-acceptance/p02-wiki-init-default-scope.sh"
   run_sc "SC-7"  "$PROJECT_ROOT/tests/m032-acceptance/p02-glossary-surface.sh"

   # ---------- P03 SCs ----------
   run_sc "SC-4"  "$PROJECT_ROOT/tests/m032-acceptance/p02-wiki-init-with-giscus.sh"
   run_sc "SC-5"  "$PROJECT_ROOT/tests/m032-acceptance/p03-wiki-init-deploy-live.sh"
   run_sc "SC-6"  "$PROJECT_ROOT/tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh"

   # ---------- P04 SCs ----------
   run_sc "SC-8"  "$PROJECT_ROOT/tests/m032-acceptance/p0X-scanner-extensions.sh"
   run_sc "SC-9"  "$PROJECT_ROOT/tests/m032-acceptance/p0X-code-decorator.sh"
   run_sc "SC-11" "$PROJECT_ROOT/tests/m032-acceptance/sc11-doctor-no-warnings.sh"

   # ---------- Aggregate ----------
   printf 'BATTERY: pass=%s skip=%s fail=%s\n' "$pass" "$skip" "$fail"
   if [ "$fail" -eq 0 ]; then
     exit 0
   fi
   exit 1
   ```

2. **Author `tools/verify/m032-p04-acceptance-battery-shape.sh`**:

   The verifier asserts:
   - The runner script exists at the documented path and is executable.
   - The script contains the string `BATTERY:` (final summary line literal).
   - The script contains the string `MIT-001` (in a comment block citing
     the three-category contract).
   - The script contains the string `SKIP_REASON` (the BATTERY-SKIP
     emission).
   - The script contains the string `exit 77` or `rc -eq 77` (the
     skip-code branch).
   - The script contains all eleven SC labels: `SC-1`, `SC-2`, `SC-3`,
     `SC-4`, `SC-5`, `SC-6`, `SC-7`, `SC-8`, `SC-9`, `SC-10`, `SC-11`.
   - The script contains the three counter names: `pass=`, `skip=`,
     `fail=`.
   - The script contains `set -uo pipefail` (M030/M031 inheritance).
   - Running `M032_ACCEPTANCE_BATTERY_DRY=1 bash <runner>` emits a
     `BATTERY: pass=0 skip=11 fail=0` line and exits 0 (dry-mode
     verification of the eleven SC count).

3. **Make new scripts executable**:
   ```
   chmod +x tests/m032-acceptance/run-acceptance-battery.sh
   chmod +x tools/verify/m032-p04-acceptance-battery-shape.sh
   ```

4. **Run T04 verifier locally** to confirm green:
   - `bash tools/verify/m032-p04-acceptance-battery-shape.sh`
   - `M032_ACCEPTANCE_BATTERY_DRY=1 bash tests/m032-acceptance/run-acceptance-battery.sh`
   - (Optionally — and time-permitting) the full live battery:
     `bash tests/m032-acceptance/run-acceptance-battery.sh` — expected
     output `BATTERY: pass=10 skip=1 fail=0` (SC-5 may skip in
     unauthenticated environments) OR `BATTERY: pass=11 skip=0 fail=0`.

5. **Run sibling-phase regression check**:
   - `bash tools/verify/m032-p02-phase-suite.sh`
   - `bash tools/verify/m032-p03-phase-suite.sh`

   Both should remain green at their close-time numbers.

## Must-Haves

- `tests/m032-acceptance/run-acceptance-battery.sh` exists, is executable, implements MIT-001 three-category exit-code semantics, and emits final line `BATTERY: pass=N skip=M fail=K`
- The runner chains all eleven SC verifiers (SC-1..SC-11) in literal sequence per AD-19 single-script-file shape (each invocation is a separate `run_sc` call with `bash <path>` execution; no for-loops over the invocations)
- The runner exits 0 iff `fail == 0` (skip>=0 acceptable; skip==1 with attestation enforced by T05's milestone-close gate)
- The runner inherits the M030/M031 `set -uo pipefail` + `run_sc()` helper + final `BATTERY:` envelope shape
- The runner supports a `M032_ACCEPTANCE_BATTERY_DRY=1` test-only env-var that bypasses real SC invocations and emits `BATTERY: pass=0 skip=11 fail=0` for shape verification
- `tools/verify/m032-p04-acceptance-battery-shape.sh` asserts the runner's shape (path + executable + token surface + dry-mode exit) and ships green
- P02 + P03 phase-suites remain green post-T04

## Verification

```bash
bash tools/verify/m032-p04-acceptance-battery-shape.sh
```

```bash
M032_ACCEPTANCE_BATTERY_DRY=1 bash tests/m032-acceptance/run-acceptance-battery.sh
```

```bash
bash tools/verify/m032-p02-phase-suite.sh
```

```bash
bash tools/verify/m032-p03-phase-suite.sh
```

## Notes

Expected output:
- `m032-p04-acceptance-battery-shape.sh`: final line `SUMMARY:
  m032-p04-acceptance-battery-shape.sh pass=N fail=0`, exit 0.
- Dry-mode runner: final line `BATTERY: pass=0 skip=11 fail=0`, exit 0.
- Live runner (optional, may be deferred to T05's full integration
  pass): final line `BATTERY: pass=10 skip=1 fail=0` (SC-5 unauthenticated)
  OR `BATTERY: pass=11 skip=0 fail=0` (SC-5 authenticated).

Verifier-contract-over-verifier-skeleton latitude: the runner's
`run_sc()` helper structure is the M030/M031 idiom — preserve it
verbatim. The three-category mapping (rc==0/77/other) is the load-
bearing MIT-001 contract; preserve it verbatim. The eleven SC
invocations are literal-sequence per AD-19 — do NOT collapse into a
for-loop or compound chain.

The path-mismatch reality: SC-4 acceptance script lives at
`p02-wiki-init-with-giscus.sh` (P03-built per the spec text continuity
note in the M032 roadmap); SC-6 at `p02-wiki-generate-nav-custom-region.sh`
(also P03-built); SC-10 at `p01-staged-dirs-collision.sh`. The battery
references the on-disk paths verbatim — do NOT rename for prefix
consistency. The roadmap "no conflicting producers" validation note
(line 1128 of the planning payload) explicitly acknowledges this
naming-vs-phase mismatch as intentional.

If any prerequisite acceptance script is missing at T04 invocation
time, the runner's `[ ! -x "$path" ]` check emits a `BATTERY-FAIL`
line for that SC; the verifier's dry-mode shape check still exits 0
because dry-mode bypasses the existence check. The full live battery
is the load-bearing verification at T05's full close.

Bash 3.2 gotcha: the `local label=...` declarations require the
function be invoked from within a function body (not at script top
level). The `run_sc()` helper is a function so this is fine. Without
the function wrapper, `local` would emit a runtime error.

## Inputs

### From Previous Tasks

- `tests/m032-acceptance/sc11-doctor-no-warnings.sh` (T03) — invoked as
  SC-11 in the battery; existence and executable bit required at T04
  authoring time per plan-time discipline rule 2.
- `tests/m032-acceptance/p0X-scanner-extensions.sh` (T01) — invoked as
  SC-8 in the battery.
- `tests/m032-acceptance/p0X-code-decorator.sh` (T02) — invoked as
  SC-9 in the battery.

Each upstream verifier's contract: exit 0 on pass; exit 77 on skip
(with SKIP_REASON emission to stdout); other-non-zero on fail. The
battery does NOT parse stdout — it only consumes the exit code.

### From Disk (Pre-existing)

- `tests/m030-acceptance/run-acceptance-battery.sh` — pattern
  reference for the runner shape ([M030](../../../../../milestones/M030/index.md) lineage).
- `tests/m031-acceptance/run-acceptance-battery.sh` — pattern
  reference (M031 lineage; closest precedent — same `set -uo pipefail`
  + `run_sc()` helper structure).
- `tests/m032-acceptance/p01-managed-bundle-shape.sh` (P01) — SC-1
  invocation target.
- `tests/m032-acceptance/p01-symlink-mode.sh` (P01) — SC-2.
- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (P02) — SC-3.
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` (P03 actual,
  spec-text-prefix `p02`) — SC-4.
- `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` (P03) — SC-5
  (the only SC that may skip with exit 77).
- `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh` (P03
  actual, spec-text-prefix `p02`) — SC-6.
- `tests/m032-acceptance/p02-glossary-surface.sh` (P02) — SC-7.
- `tests/m032-acceptance/p01-staged-dirs-collision.sh` (P01) — SC-10.

## Constraints

- Single-script-file shape per AD-19. The eleven SC invocations are
  literal-sequence; no for-loop over the invocation list.
- bash 3.2 compatibility (per MEM001) — no associative arrays, no
  process substitution, no compound-chain-gt2.
- Verifier scripts under `tools/verify/m032-p04-*`.
- Acceptance battery runner under `tests/m032-acceptance/run-acceptance-battery.sh`
  (literal name per the spec; modeled on M030/M031 precedent).
- The MIT-001 three-category mapping is the load-bearing contract; the
  pass counter MUST NOT be incremented on rc==77 per MIT-001 + SC-12.
- T04 modifies ZERO files outside the new battery runner + the new
  verifier (no production-side modifications, no sibling-task
  deliverable modifications).
- The `M032_ACCEPTANCE_BATTERY_DRY=1` env-var is test-only; it MUST
  emit `pass=0 skip=11 fail=0` exactly (the eleven-count is the
  literal SC label set; if the battery's literal sequence is amended
  to a different count, the dry-mode emission must reflect it
  correspondingly).

## Expected Output

After T04 completes:

- `tests/m032-acceptance/run-acceptance-battery.sh` exists, is executable,
  emits `BATTERY: pass=N skip=M fail=K` with the three-category MIT-001
  semantics, and exits 0 in dry-mode and on a clean live run.
- `tools/verify/m032-p04-acceptance-battery-shape.sh` exists, is
  executable, and exits 0.
- P02 + P03 phase-suites remain green at their close numbers.
