---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M031"
goal: "Close M031 by shipping (a) the doc-drift fix on `commands/evaluate.md` (FR-14) and `references/tier-definitions.md` (FR-15) so Tier A reads identically across both surfaces; (b) the `auto_proceed: true` default in `templates/orchestrator-config-default.yml` (FR-16, AD-8) co-named in the CHANGELOG entry per AD-9; (c) the `scripts/diagnostics/run-doctor.sh` one-time compound-change comms message (AD-9 — names auto-proceed flip + unconditional Quick injection + recovery path; detects pre-M031 config by absence of `quick_knowledge_token_budget`); (d) the `scripts/diagnostics/efficiency-footer.sh` `QUICK_BUDGET_DRIFT` informational warning (AD-19 — rolling median of `knowledge_section_tokens` across the most recent 7 Quick dispatches > budget × 1.1, non-blocking JSONL emission); (e) the milestone-grain `tests/m031-acceptance/scope-guard.sh` (SC-12) verifier paired with the `tests/m031-acceptance/run-acceptance-battery.sh` aggregator (SC-14) chaining every prior phase's SC scripts plus the new P04 SCs; (f) the M031 `CHANGELOG.md` entry naming the compound behavioral change per AD-9; (g) the `M031-ACCEPTANCE-EVIDENCE.md` evidence ledger of the green run paralleling the M030 convention; (h) the SC-9 doc-drift verifier, SC-10 auto-proceed test, AD-9 doctor compound-change test, AD-19 budget-drift test, plus the `tools/verify/m031-p04-phase-suite.sh` aggregator and `tools/verify/m031-p04-scope-guard.sh` SC-12 phase-grain block-list — all under the dual-prefix permissive carve-out (`.orchestrator/observability/` + `.orchestrator/tier-a-plus/`) and MEM `hit_count`-only carve-out conventions inherited from P01 → P02 → P03."
demo_sentence: "An operator runs `bash tests/m031-acceptance/doc-drift-verifier.sh` and observes `RESULT: SC-9 pass` (zero matches for `no orchestrator overhead` / `Do NOT create any orchestrator directory` in `commands/evaluate.md`; canonical Tier A description present in both `commands/evaluate.md` and `references/tier-definitions.md`); runs `bash tests/m031-acceptance/test-auto-proceed-default.sh` and observes `RESULT: SC-10 pass` (`grep auto_proceed templates/orchestrator-config-default.yml` shows `auto_proceed: true`; CHANGELOG.md M031 entry names the compound flip); runs `bash tests/m031-acceptance/test-doctor-compound-change.sh` and observes `RESULT: AD-9 pass` (against a fixture project whose `.orchestrator/config.yml` lacks `quick_knowledge_token_budget`, `run-doctor.sh` emits a one-time message naming both behavioral changes plus the recovery path); runs `bash tests/m031-acceptance/test-budget-drift-warning.sh` and observes `RESULT: AD-19 pass` (a 7-dispatch fixture stream with rolling median > budget × 1.1 produces a `QUICK_BUDGET_DRIFT` JSONL record from `efficiency-footer.sh`); runs `bash tests/m031-acceptance/scope-guard.sh` and observes `RESULT: SC-12 pass` (M031's diff touches no path under `knowledge/**` schema, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`); runs `bash tests/m031-acceptance/run-acceptance-battery.sh` and observes `BATTERY: pass=N fail=0` with N ≥ 15 (SC-1..SC-13 plus SC-15 + SC-16 plus the SC-9 / SC-10 / SC-12 / AD-9 / AD-19 entries P04 ships); runs `bash tools/verify/m031-p04-phase-suite.sh` and observes `SUMMARY: m031-p04-phase-suite.sh pass=N fail=0`; runs `bash tools/verify/m031-p04-scope-guard.sh` and observes `SUMMARY: m031-p04-scope-guard.sh pass=N fail=0 block_list_violations=0`; reads `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md` and observes the green-run timestamp + battery summary line + per-SC pass/fail roll-up."
risk: "medium"
depends_on: ["P01", "P02", "P03"]
---

## Must-Haves

<!-- All Check commands use the single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/ per
     M032 Finding A. Verifier scripts are co-authored alongside their
     corresponding artifact within the SAME task (plan-time discipline
     rule 2). Namespacing: `m031-p04-*` prefix avoids collision with
     the M031/P01..P03 verifiers + the M030 verifiers in the shared
     tools/verify/ tree. The check-must-haves invocation is always
     given the phase DIRECTORY (not a specific plan filename) per the
     P03 plan-time defect note in continue.md. -->

### Truths

- `commands/evaluate.md` post-fix contains zero matches for the pre-M024 Tier A "no orchestrator overhead" / "Do NOT create any orchestrator directory" phrasings (FR-14 / SC-9). The canonical Tier A description "single dispatch with knowledge + compression via the Quick profile" is present.
  - Check: `bash tools/verify/m031-p04-evaluate-md-drift-shape.sh`

- `references/tier-definitions.md` post-fix matches `commands/evaluate.md` and explicitly states that `.orchestrator/` (config, knowledge, integrations) is always present and that only `.orchestrator/milestones/M###/` scaffolding is conditional (FR-15 / SC-9). Zero matches for the pre-M024 "no orchestrator overhead" string.
  - Check: `bash tools/verify/m031-p04-tier-definitions-drift-shape.sh`

- `templates/orchestrator-config-default.yml` declares `auto_proceed: true` as the active default (FR-16 / AD-8 / SC-10). The file's surrounding comment block names the flip explicitly so an operator reading the template understands the new default.
  - Check: `bash tools/verify/m031-p04-auto-proceed-default-shape.sh`

- `CHANGELOG.md` carries an M031 entry naming the **compound** behavioral change (auto-proceed flip AND unconditional Quick-profile knowledge injection) per AD-9. The entry references both the `auto_proceed` knob AND the `quick_knowledge_token_budget` knob so an operator upgrading from a pre-M031 project sees both changes co-located.
  - Check: `bash tools/verify/m031-p04-changelog-shape.sh`

- `scripts/diagnostics/run-doctor.sh` post-amend emits a one-time M031 compound-change message when invoked against a project whose `.orchestrator/config.yml` lacks `quick_knowledge_token_budget` (AD-9). The message names: (1) the `auto_proceed` flip from `false` to `true`; (2) the unconditional Quick-profile knowledge injection (no more skip branch); (3) the recovery path "add `auto_proceed: false` to `.orchestrator/config.yml` if you prefer the pre-M031 behavior." The detection is gated on the absence of the `quick_knowledge_token_budget` literal in the active config so operators whose config already has the knob (post-M031 init or explicit override) do NOT see the message on every run.
  - Check: `bash tools/verify/m031-p04-doctor-compound-change-shape.sh`

- `scripts/diagnostics/efficiency-footer.sh` post-amend emits a `QUICK_BUDGET_DRIFT` informational JSONL record when the rolling median of `knowledge_section_tokens` across the most recent 7 Quick dispatches exceeds `quick_knowledge_token_budget × 1.1` (AD-19). The signal is non-blocking — it surfaces via the existing M027 efficiency-footer JSONL stream and never causes a non-zero exit. The 7-dispatch window reads from the existing `payload_breakdown` JSONL records emitted by P01's `build-context.sh`.
  - Check: `bash tools/verify/m031-p04-budget-drift-shape.sh`

- `tests/m031-acceptance/doc-drift-verifier.sh` (SC-9, FR-17) exists, is executable, and exits 0 against the post-fix `commands/evaluate.md` + `references/tier-definitions.md`. Asserts: zero matches for the prohibited phrasings; canonical Tier A description present in both files. Emits `RESULT: SC-9 pass` on success. POSIX-bash per CON-6 / DC-7 so M009 can extend without rewrite.
  - Check: `bash tools/verify/m031-p04-test-doc-drift-shape.sh`

- `tests/m031-acceptance/test-auto-proceed-default.sh` (SC-10) exists, is executable, and exits 0. Asserts: `auto_proceed: true` literal present in `templates/orchestrator-config-default.yml`; `auto_proceed` is named in the M031 CHANGELOG entry. Emits `RESULT: SC-10 pass` on success.
  - Check: `bash tools/verify/m031-p04-test-auto-proceed-shape.sh`

- `tests/m031-acceptance/test-doctor-compound-change.sh` (AD-9) exists, is executable, and exits 0. Stages a fixture `.orchestrator/config.yml` lacking `quick_knowledge_token_budget` under a tmp scratch root and a fixture `.orchestrator/config.yml` carrying the knob; invokes `bash scripts/diagnostics/run-doctor.sh` against each via test-only env override (`ORCH_DOCTOR_CONFIG_PATH` or equivalent — staged by T02 as part of the doctor amendment). Asserts: the absent-knob fixture produces stderr/stdout containing the literal substrings `auto_proceed`, `quick`, and `M031`; the present-knob fixture does NOT emit those substrings. Emits `RESULT: AD-9 pass` on success.
  - Check: `bash tools/verify/m031-p04-test-doctor-compound-change-shape.sh`

- `tests/m031-acceptance/test-budget-drift-warning.sh` (AD-19) exists, is executable, and exits 0. Constructs a 7-record fixture JSONL stream of `payload_breakdown` records whose rolling median `knowledge_section_tokens` exceeds `quick_knowledge_token_budget × 1.1`; pipes it through `scripts/diagnostics/efficiency-footer.sh` via a test-only env override (e.g. `ORCH_EFFICIENCY_FOOTER_INPUT` or `--records-from <path>`). Asserts: the output contains a JSONL record carrying the literal substring `QUICK_BUDGET_DRIFT`. Constructs a control 7-record stream whose rolling median is below the threshold; asserts the control output does NOT contain `QUICK_BUDGET_DRIFT`. Emits `RESULT: AD-19 pass` on success.
  - Check: `bash tools/verify/m031-p04-test-budget-drift-shape.sh`

- `tests/m031-acceptance/scope-guard.sh` (SC-12 milestone-grain) exists, is executable, and exits 0 against the M031 working-tree diff. Asserts the M031 diff (whatever range the verifier defines — typically the merge-base range OR the working tree vs HEAD per the P01..P03 phase-grain convention) touches NO path under `knowledge/**` schema, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. Inherits the MEM `hit_count`-only carve-out and the `.orchestrator/observability/` + `.orchestrator/tier-a-plus/` dual-prefix permissive carve-out from the P01..P03 phase-grain scope-guards. Emits `RESULT: SC-12 pass` on success.
  - Check: `bash tools/verify/m031-p04-test-scope-guard-shape.sh`

- `tests/m031-acceptance/run-acceptance-battery.sh` (SC-14) exists, is executable, chains every prior-phase SC script and every P04 SC script in literal-sequence `bash <path>` invocations (AD-19 single-script-file shape, no array loops, no compound chains), captures rc per call, accumulates `pass`/`fail`, and emits a final `BATTERY: pass=N fail=M` line. Exits 0 iff `fail == 0`. Sub-gates (minimum N ≥ 15 — when SC13-OPTION.md records Option B; N ≥ 14 under Option A): SC-1 (`test-quick-injects-knowledge.sh`), SC-2 (`test-build-context-profile.sh`), SC-3 (`test-compression-applies-to-quick.sh`), SC-5 (`test-tier-a-plus-classifier.sh`), SC-6 (`test-tier-a-plus-flow.sh`), SC-7 (`test-universal-entry-trivial.sh`), SC-8 (`test-universal-entry-lowconf.sh`), SC-9 (`doc-drift-verifier.sh`), SC-10 (`test-auto-proceed-default.sh`), SC-11 (`empirical-baseline.sh --compare`), SC-12 (`scope-guard.sh`), SC-13 (`verify-baseline-ordering.sh` under Option B; otherwise dropped), SC-15 (`test-quick-budget-median.sh`), SC-16 (`test-tier-a-plus-prompt-ux.sh`), AD-9 (`test-doctor-compound-change.sh`), AD-19 (`test-budget-drift-warning.sh`). Mirrors the M030 acceptance-battery convention at `tests/m030-acceptance/run-acceptance-battery.sh`.
  - Check: `bash tools/verify/m031-p04-battery-shape.sh`

- `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md` exists post-phase, contains the literal output line `BATTERY: pass=N fail=0` from the green battery run (or a structurally-equivalent transcribed summary), names every SC by ID with its pass/fail outcome, names the timestamp of the green run in ISO-8601 form, and links back to the run-acceptance-battery.sh path. Mirrors the M030 evidence-ledger convention.
  - Check: `bash tools/verify/m031-p04-evidence-ledger-shape.sh`

- `tools/verify/m031-p04-phase-suite.sh` exists, is executable, invokes every P04 sub-gate in T01 → T02 → T03 → T04 → T05 dependency order via straight-line `bash <verifier>` invocations (AD-19 — no array loops, no compound chains, no eval), and emits a single final stdout line `SUMMARY: m031-p04-phase-suite.sh pass=N fail=M`. Exits 0 iff every sub-gate exits 0. Aggregator does NOT short-circuit on a sub-gate failure (all gates run regardless). Sub-gate ordering: T01 (5 gates: evaluate-md-drift-shape, tier-definitions-drift-shape, auto-proceed-default-shape, changelog-shape, test-doc-drift-shape, test-auto-proceed-shape), T02 (2 gates: doctor-compound-change-shape, test-doctor-compound-change-shape), T03 (2 gates: budget-drift-shape, test-budget-drift-shape), T04 (3 gates: test-scope-guard-shape, battery-shape, evidence-ledger-shape — note: evidence-ledger-shape is structural, not run-time-dependent), T05 (1 gate: m031-p04-scope-guard.sh — last gate per the P01/P02/P03 convention).
  - Check: `bash tools/verify/m031-p04-phase-suite.sh`

- `tools/verify/m031-p04-scope-guard.sh` exists, is executable, and asserts the P04 working-tree diff (vs HEAD) does NOT touch any path under the SC-12 block-list (`knowledge/**` schema, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`). Inherits the MEM `hit_count`-only carve-out (`^[+-]hit_count: [0-9]+$` regex on `knowledge/(conventions|lessons|patterns)/MEM*.md` paths) verbatim from P01/P02/P03. Inherits the dual-prefix permissive carve-out (`.orchestrator/observability/` + `.orchestrator/tier-a-plus/`) verbatim from P02/P03. Allow-list reflects the P04 "Files Likely Touched" surface plus phase/task plan + summary paths under `.orchestrator/milestones/M031/phases/P04/` plus the milestone summary path `.orchestrator/milestones/M031/M031-SUMMARY.md` and the evidence ledger `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`.
  - Check: `bash tools/verify/m031-p04-scope-guard.sh`

### Artifacts

- `commands/evaluate.md` (modify) (min 100 lines, contains "Quick profile", does NOT contain "no orchestrator overhead", does NOT contain "Do NOT create any orchestrator directory")
- `references/tier-definitions.md` (modify) (min 100 lines, contains "knowledge + compression", contains "Quick profile", does NOT contain "no orchestrator overhead")
- `templates/orchestrator-config-default.yml` (modify-or-confirm) (contains "auto_proceed: true", contains "M031", contains "quick_knowledge_token_budget")
- `CHANGELOG.md` (modify) (contains "M031", contains "auto_proceed", contains "quick_knowledge_token_budget", contains "compound")
- `scripts/diagnostics/run-doctor.sh` (modify) (min 200 lines, contains "M031", contains "quick_knowledge_token_budget", contains "auto_proceed")
- `scripts/diagnostics/efficiency-footer.sh` (modify) (min 250 lines, contains "QUICK_BUDGET_DRIFT", contains "quick_knowledge_token_budget", contains "knowledge_section_tokens")
- `tests/m031-acceptance/doc-drift-verifier.sh` (create) (min 40 lines, contains "SC-9", contains "evaluate.md", contains "tier-definitions.md")
- `tests/m031-acceptance/test-auto-proceed-default.sh` (create) (min 30 lines, contains "SC-10", contains "auto_proceed", contains "CHANGELOG")
- `tests/m031-acceptance/test-doctor-compound-change.sh` (create) (min 50 lines, contains "AD-9", contains "run-doctor.sh", contains "quick_knowledge_token_budget")
- `tests/m031-acceptance/test-budget-drift-warning.sh` (create) (min 50 lines, contains "AD-19", contains "QUICK_BUDGET_DRIFT", contains "efficiency-footer.sh")
- `tests/m031-acceptance/scope-guard.sh` (create) (min 80 lines, contains "SC-12", contains "knowledge/", contains "scripts/cost", contains "scripts/dispatch/adapters/router", contains "scripts/auto/loop")
- `tests/m031-acceptance/run-acceptance-battery.sh` (create) (min 80 lines, contains "BATTERY:", contains "SC-1", contains "SC-9", contains "SC-12", contains "SC-14", contains "AD-9", contains "AD-19")
- `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md` (create) (min 30 lines, contains "BATTERY:", contains "M031", contains "SC-")
- `tools/verify/m031-p04-evaluate-md-drift-shape.sh` (create) (min 25 lines, contains "evaluate.md", contains "no orchestrator overhead", contains "Quick profile")
- `tools/verify/m031-p04-tier-definitions-drift-shape.sh` (create) (min 25 lines, contains "tier-definitions.md", contains "Quick profile")
- `tools/verify/m031-p04-auto-proceed-default-shape.sh` (create) (min 20 lines, contains "auto_proceed", contains "true", contains "orchestrator-config-default.yml")
- `tools/verify/m031-p04-changelog-shape.sh` (create) (min 25 lines, contains "CHANGELOG", contains "M031", contains "auto_proceed", contains "quick_knowledge_token_budget")
- `tools/verify/m031-p04-doctor-compound-change-shape.sh` (create) (min 25 lines, contains "run-doctor.sh", contains "quick_knowledge_token_budget", contains "M031")
- `tools/verify/m031-p04-budget-drift-shape.sh` (create) (min 25 lines, contains "efficiency-footer.sh", contains "QUICK_BUDGET_DRIFT")
- `tools/verify/m031-p04-test-doc-drift-shape.sh` (create) (min 20 lines, contains "doc-drift-verifier.sh", contains "SC-9")
- `tools/verify/m031-p04-test-auto-proceed-shape.sh` (create) (min 20 lines, contains "test-auto-proceed-default.sh", contains "SC-10")
- `tools/verify/m031-p04-test-doctor-compound-change-shape.sh` (create) (min 20 lines, contains "test-doctor-compound-change.sh", contains "AD-9")
- `tools/verify/m031-p04-test-budget-drift-shape.sh` (create) (min 20 lines, contains "test-budget-drift-warning.sh", contains "AD-19")
- `tools/verify/m031-p04-test-scope-guard-shape.sh` (create) (min 20 lines, contains "scope-guard.sh", contains "SC-12")
- `tools/verify/m031-p04-battery-shape.sh` (create) (min 25 lines, contains "run-acceptance-battery.sh", contains "BATTERY:")
- `tools/verify/m031-p04-evidence-ledger-shape.sh` (create) (min 20 lines, contains "M031-ACCEPTANCE-EVIDENCE.md", contains "BATTERY:")
- `tools/verify/m031-p04-phase-suite.sh` (create) (min 80 lines, contains "SUMMARY:", contains "m031-p04-evaluate-md-drift-shape", contains "m031-p04-doctor-compound-change-shape", contains "m031-p04-budget-drift-shape", contains "m031-p04-battery-shape", contains "m031-p04-scope-guard")
- `tools/verify/m031-p04-scope-guard.sh` (create) (min 100 lines, contains "knowledge/", contains "scripts/cost", contains "scripts/dispatch/adapters/router", contains "scripts/auto/loop", contains "SC-12", contains "tier-a-plus", contains "observability")

### Key Links

<!-- Each declared key-link points to a file that EXISTS POST-PHASE
     under the artifact list above. Per the P02/T05 + P03 lesson, links
     pointing at literal filenames must be discoverable via grep on the
     basename inside the producing file — co-author a `# Key links
     (M031/P04):` comment block in scripts/tests that need to surface
     their cross-references for must-have verification (mirrors the
     P01 build-context.sh + P02 route-to-dispatch.sh + P03 phase-suite
     remediation pattern). -->

- `scripts/diagnostics/run-doctor.sh` → `templates/orchestrator-config-default.yml` (the doctor reads the active config and compares against the template default to detect pre-M031 projects)
- `scripts/diagnostics/efficiency-footer.sh` → `templates/orchestrator-config-default.yml` (the footer reads `quick_knowledge_token_budget` to compute the AD-19 drift threshold)
- `tests/m031-acceptance/doc-drift-verifier.sh` → `commands/evaluate.md` (SC-9 verifier scans evaluate.md for prohibited phrasings)
- `tests/m031-acceptance/doc-drift-verifier.sh` → `references/tier-definitions.md` (SC-9 verifier scans tier-definitions.md for canonical Tier A description)
- `tests/m031-acceptance/test-auto-proceed-default.sh` → `templates/orchestrator-config-default.yml` (SC-10 grep target)
- `tests/m031-acceptance/test-auto-proceed-default.sh` → `CHANGELOG.md` (SC-10 verifies the M031 entry names the flip)
- `tests/m031-acceptance/test-doctor-compound-change.sh` → `scripts/diagnostics/run-doctor.sh` (AD-9 invokes doctor under fixture configs)
- `tests/m031-acceptance/test-budget-drift-warning.sh` → `scripts/diagnostics/efficiency-footer.sh` (AD-19 invokes footer with fixture JSONL stream)
- `tests/m031-acceptance/run-acceptance-battery.sh` → `tests/m031-acceptance/test-quick-injects-knowledge.sh` (battery chains SC-1)
- `tests/m031-acceptance/run-acceptance-battery.sh` → `tests/m031-acceptance/test-tier-a-plus-flow.sh` (battery chains SC-6)
- `tests/m031-acceptance/run-acceptance-battery.sh` → `tests/m031-acceptance/test-universal-entry-trivial.sh` (battery chains SC-7)
- `tests/m031-acceptance/run-acceptance-battery.sh` → `tests/m031-acceptance/doc-drift-verifier.sh` (battery chains SC-9)
- `tests/m031-acceptance/run-acceptance-battery.sh` → `tests/m031-acceptance/test-auto-proceed-default.sh` (battery chains SC-10)
- `tests/m031-acceptance/run-acceptance-battery.sh` → `tests/m031-acceptance/scope-guard.sh` (battery chains SC-12)
- `tests/m031-acceptance/run-acceptance-battery.sh` → `tests/m031-acceptance/test-doctor-compound-change.sh` (battery chains AD-9)
- `tests/m031-acceptance/run-acceptance-battery.sh` → `tests/m031-acceptance/test-budget-drift-warning.sh` (battery chains AD-19)
- `tools/verify/m031-p04-phase-suite.sh` → `tools/verify/m031-p04-evaluate-md-drift-shape.sh` (suite invokes evaluate-md-drift gate)
- `tools/verify/m031-p04-phase-suite.sh` → `tools/verify/m031-p04-doctor-compound-change-shape.sh` (suite invokes doctor compound-change gate)
- `tools/verify/m031-p04-phase-suite.sh` → `tools/verify/m031-p04-budget-drift-shape.sh` (suite invokes budget-drift gate)
- `tools/verify/m031-p04-phase-suite.sh` → `tools/verify/m031-p04-battery-shape.sh` (suite invokes battery shape gate)
- `tools/verify/m031-p04-phase-suite.sh` → `tools/verify/m031-p04-scope-guard.sh` (suite invokes the phase scope-guard as the last gate)

## Tasks

### T01: Drift fix on `commands/evaluate.md` + `references/tier-definitions.md`, `auto_proceed` default + CHANGELOG entry, SC-9 + SC-10 acceptance tests (FR-14, FR-15, FR-16, AD-8, AD-9 CHANGELOG portion)

See `tasks/T01-drift-fix-and-changelog-PLAN.md`.

T01 ships the prose-level closures: removes the pre-M024 "no orchestrator overhead" / "Do NOT create any orchestrator directory" passages from `commands/evaluate.md` (FR-14), reconciles `references/tier-definitions.md` to the same canonical Tier A description (FR-15), confirms `auto_proceed: true` is the committed default in `templates/orchestrator-config-default.yml` (FR-16 / AD-8 — the working-tree value is already `true`; T01 commits that state and the surrounding documentation block names it explicitly), and adds the M031 `CHANGELOG.md` entry naming the **compound** behavioral change (auto-proceed flip AND unconditional Quick injection) per AD-9. T01 ships `tests/m031-acceptance/doc-drift-verifier.sh` (SC-9) and `tests/m031-acceptance/test-auto-proceed-default.sh` (SC-10) as the acceptance gates, plus four shape verifiers under `tools/verify/m031-p04-*.sh` (evaluate-md-drift-shape, tier-definitions-drift-shape, auto-proceed-default-shape, changelog-shape) and two SC-shape verifiers (test-doc-drift-shape, test-auto-proceed-shape).

### T02: `run-doctor.sh` compound-change comms (AD-9 active surface) + AD-9 acceptance test

See `tasks/T02-doctor-compound-change-PLAN.md`.

T02 amends `scripts/diagnostics/run-doctor.sh` to emit a one-time M031 compound-change message when invoked against a project whose `.orchestrator/config.yml` lacks the `quick_knowledge_token_budget` knob (the absence-detection avoids a permanent message after the operator updates their config). The message names: (a) the `auto_proceed` flip from `false` to `true`; (b) the unconditional Quick-profile knowledge injection (no more skip branch); (c) the recovery path "add `auto_proceed: false` to `.orchestrator/config.yml` if you prefer the pre-M031 behavior." T02 stages the `ORCH_DOCTOR_CONFIG_PATH` (or equivalent) test-only env override into the doctor script so the SC test can exercise both the present-knob and absent-knob branches deterministically. T02 ships `tests/m031-acceptance/test-doctor-compound-change.sh` and two shape verifiers (doctor-compound-change-shape, test-doctor-compound-change-shape).

### T03: `efficiency-footer.sh` `QUICK_BUDGET_DRIFT` warning (AD-19) + AD-19 acceptance test

See `tasks/T03-budget-drift-warning-PLAN.md`.

T03 amends `scripts/diagnostics/efficiency-footer.sh` to emit a `QUICK_BUDGET_DRIFT` informational JSONL record when the rolling median of `knowledge_section_tokens` across the most recent 7 Quick dispatches exceeds `quick_knowledge_token_budget × 1.1`. Threshold reads from `templates/orchestrator-config-default.yml` (or the active `.orchestrator/config.yml` if the knob is set there). The signal is non-blocking — it surfaces via the existing M027 efficiency-footer JSONL stream and never causes a non-zero exit; AD-19 is informational by design. T03 stages a test-only env override (e.g. `ORCH_EFFICIENCY_FOOTER_INPUT` or `--records-from <path>`) so the SC test can pipe a fixture 7-record stream deterministically. T03 ships `tests/m031-acceptance/test-budget-drift-warning.sh` and two shape verifiers (budget-drift-shape, test-budget-drift-shape).

### T04: Milestone-grain SC-12 scope-guard + acceptance battery aggregator (SC-14)

See `tasks/T04-scope-guard-and-battery-PLAN.md`.

T04 ships `tests/m031-acceptance/scope-guard.sh` — the **milestone-grain** SC-12 verifier distinct from the per-phase `tools/verify/m031-p0X-scope-guard.sh` family. The milestone-grain scope-guard targets the M031 working-tree diff as a whole (or whatever range the verifier defines for the milestone-close moment) rather than a single phase's surface. It inherits the block-list, MEM `hit_count` carve-out, and dual-prefix permissive carve-out from the per-phase scope-guards verbatim. T04 ships `tests/m031-acceptance/run-acceptance-battery.sh` chaining every prior-phase SC script (SC-1 / SC-2 / SC-3 / SC-5 / SC-6 / SC-7 / SC-8 / SC-11 / SC-15 / SC-16) plus the new P04 SC scripts (SC-9 / SC-10 / SC-12 / AD-9 / AD-19) plus SC-13 (`verify-baseline-ordering.sh`) under Option B in literal-sequence `bash <path>` invocations (AD-19 — straight-line, no array loops, no compound chains). The aggregator emits `BATTERY: pass=N fail=M` and exits 0 iff `fail == 0`. Mirrors the M030 acceptance-battery convention. T04 ships three shape verifiers: test-scope-guard-shape, battery-shape, evidence-ledger-shape. The evidence-ledger shape verifier is **structural** (asserts the output file shape) and only fails if T05's evidence ledger is malformed; it is a placeholder gate at T04 close that becomes load-bearing once T05 writes the ledger.

### T05: `M031-ACCEPTANCE-EVIDENCE.md` evidence ledger + P04 phase-suite + P04 phase-grain scope-guard

See `tasks/T05-evidence-ledger-and-phase-suite-PLAN.md`.

T05 runs the green `tests/m031-acceptance/run-acceptance-battery.sh` end-to-end and authors `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md` with the captured `BATTERY: pass=N fail=0` line, the per-SC pass/fail roll-up, the ISO-8601 timestamp of the green run, and a back-link to the battery script path. Mirrors the M030 evidence-ledger convention. T05 ships `tools/verify/m031-p04-phase-suite.sh` chaining every P04 sub-gate in T01 → T05 dependency order via straight-line `bash <verifier>` invocations (AD-19 — no array loops, no compound chains, no eval). The phase-suite emits `SUMMARY: m031-p04-phase-suite.sh pass=N fail=M`. T05 ships `tools/verify/m031-p04-scope-guard.sh` enforcing the SC-12 block-list with the same MEM hit_count + dual-prefix permissive carve-outs the prior-phase scope-guards use. The phase-grain scope-guard is the last gate in the phase-suite (clean diff required for green). T05 confirms `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P04/` reports 0 FAIL.

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03 ──▶ T04 ──▶ T05
```

Strict linear chain. T02 depends on T01 because the doctor message references the same compound-change vocabulary the CHANGELOG entry uses (single source of truth). T03 depends on T02 because the AD-19 budget-drift warning composes with the AD-9 doctor message — both surface the same `quick_knowledge_token_budget` knob to the operator. T04 depends on T03 because the acceptance battery chains the AD-19 test (and every prior SC test). T05 depends on T04 because the evidence ledger transcribes the green battery run and the phase-suite invokes T04's three shape verifiers as sub-gates.

## Files Likely Touched

- `commands/evaluate.md` (modify)
- `references/tier-definitions.md` (modify)
- `templates/orchestrator-config-default.yml` (modify-or-confirm)
- `CHANGELOG.md` (modify)
- `scripts/diagnostics/run-doctor.sh` (modify)
- `scripts/diagnostics/efficiency-footer.sh` (modify)
- `tests/m031-acceptance/doc-drift-verifier.sh` (create)
- `tests/m031-acceptance/test-auto-proceed-default.sh` (create)
- `tests/m031-acceptance/test-doctor-compound-change.sh` (create)
- `tests/m031-acceptance/test-budget-drift-warning.sh` (create)
- `tests/m031-acceptance/scope-guard.sh` (create)
- `tests/m031-acceptance/run-acceptance-battery.sh` (create)
- `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md` (create)
- `tools/verify/m031-p04-evaluate-md-drift-shape.sh` (create)
- `tools/verify/m031-p04-tier-definitions-drift-shape.sh` (create)
- `tools/verify/m031-p04-auto-proceed-default-shape.sh` (create)
- `tools/verify/m031-p04-changelog-shape.sh` (create)
- `tools/verify/m031-p04-doctor-compound-change-shape.sh` (create)
- `tools/verify/m031-p04-budget-drift-shape.sh` (create)
- `tools/verify/m031-p04-test-doc-drift-shape.sh` (create)
- `tools/verify/m031-p04-test-auto-proceed-shape.sh` (create)
- `tools/verify/m031-p04-test-doctor-compound-change-shape.sh` (create)
- `tools/verify/m031-p04-test-budget-drift-shape.sh` (create)
- `tools/verify/m031-p04-test-scope-guard-shape.sh` (create)
- `tools/verify/m031-p04-battery-shape.sh` (create)
- `tools/verify/m031-p04-evidence-ledger-shape.sh` (create)
- `tools/verify/m031-p04-phase-suite.sh` (create)
- `tools/verify/m031-p04-scope-guard.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-5]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. Test-run scratch files
     written under .orchestrator/tier-a-plus/<task-slug>/ during
     integration smoke runs land under the .orchestrator/tier-a-plus/
     permissive prefix (carve-out inherited from P02/P03 scope-guard).
     Test-run JSONL records written via test-only env overrides land
     at paths the test controls (typically /tmp); they are out of the
     scope-guard's purview because /tmp is outside the repo tree. -->
