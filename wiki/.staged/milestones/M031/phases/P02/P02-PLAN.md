---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M031"
goal: "Ship the Tier A+ middle flow: extend the M024 shape classifier additively with a `tier_a_plus` verdict (FR-6) and ground it in `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` (AD-16); ship a deterministic task-slug derivation library producing `<40-char-lower-hyphen-alnum>[-<sha1-4>]` paths under `.orchestrator/tier-a-plus/<slug>/{research,plan}.md` (AD-10); ship three prescriptive role templates `templates/dispatch-role-{research,plan,build}.md` (FR-8); ship the AD-7 + AD-20 Tier A+ approval prompt — plain-language framing, inline N-line research summary read from `tier_a_plus_prompt_summary_lines` (P00 default 8), three named single-keystroke options (`y`/`n`/`c`), `(N more lines at <path>)` ellipsis, resume-vs-rerun visibility against existing `research.md`, `--yes` skip with `research: <path>` stderr audit line; amend `scripts/intake/route-to-dispatch.sh` to recognize `tier_a_plus` and chain three sequential P01-Quick-profile dispatches (research → operator prompt → plan → build) with JSONL `unit_close` schema additions for `tier_a_plus_role` (`research|plan|build`) and `aborted` flag (FR-7); ship the SC-5 / SC-6 / SC-16 acceptance tests under `tests/m031-acceptance/`; aggregate every P02 sub-gate via `tools/verify/m031-p02-phase-suite.sh` and enforce the SC-12 block-list per the M031 P01 carve-out pattern via `tools/verify/m031-p02-scope-guard.sh`."
demo_sentence: "An operator runs `bash scripts/intake/shape-detect.sh --input \"$(cat tests/m031-acceptance/fixtures/tier-a-plus-input.txt)\"` and observes stdout containing `input_shape=tier_a_plus`; runs `bash tests/m031-acceptance/test-tier-a-plus-classifier.sh` (SC-5) and observes exit 0; runs `bash tests/m031-acceptance/test-tier-a-plus-flow.sh --yes --task \"add a flag to script X with three tests and a doc update\"` (SC-6) and observes exactly three sequential dispatches firing with role payloads `research`, `plan`, `build`, deterministic outputs at `.orchestrator/tier-a-plus/add-a-flag-to-script-x-with-three-tests-an/research.md` and `.../plan.md`, zero approval prompts (because of `--yes`), one `research: <path>` audit line on stderr, no `.orchestrator/milestones/M###/` scaffolding created, and no auto-loop lock acquired; runs `bash tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh` (SC-16 / AD-20) and observes exit 0 — captured stdout/stderr include the inline 8-line research summary, the three named options `y`/`n`/`c`, the `(N more lines at <path>)` ellipsis when research exceeds the inline budget, and plain-language framing (no `null`, no JSON braces, no scaffold-placeholder marker bracket-TODO patterns); runs `bash tools/verify/m031-p02-phase-suite.sh` and observes a single `SUMMARY: m031-p02-phase-suite.sh pass=N fail=0` line; runs `bash tools/verify/m031-p02-scope-guard.sh` and observes `SUMMARY: m031-p02-scope-guard.sh pass=N fail=0 block_list_violations=0`."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m031-p02-*` prefix avoids collision with [M030](../../../../milestones/M030/index.md)'s
     existing `p02-*` verifiers in the shared tools/verify/ tree. -->

### Truths

- `scripts/intake/shape-detect.sh` and `scripts/intake/paragraph-classify.sh` accept the [M024](../../../../milestones/M024/index.md) input surface unchanged AND emit a fourth verdict value `tier_a_plus` (additive to the existing `idea | paragraph | fragment | spec | empty` enum, AD-2 / CON-3). The Tier A+ heuristic boundary is documented inline in each classifier's body and grounded by `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` per AD-16. Word-count and structural-marker heuristics for the existing four verdicts MUST stay byte-equal (no regression on M024 fixtures).
  - Check: `bash tools/verify/m031-p02-classifier-extension-shape.sh`

- `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` exists with at least one historical `.orchestrator/` JSONL `unit_close` record cited by `<milestone>/<phase>/<task>` provenance, plus the annotator's classification rationale for why the cited record is a Tier A+ candidate (AD-16). The file is normative — no Tier A+ verifier may pass without its existence.
  - Check: `bash tools/verify/m031-p02-fixture-provenance-shape.sh`

- `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` exists with a 30–80 word feature-request fixture matching the Tier A+ heuristic (input the classifier classifies as `tier_a_plus` with high confidence). The fixture body is keyed to the `FIXTURE-PROVENANCE.md` rationale (a paraphrase of one of the cited historical records).
  - Check: `bash tools/verify/m031-p02-tier-a-plus-input-shape.sh`

- `scripts/intake/lib/task-slug.sh` (or sibling-symmetric helper under `scripts/intake/`) exists and exposes a `derive_task_slug <task-description>` function returning `<40-char-lower-hyphen-alnum>[-<sha1-4>]`. The 4-character SHA-1 collision suffix is appended ONLY when an output directory `.orchestrator/tier-a-plus/<base-slug>/` already exists with content for a different task description (AD-10 collision discipline). Bash 3.2-compatible.
  - Check: `bash tools/verify/m031-p02-task-slug-shape.sh`

- `templates/dispatch-role-research.md`, `templates/dispatch-role-plan.md`, and `templates/dispatch-role-build.md` exist with YAML frontmatter (`schema_version: "1.0"`, `type: dispatch-role`, `role: <research|plan|build>`) and a prescriptive body declaring (a) the exact output shape (research = N findings; plan = single PLAN.md with explicit Steps + Verification + Inputs + Files Likely Touched; build = execute the plan and run inline verifiers), (b) the per-role dispatch-payload requirements (each role consumes the P01 `--profile=quick` Quick-profile knowledge inject + `--meta-out` sidecar by default), and (c) the role-output-path convention `.orchestrator/tier-a-plus/<task-slug>/<role>.md` (research and plan; build emits no per-role file beyond the dispatched edits) per AD-10.
  - Check: `bash tools/verify/m031-p02-role-templates-shape.sh`

- `scripts/intake/lib/tier-a-plus-prompt.sh` (or sibling-symmetric helper) exists and implements the AD-7 + AD-20 prompt protocol: (a) plain-language framing (no `null`, no `{` or `}` JSON-brace tokens in the prompt body, no scaffold-placeholder marker bracket-TODO byte pattern); (b) inline first-N-lines summary of `research.md` where N = `tier_a_plus_prompt_summary_lines` from active config (P00 default 8); (c) three named options `(y) plan against this research / (n) re-run research with different framing / (c) abort this Tier A+ flow` with single-keystroke responses and `default-on-no-answer = c`; (d) `(N more lines at <path>)` ellipsis when research.md exceeds the inline budget; (e) resume-vs-rerun marker distinguishing pre-existing research from current-session research; (f) `--yes` skip path emits one `research: <path>` line on stderr instead of the interactive prompt; (g) the prompt MUST emit the research findings path on stdout (or stderr) regardless of mode so the operator audit trail exists.
  - Check: `bash tools/verify/m031-p02-prompt-shape.sh`

- `scripts/intake/route-to-dispatch.sh` recognizes a `tier_a_plus` verdict and chains exactly three sequential dispatches (research → operator-prompt-gate → plan → build), each invoking the existing dispatch surface with the corresponding `templates/dispatch-role-<role>.md` payload and `--profile=quick` (Tier A+ research and build default to Quick per the P01 reconciled `commands/dispatch.md`). The router MUST NOT invoke `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate`. The router MUST NOT acquire any auto-loop lock or write any `.orchestrator/milestones/M###/` scaffolding (CON-4 / DC-4). On operator-cancel at the prompt OR on inline build-verifier failure, the router exits non-zero and writes a `unit_close` record with `aborted: true`. Each of the three dispatches emits one `unit_close` record carrying `tier_a_plus_role: <research|plan|build>` and `aborted: <true|false>`.
  - Check: `bash tools/verify/m031-p02-router-shape.sh`

- `tests/m031-acceptance/test-tier-a-plus-classifier.sh` (SC-5) exists, is executable, and exits 0. Asserts: `bash scripts/intake/shape-detect.sh --input "$(cat tests/m031-acceptance/fixtures/tier-a-plus-input.txt)"` produces stdout containing the literal token `tier_a_plus`; `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` exists with at least one JSONL provenance line (AD-16 grounding); the existing four classifier verdict outputs (idea / paragraph / fragment / spec / empty) on M024 regression fixtures remain byte-equal pre/post.
  - Check: `bash tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh`

- `tests/m031-acceptance/test-tier-a-plus-flow.sh` (SC-6) exists, is executable, and exits 0. Asserts: invoking the router against a `tier_a_plus` verdict produces exactly three dispatches with role payloads research / plan / build (verified by counting `tier_a_plus_role:` keys in the captured `unit_close` JSONL); creates exactly two output files at `.orchestrator/tier-a-plus/<task-slug>/research.md` and `.orchestrator/tier-a-plus/<task-slug>/plan.md`; creates ZERO files under `.orchestrator/milestones/`; ZERO auto-loop lock files written under any path matching `*lock*`; under `--yes` mode emits ZERO interactive prompts and exactly one `research: <path>` stderr line; under interactive mode emits exactly ONE prompt before the plan dispatch fires.
  - Check: `bash tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh`

- `tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh` (SC-16 per AD-20) exists, is executable, and exits 0. Asserts: captured stdout/stderr from a Tier A+ flow with a fixture `research.md` longer than `tier_a_plus_prompt_summary_lines` includes (a) plain-language framing strings (no `null`, no `{`/`}` JSON braces, no scaffold-placeholder bracket-TODO byte patterns), (b) the first N lines of the fixture `research.md` rendered inline (N = `tier_a_plus_prompt_summary_lines` = 8 by P00 default), (c) all three named options visible (`y` / `n` / `c`), (d) the `(N more lines at <path>)` ellipsis where the literal numeric N matches `(total_lines − inline_lines)`, AND (e) when `--yes` is passed, the `research: <path>` audit-line appears on stderr.
  - Check: `bash tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh`

- `tools/verify/m031-p02-phase-suite.sh` exists, is executable, invokes every P02 sub-gate in T01 → T02 → T03 → T04 dependency order via straight-line `bash <verifier>` invocations (AD-19 — no array loops, no compound chains), and emits a single final stdout line `SUMMARY: m031-p02-phase-suite.sh pass=N fail=M`. Exits 0 iff every sub-gate exits 0. The aggregator does NOT short-circuit on a sub-gate failure (all gates run).
  - Check: `bash tools/verify/m031-p02-phase-suite.sh`

- `tools/verify/m031-p02-scope-guard.sh` exists, is executable, and asserts the P02 diff (working tree vs HEAD) does NOT touch any path under the SC-12 block-list (`knowledge/**` schema, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`). The MEM `hit_count`-only carve-out from the P01 scope-guard is preserved verbatim. Allow-list reflects the P02 "Files Likely Touched" surface.
  - Check: `bash tools/verify/m031-p02-scope-guard.sh`

### Artifacts

- `scripts/intake/shape-detect.sh` (min existing-baseline+15 lines, contains "tier_a_plus") — modify
- `scripts/intake/paragraph-classify.sh` (min existing-baseline+8 lines, contains "tier_a_plus") — modify
- `scripts/intake/route-to-dispatch.sh` (min existing-baseline+40 lines, contains "tier_a_plus", contains "tier_a_plus_role", contains "aborted", contains "research", contains "plan", contains "build") — modify
- `scripts/intake/lib/task-slug.sh` (min 60 lines, contains "derive_task_slug", contains "sha1") — create
- `scripts/intake/lib/tier-a-plus-prompt.sh` (min 100 lines, contains "tier_a_plus_prompt_summary_lines", contains "research:", contains "(y)", contains "(n)", contains "(c)") — create
- `templates/dispatch-role-research.md` (min 25 lines, contains "type: dispatch-role", contains "role: research", contains "findings", contains "research.md") — create
- `templates/dispatch-role-plan.md` (min 25 lines, contains "type: dispatch-role", contains "role: plan", contains "PLAN.md", contains "Verification", contains "Steps") — create
- `templates/dispatch-role-build.md` (min 25 lines, contains "type: dispatch-role", contains "role: build", contains "verifiers", contains "inline") — create
- `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` (min 25 lines, contains "tier_a_plus", contains "unit_close", contains "rationale") — create
- `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` (min 4 lines, exists with 30-80 word body) — create
- `tests/m031-acceptance/test-tier-a-plus-classifier.sh` (min 35 lines, contains "SC-5", contains "tier_a_plus", contains "FIXTURE-PROVENANCE") — create
- `tests/m031-acceptance/test-tier-a-plus-flow.sh` (min 60 lines, contains "SC-6", contains "tier_a_plus_role", contains "research", contains "plan", contains "build", contains "aborted") — create
- `tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh` (min 60 lines, contains "SC-16", contains "AD-20", contains "tier_a_plus_prompt_summary_lines", contains "(N more lines at") — create
- `tools/verify/m031-p02-classifier-extension-shape.sh` (min 30 lines, contains "tier_a_plus", contains "shape-detect.sh", contains "paragraph-classify.sh") — create
- `tools/verify/m031-p02-fixture-provenance-shape.sh` (min 25 lines, contains "FIXTURE-PROVENANCE.md", contains "AD-16", contains "unit_close") — create
- `tools/verify/m031-p02-tier-a-plus-input-shape.sh` (min 25 lines, contains "tier-a-plus-input.txt", contains "30") — create
- `tools/verify/m031-p02-task-slug-shape.sh` (min 30 lines, contains "task-slug.sh", contains "derive_task_slug", contains "sha1") — create
- `tools/verify/m031-p02-role-templates-shape.sh` (min 35 lines, contains "dispatch-role-research", contains "dispatch-role-plan", contains "dispatch-role-build", contains "type: dispatch-role") — create
- `tools/verify/m031-p02-prompt-shape.sh` (min 40 lines, contains "tier-a-plus-prompt.sh", contains "tier_a_plus_prompt_summary_lines", contains "(y)", contains "(c)") — create
- `tools/verify/m031-p02-router-shape.sh` (min 40 lines, contains "route-to-dispatch.sh", contains "tier_a_plus", contains "tier_a_plus_role", contains "aborted") — create
- `tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh` (min 25 lines, contains "test-tier-a-plus-classifier.sh", contains "SC-5") — create
- `tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh` (min 25 lines, contains "test-tier-a-plus-flow.sh", contains "SC-6") — create
- `tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh` (min 25 lines, contains "test-tier-a-plus-prompt-ux.sh", contains "SC-16", contains "AD-20") — create
- `tools/verify/m031-p02-phase-suite.sh` (min 60 lines, contains "SUMMARY:", contains "m031-p02-classifier-extension-shape", contains "m031-p02-router-shape", contains "m031-p02-prompt-shape", contains "m031-p02-phase-suite") — create
- `tools/verify/m031-p02-scope-guard.sh` (min 80 lines, contains "knowledge/", contains "scripts/cost", contains "scripts/dispatch/adapters/router", contains "scripts/auto/loop", contains "SC-12", contains "mem-hitcount-only") — create

### Key Links

- `scripts/intake/shape-detect.sh` → `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` (the `tier_a_plus` heuristic body references the provenance file as its empirical grounding per AD-16)
- `scripts/intake/route-to-dispatch.sh` → `templates/dispatch-role-research.md` (router invokes the research role template as the first of three dispatches)
- `scripts/intake/route-to-dispatch.sh` → `templates/dispatch-role-plan.md` (router invokes the plan role template as the second dispatch, after the operator prompt gate)
- `scripts/intake/route-to-dispatch.sh` → `templates/dispatch-role-build.md` (router invokes the build role template as the third dispatch)
- `scripts/intake/route-to-dispatch.sh` → `scripts/intake/lib/task-slug.sh` (router calls `derive_task_slug` to compute `<task-slug>` for the per-flow output directory)
- `scripts/intake/route-to-dispatch.sh` → `scripts/intake/lib/tier-a-plus-prompt.sh` (router invokes the prompt helper between the research and plan dispatches per AD-7)
- `scripts/intake/lib/tier-a-plus-prompt.sh` → `templates/orchestrator-config-default.yml` (prompt reads `tier_a_plus_prompt_summary_lines` from the active config; default = 8 per P00)
- `tests/m031-acceptance/test-tier-a-plus-classifier.sh` → `scripts/intake/shape-detect.sh` (SC-5 invokes shape-detect against the tier-a-plus-input.txt fixture)
- `tests/m031-acceptance/test-tier-a-plus-flow.sh` → `scripts/intake/route-to-dispatch.sh` (SC-6 invokes the router and asserts the three-dispatch chain shape)
- `tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh` → `scripts/intake/lib/tier-a-plus-prompt.sh` (SC-16 / AD-20 captures the prompt's stdout/stderr and asserts UX contract)
- `tools/verify/m031-p02-phase-suite.sh` → `tools/verify/m031-p02-classifier-extension-shape.sh` (suite invokes classifier extension gate)
- `tools/verify/m031-p02-phase-suite.sh` → `tools/verify/m031-p02-router-shape.sh` (suite invokes router shape gate)
- `tools/verify/m031-p02-phase-suite.sh` → `tools/verify/m031-p02-prompt-shape.sh` (suite invokes prompt shape gate)
- `tools/verify/m031-p02-phase-suite.sh` → `tools/verify/m031-p02-scope-guard.sh` (suite invokes the scope-guard as the last gate)

## Tasks

### T01: Tier A+ classifier verdict (FR-6) + AD-16 fixture provenance + SC-5 test

See `tasks/T01-classifier-and-provenance-PLAN.md`.

T01 extends `scripts/intake/shape-detect.sh` and `scripts/intake/paragraph-classify.sh` with a fourth verdict value `tier_a_plus` — additive to the existing M024 verdict enum, no regression on existing fixtures (CON-3 / AD-2). T01 ships the AD-16 normative `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` grounding the classifier in at least one historical `.orchestrator/` JSONL `unit_close` record with annotator rationale. T01 ships the `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` 30–80 word fixture matching the heuristic. T01 ships SC-5 (`tests/m031-acceptance/test-tier-a-plus-classifier.sh`) plus three shape verifiers under `tools/verify/m031-p02-*.sh`: classifier-extension-shape, fixture-provenance-shape, tier-a-plus-input-shape, and test-tier-a-plus-classifier-shape.

### T02: Task-slug derivation library (AD-10) + role templates (FR-8)

See `tasks/T02-slug-and-role-templates-PLAN.md`.

T02 ships `scripts/intake/lib/task-slug.sh` exposing `derive_task_slug <description>` returning `<40-char-lower-hyphen-alnum>[-<sha1-4>]` per AD-10 — the SHA-1 collision suffix is appended only when an output directory exists for a different prior task description. T02 ships three prescriptive role templates under `templates/dispatch-role-{research,plan,build}.md` per FR-8 — each with YAML frontmatter (`type: dispatch-role`, `role: <name>`) and a prescriptive body declaring the exact output shape, the dispatch-payload requirements (Quick-profile knowledge inject + `--meta-out` sidecar), and the per-role output-path convention. T02 ships two shape verifiers: m031-p02-task-slug-shape.sh and m031-p02-role-templates-shape.sh. No edits to `scripts/intake/route-to-dispatch.sh` in T02 (T04's job).

### T03: Tier A+ approval prompt (AD-7 + AD-20) + SC-16 prompt UX test

See `tasks/T03-prompt-and-prompt-ux-test-PLAN.md`.

T03 ships `scripts/intake/lib/tier-a-plus-prompt.sh` implementing the AD-7 + AD-20 prompt protocol: plain-language framing (no `null`, no JSON braces, no scaffold-placeholder bracket-TODO byte pattern), inline first-N-lines summary of `research.md` (N = `tier_a_plus_prompt_summary_lines` from config, P00 default 8), three named options `(y) plan against this research / (n) re-run research with different framing / (c) abort this Tier A+ flow` with single-keystroke responses and default-on-no-answer = `c`, `(N more lines at <path>)` ellipsis when research exceeds the inline budget, resume-vs-rerun visibility against pre-existing `research.md` files, and `--yes` skip path emitting one `research: <path>` stderr audit line. T03 ships SC-16 (`tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh`) plus two shape verifiers: m031-p02-prompt-shape.sh and m031-p02-test-tier-a-plus-prompt-ux-shape.sh.

### T04: Tier A+ router (FR-7) + SC-6 end-to-end flow test

See `tasks/T04-router-and-flow-test-PLAN.md`.

T04 amends `scripts/intake/route-to-dispatch.sh` to recognize a `tier_a_plus` verdict and chain exactly three sequential dispatches (research → operator prompt gate (T03) → plan → build) using T02's role templates and slug-derivation library, with `--profile=quick` per the P01 reconciled `commands/dispatch.md`. The router emits one `unit_close` JSONL record per dispatch carrying `tier_a_plus_role: <research|plan|build>` and `aborted: <true|false>` (additive schema). The router MUST NOT invoke `orchestrator:auto` / `orchestrator:roadmap` / `orchestrator:consolidate`, MUST NOT acquire any auto-loop lock, and MUST NOT write `.orchestrator/milestones/M###/` scaffolding (CON-4 / DC-4). Operator cancel at the prompt OR inline build-verifier failure produces a `unit_close` record with `aborted: true` and a non-zero router exit. T04 ships SC-6 (`tests/m031-acceptance/test-tier-a-plus-flow.sh`) plus two shape verifiers: m031-p02-router-shape.sh and m031-p02-test-tier-a-plus-flow-shape.sh.

### T05: P02 phase-suite aggregator + SC-12 scope-guard for P02

See `tasks/T05-phase-suite-and-scope-guard-PLAN.md`.

T05 ships `tools/verify/m031-p02-phase-suite.sh` chaining every P02 sub-gate (in T01 → T02 → T03 → T04 dependency order) via straight-line `bash <verifier>` invocations (AD-19 compliant — no array loops, no compound chains). The suite emits a single final `SUMMARY: m031-p02-phase-suite.sh pass=N fail=M` line and exits 0 iff every sub-gate exits 0; gates do NOT short-circuit on failure. T05 ships `tools/verify/m031-p02-scope-guard.sh` enforcing the SC-12 block-list (`knowledge/**` schema, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`) — the MEM `hit_count`-only carve-out from the P01 scope-guard is preserved verbatim. The allow-list reflects the P02 "Files Likely Touched" surface plus phase/task plan + summary paths plus `.orchestrator/observability/` prefix. The scope-guard is the last gate in the phase-suite (so a clean diff is required for green).

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03 ──▶ T04 ──▶ T05
```

Strict linear chain. T01 ships the additive classifier verdict + AD-16 provenance + SC-5 (no router edits). T02 depends on T01 only because the role templates reference the classifier verdict in their preamble; otherwise T02 is independent of T01 (slug library + role templates are isolated artifacts). T03 depends on T02 because the prompt helper consumes T02's role templates' output-path convention. T04 depends on T03 because the router invokes the T03 prompt helper between the research and plan dispatches. T05 depends on T04 because the phase-suite aggregator invokes every shape verifier shipped alongside the deliverables in T01–T04 and the scope-guard's allow-list reflects the post-T04 file inventory.

## Files Likely Touched

- `scripts/intake/shape-detect.sh` (modify)
- `scripts/intake/paragraph-classify.sh` (modify)
- `scripts/intake/route-to-dispatch.sh` (modify)
- `scripts/intake/lib/task-slug.sh` (create)
- `scripts/intake/lib/tier-a-plus-prompt.sh` (create)
- `templates/dispatch-role-research.md` (create)
- `templates/dispatch-role-plan.md` (create)
- `templates/dispatch-role-build.md` (create)
- `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` (create)
- `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` (create)
- `tests/m031-acceptance/test-tier-a-plus-classifier.sh` (create)
- `tests/m031-acceptance/test-tier-a-plus-flow.sh` (create)
- `tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh` (create)
- `tools/verify/m031-p02-classifier-extension-shape.sh` (create)
- `tools/verify/m031-p02-fixture-provenance-shape.sh` (create)
- `tools/verify/m031-p02-tier-a-plus-input-shape.sh` (create)
- `tools/verify/m031-p02-task-slug-shape.sh` (create)
- `tools/verify/m031-p02-role-templates-shape.sh` (create)
- `tools/verify/m031-p02-prompt-shape.sh` (create)
- `tools/verify/m031-p02-router-shape.sh` (create)
- `tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh` (create)
- `tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh` (create)
- `tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh` (create)
- `tools/verify/m031-p02-phase-suite.sh` (create)
- `tools/verify/m031-p02-scope-guard.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-5]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. Test-run output files written
     under .orchestrator/tier-a-plus/<task-slug>/ during integration
     smoke runs are scratch artifacts under the .orchestrator/observability/
     prefix-equivalent — the scope-guard treats .orchestrator/tier-a-plus/
     as a permissive prefix matching the .orchestrator/observability/
     pattern from P01. -->
