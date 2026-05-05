---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M033"
goal: "Land the M033 foundation surface — `commands/start.md` + `scripts/lifecycle/start.sh` with FR-2 deterministic branch detection (greenfield-empty / greenfield-with-materials / existing-codebase / migrating), idempotent `init-project.sh` invocation, per-branch sub-flow stubs that print `would-execute` diagnostics, the US-1 AS-5 disambiguation question for ambiguous signals, the MIT-006 / RISK-006 disambiguation extension for `git init`-only projects with ≤9 source files, the `references/branch-detection.md` SSOT, the friendly-tester protocol artifact + report template + mechanical `validate-report.sh` (FR-19 / SC-15 gate), the `tests/fixtures/m033-pbj-materials-fixture/` with exactly 5 curated CON-4-category inconsistencies + ground-truth README (FR-23 / MIT-003 / AD-5), the SC-1 + SC-8 acceptance scripts, and the `m033-p01-*` phase-suite + scope-guard verifiers."
demo_sentence: "An operator runs `bash scripts/lifecycle/start.sh --project-dir <fixture> --yes` against four branch-shape fixtures (greenfield-empty / greenfield-with-materials / existing-codebase / migrating) and observes (a) each fixture's intended branch detected via FR-2's deterministic ordered rules, (b) `init-project.sh` invoked exactly once (idempotent re-runs skipped per Edge Case `init already ran`), (c) the per-branch sub-flow stub printing its `would-execute: <sub-flow-name> --project-dir <fixture>` diagnostic on stdout, (d) exit code 0; runs against a fifth fixture with ambiguous signals (`package.json` + `.gsd/`) without `--yes` and observes the disambiguation question fire per US-1 AS-5; runs against a sixth fixture where `git init` has been run on an otherwise-empty project (≤9 source files, no prior-tooling artifacts) and observes the MIT-006 / RISK-006 disambiguation question offering `greenfield-empty` as the recommended branch; runs `bash tests/m033-acceptance/friendly-tester-pass/validate-report.sh tests/m033-acceptance/friendly-tester-pass/fixtures/report-pass.md` and observes exit 0; runs the same validator against `fixtures/report-fail.md` (frontmatter `friction_blockers: 1`) and observes non-zero exit + the blocker description echoed to stderr; reads `tests/fixtures/m033-pbj-materials-fixture/README.md` and finds all 5 inconsistencies enumerated by name + category + affected document pair (the SC-4 ground-truth oracle); runs `bash tests/m033-acceptance/p01-start-branch-routing.sh` (SC-1) and `bash tests/m033-acceptance/p07-friendly-tester-protocol.sh` (SC-8) and observes exit 0 from each; runs `bash tools/verify/m033-p01-phase-suite.sh` and observes `SUMMARY: m033-p01-phase-suite.sh pass=N fail=0`."
risk: "high"
depends_on: []
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m033-p01-*` prefix avoids collision with M030/M031/M032
     existing `m###-p##-*` verifiers in the shared tools/verify/ tree
     (per the milestone-slug-required convention; phase-only `p##-*`
     names silently clobbered prior milestones — M030 lost to M031, etc.). -->

### Truths

- `commands/start.md` exists in the canonical command-document shape (YAML frontmatter with `description:`; Title; Prerequisites / State Check; Core Workflow; Output; Idempotency; Error Handling; Referenced Scripts/Templates per MEM012). The `description:` frontmatter advertises `orchestrator:start` as the warm conversational front door for any new orchestrator-managed project. The Referenced Scripts section names `scripts/lifecycle/start.sh`, `scripts/lifecycle/init-project.sh`, and `references/branch-detection.md`.
  - Check: `bash tools/verify/m033-p01-start-md-shape.sh`

- `scripts/lifecycle/start.sh` exists and is executable. It accepts `--project-dir <path>` (default `pwd`), `--yes` (auto-accept defaults), `--branch <branch>` (operator override of detection — `greenfield-empty | greenfield-with-materials | existing-codebase | migrating`), `--stack <stack>` (optional; recommendation is derived at sub-flow time per FR-1 / MIT-004; P01 only forwards the flag — sub-flow stubs do not consume it), and `--dry-run`. Unknown flags exit non-zero with a usage diagnostic naming the unknown flag. The script invokes `bash scripts/lifecycle/init-project.sh --project-dir <path>` exactly once per invocation; if `<path>/.orchestrator/config.yml` already exists, init invocation is skipped and a `init already complete, proceeding to branch sub-flow` diagnostic is emitted (Edge Case `init already ran`).
  - Check: `bash tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh`

- `scripts/lifecycle/start.sh` implements FR-2's deterministic branch-detection rules in this strict order, against `<project-dir>` as the probe target: (1) `.gsd/` OR `.gsd2/` OR `.specify/` artifact present → `migrating`; (2) ≥3 project-root `.md` files matching `*BRIEF*.md|*PLAN*.md|*DECISIONS*.md|*HANDOFF*.md|*AUDIT*.md` AND no `src/` directory → `greenfield-with-materials`; (3) `src/` directory present OR ≥10 source files at project root (extensions `.js|.ts|.jsx|.tsx|.py|.rs|.go|.rb|.java|.kt|.swift|.cs|.cpp|.c|.h`) OR `.git/` with ≥1 commit → `existing-codebase`; (4) otherwise → `greenfield-empty`. Detection order is non-negotiable — rule 1 fires before rule 3 even when both match (per US-1 AS-4 — `migrating` always wins over `existing-codebase`). The detected branch is printed to stdout as `branch: <name>` before sub-flow dispatch. Operator-supplied `--branch <name>` skips detection entirely (override is silent — no warning unless detection would have produced a different name, in which case a `branch-override: detected=<X> overridden=<Y>` diagnostic is emitted to stderr).
  - Check: `bash tools/verify/m033-p01-branch-detection-rules.sh`

- The four per-branch sub-flow stubs are dispatched by `start.sh` after init completes. Each stub is a small function (or sourced helper) that prints `would-execute: <sub-flow-name> --project-dir <project-dir>` to stdout and exits 0 without performing real sub-flow work. The four stub names are `ideation-stub`, `materials-intake-stub`, `ingest-codebase-stub`, `migrate-routing-stub`, mapped 1:1 from the four branch names. The stubs are deliberately vacuous in P01 — they ship as the FR-1 dispatch surface that P02..P05 fills with real sub-flow logic. Stub output is line-prefixed with `would-execute:` (literal, lowercase, colon-terminated) so SC-1's regex assertions match across all four branches uniformly.
  - Check: `bash tools/verify/m033-p01-subflow-stubs-shape.sh`

- The US-1 AS-5 disambiguation question fires when (a) running without `--yes`, AND (b) detection rules produce ambiguous signals. The two ambiguous-signal cases supported in P01 are: (i) rule-1 + rule-3 both match (e.g., `package.json` + `src/` + `.gsd/v1-roadmap.yml` — could be `migrating` or `existing-codebase`), AND (ii) rule-3 fires solely because `.git/` has ≥1 commit but the project has ≤9 source files AND no prior-tooling artifacts (the MIT-006 / RISK-006 case — recommended branch is `greenfield-empty`, detected branch by rule-3 is `existing-codebase`). The question follows the grilling-protocol shape (sequential, recommendation-named-first, one-keystroke accept). Question text MUST: (a) name the detected branch, (b) name the recommended branch, (c) name a one-line reason for the disambiguation (e.g., `git history present but only N source files — likely a fresh project where you ran git init`), (d) accept Y/y/<enter> for the recommended branch, n/N for the detected branch, or any other key for explicit `--branch <name>` re-invocation. Under `--yes`, case (i) auto-accepts the recommended (rule-1 wins per ordering); case (ii) auto-accepts the detected (rule-3 fires as documented; the `--branch greenfield-empty` override is the explicit correction path per FR-2's MIT-006 note).
  - Check: `bash tools/verify/m033-p01-disambiguation-question-shape.sh`

- `references/branch-detection.md` exists as the SSOT for the regex/glob patterns used by FR-2. It documents: (a) the four branch names and the ordered detection rules; (b) the literal regex/glob patterns used at each rule (project-root markdown glob, source-file extension list, prior-tooling-artifact paths); (c) the ambiguity cases (i) + (ii) with example fixtures; (d) the rationale for the ordered-rule design (rule-1 is provenance — explicit prior tooling; rule-2 is structural — content-only project; rule-3 is structural — code-bearing project; rule-4 is the fallback); (e) the `--branch` override contract; (f) cross-references to the FR-2 / MIT-006 / RISK-006 / AD-4 spec entries. The file is the input that P02..P05 sub-flow phases consume when they extend detection (e.g., P03 may add a rule-3 sub-classification by language). The patterns documented here MUST byte-match the patterns implemented in `start.sh` (cross-checked by the verifier).
  - Check: `bash tools/verify/m033-p01-branch-detection-ssot-parity.sh`

- `tests/m033-acceptance/friendly-tester-pass/protocol.md` exists and documents (FR-19): (a) a tester-eligibility checklist with a `not_familiar_with_orchestrator: yes/no` self-attestation field (per Edge Case `Friendly-tester pass run by a tester who is too close`); (b) per-branch pre-conditions for all four branches (greenfield-empty / greenfield-with-materials / existing-codebase / migrating); (c) a 30-minute walkthrough script per branch with concrete invocation lines (`bash scripts/lifecycle/start.sh --project-dir <fixture-path>`) and expected observation prompts (where to look, what should appear, what to capture if surprised); (d) a friction-capture template covering "where they got stuck", "where they re-read", "where they bounced". The file is a markdown document, not an executable script — its existence + section presence is the FR-19 contract.
  - Check: `bash tools/verify/m033-p01-friendly-tester-protocol-shape.sh`

- `tests/m033-acceptance/friendly-tester-pass/report-template.md` exists with YAML frontmatter defining the load-bearing fields: `friction_blockers:` (integer, default 0), `friction_warnings:` (integer, default 0), `eligible_testers:` (integer, default 0), `tester_attestations:` (list of `{tester_id, not_familiar_with_orchestrator: yes|no}` records), `tested_branches:` (list of branch names actually walked), `report_date:` (ISO 8601 date). Body sections cover one-section-per-walked-branch with the captured friction notes verbatim.
  - Check: `bash tools/verify/m033-p01-report-template-shape.sh`

- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` exists, is executable, and implements the SC-15 mechanical gate per US-8 AS-3. The script accepts a single positional argument (path to a filled report). It exits 0 iff the report's frontmatter shows `friction_blockers: 0` AND `eligible_testers >= 1` (per SC-15's `single-tester signal accepted` clause). It exits non-zero with a stderr diagnostic in any of these cases: (a) `friction_blockers > 0` — prints the per-branch friction-blocker descriptions verbatim from the report body; (b) `eligible_testers < 1` — prints `no eligible testers — recruit ≥1 outsider per SC-15` and exits non-zero; (c) any tester in `tester_attestations:` shows `not_familiar_with_orchestrator: no` — that tester is excluded from the `eligible_testers` count, and a stderr warning names them; (d) the report file does not exist — prints `friendly-tester pass not run — milestone close blocked` per US-8 AS-5 and exits non-zero. The SC-15 escalation path (`M033_SKIP_FRIENDLY_TESTER_PASS=1` in `M033-SUMMARY.md` with signed attestation) is checked by `validate-milestone.sh` (M032/M030 closed pattern), NOT by `validate-report.sh` — `validate-report.sh` is purely the per-report verifier.
  - Check: `bash tools/verify/m033-p01-validate-report-sh-contract.sh`

- `tests/m033-acceptance/friendly-tester-pass/fixtures/report-pass.md` AND `tests/m033-acceptance/friendly-tester-pass/fixtures/report-fail.md` exist as test fixtures for `validate-report.sh`. `report-pass.md` carries `friction_blockers: 0` + `eligible_testers: 1` + one valid tester attestation; `validate-report.sh fixtures/report-pass.md` exits 0. `report-fail.md` carries `friction_blockers: 1` with one named blocker in the body; `validate-report.sh fixtures/report-fail.md` exits non-zero with the blocker text echoed to stderr. These fixtures power SC-8's mechanical assertion that the validator gate is real.
  - Check: `bash tools/verify/m033-p01-validate-report-fixtures-shape.sh`

- `tests/fixtures/m033-pbj-materials-fixture/` exists as a self-contained synthetic-PBJ-shape fixture (FR-23 / MIT-003 / AD-5). The fixture contains exactly 4 materials documents (`PRODUCT-BRIEF.md`, `MVP-PLAN.md`, `DECISIONS.md`, `MILESTONE-AUDIT.md` — the named PBJ shape per the spec) and exactly 5 curated inconsistencies covering at minimum one instance per CON-4 detection category: (1) one ID-misalignment inconsistency (e.g., `PRODUCT-BRIEF.md` references `US-3` while `MVP-PLAN.md` defines only `US-1` and `US-2`); (2) one scheme-contradiction inconsistency (e.g., `DECISIONS.md` says "deploy via Vercel" while `MVP-PLAN.md` says "deploy via Cloudflare Workers"); (3) one orphan-reference inconsistency (e.g., `MILESTONE-AUDIT.md` mentions a milestone `M-X` that no other document defines); the remaining 2 inconsistencies are additional instances of these categories chosen to stress the deterministic-not-LLM detector. The fixture contains NO source files, NO `.git/`, NO prior-tooling artifacts — it is purely the materials-intake input shape, so US-1's branch-detection on this fixture (after copying into a probe target) reaches rule-2 (`greenfield-with-materials`) cleanly.
  - Check: `bash tools/verify/m033-p01-pbj-fixture-shape.sh`

- `tests/fixtures/m033-pbj-materials-fixture/README.md` exists and is the SC-4 ground-truth oracle. It enumerates all 5 inconsistencies as a numbered list, each entry naming: (a) the CON-4 category (`id-misalignment | scheme-contradiction | orphan-reference`), (b) the affected document pair (e.g., `PRODUCT-BRIEF.md` ↔ `MVP-PLAN.md`), (c) the inconsistency description (one to two sentences). The README also documents (d) the fixture's intended use in P04's `p04-materials-intake.sh` (SC-4), (e) the deterministic-output guarantee (same fixture + same operator answers → same detection output across platforms and operator identities, per FR-23), (f) the consumer phases (P04 SC-4 reads ground-truth from this README to verify "exactly 5 conflicts surfaced"). The README format is consumed by P04's verifier mechanically — the numbered list shape MUST be parseable line-by-line so `p04-materials-intake.sh` can compare detector output to oracle output.
  - Check: `bash tools/verify/m033-p01-pbj-fixture-readme-oracle.sh`

- `tests/m033-acceptance/p01-start-branch-routing.sh` exists, is executable, and exits 0 (SC-1). The script: (a) creates six test-staging directories under `mktemp -d` — fixture-1 (greenfield-empty: empty dir), fixture-2 (greenfield-with-materials: 3 PBJ-shape `.md` files, no `src/`), fixture-3 (existing-codebase: `package.json` + populated `src/` + `.git/` with ≥1 commit), fixture-4 (migrating: `.gsd/v1-roadmap.yml`), fixture-5 (ambiguous: `package.json` + `src/` + `.gsd/v1-roadmap.yml`), fixture-6 (MIT-006 / RISK-006: `.git/` with ≥1 commit + 3 source files + no prior-tooling artifacts); (b) runs `bash scripts/lifecycle/start.sh --project-dir <fixture-N> --yes` against fixtures 1–4 and asserts the `branch: <expected>` line appears, asserts `init-project.sh` was invoked exactly once (greppable diagnostic in stdout), asserts the corresponding `would-execute: <sub-flow>-stub` diagnostic appears, asserts exit 0; (c) runs `start --project-dir fixture-5` WITHOUT `--yes` against simulated stdin (`printf 'y\n'`) and asserts the disambiguation question fires (regex match on the question text), asserts the resolved branch follows the recommended; (d) runs `start --project-dir fixture-6` WITHOUT `--yes` against simulated stdin (`printf 'y\n'`) and asserts the MIT-006 / RISK-006 disambiguation question fires offering `greenfield-empty` as the recommended branch; (e) re-runs `start --project-dir <fixture-1>` against the same fixture and asserts `init already complete` diagnostic AND `init-project.sh` was NOT invoked the second time (the idempotency assertion). Cleanup: `rm -rf` of all staging dirs is mandatory.
  - Check: `bash tools/verify/m033-p01-acceptance-shape-sc1.sh`

- `tests/m033-acceptance/p07-friendly-tester-protocol.sh` exists, is executable, and exits 0 (SC-8). The script asserts: (a) `tests/m033-acceptance/friendly-tester-pass/protocol.md` exists with the four documented sections (one per branch) AND the tester-eligibility checklist; (b) `tests/m033-acceptance/friendly-tester-pass/report-template.md` exists with the `friction_blockers:` and `eligible_testers:` frontmatter fields defined; (c) `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` is executable; (d) `validate-report.sh fixtures/report-pass.md` exits 0; (e) `validate-report.sh fixtures/report-fail.md` exits non-zero AND the stderr contains the blocker description from the report body. The script does NOT assert that any real friendly-tester pass has been run — that is SC-15's gate, fired at milestone close (P05).
  - Check: `bash tools/verify/m033-p01-acceptance-shape-sc8.sh`

- `tools/verify/m033-p01-phase-suite.sh` exists, is executable, invokes every P01 verifier in dependency order, exits 0 iff every sub-gate passes, and emits a single line `SUMMARY: m033-p01-phase-suite.sh pass=N fail=M` before exit. The suite chains, in order: `m033-p01-pbj-fixture-shape.sh`, `m033-p01-pbj-fixture-readme-oracle.sh`, `m033-p01-branch-detection-ssot-parity.sh`, `m033-p01-start-md-shape.sh`, `m033-p01-start-sh-flags-and-init-invocation.sh`, `m033-p01-branch-detection-rules.sh`, `m033-p01-subflow-stubs-shape.sh`, `m033-p01-disambiguation-question-shape.sh`, `m033-p01-friendly-tester-protocol-shape.sh`, `m033-p01-report-template-shape.sh`, `m033-p01-validate-report-sh-contract.sh`, `m033-p01-validate-report-fixtures-shape.sh`, `m033-p01-acceptance-shape-sc1.sh`, `m033-p01-acceptance-shape-sc8.sh`. Fourteen sub-gates plus the suite line.
  - Check: `bash tools/verify/m033-p01-phase-suite.sh`

- The SC-13 / scope-guard invariant holds for the P01 diff: P01 modifies/creates only files declared in this phase's "Files Likely Touched" list. None of `scripts/lifecycle/grilling-shell.sh`, `scripts/lifecycle/constitution-author.sh`, `scripts/lifecycle/ingest-codebase.sh`, `scripts/lifecycle/materials-intake.sh`, `scripts/lifecycle/ideation.sh`, `scripts/lifecycle/customblock-draft.sh`, `templates/constitution-starters/**`, `wiki/**`, or any sub-flow real-implementation file is touched (those belong to P02–P05). The `tests/paired-m032-m033/` directory is NOT a P01 deliverable.
  - Check: `bash tools/verify/m033-p01-scope-guard.sh`

### Artifacts

- `commands/start.md` (min 80 lines, contains "orchestrator:start", contains "warm conversational front door", contains "scripts/lifecycle/start.sh", contains "references/branch-detection.md", contains "init-project.sh") — create
- `scripts/lifecycle/start.sh` (min 200 lines, contains "--project-dir", contains "--yes", contains "--branch", contains "--stack", contains "--dry-run", contains "branch:", contains "would-execute:", contains "init already complete", contains "init-project.sh") — create
- `references/branch-detection.md` (min 90 lines, contains "greenfield-empty", contains "greenfield-with-materials", contains "existing-codebase", contains "migrating", contains "FR-2", contains "MIT-006", contains "RISK-006", contains "--branch") — create
- `tests/m033-acceptance/friendly-tester-pass/protocol.md` (min 100 lines, contains "tester-eligibility", contains "not_familiar_with_orchestrator", contains "greenfield-empty", contains "greenfield-with-materials", contains "existing-codebase", contains "migrating", contains "30-minute", contains "friction") — create
- `tests/m033-acceptance/friendly-tester-pass/report-template.md` (min 40 lines, contains "friction_blockers:", contains "friction_warnings:", contains "eligible_testers:", contains "tester_attestations:", contains "tested_branches:", contains "report_date:") — create
- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` (min 70 lines, contains "friction_blockers", contains "eligible_testers", contains "not_familiar_with_orchestrator", contains "milestone close blocked") — create
- `tests/m033-acceptance/friendly-tester-pass/fixtures/report-pass.md` (min 15 lines, contains "friction_blockers: 0", contains "eligible_testers: 1") — create
- `tests/m033-acceptance/friendly-tester-pass/fixtures/report-fail.md` (min 15 lines, contains "friction_blockers: 1") — create
- `tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md` (min 25 lines, contains "## Problem", contains "## Target User", contains "US-") — create
- `tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md` (min 25 lines, contains "## User Stories", contains "US-") — create
- `tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md` (min 20 lines, contains "DR-") — create
- `tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md` (min 20 lines, contains "M-") — create
- `tests/fixtures/m033-pbj-materials-fixture/README.md` (min 60 lines, contains "id-misalignment", contains "scheme-contradiction", contains "orphan-reference", contains "ground-truth", contains "1.", contains "2.", contains "3.", contains "4.", contains "5.") — create
- `tests/m033-acceptance/p01-start-branch-routing.sh` (min 120 lines, contains "SC-1", contains "FR-1", contains "FR-2", contains "greenfield-empty", contains "greenfield-with-materials", contains "existing-codebase", contains "migrating", contains "MIT-006", contains "init already complete") — create
- `tests/m033-acceptance/p07-friendly-tester-protocol.sh` (min 60 lines, contains "SC-8", contains "FR-19", contains "validate-report.sh", contains "report-pass.md", contains "report-fail.md") — create
- `tools/verify/m033-p01-start-md-shape.sh` (min 25 lines, contains "commands/start.md", contains "orchestrator:start", contains "scripts/lifecycle/start.sh") — create
- `tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh` (min 30 lines, contains "scripts/lifecycle/start.sh", contains "--project-dir", contains "--yes", contains "--branch", contains "init-project.sh") — create
- `tools/verify/m033-p01-branch-detection-rules.sh` (min 30 lines, contains "greenfield-empty", contains "greenfield-with-materials", contains "existing-codebase", contains "migrating", contains "FR-2") — create
- `tools/verify/m033-p01-subflow-stubs-shape.sh` (min 25 lines, contains "would-execute:", contains "ideation-stub", contains "materials-intake-stub", contains "ingest-codebase-stub", contains "migrate-routing-stub") — create
- `tools/verify/m033-p01-disambiguation-question-shape.sh` (min 25 lines, contains "AS-5", contains "MIT-006", contains "recommendation", contains "scripts/lifecycle/start.sh") — create
- `tools/verify/m033-p01-branch-detection-ssot-parity.sh` (min 30 lines, contains "references/branch-detection.md", contains "scripts/lifecycle/start.sh") — create
- `tools/verify/m033-p01-friendly-tester-protocol-shape.sh` (min 25 lines, contains "protocol.md", contains "tester-eligibility", contains "30-minute") — create
- `tools/verify/m033-p01-report-template-shape.sh` (min 25 lines, contains "report-template.md", contains "friction_blockers", contains "eligible_testers") — create
- `tools/verify/m033-p01-validate-report-sh-contract.sh` (min 30 lines, contains "validate-report.sh", contains "friction_blockers", contains "eligible_testers", contains "not_familiar_with_orchestrator") — create
- `tools/verify/m033-p01-validate-report-fixtures-shape.sh` (min 25 lines, contains "report-pass.md", contains "report-fail.md") — create
- `tools/verify/m033-p01-pbj-fixture-shape.sh` (min 25 lines, contains "m033-pbj-materials-fixture", contains "PRODUCT-BRIEF.md", contains "MVP-PLAN.md", contains "DECISIONS.md", contains "MILESTONE-AUDIT.md") — create
- `tools/verify/m033-p01-pbj-fixture-readme-oracle.sh` (min 25 lines, contains "README.md", contains "id-misalignment", contains "scheme-contradiction", contains "orphan-reference") — create
- `tools/verify/m033-p01-acceptance-shape-sc1.sh` (min 25 lines, contains "p01-start-branch-routing.sh", contains "SC-1") — create
- `tools/verify/m033-p01-acceptance-shape-sc8.sh` (min 25 lines, contains "p07-friendly-tester-protocol.sh", contains "SC-8") — create
- `tools/verify/m033-p01-phase-suite.sh` (min 60 lines, contains "SUMMARY:", contains "m033-p01-pbj-fixture-shape", contains "m033-p01-branch-detection-rules", contains "m033-p01-acceptance-shape-sc1", contains "m033-p01-acceptance-shape-sc8", contains "m033-p01-phase-suite") — create
- `tools/verify/m033-p01-scope-guard.sh` (min 35 lines, contains "scripts/lifecycle/grilling-shell.sh", contains "scripts/lifecycle/constitution-author.sh", contains "templates/constitution-starters", contains "wiki/", contains "tests/paired-m032-m033", contains "SC-13") — create

### Key Links

- `commands/start.md` → `scripts/lifecycle/start.sh` (Referenced Scripts section names the start.sh driver per MEM012)
- `commands/start.md` → `references/branch-detection.md` (Referenced Scripts/Templates section names the SSOT)
- `scripts/lifecycle/start.sh` → `scripts/lifecycle/init-project.sh` (FR-1 — start invokes init exactly once)
- `scripts/lifecycle/start.sh` → `references/branch-detection.md` (FR-2 — header comment cross-references the SSOT for the regex/glob patterns)
- `references/branch-detection.md` → `scripts/lifecycle/start.sh` (the SSOT names the implementing script for round-trip auditability)
- `tests/m033-acceptance/friendly-tester-pass/protocol.md` → `tests/m033-acceptance/friendly-tester-pass/report-template.md` (protocol points testers at the report template)
- `tests/m033-acceptance/friendly-tester-pass/protocol.md` → `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` (protocol documents the mechanical gate that consumes the filled report)
- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` → `tests/m033-acceptance/friendly-tester-pass/report-template.md` (validator reads the template-defined frontmatter fields)
- `tests/fixtures/m033-pbj-materials-fixture/README.md` → `tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md` (oracle names the affected document pair)
- `tests/fixtures/m033-pbj-materials-fixture/README.md` → `tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md` (oracle names the affected document pair)
- `tests/m033-acceptance/p01-start-branch-routing.sh` → `scripts/lifecycle/start.sh` (SC-1 invokes start.sh against six fixtures)
- `tests/m033-acceptance/p07-friendly-tester-protocol.sh` → `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` (SC-8 invokes the validator against the two report fixtures)
- `tools/verify/m033-p01-phase-suite.sh` → `tools/verify/m033-p01-acceptance-shape-sc1.sh` (suite chains the SC-1 wrapper)
- `tools/verify/m033-p01-phase-suite.sh` → `tools/verify/m033-p01-acceptance-shape-sc8.sh` (suite chains the SC-8 wrapper)

## Tasks

### T01: PBJ acceptance fixture + ground-truth README (FR-23 / MIT-003 / AD-5)

See `tasks/T01-pbj-fixture-and-oracle-PLAN.md`.

### T02: `references/branch-detection.md` SSOT + parity verifier scaffold

See `tasks/T02-branch-detection-ssot-PLAN.md`.

### T03: `commands/start.md` + `scripts/lifecycle/start.sh` skeleton + sub-flow stubs + disambiguation question

See `tasks/T03-start-command-and-driver-PLAN.md`.

### T04: Friendly-tester pass artifacts + `validate-report.sh` + report fixtures (FR-19 / SC-15 gate)

See `tasks/T04-friendly-tester-pass-artifacts-PLAN.md`.

### T05: SC-1 + SC-8 acceptance scripts + `m033-p01-*` phase-suite + scope-guard verifiers

See `tasks/T05-acceptance-suite-and-phase-suite-PLAN.md`.

## Task Dependencies

```
T01 ──┐
T02 ──┼──► T03 ──► T05
T04 ──┘
```

T01 (PBJ fixture) and T02 (branch-detection SSOT) and T04 (friendly-tester artifacts) have no inter-task dependencies and can run in parallel. T03 depends on T01 (fixture used by start.sh's branch-detection self-test in dev-loop iteration), T02 (SSOT must exist before start.sh can cross-reference it). T05 (acceptance suite + phase-suite) depends on T01 + T02 + T03 + T04 because the SC-1 acceptance script needs `start.sh` and the six fixture shapes, and the SC-8 acceptance script needs the friendly-tester artifacts. The `m033-p01-phase-suite.sh` aggregator chains all 14 P01 verifiers, so it must be last.

## Files Likely Touched

- `commands/start.md` (create)
- `scripts/lifecycle/start.sh` (create)
- `references/branch-detection.md` (create)
- `tests/m033-acceptance/friendly-tester-pass/protocol.md` (create)
- `tests/m033-acceptance/friendly-tester-pass/report-template.md` (create)
- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` (create)
- `tests/m033-acceptance/friendly-tester-pass/fixtures/report-pass.md` (create)
- `tests/m033-acceptance/friendly-tester-pass/fixtures/report-fail.md` (create)
- `tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md` (create)
- `tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md` (create)
- `tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md` (create)
- `tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md` (create)
- `tests/fixtures/m033-pbj-materials-fixture/README.md` (create)
- `tests/m033-acceptance/p01-start-branch-routing.sh` (create)
- `tests/m033-acceptance/p07-friendly-tester-protocol.sh` (create)
- `tools/verify/m033-p01-start-md-shape.sh` (create)
- `tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh` (create)
- `tools/verify/m033-p01-branch-detection-rules.sh` (create)
- `tools/verify/m033-p01-subflow-stubs-shape.sh` (create)
- `tools/verify/m033-p01-disambiguation-question-shape.sh` (create)
- `tools/verify/m033-p01-branch-detection-ssot-parity.sh` (create)
- `tools/verify/m033-p01-friendly-tester-protocol-shape.sh` (create)
- `tools/verify/m033-p01-report-template-shape.sh` (create)
- `tools/verify/m033-p01-validate-report-sh-contract.sh` (create)
- `tools/verify/m033-p01-validate-report-fixtures-shape.sh` (create)
- `tools/verify/m033-p01-pbj-fixture-shape.sh` (create)
- `tools/verify/m033-p01-pbj-fixture-readme-oracle.sh` (create)
- `tools/verify/m033-p01-acceptance-shape-sc1.sh` (create)
- `tools/verify/m033-p01-acceptance-shape-sc8.sh` (create)
- `tools/verify/m033-p01-phase-suite.sh` (create)
- `tools/verify/m033-p01-scope-guard.sh` (create)
