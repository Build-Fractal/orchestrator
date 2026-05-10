---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M031"
provides:
  - "commands/evaluate.md drift fix (FR-14): pre-M024 'no orchestrator overhead' bullet replaced with 'single dispatch with knowledge + compression via the Quick profile' canonical Tier A descriptor; pre-M024 'Do NOT create any orchestrator directory structure (FR-003)' Tier A Result block replaced with M031-aligned prose naming orchestrator:dispatch + Quick profile + .orchestrator/ always-present + milestones/M###/ scaffolding-conditional-on-Tier-B/C reconciliation"
  - "references/tier-definitions.md drift fix (FR-15): pre-M024 'Direct routing to the host runtime\\'s native workflow with no orchestrator overhead' bullet replaced with 'Single dispatch with knowledge + compression via the Quick profile (M031: build-context.sh always runs)'; new always-present .orchestrator/ statement added to Tier A entry (config/knowledge/integrations always present; only milestones/M###/ scaffolding conditional)"
  - "templates/orchestrator-config-default.yml: confirmed auto_proceed: true active default (FR-16/AD-8); comment block amended to name M031 (right-sized entry, 2026-05-01) as the flip's owner + reference quick_knowledge_token_budget knob + document the recovery path (operators add explicit auto_proceed: false to .orchestrator/config.yml for pre-M031 behavior)"
  - "CHANGELOG.md M031 entry under [Unreleased]: ### Changed (M031 — right-sized entry) sub-section frames the auto_proceed flip + Quick-profile knowledge+compression unconditionality as a single compound behavioral change per AD-9; names quick_knowledge_token_budget + entry_routing_confidence_floor knobs; documents recovery path"
  - "tests/m031-acceptance/doc-drift-verifier.sh (SC-9, FR-17): 70-line POSIX-bash (CON-6/DC-7) verifier with check_absent + check_present helpers; emits RESULT: SC-9 pass on 5/5 assertion green; exits 0 iff fail=0"
  - "tests/m031-acceptance/test-auto-proceed-default.sh (SC-10): 53-line bash 3.2-compatible test asserting auto_proceed: true literal in template + 4 CHANGELOG substrings (M031 / auto_proceed / quick_knowledge_token_budget / compound); emits RESULT: SC-10 pass on 5/5 green; exits 0 iff fail=0"
  - "Six AD-19 single-script-file shape verifiers under tools/verify/m031-p04-* (evaluate-md-drift, tier-definitions-drift, auto-proceed-default, changelog, test-doc-drift, test-auto-proceed); all bash 3.2 / MEM001 compatible; each emits SUMMARY: <basename> pass=N fail=M and exits 0 iff fail=0"
requires:
  - "P00,P01,P02,P03"
affects:
  - "P04 T02 (doctor compound-change comms surface), T03, T04 (battery), T05 (phase-suite)"
key_files:
  - "commands/evaluate.md,references/tier-definitions.md,templates/orchestrator-config-default.yml,CHANGELOG.md,tests/m031-acceptance/doc-drift-verifier.sh,tests/m031-acceptance/test-auto-proceed-default.sh,tools/verify/m031-p04-evaluate-md-drift-shape.sh,tools/verify/m031-p04-tier-definitions-drift-shape.sh,tools/verify/m031-p04-auto-proceed-default-shape.sh,tools/verify/m031-p04-changelog-shape.sh,tools/verify/m031-p04-test-doc-drift-shape.sh,tools/verify/m031-p04-test-auto-proceed-shape.sh"
key_decisions:
  - "Tier A Result block (commands/evaluate.md ~line 138) replaced wholesale rather than bullet-deleted; the surrounding paragraph instructed agents to 'Do NOT create any orchestrator directory structure (FR-003)' and 'exit and let the developer use standard spec-kit commands directly' — both pre-M024 framings contradict the post-M031 always-present .orchestrator/ contract; replaced with M031-aligned prose naming orchestrator:dispatch + Quick profile + .orchestrator/ always-present invariant"
  - "tier-definitions.md Tier A entry: bullet-replace + add a new sentence between the 'When it applies' line and the 'What's Included' subsection naming .orchestrator/ as always-present (config/knowledge/integrations) with only milestones/M###/ scaffolding conditional — the explicit always-present statement makes the post-M031 contract grep-discoverable for downstream verifiers"
  - "tier-definitions.md What's Included list rewritten to lead with the M031 single-dispatch + Quick-profile + knowledge + compression bullet; the host-runtime native SDD bullet retained as a secondary option ('remains available...when the operator prefers') rather than the primary recommendation"
  - "tier-definitions.md What's Excluded list updated: the legacy 'No .orchestrator/ directory created' bullet removed (contradicts the new always-present statement); replaced with 'No .orchestrator/milestones/M###/ directory created' which matches the M031 contract"
  - "templates/orchestrator-config-default.yml: comment block amended ABOVE the auto_proceed line rather than below; the 5-line M031 sub-block names the flip's owner + the 2026-05-01 date + quick_knowledge_token_budget cross-reference + the explicit recovery path; quick_knowledge_token_budget stanza already present at line 138 (P00 added it) — no append needed"
  - "CHANGELOG.md: M031 entry placed at the TOP of the [Unreleased] section as a new ### Changed (M031 — right-sized entry) heading rather than appending to the existing ### Changed list; the M031 entries are heading-bracketed by the milestone framing per the existing v0.9.2 M018 entry-shape convention; the four required substrings (M031 / auto_proceed / quick_knowledge_token_budget / compound) all appear in the first bullet's 'Compound behavioral change' framing"
  - "SC-9 doc-drift-verifier.sh: POSIX-bash dialect (no [[ ]], no bash 4 features, no declare -A) per the task plan's CON-6/DC-7 constraint; check_absent + check_present helper functions take (file, needle, label) positional arguments and use grep -q -F -- pattern matching; the same -F flag pattern matches the M031/P03 verifier convention so BSD grep on macOS does not trip on flag-tokens"
  - "Six shape verifiers all use the M031/P03 verifier idiom (single SCRIPT_DIR + PROJECT_ROOT resolution, ok()/ng() accumulator, check_literal helper for grep -qF -- needle pattern, final SUMMARY: <basename> pass=N fail=M envelope, exit 0 iff fail=0); each verifier ≥20 lines per phase plan Artifacts; the pre-M024 prohibited phrasings appear in the test-doc-drift-shape verifier as needle inventory (the verifier reads the SC-9 test source, not the production target files — production target absence is the SC-9 verifier's job per the task plan's two-layer separation)"
patterns_established:
  - "two-layer absence-check separation: production target files (commands/evaluate.md + references/tier-definitions.md) are read by the SC-9 acceptance test (doc-drift-verifier.sh); the test source is read by the m031-p04-test-doc-drift-shape.sh shape verifier (asserts the test's needle inventory). The shape verifier does NOT duplicate the production absence-check; the SC-9 test does NOT assert anything about its own source. Each layer has a single grep responsibility."
  - "POSIX-bash discipline for cross-runtime acceptance tests (CON-6/DC-7): SC-9 test uses [ ... ] not [[ ... ]], $((...)) arithmetic, printf not echo -e, no declare -A; the SC-9 test runs unmodified under bash 3.2 + dash + sh which keeps M009 multi-runtime parity audit free of rewrite work"
  - "single co-located CHANGELOG note for compound behavioral changes (AD-9): when two related defaults flip simultaneously (auto_proceed + Quick-profile knowledge unconditionality in M031), they ship as one bullet framed with the 'compound' keyword rather than two independent bullets; downstream operator searches grep 'compound' and find the unified framing"
  - "doc-drift verifier idiom: emit RESULT: SC-N pass / RESULT: SC-N fail per the M031 P01/P02/P03 acceptance-test envelope convention; the matching shape verifier (m031-p04-test-doc-drift-shape.sh) emits SUMMARY: <basename> pass=N fail=M per the M031 P01/P02/P03 shape-verifier convention; the dual envelope shape (RESULT: for acceptance, SUMMARY: for shape) repeats verbatim across all four M031 phases"
  - "comment-block-naming-the-flip-owner pattern in config templates: when a default value flips (M031 auto_proceed: false -> true), the comment block immediately above the value line names the milestone + date + recovery path; future operators reading the template understand WHY the default is what it is and how to revert"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P04/tasks/T01-drift-fix-and-changelog-PLAN.md"
duration: "60m"
verification_result: "pass"
completed_at: ""
---

## What Was Built

T01 closes the **prose-level + CHANGELOG-level** surface for M031:

1. **`commands/evaluate.md` drift fix (FR-14, SC-9)** — two pre-[M024](../../../../../milestones/M024/index.md) phrasings contradicting the post-M024 routing table were replaced. The Tier A description block (lines ~101–106) had a bullet `- Direct routing to the host runtime's native workflow with no orchestrator overhead` already removed in a prior session, and the bullet `- **Result**: No orchestrator overhead — route directly to standard spec-kit commands` (line 106) was replaced with the canonical Tier A descriptor `Single dispatch with knowledge + compression via the Quick profile (M031: build-context.sh always runs; the Quick profile scopes traversal to 1-hop touched-file hits)`. The Tier A Result block (line ~138) had `- Do NOT create any orchestrator directory structure (FR-003)` replaced wholesale with M031-aligned prose: `Tier A invokes orchestrator:dispatch with the Quick profile (knowledge + compression unconditional per M031). .orchestrator/ (config, knowledge, integrations) is always present; only .orchestrator/milestones/M###/ scaffolding is conditional on Tier B/C.`

2. **`references/tier-definitions.md` drift fix (FR-15, SC-9)** — Tier A description block (lines 14–46) reconciled to match commands/evaluate.md. The pre-M024 bullet `- Direct routing to the host runtime's native workflow with no orchestrator overhead` (line 22) was replaced with `- Single dispatch with knowledge + compression via the Quick profile (M031: build-context.sh always runs)`. A new sentence added between the "When it applies" line and the "What's Included" subsection: `.orchestrator/ (config, knowledge, integrations) is always present in any orchestrator-installed project; only .orchestrator/milestones/M###/ scaffolding is conditional on Tier B/C. Tier A invocations read knowledge and reuse the project's compression layer — they just skip the milestone-tree ceremony.` The What's Included list now leads with the M031 single-dispatch+Quick-profile+knowledge+compression bullet. The What's Excluded list's legacy `No .orchestrator/ directory created` bullet was replaced with `No .orchestrator/milestones/M###/ directory created` to match the always-present contract.

3. **`templates/orchestrator-config-default.yml` flip confirmation + comment amend (FR-16, AD-8)** — `auto_proceed: true` confirmed at line 27 (working-tree state at session entry). Comment block immediately above the `auto_proceed` line amended with a 5-line M031 sub-block naming the flip's owner (`M031 (right-sized entry, 2026-05-01)`), the cross-referenced knob (`quick_knowledge_token_budget`), and the recovery path (`Operators who prefer the pre-M031 behavior should add an explicit auto_proceed: false line to their .orchestrator/config.yml`). The `quick_knowledge_token_budget: 800` stanza is already present at line 138 (P00 added it during the M031 right-sized entry foundation phase) so no append was needed.

4. **`CHANGELOG.md` M031 entry (AD-9)** — added a new `### Changed (M031 — right-sized entry)` sub-section at the TOP of the existing `## [Unreleased]` section. Four bullets: (a) the **compound** behavioral change framing the auto_proceed flip + Quick-profile knowledge+compression unconditionality as ONE bullet per AD-9; (b) the new `quick_knowledge_token_budget` config knob (default 800 tokens); (c) the new `entry_routing_confidence_floor` knob (default 0.7); (d) the recovery path. All four required substrings (`M031`, `auto_proceed`, `quick_knowledge_token_budget`, `compound`) are present in the first bullet alone; the recovery-path bullet repeats `auto_proceed: false` for operator visibility.

5. **SC-9 doc-drift verifier** — `tests/m031-acceptance/doc-drift-verifier.sh` (70 lines, POSIX-bash CON-6/DC-7 compatible). Five assertions: 2× absence-check on commands/evaluate.md (no orchestrator overhead + Do NOT create any orchestrator directory), 1× presence-check on commands/evaluate.md (Quick profile), 1× absence-check on references/tier-definitions.md (no orchestrator overhead), 1× presence-check on references/tier-definitions.md (Quick profile). Emits `RESULT: SC-9 pass` (exit 0) on 5/5 green.

6. **SC-10 auto-proceed default test** — `tests/m031-acceptance/test-auto-proceed-default.sh` (53 lines, bash 3.2 / MEM001 compatible). Five assertions: 1× presence-check on templates/orchestrator-config-default.yml (`auto_proceed: true`), 4× presence-check on CHANGELOG.md (`M031`, `auto_proceed`, `quick_knowledge_token_budget`, `compound`). Emits `RESULT: SC-10 pass` (exit 0) on 5/5 green.

7. **Six shape verifiers under `tools/verify/`** — all AD-19 single-script-file shape, bash 3.2 / MEM001 compatible:
   - `m031-p04-evaluate-md-drift-shape.sh` (pass=4 fail=0)
   - `m031-p04-tier-definitions-drift-shape.sh` (pass=4 fail=0)
   - `m031-p04-auto-proceed-default-shape.sh` (pass=4 fail=0)
   - `m031-p04-changelog-shape.sh` (pass=5 fail=0)
   - `m031-p04-test-doc-drift-shape.sh` (pass=8 fail=0)
   - `m031-p04-test-auto-proceed-shape.sh` (pass=6 fail=0)

## Verification Results

All eight verifiers green:

| Verifier | Result | Pass/Fail |
|----------|--------|-----------|
| `tests/m031-acceptance/doc-drift-verifier.sh` | `RESULT: SC-9 pass` | 5/0 |
| `tests/m031-acceptance/test-auto-proceed-default.sh` | `RESULT: SC-10 pass` | 5/0 |
| `tools/verify/m031-p04-evaluate-md-drift-shape.sh` | `SUMMARY: ... pass=4 fail=0` | 4/0 |
| `tools/verify/m031-p04-tier-definitions-drift-shape.sh` | `SUMMARY: ... pass=4 fail=0` | 4/0 |
| `tools/verify/m031-p04-auto-proceed-default-shape.sh` | `SUMMARY: ... pass=4 fail=0` | 4/0 |
| `tools/verify/m031-p04-changelog-shape.sh` | `SUMMARY: ... pass=5 fail=0` | 5/0 |
| `tools/verify/m031-p04-test-doc-drift-shape.sh` | `SUMMARY: ... pass=8 fail=0` | 8/0 |
| `tools/verify/m031-p04-test-auto-proceed-shape.sh` | `SUMMARY: ... pass=6 fail=0` | 6/0 |

Truth #1 (evaluate.md drift), Truth #2 (tier-definitions.md drift), Truth #3 (auto_proceed default), Truth #4 (CHANGELOG M031 entry), Truth #7 (SC-9 verifier exists+executable+exit 0), and Truth #8 (SC-10 test exists+executable+exit 0) all satisfied.

## Patterns Established

- **Two-layer absence-check separation**: production targets read by the SC-N acceptance test; the test source itself read by the matching shape verifier. No duplicated grep responsibility.
- **POSIX-bash discipline for cross-runtime acceptance tests** (CON-6/DC-7): SC-9 verifier runs unmodified under bash 3.2 + dash + sh; M009 audit gets it free.
- **Single co-located CHANGELOG note for compound behavioral changes** (AD-9): the `compound` keyword is the search-discoverable framing.
- **Dual envelope shape**: `RESULT: SC-N pass/fail` for acceptance tests, `SUMMARY: <basename> pass=N fail=M` for shape verifiers — repeats verbatim across all four M031 phases.
- **Comment-block-naming-the-flip-owner pattern in config templates**: when a default value flips, the comment block immediately above names the milestone + date + recovery path so future operators understand WHY without git-blame archaeology.

## Forward-Looking Notes for T02+

- T02 picks up the active doctor compound-change comms surface (`scripts/diagnostics/run-doctor.sh` + `scripts/diagnostics/efficiency-footer.sh` amendments).
- The SC-9 + SC-10 verifiers + the six shape verifiers are now T05 phase-suite candidates. T05 will aggregate them with T02–T04 sub-gates into `m031-p04-phase-suite.sh`.
- Pre-existing working-tree drift ([M030](../../../../../milestones/M030/index.md) ROADMAP, AGENTS.md, KNOWLEDGE-INDEX.md, knowledge/MEM*.md hit_count increments, scripts/dispatch/build-context.sh, references/RUNTIME-ASSUMPTIONS.md, tools/verify/p00-phase-suite.sh, .orchestrator/doctor-history.jsonl) carried forward from prior sessions remains uncommitted; recommend a milestone-level housekeeping commit before M031-SUMMARY.md writes per the P03 forward note.
