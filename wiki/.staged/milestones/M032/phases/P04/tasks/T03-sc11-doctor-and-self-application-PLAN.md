---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M032"
name: "SC-11 doctor-no-warnings + wiki-serve self-application + audit-trail acceptance script"
depends_on: []
---

## Prerequisites

- P03 closed (`scripts/lifecycle/wiki-init.sh --with-giscus --deploy`
  with `M032_GISCUS_IDS_FROM_GH_STUB=1` + `M032_DEPLOY_GH_API_STUB=1`
  envelopes ships the audit-trail emission to
  `<PROJECT_DIR>/.orchestrator/execution-log.jsonl`). Verified by:
  - `[ -f scripts/lifecycle/wiki-init.sh ]`
  - `grep -q M032_DEPLOY_GH_API_STUB scripts/lifecycle/wiki-init.sh`
  - `grep -q wiki-deploy-mutation scripts/lifecycle/wiki-init.sh`
- `scripts/diagnostics/run-doctor.sh` exists ([M021](../../../../../milestones/M021/index.md) + [M027](../../../../../milestones/M027/index.md) surface).
  Verified by `[ -f scripts/diagnostics/run-doctor.sh ]`.
- `scripts/wiki/wiki-serve.sh` exists with `--probe` mode (P02 helper
  surface). Verified by:
  - `[ -f scripts/wiki/wiki-serve.sh ]`
  - `grep -q -- '--probe' scripts/wiki/wiki-serve.sh` (or equivalent
    port-free health check; see Notes for fallback discipline).
- `tests/fixtures/m032-fresh-project-fixture/` exists (P01 shared
  fixture). Verified by `[ -d tests/fixtures/m032-fresh-project-fixture ]`.

## Description

T03 lands the SC-11 acceptance script that verifies three orthogonal
invariants per the spec's MIT-002 + MIT-008 amendments:

1. **Constitution VIII (No Dead Infrastructure)** — running
   `bash scripts/diagnostics/run-doctor.sh` against an `init --with-wiki
   --with-giscus --deploy`-bootstrapped fixture project exits 0 AND
   stdout contains zero `dead-infrastructure` or `unreferenced-asset`
   warning lines.

2. **MIT-002 FR-6 self-application loop closure** — running
   `bash scripts/wiki/wiki-serve.sh --probe` (or equivalent port-free
   `mkdocs build --strict` health check) against the orchestrator
   repo's own `wiki/` source tree exits 0. This closes the FR-6
   self-application loop — the orchestrator dogfoods its own wiki
   throughout M032 + [M033](../../../../../milestones/M033/index.md) paired development.

3. **MIT-008 audit-trail presence** — after the stubbed `--deploy` step
   completes, the fixture's
   `<fixture>/.orchestrator/execution-log.jsonl` contains ≥ 1 NDJSON
   record matching `"event_type":"wiki-deploy-mutation"` AND
   `"result":"success"`. Constitution VI (State On Disk Is Truth)
   applied to remote-state mutations.

The fixture used for invariants (1) and (3) is the P01 shared
`tests/fixtures/m032-fresh-project-fixture/` pre-bootstrapped via the
`M032_GISCUS_IDS_FROM_GH_STUB=1` + `M032_DEPLOY_GH_API_STUB=1`
envelopes. No live network dependence.

## Steps

1. **Author `tests/m032-acceptance/sc11-doctor-no-warnings.sh`**.
   Single-script-file shape per AD-19; bash 3.2 compatible per MEM001.
   The skeleton:

   ```bash
   #!/usr/bin/env bash
   # SC-11 — verifies Constitution VIII (no dead-infrastructure) +
   # MIT-002 (FR-6 self-application loop) + MIT-008 (audit-trail
   # presence) per the M032 spec amendments.
   set -uo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   FIXTURE_SRC="$PROJECT_ROOT/tests/fixtures/m032-fresh-project-fixture"
   FIXTURE_DST="/tmp/m032-p04-sc11-fixture-$$"
   STUB_DIR="/tmp/m032-p04-sc11-stub-$$"

   cleanup() {
     set +e
     rm -rf "$FIXTURE_DST" 2>/dev/null
     rm -rf "$STUB_DIR" 2>/dev/null
     true
   }
   trap cleanup EXIT INT TERM

   pass=0; fail=0
   say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
   say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

   # ---- bootstrap fixture under stubs ----
   cp -R "$FIXTURE_SRC" "$FIXTURE_DST"
   mkdir -p "$STUB_DIR"
   # ... write deterministic stub responses for the four gh api calls ...

   # Run wiki-init --with-wiki --with-giscus --deploy under stubs
   M032_GISCUS_IDS_FROM_GH_STUB=1 \
     M032_DEPLOY_GH_API_STUB=1 \
     M032_DEPLOY_GH_API_STUB_DIR="$STUB_DIR" \
     M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 \
     bash "$PROJECT_ROOT/scripts/lifecycle/wiki-init.sh" \
       --with-wiki --with-giscus --deploy \
       --project-dir "$FIXTURE_DST" \
       --repo "fixture-owner/fixture-repo" \
       --category "Wiki Comments" \
       >"$STUB_DIR/wiki-init.out" 2>"$STUB_DIR/wiki-init.err" || true

   # ---- ASSERTION GROUP 1: Constitution VIII (run-doctor.sh no warnings) ----
   bash "$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh" \
     --project-dir "$FIXTURE_DST" \
     >"$STUB_DIR/doctor.out" 2>&1
   _doctor_rc=$?
   _warn_count=$(grep -cE '(dead-infrastructure|unreferenced-asset)' "$STUB_DIR/doctor.out" || true)
   if [ "$_doctor_rc" -eq 0 ] && [ "$_warn_count" -eq 0 ]; then
     say_pass 'Constitution VIII: run-doctor.sh exit 0 with zero dead-infrastructure/unreferenced-asset warnings'
   else
     say_fail "Constitution VIII: doctor rc=$_doctor_rc, warn_count=$_warn_count"
   fi

   # ---- ASSERTION GROUP 2: MIT-002 (wiki-serve --probe self-application) ----
   bash "$PROJECT_ROOT/scripts/wiki/wiki-serve.sh" --probe \
     --root "$PROJECT_ROOT" \
     >"$STUB_DIR/serve.out" 2>&1
   _serve_rc=$?
   if [ "$_serve_rc" -eq 0 ]; then
     say_pass 'MIT-002: wiki-serve.sh --probe exit 0 against orchestrator wiki/'
   else
     say_fail "MIT-002: wiki-serve --probe rc=$_serve_rc"
   fi

   # ---- ASSERTION GROUP 3: MIT-008 (audit-trail record presence) ----
   _logfile="$FIXTURE_DST/.orchestrator/execution-log.jsonl"
   if [ -f "$_logfile" ]; then
     _audit_count=$(grep -cF '"event_type":"wiki-deploy-mutation"' "$_logfile" || true)
     _success_count=$(grep -cF '"result":"success"' "$_logfile" || true)
     if [ "$_audit_count" -ge 1 ] && [ "$_success_count" -ge 1 ]; then
       say_pass "MIT-008: execution-log.jsonl carries $_audit_count wiki-deploy-mutation record(s) with result=success"
     else
       say_fail "MIT-008: audit_count=$_audit_count, success_count=$_success_count"
     fi
   else
     say_fail "MIT-008: execution-log.jsonl missing at $_logfile"
   fi

   printf 'RESULT: SC-11 pass=%d fail=%d\n' "$pass" "$fail"
   [ "$fail" -eq 0 ]
   ```

   Stub directory contents: write four small JSON stub-response files
   matching the M032_DEPLOY_GH_API_STUB pattern established in P03/T02
   (consult `scripts/lifecycle/wiki-init.sh` for the exact filenames the
   stub envelope reads — typically `discussions-patch.json`,
   `pages-get.json`, `pages-put.json`, etc.; reuse the P03/T02 stub
   shape verbatim).

2. **Author `tools/verify/m032-p04-acceptance-shape-sc11.sh`** — asserts
   the SC-11 script exists, is executable, and contains the load-
   bearing token surface:
   - The string `SC-11`
   - The string `MIT-002` (FR-6 self-application)
   - The string `MIT-008` (audit-trail)
   - The string `run-doctor.sh`
   - The string `wiki-serve.sh`
   - The string `--probe`
   - The string `wiki-deploy-mutation`
   - The string `dead-infrastructure`
   - The string `unreferenced-asset`
   - The string `M032_GISCUS_IDS_FROM_GH_STUB`
   - The string `M032_DEPLOY_GH_API_STUB`
   - The string `trap` (cleanup pattern)
   - At least one `say_pass` and one `say_fail` (or `RESULT:` line)

3. **Make new scripts executable**:
   ```
   chmod +x tests/m032-acceptance/sc11-doctor-no-warnings.sh
   chmod +x tools/verify/m032-p04-acceptance-shape-sc11.sh
   ```

4. **Run T03 verifier locally** to confirm green:
   - `bash tools/verify/m032-p04-acceptance-shape-sc11.sh`
   - `bash tests/m032-acceptance/sc11-doctor-no-warnings.sh`

5. **Run sibling-phase regression check**:
   - `bash tools/verify/m032-p02-phase-suite.sh`
   - `bash tools/verify/m032-p03-phase-suite.sh`

   Both should remain green at their close-time numbers.

## Must-Haves

- `tests/m032-acceptance/sc11-doctor-no-warnings.sh` exists, is executable, and exits 0 against a stub-bootstrapped fixture
- The script asserts three independent invariants: Constitution VIII (run-doctor.sh exit 0 + zero `dead-infrastructure|unreferenced-asset` warnings); MIT-002 (`wiki-serve.sh --probe` exit 0 against orchestrator's own wiki/); MIT-008 (≥ 1 `wiki-deploy-mutation` record with `result:success` in `execution-log.jsonl`)
- The script uses `M032_GISCUS_IDS_FROM_GH_STUB=1` + `M032_DEPLOY_GH_API_STUB=1` envelopes for hermetic execution (no live network)
- The script implements trap-EXIT cleanup per the P03 / AD-7 throwaway-fixture pattern
- `tools/verify/m032-p04-acceptance-shape-sc11.sh` ships green
- P02 + P03 phase-suites remain green post-T03

## Verification

```bash
bash tools/verify/m032-p04-acceptance-shape-sc11.sh
```

```bash
bash tests/m032-acceptance/sc11-doctor-no-warnings.sh
```

```bash
bash tools/verify/m032-p02-phase-suite.sh
```

```bash
bash tools/verify/m032-p03-phase-suite.sh
```

## Notes

Expected output: each verifier's final line is `SUMMARY:` or `RESULT:`
with `pass=N fail=0` and exit 0. P02 remains 12/12; P03 remains 10/10.

Verifier-contract-over-verifier-skeleton latitude: SC-11's three
assertion groups are the load-bearing contract. If the stub envelope
naming or directory layout differs from this plan's sketch (e.g.
P03/T02 may have used a different stub-filename convention), the
implementing agent SHOULD reuse the actual P03 stub shape verbatim
rather than the literal sketch above. Read
`scripts/lifecycle/wiki-init.sh` lines around the
`M032_DEPLOY_GH_API_STUB` block to confirm the on-disk stub-loading
shape. Similarly, if `wiki-serve.sh --probe` mode does not exist on
disk or behaves differently than expected, fall back to the P02 helper
`tools/verify/lib/m032-p02-wiki-serve-probe.sh` invocation pattern, OR
ship the contract intent (port-free `mkdocs build --strict` health
check against `<PROJECT_ROOT>/wiki/`) using whatever surface is on
disk. This is the canonical M032 P02/P03 in-flight repair convention.

The `run-doctor.sh --project-dir` flag is the standard M021 surface
for running doctor against a non-default project. If `run-doctor.sh`
does not honor this flag verbatim, the fixture invocation MAY use
`cd <FIXTURE_DST>; bash $PROJECT_ROOT/scripts/diagnostics/run-doctor.sh`
as a fallback (the implementing agent should verify on-disk shape and
adjust). The contract is: doctor runs against the bootstrapped fixture
project and reports zero `dead-infrastructure|unreferenced-asset`
warnings.

The `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1` envelope is required because
the fixture's git remote does not match `repo_url:` in the templated
`mkdocs.yml`. The bypass envelope is the test-only surface for unit-
level coverage where the fixture has no real git remote (per the P03
patterns-established convention).

The `grep -c` under `set -uo pipefail` requires `|| true` fallback per
the P02/T03 patterns-established gotcha (silent abort when count==0
otherwise). Three `grep -c` invocations in the script — all three need
the fallback.

The audit-trail check uses `grep -cF` (literal-string, not regex) to
avoid false matches against any operator-edited entries. The `event_type`
JSON field shape is stable per the MIT-008 contract.

## Inputs

### From Previous Tasks

(None — T03 has zero upstream task dependencies inside P04.)

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` (P02/P03 surface) — provides the
  `--with-wiki --with-giscus --deploy` flag chain under the
  `M032_GISCUS_IDS_FROM_GH_STUB=1` + `M032_DEPLOY_GH_API_STUB=1`
  envelopes. Key API surface: invocation writes
  `<PROJECT_DIR>/.orchestrator/execution-log.jsonl` with
  `wiki-deploy-mutation` NDJSON records.
- `scripts/diagnostics/run-doctor.sh` (M021 + M027 surface) — exits 0
  on healthy project; emits `dead-infrastructure` / `unreferenced-asset`
  diagnostic lines per Constitution VIII when surfaces are unreachable.
- `scripts/wiki/wiki-serve.sh` (M012/P02 + M032/P02 helper) — supports
  `--probe` mode for port-free health check (per P02/T01 patterns-
  established). If `--probe` is absent on disk, fall back to the
  `tools/verify/lib/m032-p02-wiki-serve-probe.sh` helper or to
  `mkdocs build --strict` direct invocation.
- `tests/fixtures/m032-fresh-project-fixture/` (P01/T03) — shared
  fixture providing `wiki/`, `commands/`, `scripts/`, `references/`,
  `templates/` runtime dirs + `.orchestrator/` skeleton. Used as the
  bootstrap source for SC-11's stub-mode wiki-init invocation.

## Constraints

- Single-script-file shape per AD-19.
- bash 3.2 compatibility (per MEM001).
- Verifier scripts under `tools/verify/m032-p04-*`.
- Acceptance script under `tests/m032-acceptance/sc11-doctor-no-warnings.sh`
  (literal name per the spec; `sc11-` prefix not `p0X-` because this
  script does not bind to a phase-prefix scheme — it is the SC-11
  named verifier that stitches across multiple invariants).
- T03 modifies ZERO files outside the new acceptance script + the new
  verifier (no production-side modifications). The Constitution VIII /
  MIT-002 / MIT-008 surfaces are all pre-existing P02/P03 deliverables.
- T03 does NOT touch any sibling-task deliverable (T01 scanner; T02
  decorator + `--with-wiki`; T04 battery; T05 close ceremony).

## Expected Output

After T03 completes:

- `tests/m032-acceptance/sc11-doctor-no-warnings.sh` exists, is
  executable, and exits 0 (all three assertion groups green).
- `tools/verify/m032-p04-acceptance-shape-sc11.sh` exists, is
  executable, and exits 0.
- P02 + P03 phase-suites remain green at their close numbers.
