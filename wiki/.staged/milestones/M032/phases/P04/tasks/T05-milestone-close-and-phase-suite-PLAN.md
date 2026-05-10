---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M032"
name: "M032 milestone close ceremony + P04 phase-suite + scope-guard"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01–T04 have all landed at execution time. T05 reads each upstream
  task's verifier paths to compose the phase-suite chain and the
  scope-guard allowlist, AND consumes T04's battery for the SC-12
  verdict in M032-SUMMARY.md and M032-ACCEPTANCE-EVIDENCE.md.
  Verified by:
  - `[ -x tools/verify/m032-p04-scanner-extensions.sh ]` (T01)
  - `[ -x tools/verify/m032-p04-nav-extensions.sh ]` (T01)
  - `[ -x tools/verify/m032-p04-acceptance-shape-sc8.sh ]` (T01)
  - `[ -x tools/verify/m032-p04-decorator-shape.sh ]` (T02)
  - `[ -x tools/verify/m032-p04-acceptance-shape-sc9.sh ]` (T02)
  - `[ -x tools/verify/m032-p04-with-wiki-noop.sh ]` (T02)
  - `[ -x tools/verify/m032-p04-acceptance-shape-sc11.sh ]` (T03)
  - `[ -x tests/m032-acceptance/run-acceptance-battery.sh ]` (T04)
  - `[ -x tools/verify/m032-p04-acceptance-battery-shape.sh ]` (T04)
- `tools/verify/fixtures/` exists from P01/P02/P03 baseline-ref
  convention. Verified by `[ -d tools/verify/fixtures ]`.
- The previous P03 baseline-ref `tools/verify/fixtures/m032-p03-baseline-ref.txt`
  exists as the pattern T05 follows for `m032-p04-baseline-ref.txt`.
  Verified by `[ -f tools/verify/fixtures/m032-p03-baseline-ref.txt ]`.
- [M030](../../../../../milestones/M030/index.md) + [M031](../../../../../milestones/M031/index.md) milestone-close artifacts exist as the pattern reference
  for M032's close ceremony:
  - `[ -f .orchestrator/milestones/M030/M030-VALIDATED ]`
  - `[ -f [.orchestrator/milestones/M030/M030-SUMMARY.md](../../../../../milestones/M030/M030-SUMMARY.md) ]`
  - `[ -f [.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) ]`
  - `[ -f .orchestrator/milestones/M031/M031-VALIDATED ]`
  - `[ -f [.orchestrator/milestones/M031/M031-SUMMARY.md](../../../../../milestones/M031/M031-SUMMARY.md) ]`
  - `[ -f [.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) ]`

## Description

T05 is the M032 milestone-close ceremony plus the P04 verification-
aggregation surface. The deliverable surface has nine pieces:

1. **`M032-SUMMARY.md`** at [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md)
   per the milestone-summary template (16-field frontmatter +
   narrative body) modeled on M030/M031.
2. **`M032-VALIDATED` marker file** at `.orchestrator/milestones/M032/M032-VALIDATED`,
   conditioned on the SC-12 outcome (skip=0 OR signed-attestation
   block in the summary).
3. **`unit_close` JSONL record** appended to `.orchestrator/milestones/M032/execution-log.jsonl`
   at milestone-grain.
4. **`M032-ACCEPTANCE-EVIDENCE.md`** at [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md)
   per the M030/M031 evidence-ledger convention.
5. **`tools/verify/m032-p04-validate-milestone.sh`** invoking
   `scripts/verify/validate-milestone.sh .orchestrator/milestones/M032/`
   and asserting the final `VALIDATE: PASS` line.
6. **`tools/verify/m032-p04-milestone-close-ceremony.sh`** asserting
   the marker + summary + JSONL record presence.
7. **`tools/verify/m032-p04-acceptance-evidence-ledger.sh`** asserting
   the evidence ledger's shape.
8. **`tools/verify/m032-p04-phase-suite.sh`** chaining all eleven P04
   sub-gates per AD-19 single-script-file shape.
9. **`tools/verify/m032-p04-scope-guard.sh`** + **`tools/verify/fixtures/m032-p04-baseline-ref.txt`**
   asserting P04's diff confined to the declared "Files Likely Touched"
   list with first-run baseline-ref capture per the M032 P01/P02/P03
   baseline-ref convention.

## Steps

1. **Run the live acceptance battery** to capture the verdict that
   M032-SUMMARY.md + M032-ACCEPTANCE-EVIDENCE.md transcribe:

   ```bash
   bash tests/m032-acceptance/run-acceptance-battery.sh > /tmp/m032-battery.out 2>&1
   ```

   Expected output: final line `BATTERY: pass=10 skip=1 fail=0`
   (SC-5 unauthenticated CI) OR `BATTERY: pass=11 skip=0 fail=0`
   (SC-5 authenticated). Capture the output for transcription into
   M032-ACCEPTANCE-EVIDENCE.md.

   If `fail > 0`, T05 STOPS and surfaces the failure for in-flight
   repair per the P03 patterns-established convention. The
   milestone-close ceremony cannot proceed with `fail > 0`.

   If `skip == 1` (SC-5 unauthenticated), T05 either (a) re-runs SC-5
   in an authenticated environment to drive `skip == 0`, OR (b)
   includes the signed-attestation block in M032-SUMMARY.md per the
   MIT-001 + SC-14 contract. The attestation block shape is documented
   in step 3 below.

2. **Run `validate-milestone.sh` to capture the framework-side verdict**:

   ```bash
   bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M032/ > /tmp/m032-validate.out 2>&1
   ```

   Expected output: `VALIDATE: PASS — NNN/NNN checks passed` with NNN
   matching the framework-side check count (phase-summary existence +
   boundary-map produces presence + cross-phase consumes-met-by-produces).

3. **Author [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md)** per the
   milestone-summary template (mirror M030 / M031 byte-for-byte where
   structurally possible). Required frontmatter shape:

   ```yaml
   ---
   schema_version: "1.0"
   type: milestone-summary
   id: "M032"
   parent: "035-wiki-distribution-init-integration"
   milestone: "M032"
   provides:
     - "<comma-separated bullet of every load-bearing surface across P01..P04>"
   requires:
     - "[M025](../../../../../milestones/M025/index.md) (installer coexistence — pinned-sha gate); M031 (Quick/Standard/Full profile contract); [M020](../../../../../milestones/M020/index.md) (knowledge-kind taxonomy); M030 (milestone-close discipline precedent); commands/conversus-gate.md (manual gate per A-5); [M035](../../../../../milestones/M035/index.md) P00 (--mode=symlink runtime cache, fallback to local cache per A-1)"
   affects:
     - "[M033](../../../../../milestones/M033/index.md) (project onboarding — paired-launch via FR-11 --with-wiki gate); M036b (post-launch wiki projection — P08 blocked by M032 closure); post-launch wiki-UX-deep + external-tool-adapters (FR-20 decorator polish surface); future --with-github-integration / --with-design-layer (FR-13 flag pattern); run-doctor.sh (FR-22 collision invariant ongoing consumer)"
   key_files:
     - "<comma-separated key-file enumeration aggregating P01..P04 key_files>"
   key_decisions:
     - "<comma-separated decision list: FR-1..FR-22, MIT-001..MIT-011, AD-5, AD-7, AD-19, CON-1..CON-6, US-1..US-8, SC-1..SC-14, Finding-A..Finding-K, MEM001, MEM012, MEM013, MEM030>"
   patterns_established:
     - "<comma-separated patterns aggregating P01..P04 patterns_established — managed project-asset distribution; sequential-atomicity dispatch; reader-only knowledge-adapter boundary; paired-milestone seam-script convention; throwaway-fixture protocol with three-category exit semantics; verifier-contract-over-verifier-skeleton course-correction; in-flight repair convention; four-step ordered remote-state mutation with audit trail; two-region marker split (auto/custom); progressive-opt-in --with-<feature> convention; first-run-captures-HEAD-as-baseline + regex-allowlist + regex-denylist twin-check>"
   drill_down_paths:
     - "[.orchestrator/milestones/M032/phases/P01/P01-SUMMARY.md](../../../../../milestones/M032/phases/P01/P01-SUMMARY.md), [.orchestrator/milestones/M032/phases/P02/P02-SUMMARY.md](../../../../../milestones/M032/phases/P02/P02-SUMMARY.md), [.orchestrator/milestones/M032/phases/P03/P03-SUMMARY.md](../../../../../milestones/M032/phases/P03/P03-SUMMARY.md), [.orchestrator/milestones/M032/phases/P04/P04-SUMMARY.md](../../../../../milestones/M032/phases/P04/P04-SUMMARY.md), [.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md)"
   duration: "<sum-of-P01..P04 durations in minutes>"
   verification_result: "pass"
   completed_at: "<ISO8601Z>"
   observability_surfaces:
     - "wiki-deploy-mutation NDJSON record on .orchestrator/execution-log.jsonl per MIT-008 (Constitution VI applied to remote-state mutations); .orchestrator/installed-files.txt per-asset mode tracking (FR-4 surface for downstream uninstall + collision-invariant inspection); BATTERY: pass=N skip=M fail=K three-category aggregator output (MIT-001); proposals: + extra: + knowledge-flat scanner record families with frontmatter stage badge derivation (FR-17/18/19 surface for wiki nav rendering)"
   ---
   ```

   The body sections (mirror M031-SUMMARY.md structure):

   - **Lead paragraph** — one paragraph: "M032 (wiki distribution +
     init integration) closes the orchestrator's distribution-surface
     gap by..." with the M032 elevator pitch.
   - **Phase rollup** — bullet per phase (P01..P04) with what shipped
     + verification verdict.
   - **Cross-phase inheritance** — patterns repeated verbatim across
     phases; effectively M032-stable utilities.
   - **Verification at close** — `BATTERY: pass=N skip=M fail=K` line
     verbatim from step 1; `validate-milestone.sh` verdict from step 2;
     per-phase phase-suite + scope-guard verdicts.
   - **Forward-pointing notes** — what's deferred to M033, post-launch
     fast-follows, etc.
   - **Signed-attestation block** (CONDITIONAL — only if `skip == 1`
     in step 1's battery output) — see template below.

   **Signed-attestation block template** (per MIT-001 + SC-14 — required
   only when battery closed at skip=1):

   ```markdown
   ## SC-5 Live-Fixture Signed Attestation (per MIT-001 + SC-14)

   The acceptance battery closed at `BATTERY: pass=10 skip=1 fail=0`
   in this run. SC-5 (`p03-wiki-init-deploy-live.sh`) emitted exit 77
   with SKIP_REASON because `gh auth status` was not authenticated in
   the close-ceremony environment. Per MIT-001 + SC-14, the
   `M032-VALIDATED` marker creation is conditioned on SC-12 `skip=0`
   OR this signed-attestation block.

   **Attestation**: SC-5 was independently executed in an authenticated
   environment on <ISO8601Z> against the throwaway GitHub fixture
   `<owner>/<ts>-m032-fixture` (created via `gh repo create
   <ts>-m032-fixture --private --add-readme`, deleted via `gh repo
   delete <ts>-m032-fixture --yes` per the AD-7 throwaway-fixture
   protocol) and produced exit 0 (pass). Operator: <signer-name>.
   Fixture cleanup verified post-teardown (no orphan branches in this
   repo, no leaked `<owner>/<ts>-m032-fixture` references in
   `.git/refs/`, no leaked `.orchestrator/` files in the consumer
   fixture).
   ```

   The attestation block carries the MIT-001 invariant verbatim — without
   it the M032-VALIDATED marker MUST NOT be created at skip=1.

4. **Create the marker file**: `touch .orchestrator/milestones/M032/M032-VALIDATED`.
   The file is empty; its presence is the marker per the M030/M031
   convention. Conditional creation gate: per the SC-14 contract, the
   marker MUST NOT be created if SC-12 closed at `skip=1` AND the
   M032-SUMMARY.md does not contain the signed-attestation block. The
   verifier `m032-p04-milestone-close-ceremony.sh` enforces this gate.

5. **Append the milestone-grain `unit_close` record** to
   `.orchestrator/milestones/M032/execution-log.jsonl`:

   ```bash
   _ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   printf '{"event_type":"unit_close","unit":"M032","timestamp":"%s","verification_result":"pass"}\n' "$_ts" \
     >> .orchestrator/milestones/M032/execution-log.jsonl
   ```

   The record is single-line NDJSON. Append-only; do not modify
   prior records.

6. **Author [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md)**
   per the M030/M031 evidence-ledger convention. Read
   [`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) and
   [`.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) as
   structural templates and produce a byte-for-byte format-mirror
   where structurally possible. Required content:

   - **Header** with milestone ID, ISO-8601 close timestamp, back-link
     to `tests/m032-acceptance/run-acceptance-battery.sh`.
   - **BATTERY line transcription** verbatim from step 1's output.
   - **Per-SC roll-up table** (one row per SC-1..SC-13) with columns
     [SC, verifier path, verdict (pass/skip/fail), last-run timestamp,
     notes (e.g. SKIP_REASON for SC-5 if applicable)].
   - **`validate-milestone.sh` transcription** — the `VALIDATE: PASS
     — NNN/NNN checks passed` line verbatim from step 2's output.
   - **SC-13 NNN derivation** — references the table in P04-PLAN.md
     `## SC-13 NNN Derivation` section (the per-script assertion-group
     count list summing to NNN). Cross-reference for audit trace.
   - **Phase-suite + scope-guard verdicts** — one row per phase
     (P01..P04) with the suite/guard verdict numbers.

7. **Author `tools/verify/m032-p04-validate-milestone.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m032-p04-validate-milestone.sh
   # M032/P04/T05 — asserts validate-milestone.sh M032 reports PASS
   # for every entry per MIT-004 + SC-13.
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT"
   pass=0; fail=0
   say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
   say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

   _out="/tmp/m032-p04-validate-$$.out"
   bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M032/ > "$_out" 2>&1
   _rc=$?
   if [ "$_rc" -eq 0 ] && grep -q '^VALIDATE: PASS' "$_out"; then
     say_pass "validate-milestone.sh M032 final line: $(grep '^VALIDATE: PASS' "$_out" | tail -1)"
   else
     say_fail "validate-milestone.sh M032 rc=$_rc; tail=$(tail -3 "$_out" | tr '\n' ' ')"
   fi
   rm -f "$_out"
   printf 'SUMMARY: m032-p04-validate-milestone.sh pass=%d fail=%d\n' "$pass" "$fail"
   [ "$fail" -eq 0 ]
   ```

8. **Author `tools/verify/m032-p04-milestone-close-ceremony.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m032-p04-milestone-close-ceremony.sh
   # M032/P04/T05 — asserts milestone close ceremony artifacts present:
   # M032-VALIDATED marker, M032-SUMMARY.md, milestone-grain unit_close
   # record in execution-log.jsonl. Conditioned on SC-12 outcome per
   # MIT-001 + SC-14.
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT"
   MILE_DIR=".orchestrator/milestones/M032"
   pass=0; fail=0
   say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
   say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

   # Marker file
   if [ -f "$MILE_DIR/M032-VALIDATED" ]; then
     say_pass "M032-VALIDATED marker present at $MILE_DIR/M032-VALIDATED"
   else
     say_fail "M032-VALIDATED marker missing at $MILE_DIR/M032-VALIDATED"
   fi

   # Summary file
   if [ -f "$MILE_DIR/M032-SUMMARY.md" ]; then
     # Spot-check shape: schema_version, type: milestone-summary, id: M032
     if grep -q 'schema_version' "$MILE_DIR/M032-SUMMARY.md" \
        && grep -q 'type: milestone-summary' "$MILE_DIR/M032-SUMMARY.md" \
        && grep -q 'id: "M032"' "$MILE_DIR/M032-SUMMARY.md"; then
       say_pass "M032-SUMMARY.md present with required frontmatter shape"
     else
       say_fail "M032-SUMMARY.md present but frontmatter shape incomplete"
     fi
     # Conditional: if signed-attestation block is required, assert it.
     # Detect skip=1 by reading the BATTERY transcription in the summary body.
     if grep -qE 'BATTERY:.*skip=1' "$MILE_DIR/M032-SUMMARY.md"; then
       if grep -q 'SC-5 Live-Fixture Signed Attestation' "$MILE_DIR/M032-SUMMARY.md"; then
         say_pass 'Signed-attestation block present (skip=1 conditional)'
       else
         say_fail 'Skip=1 verdict but signed-attestation block missing — MIT-001 violation'
       fi
     else
       say_pass 'Skip=0 — signed-attestation block not required'
     fi
   else
     say_fail "M032-SUMMARY.md missing at $MILE_DIR/M032-SUMMARY.md"
   fi

   # unit_close JSONL record
   _logfile="$MILE_DIR/execution-log.jsonl"
   if [ -f "$_logfile" ]; then
     _count=$(grep -cF '"event_type":"unit_close"' "$_logfile" || true)
     _m032_count=$(grep -cF '"unit":"M032"' "$_logfile" || true)
     if [ "$_count" -ge 1 ] && [ "$_m032_count" -ge 1 ]; then
       say_pass "unit_close milestone-grain record present in $_logfile"
     else
       say_fail "unit_close M032 record missing or count $_count/$_m032_count"
     fi
   else
     say_fail "execution-log.jsonl missing at $_logfile"
   fi

   printf 'SUMMARY: m032-p04-milestone-close-ceremony.sh pass=%d fail=%d\n' "$pass" "$fail"
   [ "$fail" -eq 0 ]
   ```

9. **Author `tools/verify/m032-p04-acceptance-evidence-ledger.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m032-p04-acceptance-evidence-ledger.sh
   # M032/P04/T05 — asserts M032-ACCEPTANCE-EVIDENCE.md present and
   # transcribes BATTERY + per-SC roll-up + back-link to runner per
   # the M030/M031 evidence-ledger convention.
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT"
   LEDGER="[.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md)"
   pass=0; fail=0
   say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
   say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

   if [ ! -f "$LEDGER" ]; then
     say_fail "evidence ledger missing at $LEDGER"
     printf 'SUMMARY: m032-p04-acceptance-evidence-ledger.sh pass=%d fail=%d\n' "$pass" "$fail"
     exit 1
   fi
   say_pass "ledger file present"

   # Required content tokens:
   for _tok in 'BATTERY:' 'SC-1' 'SC-11' 'SC-13' 'run-acceptance-battery.sh' 'VALIDATE:'; do
     if grep -qF "$_tok" "$LEDGER"; then
       say_pass "ledger contains '$_tok'"
     else
       say_fail "ledger missing '$_tok'"
     fi
   done

   printf 'SUMMARY: m032-p04-acceptance-evidence-ledger.sh pass=%d fail=%d\n' "$pass" "$fail"
   [ "$fail" -eq 0 ]
   ```

10. **Author `tools/verify/m032-p04-phase-suite.sh`** chaining all
    eleven P04 sub-gates. Mirror P03/T05's `m032-p03-phase-suite.sh`
    skeleton verbatim — the only differences are the `m032-p04-`
    prefix and the eleven gate names:

    Gates (in order):
    - `FR-17/18/19 scanner-extensions` → `m032-p04-scanner-extensions.sh`
    - `FR-17/18/19 nav-extensions` → `m032-p04-nav-extensions.sh`
    - `FR-20 decorator-shape` → `m032-p04-decorator-shape.sh`
    - `--with-wiki noop` → `m032-p04-with-wiki-noop.sh`
    - `SC-8 acceptance-shape` → `m032-p04-acceptance-shape-sc8.sh`
    - `SC-9 acceptance-shape` → `m032-p04-acceptance-shape-sc9.sh`
    - `SC-11 acceptance-shape` → `m032-p04-acceptance-shape-sc11.sh`
    - `SC-12 battery-shape` → `m032-p04-acceptance-battery-shape.sh`
    - `SC-13 validate-milestone` → `m032-p04-validate-milestone.sh`
    - `SC-14 close-ceremony` → `m032-p04-milestone-close-ceremony.sh`
    - `evidence-ledger` → `m032-p04-acceptance-evidence-ledger.sh`

    Single-script-file shape per AD-19; emits final line `SUMMARY:
    m032-p04-phase-suite.sh pass=N fail=M`; exits 0 iff every sub-
    gate passes.

11. **Author `tools/verify/m032-p04-scope-guard.sh`** mirroring
    P03/T05's `m032-p03-scope-guard.sh` skeleton verbatim. The
    differences are:

    **P04 allowlist** (every path P04 may touch):
    ```
    scripts/wiki/wiki-scan-sources.sh
    scripts/wiki/wiki-generate-nav.sh
    scripts/wiki/wiki-generate-stubs.sh
    scripts/wiki/wiki-decorate-codes.sh
    scripts/lifecycle/wiki-init.sh
    tests/m032-acceptance/p0X-scanner-extensions.sh
    tests/m032-acceptance/p0X-code-decorator.sh
    tests/m032-acceptance/sc11-doctor-no-warnings.sh
    tests/m032-acceptance/run-acceptance-battery.sh
    .orchestrator/milestones/M032/M032-VALIDATED
    [.orchestrator/milestones/M032/M032-SUMMARY.md](../../../../../milestones/M032/M032-SUMMARY.md)
    [.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md)
    .orchestrator/milestones/M032/execution-log.jsonl
    [.orchestrator/milestones/M032/phases/P04/P04-PLAN.md](../../../../../milestones/M032/phases/P04/P04-PLAN.md)
    .orchestrator/milestones/M032/phases/P04/P04-PLANNING-PAYLOAD.md
    [.orchestrator/milestones/M032/phases/P04/P04-SUMMARY.md](../../../../../milestones/M032/phases/P04/P04-SUMMARY.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T01-scanner-extensions-PLAN.md](../../../../../milestones/M032/phases/P04/tasks/T01-scanner-extensions-PLAN.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T01-scanner-extensions-PAYLOAD.md](../../../../../milestones/M032/phases/P04/tasks/T01-scanner-extensions-PAYLOAD.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T01-scanner-extensions-SUMMARY.md](../../../../../milestones/M032/phases/P04/tasks/T01-scanner-extensions-SUMMARY.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-PLAN.md](../../../../../milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-PLAN.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-PAYLOAD.md](../../../../../milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-PAYLOAD.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-SUMMARY.md](../../../../../milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-SUMMARY.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T03-sc11-doctor-and-self-application-PLAN.md](../../../../../milestones/M032/phases/P04/tasks/T03-sc11-doctor-and-self-application-PLAN.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T03-sc11-doctor-and-self-application-PAYLOAD.md](../../../../../milestones/M032/phases/P04/tasks/T03-sc11-doctor-and-self-application-PAYLOAD.md)
    .orchestrator/milestones/M032/phases/P04/tasks/T03-sc11-doctor-and-self-application-SUMMARY.md
    [.orchestrator/milestones/M032/phases/P04/tasks/T04-acceptance-battery-PLAN.md](../../../../../milestones/M032/phases/P04/tasks/T04-acceptance-battery-PLAN.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T04-acceptance-battery-PAYLOAD.md](../../../../../milestones/M032/phases/P04/tasks/T04-acceptance-battery-PAYLOAD.md)
    .orchestrator/milestones/M032/phases/P04/tasks/T04-acceptance-battery-SUMMARY.md
    [.orchestrator/milestones/M032/phases/P04/tasks/T05-milestone-close-and-phase-suite-PLAN.md](../../../../../milestones/M032/phases/P04/tasks/T05-milestone-close-and-phase-suite-PLAN.md)
    [.orchestrator/milestones/M032/phases/P04/tasks/T05-milestone-close-and-phase-suite-PAYLOAD.md](../../../../../milestones/M032/phases/P04/tasks/T05-milestone-close-and-phase-suite-PAYLOAD.md)
    .orchestrator/milestones/M032/phases/P04/tasks/T05-milestone-close-and-phase-suite-SUMMARY.md
    tools/verify/m032-p04-scanner-extensions.sh
    tools/verify/m032-p04-nav-extensions.sh
    tools/verify/m032-p04-decorator-shape.sh
    tools/verify/m032-p04-with-wiki-noop.sh
    tools/verify/m032-p04-acceptance-shape-sc8.sh
    tools/verify/m032-p04-acceptance-shape-sc9.sh
    tools/verify/m032-p04-acceptance-shape-sc11.sh
    tools/verify/m032-p04-acceptance-battery-shape.sh
    tools/verify/m032-p04-validate-milestone.sh
    tools/verify/m032-p04-milestone-close-ceremony.sh
    tools/verify/m032-p04-acceptance-evidence-ledger.sh
    tools/verify/m032-p04-phase-suite.sh
    tools/verify/m032-p04-scope-guard.sh
    tools/verify/fixtures/m032-p04-baseline-ref.txt
    ```

    **P04 denylist** (paths P00/P01/P02/P03 own — P04 MUST NOT touch):
    ```
    packaging/install/install-claude-code.sh
    packaging/install/install-codex.sh
    packaging/install/install-cursor.sh
    packaging/bundle/manifest.yml
    commands/init.md
    scripts/lifecycle/init-project.sh
    wiki/glossary.md
    wiki/mkdocs.yml
    scripts/knowledge/lookup-mems.sh
    scripts/wiki/wiki-deploy.sh
    wiki/overrides/partials/comments.html
    references/installation.md
    tests/m032-acceptance/throwaway-fixture-protocol.md
    tests/paired-m032-m033/seam-A.sh
    tests/paired-m032-m033/seam-B.sh
    tests/paired-m032-m033/seam-C.sh
    ```

    **Single sibling-phase exception** (allowlisted in P04):
    `scripts/lifecycle/wiki-init.sh` — P04/T02 amends this file with
    the `--with-wiki) shift ;;` no-op case arm per the in-flight
    repair convention.

    Baseline-ref capture at `tools/verify/fixtures/m032-p04-baseline-ref.txt`
    per the P01/P02/P03 first-run-captures-HEAD convention.

12. **Make all new scripts executable**:
    ```
    chmod +x tools/verify/m032-p04-validate-milestone.sh
    chmod +x tools/verify/m032-p04-milestone-close-ceremony.sh
    chmod +x tools/verify/m032-p04-acceptance-evidence-ledger.sh
    chmod +x tools/verify/m032-p04-phase-suite.sh
    chmod +x tools/verify/m032-p04-scope-guard.sh
    ```

13. **Capture the baseline-ref**. On first execution, the scope-guard's
    first-run-captures-baseline branch writes `tools/verify/fixtures/m032-p04-baseline-ref.txt`:
    ```
    bash tools/verify/m032-p04-scope-guard.sh
    ```

14. **Run the full P04 phase-suite once at task close**:
    ```
    bash tools/verify/m032-p04-phase-suite.sh
    ```
    Expected output: `SUMMARY: m032-p04-phase-suite.sh pass=11 fail=0`,
    exit 0.

15. **Run sibling-phase regression check** (final pass):
    - `bash tools/verify/m032-p01-phase-suite.sh` (or whichever P01
      phase-suite name shipped — see Notes on P01 known-pre-existing
      failures)
    - `bash tools/verify/m032-p02-phase-suite.sh`
    - `bash tools/verify/m032-p03-phase-suite.sh`

    All three should remain green at their close-time numbers (or
    document any pre-existing failures per the P03/T05 stash-compare
    pattern).

## Must-Haves

- [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md) exists with the 16-field milestone-summary frontmatter and references SC-1..SC-13 verdicts in the body (with signed-attestation block when SC-12 closed at skip=1)
- `.orchestrator/milestones/M032/M032-VALIDATED` marker file exists, conditioned on SC-12 skip=0 OR signed-attestation block per MIT-001 + SC-14
- `.orchestrator/milestones/M032/execution-log.jsonl` contains one milestone-grain `unit_close` record `{event_type: 'unit_close', unit: 'M032', timestamp: '<ISO8601Z>', verification_result: 'pass'}`
- [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md) exists per the M030/M031 evidence-ledger convention (BATTERY transcription + per-SC roll-up + validate-milestone transcription + back-link to runner)
- `tools/verify/m032-p04-validate-milestone.sh` asserts validate-milestone.sh M032 reports VALIDATE: PASS
- `tools/verify/m032-p04-milestone-close-ceremony.sh` asserts marker + summary + JSONL record presence with conditional attestation gate
- `tools/verify/m032-p04-acceptance-evidence-ledger.sh` asserts ledger shape + token surface
- `tools/verify/m032-p04-phase-suite.sh` chains all eleven P04 sub-gates per AD-19 single-script-file shape and emits `SUMMARY: m032-p04-phase-suite.sh pass=11 fail=0`
- `tools/verify/m032-p04-scope-guard.sh` enforces SC-13 scope discipline against P04 allowlist + P00/P01/P02/P03 denylist with first-run baseline-ref capture
- `tools/verify/fixtures/m032-p04-baseline-ref.txt` captured per the P01/P02/P03 baseline-ref convention
- T05 modifies ZERO T01–T04 deliverables — purely additive (only consumes them)

## Verification

```bash
bash tools/verify/m032-p04-validate-milestone.sh
```

```bash
bash tools/verify/m032-p04-milestone-close-ceremony.sh
```

```bash
bash tools/verify/m032-p04-acceptance-evidence-ledger.sh
```

```bash
bash tools/verify/m032-p04-phase-suite.sh
```

```bash
bash tools/verify/m032-p04-scope-guard.sh
```

```bash
bash tests/m032-acceptance/run-acceptance-battery.sh
```

## Notes

Expected output:
- `m032-p04-phase-suite.sh` final line: `SUMMARY: m032-p04-phase-suite.sh pass=11 fail=0`, exit 0.
- `m032-p04-scope-guard.sh` final lines (two-line per the P02/P03 precedent): `PASS: m032-p04 scope-guard pass=N fail=0 in_scope=M denylist_hits=0` followed by `SUMMARY: m032-p04-scope-guard.sh pass=N fail=0`, exit 0.
- `run-acceptance-battery.sh` final line: `BATTERY: pass=10 skip=1 fail=0` (SC-5 unauthenticated) OR `BATTERY: pass=11 skip=0 fail=0` (authenticated).

Verifier-contract-over-verifier-skeleton latitude (mirrored from P03/T05):
the phase-suite aggregator is intentionally thin — chains existing
verifiers, no new verification logic. The scope-guard's allowlist
intentionally includes the planning-state files (`P04-PLAN.md`,
`P04-PLANNING-PAYLOAD.md`, `P04-SUMMARY.md`, the per-task `T##-*-PAYLOAD.md`
/ `-SUMMARY.md`) and the milestone execution-log because P04 work
flows through those paths during dispatch. The denylist includes
ONLY the P00/P01/P02/P03-owned paths; future-phase paths are NOT
denylisted (none exist; if a P04 task accidentally created one, the
allowlist check would still flag it as out-of-scope).

P01 known-pre-existing failures (per P03-SUMMARY.md operator
follow-ups): `m032-p01-install-cc-byte-identical.sh`,
`m032-p01-installers-parity.sh`, `m032-p01-acceptance-shape-sc1.sh`
have been failing since pre-P03 close and are NOT P04-caused. T05's
sibling-phase regression check should distinguish "pre-existing red"
from "P04-introduced red" via stash-compare per the P03/T05 pattern.
If P04 introduces any new P01 regression, repair in-flight per the
P03 patterns-established convention.

The leaked GitHub fixture follow-up from P03/T04 SC-5 dry-run
(`bkellgren/1777950218-m032-fixture`) is a separate operator action
(documented recovery runbook in `tests/m032-acceptance/throwaway-fixture-protocol.md`)
and does NOT block T05 close. T05 may note this in M032-SUMMARY.md's
forward-pointing notes section as deferred-cleanup-pending.

Bash 3.2 gotchas: `grep -c` under `set -uo pipefail` requires `|| true`
fallback per the P02/T03 patterns-established gotcha (used in steps 8
and 9). `printf` with `%s` for the unit_close JSONL record handles
ISO-8601 timestamps with `:` characters cleanly (no quoting issues).

Conversus-gate / shape-classifier note: the P03/T05 scope-guard hit the
working-tree noise issue (146 out-of-scope FAILs from parallel M033
development). T05 here adopts the same `git diff --name-only baseline_ref
HEAD` committed-history-only pattern from the P03/T05 patterns-established
to avoid that failure mode. The first-run-captures-HEAD baseline-ref
is the load-bearing convention.

The SC-13 NNN derivation table in P04-PLAN.md (`## SC-13 NNN
Derivation` section) is the audit-trace for the M032-SUMMARY.md SC-13
verdict and the M032-ACCEPTANCE-EVIDENCE.md per-SC roll-up. T05 does
NOT modify the table — the planner authored it; T05 references it.

## Inputs

### From Previous Tasks

- All eleven P04 verifier scripts (T01: 3; T02: 3; T03: 1; T04: 1; T05:
  the remaining 5 it authors plus the phase-suite + scope-guard).
- `tests/m032-acceptance/run-acceptance-battery.sh` (T04) — invoked at
  step 1 to capture the BATTERY verdict for transcription.

Each upstream verifier's contract: exit 0 on pass with final line
`SUMMARY: <name> pass=N fail=0`; exit 77 on skip (battery only); other-
non-zero on fail. The phase-suite aggregator does NOT parse the SUMMARY
line — it only consumes the exit code (`bash <gate>` and check `$?`).

### From Disk (Pre-existing)

- `scripts/verify/validate-milestone.sh` — framework-owned validator
  invoked by `m032-p04-validate-milestone.sh`. Contract: emits
  `VALIDATE: <verdict> — N/M checks passed` final line; exit 0 on PASS.
- `tests/m030-acceptance/run-acceptance-battery.sh` — pattern reference
  for runner shape (M030 lineage).
- `tests/m031-acceptance/run-acceptance-battery.sh` — pattern reference
  (M031 lineage; closest precedent).
- [`.orchestrator/milestones/M030/M030-SUMMARY.md`](../../../../../milestones/M030/M030-SUMMARY.md) — pattern reference
  for milestone-summary structure (M030 byte-for-byte template).
- [`.orchestrator/milestones/M031/M031-SUMMARY.md`](../../../../../milestones/M031/M031-SUMMARY.md) — pattern reference
  (M031 lineage; closest precedent).
- [`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) — pattern
  reference for evidence-ledger structure.
- [`.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) — pattern
  reference (M031 lineage; closest precedent).
- `tools/verify/m032-p03-phase-suite.sh` — skeleton reference for the
  P04 phase-suite aggregator shape.
- `tools/verify/m032-p03-scope-guard.sh` — skeleton reference for the
  P04 scope-guard shape with allowlist + denylist + baseline-ref
  capture.
- `tools/verify/fixtures/m032-p03-baseline-ref.txt` — file-shape
  reference for the `m032-p04-baseline-ref.txt` capture.
- All P04 task PLAN.md / PAYLOAD.md / SUMMARY.md files (in-progress
  during T05 execution; the scope-guard's allowlist enumerates them
  even before they exist).

## Constraints

- Single-script-file shape for verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001).
- Verifier scripts under `tools/verify/m032-p04-*` (slug-bearing per
  AD-19).
- T05 modifies ZERO T01–T04 deliverables — purely additive.
- The `tools/verify/fixtures/m032-p04-baseline-ref.txt` path is INSIDE
  the P04 allowlist (the scope-guard captures its own baseline as part
  of its diff per the P03/T05 precedent).
- The phase-suite's gate-naming preserves the FR-/SC-/AD-/MIT-/CON-
  tag prefixes for grep-able diagnostics in failure cases.
- Milestone-close ceremony artifacts (M032-VALIDATED, M032-SUMMARY.md,
  unit_close JSONL, M032-ACCEPTANCE-EVIDENCE.md) MUST mirror M030/M031
  byte-for-byte where structurally possible per AD-2 milestone-close
  discipline.
- The signed-attestation block in M032-SUMMARY.md is conditional on
  SC-12 outcome — present iff `BATTERY: ... skip=1 ...` per MIT-001 +
  SC-14. The `m032-p04-milestone-close-ceremony.sh` verifier enforces
  this gate.
- T05 may NOT bypass the SC-12 + SC-14 gate. If `BATTERY: ... fail>0`
  occurs, T05 STOPS and surfaces the failure for in-flight repair
  per the P03 patterns-established convention. The milestone-close
  ceremony cannot proceed with `fail > 0`.

## Expected Output

After T05 completes:

- [`.orchestrator/milestones/M032/M032-SUMMARY.md`](../../../../../milestones/M032/M032-SUMMARY.md) (50+ lines, 16-field
  frontmatter, body with phase rollup + verification verdict + signed-
  attestation block when applicable).
- `.orchestrator/milestones/M032/M032-VALIDATED` marker file (empty;
  presence is the marker).
- `.orchestrator/milestones/M032/execution-log.jsonl` carries one
  milestone-grain `unit_close` record at the tail.
- [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md) (30+
  lines, BATTERY transcription + per-SC roll-up + back-link to
  runner).
- Five new verifier scripts under `tools/verify/m032-p04-*`
  (validate-milestone, milestone-close-ceremony, acceptance-evidence-
  ledger, phase-suite, scope-guard).
- `tools/verify/fixtures/m032-p04-baseline-ref.txt` captured.
- `bash tools/verify/m032-p04-phase-suite.sh` exits 0 with `pass=11
  fail=0`.
- `bash tools/verify/m032-p04-scope-guard.sh` exits 0 with `pass=N
  fail=0 denylist_hits=0`.
- `bash tests/m032-acceptance/run-acceptance-battery.sh` exits 0 with
  `BATTERY: pass=N skip=M fail=0`.
- `bash scripts/verify/validate-milestone.sh
  .orchestrator/milestones/M032/` exits 0 with `VALIDATE: PASS`.
- M032 milestone is closed.
