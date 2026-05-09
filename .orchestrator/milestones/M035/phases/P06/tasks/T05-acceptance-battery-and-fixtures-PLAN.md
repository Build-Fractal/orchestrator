---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P06"
milestone: "M035"
name: "SC-1..SC-15 acceptance battery + fixture quartet + acceptance-battery-shape verifier (SC-15 self-reference)"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- **T01–T04 closed** with their per-truth verifiers on disk:
  - `tools/verify/m035-p06-config-schema-shape.sh` (T01)
  - `tools/verify/m035-p06-multi-source-dispatch-shape.sh` (T02)
  - `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh` (T03)
  - `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh` (T04)
- **Per-phase aggregators present** for every prior M035 phase
  (P00 → P05). Verified at plan-authoring time:
  - `tools/verify/m035-p00-phase-suite.sh` ✓
  - `tools/verify/m035-p015-phase-suite.sh` (P01.5; verify exact
    filename at execution time — could also be `m035-p01.5-phase-suite.sh`
    if the dot-form was accepted)
  - `tools/verify/m035-p02-phase-suite.sh` ✓
  - `tools/verify/m035-p03-phase-suite.sh` ✓
  - `tools/verify/m035-p04-phase-suite.sh` ✓
  - `tools/verify/m035-p05-phase-suite.sh` ✓
- **Pattern reference** — `tests/m029-acceptance/run-acceptance-battery.sh`
  is the canonical milestone-grain acceptance-battery shape (chains
  P01/P02/P03 sub-batteries; emits BATTERY rollup). T05 mirrors this
  shape but chains phase-suite aggregators directly rather than per-phase
  sub-batteries.
- **`scripts/lib/errors.sh`** exports `emit_result`. Used by T05's
  acceptance-battery-shape verifier.
- **`scripts/util/run-probe.sh`** exists for any staged probe needs.
  T05 does NOT use this for the battery script itself (the battery
  is repo-resident); only fixture-construction probes (if any) run
  through `run-probe.sh`.
- **None of the following exist on disk** at plan-authoring time
  (Plan-Time Discipline Rule 6 confirmed absent):
  - `tests/m035-acceptance/run-acceptance-battery.sh`
  - `tests/m035-acceptance/fixtures/m035-p06-config-update-source-git/`
  - `tests/m035-acceptance/fixtures/m035-p06-config-update-source-npm/`
  - `tests/m035-acceptance/fixtures/m035-p06-config-update-source-homebrew/`
  - `tests/m035-acceptance/fixtures/m035-p06-config-update-source-none/`
  - `tools/verify/m035-p06-acceptance-battery-shape.sh`
- **`scripts/verify/validate-milestone.sh`** exists. T05 does NOT
  invoke it (T06 does, post-marker-write); T05's battery surfaces
  the SC-1..SC-15 evidence that `validate-milestone.sh` consumes.

## Description

T05 ships the milestone-grain acceptance battery for M035 plus the
four fixture project trees that T02's dispatch verifier consumes
(repurposed here as inline test surface for the battery's SC-13
arm). Two surfaces:

1. **`tests/m035-acceptance/run-acceptance-battery.sh`** — chains
   every per-phase aggregator (P00 → P01.5 → P02 → P03 → P04 → P05
   → P06 + the acceptance-battery-shape verifier itself for the
   SC-15 self-reference), reports per-phase PASS/FAIL, sums
   pass/fail/skip across all sub-aggregators, and emits a
   single `BATTERY: pass=N fail=0 skip=M` rollup line. The pass
   count maps to SCs covered:
   - SC-1..SC-4 → P01 phase-suite
   - SC-5, SC-6 → P00 phase-suite
   - SC-7, SC-7b → P01.5 phase-suite
   - SC-8 → P02 phase-suite
   - SC-9 → P03 phase-suite (live-channel MOS-3 SKIP)
   - SC-10 → cross-channel-byte-equivalence (referenced by P02/P03/P04
     phase-suites)
   - SC-11, SC-12, SC-12b → P05 phase-suite
   - SC-13, SC-14 → P06 phase-suite (multi-source dispatch + JSONL
     emission); SC-14 secret-scoping has live-channel MOS-4/MOS-5
     SKIPs that surface as `skip=2` in the rollup
   - SC-15 → the battery script's own BATTERY line (self-reference)
   - SC-16 → NOT covered by the battery (T06 owns this via
     `validate-milestone.sh M035 = PASS` + `M035-VALIDATED` marker;
     chicken-and-egg loop avoided)

2. **Fixture quartet** — four `tests/m035-acceptance/fixtures/m035-p06-config-update-source-{git,npm,homebrew,none}/.orchestrator/config.yml`
   files with the corresponding `update_source: <value>` line.
   These fixtures back the SC-13 dispatch arm AND are consumed by
   T02's dispatch verifier for its `--dry-run` per-channel
   assertion.

3. **`tools/verify/m035-p06-acceptance-battery-shape.sh`** — verifier
   that asserts the battery script's structural shape: file exists,
   executable, contains every chained sub-aggregator's `bash
   tools/verify/m035-p<N>-phase-suite.sh` invocation, contains the
   `BATTERY:` rollup line, and exits 0 on a green run. The
   self-reference is realized by including this verifier in the
   battery's chain — when the battery runs, it includes its own
   shape verifier in the rollup count, satisfying SC-15.

## Steps

1. **Stage the fixture quartet**. For each of `git`, `npm`,
   `homebrew`, `none`, create:
   `tests/m035-acceptance/fixtures/m035-p06-config-update-source-<value>/.orchestrator/config.yml`
   with content (verbatim, replacing `<value>`):

   ```yaml
   schema_version: "1.0"
   type: orchestrator-config
   # M035 P06 T05 fixture: drives SC-13 dispatch arm.
   update_source: <value>
   ```

   The four fixtures share the same minimal schema — only the
   `update_source` value differs.

2. **Author `tools/verify/m035-p06-acceptance-battery-shape.sh`**.
   Single-script-file shape, AD-19, ~50 lines. Sources
   `scripts/lib/errors.sh`. Asserts:

   1. `tests/m035-acceptance/run-acceptance-battery.sh` exists,
      executable.
   2. The battery script contains the literal token `BATTERY:`
      (rollup line present).
   3. The battery script contains every required sub-aggregator
      invocation:
      - `m035-p00-phase-suite.sh`
      - `m035-p015-phase-suite.sh` OR `m035-p01.5-phase-suite.sh`
        (verifier accepts either, with the actual filename
        determined at execution time)
      - `m035-p02-phase-suite.sh`
      - `m035-p03-phase-suite.sh`
      - `m035-p04-phase-suite.sh`
      - `m035-p05-phase-suite.sh`
      - `m035-p06-phase-suite.sh`
      - `m035-p06-acceptance-battery-shape.sh` (self-reference for
        SC-15)
   4. The battery script's first line is `#!/usr/bin/env bash`.
   5. The battery script contains the literal token `set -u`.
   6. The four fixture `config.yml` files exist and each contains the
      expected `update_source: <value>` line.

   Emit `BATTERY: pass=N fail=0` summary.

3. **Author `tests/m035-acceptance/run-acceptance-battery.sh`**.
   ~150 lines. Single-script-file shape, AD-19, bash 3.2. Mirrors
   the M029 acceptance-battery convention (chain sub-aggregators,
   sum BATTERY counters, emit rollup). The script:

   ```bash
   #!/usr/bin/env bash
   # tests/m035-acceptance/run-acceptance-battery.sh
   # M035 milestone-grain acceptance battery (SC-15).
   #
   # Chains every per-phase aggregator + the acceptance-battery-shape
   # verifier. Coverage:
   #   P00 phase-suite       → SC-5, SC-6
   #   P01 phase-suite       → SC-1..SC-4
   #   P01.5 phase-suite     → SC-7, SC-7b
   #   P02 phase-suite       → SC-8 + part of SC-10/SC-14
   #   P03 phase-suite       → SC-9 + part of SC-10/SC-14 (MOS-3 SKIP)
   #   P04 phase-suite       → part of SC-10/SC-14 (MOS-4/MOS-5 SKIP)
   #   P05 phase-suite       → SC-11, SC-12, SC-12b
   #   P06 phase-suite       → SC-13, part of SC-14 (multi-source dispatch + JSONL)
   #   acceptance-battery    → SC-15 (self-reference)
   #
   # SC-16 is NOT covered here (T06 owns it via validate-milestone.sh
   # + M035-VALIDATED marker; chicken-and-egg loop avoided).
   #
   # Bash 3.2 / MEM001 / AD-19 single-script-file shape.

   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"

   total_pass=0
   total_fail=0
   total_skip=0

   # Discover P01.5 aggregator filename — the dot-form is operator-
   # readable but some discovery tools may have normalized to p015.
   P015_AGG=""
   if [ -x "tools/verify/m035-p015-phase-suite.sh" ]; then
     P015_AGG="tools/verify/m035-p015-phase-suite.sh"
   elif [ -x "tools/verify/m035-p01.5-phase-suite.sh" ]; then
     P015_AGG="tools/verify/m035-p01.5-phase-suite.sh"
   fi

   # The chain-and-rollup pattern: invoke each sub-aggregator,
   # capture stdout to a tempfile, parse its BATTERY line, sum
   # counters into total_*. Exit 0 iff total_fail=0.
   run_one() {
     local label="$1"
     local cmd="$2"
     if [ ! -x "$cmd" ]; then
       printf 'SKIP: %s — verifier not found at %s\n' "$label" "$cmd"
       total_skip=$(( total_skip + 1 ))
       return 0
     fi
     local out_log
     out_log="$(mktemp)"
     local err_log
     err_log="$(mktemp)"
     bash "$cmd" >"$out_log" 2>"$err_log"
     local rc=$?
     local battery_line
     battery_line="$(grep -E '^BATTERY:' "$out_log" | tail -1)"
     local p=0 f=0 s=0
     if [ -n "$battery_line" ]; then
       p="$(echo "$battery_line" | sed -E 's/.*pass=([0-9]+).*/\1/' | head -1)"
       f="$(echo "$battery_line" | sed -E 's/.*fail=([0-9]+).*/\1/' | head -1)"
       case "$battery_line" in
         *skip=*) s="$(echo "$battery_line" | sed -E 's/.*skip=([0-9]+).*/\1/' | head -1)" ;;
         *)       s=0 ;;
       esac
     fi
     # Defensive: if grep/sed yielded non-numeric, fall back to 0.
     case "$p" in ''|*[!0-9]*) p=0 ;; esac
     case "$f" in ''|*[!0-9]*) f=0 ;; esac
     case "$s" in ''|*[!0-9]*) s=0 ;; esac
     total_pass=$(( total_pass + p ))
     total_fail=$(( total_fail + f ))
     total_skip=$(( total_skip + s ))
     if [ "$rc" -eq 0 ]; then
       printf 'PASS: %s (pass=%s fail=%s skip=%s)\n' "$label" "$p" "$f" "$s"
     else
       printf 'FAIL: %s (rc=%d pass=%s fail=%s skip=%s)\n' "$label" "$rc" "$p" "$f" "$s"
       cat "$err_log" >&2
     fi
     rm -f "$out_log" "$err_log"
   }

   run_one "P00 phase-suite (SC-5/SC-6)"     "tools/verify/m035-p00-phase-suite.sh"
   if [ -n "$P015_AGG" ]; then
     run_one "P01.5 phase-suite (SC-7/SC-7b)"  "$P015_AGG"
   else
     printf 'SKIP: P01.5 phase-suite — neither m035-p015-phase-suite.sh nor m035-p01.5-phase-suite.sh found\n'
     total_skip=$(( total_skip + 1 ))
   fi
   run_one "P02 phase-suite (SC-8 + part SC-10/SC-14)"  "tools/verify/m035-p02-phase-suite.sh"
   run_one "P03 phase-suite (SC-9 + MOS-3 SKIP)"        "tools/verify/m035-p03-phase-suite.sh"
   run_one "P04 phase-suite (part SC-10/SC-14 + MOS-4/MOS-5 SKIP)"  "tools/verify/m035-p04-phase-suite.sh"
   run_one "P05 phase-suite (SC-11/SC-12/SC-12b)"       "tools/verify/m035-p05-phase-suite.sh"
   run_one "P06 phase-suite (SC-13 + part SC-14)"       "tools/verify/m035-p06-phase-suite.sh"
   run_one "Acceptance-battery shape (SC-15 self-reference)"  "tools/verify/m035-p06-acceptance-battery-shape.sh"

   # P01 phase-suite covers SC-1..SC-4. P01 is closed but verify the
   # aggregator was actually shipped — best-effort SKIP if absent.
   run_one "P01 phase-suite (SC-1..SC-4)"               "tools/verify/m035-p01-phase-suite.sh"

   # Final rollup line. SC-15 self-reference: this very line.
   printf 'BATTERY: pass=%d fail=%d skip=%d\n' "$total_pass" "$total_fail" "$total_skip"

   if [ "$total_fail" -eq 0 ]; then
     exit 0
   else
     exit 1
   fi
   ```

   Make it executable (`chmod +x`).

4. **Run the battery once locally** (manual sanity check, NOT
   committed): `bash tests/m035-acceptance/run-acceptance-battery.sh`
   should emit a `BATTERY: pass=N fail=0 skip=M` line. If any
   aggregator FAILs, the battery exits 1 — this is the load-bearing
   gate that T06's milestone-close logic depends on.

## Must-Haves

- `tests/m035-acceptance/run-acceptance-battery.sh` exists,
  executable, ~150+ lines, contains `BATTERY:`, contains every
  required sub-aggregator invocation (eight per-phase + one
  acceptance-battery-shape self-reference + P01 best-effort).
- Four fixture `config.yml` files exist under
  `tests/m035-acceptance/fixtures/m035-p06-config-update-source-{git,npm,homebrew,none}/.orchestrator/`
  each carrying the matching `update_source:` line.
- `tools/verify/m035-p06-acceptance-battery-shape.sh` exists,
  executable, ~50+ lines, contains `BATTERY:`, runs against the
  battery script + fixture quartet, emits `BATTERY: pass=N fail=0`.

## Verification

```bash
bash tools/verify/m035-p06-acceptance-battery-shape.sh
```

```bash
bash tests/m035-acceptance/run-acceptance-battery.sh
```

## Inputs

### From Previous Tasks

- `tools/verify/m035-p06-config-schema-shape.sh` (from T01)
- `tools/verify/m035-p06-multi-source-dispatch-shape.sh` (from T02)
- `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh` (from T03)
- `tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh` (from T04)
  - Key contract: each emits a single `BATTERY: pass=N fail=N` line
    on stdout. T05's battery does NOT chain these directly — they
    chain through T06's phase-suite aggregator. T05 references them
    only through that aggregator.

### From Disk (Pre-existing)

- `tools/verify/m035-p00-phase-suite.sh` — P00 aggregator (closed).
- `tools/verify/m035-p01-phase-suite.sh` — P01 aggregator (closed).
- `tools/verify/m035-p015-phase-suite.sh` (or `m035-p01.5-phase-suite.sh`)
  — P01.5 aggregator. Filename verified at execution time.
- `tools/verify/m035-p02-phase-suite.sh` — P02 aggregator.
- `tools/verify/m035-p03-phase-suite.sh` — P03 aggregator.
- `tools/verify/m035-p04-phase-suite.sh` — P04 aggregator.
- `tools/verify/m035-p05-phase-suite.sh` — P05 aggregator.
- `tests/m029-acceptance/run-acceptance-battery.sh` — pattern
  reference for the chain-and-rollup shape.
- `scripts/lib/errors.sh` — sourceable lib exporting `emit_result`.
  Used by T05's verifier.

## Constraints

- **AD-19 single-script-file shape** — every check command is `bash
  <single-script>`. The battery's `run_one` helper uses a
  function-body composition (mktemp + bash + grep + sed) which is
  AP-009-permitted (function bodies are not subject to the inline-
  compound-shape guard); per the P05 T06 phase-suite precedent.
- **Bash 3.2 + POSIX-sh** — CON-2/CON-7. The battery runs on macOS
  bash 3.2 unmodified. No associative arrays, no process
  substitution, no herestrings.
- **BATTERY-line shape consistency** — `BATTERY: pass=N fail=N
  skip=M` matches the M029/M030/M031/M032/M037 + M035 P02/P03/P04/P05
  phase-suite convention. Operators reading the battery output get
  consistent shape across milestones.
- **Defensive numeric parsing** — the `case "$X" in ''|*[!0-9]*) X=0 ;;`
  guard catches grep/sed failures (empty match, non-numeric output)
  and falls back to 0 rather than letting `$(( total + non-num ))`
  cause a bash arithmetic error. Mirrors the M027 P02 + M032 P03
  rollup-defensive patterns.
- **SKIP semantics** — missing sub-aggregators (e.g. if P01.5's
  aggregator filename diverges from both candidates) emit `SKIP:`
  + increment `total_skip` rather than FAIL. This protects against
  filename-shape drift across milestones; the verifier separately
  asserts the canonical filenames.
- **Plan-Time Discipline Rule 6 (Path-collision)** — `ls -la`
  performed against every `create` path. All ABSENT.

## Expected Output

Stdout from `bash tests/m035-acceptance/run-acceptance-battery.sh`
(approximate; actual pass count depends on each phase-suite's pass
count — sum across all):

```
PASS: P00 phase-suite (SC-5/SC-6) (pass=N fail=0 skip=K)
PASS: P01.5 phase-suite (SC-7/SC-7b) (pass=N fail=0 skip=K)
PASS: P02 phase-suite (SC-8 + part SC-10/SC-14) (pass=8 fail=0 skip=0)
PASS: P03 phase-suite (SC-9 + MOS-3 SKIP) (pass=7 fail=0 skip=0)
PASS: P04 phase-suite (part SC-10/SC-14 + MOS-4/MOS-5 SKIP) (pass=6 fail=0 skip=0)
PASS: P05 phase-suite (SC-11/SC-12/SC-12b) (pass=50 fail=0 skip=1)
PASS: P06 phase-suite (SC-13 + part SC-14) (pass=N fail=0 skip=K)
PASS: Acceptance-battery shape (SC-15 self-reference) (pass=N fail=0 skip=0)
PASS: P01 phase-suite (SC-1..SC-4) (pass=N fail=0 skip=K)
BATTERY: pass=N fail=0 skip=K
```

Stdout from `bash tools/verify/m035-p06-acceptance-battery-shape.sh`:

```
PASS: run-acceptance-battery.sh exists and is executable
PASS: battery contains BATTERY: rollup line
PASS: battery references m035-p00-phase-suite.sh
PASS: battery references m035-p015-phase-suite.sh OR m035-p01.5-phase-suite.sh
PASS: battery references m035-p02-phase-suite.sh
PASS: battery references m035-p03-phase-suite.sh
PASS: battery references m035-p04-phase-suite.sh
PASS: battery references m035-p05-phase-suite.sh
PASS: battery references m035-p06-phase-suite.sh
PASS: battery references m035-p06-acceptance-battery-shape.sh (SC-15 self-reference)
PASS: battery shebang is #!/usr/bin/env bash
PASS: battery contains set -u
PASS: fixture m035-p06-config-update-source-git/.orchestrator/config.yml exists with update_source: git
PASS: fixture m035-p06-config-update-source-npm/.orchestrator/config.yml exists with update_source: npm
PASS: fixture m035-p06-config-update-source-homebrew/.orchestrator/config.yml exists with update_source: homebrew
PASS: fixture m035-p06-config-update-source-none/.orchestrator/config.yml exists with update_source: none
BATTERY: pass=16 fail=0
```
