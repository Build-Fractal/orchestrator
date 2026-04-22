# Feature Specification: M014 Spec Management Extended — Native `orchestrator:specify`, Conversus-Suggestion, Dual-Write Runtime Instructions, Comment→Workflow Automation

**Feature Branch**: `024-spec-management-extended`
**Created**: 2026-04-22
**Last Revised**: 2026-04-22 (post-conversus cooperative deliberation; 14 MITs applied pre-discuss per `conversus/summary/final.md`)
**Status**: Ready-for-discuss
**Milestone**: M014 (see `.orchestrator/milestone-summary.md`, roadmap entry "Spec Management + Comment→Workflow Automation", scope extended 2026-04-22 per `.orchestrator/DECISIONS.md` D016)
**Input**: User description: "M014 Spec Management Extended (bundled): ship native `orchestrator:specify` as a portable, CC-first replacement for the spec-kit `/speckit.specify` command (removed by M015 cutover), treating the existing spec-kit `spec-template.md` shape as an I/O contract rather than a verbatim port; add conversus-suggestion logic so complex or controversial draft specs auto-propose red-blue pressure-test (with optional spec-decomposition-before-conversus for very large specs), opt-in per proposal; add `AGENTS.md` dual-write alongside every `CLAUDE.md` write (init, knowledge updates, recent-changes appends) so Codex-runtime subagents stay fed without a separate milestone; finish M014's original mission — wiki Giscus comments and GitHub Issue/PR comments classified into workflow actions (file UAT bug / append decision / amend spec chunk / route to human triage) with ambiguous comments invoking the M011/P07 conversus adapter. Consumes M012's wiki-giscus-remap thread mapping and M013's UAT ingestion path. Dogfood resolves a bootstrapping irony: M015 ripped spec-kit out, M014 ships the native equivalent, and future milestones' specs are authored by the orchestrator instead of by hand."

## Problem Statement

After M015's standalone cutover, this repo has no native command for authoring feature specs. `spec-kit`'s `/speckit.specify` script (and its `.specify/` template tree) were removed; the M013 spec (`specs/023-github-native-integration/spec.md`) and this spec (`specs/024-spec-management-extended/spec.md`) were hand-authored on `main` because no replacement existed. That gap is a dogfood hole: every future milestone either re-hand-authors its spec or pulls back in a spec-kit dependency the project has already committed to living without.

Three concrete gaps follow from the gap:

1. **No portable spec-authoring surface.** Operators on Codex CLI or Cursor (or on a second machine without `spec-kit` installed) cannot start a new spec without either copying the last spec by hand or reintroducing the toolchain M015 deleted. Constitution X (Templating Over Inference) says authoring is a templated operation; without a command that owns the template, the template exists only in drift-prone copies scattered across `specs/**/`.
2. **No default pressure-test path for risky specs.** The M013 spec was pressure-tested via `/conversus run` red-blue deliberation only because the author happened to remember to propose it after drafting (see `.orchestrator/DECISIONS.md` D014). For the next author — or the next agent running the command — there is no automatic prompt saying "this spec is big enough / contradictory enough / ambiguous enough to warrant adversarial review before discuss." Conversus integration stays as the M011/P07 reusable adapter per D007; M014's job is to be one of the opt-in sites that invokes it at the one checkpoint it pays off most (post-draft, pre-discuss).
3. **Codex-runtime guidance drifts.** The orchestrator writes to `CLAUDE.md` on every `orchestrator:init`, on knowledge updates, and on recent-changes appends. Codex CLI reads `AGENTS.md` for the same purpose. Today Codex users either maintain `AGENTS.md` by hand (drift accumulates) or they don't (Codex subagents get no runtime guidance). D016 explicitly calls this out as "without a separate milestone" — the surface is too small to justify its own milestone but too important to leave unhandled.
4. **Comment surfaces (wiki + GitHub) are write-only today.** M012 shipped Giscus threading on every wiki page; M013 shipped GitHub Issues with the UAT Bug template. A stakeholder who comments "this acceptance scenario contradicts scenario 3" on a wiki page has nowhere structured for that to land — it sits as a thread until a human reads it and manually files a bug or amendment. The *original* M014 mission was to close this loop: classify each comment into a workflow action (file UAT bug, append decision, amend spec chunk, route to human triage) and apply trivial actions automatically, invoking the M011/P07 conversus adapter to triage ambiguous comments.

M014 ships the minimum surface that fixes all four: a native `orchestrator:specify` command that produces a byte-compatible (to the existing hand-authored spec precedent) `specs/<NNN>-<slug>/spec.md` from a natural-language description; a threshold-gated conversus-suggestion pass that proposes pressure-test (and optional pre-conversus decomposition for very large specs) when the draft crosses configured thresholds; an `AGENTS.md` dual-write discipline applied to every existing `CLAUDE.md` write-site; and the comment→workflow classifier that consumes M012/M013 surfaces and routes each comment into one of four structured actions.

Scope discipline matters. M014 does **not** attempt: bi-directional spec↔GitHub sync beyond the narrow UAT-read-back M013 already owns; spec versioning beyond what `git` already provides; spec linting/validation as a separate command (defer to M020 or post-launch); auto-apply on every comment classification (human-in-the-loop for anything beyond the trivial actions enumerated below); Codex-native `orchestrator:specify` parity (CC-first for v1 per FR-12-style runtime-stance inherited from M013; Codex parity is a fast-follow demand-driven via M009 runtime-parity audit). The four clusters ship as one bundled milestone because they share the same substrate (the spec file, its chunks, its runtime-instruction context, and the comment threads that reference them) and sequentially unlock each other: US-2 lands first so the rest of M014 — and every future milestone — dogfoods it.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The dogfood loop closes on a minimum subset of US-2 and US-4:

- **Full US-2**: `orchestrator:specify` create-path — takes `--description <prose>` (and optional `--slug <short-name>`), scaffolds `specs/<NNN>-<slug>/spec.md` conforming to the I/O contract in the FR-2 Section Contract, and prints the written path on stdout. No conversus auto-propose; no interactive clarify loop in Phase 1.
- **Minimal US-4**: Dual-write applied to `orchestrator:specify` only — when the command authors a new spec and its scaffolding touches `CLAUDE.md`'s Recent Changes section (the existing orchestrator pattern), it also emits the equivalent block into `AGENTS.md` at a marker-bounded region. No backfill of historical `CLAUDE.md` surfaces; no generator-from-SSOT authoring; the broader dual-write discipline (knowledge updates, `orchestrator:init`) rides in later phases.

This slice is what Phase 1 of M014 execution is expected to ship. The full surface — conversus-suggestion (US-3), comment→workflow classifier (US-1), and dual-write applied to all `CLAUDE.md` write-sites (full US-4) — rides in Phases 2–N, defended on two downstream consumers: (1) every subsequent orchestrator-authored spec in M013→M024→M020 dogfoods Phase 1 before Phase 2+ lands; (2) M012/M013 comment backlog is the input signal that sizes the US-1 classifier scope, not up-front speculation (Constitution XIV).

The bootstrapping irony resolves when M014/P01 closes: the next milestone's spec (M020 or M024) is authored by running `orchestrator:specify` rather than by hand-copying this file or the M013 file.

### Phase Sequencing

The bundle's four clusters ship across four phases with mechanically-enforceable exit criteria. This table lands spec-layer (pre-discuss) as the minimum-viable defense of the bundle against Constitution XIV's speculative-complexity test. Planning extends it with additional columns (execution notes, external dependency fanout) but may not contract it.

| Phase | User-story slices | Exit criteria | Dogfood consumer | External milestone dependencies |
|---|---|---|---|---|
| P1 | Full US-2 (`orchestrator:specify` create-path) + minimal US-4 (dual-write at `orchestrator:specify`'s Recent Changes write-site only) | `orchestrator:specify --description ... --slug ...` scaffolds a `specs/<NNN>-<slug>/spec.md` passing `scripts/verify/spec-shape-lint.sh`; `AGENTS.md` Recent Changes region matches `CLAUDE.md`; fixture test `tests/test-specify-shape.sh` green; SC-1, SC-2, SC-6, SC-7, SC-9, SC-14 met | Every subsequent orchestrator-authored spec (M013→M024→M020) replaces hand-authoring with `orchestrator:specify` invocation; SC-13 is the close gate | None |
| P2 | Full US-4 (dual-write extended to `orchestrator:init` and `orchestrator:consolidate` write-sites) + FR-13 drift detector | `scripts/verify/check-docs.sh` drift pass green across all documented write-sites; SC-6, SC-6a met; `orchestrator:doctor` surfaces `runtime_instruction_drift` | Codex-runtime operators running M014-generated specs; M009 runtime-parity audit consumes `RUNTIME-ASSUMPTIONS.md` entries | None |
| P3 | Full US-1 (wiki + GitHub comment fetch + classify + review queue) + US-5 (spec-amendment apply path) | `orchestrator:comments classify` end-to-end on seeded inbox; auto-apply path for `uat-bug` + `decision-append`; review queue for `spec-amendment`; SC-4, SC-5, SC-8, SC-16 met | M012/M013 comment backlog; SC-16 dogfood-data table sizes FR-9 classifier shape decision | **M013/P04** — FR-8 GitHub Issue comment fetch consumes M013's sync cycle + post-verify hook + UAT comment surface; P3 cannot start before M013/P04 closes |
| P4 | US-3 conversus auto-propose + FR-5 complexity probe + FR-6 conversus preset + SC close-outs | `templates/conversus-presets/spec-pressure-test.yml` shipped; probe emits structured fields; three-way prompt (y/n/d) exercised end-to-end; SC-3, SC-15 met; all remaining SCs green | Next milestone's spec whose complexity exceeds threshold auto-proposes pressure-test | M011/P07 conversus adapter (shipped) |

---

### User Story 1 — Wiki And GitHub Comments Classify Into Structured Workflow Actions (Priority: P1)

A stakeholder reading the M012 wiki opens a spec chunk page and leaves a Giscus comment: "This scenario contradicts AS-3; which takes precedence?". Separately, another stakeholder opens a GitHub Issue on a shipped phase and comments: "Acceptance criterion 2 fails on macOS 13." A maintainer (or a periodic command) runs `orchestrator:comments classify`. The command fetches unactioned comments from both surfaces, classifies each into one of four workflow actions — file UAT bug, append decision, amend spec chunk, route to human triage — and either applies the trivial actions automatically or surfaces a review queue for human sign-off. Ambiguous comments invoke the M011/P07 conversus adapter for triage.

**Why this priority**: This is the original M014 mission as scoped in the roadmap before the D016 extension. The comment surfaces (wiki Giscus + GitHub Issues/PRs) exist as of M012/M013 close but are write-only without the classifier. Without US-1, the spec→wiki→GitHub loop is one-directional and stakeholders learn to stop commenting because nothing happens.

**Independent Test**: Seed a test project with (a) one wiki page bearing a Giscus thread containing three comments of distinct classes (one UAT-bug-shaped, one decision-request-shaped, one ambiguous), and (b) one GitHub Issue on a shipped phase bearing two comments (one spec-amendment-shaped, one ambiguous). Run `orchestrator:comments classify --dry-run`. Confirm the command reports a manifest of 5 comments with their proposed actions: 1 UAT bug to file, 1 decision-append, 1 spec-amendment, 2 ambiguous → conversus triage. Running without `--dry-run` applies only the two trivial actions (UAT bug + decision-append); the spec-amendment is queued for human review (Constitution XV — no silent spec mutation); the two ambiguous comments are passed to the M011/P07 conversus adapter which returns a triage verdict.

**Acceptance Scenarios**:

1. **Given** a Giscus thread exists at a wiki page keyed to a spec chunk `SPEC-US-003`, **When** `orchestrator:comments classify` runs, **Then** each unactioned comment in the thread is fetched (via `gh api` against the Giscus Discussion) and associated with `SPEC-US-003` via the M012 wiki-giscus pathname-keyed thread mapping (per `scripts/wiki/wiki-giscus-remap.sh`).
2. **Given** a GitHub Issue comment contains a structured pattern matching the UAT-bug classifier (e.g., "acceptance criterion N fails", "bug:", or the YAML frontmatter shape installed by the M013 UAT Bug template reply), **When** classification runs, **Then** the comment is labeled `class: uat-bug` with a confidence score and a reference back to the source comment URL.
3. **Given** a comment contains a structured pattern matching decision-append (e.g., "decision:", "we decided", or explicit "/append-decision" trigger), **When** classification runs, **Then** the comment is labeled `class: decision-append` and — if confidence ≥ the auto-apply threshold — the orchestrator appends a `.orchestrator/DECISIONS.md` entry citing the comment URL; below threshold it queues for review.
4. **Given** a comment proposes a spec-chunk amendment (e.g., "FR-5 should also cover X" or "AS-2 is wrong because Y"), **When** classification runs, **Then** the proposed amendment is **never auto-applied**; instead it is written to `.orchestrator/comments/review-queue/<comment-id>.md` with a proposed diff for human sign-off (Constitution XV — spec mutation is human-gated).
5. **Given** a comment does not match any classifier (confidence below all class thresholds), **When** classification runs, **Then** the comment is passed to the M011/P07 conversus adapter (`scripts/dispatch/adapters/tool/conversus.sh`) with a `classify-comment` preset; the adapter's verdict is recorded and — if the adapter too returns low confidence — the comment routes to `orchestrator:comments triage` (human bucket).
6. **Given** a comment has already been actioned (present in `.orchestrator/comments/actioned.jsonl` with a prior run's comment URL + timestamp), **When** classification re-runs, **Then** the comment is skipped (idempotency — mirror of M013/FR-4's marker invariant). Re-classification is an explicit opt-in via `orchestrator:comments classify --reclassify <comment-url>`.
7. **Given** a maintainer runs `orchestrator:comments status`, **When** there are comments in the review queue, **Then** the command lists each queued comment with its proposed action, source URL, and the command to approve (`orchestrator:comments apply <queue-id>`) or reject (`orchestrator:comments reject <queue-id>`).
8. **Given** the conversus adapter is unavailable (absent binary or `--strict` failure), **When** classification encounters an ambiguous comment, **Then** the comment routes to the human triage bucket with a diagnostic — it does not silently drop (inherits M013/FR-13 strict-mode discipline).

---

### User Story 2 — Native `orchestrator:specify` Creates A Byte-Compatible Spec From A Natural-Language Description (Priority: P1)

A maintainer on any orchestrator-enabled runtime (Claude Code in v1; Codex/Cursor via fast-follow) has an idea for a new milestone or feature. They run `orchestrator:specify --description "Add an opt-in exporter that ships merged-PR diffs to a Slack channel for async review"` (or respond to an interactive prompt). The command derives a short-slug, picks the next sequential spec number, scaffolds `specs/<NNN>-<slug>/spec.md` conforming to the section contract pinned by FR-2 (Problem Statement → Minimal Slice → User Stories → Edge Cases → Functional Requirements → Success Criteria → Constraints → Non-Goals → Assumptions → Knowledge-Layer Boundary → Constitution Check → Open Questions → Dependencies → Downstream Consumers), inserts a populated frontmatter block matching the hand-authored precedent (Feature Branch, Created date, Status: Draft, Milestone binding, Input), and prints the written path. The draft is not ready-for-discuss (requires human revision and — per US-3 thresholds — a possible conversus pressure-test first).

**Why this priority**: This is the load-bearing P01 of M014. Every downstream phase of this milestone, and every future milestone's spec, dogfoods this command. Without it, the M015 bootstrapping irony (spec-kit ripped out, no replacement) persists and the project cannot ship external adoption credibly. P1 over US-1 because US-1 consumes comment surfaces the spec must define first; US-2 also owns the entry point for US-3 and US-4-minimal.

**Independent Test**: On a clean orchestrator project with no prior `specs/024-*/` directory, run `orchestrator:specify --description "<test prose>" --slug test-exporter`. Confirm: (a) a new directory at `specs/<next-number>-test-exporter/` exists; (b) `spec.md` inside that directory contains every section listed in FR-2's Section Contract in the specified order; (c) the frontmatter block has `Status: Draft`, a today-dated `Created:` field, and a populated `Input:` field quoting the description; (d) the file passes `scripts/verify/spec-shape-lint.sh` (new, authored by this milestone per FR-4); (e) the command prints the absolute path to the written spec on stdout and exits zero; (f) running the command a second time with the same slug fails with a clear error ("spec directory already exists; pass --force to overwrite or use a different --slug") — Constitution XV, no silent overwrite.

**Acceptance Scenarios**:

1. **Given** no spec directory exists at `specs/<NNN>-<slug>/`, **When** `orchestrator:specify --description "<prose>" --slug <slug>` is invoked, **Then** the next sequential spec number is allocated (highest existing `specs/NNN-*` + 1), the directory is created, and `spec.md` is written atomically (temp-file-then-rename; pattern inherited from `scripts/knowledge/normalize-spec.sh`).
2. **Given** a spec is scaffolded, **When** the maintainer opens the file, **Then** every section named in the FR-2 Section Contract appears in the required order with inline placeholder prose or bracketed `<TODO: ...>` prompts indicating author responsibility for each section. Placeholders are bracketed consistently so `scripts/verify/spec-shape-lint.sh` can detect "spec is still a skeleton" vs. "spec is authored."
3. **Given** the `--description` is long enough (configurable threshold; FR-3), **When** the command runs, **Then** the LLM-assisted scaffolder populates first-pass content for the Problem Statement and at least one User Story stub from the description prose; shorter descriptions scaffold skeleton-only and the maintainer authors all content. Scaffolder is CC-first (Claude Code LLM round-trip); Codex and Cursor runtimes fall back to skeleton-only scaffold in v1 (fast-follow per D016 runtime-parity audit at M009).
4. **Given** `--slug` is omitted, **When** the command runs, **Then** the slug is derived deterministically from the description (first-N words, lowercased, kebab-cased, truncated to a planning-set length) and printed back to the operator before directory creation with a one-keystroke accept/reject prompt in interactive mode, or accepted automatically in `--yes` / auto mode.
5. **Given** the orchestrator is mid-milestone (an in-flight milestone has an unclosed phase), **When** `--milestone <M###>` is passed, **Then** the spec's frontmatter binds to that milestone and — per US-4 minimal — the Recent Changes section of `CLAUDE.md` and `AGENTS.md` are dual-written with a one-line entry referencing the new spec.
6. **Given** the target runtime is Codex CLI or Cursor, **When** `orchestrator:specify` runs in v1, **Then** the command skeleton-scaffolds the spec (no LLM round-trip) and prints a one-line diagnostic: "LLM-assisted scaffold requires Claude Code runtime in v1; skeleton-only scaffold written. Runtime-parity scaffolding is deferred to the M009 runtime-parity audit." Skeleton scaffolding is fully functional — the maintainer fills every section by hand exactly as M013 and M014 specs were authored.
7. **Given** auto-mode dispatches `orchestrator:specify` without a human in the loop, **When** the command runs under `orchestrator:auto`, **Then** no interactive prompts fire (inherits M016/M021 zero-prompt baseline); `--yes` is assumed; ambiguous slug derivation logs a diagnostic rather than blocking.
8. **Given** the scaffolded spec is committed, **When** `orchestrator:ingest --spec-path specs/<NNN>-<slug>/spec.md --slug <slug>` is run, **Then** the file passes the M011 shape probe (`scripts/knowledge/detect-spec-shape.sh`) as `shape=speckit` (i.e., ingest takes the fast path with no normalization) — this is the I/O-contract assertion that the native command's output is byte-compatible with what spec-kit's `/speckit.specify` would have produced.

---

### User Story 3 — Complex Or Controversial Drafts Auto-Propose Conversus Pre-Discuss Pressure-Test (Priority: P2)

A maintainer runs `orchestrator:specify` and the draft lands. The draft is large (many FRs, many user stories), or the description prose included contradiction signals ("should support both X and its opposite"), or the skeleton pass left a large number of `<TODO>` placeholders. The command prints a suggestion: "This draft crosses <threshold-name> (<reason>). Recommend running `orchestrator:conversus-suggest specs/<NNN>-<slug>/spec.md` to pressure-test before `orchestrator:discuss`. [y]es / [n]o / [d]ecompose-first". On `y`, the M011/P07 conversus adapter runs in red-blue deliberation mode against the draft; on `d`, `orchestrator:specify split` proposes a 2–N-way decomposition (one sub-spec per coherent cluster), each of which is then pressure-tested independently; on `n`, the draft proceeds unmodified.

**Why this priority**: This is the D016 extension — threshold-gated auto-propose so the next author does not forget to pressure-test (the D014 precedent for M013 came only because the operator remembered). P2 because conversus is opt-in, the threshold can default to off if planning deems it premature, and manual `/conversus run` is a workable fallback. P2 rather than P1 because it layers on US-2 and would be meaningless without it.

**Independent Test**: On a test project with US-2 shipped, author a spec whose prose explicitly includes contradictory requirements and whose scaffolded output exceeds the FR-count threshold (configurable; planning-set default). Run `orchestrator:specify --description "<contradictory prose>" --slug contradictory-test`. Confirm the command prints the conversus-suggestion prompt. Accept with `y`; confirm the M011/P07 conversus adapter is invoked with a `spec-pressure-test` preset (authored by this milestone and landed under `templates/conversus-presets/` per FR-6); confirm the adapter's `gate-result.md` lands at `specs/<NNN>-<slug>/conversus/summary/final.md`. Retry with `d` on a very large draft; confirm `orchestrator:specify split` proposes a decomposition manifest at `.orchestrator/intake/<id>/decomposition.md` (reusing M024's manifest shape — cross-link to M024/FR-N once that spec is authored).

**Acceptance Scenarios**:

1. **Given** a spec draft is freshly scaffolded, **When** the FR-5 complexity probe runs, **Then** the probe emits a single-line verdict to stdout (`probe=below-threshold` / `probe=above-threshold: <reason>`) plus structured fields (FR count, user-story count, TODO density, contradiction signals from LLM pass in CC runtime) suitable for logging to `execution-log.jsonl` in the M019 Tier 1 shape.
2. **Given** the probe fires `above-threshold`, **When** the command is interactive, **Then** the three-way prompt (y/n/d) is displayed with the single reason (not the full structured field dump). In `--yes` / auto mode, the default is `n` (skip) — the auto-propose is advisory, never auto-blocking, in v1.
3. **Given** the operator answers `y`, **When** the conversus invocation runs, **Then** `scripts/dispatch/adapters/tool/conversus.sh gate spec-pressure-test specs/<NNN>-<slug>/spec.md specs/<NNN>-<slug>/conversus/summary/final.md` is invoked with `--strict` (adapter unavailability fails loudly, never silently); adapter exit codes are handled per M013/FR-13 discipline (0 PASS → proceed; 0 SKIPPED: → proceed with warning; 2 BLOCK → record verdict and surface to operator; 1 ERROR → halt).
4. **Given** the operator answers `d`, **When** the split flow runs, **Then** the LLM-assisted splitter (CC only in v1) proposes 2–N coherent sub-specs with a manifest naming each proposed spec's slug, its slice of the source description, and its inherited user stories. The operator accepts or rejects the manifest; accepted manifests scaffold N new `specs/<NNN>-<sub-slug>/spec.md` files via the US-2 path and run `spec-pressure-test` per sub-spec.
5. **Given** the draft is below all thresholds, **When** `orchestrator:specify` completes, **Then** no conversus prompt fires; the scaffold succeeds silently (with the standard end-of-command path report) and the operator can still run `/conversus run` manually via the preset at any later time.
6. **Given** conversus is unavailable, **When** the operator answers `y` at the prompt, **Then** the adapter exits with a `--strict` FAIL (per M013/FR-13) and the command surfaces the diagnostic; the draft is **not** modified; the operator is instructed to install the adapter or answer `n` to proceed.
7. **Given** a draft has already been pressure-tested (a populated `specs/<NNN>-<slug>/conversus/summary/final.md` exists and the spec's frontmatter `Status:` has advanced past `Draft`), **When** the operator re-runs `orchestrator:specify --amend`, **Then** the re-scaffold respects the prior pressure-test and does not re-propose conversus for unchanged sections (closes the loop on M013's D014 pattern — post-deliberation edits are preserved, not re-deliberated).

---

### User Story 5 — Spec Amendment Classifier Routes Approved Queue Items Into Atomic Spec Edits (Priority: P2)

A maintainer reviews the review queue produced by US-1 (spec-amendment-shaped comments pending human sign-off). They open a queued item, inspect the proposed diff against the source spec chunk, and approve it via `orchestrator:comments apply <queue-id>`. The orchestrator applies the amendment to the spec's source markdown (at the chunk's source line range — traced via M011 chunk metadata), re-ingests the affected chunk through `orchestrator:ingest`, marks the comment as actioned, and (if configured) posts a reply on the source comment thread linking to the commit SHA.

**Scope boundary**: US-5 is the only path that edits `specs/<NNN>-<slug>/spec.md` from a comment. All other classification outcomes (UAT bug, decision-append, ambiguous, human triage) write to knowledge / decision / queue surfaces — never to spec markdown. This boundary is the Constitution-III + XIV guard on spec mutation: every byte change to a shipped spec passes through the human-approved `apply` gate.

**Why this priority**: P2 because it layers on US-1 (classification) and requires spec-mutation discipline (chunk-ID preservation, `scripts/knowledge/rebuild-index.sh` triggering, git-commit atomicity) that is subtler than trivial-action auto-apply. Without US-5, approved spec amendments fall back to hand-editing, which reintroduces the exact drift M014 exists to eliminate.

**Independent Test**: Seed the review queue with a spec-amendment item whose proposed diff touches one FR in a shipped spec. Run `orchestrator:comments apply <queue-id>`. Confirm: (a) the target spec's source markdown is edited at the correct line range (M011 chunk-source line metadata preserved); (b) `scripts/knowledge/rebuild-index.sh` runs automatically to reflect the amended chunk; (c) a git commit lands with a message citing the queue-id and the source comment URL (using the `docs(specs): amend M###/FR-N ...` commit-message convention); (d) the comment is marked actioned in `.orchestrator/comments/actioned.jsonl`; (e) if reply-on-apply is enabled, the source comment thread receives a reply linking to the commit SHA.

**Acceptance Scenarios**:

1. **Given** an approved queue item exists, **When** `apply` runs, **Then** the amendment is applied atomically (one commit per amendment; pre-commit hooks not bypassed; Bash 3.2 compatible per Constitution IX).
2. **Given** the queue item's proposed diff no longer applies cleanly (source spec has been edited since the comment was classified), **When** `apply` runs, **Then** the amendment is rejected with a three-way diff surfaced to the operator and a `status: stale` label applied to the queue entry; no partial edit is committed.
3. **Given** the operator rejects a queue item (`orchestrator:comments reject <queue-id> --reason "<prose>"`), **When** reject runs, **Then** the queue entry is marked actioned with `applied: false`, the rejection reason is recorded, and (if reply-on-apply is enabled) the source comment thread receives a reply with the reason.
4. **Given** the amendment touches a chunk that is also being pressure-tested via US-3 conversus (e.g., the spec is still in Draft status with an in-flight deliberation), **When** `apply` is invoked, **Then** the command refuses with a clear diagnostic ("deliberation in progress at `specs/<NNN>-<slug>/conversus/`; complete or abort before applying amendments") — a Constitution-III + XIV guard against interleaving spec authorship and spec amendment.

---

### User Story 4 — `AGENTS.md` Dual-Writes Alongside `CLAUDE.md` On Every Orchestrator Write-Site (Priority: P2)

A maintainer runs `orchestrator:init` on a fresh project; later they run `orchestrator:consolidate` which appends a Recent Changes entry; later still they run `orchestrator:specify` (via US-2) which also appends a Recent Changes entry. At each of these three orchestrator write-sites, the orchestrator writes to `CLAUDE.md` (the Claude Code runtime-instruction file) *and* to `AGENTS.md` (the Codex CLI runtime-instruction file) via a marker-bounded block. An operator working from Codex CLI opens `AGENTS.md` and sees the same runtime guidance their Claude Code colleague sees from `CLAUDE.md`, including Recent Changes with both the project's shipped milestones and any new specs scaffolded by US-2.

**Why this priority**: Per D016, this is the Codex-parity surface that avoids a separate Codex-parity milestone. P2 because (a) the US-2 Minimal Slice piece is scoped narrowly (dual-write applied to the `orchestrator:specify` Recent Changes path only) and (b) the broader dual-write discipline is a 1–2 day surface, not a complex subsystem. Without it, Codex subagents on this repo run with `AGENTS.md` stale-or-missing and the M009 runtime-parity audit (D016) surfaces Codex as second-class — an adoption-credibility blocker.

**Independent Test**: On a test project with no prior `AGENTS.md`, run `orchestrator:specify --description "<prose>" --slug dual-write-test` (US-2). Confirm: (a) `CLAUDE.md`'s Recent Changes section contains a new one-line entry for the new spec; (b) `AGENTS.md` exists and contains an equivalent block between explicit `# >>> orchestrator:recent-changes >>>` / `# <<< orchestrator:recent-changes <<<` markers; (c) the block content is byte-identical to the `CLAUDE.md` entry in the Recent Changes region (or semantically equivalent via a documented transform — planning decides whether dual-write is byte-identical or transform-based). Run `scripts/verify/check-docs.sh` (extended by this milestone per FR-10) and confirm the drift-detector reports zero drift between the two surfaces.

**Acceptance Scenarios**:

1. **Given** a fresh project with neither `AGENTS.md` nor `CLAUDE.md`, **When** `orchestrator:init` runs (eventually — full `init` dual-write rides in a later phase of this milestone; Phase 1 Minimal Slice scope is US-2 only), **Then** both files are created with the marker-bounded orchestrator region populated and an explicit warning to the operator if either file already has non-orchestrator content ("orchestrator region will be added to existing `<file>`; your content outside the markers is preserved").
2. **Given** `orchestrator:specify` (Minimal Slice US-2 + minimal US-4) appends a Recent Changes entry to `CLAUDE.md`, **When** the command completes, **Then** an equivalent marker-bounded block is appended to `AGENTS.md` in the same atomic commit (pattern inherited from M012/P04's marker-bounded splice into `mkdocs.yml`). If `AGENTS.md` is absent, the minimal surface creates it with just the orchestrator region and a two-line runtime-identification header.
3. **Given** the operator edits `CLAUDE.md` by hand inside the orchestrator-owned marker region (e.g., adding a Recent Changes line manually), **When** the next orchestrator command runs, **Then** the drift detector in `check-docs.sh` reports the asymmetry and the operator is instructed to either re-run the write-site (which re-syncs both surfaces) or explicitly accept the divergence via a documented opt-out. Silent overwrite of human edits is explicitly forbidden (Constitution XV — no speculative mutation).
4. **Given** the operator has intentionally customized `AGENTS.md` outside the orchestrator markers, **When** the dual-write fires, **Then** the write replaces only the bytes between the markers; content outside the markers is preserved byte-identically (`shasum` invariant per M012 pattern). This is the "marker-bounded atomic writes" idiom from M012/P04 lifted into this milestone's dual-write implementation.
5. **Given** `AGENTS.md` dual-write is disabled via `.orchestrator/config.yml` (`dual_write_agents: false`), **When** any orchestrator write-site runs, **Then** only `CLAUDE.md` is written; no `AGENTS.md` is created or modified. Operators on pure-Claude-Code projects opt out cleanly; default is enabled.
6. **Given** a future knowledge-update write-site is added to the orchestrator (e.g., M020 adds a new consolidate path), **When** the new write-site is implemented, **Then** it consumes the shared dual-write helper at `scripts/util/dual-write-runtime-md.sh` (authored by this milestone per FR-9) rather than implementing dual-write from scratch — enforcing that the dual-write discipline is a reusable utility, not a copy-paste pattern.

---

## Edge Cases

- **Slug collision after decomposition**: US-3 decomposition proposes N sub-specs; operator approves the manifest; on scaffolding, sub-spec slug #3 collides with an existing spec directory. The scaffolder halts the entire decomposition, rolls back any partial writes, and surfaces the collision to the operator for slug-override. Partial decomposition is never committed.
- **Spec number race (concurrent `orchestrator:specify` calls)**: Two operators run `orchestrator:specify` on the same repo branch and both resolve "next number" to 025. The second scaffolder's directory-create fails (directory already exists from first scaffolder's commit); the second retries with 026. `scripts/lifecycle/lock-manager.sh` is acquired for the duration of number-resolution-through-directory-creation to prevent TOCTOU. Mirrors M013/FR-7 sync-lock pattern.
- **Comment surface returns zero unactioned comments**: US-1 classifier run produces an empty manifest. Command exits zero with `manifest=empty` and a one-line summary; no review-queue entries created; no `actioned.jsonl` rows written. Idempotency in the degenerate case.
- **Dual-write on a repo where `AGENTS.md` contains legacy Codex content predating marker convention**: US-4 dual-write preserves all bytes outside its markers; if no markers are present at write time, they are inserted above the file's first heading (or at EOF if no heading), never in the middle of existing prose. Operators with large pre-existing `AGENTS.md` files can opt out via `.orchestrator/config.yml`.
- **Conversus adapter returns BLOCK on auto-proposed pressure-test**: US-3 conversus returns BLOCK verdict. The spec's `Status:` stays `Draft`; a `DELIBERATION-BLOCKED.md` sentinel file lands at `specs/<NNN>-<slug>/conversus/` directing the operator to resolve the blocking findings before `orchestrator:discuss` can run. Closes the D014 loop (M013 applied its own BLOCK-derived edits pre-discuss) with a machine-enforceable path.
- **Classifier labels a comment as UAT-bug but the referenced spec chunk no longer exists** (supersede-in-flight): US-1 auto-apply for UAT bug is blocked; the comment routes to human triage with an `orphan-chunk` diagnostic, mirroring M013/FR-10's `chunk-lookup-failed` precedent.
- **Comment thread spans multiple classifier labels**: A single comment contains both a decision-append signal and a spec-amendment signal. Classifier picks the higher-confidence label; if both exceed auto-apply thresholds, the comment routes to human triage with both candidate actions listed. Multi-label auto-apply is explicitly forbidden in v1 — every auto-applied comment produces exactly one orchestrator write-action.
- **`orchestrator:specify` run in a non-orchestrator directory**: Preflight check detects absence of `.orchestrator/` and exits with a clear error pointing to `orchestrator:init`. No files are created outside `specs/`.
- **`--amend` on a spec whose chunks have been ingested**: US-3 AS-7 covers the primary flow; edge case: if ingested chunks reference the amended spec's chunk IDs by scope-tag, `orchestrator:ingest` re-runs automatically post-amend to re-version affected chunks (the re-ingest path is idempotent per the M011 ingest command).

---

## Functional Requirements

- **FR-1 (`orchestrator:specify` command surface)**: A new command under `commands/specify.md` defines the user-facing contract. Subcommands: `specify` (default — scaffold new spec), `specify --amend <path>` (re-scaffold against an existing draft, preserving authored regions and re-running US-3 suggestion only on changed regions), `specify split <path>` (produce a decomposition manifest for a large draft; alias for US-3's `d` path). Commands live as markdown definitions in `commands/` following the existing pattern (`commands/init.md`, `commands/ingest.md`, `commands/evaluate.md`).

- **FR-2 (Section Contract — the I/O contract the command honors)**: The scaffolded `spec.md` contains these sections, in this order, each a top-level heading where noted or a subsection under a parent:

  1. Frontmatter block: `Feature Specification:` line, `Feature Branch:`, `Created:` (ISO-8601), `Status:` (`Draft` on first scaffold), `Milestone:` (bound if `--milestone` passed; otherwise a `<TODO: bind to milestone>` placeholder), `Input:` (quoted description).
  2. `## Problem Statement`
  3. `## User Scenarios & Testing` (mandatory header)
     - `### Minimal Slice (Phase 1 Load-Bearing Scope)` subsection
     - `### User Story N — <title> (Priority: P1/P2/P3)` — at least one, each with `**Why this priority**`, `**Independent Test**`, `**Acceptance Scenarios**`.
  4. `## Edge Cases`
  5. `## Functional Requirements` (FR-N numbered)
  6. `## Success Criteria` (SC-N numbered)
  7. `## Non-Goals`
  8. `## Constraints`
     - `### Knowledge-Layer Boundary (<milestone> vs. <owning-knowledge-milestone>)` subsection
  9. `## Assumptions`
  10. `## Constitution Check`
  11. `## Open Questions (defer to planning)`
  12. `## Dependencies`
  13. `## Downstream Consumers (informational, not binding)`

  The contract is a superset of the spec-kit `spec-template.md` section vocabulary (which `scripts/knowledge/detect-spec-shape.sh` probes for) so ingested output passes as `shape=speckit` without renormalization. Placeholder syntax is `<TODO: ...>` inside sections; authored content replaces placeholders as-is. Any section the scaffolder cannot populate from the description prose is left as a bracketed placeholder rather than silently dropped.

- **FR-2b (Template SSOT)**: A `templates/spec-template.md` file ships with this milestone as the Section Contract SSOT with bracketed `<TODO: ...>` placeholders in every required section. `orchestrator:specify` loads this template as the authoritative scaffold source; `scripts/verify/spec-shape-lint.sh` (FR-4) reads it to derive the list of required sections rather than hardcoding them. The inline FR-2 prose above becomes informational — when the template and the FR-2 prose disagree, the template wins (declaration-over-inference, Principle X). Template ships before fixture test; FR-18 consumes it.

- **FR-3 (Scaffold-fill depth — runtime-dependent)**: Under Claude Code runtime, the scaffolder invokes an LLM round-trip (dispatched through `scripts/dispatch/dispatch-interface.sh` using a new `templates/spec-scaffolder-prompt.md`) to populate first-pass prose for Problem Statement and at least one User Story stub from descriptions longer than a threshold (default 80 words; configurable in `.orchestrator/config.yml`). Under Codex CLI or Cursor runtime in v1, the scaffolder writes skeleton-only (all sections present, all content placeholder). The LLM-fill is additive — every section the LLM cannot confidently populate remains a placeholder. CC-first posture inherits from M013/FR-12 discipline; Codex-parity scaffolding is explicitly deferred to a future milestone (see Non-Goal #N).

- **FR-4 (Spec shape linter)**: A new verifier at `scripts/verify/spec-shape-lint.sh` checks a spec markdown file against the FR-2 Section Contract. Detects: missing required sections, sections out of order, unresolved `<TODO: ...>` placeholders (count is the signal; zero = authored, >0 = skeleton), missing frontmatter fields, missing subsections (Minimal Slice, Knowledge-Layer Boundary). Emits structured output (`checks=N passed=M failed=K`) and exits non-zero on failure. Integrates into `orchestrator:discuss` as a preflight — discuss cannot run on a spec that fails shape lint.

- **FR-5 (Complexity probe for US-3)**: A probe at `scripts/knowledge/spec-complexity-probe.sh` reads a draft `spec.md` and emits a single-line verdict plus structured fields: FR count, User Story count, raw token count, `<TODO>` placeholder density, contradiction-signal count (LLM-derived under CC; zero under Codex/Cursor in v1). Thresholds are declared in `.orchestrator/config.yml` (`spec_complexity_thresholds:`) with planning-set defaults. The probe is invoked at the end of `orchestrator:specify` scaffolding; its verdict drives the US-3 three-way prompt. Probe emits an `execution-log.jsonl` record in M019 Tier 1 shape (`spec_complexity_probe` event type) so dogfooding data sizes the defaults.

- **FR-6 (Conversus preset for spec pressure-test)**: A new preset file at `templates/conversus-presets/spec-pressure-test.yml` authored by this milestone and discoverable by the M011/P07 adapter. Preset shape follows M013 precedent (see `specs/023-github-native-integration/conversus/` scaffolding). Per D007 reuse discipline, the preset drops in without adapter modification — `scripts/dispatch/adapters/tool/conversus.sh` is the single invocation surface for all milestones' presets. Invocation at US-3's `y` path uses `--strict` (per M013/FR-13); the adapter's `gate-result.md` lands at `specs/<NNN>-<slug>/conversus/summary/final.md` following the M013 layout precedent.

- **FR-7 (Decomposition flow for US-3 `d` path)**: `orchestrator:specify split <path>` reads a large draft and invokes the LLM-assisted splitter (CC only in v1) to propose 2–N coherent sub-specs. The splitter writes a manifest to `.orchestrator/intake/<source-id>/decomposition.md` (note: this path is declared by M024's Universal Intake milestone per D016 — M014's split flow is a consumer of that path convention; until M024 lands, the manifest is written to `.orchestrator/specify/decomposition/<source-id>/manifest.md` and moved to the M024 path on its arrival). Manifest shape names each proposed spec's slug, the slice of the source description it owns, inherited user stories with priority preservation, and a one-line rationale per slice. Operator approval triggers N parallel scaffolder invocations (each runs FR-1 US-2 path); rejection preserves the source spec unmodified.

  **Interim → M024 migration handshake**: When M024 lands, M024 owns the consumer-side migration via `scripts/migrate/specify-to-intake.sh`. M014's interim-path manifests are write-forward-compatible — the manifest schema written at `.orchestrator/specify/decomposition/<source-id>/manifest.md` is byte-identical to what M024 writes at `.orchestrator/intake/<id>/decomposition.md`, so migration is a filesystem move (and a `<source-id>` → `<id>` rename), not a schema transform. M014 commits to not extending the manifest schema after this spec without a forward-compatibility check against M024's Universal Intake spec.

- **FR-8 (Comment fetching)**: A script at `scripts/comments/fetch.sh` enumerates unactioned comments from two surfaces: (a) Giscus Discussions on the wiki (via `gh api` against the Discussions category shipped by M012), and (b) GitHub Issue/PR comments bearing orchestrator-id markers from M013's projection (phase Issues, task Issues, UAT Bug Issues). Each fetched comment is identified by a canonical URL + a content shasum used as the idempotency key (mirror of M013/FR-4 marker discipline). Fetched comments are cached to `.orchestrator/comments/inbox/<comment-id>.json`. The `actioned.jsonl` log records every comment that has been classified-and-applied or classified-and-rejected — subsequent fetches skip already-actioned URLs.

- **FR-9 (Classifier)**: A classifier at `scripts/comments/classify.sh` reads cached inbox comments and emits, per comment, a label ∈ {`uat-bug`, `decision-append`, `spec-amendment`, `ambiguous`}, a confidence score (0.0–1.0), a proposed action manifest (for trivial classes), and a queue-pointer (for review-gated classes). The classifier shape is a planning decision (Open Question #C-1) — candidates: regex/heuristic, embedding distance against class prototypes, LLM-call per comment, or a two-pass hybrid (cheap pre-filter + LLM on residuals). The exact shape is pinned by planning after M012/M013 dogfood signal sizes the inbox volume. Auto-apply threshold is per-class-configurable in `.orchestrator/config.yml` (`comments.auto_apply_threshold:`) and defaults to conservative values pinned at planning; below-threshold comments queue for review regardless of class.

- **FR-10 (Auto-apply surface for trivial actions)**: For comments classified `uat-bug` at or above threshold, the auto-apply path runs the M013 UAT-ingestion surface (M013/FR-10) with the comment as input. For comments classified `decision-append` at or above threshold, the auto-apply path appends a `.orchestrator/DECISIONS.md` entry using a templated block (planning pins the block shape). For comments classified `spec-amendment`, auto-apply is **never permitted** in v1 — the comment is always human-gated through the review queue (Constitution XV — spec mutation is explicit). The auto-apply path emits a `comment_actioned` record to `execution-log.jsonl` in M019 Tier 1 shape with `{comment_url, class, confidence, action_taken, source_surface}`.

- **FR-11 (Review queue)**: A directory at `.orchestrator/comments/review-queue/` holds one markdown file per queued item. Each file carries frontmatter with `comment_url`, `class`, `confidence`, `proposed_action`, `queued_at`, `queue_id` (deterministic — shasum of comment URL). The body renders the proposed diff (for spec amendments) or the proposed append (for below-threshold decision-appends). `orchestrator:comments status` lists the queue with `queue_id`-based invocation for approve/reject. Applied/rejected items move to `.orchestrator/comments/actioned.jsonl` with outcome recorded.

- **FR-12 (Runtime-instruction dual-write helper)**: A shared utility at `scripts/util/dual-write-runtime-md.sh` implements the marker-bounded write for both `CLAUDE.md` and `AGENTS.md`. Interface: `dual-write-runtime-md.sh --marker <region-name> --content <path-to-content-fragment> [--file CLAUDE.md] [--file AGENTS.md]`. Invariants: (a) writes only between `# >>> orchestrator:<region-name> >>>` and `# <<< orchestrator:<region-name> <<<` markers — content outside is byte-preserved (`shasum` invariant, M012 pattern); (b) if markers are absent, inserted above the first heading or at EOF; (c) is configurable off via `.orchestrator/config.yml` (`dual_write_agents: false`). Helper is consumed by `orchestrator:specify` (Minimal Slice) and by `orchestrator:init`, `orchestrator:consolidate` in later phases of this milestone.

- **FR-13 (Dual-write drift detector)**: `scripts/verify/check-docs.sh` (existing from M006 docs hardening) extends with a drift-detection pass that compares the marker-bounded regions of `CLAUDE.md` and `AGENTS.md`. Detects: missing region in one file, byte-divergence within matching regions, markers present in one file only. Reports drift as a warning (not a failure) in v1; escalates to failure in a future milestone once the pattern stabilizes. Integrates into `orchestrator:doctor` output under a new `runtime_instruction_drift` section.

- **FR-14 (`--amend` flow for US-2)**: `orchestrator:specify --amend <path>` re-scaffolds against an existing draft without overwriting authored content. The re-scaffold logic operates per section with three defined cases:
  - **(a) All-placeholder section** (only `<TODO>` markers, zero authored prose bytes): re-run FR-3 LLM-fill (CC only); under Codex/Cursor runtime, leave unchanged.
  - **(b) Partial-placeholder section** (`<TODO>` markers *and* authored prose both present): leave both unchanged; operator resolves manually. The scaffolder logs a one-line diagnostic naming the section and the case.
  - **(c) Fully-authored section** (zero `<TODO>` markers): leave unchanged byte-identically.

  "Changed section" for downstream re-probe detection (US-3 AS-7 — re-offer conversus only on changed regions) is defined as: the `<TODO>` count changed, *or* the shasum of authored (non-placeholder) prose bytes changed. FR-5 re-probe fires on changed sections only; quiet on unchanged sections. Preserves the "post-deliberation edits are preserved" invariant from M013's D014 precedent.

- **FR-15 (Dry-run and auto-mode posture)**: Every new command introduced by this milestone supports `--dry-run` that prints what would be written / classified / applied without side effects. Auto-mode invocations (under `orchestrator:auto`) produce zero Claude Code approval prompts (inherits M016/M021 zero-prompt baseline). Interactive prompts (US-2 slug-accept, US-3 three-way) are auto-resolved under `--yes` with documented defaults.

- **FR-16 (Observability emission)**: Every command introduced by this milestone emits `unit_close` JSONL records to `.orchestrator/execution-log.jsonl` in the M019 Tier 1 shape, including per-run fields appropriate to the command: `{specs_scaffolded, specs_amended, comments_classified, comments_auto_applied, comments_queued, conversus_invocations, adapter_verdicts, dual_writes, elapsed_ms, source: "runtime"}`. Conversus invocations fired via FR-6 also emit `conversus_gate_invocation` records with `{gate_id: "spec-pressure-test", adapter_version, verdict, llm_calls, elapsed_ms, estimated_cost_usd}` matching M013/FR-17. M019 owns schema evolution; M014 is a producer.

- **FR-17 (Config surface)**: `.orchestrator/config.yml` gains a `specify:` section with `complexity_thresholds:`, `scaffolder_description_min_words:`, `scaffolder_llm_on_codex: false`; a `comments:` section with `auto_apply_threshold:` (per class), `reply_on_apply:` boolean, `fetch_schedule:` (planning decision — Open Question #C-2); and a top-level `dual_write_agents:` boolean (default `true`). All new config keys carry planning-set defaults; operator overrides take precedence (existing `.orchestrator/config.yml` specificity rules).

- **FR-18 (Template byte-compatibility fixture test)**: A fixture test at `tests/test-specify-shape.sh` asserts that `orchestrator:specify --description "<fixture-prose>" --slug <fixture-slug>` produces a `spec.md` whose section headings, section order, and placeholder positions byte-match the derivation from `templates/spec-template.md` (FR-2b). The test consumes the template as its ground truth — drift between scaffolder output and template fails the test. Fixture prose is short enough that skeleton-only scaffold is exercised (avoiding LLM round-trip flake in CI); LLM-fill paths get separate coverage if planning decides they need it. Sequence: FR-2b template ships first, FR-18 test consumes it.

- **FR-19 (`--dry-run` manifest format — M014-local)**: Every M014 command's `--dry-run` output is structured JSONL to stdout, one record per proposed action. Record shape: `{command, action_type, target_path, source_ref, description}` (additional fields permitted but not removable). Example `action_type` values: `scaffold-spec`, `dual-write-region`, `classify-comment`, `apply-amendment`, `append-decision`. Pinned in `references/spec-management.md` so downstream consumers (CI gates, operator tooling) can parse dry-run manifests without prose drift. M013's `--dry-run` format is *not* retrofitted by this spec — the cross-milestone format pinning is a separate governance concern and belongs to M020 or a future D-row, not this milestone's pre-discuss scope.

## Success Criteria

- **SC-1**: On a clean orchestrator project, `orchestrator:specify --description "<50-word prose>" --slug sc1-test` completes in under 10 seconds under Claude Code runtime and under 2 seconds under Codex/Cursor runtime; the resulting `specs/<NNN>-sc1-test/spec.md` passes `scripts/verify/spec-shape-lint.sh` with all structural checks green (FR-2 Section Contract verified; `<TODO>` count > 0 since this is a skeleton).

- **SC-2**: On an authored (zero-`<TODO>`) spec scaffolded by US-2, `scripts/knowledge/detect-spec-shape.sh --spec-path <path>` exits 0 with stdout matching exactly `shape=speckit\n`; `scripts/knowledge/ingest-spec.sh --spec-path <path> --slug <slug>` exits 0 with stderr matching `grep -E '^(WARN|normalize|fallback)'` returning zero lines; the resulting `KNOWLEDGE-INDEX.md` contains the new slug within 2 seconds of ingest completion. This is the I/O-contract assertion.

- **SC-3**: On a spec draft crossing the FR-5 complexity threshold, `orchestrator:specify` prints the three-way prompt; answering `y` triggers a conversus-adapter invocation that produces `specs/<NNN>-<slug>/conversus/summary/final.md` with a documented verdict; answering `d` produces a decomposition manifest naming 2–N sub-specs; answering `n` exits zero without further side effects. All three paths are exercised by the milestone's test suite.

- **SC-4 (default branch — measurement + re-planning trigger)**: Classifier precision on the `uat-bug` and `decision-append` classes is *measured and logged* per FR-16 across a seeded inbox of ≥20 comments (mix of 4 classes) plus the M012/M013 dogfood inbox data sized by SC-16. Planning re-tunes thresholds and/or classifier shape (per Open Question #C-1) if measured precision falls below 80% after ≥20 seeded comments. At spec-ship time — before planning pins the classifier shape — SC-4 is a diagnostic gate, not an auto-apply gate: the spec cannot ship a mechanical enforcement clause against an artifact whose shape is deferred to planning (Principle II).

- **SC-4 (upgrade branch — pinned-shape gate)**: If and only if planning pins a mechanically-measurable classifier shape per Open Question #C-1 (e.g., regex/heuristic with enumerable rules, or embedding-distance with a pinned prototype corpus), SC-4 is upgraded to include the failure-posture clause: below 80% precision at milestone close, auto-apply is disabled in shipped defaults for the affected class (`.orchestrator/config.yml` default sets `comments.auto_apply_threshold.<class>: 1.0`), and the milestone does NOT hold on below-floor precision. The upgrade branch activates at plan-phase time (planning captures the shape-pinning decision in writing); otherwise the default branch governs milestone close.

- **SC-5**: Zero spec amendments are auto-applied without human sign-off. On the test suite's seeded `spec-amendment`-labeled comments, every one lands in the review queue; `grep -r "applied: true" .orchestrator/comments/actioned.jsonl` on entries where `class=spec-amendment` returns zero matches unless preceded by an `orchestrator:comments apply <id>` invocation. Constitution III (Design Before Code — spec mutation is a design act, not a runtime act) primary; Constitution XIV (No Speculative Complexity — no confidence-threshold back-door) supporting.

- **SC-6**: After a full US-2 + minimal US-4 scaffold, the drift detector `scripts/verify/check-docs.sh` reports zero drift between `CLAUDE.md` and `AGENTS.md` in the `recent-changes` region; the two files' marker-bounded regions have identical bytes (or semantically-equivalent bytes under a documented transform pinned by planning).

- **SC-6a (outside-markers byte-preservation)**: After any dual-write invocation, `shasum` of content outside the `# >>> orchestrator:<region> >>>` / `# <<< orchestrator:<region> <<<` markers on both `CLAUDE.md` and `AGENTS.md` is byte-identical pre-write and post-write. Verified by `tests/test-dual-write-outside-invariant.sh` (new, shipped by this milestone). This is the mechanical expression of the FR-12 `shasum`-invariant promise — outside-markers bytes cannot drift regardless of the write being made.

- **SC-7**: A fresh `orchestrator:auto` run that dispatches `orchestrator:specify` with `--yes` produces zero Claude Code approval prompts (inheriting the M016/M021 zero-prompt baseline). Verified against the M021 prompt-corpus fixture.

- **SC-8**: No silent degradation. Every new command fails loudly — non-zero exit, clear diagnostic — when (a) `gh` auth is missing and a comment fetch is attempted, (b) the conversus adapter is absent under US-3 `y` path (per FR-6 `--strict`), (c) an amendment's source spec has drifted since classification (US-5 stale-diff case), (d) a dual-write would overwrite content outside the marker region.

- **SC-9**: Every `orchestrator:specify`, `orchestrator:comments`, and dual-write script runs under Bash 3.2 (Constitution IX) and passes `scripts/verify/anti-pattern-lint.sh` (Constitution XV + M016/M021 hardening).

- **SC-10**: Integration does not regress any existing test suite — `tests/test-*.sh` remain green with and without `.orchestrator/config.yml`'s M014-specific sections present, and with and without `AGENTS.md` present.

- **SC-11**: `references/` contains a new doc (`references/spec-management.md` or similar) documenting the Section Contract, complexity-probe thresholds, classifier shapes and thresholds, dual-write marker convention, and failure semantics — sufficient for a future maintainer to extend the surface without reading the source.

- **SC-12**: Total new shell-script count outside `scripts/comments/`, `scripts/util/dual-write-runtime-md.sh`, and `scripts/knowledge/spec-complexity-probe.sh` does not exceed a ceiling set at Phase 1 planning (scope-cap, not scope-count, per Constitution XII + XIV).

- **SC-13**: The next milestone's spec authored after M014 closes is produced by invoking `orchestrator:specify` rather than by hand-copying an existing `specs/*/spec.md` file. This is the dogfood gate — until it is exercised, M014 has not closed its own bootstrapping loop.

- **SC-14 (`--amend` byte-preservation invariant)**: On `orchestrator:specify --amend <path>` against a spec with a mix of all-placeholder (case a), partial-placeholder (case b), and fully-authored (case c) sections per FR-14: `shasum` of non-placeholder section bytes (cases b and c) is unchanged pre- and post-amend; `git diff` on the amended file shows hunks only inside placeholder-bearing sections (case a). Verified by a fixture test shipped with this milestone.

- **SC-15 (`RUNTIME-ASSUMPTIONS.md` close-out deliverable)**: At milestone close, `RUNTIME-ASSUMPTIONS.md` (the registry established by D016) contains entries for FR-3 (LLM scaffolder), FR-5 (contradiction-signal probe), and FR-7 (splitter) unconditionally. FR-9 (classifier) is included conditionally — only if planning pins an LLM-based classifier shape per Open Question #C-1. Each entry names the CC-specific assumption (the shape that only works under Claude Code runtime), the Codex/Cursor fallback shipped in v1, and the M009 parity-audit obligation for future runtime-parity work.

- **SC-16 (dogfood-data sizing for FR-9 classifier-shape decision)**: Before `orchestrator:plan-phase` pins the FR-9 classifier shape, a dogfood-data table covering ≥1 week of M012/M013 inbox volume is captured at `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` with per-class counts and representative sample comments. The FR-9 shape decision cites this file as its evidence base; SC-4's upgrade-branch activation cites it as the basis for "mechanically-measurable shape." Planning cannot pin FR-9 shape against a zero-data prior.

- **SC-17 (Template / scaffolder byte-compatibility)**: `tests/test-specify-shape.sh` (FR-18) passes in CI — scaffolder output against a fixture description byte-matches the contract derived from `templates/spec-template.md` (FR-2b). Any drift between the shipped template and the scaffolder's output fails the suite; any drift between the FR-2 inline prose and the template is resolved in favor of the template.

## Constraints

- **CON-1 (Spec is authored on disk).** Orchestrator state mutations continue to happen via existing orchestrator commands writing to `.orchestrator/` and `specs/`. This milestone adds new write-sites (`specs/<NNN>-<slug>/spec.md`, review queue, dual-write blocks) but the discipline is unchanged — every write is explicit, atomic, and reproducible (Constitution VI + IX).

- **CON-2 (CC-first for LLM-assisted paths).** FR-3 (scaffold-fill depth), FR-5 (contradiction-signal counting), FR-7 (splitter), and portions of FR-9 (classifier, if LLM-based) require an LLM round-trip and are Claude-Code-only in v1. Codex CLI and Cursor runtimes fall back to non-LLM modes (skeleton scaffold, threshold probe without contradiction signal, classifier on heuristic-only shape). Runtime-parity for LLM paths is deferred to M009's runtime-parity audit per D016. `RUNTIME-ASSUMPTIONS.md` — established by D016 — gains entries for every CC-only path added here.

- **CON-3 (Zero approval prompts in auto mode).** Every new command must not introduce Claude Code prompt triggers (inherits M016/M021 baseline). Interactive prompts (US-2 slug-accept, US-3 three-way) auto-resolve under `--yes` with documented defaults.

- **CON-4 (Invokes M011/P07 conversus adapter, does not duplicate).** US-3 pressure-test and US-1 ambiguous-comment triage both invoke `scripts/dispatch/adapters/tool/conversus.sh` via new presets under `templates/conversus-presets/`. No deliberation logic is reimplemented. Adapter absence under `--strict` fails loudly per M013/FR-13.

- **CON-5 (Spec-amendment is human-gated).** Comments classified `spec-amendment` are **never** auto-applied in v1 regardless of confidence score. The review queue is the single path for spec mutation from comments.

- **CON-6 (Bash 3.2 + anti-pattern lint clean).** All new shell scripts, hooks, and command payloads pass `scripts/verify/anti-pattern-lint.sh` and run under Bash 3.2 (Constitution IX).

- **CON-7 (No mid-milestone scope insertion; Constitution XV).** Features not in this spec are either non-goals, future work, or out-of-scope — they do not accrete during planning or execution. The four-cluster bundle (US-1/2/3/4, plus US-5 derivative) is the scope; additional Codex-native LLM paths, additional comment surfaces (Slack, Discord, email), and additional dual-write targets (e.g., `.cursorrules`) are explicitly deferred (see Non-Goals).

- **CON-8 (Idempotency everywhere).** Every command in this milestone is re-runnable without producing duplicate state: `orchestrator:specify` errors on slug collision; `orchestrator:specify --amend` preserves authored content; `orchestrator:comments classify` skips actioned comments; `orchestrator:comments apply` errors on stale diffs; dual-write is marker-bounded with byte-preservation outside. Duplicate artifacts are a bug (mirrors M013/FR-4 discipline).

- **CON-9 (Dogfood is the truth signal).** SC-4 classifier precision, FR-5 complexity thresholds, FR-9 classifier shape choice, and FR-17 threshold defaults are all pinned at planning based on M012/M013 inbox dogfood signal — not on up-front speculation. Thresholds that don't earn their keep under dogfooding can be re-tuned without a milestone amendment (Open Questions #C-1, #C-2, #C-3 defer the specifics).

- **CON-10 (GitHub as the only comment surface in v1).** Wiki Giscus (via GitHub Discussions) and GitHub Issues/PRs are the two surfaces this milestone consumes. Slack, Discord, email, or other comment surfaces are explicitly out-of-scope and future-milestone territory.

### Knowledge-Layer Boundary (M014 vs. M020)

M014 writes to the knowledge tree at exactly one new point:

1. **FR-10 auto-apply of `decision-append`-class comments**: appends entries to `.orchestrator/DECISIONS.md` (existing format; no schema authoring) citing the source comment URL.

Comments classified `uat-bug` at or above threshold route through M013/FR-10's existing UAT-ingestion path, which writes to `knowledge/spec/defect/SPEC-DEFECT-NNN.md` per M013's schema — this milestone is a *consumer* of that schema, not an author. M020 retains authority over `knowledge/spec/**` schema evolution, review-state lifecycle, query-surface, and clustering per D014.

Spec-amendment-class comments (FR-10 CON-5) are human-gated; when applied (US-5), they edit `specs/<NNN>-<slug>/spec.md` and trigger `scripts/knowledge/rebuild-index.sh` to re-version affected chunks via the M011 ingest path. Chunk-ID preservation discipline (M011/P04) is inherited; no new chunk-ID format is introduced here.

This milestone's only substrate addition is structural — the review queue (`.orchestrator/comments/review-queue/`), the inbox cache (`.orchestrator/comments/inbox/`), and the actioned log (`.orchestrator/comments/actioned.jsonl`) — all operational state for comment processing, not knowledge. These structures are forward-compatible with M020's review-state work (entries here never claim schema authority on the knowledge tree).

## Non-Goals

- **Bi-directional spec sync to GitHub beyond M013's narrow read-backs.** Spec markdown is authored in `specs/` and committed to git; GitHub Issue bodies and PR descriptions are *not* authoritative sources the orchestrator reads back to amend specs. The US-5 amend path consumes *comments*, not Issue/PR body edits.

- **Spec versioning beyond what `git` already provides.** No parallel version-history tree; no spec-specific changelog; `git log -- specs/<slug>/spec.md` is the history surface. M011 chunk-supersession handles chunk-level versioning.

- **Spec linting/validation as a separate command.** FR-4 `scripts/verify/spec-shape-lint.sh` is a utility consumed by `orchestrator:discuss` preflight — not a user-facing `orchestrator:lint-spec` command. A broader lint/validate surface (semantic checks, cross-reference validation, requirement-deduplication) is M020-territory or post-launch.

- **Auto-applying every comment classification.** Only `uat-bug` and `decision-append` above threshold auto-apply. `spec-amendment` is always human-gated (CON-5). `ambiguous` always routes through conversus triage and into human queue.

- **Codex-native LLM-assisted scaffolding / classification.** CC-first posture (CON-2) for all LLM paths in v1. Codex parity is a fast-follow, demand-driven via M009's runtime-parity audit per D016.

- **Additional comment surfaces.** Slack, Discord, email, Jira, Linear, or other non-GitHub comment systems are out-of-scope. Wiki Giscus and GitHub Issues/PRs are the only two surfaces this milestone consumes.

- **Additional runtime-instruction dual-write targets.** `CLAUDE.md` and `AGENTS.md` are the two files; `.cursorrules`, VSCode workspace `.vscode/settings.json` prompt hooks, or other runtime-instruction surfaces are deferred. Cursor runtime inherits `AGENTS.md` by convention per Cursor's published fallback.

- **Renormalizing specs authored by `/speckit.specify` on other projects.** `orchestrator:specify` is an authoring surface, not a migration tool. The existing `scripts/knowledge/normalize-spec.sh` (M011/P07) handles foreign-shape normalization on ingest; that surface is unchanged.

- **Interactive multi-turn spec-authoring UX.** The `--description` single-shot scaffold + `--amend` re-scaffold path is the v1 surface. A multi-turn back-and-forth (operator and LLM iterate through sections) is future work — possibly M023-territory (Design Layer).

- **A native CLI dashboard or TUI for the review queue.** `orchestrator:comments status` prints a plain-text list; `apply`/`reject` are CLI invocations. TUI/web surfaces are operator-tool territory, not orchestrator-shipped.

- **Auto-decomposition of specs *already* ingested.** US-3 `d` path decomposes *drafts* (Status: Draft, not yet ingested). Decomposing a shipped spec is a migration task, not an authoring task, and is out-of-scope.

- **Launch/ecosystem docs framing.** M009 (Launch) consumes the `orchestrator:specify` surface as external-facing onboarding; M014 itself does not ship stakeholder-facing marketing or public onboarding artifacts. M009 owns that.

- **Ultraplan/ultrareview-style cloud pressure-test integration.** Parked per D016 — Claude-Code-web-only surface forks multi-runtime UX. M014's pressure-test path is M011/P07 conversus-adapter invocation, which is runtime-agnostic (adapter runs wherever conversus is installed).

## Assumptions

- **M011 is complete** — provides `scripts/knowledge/ingest-spec.sh`, `scripts/knowledge/detect-spec-shape.sh`, `scripts/knowledge/normalize-spec.sh`, and the `KNOWLEDGE-INDEX.md` regeneration path. M014 consumes these; does not modify.

- **M012 is complete** — provides wiki Giscus threading and `scripts/wiki/wiki-giscus-remap.sh` pathname-keyed thread mapping. FR-8 comment fetching consumes this mapping to associate Giscus comments with spec chunks.

- **M013 is complete** — provides `orchestrator:github` command surface, UAT Bug Issue template, UAT ingestion path, and the GitHub comment surfaces the classifier consumes. FR-10 auto-apply for `uat-bug` class routes through M013/FR-10's existing path.

- **M011/P07 conversus adapter is shipped** — `scripts/dispatch/adapters/tool/conversus.sh` with `--strict` mode. FR-6 and US-1 ambiguous-triage invoke it; absence under strict mode fails loudly.

- **M019 Tier 1 emitter is shipped** — `execution-log.jsonl` append path and schema shape. FR-16 observability emission is a producer.

- **Claude Code LLM round-trip is available** under CC runtime for FR-3, FR-5, FR-7, and LLM-based FR-9 paths. Codex and Cursor paths fall back to non-LLM mode per CON-2.

- **`gh` CLI is installed and authenticated** when FR-8 comment fetching runs. Operator owns this; M013/FR-2 preflight discipline is reused.

- **Operators are responsible** for review-queue throughput. The orchestrator queues items and surfaces `orchestrator:comments status`; it does not notify externally. Notification hooks are future work.

- **Repo layout invariants** — `specs/NNN-<slug>/spec.md` layout is stable; `specs/` is git-tracked; sequential `NNN` numbering is monotonically increasing (race is handled by FR-1 lock acquisition, not by eliminating the convention).

- **`.orchestrator/config.yml` exists** — created by `orchestrator:init`; M014 adds new keys, does not introduce the file.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` (v2.1.0) for each principle M014 materially touches. Planning verifies these at plan-phase time; implementation verifies again before milestone close.

- **Principle I (Context Minimization)**: Scope is anchored on the Minimal Slice (full US-2 + minimal US-4). Full US-1/3/4 ride in Phases 2–N with named consumers (every future milestone's spec dogfoods Phase 1; M012/M013 inbox dogfood signal sizes Phase 2+). Context budget is bounded per Phase by the Minimal Slice boundary; each user story ships independently with its own dispatch payload. The bootstrapping-irony resolution is a Principle-I win — future spec authoring becomes cheaper, not more expensive.

- **Principle III (Design Before Code)**: US-2's FR-2 Section Contract *is* the design step for the scaffolded spec — every new spec lands with a mandatory design skeleton (Problem Statement, User Scenarios with Independent Tests, Constitution Check) before code. US-3's conversus-suggestion gates risky specs through adversarial review before `orchestrator:discuss`. US-4's dual-write ensures that Codex-runtime subagents are handed a templated runtime-instruction surface (not inferred). The whole milestone operationalizes "no implementation without an approved design" by making the design artifact (spec.md) mechanically producible and mechanically checkable.

- **Principle IV (Plans Assume Zero Context)**: `orchestrator:specify` produces a spec that an agent dropped into the repo cold can read without reading any other file — the `Input:` block quotes the original description, the `Minimal Slice` pins scope, the FRs and SCs are numbered and self-referential. This milestone's command outputs (specs, review-queue entries, amended specs) honor Principle IV by construction.

- **Principle V (Fresh Context Per Unit)**: Each user story plans independently within M014. FR-8 comment fetching runs in its own lock-acquired unit; FR-10 auto-apply is atomic per comment; FR-14 `--amend` preserves authored regions so a re-scaffold is a fresh unit of work on the placeholder regions only. No inherited session state.

- **Principle VI (State On Disk Is Truth)**: `.orchestrator/comments/inbox/`, `.orchestrator/comments/review-queue/`, `.orchestrator/comments/actioned.jsonl`, `specs/<NNN>-<slug>/spec.md`, and the dual-write markers in `CLAUDE.md`/`AGENTS.md` are all on-disk state. Crash recovery (e.g., mid-`apply` on a spec-amendment) derives from disk: a half-applied amendment is detected by the stale-diff check (US-5 AS-2); the actioned.jsonl is append-only with per-comment URL as the idempotency key.

- **Principle VII (Knowledge Compounds)**: `decision-append` auto-apply (FR-10) lands entries in `.orchestrator/DECISIONS.md` — the structured, discoverable compounding surface. `uat-bug` auto-apply routes through M013/FR-10's `spec/defect` knowledge entries. Spec-amendment applied via US-5 re-versions chunks through M011's ingest path. Every auto-applied comment compounds into the same three knowledge surfaces the orchestrator already cultivates; nothing gets lost to transient comment threads.

- **Principle X (Templating Over Inference)**: `orchestrator:specify` is the templating surface for spec authorship — the FR-2 Section Contract is the template; the command is the mechanic. FR-6's conversus preset is a templated declaration consumed by the M011/P07 adapter; FR-12's dual-write helper is a templated marker-bounded utility; FR-17's config keys are declarations, not inferences. No script infers what sections a spec should have at runtime — the template declares it.

- **Principle XII (Hook Isolation)**: US-3 conversus-adapter invocation inherits M013/FR-13 discipline — 30-second default timeout, `--strict` mode, no engine-state mutation. US-1 ambiguous-comment triage invokes the same adapter with the same discipline. The adapter is the integration seam; M014 writes no new hook framework.

- **Principle XIV (No Speculative Complexity)**: CON-2 narrows LLM-assisted paths to CC-first for v1 — Codex parity is back-loaded to M009's parity audit with a concrete current-demonstrable-need gate. CON-10 narrows comment surfaces to GitHub only (Giscus + Issues/PRs) — no Slack/Discord/email speculation. CON-5 narrows auto-apply to two trivial classes; spec-amendment is human-gated with no "confidence threshold that bypasses review" back-door. CON-8 narrows dual-write targets to two files (`CLAUDE.md` + `AGENTS.md`) — no `.cursorrules` / `.vscode/` speculation. FR-4 shape-lint is a preflight consumed by `orchestrator:discuss`, not a standalone `orchestrator:lint-spec` command surface.

- **Principle XV (Surgical Precision)**:

  **XV applies to** (byte-preservation / changed-lines-trace invariants):
  - FR-12 dual-write is marker-bounded with `shasum` byte-preservation of content outside markers — the M012/P04 pattern lifted verbatim (SC-6a enforces).
  - FR-14 `--amend` preserves authored prose byte-identically and re-scaffolds only placeholder regions; SC-14 expresses the byte-preservation invariant mechanically.
  - FR-13 drift-detector reports drift but does not silently reconcile — human edits are never overwritten.

  **XV does NOT apply to** (human-gate / scope-boundary disciplines — governed by Principle III + XIV instead):
  - CON-5 spec-amendment human-gate is a Design-Before-Code (III) discipline with a no-speculative-complexity (XIV) guard against confidence-threshold back-doors; SC-5 is cited under III + XIV per this retrofit.
  - CON-7 no-scope-insertion is a Principle XIV (No Speculative Complexity) + Principle XII (Hook Isolation) discipline — the four-cluster bundle defense lives there. XV's "changed-lines trace back to the original request" test is not the governing principle for scope boundaries.

  This split corrects a prior over-reach where XV was cited thematically ("surgical precision sounds like it should govern careful policies") rather than per its literal scope in `.orchestrator/memory/constitution.md` L271–L284 (XV = each changed line traces to an explicit request; a changed-lines-trace test, not an authorization-gate discipline).

## Open Questions (defer to planning)

These are **not** decisions the spec makes. They are captured so planning starts with the list.

- **#C-1 Classifier shape.** Regex/heuristic, embedding-distance-against-class-prototypes, LLM-call-per-comment, or two-pass hybrid (cheap pre-filter + LLM on residuals)? Decision is informed by M012/M013 inbox dogfood volume signal. Planning picks the shape and the fallback.

- **#C-2 Comment fetch schedule.** Manual (`orchestrator:comments classify` on demand), post-verify hook (classify after every `orchestrator:verify`), or cron (planning-documented crontab line)? Similar to M013's sync-mode trilemma; planning picks a default and documents the alternatives.

- **#C-3 Auto-apply confidence thresholds.** Per-class defaults for `uat-bug` and `decision-append`. Calibration happens after SC-4 dogfood data. Planning pins conservative initial defaults; dogfood re-tunes.

- **#C-4 Complexity-probe thresholds for US-3 auto-propose.** FR count, user-story count, raw token count, `<TODO>` density, contradiction-signal count — planning pins the thresholds. Probe emits the structured fields so dogfood data can re-tune.

- **#C-5 Dual-write: byte-identical or transform-based?** Is `AGENTS.md`'s Recent Changes region byte-identical to `CLAUDE.md`'s, or does the dual-write helper apply a documented transform (e.g., `Claude Code` → `Codex CLI` name substitution in the runtime-identification header)? Planning decides; FR-13 drift-detector follows the decision.

- **#C-6 Scaffolder prompt authorship.** `templates/spec-scaffolder-prompt.md` shape — is it monolithic, or sharded by section (one prompt per section the scaffolder fills)? Affects FR-3 LLM round-trip cost and quality. Planning picks the shape.

- **#C-7 `orchestrator:specify split` manifest path.** M024's `.orchestrator/intake/<id>/decomposition.md` convention is the target; until M024 lands, planning picks the interim path (current proposal: `.orchestrator/specify/decomposition/<id>/manifest.md`) and the migration discipline when M024 arrives.

- **#C-8 Review-queue notification surface.** Does `orchestrator:comments status` print-only, or does it also emit to a notification hook (`.orchestrator/hooks/on-queue-update/`)? V1 recommendation: print-only; planning confirms.

- **#C-9 `decision-append` block shape.** What is the exact templated block appended to `.orchestrator/DECISIONS.md` from a `decision-append`-class comment? Decision-register rows are a well-known shape; planning extends or reuses.

- **#C-10 Codex fast-follow sequencing.** D016 defers LLM-assisted Codex paths to the M009 runtime-parity audit. If Codex demand materializes mid-M014, does the LLM-path work pull into a late M014 phase, or stay in M009? Planning pins the answer and documents the condition that would re-open the question.

- **#C-11 Exhaustive `CLAUDE.md` write-site enumeration.** At `orchestrator:plan-phase` time (before P2 dual-write extension ships), planning runs `grep -rn 'CLAUDE.md' scripts/ commands/` to produce the full list of current write-sites; the phase plan commits the enumerated list as a must-have checklist. Any write-site discovered post-plan during execution triggers a phase-plan amendment (new task) rather than silent extension of the dual-write helper to an uncatalogued surface. Guards against "dual-write discipline" becoming an implicit policy that new write-sites quietly inherit without an explicit gate.

## Dependencies

- **M011 (Spec Management)** — complete. Provides `scripts/knowledge/ingest-spec.sh`, `scripts/knowledge/detect-spec-shape.sh`, `scripts/knowledge/normalize-spec.sh`, chunk-ID preservation discipline (chunk-source line metadata), and `scripts/knowledge/rebuild-index.sh` for re-version on amend.

- **M011/P07 Conversus Adapter** (`scripts/dispatch/adapters/tool/conversus.sh`) — shipped. Invoked at US-3 pressure-test and US-1 ambiguous-comment triage sites with `--strict` per M013/FR-13 discipline.

- **M012 (Spec Wiki)** — complete. Provides wiki Giscus threading and `scripts/wiki/wiki-giscus-remap.sh` pathname-keyed thread mapping consumed by FR-8 comment fetching.

- **M013 (GitHub Native Integration)** — complete (P04 final phase pending per CLAUDE.md). Provides `orchestrator:github` command surface, UAT Bug Issue template, UAT ingestion path, GitHub comment surfaces, and the orchestrator-id marker convention re-used by FR-8's idempotency discipline.

- **M019 Tier 1 emitter** — shipped. `execution-log.jsonl` append path; M014 is a producer per FR-16.

- **M016/M021 zero-prompt baseline** — shipped. M014 inherits per CON-3; SC-7 is the compliance gate.

- **`gh` CLI** — external dependency; operator-installed. FR-8 consumes; preflight per M013/FR-2.

- **Claude Code LLM round-trip** — runtime-provided under CC; fallback for Codex/Cursor per CON-2.

- **No runtime dependency on M020 or later milestones.** M014 ships standalone; M020 consumes M014's `decision-append` auto-apply as one of its knowledge-maturation inputs downstream.

## Downstream Consumers (informational, not binding)

- **Every subsequent milestone's spec** — M020, M024, M023, M018, M009, M010 specs are intended to be authored via `orchestrator:specify` rather than by hand-copying. The dogfood gate (SC-13) formalizes this. Any milestone whose author falls back to hand-copying signals a US-2 scope gap that planning should absorb as an amendment.

- **M020 (Knowledge Layer Maturation)** — consumes `decision-append` auto-apply entries and review-queue applied spec-amendments as inputs to its review-state lifecycle and query-surface work. M020 also supersedes M014's `.orchestrator/DECISIONS.md` append format if it introduces a more structured decision-log schema (forward-compatible addition, per D014 discipline).

- **M024 (Universal Intake & Routing)** — consumes `orchestrator:specify` as the downstream scaffolder invoked by its proposal-artifact router. US-3's decomposition manifest path (`.orchestrator/intake/<id>/decomposition.md`) aligns with M024's intake convention; M014/FR-7 is a pre-consumer of that path. When M024 lands, the interim path resolves onto the M024 convention.

- **M023 (Design Layer)** — consumes the scaffolded spec as the context a `orchestrator:design` invocation reads to produce DESIGN.md drafts. The spec's FR-2 Section Contract gives M023 a stable input shape.

- **M009 (Launch & Ecosystem)** — consumes `orchestrator:specify` as the primary external-adopter onboarding path ("how do you author your first spec with the orchestrator?"). **Handoff contract to M009**: M014 ships `references/spec-management.md` (SC-11), a populated `.orchestrator/config.yml` scaffold for `specify:` / `comments:` / `dual_write_agents:`, and the `orchestrator:specify`, `orchestrator:comments`, and dual-write command surfaces. M009's runtime-parity audit (per D016) consumes CON-2's `RUNTIME-ASSUMPTIONS.md` entries as a punch-list for Codex/Cursor LLM-path enablement.

- **M019 Tier 2/3 (Observability)** surfaces specify-cost, classifier-cost, conversus-cost-per-spec-draft, and comment-auto-apply-rate metrics via the execution-log emitter. M014 emits these events in the M019 Tier 1 shape per FR-16 so the rollup is free when M019 Tier 2/3 ships.

- **Future non-Claude-Code runtime-adapter milestone** — consumes FR-12 dual-write helper as the shared utility for any new runtime-instruction file ( `.cursorrules`, etc.) when demand earns it.
