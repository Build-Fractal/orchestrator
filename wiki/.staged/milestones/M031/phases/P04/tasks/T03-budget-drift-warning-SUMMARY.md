---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P04"
milestone: "M031"
provides:
  - "scripts/diagnostics/efficiency-footer.sh AD-19 QUICK_BUDGET_DRIFT informational warning surface: three new bash 3.2 helpers (m031_quick_budget 4-layer config-knob resolver, m031_quick_window_median rolling 7-record median over knowledge_section_tokens filtered by profile=quick, m031_quick_budget_drift_check trigger emitter); CLI call site after efficiency_footer_render with ORCH_EFFICIENCY_FOOTER_INPUT env override at the top of the input-resolution chain and .orchestrator/observability/payload_breakdown.jsonl as the production fallback; QUIET=0 gate preserves the existing CON-3/SC-3 byte-identity contract for --quiet invocation; helper trio always returns 0 (informational; never gates exit)"
  - "tests/m031-acceptance/test-budget-drift-warning.sh (AD-19 SC test, 78 lines, executable, bash 3.2 / MEM001 compatible): hermetic mktemp scratch root + trap rm -rf EXIT cleanup pattern; constructs trip fixture (7 quick records each knowledge_section_tokens=1000 -> median 1000 > threshold 880 -> trigger fires) and safe fixture (7 quick records each knowledge_section_tokens=700 -> median 700 < threshold 880 -> trigger suppressed); pipes each fixture through efficiency-footer.sh via ORCH_EFFICIENCY_FOOTER_INPUT seam with --project flag (skips active-milestone resolution for hermetic runs); emits RESULT: AD-19 pass on 2/2 PASS"
  - "tools/verify/m031-p04-budget-drift-shape.sh (AD-19 single-script Truth Check, bash 3.2 / MEM001 compatible, 65 lines): asserts efficiency-footer.sh post-amend carries the five required literal substrings (QUICK_BUDGET_DRIFT, quick_knowledge_token_budget, knowledge_section_tokens, ORCH_EFFICIENCY_FOOTER_INPUT, m031_quick_budget_drift_check); emits SUMMARY: m031-p04-budget-drift-shape.sh pass=N fail=M; exits 0 iff fail=0 (current pass=6 fail=0)"
  - "tools/verify/m031-p04-test-budget-drift-shape.sh (AD-19 single-script Truth Check, bash 3.2 / MEM001 compatible, 71 lines): asserts the SC test exists, is executable, and references AD-19 + QUICK_BUDGET_DRIFT + efficiency-footer.sh + ORCH_EFFICIENCY_FOOTER_INPUT literal substrings; emits SUMMARY: m031-p04-test-budget-drift-shape.sh pass=N fail=M; exits 0 iff fail=0 (current pass=6 fail=0)"
requires:
  - "T01,T02"
affects:
  - "P04 T04 (battery aggregates AD-19 SC test), T05 (phase-suite gates AD-19 verifiers)"
key_files:
  - "scripts/diagnostics/efficiency-footer.sh,tests/m031-acceptance/test-budget-drift-warning.sh,tools/verify/m031-p04-budget-drift-shape.sh,tools/verify/m031-p04-test-budget-drift-shape.sh"
key_decisions:
  - "Window=7 + threshold-multiplier=1.1: 7-record window is the minimum stable median sample (smaller windows false-positive on a single anomalous task; larger windows lag the operator-visible signal); 1.1 multiplier treats quick_knowledge_token_budget as advisory ceiling per FR-5/AD-13 (drift fires only when median sits >=10% over budget for 7 consecutive runs, not on a single overshoot)"
  - "Median statistic chosen over mean: mean is sensitive to a single outlier dispatch with very large knowledge_section_tokens; median absorbs that variance gracefully and is the operator-meaningful summary for budget-drift detection. Implementation: sort 7 values numerically and pick row 4 (the canonical median for an odd-sized window)"
  - "Half-full-window gate: m031_quick_window_median emits empty stdout when fewer than 7 quick records are available; m031_quick_budget_drift_check early-returns 0 on empty median (AD-19 trigger does not fire on a half-full window). Operators starting fresh with no history see no spurious early warnings"
  - "Direct-YAML-grep budget resolver: m031_quick_budget mirrors the M031/P02 + P03 4-layer config-knob resolution pattern (env-var implicit / .orchestrator/config.yml / templates/orchestrator-config-default.yml / hardcoded P00 default 800). Direct grep avoids a hard dependency on read-config.sh's VALID_KEYS allowlist, mirroring the P02 tier-a-plus-prompt.sh tier_a_plus_prompt_summary_lines pattern"
  - "Test seam: ORCH_EFFICIENCY_FOOTER_INPUT env override placed at the top of the input-resolution chain so the SC test beats every production fallback; production fallback is .orchestrator/observability/payload_breakdown.jsonl. Override naming follows the ORCH_<SUBSURFACE>_<NOUN> convention established by P02 (ORCH_TIER_A_PLUS_LOG) + P03 (ORCH_DO_ENTRY_LOG) + P04 T02 (ORCH_DOCTOR_CONFIG_PATH)"
  - "QUIET=0 gate on the drift-check call site: the new emission is suppressed when --quiet is in effect so the load-bearing CON-3/SC-3 byte-identity contract (zero stdout under --quiet) stays intact. Production drift detection runs in normal-output mode; the operator-suppression knob still wins"
  - "Call site placement: m031_quick_budget_drift_check invoked AFTER efficiency_footer_render in the CLI block so the new JSONL record appears at the tail of the stream, never above the human-readable footer body. Production callers consume the existing footer block first then optionally pipe through the JSONL warning"
  - "JSONL output shape: {\"warning\":\"QUICK_BUDGET_DRIFT\",\"window\":7,\"median\":N,\"budget\":N,\"threshold\":N} — the literal QUICK_BUDGET_DRIFT is the load-bearing contract per the task plan; the surrounding fields are implementation-defined diagnostic carriers. printf-only emission (no echo -e, no heredoc) for bash 3.2 / POSIX portability"
  - "awk integer-truncation for threshold: awk -v b=$budget BEGIN{printf %d, b * 11 / 10} produces threshold=880 for budget=800 (exact); for non-multiple-of-10 budgets the truncation is acceptable for an advisory threshold. No floating-point arithmetic in bash"
  - "Helper definitions placed at the TOP of the script (after _EFF_PROJECT_ROOT resolution, before efficiency_footer_render) so they are available to both sourced and CLI consumers; CLI invocation gated to the BASH_SOURCE != 0 entry point. Mirrors the existing efficiency_footer_render placement"
  - "no edits to T01 / T02 deliverables (templates/orchestrator-config-default.yml, CHANGELOG.md, scripts/diagnostics/run-doctor.sh, tests/m031-acceptance/{doc-drift-verifier,test-auto-proceed-default,test-doctor-compound-change}.sh, six T01/T02 shape verifiers all byte-frozen post-T01/T02 per plan-time discipline rule); T03 touches only scripts/diagnostics/efficiency-footer.sh + the new SC test + the two new shape verifiers"
  - "no edits to scripts/cost/, scripts/dispatch/adapters/router/, scripts/auto/loop/, knowledge/** in T03 (SC-12 block-list); CON-7/D020 scaffold-placeholder bracket-TODO byte pattern absent in all three new files; CON-1 invariant unaffected (T03 amendment is observational only — does not change dispatch behavior); NG-2 preserved (T03 ADDS one informational signal; existing M027 cost-rollup, predictive-surface, and check-anomalies surfaces untouched)"
patterns_established:
  - "AD-19 windowed-median informational warning shape: helper trio (config-knob resolver + windowed-statistic computer + trigger emitter) wired into a CLI consumer with a test-only env-override seam at the top of the input-resolution chain. Pattern reusable for any future budget-drift / threshold-drift surface (e.g. compression-savings drift, token-budget drift on Standard / Full profiles)"
  - "Half-full-window early-return discipline: windowed statistics emit empty stdout when the window holds fewer than N records; downstream consumers early-return 0 on empty stat. No spurious warnings before the first N-record window has accumulated. Generalizes the M005/P04 stagnation-signal pattern to rolling-window contexts"
  - "QUIET=0 gate as the byte-identity preservation discipline: when adding new emission surfaces to a script that already carries a load-bearing zero-stdout contract under --quiet, gate the new emission on QUIET=0 so the existing contract holds verbatim. Mirrors the M027/P02 efficiency_footer suppression pattern but applied additively"
  - "ORCH_<SUBSURFACE>_<NOUN> env-override naming convention now spans four consecutive surfaces: ORCH_TIER_A_PLUS_LOG (P02) -> ORCH_DO_ENTRY_LOG (P03) -> ORCH_DOCTOR_CONFIG_PATH (P04 T02) -> ORCH_EFFICIENCY_FOOTER_INPUT (P04 T03). Grep-discoverable across the codebase as the test-seam idiom"
  - "Hermetic mktemp + trap-rm-rf cleanup discipline carried forward from M031/P03 SC-7 / SC-8 + P04 T02 SC-9: SC test creates fixture JSONL streams under one mktemp -d work/ root, runs both back-to-back, traps the cleanup on EXIT. No /tmp residue between test runs"
  - "AD-19 single-script Truth Check shape preserved across both new verifiers (no inline compound bash, no process substitution, no plain subshells in verifier bodies); pattern matches M031/P03 do-md-shape.sh template verbatim including SCRIPT_DIR + PROJECT_ROOT resolution + ok()/ng() accumulator + check_literal helper using grep -qF -- needle for BSD-grep flag-token portability"
  - "Stream-agnostic SC test grep: 2>&1 captures stdout + stderr because the efficiency-footer's stream choice for the new JSONL record is implementation-defined; current implementation prints to stdout (printf default) but the test does not depend on that choice"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P04/tasks/T03-budget-drift-warning-PLAN.md"
duration: "25m"
verification_result: "pass"
completed_at: ""
---

## What Was Built

T03 closes the **post-merge runtime safety net** for Quick-injection efficiency drift. P01 made `quick_knowledge_token_budget` an advisory ceiling (FR-5 / AD-13 — not a hard cap); T01 wired the knob default into the config template; T02 wired the compound-change comms into the doctor. T03 ships the active drift-detection surface — operators running 7 consecutive Quick dispatches whose median knowledge injection sits >=10% above the budget see one informational `QUICK_BUDGET_DRIFT` JSONL record on the efficiency-footer stream. Non-blocking; never gates exit; preserves the existing CON-3/SC-3 byte-identity contract under `--quiet`.

Four artifacts shipped:

1. **`scripts/diagnostics/efficiency-footer.sh` amendment** — three new bash 3.2 helpers + one CLI call site, all preserving the existing exit-code + byte-identity contract:
   - **`m031_quick_budget`** (4-layer config-knob resolver) — env-var implicit / `.orchestrator/config.yml` / `templates/orchestrator-config-default.yml` / hardcoded P00 default 800. Direct YAML grep mirrors the M031/P02 `tier_a_plus_prompt_summary_lines` pattern.
   - **`m031_quick_window_median`** (rolling 7-record median) — filters the JSONL stream for `profile="quick"`, `tail -n 7` for the most recent window, extracts `knowledge_section_tokens` via `grep -oE`, sorts numerically, picks row 4. Emits empty stdout when fewer than 7 quick records are available.
   - **`m031_quick_budget_drift_check`** (trigger emitter) — when `median > budget * 1.1`, prints one JSONL record carrying the literal `QUICK_BUDGET_DRIFT` substring (`{"warning":"QUICK_BUDGET_DRIFT","window":7,"median":N,"budget":N,"threshold":N}`); silent otherwise. Always returns 0.
   - **CLI call site** — placed after `efficiency_footer_render` in the `BASH_SOURCE[0] = $0` block. Resolves `INPUT_PATH` via `ORCH_EFFICIENCY_FOOTER_INPUT` env override first, falling back to `$_EFF_PROJECT_ROOT/.orchestrator/observability/payload_breakdown.jsonl`. Gated on `QUIET=0` so the existing `--quiet` zero-stdout contract holds.

2. **`tests/m031-acceptance/test-budget-drift-warning.sh`** (78 lines, executable, bash 3.2 compatible) — hermetic `mktemp -d` scratch root with `trap rm -rf EXIT` cleanup. Constructs two fixture JSONL streams (`trip.jsonl` with 7 records each `knowledge_section_tokens=1000`; `safe.jsonl` with 7 records each `knowledge_section_tokens=700`). Pipes each fixture through `efficiency-footer.sh --project` via `ORCH_EFFICIENCY_FOOTER_INPUT=$stream` and asserts the trip case emits `QUICK_BUDGET_DRIFT` while the safe case suppresses it. Emits `RESULT: AD-19 pass` on 2/2 PASS.

3. **`tools/verify/m031-p04-budget-drift-shape.sh`** (AD-19 single-script Truth Check, 65 lines, bash 3.2) — asserts `scripts/diagnostics/efficiency-footer.sh` post-amend carries the five required literal substrings (`QUICK_BUDGET_DRIFT`, `quick_knowledge_token_budget`, `knowledge_section_tokens`, `ORCH_EFFICIENCY_FOOTER_INPUT`, `m031_quick_budget_drift_check`). Emits `SUMMARY: m031-p04-budget-drift-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`. Current `pass=6 fail=0`.

4. **`tools/verify/m031-p04-test-budget-drift-shape.sh`** (AD-19 single-script Truth Check, 71 lines, bash 3.2) — asserts the SC test exists, is executable, and references the four required artifact identifiers (`AD-19`, `QUICK_BUDGET_DRIFT`, `efficiency-footer.sh`, `ORCH_EFFICIENCY_FOOTER_INPUT`). Emits `SUMMARY: m031-p04-test-budget-drift-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`. Current `pass=6 fail=0`.

## Key Decisions

- **Window=7 + threshold-multiplier=1.1** — 7-record window is the minimum stable median sample size (smaller windows false-positive on a single anomalous task; larger windows lag the operator-visible signal too long); 1.1 multiplier treats `quick_knowledge_token_budget` as advisory ceiling per FR-5/AD-13. Drift fires only when median sits >=10% over budget for 7 consecutive runs.
- **Median over mean** — mean is sensitive to a single outlier dispatch; median absorbs variance gracefully and is the operator-meaningful summary. Implementation: sort 7 values numerically, pick row 4.
- **Half-full-window early-return** — `m031_quick_window_median` emits empty stdout when fewer than 7 quick records are available; `m031_quick_budget_drift_check` early-returns 0 on empty median. Operators starting fresh with no history see no spurious early warnings.
- **Direct-YAML-grep budget resolver** — `m031_quick_budget` mirrors the M031/P02 + P03 4-layer config-knob resolution pattern. Direct grep avoids a hard dependency on `read-config.sh`'s `VALID_KEYS` allowlist (the P02 `tier_a_plus_prompt_summary_lines` pattern).
- **`ORCH_EFFICIENCY_FOOTER_INPUT` at the top of the input-resolution chain** — test seam beats every production fallback. Production fallback: `.orchestrator/observability/payload_breakdown.jsonl`. Naming follows the `ORCH_<SUBSURFACE>_<NOUN>` convention established by P02/P03/P04-T02.
- **`QUIET=0` gate on the drift-check call site** — preserves the load-bearing CON-3/SC-3 byte-identity contract (zero stdout under `--quiet`) verbatim. Production drift detection runs in normal-output mode; the operator-suppression knob still wins.
- **Call site placement after `efficiency_footer_render`** — the new JSONL record appears at the tail of the stream, never above the human-readable footer body.
- **JSONL output shape** — `{"warning":"QUICK_BUDGET_DRIFT","window":7,"median":N,"budget":N,"threshold":N}`. The literal `QUICK_BUDGET_DRIFT` is the load-bearing contract per the task plan; surrounding fields are implementation-defined diagnostic carriers. `printf`-only emission for bash 3.2 / POSIX portability.
- **`awk` integer-truncation for threshold** — `awk -v b=$budget BEGIN{printf "%d", b * 11 / 10}` yields exact 880 for budget 800; truncation acceptable for an advisory threshold. No floating-point arithmetic in bash.
- **No edits to T01 / T02 deliverables** in T03 (`templates/orchestrator-config-default.yml`, `CHANGELOG.md`, `scripts/diagnostics/run-doctor.sh`, three SC tests, six T01/T02 shape verifiers all byte-frozen post-T01/T02). T03 touches only `scripts/diagnostics/efficiency-footer.sh` + the new SC test + the two new shape verifiers.
- **CON-1 invariant preserved** — T03 amendment is observational; does NOT change dispatch behavior. **NG-2 preserved** — T03 ADDS one informational signal; existing [M027](../../../../../milestones/M027/index.md) cost-rollup, predictive-surface, and check-anomalies surfaces are untouched. **SC-12 untouched directories preserved** — `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/` all unmodified.

## Patterns Established

- **AD-19 windowed-median informational warning shape** — helper trio (config-knob resolver + windowed-statistic computer + trigger emitter) wired into a CLI consumer with a test-only env-override seam at the top of the input-resolution chain. Reusable for any future budget-drift / threshold-drift surface.
- **Half-full-window early-return discipline** — windowed statistics emit empty stdout when the window holds fewer than N records; downstream consumers early-return 0 on empty stat. Generalizes the M005/P04 stagnation-signal pattern to rolling-window contexts.
- **`QUIET=0` gate as byte-identity preservation discipline** — when adding new emission surfaces to a script that already carries a load-bearing zero-stdout contract under `--quiet`, gate the new emission on `QUIET=0` so the existing contract holds verbatim.
- **`ORCH_<SUBSURFACE>_<NOUN>` env-override naming convention** now spans four consecutive surfaces: `ORCH_TIER_A_PLUS_LOG` (P02) → `ORCH_DO_ENTRY_LOG` (P03) → `ORCH_DOCTOR_CONFIG_PATH` (P04 T02) → `ORCH_EFFICIENCY_FOOTER_INPUT` (P04 T03). Grep-discoverable as the test-seam idiom.
- **Hermetic mktemp + trap-rm-rf cleanup** carried forward from M031/P03 SC-7 / SC-8 + P04 T02 SC-9.
- **AD-19 single-script Truth Check shape** preserved across both new verifiers — pattern matches M031/P03 `do-md-shape.sh` template verbatim.
- **Stream-agnostic SC test grep** — `2>&1` captures stdout + stderr because the new record's stream choice is implementation-defined.

## Verification

- `bash tests/m031-acceptance/test-budget-drift-warning.sh` → `RESULT: AD-19 pass` (2 PASS / 0 FAIL across trip-fixture + safe-fixture branches).
- `bash tools/verify/m031-p04-budget-drift-shape.sh` → `SUMMARY: m031-p04-budget-drift-shape.sh pass=6 fail=0`.
- `bash tools/verify/m031-p04-test-budget-drift-shape.sh` → `SUMMARY: m031-p04-test-budget-drift-shape.sh pass=6 fail=0`.

All three checks exit 0. Existing `--quiet` byte-identity contract verified: `bash scripts/diagnostics/efficiency-footer.sh --quiet` produces zero stdout. T03 leaves the post-merge runtime safety net for Quick-injection efficiency drift in place. T04 picks up with the milestone-grain SC-12 scope-guard + the SC-14 acceptance battery aggregator.
