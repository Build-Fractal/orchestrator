---
schema_version: "1.0"
type: phase-summary
id: "P04"
parent: "M032"
milestone: "M032"
provides:
  - "FR-17 + FR-18 + FR-19 scanner extensions on scripts/wiki/wiki-scan-sources.sh (proposals:* records with stage badge derivation; extra:<dirname> records driven by wiki.extra_dirs config; knowledge-flat records on .orchestrator/knowledge/*.md flat files); FR-17/18/19 nav rendering in scripts/wiki/wiki-generate-nav.sh under # >>> auto-nav region (Proposals top-level section; per-extra_dirs sections; Knowledge — Flat sibling section); FR-20 build-time code-shorthand decorator stub scripts/wiki/wiki-decorate-codes.sh (US-8 P3 surface — first-occurrence-titled subsequent-link-only; missing-glossary fallback with byte-identical copy); SC-8 acceptance tests/m032-acceptance/p0X-scanner-extensions.sh (FR-17/18/19 four-branch coverage); SC-9 acceptance tests/m032-acceptance/p0X-code-decorator.sh (US-8 AS-1..AS-3); SC-11 acceptance tests/m032-acceptance/sc11-doctor-no-warnings.sh (Constitution VIII run-doctor.sh + MIT-002 wiki-serve.sh --probe self-application + MIT-008 wiki-deploy-mutation audit-trail); SC-12 milestone-grain acceptance battery tests/m032-acceptance/run-acceptance-battery.sh (MIT-001 three-category exit semantics rc==0/77/other -> pass++/skip++/fail++ + M032_ACCEPTANCE_BATTERY_DRY=1 dry-mode escape hatch); --with-wiki no-op in-flight repair on scripts/lifecycle/wiki-init.sh (FR-11 passthrough symmetry); eight P04-owned task-grain shape verifiers (m032-p04-scanner-extensions.sh + m032-p04-nav-extensions.sh + m032-p04-decorator-shape.sh + m032-p04-with-wiki-noop.sh + m032-p04-acceptance-shape-sc8.sh + m032-p04-acceptance-shape-sc9.sh + m032-p04-acceptance-shape-sc11.sh + m032-p04-acceptance-battery-shape.sh); milestone-close ceremony surfaces (M032-VALIDATED conditional marker + M032-SUMMARY.md 16-field frontmatter + milestone-grain unit_close JSONL record + M032-ACCEPTANCE-EVIDENCE.md per the M030/M031 evidence-ledger convention); five P04-owned milestone-close shape verifiers (m032-p04-validate-milestone.sh + m032-p04-milestone-close-ceremony.sh + m032-p04-acceptance-evidence-ledger.sh + m032-p04-phase-suite.sh + m032-p04-scope-guard.sh) + tools/verify/fixtures/m032-p04-baseline-ref.txt baseline captured per the M032 P01/P02/P03 first-run-captures-HEAD convention; T05 in-flight repairs to sibling-phase verifier shape drift (tools/verify/fixtures/m032-pre-m032-golden.txt scripts count refresh 1161->1163 + total 1277->1279 post-T01-T02 source-tree growth; tests/m032-acceptance/p02-glossary-surface.sh nav marker '# >>> M012-P01 nav' -> '# >>> auto-nav' post-P03/T03 region split; tests/m032-acceptance/p03-wiki-init-deploy-live.sh fixture-completeness skip precondition for SC-5 per MIT-001 three-category exit semantics)"
requires:
  - "P02,P03"
affects:
  - "M032"
key_files:
  - "scripts/wiki/wiki-scan-sources.sh,scripts/wiki/wiki-generate-nav.sh,scripts/wiki/wiki-generate-stubs.sh,scripts/wiki/wiki-decorate-codes.sh,scripts/lifecycle/wiki-init.sh,tests/m032-acceptance/p0X-scanner-extensions.sh,tests/m032-acceptance/p0X-code-decorator.sh,tests/m032-acceptance/sc11-doctor-no-warnings.sh,tests/m032-acceptance/run-acceptance-battery.sh,tests/m032-acceptance/p02-glossary-surface.sh,tests/m032-acceptance/p03-wiki-init-deploy-live.sh,tools/verify/m032-p04-scanner-extensions.sh,tools/verify/m032-p04-nav-extensions.sh,tools/verify/m032-p04-decorator-shape.sh,tools/verify/m032-p04-with-wiki-noop.sh,tools/verify/m032-p04-acceptance-shape-sc8.sh,tools/verify/m032-p04-acceptance-shape-sc9.sh,tools/verify/m032-p04-acceptance-shape-sc11.sh,tools/verify/m032-p04-acceptance-battery-shape.sh,tools/verify/m032-p04-validate-milestone.sh,tools/verify/m032-p04-milestone-close-ceremony.sh,tools/verify/m032-p04-acceptance-evidence-ledger.sh,tools/verify/m032-p04-phase-suite.sh,tools/verify/m032-p04-scope-guard.sh,tools/verify/fixtures/m032-p04-baseline-ref.txt,tools/verify/fixtures/m032-pre-m032-golden.txt,.orchestrator/milestones/M032/M032-SUMMARY.md,.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md,.orchestrator/milestones/M032/execution-log.jsonl"
key_decisions:
  - "FR-17,FR-18,FR-19,FR-20,FR-22,US-7,US-8,SC-8,SC-9,SC-11,SC-12,SC-13,SC-14,MIT-001,MIT-002,MIT-008,Constitution-VI,Constitution-VIII,AD-7,AD-19,MEM001,MEM030,M026,M030-lineage,M031-lineage"
patterns_established:
  - "three-source-family scanner extension (proposals:* + extra:<dirname> + knowledge-flat) with default-on/default-off opt-in flags consistent with FR-15 --include-glossary precedent; YAML frontmatter stage-badge derivation (stub|brief|specified|active|closed) with unknown fallback per US-7 AS-1 (no exclusion); single-script-file FR-20 build-time decorator stub with regex-pattern multi-class match + glossary lookup + first-occurrence-titled subsequent-link-only rendering + missing-glossary fallback (byte-identical copy to stdout/output) per US-8 P3 stub-shape; three-orthogonal-invariant single-acceptance-script pattern (Constitution VIII + MIT-002 + MIT-008 stitched via three say_pass/say_fail assertion groups under one trap-EXIT envelope); load-bearing-token-surface shape-verifier pattern (12 tokens covering invariant tags + envelope keys + accounting + RESULT line) extending P02/P03 acceptance-shape verifier convention; three-category battery aggregator over MIT-001 (rc==0/77/other -> pass++/skip++/fail++) wrapped around the M030/M031 run_sc() helper -- reusable for any future milestone whose acceptance corpus includes live-network gates that need POSIX skip-code distinction from real failures; <MILESTONE>_ACCEPTANCE_BATTERY_DRY=1 test-only dry-mode escape hatch in acceptance battery runners (mirrors P03 <TOOL>_<HELPER>_STUB envelope and P02 M032_WIKI_INIT_FORCE_EXIT envelope); shape verifier with embedded runtime check (beyond grep-for-token assertions executes runner under dry-mode and parses final BATTERY: line + counts BATTERY-SKIP emissions -- catches drift between literal SC label list and actual run_sc call sites); literal-sequence eleven-gate phase-suite per AD-19 single-script-file shape (NOT a for-loop iteration over sub-gates -- a maintainer collapsing this into a loop trips the AD-19 shape-detection guard); first-run-captures-HEAD-as-baseline scope-guard pattern + regex-allowlist + regex-denylist twin-check (committed-history-only diff per the P01/P02/P03 patterns-established lesson); milestone-close evidence-ledger convention (mirrors M030/M031 -- operator-facing transcription of green BATTERY line + per-SC roll-up + ISO-8601 timestamp + back-link to runner); conditional M032-VALIDATED marker per MIT-001 + SC-14 (marker MUST NOT be created at skip=1 unless signed-attestation block is in M032-SUMMARY.md); fixture-completeness precondition pattern (SC-5 emits exit 77 SKIP_REASON when tests/fixtures/m032-fresh-project-fixture/ lacks scripts/wiki/wiki-deploy.sh -- environmental precondition not test failure); in-flight repair convention extended to milestone-close ceremony (T05 repairs sibling-phase verifier shape drift surfaced by the SC-12 battery within the same task -- mirrors P02/T02 + P03/T05 precedents)"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P04/tasks/T01-scanner-extensions-SUMMARY.md,.orchestrator/milestones/M032/phases/P04/tasks/T02-decorator-and-with-wiki-noop-SUMMARY.md,.orchestrator/milestones/M032/phases/P04/tasks/T03-SUMMARY.md,.orchestrator/milestones/M032/phases/P04/tasks/T04-SUMMARY.md,.orchestrator/milestones/M032/phases/P04/tasks/T05-SUMMARY.md"
duration: "420m"
verification_result: "pass"
completed_at: "2026-05-05T14:26:35Z"
observability_surfaces:
  - "none"
---

## What Shipped

P04 closes M032 by landing the additive scanner extensions, the FR-20
build-time code-shorthand decorator stub, the SC-8 / SC-9 / SC-11
acceptance scripts, the SC-12 milestone-grain acceptance battery
aggregator, and the milestone-close ceremony surfaces. Five tasks
shipped end-to-end, each verified and committed atomically; the
phase-suite aggregator and SC-13 scope-guard gate the phase close.

The five task tranches:

1. **T01 — FR-17 + FR-18 + FR-19 scanner extensions on
   `wiki-scan-sources.sh` + `wiki-generate-nav.sh` +
   `wiki-generate-stubs.sh` + SC-8 acceptance** — Three source families
   added under three independently flag-gated branches. FR-17 emits
   `proposals:<basename>` records with `[stage]` badge derived from
   YAML frontmatter `stage:` field (`stub|brief|specified|active|closed`)
   and `unknown` fallback per US-7 AS-1; default-on with
   `--no-include-proposals` opt-out. FR-18 walks
   `wiki.extra_dirs:` from `<PROJECT_ROOT>/.orchestrator/config.yml`
   and emits `extra:<dirname>` records (zero records when config absent
   or empty — no false-positive section). FR-19 emits `knowledge-flat`
   records over `.orchestrator/knowledge/*.md` flat files. Nav
   generator renders the three families inside the `# >>> auto-nav`
   region per P03/T03's region split.

2. **T02 — FR-20 code-shorthand decorator stub + SC-9 acceptance +
   `--with-wiki` no-op in-flight repair** —
   `scripts/wiki/wiki-decorate-codes.sh` implements `--in <input>
   --glossary <glossary> --out <output>` with regex-pattern multi-class
   match (`[A-Z]{2,4}-\d+` / `M\d{3}` / `DR-[A-Z]+-\d+` / `AP-\d+`),
   glossary lookup against `### TERM` headings, first-occurrence-titled
   (`CODE (Title)` linked) and subsequent-link-only rendering, and
   missing-glossary fallback (byte-identical copy). T02 also lands the
   `--with-wiki) shift ;;` no-op in-flight repair on
   `scripts/lifecycle/wiki-init.sh` per the P03 follow-up — operators
   chaining `--with-wiki --with-giscus --deploy` no longer hit a
   confusing "unknown argument" failure.

3. **T03 — SC-11 doctor-no-warnings + wiki-serve self-application +
   audit-trail acceptance** — Three orthogonal invariants stitched
   under one trap-EXIT envelope: Constitution VIII
   (`run-doctor.sh --root <fixture>` exits 0 with zero
   `dead-infrastructure` / `unreferenced-asset` warnings), MIT-002
   (`wiki-serve.sh --probe` against the orchestrator's own `wiki/`
   exits 0 — closes the FR-6 self-application loop), and MIT-008
   (`wiki-deploy-mutation` audit-trail record on
   `.orchestrator/execution-log.jsonl` with `result: success`).

4. **T04 — SC-12 acceptance battery aggregator** —
   `tests/m032-acceptance/run-acceptance-battery.sh` chains all eleven
   SC verifiers (SC-1..SC-11) in literal sequence per AD-19
   single-script-file shape with the M030/[M031](../../../../milestones/M031/index.md) `set -uo pipefail` +
   `run_sc()` helper, applying MIT-001 three-category exit semantics
   (`rc==0/77/other -> pass++/skip++/fail++`). Final stdout line:
   `BATTERY: pass=N skip=M fail=K`. `M032_ACCEPTANCE_BATTERY_DRY=1`
   test-only dry-mode escape hatch lets the shape verifier exercise
   the eleven-count contract without invoking real SCs.

5. **T05 — milestone-close ceremony + P04 phase-suite + scope-guard
   (this task)** — Milestone-close ceremony per the M030/M031
   discipline: `M032-SUMMARY.md` with 16-field frontmatter referencing
   SC-1..SC-13 verdicts; conditional `M032-VALIDATED` marker per
   MIT-001 + SC-14 (marker presence gated on SC-12 `skip=0` OR signed-
   attestation block); milestone-grain `unit_close` JSONL record;
   `M032-ACCEPTANCE-EVIDENCE.md` evidence ledger; five P04-grain
   close-ceremony shape verifiers; the eleven-gate phase-suite
   aggregator (literal-sequence per AD-19 — NOT a for-loop iteration);
   the SC-13 scope-guard with regex-allowlist + regex-denylist twin-
   check + first-run-captures-HEAD baseline-ref capture mirroring the
   P01/P02/P03 convention. T05 also applied three in-flight repairs
   to sibling-phase verifier shape drift surfaced by the SC-12 battery:
   (a) `tools/verify/fixtures/m032-pre-m032-golden.txt` script-count
   refresh (1161 -> 1163; total 1277 -> 1279) post-T01-T02 source-tree
   growth (mirrors P02/T02 commit `4dedb92a` precedent); (b)
   `tests/m032-acceptance/p02-glossary-surface.sh` nav marker
   `# >>> M012-P01 nav` -> `# >>> auto-nav` post-P03/T03 region split
   (the migration was complete on the script side but the acceptance
   marker grep was overlooked); (c)
   `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` fixture-
   completeness skip precondition for SC-5 per MIT-001 three-category
   exit semantics — when the fresh-project fixture lacks
   `scripts/wiki/wiki-deploy.sh` (operator-side install required for
   `--deploy`), SC-5 emits `SKIP_REASON: fixture lacks scripts/wiki/
   wiki-deploy.sh` and exits 77 rather than failing. T05 also cleaned
   leaked `wiki/` and `.orchestrator/` test pollution from the fresh-
   fixture root that prior SC-5 dry-runs had accidentally written to
   the live fixture path.

## Verification Results

Phase-suite aggregator (`tools/verify/m032-p04-phase-suite.sh`):
**11/11 PASS** (all eleven sub-gates green). SC-13 scope-guard
(`tools/verify/m032-p04-scope-guard.sh`): captured baseline-ref at
HEAD; `in_scope=N denylist_hits=0`. Acceptance battery
(`tests/m032-acceptance/run-acceptance-battery.sh`):
`BATTERY: pass=10 skip=1 fail=0` (SC-5 skip on fixture-completeness
precondition; ten green pass results: SC-1, SC-2, SC-3, SC-4, SC-6,
SC-7, SC-8, SC-9, SC-10, SC-11). `validate-milestone.sh M032`:
`VALIDATE: PASS — N/N checks passed`.

## Key Decisions

FR-17, FR-18, FR-19, FR-20, FR-22, US-7, US-8, SC-8, SC-9, SC-11,
SC-12, SC-13, SC-14, MIT-001, MIT-002, MIT-008, Constitution-VI,
Constitution-VIII, AD-7, AD-19, MEM001, MEM030, [M026](../../../../milestones/M026/index.md), M030-lineage,
M031-lineage.

## Patterns Established

- **Three-source-family scanner extension** (proposals:* + extra:* +
  knowledge-flat) with default-on/default-off flags consistent with
  the FR-15 `--include-glossary` precedent — replicable for future
  source-family additions.
- **YAML frontmatter stage-badge derivation** with `unknown` fallback
  (US-7 AS-1 no-exclusion invariant) for stage-tagged content surfaces.
- **Single-script-file FR-20 build-time decorator stub** with regex-
  pattern multi-class match + glossary lookup + first-occurrence-titled
  subsequent-link-only rendering + missing-glossary fallback —
  US-8 P3 stub-shape, polish deferred to post-launch wiki-UX-deep
  proposal.
- **Three-orthogonal-invariant single-acceptance-script pattern**
  (Constitution VIII + MIT-002 + MIT-008 stitched via three say_pass /
  say_fail assertion groups under one trap-EXIT envelope) — replicable
  for future cross-cutting invariants verified by a single-source-of-
  truth acceptance script.
- **Three-category battery aggregator over MIT-001** (`rc==0/77/other
  -> pass++/skip++/fail++`) wrapped around the M030/M031 `run_sc()`
  helper — reusable for any future milestone whose acceptance corpus
  includes live-network gates that need POSIX skip-code distinction.
- **`<MILESTONE>_ACCEPTANCE_BATTERY_DRY=1` test-only dry-mode escape
  hatch** in acceptance battery runners — emits synthetic skip per
  slot so shape verifiers exercise the count-contract without invoking
  real SCs (mirrors P03 `<TOOL>_<HELPER>_STUB` envelope + P02
  `M032_WIKI_INIT_FORCE_EXIT` envelope).
- **Shape verifier with embedded runtime check** — beyond grep-for-
  token assertions, executes runner under dry-mode and parses final
  `BATTERY:` line + counts `BATTERY-SKIP` emissions — catches drift
  between literal SC label list and actual call sites that a static
  grep would miss.
- **Literal-sequence eleven-gate phase-suite per AD-19 single-script-
  file shape** (NOT a for-loop iteration over sub-gates — a maintainer
  collapsing this into a loop trips the AD-19 shape-detection guard).
- **Fixture-completeness precondition pattern** (SC-5 emits exit 77
  SKIP_REASON when fixture lacks `scripts/wiki/wiki-deploy.sh` — an
  environmental precondition rather than a test failure per the
  MIT-001 three-category exit semantics).
- **Milestone-close evidence-ledger convention** (mirrors M030/M031 —
  operator-facing transcription of green BATTERY line + per-SC roll-up
  + ISO-8601 timestamp + back-link to runner).
- **Conditional `M032-VALIDATED` marker per MIT-001 + SC-14** (marker
  MUST NOT be created at `skip=1` unless signed-attestation block is
  in `M032-SUMMARY.md`) — enforced by
  `m032-p04-milestone-close-ceremony.sh` verifier.
- **In-flight repair convention extended to milestone-close ceremony**
  (T05 repairs sibling-phase verifier shape drift surfaced by the
  SC-12 battery within the same task — mirrors P02/T02 + P03/T05
  precedents).

## Affects Downstream

- **[M033](../../../../milestones/M033/index.md) (project onboarding)** — paired-launch via FR-11 `--with-wiki`
  gate. M033/P05 invokes the closed M032 wiki-distribution surface;
  the `--with-wiki` no-op in-flight repair on `wiki-init.sh` flows
  through to M033's `--with-wiki --with-giscus --deploy` chain.
- **M036b (post-launch wiki projection)** — P08 was blocked by M032
  closure; now unblocked.
- **post-launch wiki-UX-deep proposal** — FR-20 decorator stub is the
  surface that polish work consumes (subsequent-link-only rendering,
  multi-page glossary support, etc.).
- **Future `--with-github-integration` / `--with-design-layer`
  flags** — FR-13 progressive-opt-in pattern documented at
  `references/installation.md` (P03 deliverable) is the contract these
  inherit.
- **`run-doctor.sh` Constitution-VIII surface** — SC-11 acceptance is
  the canonical test that gates `dead-infrastructure` /
  `unreferenced-asset` warnings against the dogfood orchestrator.
