---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P04"
milestone: "M032"
provides:
  - "SC-12 milestone-grain acceptance battery aggregator tests/m032-acceptance/run-acceptance-battery.sh implementing MIT-001 three-category exit-code semantics (rc==0/77/other -> pass++/skip++/fail++) chaining all eleven SC verifiers (SC-1..SC-11) literal-sequence per AD-19 single-script-file shape with M030/M031 set -uo pipefail + run_sc() helper + final BATTERY: pass=N skip=M fail=K envelope + M032_ACCEPTANCE_BATTERY_DRY=1 test-only dry-mode escape hatch emitting synthetic BATTERY-SKIP per slot; tools/verify/m032-p04-acceptance-battery-shape.sh shape verifier (29/29 PASS) asserting path+executable+token-surface (set -uo pipefail/run_sc/BATTERY:/MIT-001/SKIP_REASON/rc -eq 77/three-counters/three-line-shapes/eleven-SC-labels/no-for-loop/dry-mode-env-var) + dry-mode runtime check (runner exits 0 emitting BATTERY: pass=0 skip=11 fail=0 with eleven BATTERY-SKIP lines)"
requires:
  - "from:P04/T01 what:SC-8 acceptance script p0X-scanner-extensions.sh; from:P04/T02 what:SC-9 acceptance script p0X-code-decorator.sh; from:P04/T03 what:SC-11 acceptance script sc11-doctor-no-warnings.sh; from:P01 what:SC-1/SC-2/SC-10 acceptance scripts; from:P02 what:SC-3/SC-7 acceptance scripts; from:P03 what:SC-4/SC-5/SC-6 acceptance scripts"
affects:
  - "P04/T05"
key_files:
  - "tests/m032-acceptance/run-acceptance-battery.sh,tools/verify/m032-p04-acceptance-battery-shape.sh"
key_decisions:
  - "SC-12,MIT-001,AD-19,MEM001,M030-lineage,M031-lineage"
patterns_established:
  - "three-category battery aggregator over MIT-001 (rc==0/77/other -> pass++/skip++/fail++) wrapped around the M030/M031 run_sc() helper -- reusable for any future milestone whose acceptance corpus includes live-network gates that need POSIX skip-code distinction from real failures; test-only dry-mode escape hatch in acceptance battery runners (<MILESTONE>_ACCEPTANCE_BATTERY_DRY=1 emits synthetic skip per slot) lets shape verifier exercise count-contract without invoking real SCs (mirrors P03 <TOOL>_<HELPER>_STUB envelope and P02 M032_WIKI_INIT_FORCE_EXIT envelope); shape verifier with embedded runtime check (beyond grep-for-token assertions executes runner under dry-mode and parses final BATTERY: line + counts BATTERY-SKIP emissions -- catches drift between literal SC label list and actual run_sc call sites that a static grep would miss)"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P04/tasks/T04-acceptance-battery-PAYLOAD.md,.orchestrator/milestones/M032/phases/P04/tasks/T04-acceptance-battery-PLAN.md"
duration: "30m"
verification_result: "pass"
completed_at: "2026-05-05T05:30:00Z"
---

## What Shipped

T04 lands the M032 SC-12 milestone-grain acceptance battery
aggregator (`tests/m032-acceptance/run-acceptance-battery.sh`) plus
its companion shape verifier
(`tools/verify/m032-p04-acceptance-battery-shape.sh`):

1. **tests/m032-acceptance/run-acceptance-battery.sh** — single-script
   bash 3.2 (AD-19 shape). Inherits the M030/[M031](../../../../../milestones/M031/index.md) lineage
   (`set -uo pipefail` + `run_sc()` helper + final `BATTERY:` envelope)
   and extends it with the MIT-001 three-category exit-code semantics:
   `rc==0` → pass++, `rc==77` → skip++, other → fail++. Eleven SC
   verifiers (SC-1..SC-11) chained literal-sequence per AD-19 — no
   for-loop over the invocation list. Final stdout line is
   `BATTERY: pass=N skip=M fail=K`; exits 0 iff `fail==0`.
   The runner exposes a test-only `M032_ACCEPTANCE_BATTERY_DRY=1`
   env-var that emits a synthetic `BATTERY-SKIP` per slot
   (`BATTERY: pass=0 skip=11 fail=0`) so shape verification can
   exercise the eleven-count without exercising every real SC.

2. **tools/verify/m032-p04-acceptance-battery-shape.sh** — shape
   verifier asserting the runner's path + executable bit + load-bearing
   token surface (`set -uo pipefail`, `run_sc()`, `BATTERY:` envelope,
   `MIT-001` citation, `SKIP_REASON`, `rc -eq 77` skip branch, three
   counter tokens, three battery line shapes, all eleven SC labels,
   no for-loop over SCs, `M032_ACCEPTANCE_BATTERY_DRY` env-var) +
   dry-mode runtime check (the runner exits 0 under
   `M032_ACCEPTANCE_BATTERY_DRY=1` and emits exactly
   `BATTERY: pass=0 skip=11 fail=0` with eleven `BATTERY-SKIP` lines).
   Final line `SUMMARY: m032-p04-acceptance-battery-shape pass=29 fail=0`.

## Verification Results

- `tools/verify/m032-p04-acceptance-battery-shape.sh`: **29/29 PASS**.
- `M032_ACCEPTANCE_BATTERY_DRY=1 bash tests/m032-acceptance/run-acceptance-battery.sh`:
  emits eleven `BATTERY-SKIP` lines + `BATTERY: pass=0 skip=11 fail=0`
  and exits 0.
- Sibling-phase regression: `m032-p02-phase-suite.sh` **12/12 PASS**;
  `m032-p03-phase-suite.sh` **10/10 PASS**. Both green at their close
  numbers.

## Key Decisions

- **MIT-001 three-category exit-code contract** is the load-bearing
  invariant. The pass counter MUST NOT be incremented on `rc==77`;
  the skip counter is distinct and the runner exits 0 on
  `fail==0` regardless of skip count. The skip==1 case (SC-5
  unauthenticated CI) is acceptable for milestone close ONLY with the
  M032-SUMMARY.md signed-attestation gate enforced by T05's
  milestone-close-ceremony verifier — not by this script.
- **AD-19 single-script-file shape — literal-sequence run_sc invocations**.
  Eleven `run_sc` calls, one per SC; no for-loop iterating over an SC
  list; no compound chains; no eval. The shape verifier asserts the
  no-for-loop invariant explicitly via `grep -E '^[[:space:]]*for[[:space:]]+.*[Ss][Cc]-'`.
- **M030/M031 lineage inheritance** — `set -uo pipefail` + `run_sc()`
  helper + final `BATTERY:` envelope preserved verbatim. The MIT-001
  three-category extension is additive over the M031 binary
  (pass/fail) shape.
- **Dry-mode escape hatch via M032_ACCEPTANCE_BATTERY_DRY=1** — emits
  a synthetic skip per slot so the shape verifier can validate the
  eleven-count and dry-mode exit behavior without invoking the real
  SC chain (especially SC-5 which would otherwise either skip on
  unauthenticated environments or attempt live remote-state mutation).
- **On-disk path verbatim referencing** — SC-4 (`p02-wiki-init-with-giscus.sh`)
  and SC-6 (`p02-wiki-generate-nav-custom-region.sh`) carry the
  spec-text `p02-` prefix even though they were authored in P03. The
  battery references the on-disk paths verbatim; no rename for prefix
  consistency.

## Patterns Established

- **Three-category battery aggregator over MIT-001** — the
  `pass++/skip++/fail++` exit-code mapping (rc==0/77/other) wrapped
  around the M030/M031 `run_sc()` helper. Reusable for any future
  milestone whose acceptance corpus includes live-network gates that
  need POSIX skip-code distinction from real failures.
- **Test-only dry-mode escape hatch in acceptance battery runners** —
  `<MILESTONE>_ACCEPTANCE_BATTERY_DRY=1` env-var emits a synthetic
  skip per slot; lets the shape verifier exercise the eleven-count
  contract without invoking real SCs. Reusable for any milestone whose
  battery references SCs that require expensive setup or external
  state (network, fixtures, auth). Mirrors the
  `<TOOL>_<HELPER>_STUB=<1|fail>` envelope established in P03/T01 and
  the `M032_WIKI_INIT_FORCE_EXIT` envelope established in P02/T02.
- **Shape verifier with embedded runtime check** — beyond grep-for-token
  assertions, the shape verifier executes the runner under dry-mode
  and parses the final `BATTERY:` line + counts the `BATTERY-SKIP`
  emissions. Catches drift between the literal SC label list and the
  actual run_sc call sites — a static grep would only assert label
  presence, not call-site count.

## Affects Downstream

- **T05 (milestone-close-ceremony)** — T05's
  `tools/verify/m032-p04-milestone-close-ceremony.sh` will invoke the
  battery as the load-bearing close gate (full live run expected
  `BATTERY: pass=10 skip=1 fail=0` or `pass=11 skip=0 fail=0`); the
  signed-attestation block in M032-SUMMARY.md is the gate that
  permits skip==1 for SC-5 unauthenticated.
- **T05 phase-suite aggregator** — will chain
  `m032-p04-acceptance-battery-shape.sh` as one of the SC-12-related
  sub-gates per the AD-19 single-script-file shape established in
  P02/P03 phase-suite-aggregator pattern.
