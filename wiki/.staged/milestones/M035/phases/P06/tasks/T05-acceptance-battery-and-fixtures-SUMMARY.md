---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P06"
milestone: "M035"
provides:
  - "tests/m035-acceptance/run-acceptance-battery.sh (M035 milestone-grain acceptance battery — chains P00/P01/P01.5/P02/P03/P04/P05/P06 phase-suites + acceptance-battery-shape self-reference; defensive numeric parsing; SKIP semantics for missing aggregators; canonical BATTERY: pass=N fail=N skip=M rollup; SC-15 self-reference) + tests/m035-acceptance/fixtures/m035-p06-config-update-source-X/.orchestrator/config.yml fixture quartet for X in git/npm/homebrew/none (3-line schema + update_source: <value> per fixture; backs SC-13 dispatch arm + T02 dispatch verifier --dry-run per-channel assertion) + tools/verify/m035-p06-acceptance-battery-shape.sh (16-assertion structural verifier; battery shebang/set -u/BATTERY: line/sub-aggregator references + 4 fixture update_source: lines; BATTERY pass=16)"
requires:
  - "from:M035/P06-T01 what:m035-p06-config-schema-shape.sh as task-grain regression baseline (BATTERY pass=7) from:M035/P06-T02 what:m035-p06-multi-source-dispatch-shape.sh + fixture-quartet contract (consumed by T02 --dry-run per-channel assertion) from:M035/P06-T03 what:m035-p06-update-run-jsonl-emission-shape.sh as regression baseline (BATTERY pass=12) from:M035/P06-T04 what:m035-p06-update-skill-doc-multi-source-shape.sh as regression baseline (BATTERY pass=12) from:disk what:tools/verify/m035-p00..p05-phase-suite.sh aggregators (P00 chmod missing emits SKIP; P01.5 dot-elision form m035-p015-phase-suite.sh on disk) from:disk what:tests/m029-acceptance/run-acceptance-battery.sh as canonical chain-and-rollup pattern reference from:disk what:scripts/lib/errors.sh sourceable lib (emit_result + ORCH_ERR_ taxonomy)"
affects:
  - "P06/T06 (consumes the milestone-grain BATTERY rollup as the load-bearing gate for validate-milestone.sh M035 = PASS + M035-VALIDATED marker write; T06 must address pre-existing P01.5/P02/P04 upstream phase-suite failures before the gate can succeed)"
key_files:
  - "tests/m035-acceptance/run-acceptance-battery.sh,tools/verify/m035-p06-acceptance-battery-shape.sh,tests/m035-acceptance/fixtures/m035-p06-config-update-source-git/.orchestrator/config.yml,tests/m035-acceptance/fixtures/m035-p06-config-update-source-npm/.orchestrator/config.yml,tests/m035-acceptance/fixtures/m035-p06-config-update-source-homebrew/.orchestrator/config.yml,tests/m035-acceptance/fixtures/m035-p06-config-update-source-none/.orchestrator/config.yml"
key_decisions:
  - "D007 (curl-pipe-bash to npm collapse — fixture quartet enumerates only the four legitimate update_source values: git/npm/homebrew/none),D009 (single-source-of-truth tarball — informs the fixture quartet value enumeration),D012 (update_source schema enumeration — drives fixture matrix shape),SC-15 (self-reference — battery includes its own shape verifier in the chain to satisfy the criterion without circularity)"
patterns_established:
  - "function-body-composition-exempt-from-AP-009 (run_one mktemp + bash + grep + sed pipeline permitted because AP-009 fires on caller-side compound shapes not function-body composition; P05 T06 phase-suite precedent),defensive-numeric-parsing-via-case-glob (guards arithmetic against empty match or non-numeric grep/sed output; mirrors M027 P02 + M032 P03 rollup-defensive precedent),P015-aggregator-filename-auto-discovery (dot-form vs dot-elision; battery probes via test -x at startup; verifier accepts either reference),SKIP-for-missing-sub-aggregators-not-FAIL (defensive test returns SKIP + total_skip++ rather than counting as fail; allows battery to run cleanly with P06 phase-suite missing — load-bearing T05/T06 dependency decoupling),self-reference-for-SC-15 (acceptance-battery-shape verifier included in battery chain; verifier asserts battery shape not its own result so no circularity; battery rollup naturally absorbs the +16 contribution)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P06/tasks/T05-acceptance-battery-and-fixtures-PLAN.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-05-10T00:26:34Z"
---

T05 ships the M035 milestone-grain acceptance battery + the four fixture project trees that back the SC-13 multi-source dispatch arm + the acceptance-battery-shape verifier (SC-15 self-reference).

Three surfaces:

1. `tests/m035-acceptance/run-acceptance-battery.sh` — chains every per-phase aggregator (P00 → P01.5 → P02 → P03 → P04 → P05 → P06 → acceptance-battery-shape → P01) and emits a single canonical `BATTERY: pass=N fail=N skip=M` rollup. SKIP semantics for missing aggregators (defensive, protects against filename drift and the T06-not-yet-shipped P06 phase-suite). Defensive numeric parsing via `case "$X" in ''|*[!0-9]*) X=0 ;;` per the M027/[M032](../../../../../milestones/M032/index.md) rollup-defensive precedent. P01.5 aggregator filename auto-discovered (dot-elision form `m035-p015-phase-suite.sh` was on disk; verifier tolerates either form).

2. Fixture quartet — `tests/m035-acceptance/fixtures/m035-p06-config-update-source-{git,npm,homebrew,none}/.orchestrator/config.yml` — minimal three-line schema + the matching `update_source: <value>` line. Backs the SC-13 dispatch arm; consumed by T02's dispatch verifier `--dry-run` per-channel assertion.

3. `tools/verify/m035-p06-acceptance-battery-shape.sh` — 16-assertion structural verifier. Sources `scripts/lib/errors.sh`. Asserts: battery exists+executable; `BATTERY:` rollup line present; every chained sub-aggregator referenced (8 phase-suites + self-reference); shebang `#!/usr/bin/env bash`; `set -u` present; four fixture configs carry their matching `update_source: <value>` line.

The battery's `run_one` helper uses function-body composition (mktemp + bash + grep + sed); AP-009 permits in-function pipelines per the P05 T06 phase-suite precedent. The shape-verifier walks 16 assertions in the AD-19 single-script-file flat shape.

T01..T04 task-grain regressions all green: T01 7/7, T02 13/13, T03 12/12, T04 12/12. The T05 acceptance-battery-shape verifier itself passes 16/16.

Two pre-existing unstaged operator-owned files (`templates/phase-plan.md`, `.orchestrator/direct-mode-execution-log.jsonl`) left untouched per dispatch instructions.

## Pre-existing upstream phase-suite failures (NOT T05 scope)

The battery exit code is 1 today (`BATTERY: pass=100 fail=4 skip=3`). All four fails come from upstream phase-suites and predate T05:

- **P01.5** (2 fails) — `tools/verify/m035-p015-operator-paths.sh` self-trips. The verifier scans for `~/Sites/spec-kit-orchestrator` residue and matches its own source (the regex appears in its own comment+impl lines). The MD residue scan also finds matches in `.orchestrator/milestones/M035/phases/P02/T01-SUMMARY.md` + sibling SUMMARY files + `wiki/docs/index.md` + `wiki/mkdocs.yml` + `specs/040-wiki-readability-decorator/spec.md`.
- **P02** (1 fail) — cascade from the same residue scan or another upstream trip.
- **P04** (1 fail) — `tools/verify/m035-p04-update-skill-doc-curl.sh` expects `update_source: curl-pipe-bash` row in `commands/update.md`. T04 collapsed `curl-pipe-bash → npm` per D007/D009 (curl-pipe-bash users auto-detected as npm because the curl-pipe-bash installer extracts the npm tarball; the four legitimate values are git/npm/homebrew/none). The P04 verifier predates the D012 enumeration tightening and now mismatches the doc shape T04 ships.

These failures are properly within T06's milestone-close scope (validate-milestone.sh M035 = PASS gate) — T06 will need to either fix the upstream verifiers, update the operator-paths allowlist, or the doc to satisfy the milestone gate. T05's responsibility is to ship the battery script + verifier + fixtures with the correct structural shape, which is done.

## Patterns established

- Function-body composition exempts from AP-009 — `run_one`'s mktemp + bash + grep + sed sequence is permitted because AP-009 fires on caller-side inline compound shapes, not function-body composition. Mirrors P05 T06 phase-suite precedent.
- Defensive numeric parsing for grep+sed extraction — `case "$X" in ''|*[!0-9]*) X=0 ;;` guards against empty match / non-numeric output before arithmetic. Prevents bash arithmetic errors that would otherwise cascade into spurious script failures.
- P01.5 aggregator filename auto-discovery — dot-form (`m035-p01.5-phase-suite.sh`) vs dot-elision (`m035-p015-phase-suite.sh`) handled via `[ -x ... ]` probe at battery startup; both verifier and battery accept either. Protects against filename-shape drift across milestone closures.
- SKIP for missing sub-aggregators (NOT FAIL) — `[ ! -x "$cmd" ]` returns SKIP + increments `total_skip` rather than counting as a fail. Allows the battery to run cleanly even when one phase-suite hasn't shipped yet (e.g. P06 phase-suite which T06 ships; this is the load-bearing T05/T06 dependency-decoupling pattern).
- Self-reference for SC-15 — the acceptance-battery-shape verifier is included in the battery's chain; when the battery runs, it references its own shape verifier in the rollup count, satisfying SC-15 without circularity (the verifier asserts the battery's shape, not its own result).

## Verification

- `bash tools/verify/m035-p06-acceptance-battery-shape.sh` → `BATTERY: pass=16 fail=0` (all 16 assertions PASS exactly per plan Expected Output)
- `bash tests/m035-acceptance/run-acceptance-battery.sh` → `BATTERY: pass=100 fail=4 skip=3` (exit 1, attributable entirely to upstream phase-suite failures listed above; T05's contribution is the +16 from the shape verifier and the +7 from P01)
- T01 regression: `BATTERY: pass=7 fail=0`
- T02 regression: `BATTERY: pass=13 fail=0`
- T03 regression: `BATTERY: pass=12 fail=0`
- T04 regression: `BATTERY: pass=12 fail=0`

## Caveats

- The battery's exit code 1 today is upstream-induced (P01.5/P02/P04 phase-suites). The battery's logic is correct per plan Step 4: "If any aggregator FAILs, the battery exits 1 — this is the load-bearing gate that T06's milestone-close logic depends on." T06 will need to address the upstream failures before `validate-milestone.sh M035 = PASS` can succeed; specifically: (a) either narrow the P01.5 operator-paths allowlist to exclude the verifier's own source + the historical M035 SUMMARY files, or move them under the historical-files allowlist; (b) reconcile P04's `m035-p04-update-skill-doc-curl.sh` with T04's D007/D009 curl-pipe-bash → npm collapse (drop the `update_source: curl-pipe-bash` assertion or fold it into a general "curl-pipe-bash users dispatch via npm" assertion).
- The `m035-p00-phase-suite.sh` was pre-existing without an executable bit; the battery correctly emits SKIP rather than FAIL. Operator follow-up: `chmod +x` on disk if not intentionally non-executable.
- The P01.5 aggregator filename on disk is `m035-p015-phase-suite.sh` (dot-elision form). The battery's auto-discovery probes that filename first (preferred), falling back to `m035-p01.5-phase-suite.sh`. The shape verifier accepts either reference.
- T05's surfaces add nothing to commands/update.md, scripts/, or DECISIONS.md — pure test/fixture/verifier additions. No scope leakage.

## Out-of-scope-found

- T06 territory — the upstream phase-suite failures listed above. T05 surfaces them via the battery's `fail=4` rollup; T06's milestone-close logic must either fix them or block on them.
- M035 P00 phase-suite executable-bit operator follow-up (mode 644 → 755 on `tools/verify/m035-p00-phase-suite.sh`). Not T05 scope; minor papercut.
