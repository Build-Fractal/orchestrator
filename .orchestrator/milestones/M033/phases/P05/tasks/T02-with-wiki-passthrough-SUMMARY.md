---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P05"
milestone: "M033"
provides:
  - "FR-15 --with-wiki paired-launch passthrough additive extension to scripts/lifecycle/start.sh: --with-wiki / --with-giscus / --deploy flag handlers + WITH_WIKI/WITH_GISCUS/DEPLOY default-zero variable initialization + wiki_init_passthrough function (stub-mode under M033_FR15_STUB=1 + real-mode dispatch to scripts/lifecycle/wiki-init.sh when present + genuine-failure not-skip when M032/P02 unclosed) + post-onboarding invocation gate threaded into main() after dispatch_stub + FR-22 wiki_init_invoked JSONL emit with downstream exit_code/stub_mode/with_giscus/deploy fields + sequential-atomicity model (US-1..US-7 sub-flow markers preserved on wiki-init failure; underlying exit code propagated verbatim per spec 035 CON-3) + USAGE string extended; tools/verify/m033-p05-with-wiki-passthrough-shape.sh (21-check shape verifier: 1 file-existence + 15 load-bearing-token-presence + 4 functional smoke (stub-mode rc=0 path + stub-mode rc=42 propagation + STUB token emit + failure diagnostic emit) + 1 SC-1 P01 cross-phase regression check)"
requires:
  - "P01/T01 (start.sh skeleton + flag parser); P02/T01 (jsonl-event-emitter.sh with wiki_init_invoked in 12-event closed enum); P02/T02 (start-state-markers.sh for US-1..US-7 marker preservation invariant); P04/T04 (migrate_routing function + --dry-run gate coexistence boundary)"
affects:
  - "P05/T03 (--with-github gate inserted AFTER T02's gate so natural code ordering enforces github-init not firing before wiki-init succeeds); P05/T04 (p08-with-wiki-passthrough.sh acceptance script consumes the FR-15 surface end-to-end); P05/T05 (phase-suite + cross-phase regression aggregator picks up m033-p05-with-wiki-passthrough-shape.sh)"
key_files:
  - "scripts/lifecycle/start.sh (modified, +95 net lines: 6-line variable init block + 1-line USAGE extension + 12-line flag-parser cases block + 76-line wiki_init_passthrough function + 13-line main()-block invocation gate); tools/verify/m033-p05-with-wiki-passthrough-shape.sh (created, 99 lines, executable)"
key_decisions:
  - "set-e-safe rc-capture pattern (cmd || rc=$? rather than cmd; rc=$?) applied to both wiki_init_passthrough's wiki-init.sh invocation AND main()'s wiki_init_passthrough call because set -e is active in start.sh and would exit on first non-zero return before $? could be captured; preferred over set +e/set -e wrapping because the existing P04 migrate_routing pattern uses the same || rc=$? form indirectly (rc=0 default + only-set-on-error path); wiki_init_passthrough function placed near branch_to_subflow/before main() rather than near migrate_routing because the natural reading order is sub-flow-helpers then post-onboarding-gate-helpers then main(); JSONL emit uses || true tolerance because emitter failures must NOT mask the actual wiki-init exit code (spec 035 CON-3 sequential-atomicity); stub-mode check uses ${M033_FR15_STUB:-0} expansion because set -u is active and an unset env var would otherwise crash before the check; failure diagnostic written to stdout (not stderr) because the load-bearing 'wiki-init failed' token discovery contract is operator-facing and integration-test asserted via stdout grep"
patterns_established:
  - "set-e-safe-rc-capture-pattern (rc=0 default + cmd || rc=$? + checked rc) for additive extensions into set-e scripts where caller needs to inspect non-zero return; ${VAR:-default} expansion for set-u-safe env-var probing in test-mode-toggle conditionals; stub-mode-vs-real-mode-vs-genuine-failure three-way branch (stub_env=true => synthetic emit + synthetic rc; real_target_present => bash invoke; neither => printf-error rc=1) as MIT-001 two-mode test contract template; JSONL emit with payload constructed via printf single-line %s/%d/%s template (no jq dependency, bash 3.2 safe); post-onboarding-gate ordering convention (T02 wiki gate before T03 github gate so natural code ordering enforces the FR-16 'github does not fire before wiki' invariant without explicit dependency check)"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P05/tasks/T02-with-wiki-passthrough-PLAN.md (task plan); .orchestrator/milestones/M033/phases/P05/P05-PLAN.md (phase plan with FR-15 truth #4 / must-haves enumeration); references/m033-fr21-dual-write-convention.md (FR-21 SSOT — note: FR-15 is glue not a content-authoring surface so no FR-21 fragment is emitted, mirroring P04/T04's D-T04-04 decision); scripts/util/jsonl-event-emitter.sh (12-event closed enum confirming wiki_init_invoked is in scope without enum extension)"
duration: "~25m"
verification_result: "pass"
completed_at: "2026-05-04T15:30:00Z"
---

T02 ships the FR-15 `--with-wiki [--with-giscus] [--deploy]` paired-launch passthrough as an additive extension to `scripts/lifecycle/start.sh`, plus its 21-check shape verifier with embedded SC-1 cross-phase regression assertion. P05's M032-paired-launch contract (CON-1) gets its driver-side surface; T03 will mirror the shape for `--with-github`; T04 will exercise the surface end-to-end via `p08-with-wiki-passthrough.sh`.

## What was built

- **`scripts/lifecycle/start.sh` (modified, +95 net lines)** — five surgical insertions, all additive, all behind the `--with-wiki` flag (zero behavior change for invocations without the flag):
  1. **Variable initialization** at the defaults block: `WITH_WIKI=0`, `WITH_GISCUS=0`, `DEPLOY=0` (default-off preserves P01/P02/P04 behavior).
  2. **USAGE string extension** with the three new flag forms.
  3. **Flag-parser cases** for `--with-wiki`, `--with-giscus`, `--deploy` — non-overlapping with existing `--project-dir`, `--yes`, `--branch`, `--stack`, `--dry-run`, `--no-resume` (P01/T01 + P02/T02).
  4. **`wiki_init_passthrough` function** — three-way branch:
     - **Stub mode** (`M033_FR15_STUB=1`): emits `STUB: wiki-init invoked --project-dir=<path> [--with-giscus] [--deploy]`, returns `M033_FR15_STUB_EXIT_CODE` (default 0). Does NOT invoke `wiki-init.sh`.
     - **Real mode + target present**: invokes `bash scripts/lifecycle/wiki-init.sh --project-dir <path> [flags]` (M032/P02 closed); captures rc via `|| rc=$?` (set-e-safe).
     - **Real mode + target absent**: emits `wiki-init.sh not found ...` to stderr and returns rc=1 — genuine failure, NOT skip (SC-14 `skip=0` invariant).
  5. **Post-onboarding invocation gate** in `main()` after `dispatch_stub`: fires only when `WITH_WIKI=1`; on non-zero return, propagates exit code verbatim per spec 035 CON-3 sequential-atomicity model.

- **FR-22 JSONL emit** — `wiki_init_invoked` payload threads `project_dir` / `exit_code` / `stub_mode` / `with_giscus` / `deploy`. Already in the 12-event closed enum (P02/T01 + P03/T04) — no enum extension required.

- **`tools/verify/m033-p05-with-wiki-passthrough-shape.sh` (created, 99 lines, executable)** — 21-check verifier:
  - 1 file-existence guard + early-exit summary.
  - 15 load-bearing-token-presence assertions covering flags, vars, env-var contracts, function name, both diagnostic strings, and the FR-22 emit token.
  - 2 stub-mode functional smokes (rc=0 propagation path emits STUB token + rc=42 propagation path emits failure diagnostic).
  - 1 SC-1 P01 cross-phase regression check (re-runs `tests/m033-acceptance/p01-start-branch-routing.sh` and asserts rc=0).

## Patterns established

- **set-e-safe rc-capture** (`rc=0; cmd || rc=$?`) applied at both call sites that need to inspect non-zero return without triggering `set -e` exit. Both inside `wiki_init_passthrough` (real-mode `wiki-init.sh` invocation) and at the `main()` call site.
- **`${VAR:-default}` set-u-safe env-var probing** for the test-mode toggle (`M033_FR15_STUB`, `M033_FR15_STUB_EXIT_CODE`).
- **Three-way stub/real/genuine-failure branch** as MIT-001 two-mode contract template — reusable for T03's `--with-github` gate.
- **JSONL payload construction via single-line `printf '%s' / '%d'` template** — no jq dependency, bash 3.2 safe, no process substitution.
- **Post-onboarding gate ordering as the github-not-before-wiki enforcement mechanism** — T03's `--with-github` gate will be inserted AFTER T02's gate in `main()`; the natural code ordering plus `exit "$WIKI_RC"` on wiki-init failure makes the FR-16 invariant load-bearing without an explicit dependency check.

## Decisions captured during execution

- **D-T02-01**: `set -e` is active in `start.sh`; the natural `cmd; rc=$?` pattern would exit before `$?` could be captured. Switched to the `rc=0; cmd || rc=$?` form at both inner (wiki-init.sh invocation) and outer (`wiki_init_passthrough` call) sites.
- **D-T02-02**: Function placement — `wiki_init_passthrough` lives near `branch_to_subflow` (just before `main()`) rather than near `migrate_routing`, because the reading order is sub-flow-helpers → post-onboarding-gate-helpers → `main()`.
- **D-T02-03**: Failure diagnostic written to **stdout** (not stderr) because the `wiki-init failed; re-run "orchestrator:wiki-init" independently to complete; all other onboarding outputs preserved` token discovery is operator-facing and the verifier asserts via `grep -F` on `stdout`. The `wiki-init.sh not found` diagnostic remains on stderr because it's an internal-environment error rather than an operator-actionable wiki-init outcome.
- **D-T02-04**: JSONL emit uses `|| true` tolerance — emitter failures must NOT mask the actual wiki-init exit code (CON-3 sequential-atomicity).
- **D-T02-05**: No FR-21 dual-write fragment for FR-15 — FR-15 is integration-glue, not a content-authoring surface. Mirrors P04/T04's D-T04-04 decision (FR-11 migrate-routing also skipped FR-21 for the same reason).
- **D-T02-06**: `wiki_init_invoked` already in the 12-event JSONL closed enum (P02/T01 shipped + P03/T04 extended to add `imported_context_loaded`). No enum extension required, so the P02 emitter file is NOT modified by this task — only `start.sh` is touched, preserving the additive-only AD-15 invariant.

## Verification result

- `tools/verify/m033-p05-with-wiki-passthrough-shape.sh`: `pass=21 fail=0`
- `tools/verify/m033-p01-phase-suite.sh` (cross-phase regression): `pass=14 fail=0` ✅
- `tools/verify/m033-p02-phase-suite.sh` (cross-phase regression): `pass=10 fail=0` ✅
- `tools/verify/m033-p04-phase-suite.sh` (cross-phase regression): `pass=9 fail=0` ✅
- `tests/m033-acceptance/p01-start-branch-routing.sh` (SC-1 acceptance, embedded in T02 verifier): rc=0 ✅

All four pre-existing P01/P02/P04 surfaces preserve their green state; T02's modification is provably additive per AD-15 cross-phase regression discipline.

## What downstream tasks consume

- **T03** (`--with-github` paired-launch passthrough) reuses the three-way stub/real/genuine-failure branch template + the set-e-safe rc-capture pattern + the post-onboarding gate insertion convention; T03's gate is inserted AFTER T02's gate so natural code ordering enforces FR-16 (github-init does not fire before wiki-init succeeds).
- **T04** (`p08-with-wiki-passthrough.sh` acceptance script) exercises `wiki_init_passthrough` end-to-end under both `M033_FR15_STUB=0` (real-mode against an M032/P02 surrogate) and `M033_FR15_STUB=1` (synthetic exit-code propagation) modes.
- **T05** (phase-suite + cross-phase regression aggregator) appends `m033-p05-with-wiki-passthrough-shape.sh` to the P05 phase-suite verifier list.
