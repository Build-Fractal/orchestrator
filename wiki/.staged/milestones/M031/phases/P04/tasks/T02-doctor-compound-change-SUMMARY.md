---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M031"
provides:
  - "scripts/diagnostics/run-doctor.sh AD-9 compound-change comms surface: ORCH_DOCTOR_CONFIG_PATH test-only env override resolves the active config path with .orchestrator/config.yml under PROJECT_ROOT as the production fallback; m031_compound_change_check function emits the M031 compound-change message via printf when the active config lacks quick_knowledge_token_budget; the function is called once at the top of the run-doctor.sh main flow before any run_check invocation; always returns 0 (passive observation surface, does not affect health-check scoring or exit codes)"
  - "tests/m031-acceptance/test-doctor-compound-change.sh (AD-9 SC test, 70 lines, executable, bash 3.2 / MEM001 compatible): hermetic mktemp scratch root + trap rm -rf EXIT cleanup pattern; constructs absent-knob and present-knob fixture configs; invokes the doctor once per fixture via the ORCH_DOCTOR_CONFIG_PATH env override; asserts (a) absent-knob fixture emits M031 + auto_proceed + quick_knowledge_token_budget literal substrings (3 PASS), (b) present-knob fixture suppresses the M031 (right-sized entry) is active header (1 PASS); emits RESULT: AD-9 pass (exit 0) on 4/4 green"
  - "tools/verify/m031-p04-doctor-compound-change-shape.sh (AD-19 single-script Truth Check, bash 3.2 / MEM001 compatible, 56 lines): asserts run-doctor.sh post-amend carries M031 + quick_knowledge_token_budget + auto_proceed + m031_compound_change_check + ORCH_DOCTOR_CONFIG_PATH literal substrings; emits SUMMARY: m031-p04-doctor-compound-change-shape.sh pass=N fail=M; exits 0 iff fail=0 (current pass=6 fail=0)"
  - "tools/verify/m031-p04-test-doctor-compound-change-shape.sh (AD-19 single-script Truth Check, bash 3.2 / MEM001 compatible, 64 lines): asserts the SC test exists, is executable, and references AD-9 + run-doctor.sh + ORCH_DOCTOR_CONFIG_PATH + quick_knowledge_token_budget literal substrings; emits SUMMARY: m031-p04-test-doctor-compound-change-shape.sh pass=N fail=M; exits 0 iff fail=0 (current pass=6 fail=0)"
requires:
  - "T01"
affects:
  - "P04 T03 (budget-drift surface composes with the doctor amendment), T04 (battery aggregates AD-9), T05 (phase-suite gates AD-9 verifiers)"
key_files:
  - "scripts/diagnostics/run-doctor.sh,tests/m031-acceptance/test-doctor-compound-change.sh,tools/verify/m031-p04-doctor-compound-change-shape.sh,tools/verify/m031-p04-test-doctor-compound-change-shape.sh"
key_decisions:
  - "Detection-by-knob-absence: pre-M031 config = active .orchestrator/config.yml lacking the literal substring quick_knowledge_token_budget. No version field, no migration timestamp, no separate state file — the simplest invariant is that any config initialized post-P01 carries the knob and any config initialized pre-M031 lacks it"
  - "ORCH_DOCTOR_CONFIG_PATH env override placed at the TOP of the resolution chain so the test seam beats every fallback; production callers do NOT set the env var and the doctor falls back to PROJECT_ROOT/.orchestrator/config.yml. Mirrors the M031/P02 ORCH_TIER_A_PLUS_LOG and M031/P03 ORCH_DO_ENTRY_LOG override-naming convention"
  - "m031_compound_change_check call site: placed at the top of the run-doctor.sh main flow (after the === Orchestrator Diagnostics === / Project root / Date echo block, before the first run_check invocation). The compound-change message reads as a one-time milestone announcement banner above the per-check output rather than buried mid-flow"
  - "printf-only message body (no echo -e, no heredoc): bash 3.2 / POSIX-portable; single-quoted printf strings with ' literal escaped via '\\'' standard concatenation; no $(...) substitution inside the message body so the emitted text is byte-stable across shells"
  - "function returns 0 unconditionally — passive observation surface per CON-1 (knowledge-unconditional) doctrine; the health-check scoring + exit-code contract is preserved by T02 (no checks_passed / checks_total mutation; no advisory_warnings increment). Operators who run orchestrator:doctor see the message as an informational banner above the existing health report, not as a failed check"
  - "AD-9 test asserts the present-knob path via the M031 (right-sized entry) is active header substring rather than a generic M031 absence-check. The doctor script body itself contains M031 markers in T02 comments (e.g. '# M031/P04/T02:'); a generic absence-check would false-positive when the doctor's stderr captures script-source bleeds. The full header substring is unique to the message body and so robust to incidental M031 mentions in the doctor's other output"
  - "SC test grep is stream-agnostic (2>&1 captures stdout + stderr) because the doctor's output stream choice for the new message is implementation-defined: printf to stdout makes sense for an operator-facing comm, stderr is also reasonable. The current implementation prints to stdout (printf default) but the test does not depend on that choice"
  - "no edits to T01 deliverables (commands/evaluate.md, references/tier-definitions.md, templates/orchestrator-config-default.yml, CHANGELOG.md, tests/m031-acceptance/doc-drift-verifier.sh, tests/m031-acceptance/test-auto-proceed-default.sh, six T01 shape verifiers all byte-frozen post-T01 per the plan-time discipline rule); T02 touches only scripts/diagnostics/run-doctor.sh + the new SC test + the two new shape verifiers"
  - "no edits to scripts/intake/, scripts/dispatch/, or commands/ in T02; no scaffold-placeholder marker bracket-TODO byte pattern in any new file (CON-7 / D020); SC-12 scope-guard untouched directories preserved (knowledge/**, scripts/cost/, scripts/dispatch/adapters/router/, scripts/auto/loop/)"
patterns_established:
  - "test-only env-override seam at the top of the resolution chain (ORCH_DOCTOR_CONFIG_PATH beats every production fallback): pattern repeats across M031 P02 (ORCH_TIER_A_PLUS_LOG) + P03 (ORCH_DO_ENTRY_LOG) + P04 T02 (ORCH_DOCTOR_CONFIG_PATH) — three consecutive phases use the same naming convention (ORCH_<SUBSURFACE>_<NOUN>) so the seam is grep-discoverable across the codebase"
  - "passive-observation-surface discipline: m031_compound_change_check returns 0 unconditionally and never increments checks_passed / checks_total / advisory_warnings — the existing exit-code contract is preserved verbatim. Future compound-change comms surfaces should follow the same passive-banner shape (printf message + return 0) rather than registering as a doctor check"
  - "detection-by-knob-absence pattern: when a milestone introduces a config knob (P01 added quick_knowledge_token_budget), downstream comms surfaces use the knob's absence as the migration trigger. No version field, no migration timestamp, no separate state file. Mirrors the M031/P03 entry_routing_confidence_floor knob-absence detection convention but inverted (P03 cares about presence; P04 T02 cares about absence)"
  - "compound-change comms framing (AD-9): T01 shipped the passive surface (CHANGELOG); T02 ships the active surface (doctor). The two surfaces share the same vocabulary (M031, auto_proceed, quick_knowledge_token_budget, compound) so an operator who reads either gets the same migration story. The active surface is one-time (suppresses on present-knob) so the operator is not nagged on every doctor run"
  - "AD-19 single-script Truth Check shape preserved across both new verifiers (no inline compound bash, no process substitution, no plain subshells in verifier bodies) — pattern matches M031 P03 do-md-shape.sh template verbatim including the SCRIPT_DIR + PROJECT_ROOT resolution + ok()/ng() accumulator + check_present helper using grep -qF -- needle for BSD-grep flag-token portability"
  - "hermetic-mktemp + trap-rm-rf cleanup discipline carried forward from P03 SC-7 / SC-8: SC test creates two fixture configs under one mktemp -d work/ root, runs both fixtures back-to-back, traps the cleanup on EXIT. No /tmp residue between test runs"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P04/tasks/T02-doctor-compound-change-PLAN.md"
duration: "30m"
verification_result: "pass"
completed_at: ""
---

## What Was Built

T02 closes the **active comms surface** for the AD-9 compound change. T01 shipped the passive surface (CHANGELOG bullet — operators only see it if they go looking); T02 ships the active surface — `orchestrator:doctor` runs as part of normal lifecycle health checks and emits a one-time message to operators upgrading from a pre-M031 project.

Four artifacts shipped:

1. **`scripts/diagnostics/run-doctor.sh` amendment** — two additions, both bash 3.2 compatible, both preserving the existing exit-code contract:
   - **Config-path resolution + env override** (top of the script, before the existing `--config-check` block): `ORCH_DOCTOR_CONFIG_PATH` test-only env override sets `DOCTOR_CONFIG_PATH` when present; production fallback is `PROJECT_ROOT/.orchestrator/config.yml`. The override is read at the top of the chain so it beats every fallback.
   - **`m031_compound_change_check` function + call site** — the function takes one positional argument (the config path), early-returns 0 if the file is missing, early-returns 0 if the file contains `quick_knowledge_token_budget`, and otherwise emits an 18-line printf message body framing the compound change (auto_proceed flip + Quick-profile knowledge+compression unconditionality) with a recovery path (`auto_proceed: false`) and a tuning hint (`quick_knowledge_token_budget` default 800). The function is called once at the top of the main flow (after the `=== Orchestrator Diagnostics ===` header, before the first `run_check` invocation) so the message reads as a one-time milestone announcement banner above the per-check output.

2. **`tests/m031-acceptance/test-doctor-compound-change.sh`** (70 lines, executable, bash 3.2 compatible) — hermetic mktemp scratch root with trap-rm-rf EXIT cleanup. Constructs two fixture configs (`absent.yml` lacking `quick_knowledge_token_budget`; `present.yml` carrying both `auto_proceed: true` and `quick_knowledge_token_budget: 800`). Invokes the doctor once per fixture via `ORCH_DOCTOR_CONFIG_PATH=$cfg bash $DOCTOR 2>&1 || true`. Four assertions: 3 against the absent-knob output (M031 + auto_proceed + quick_knowledge_token_budget literal substrings present), 1 against the present-knob output (`M031 (right-sized entry) is active` header substring absent). Emits `RESULT: AD-9 pass` (exit 0) on 4/4 green.

3. **`tools/verify/m031-p04-doctor-compound-change-shape.sh`** (AD-19 single-script Truth Check, 56 lines, bash 3.2) — asserts `scripts/diagnostics/run-doctor.sh` post-amend carries the five required literal substrings (`M031`, `quick_knowledge_token_budget`, `auto_proceed`, `m031_compound_change_check`, `ORCH_DOCTOR_CONFIG_PATH`). Emits `SUMMARY: m031-p04-doctor-compound-change-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`. Current `pass=6 fail=0`.

4. **`tools/verify/m031-p04-test-doctor-compound-change-shape.sh`** (AD-19 single-script Truth Check, 64 lines, bash 3.2) — asserts the SC test exists, is executable, and references the four required artifact identifiers (`AD-9`, `run-doctor.sh`, `ORCH_DOCTOR_CONFIG_PATH`, `quick_knowledge_token_budget`). Emits `SUMMARY: m031-p04-test-doctor-compound-change-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`. Current `pass=6 fail=0`.

## Key Decisions

- **Detection-by-knob-absence** as the pre-M031 trigger: any active `.orchestrator/config.yml` that lacks the literal `quick_knowledge_token_budget` substring is pre-M031 by definition. P01 added the knob to `templates/orchestrator-config-default.yml`; any config initialized post-P01 carries the knob; any config initialized pre-M031 lacks it. No version field, no migration timestamp, no separate state file — simplest invariant available.

- **`ORCH_DOCTOR_CONFIG_PATH` at the top of the resolution chain** so the test seam beats every production fallback. Production callers do NOT set the env var. The override naming follows the `ORCH_<SUBSURFACE>_<NOUN>` convention established by P02 (`ORCH_TIER_A_PLUS_LOG`) and P03 (`ORCH_DO_ENTRY_LOG`).

- **Call site at the top of the main flow** (after `=== Orchestrator Diagnostics ===` header echo, before the first `run_check` invocation) — the compound-change message reads as a one-time milestone announcement banner above the per-check output rather than buried mid-flow.

- **`printf`-only message body** (no `echo -e`, no heredoc, no `$(...)` inside the message body): bash 3.2 / POSIX-portable; single-quoted strings with `'` literal escaped via `'\''` standard concatenation. The emitted text is byte-stable across shells.

- **Function returns 0 unconditionally** — passive observation surface; the health-check scoring + exit-code contract is preserved by T02. Operators who run `orchestrator:doctor` see the message as an informational banner above the existing health report, not as a failed check. CON-1 invariant (knowledge-unconditional) is unaffected because T02 does not change dispatch behavior.

- **Present-knob assertion via the full `M031 (right-sized entry) is active` header substring** rather than a generic `M031` absence-check. The doctor script body itself contains `M031` markers in T02 comments (e.g. `# M031/P04/T02:`); a generic absence-check would false-positive when the doctor's stderr captures script-source bleeds. The full header substring is unique to the message body and robust to incidental `M031` mentions in the doctor's other output.

- **No edits to T01 deliverables** in T02 (`commands/evaluate.md`, `references/tier-definitions.md`, `templates/orchestrator-config-default.yml`, `CHANGELOG.md`, `tests/m031-acceptance/doc-drift-verifier.sh`, `tests/m031-acceptance/test-auto-proceed-default.sh`, and the six T01 shape verifiers all byte-frozen post-T01). No edits to `scripts/intake/`, `scripts/dispatch/`, or `commands/`. SC-12 scope-guard untouched directories preserved.

## Patterns Established

- **Test-only env-override seam at the top of the resolution chain** — pattern repeats across M031 P02 (`ORCH_TIER_A_PLUS_LOG`) + P03 (`ORCH_DO_ENTRY_LOG`) + P04 T02 (`ORCH_DOCTOR_CONFIG_PATH`); three consecutive phases use the same `ORCH_<SUBSURFACE>_<NOUN>` naming convention.
- **Passive-observation-surface discipline** — `m031_compound_change_check` returns 0 unconditionally and never increments scoring counters; the existing exit-code contract is preserved verbatim. Future compound-change comms surfaces should follow the same passive-banner shape rather than registering as a doctor check.
- **Detection-by-knob-absence** — when a milestone introduces a config knob, downstream comms surfaces use the knob's absence as the migration trigger. No version field, no migration timestamp, no separate state file.
- **Compound-change comms framing (AD-9)** — T01 ships the passive surface (CHANGELOG); T02 ships the active surface (doctor). Both surfaces share the same vocabulary (`M031`, `auto_proceed`, `quick_knowledge_token_budget`, `compound`) so an operator who reads either gets the same migration story.
- **AD-19 single-script Truth Check shape** preserved across both new verifiers (mirrors the M031/P03 `do-md-shape.sh` template verbatim including the SCRIPT_DIR + PROJECT_ROOT resolution + ok()/ng() accumulator + `check_present` helper using `grep -qF -- needle` for BSD-grep flag-token portability).
- **Hermetic mktemp + trap-rm-rf cleanup** carried forward from P03 SC-7 / SC-8: SC test creates fixture configs under one `mktemp -d work/` root, runs both back-to-back, traps cleanup on EXIT. No `/tmp` residue between test runs.

## Verification

- `bash tests/m031-acceptance/test-doctor-compound-change.sh` → `RESULT: AD-9 pass` (4 PASS / 0 FAIL across absent-knob and present-knob fixture branches).
- `bash tools/verify/m031-p04-doctor-compound-change-shape.sh` → `SUMMARY: m031-p04-doctor-compound-change-shape.sh pass=6 fail=0`.
- `bash tools/verify/m031-p04-test-doctor-compound-change-shape.sh` → `SUMMARY: m031-p04-test-doctor-compound-change-shape.sh pass=6 fail=0`.

All three checks exit 0. T02 leaves the active comms surface for the AD-9 compound change in place. T03 picks up with the AD-19 budget-drift warning on the [M027](../../../../../milestones/M027/index.md) efficiency-footer.
