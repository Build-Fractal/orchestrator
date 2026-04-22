# Feature Specification: M013 GitHub Native Integration — Opt-In Projection Of Orchestrator State Onto Issues, Milestones, And Projects

**Feature Branch**: `023-github-native-integration`
**Created**: 2026-04-21
**Last Revised**: 2026-04-21 (post-conversus red-blue deliberation; 13 MITs + 3 arbitrated rulings applied per `conversus/summary/final.md` + `conversus/arbitration/resolution.md`)
**Status**: Ready-for-discuss
**Milestone**: M013 (see `.orchestrator/milestone-summary.md`, roadmap entry "GitHub Native Integration — Issues/Milestones/Projects sync, UAT loop; invokes the M011/P07 conversus adapter for opt-in pre-merge review gates")
**Input**: User description: "M013 GitHub Native Integration: opt-in sync of orchestrator state (milestones, phases, tasks, spec chunks, acceptance criteria, verification status) to GitHub Issues, Milestones, and Projects v2. Orchestrator state on disk stays authoritative — GitHub is a projection, not a peer. Primarily push; the only read-backs are UAT issues filed against spec chunks and (via M014) comments routed into the classifier. REST-first using `gh` CLI with ≤2 GraphQL calls per sync (`createProjectV2` once, `addProjectV2ItemById` per item). Idempotency via hidden `<!-- orchestrator-id: ... -->` markers; sidecar config caches id→issue-number mapping and stores sync mode (`manual` / `on-transition` / `cron`). Reversible by deleting the config. Dogfood goal: UAT bugs filed in GitHub auto-link to the spec chunk that authored the failing acceptance criterion, enabling fast triage into execution-error / spec-gap / spec-error buckets."

## Problem Statement

The orchestrator holds the canonical record of planned and in-flight work at `.orchestrator/` — milestones, per-milestone `CONTEXT/EVALUATION/ROADMAP/SUMMARY` files, phase plans, task payloads, verification results, and the knowledge graph that binds spec chunks to phases to tests. Constitution VI (State On Disk Is Truth) says this is the substrate the orchestrator plans, dispatches, and verifies against. Constitution VII (Knowledge Compounds) says the spec→phase→test→defect chain is where cross-milestone learning lives.

That substrate is invisible to anyone who isn't reading raw markdown or the wiki (M012 ships a browseable surface, but it's a reader's view — not a work surface). Today:

1. **Stakeholders cannot see planned work in their native tools.** Product managers, designers, and non-engineering contributors track work in GitHub Issues, Milestones, and Projects boards. They cannot watch orchestrator milestones progress without opening the repo, reading markdown, and reconstructing state mentally. They cannot filter "what's blocked," "what's in verify," or "what ships this milestone" from a kanban.
2. **UAT feedback has no durable home.** When a stakeholder exercises a shipped phase and finds a bug, there is no structured place to file it that preserves the join back to the spec chunk that authored the failing acceptance criterion. Comments land in PRs (transient), Slack (searchless), or M012 wiki threads (attached to the spec, not to the work). The triage question — *is this an execution error, a spec gap, or a spec error?* — requires a human to reconstruct the link every time.
3. **Orchestrator planning cannot reach back into GitHub work.** Even if a maintainer manually creates a GitHub Issue mirroring an orchestrator task, nothing binds them. Two re-syncs later, the orchestrator has replanned but the Issue is stale; the Issue is resolved but the orchestrator doesn't know. Drift accumulates until the surfaces diverge and stakeholders stop trusting either.

M013 ships the minimum surface that fixes all three: a one-command opt-in that projects orchestrator state onto GitHub as Issues (one per phase, sub-issues for tasks), Milestones (one per orchestrator milestone), and Projects v2 (one per orchestrator milestone, with status field reflecting verification state); an idempotent re-sync that keeps the projection honest as state changes; and a UAT-bug intake that binds incoming issues back to spec chunk IDs so the triage path exists.

The scope discipline matters. M013 does **not** attempt bi-directional synchronization, comment classification, cross-repo or cross-org rollups, or a visual kanban DSL. GitHub is a projection, read mostly write-only. The two narrow read-back paths — UAT issue ingestion and (downstream, in M014) comment routing — are the only places orchestrator state depends on GitHub state.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The dogfood loop closes on a minimum subset of US-1, US-2, and US-3:

- **Full US-3**: UAT Bug Issue template + Spec Chunk ID autocomplete + ingestion into `knowledge/spec/defect/SPEC-DEFECT-NNN.md` with graph edges `{chunk, phase, tests}`.
- **Minimal US-1**: Sidecar config at `.orchestrator/integrations/github.json` with repo slug + UAT-template install marker. No Project v2 creation, no phase Issue projection at the slice boundary.
- **US-2 idempotency applied to UAT entries only**: FR-4's marker invariant extends to `spec/defect` frontmatter so re-running ingestion does not create duplicate entries.

This slice is what Phase 1 of M013 execution is expected to ship. Full US-1 projection (Issues/Milestones/Project v2) and full US-2 sync cycle ride in Phases 2–3, defended on M009 handoff (see Downstream Consumers) and M014 consumption (see Downstream Consumers) — not on loop closure.

---

### User Story 1 — Maintainer Opts In And Pushes Current Roadmap To GitHub In One Command (Priority: P1)

A maintainer on a repo that already runs the orchestrator wants stakeholders to see the current milestone's plan in GitHub. They run `orchestrator:github init` once. The command verifies `gh` CLI auth, asks whether to create a new Project v2 or attach to an existing one, creates the required labels and milestone, pushes every in-flight phase as an Issue with a `phase` label, every task as a sub-issue of its phase, and attaches each Issue to the Project v2 board with a status reflecting its orchestrator state. The command writes a sidecar config and prints a summary of what was created.

**Why this priority**: This is the entry-point experience and the whole milestone's user-visible "it works" moment. Without a working init, nothing downstream matters.

**Independent Test**: On a clean orchestrator project with at least one in-flight milestone containing ≥2 phases and ≥3 tasks across those phases, run `orchestrator:github init` against a test repo. Confirm the command completes in under 60 seconds and that the resulting GitHub state contains: one Milestone (named after the orchestrator milestone), one Project v2, the required labels (`phase`, `task`, `uat-bug`, `spec-gap` at minimum), one Issue per phase with the `phase` label, one sub-issue per task linked from its phase Issue, and each Issue attached to the Project v2 with a status value.

**Acceptance Scenarios**:

1. **Given** a project with a committed orchestrator roadmap, **When** the maintainer runs `orchestrator:github init`, **Then** the command preflights `gh auth status` and refuses (exit non-zero, clear error) if auth is missing or expired.
2. **Given** `gh` is authenticated and the repo is accessible, **When** init runs, **Then** the maintainer is prompted to create a new Project v2 or supply the ID of an existing one.
3. **Given** init completes, **When** the maintainer opens the GitHub Milestones tab, **Then** the current orchestrator milestone is listed with a completion percentage derived from closed/total sub-issues.
4. **Given** init completes, **When** the maintainer opens the Issues tab and filters by `label:phase`, **Then** every in-flight phase appears as an Issue whose body includes a hidden `<!-- orchestrator-id: <milestone>-<phase> -->` marker.
4a. **Given** the orchestrator state has phases in future-dated Planning vs. in-flight Ready/Executing/Verifying states, **When** init runs, **Then** phase and task Issues are created **lazily**: Phase Issues created on phase transition to Ready; task Issues on task transition to Ready. First-init creates Issues only for in-flight-or-ready phases. Future-dated phases project on transition, not on init (closes Open Question #1).
5. **Given** init completes, **When** the maintainer opens a phase Issue, **Then** the task-to-Issue relationship is materialized per the Sub-Issue Representation Constraint below — either under GitHub's native sub-issue tree (if init preflight detected REST availability) or via `parent:<phase-id>` / `child:<task-id>` labels with reciprocal body links (default fallback). The chosen mode is recorded in the sidecar config and reported by init.
6. **Given** init completes, **When** the maintainer opens the Project v2 board, **Then** every phase Issue is an item with a status field value matching its orchestrator state (Planning / Ready / Executing / Verifying / Blocked / Done, exact names are a planning decision).
7. **Given** init has run, **When** the maintainer inspects the working tree, **Then** a single sidecar config file (e.g., `.orchestrator/integrations/github.json`) is present and contains the orchestrator-id → issue-number map plus the chosen sync mode.

---

### User Story 2 — Re-Running Sync After State Changes Is Idempotent And Leaves No Duplicates (Priority: P1)

After init, the orchestrator state changes — a phase completes verification, a task is added, a spec chunk is superseded. A maintainer (or a post-verify hook) runs `orchestrator:github sync`. The sync walks current orchestrator state, diffs it against the sidecar cache, and emits the minimum set of upserts: updating the status field on the affected Issue, closing sub-issues whose tasks are done, creating Issues for newly added tasks. No duplicate Issues are created. No Issues are silently orphaned.

**Why this priority**: Idempotency is the contract that keeps the projection trustworthy over time. Without it, the second run breaks the first run's output, and maintainers stop re-syncing.

**Independent Test**: After US-1's init completes, advance orchestrator state (mark a task done, add a new task to an existing phase, transition a phase from Executing to Verifying). Run `orchestrator:github sync` twice back-to-back. Confirm: run #1 applies all three changes and reports `upserts=3 skipped=0 errors=0`; run #2 reports `upserts=0 skipped=N errors=0` (N is the total number of in-scope items, all unchanged); GitHub state after each run matches the orchestrator state; no Issue has a duplicate marker.

**Acceptance Scenarios**:

1. **Given** an Issue exists with marker `<!-- orchestrator-id: M013-P02-T03 -->`, **When** sync re-runs without any state change for that task, **Then** the Issue is searched-before-created (search matches the marker), skipped, and reported as `skipped`.
2. **Given** a task moves from Ready to Done in the orchestrator, **When** sync runs, **Then** the corresponding sub-issue is closed and the parent phase Issue's checklist item is checked.
3. **Given** a phase moves from Executing to Verifying, **When** sync runs, **Then** the phase Issue's Project v2 status field is updated (single GraphQL `addProjectV2ItemById`-or-equivalent call per changed item).
4. **Given** a new task is added to an existing phase's roadmap, **When** sync runs, **Then** a new sub-issue is created with a fresh marker and linked under the parent phase Issue.
5. **Given** the GraphQL leg fails mid-sync (network error, rate limit, permission), **When** sync completes, **Then** REST-created Issues still exist and the per-item cache (FR-6) records `issue_number`, `project_v2_attached`, `status_field_synced`, `last_attempt_at`, `last_error`, `schema_version` so the next sync re-attempts only the `project_v2_attached=false` / `status_field_synced=false` reattachments (resume from last committed per-item state per FR-16).
6. **Given** one upsert fails (e.g., a labels permission error on one Issue), **When** sync continues, **Then** the remaining upserts still run (each item is its own retry boundary); the failed item is reported at exit with a non-zero status and a specific diagnostic.

---

### User Story 3 — UAT Bug Filed Against A Spec Chunk Routes Into Orchestrator Triage (Priority: P1)

A stakeholder exercises a feature shipped by a recent phase, finds a defect, and opens the repo's **UAT Bug** Issue template on GitHub. The template requires a spec chunk ID (with autocomplete sourced from the orchestrator's `KNOWLEDGE-INDEX.md`). They submit the issue. A local ingestion step (manual command or hook) reads the Issue, creates a `spec/defect` knowledge entry linked in the graph to the referenced chunk, its owning phase, and the tests that covered the failing acceptance criterion. The orchestrator can then route the defect into one of three triage buckets: execution error (re-dispatch the task), spec gap (insert a clarification phase), or spec error (supersede the chunk and replan).

**Why this priority**: This is the "pays for the whole feature" user story. Without this loop, M013 is just a one-way projection; with it, the integration becomes part of how the team closes quality gaps.

**Independent Test**: Seed a test repo with a small orchestrator project, a shipped phase whose acceptance criterion references spec chunk `SPEC-US-001`, and an M013-generated issue template for UAT bugs. Open a UAT bug referencing `SPEC-US-001`. Run the ingestion step. Confirm a `spec/defect` knowledge entry is created at `knowledge/spec/defect/SPEC-DEFECT-NNN.md` with a populated graph edge set: `{chunk: SPEC-US-001, phase: M013-P02, tests: [...]}` and a status of `open`.

**Acceptance Scenarios**:

1. **Given** the UAT Bug template is installed in `.github/ISSUE_TEMPLATE/`, **When** a stakeholder opens it, **Then** a "Spec Chunk ID" field appears with an autocomplete source derived from the repo's spec-chunk catalog. The catalog source is a planning decision — candidates: (a) widen `scripts/knowledge/rebuild-index.sh` to emit all `SPEC-*` rows from `knowledge/spec/**/SPEC-*.md` into the repo-root `KNOWLEDGE-INDEX.md`, (b) add a dedicated `scripts/state/spec-chunk-list.sh` view, or (c) walk `knowledge/spec/**/SPEC-*.md` directly at init time. Today's `KNOWLEDGE-INDEX.md` covers M016's chunks only; M013 planning chooses the widening path.
2. **Given** a UAT bug is submitted with a valid chunk ID, **When** ingestion runs, **Then** a `spec/defect` knowledge entry is created, graph-linked to the chunk → phase → tests, with an `open` status and a reference back to the GitHub Issue number.
3. **Given** a UAT bug is submitted with an unknown chunk ID, **When** ingestion runs, **Then** the entry is still created but flagged `chunk-lookup-failed` for manual reconciliation — the Issue is not silently dropped.
4. **Given** a `spec/defect` entry exists, **When** a maintainer runs the orchestrator's triage flow, **Then** the defect can be routed into one of the three buckets (re-dispatch / clarification phase / supersede chunk) and the knowledge entry records which bucket was chosen.

---

### User Story 4 — Deleting The Sidecar Config Reverses The Integration Cleanly (Priority: P2)

A maintainer decides to stop syncing — perhaps the project has moved hosts, or they want to reset before re-initing against a different Project v2. They delete `.orchestrator/integrations/github.json`. From that point on, orchestrator commands (`auto`, `dispatch`, `verify`, `consolidate`) behave exactly as they did before init. No dispatch payload includes broken GitHub references; no verify step calls `gh`; no post-verify hook attempts to push. The Issues, Milestones, and Project already created on GitHub remain in place (not deleted — the config removal is a local opt-out, not a destructive remote cleanup).

**Why this priority**: Reversibility is what lets maintainers opt in without fear. If init is a one-way door, adoption stalls. P2 rather than P1 because it is a property of the surface area, verifiable without significant new machinery — but it must hold.

**Independent Test**: Run `orchestrator:github init` on a test project, confirm end-to-end sync works. Delete `.orchestrator/integrations/github.json`. Run `orchestrator:auto` on a small phase. Confirm no `gh` subprocess is spawned, no warning about missing GitHub config blocks execution, and the phase completes normally. Inspect the remote repo: the previously created Issues and Project still exist (no destructive cleanup happened on the client side).

**Acceptance Scenarios**:

1. **Given** init has been run and a sidecar config exists, **When** the maintainer deletes `.orchestrator/integrations/github.json`, **Then** subsequent orchestrator commands run without referencing GitHub (no `gh` calls, no warnings about missing config blocking execution, no dangling sync hook).
2. **Given** the config has been deleted, **When** the maintainer runs `orchestrator:github status` or any other M013 command, **Then** the command reports "integration not configured" and exits non-zero cleanly (it does not attempt to auto-reinit).
3. **Given** a post-verify hook was installed at init, **When** the config is deleted, **Then** the hook's activation path is guarded (the hook no-ops when the config is missing — it does not error and does not silently call `gh`).

---

### User Story 5 — Post-Verify Hook Keeps The Projection Fresh Without A Daemon (Priority: P2)

A maintainer sets sync mode to `on-transition`. After each phase transition (verify success, verify failure, task completion), the orchestrator's post-verify hook invokes `orchestrator:github sync` as a follow-up step. The GitHub projection stays current without the maintainer running sync manually. No webhooks, no CI scheduling, no daemon process.

**Why this priority**: Manual sync works (US-2) but creates drift by design. On-transition sync keeps GitHub honest during normal orchestrator use. P2 because manual sync is a workable fallback — on-transition is an ergonomic win, not a blocker.

**Independent Test**: After US-1 init with sync mode set to `on-transition`, run a small phase through to completion. Confirm the GitHub Issue for that phase closes automatically without a manual sync invocation, and the Project v2 status field reaches its terminal value.

**Acceptance Scenarios**:

1. **Given** init writes `sync_mode: on-transition` to the config and the runtime is Claude Code, **When** a phase's verify step completes, **Then** the post-verify hook invokes sync as its final step before returning.
2. **Given** init runs on Codex CLI or Cursor and the operator requests `sync_mode: on-transition`, **When** init completes, **Then** the sidecar config is written with `sync_mode: manual` and init prints a clear diagnostic: "`on-transition` mode requires Claude Code runtime in v1; falling back to `manual`. Non-Claude-Code handler registration is deferred to a future runtime-adapter milestone." (per FR-12 v1 scope decision).
3. **Given** sync mode is `manual`, **When** verify completes, **Then** no sync is triggered automatically (manual only).
4. **Given** sync mode is `cron`, **When** a maintainer runs the documented cron entry on schedule, **Then** sync runs with the same semantics as manual invocation. (Cron scheduling itself is operator-side configuration, not an orchestrator-managed daemon.)
5. **Given** the hook fails (network, auth), **When** verify would otherwise have succeeded, **Then** verify still succeeds — the hook failure is reported as a warning, not as a verify regression.

---

### User Story 6 — Conversus Pre-Merge Review Gate At The M013 UAT PR Gate (Priority: P2)

A maintainer opts into a pre-merge review gate on PRs that close UAT defects. Before such a PR merges — the single D007-named "M013 UAT PR gate" site — the M011/P07 conversus adapter is invoked against the PR's context (the spec chunks touched, the verification artifacts for the defect-covering phase). The adapter's verdict is posted as a comment on the Issue / PR; the exit code blocks or allows the merge. The gate is opt-in per phase type via `github.json` configuration. Additional invocation sites (milestone close, phase Verifying→Done edges, etc.) are explicitly out of scope for v1; M014 and later milestones may add their own invocation sites per D007's consumer-invocation charter.

**Why this priority**: The roadmap explicitly calls for M013 to invoke the M011/P07 conversus adapter at opt-in gate points. P2 because the adapter itself is a dependency shipped elsewhere; this milestone wires one invocation point (the UAT PR gate) and respects opt-in configuration, without reimplementing deliberation.

**Independent Test**: With the conversus adapter available, enable the pre-merge gate for one phase type. Land a PR that closes a UAT defect issue. Confirm the adapter is invoked exactly once at the UAT PR gate, its verdict is posted as a comment on the Issue / PR, and the merge is blocked or allowed per the adapter's return code.

**Acceptance Scenarios**:

1. **Given** the config enables the gate for a phase type, **When** a UAT-defect-closing PR reaches the pre-merge check, **Then** the M011/P07 conversus adapter is invoked with a payload containing the phase's spec chunks and verification results.
2. **Given** the adapter returns a block verdict, **When** the PR would otherwise merge, **Then** the merge is blocked and the adapter's verdict is posted as a comment on the Issue / PR.
3. **Given** the gate is disabled for this phase type in `github.json`, **When** a UAT-defect-closing PR reaches the pre-merge check, **Then** the gate is skipped and the PR is not blocked.
4. **Given** the adapter is not available (not installed / disabled), **When** the gate is configured, **Then** M013 invokes the adapter in `--strict` mode so it exits non-zero with a `FAIL:` diagnostic (instead of the adapter's default graceful `SKIPPED: ... exit 0`), sync surfaces the diagnostic, and the transition does not silently proceed.

---

## Functional Requirements

- **FR-1**: `orchestrator:github` command surface provides at minimum three subcommands: `init` (one-time setup), `sync` (walk state + upsert), `status` (report config + last sync + cache summary). Commands live as markdown definitions in `commands/` following the existing pattern.
- **FR-2**: `init` preflights `gh auth status` and refuses with a clear, actionable error if auth is missing, expired, or scopeless. `init` supports four auth modes: personal PAT (classic), personal PAT (fine-grained), GitHub App installation token, and the `gh` CLI's own OAuth session. Required scopes per mode are enumerated in `references/github-integration.md` (see SC-11). `init` detects the authenticated principal, enumerates its scopes, and refuses with a specific missing-scope diagnostic if Projects v2 permissions are absent. `orchestrator:github status` reports the last time `gh auth status` was verified and warns if that timestamp is older than 60 days. Rotation is operator-owned; the orchestrator does not refresh tokens.
- **FR-3**: The mapping from orchestrator state to GitHub resources is exactly: orchestrator milestone ↔ GitHub Milestone + one Project v2; orchestrator phase ↔ Issue with `phase` label; orchestrator task ↔ sub-issue via the sub-issue REST link where available, else via the **labeled parent/child** fallback pinned by the Sub-Issue Representation Constraint below (`parent:<phase-id>` label on the phase Issue, `child:<task-id>` label on each task Issue, plus reciprocal Issue-body links); spec chunk ↔ custom field on the Issue whose value is the chunk's wiki URL (URL scheme pinned in `wiki/URL-SCHEME.md` — M012 addendum); acceptance criterion ↔ checklist item in the Issue body linking back to the chunk; verification status ↔ Project v2 status field. Init preflights sub-issue REST availability alongside `gh auth status` and reports to the operator which representation mode will be used; the choice is recorded in the sidecar config. Checklist-items-only representation is explicitly rejected — it breaks US-3's first-class-Issue contract for task-level UAT ingestion.
- **FR-4**: Every orchestrator-generated Issue body includes a hidden HTML comment of the form `<!-- orchestrator-id: <orchestrator-id> -->` where the id is deterministic and stable across re-syncs (format: `M###-P##` for phases, `M###-P##-T##` for tasks). Sync searches-by-marker before creating; finding a match means upsert, not duplicate. The marker invariant is the GitHub-surface analogue of M012's `# >>> M012-P0N <scope>` marker-bounded pattern (see `M012-SUMMARY.md` patterns_established, "marker-bounded atomic writes"); planning should reuse the same `shasum` byte-identity invariant-verification idiom where applicable.
- **FR-5**: REST calls (via `gh issue`, `gh issue edit`, `gh issue comment`, `gh api` for sub-issue linkage, `gh label`, `gh milestone`) perform ≥90% of writes. GraphQL usage is limited to **three distinct call shapes**: `createProjectV2` (once, during `init`), `addProjectV2ItemById` (per Issue attached to the Project v2), and `updateProjectV2ItemFieldValue` (per status transition). No other GraphQL shapes are added without a spec amendment; CI lints the call-shape set.
- **FR-6**: A single sidecar config file at `.orchestrator/integrations/github.json` stores: `schema_version` (integer, current cache schema version, for future migration), repo slug, Project v2 ID (if attached / created), sync mode (`manual` / `on-transition` / `cron`), recommended cron expression, optional custom-field mappings, and a per-item cache under `items.<orchestrator-id>` with the following enumerated fields:

  ```json
  {
    "schema_version": 1,
    "repo_slug": "...",
    "project_v2_id": "...",
    "sync_mode": "manual|on-transition|cron",
    "recommended_cron": "*/15 * * * * ...",
    "custom_field_mappings": [],
    "items": {
      "<orchestrator-id>": {
        "issue_number": 0,
        "project_v2_attached": true,
        "status_field_synced": true,
        "last_attempt_at": "<iso-8601>",
        "last_error": null,
        "schema_version": 1
      }
    }
  }
  ```

  The per-item shape underwrites US-2 AS #5's resume-after-partial-GraphQL contract and gives FR-17's emission concrete fields to surface. The file is human-readable JSON with a schema documented in `references/github-integration.md` (SC-11). When `init` is dispatched under auto-mode without live network/auth (parallel to M012's `DEPLOY-RECORD.md` first-deploy path), the initial config is written with a `pending`-sentinel block (e.g., `repo_slug: pending`, `project_v2_id: pending`, empty `items`) that the human operator completes on first live run; this reuses the pending-sentinel pattern established by M012/P04.

  **Pending-sentinel is not graceful degradation**: no sync runs, no projection occurs, and `orchestrator:github status` reports `pending-operator-complete` until the operator completes the config on first live run. Non-init M013 commands error with `integration not configured: run 'orchestrator:github init' to complete setup` when any top-level field holds the `pending` sentinel. "Config absent" (FR-11 reversibility) and "config pending" are two labels for one binary not-yet-live state — preserving the M007 no-dual-code-path discipline. Reversibility-by-delete (FR-11) works on pending configs identically to completed configs. Pattern inherited from M012/P04's `DEPLOY-RECORD.md` first-deploy path; validated.
- **FR-7**: A single sync script (`scripts/integrations/github-sync.sh` or equivalent; exact path is a planning decision) walks orchestrator state, computes a desired-state manifest, diffs against the sidecar cache, and emits per-item upserts. Each item is its own retry boundary — one failure does not abort the remaining items. Per-item retry explicitly excludes rate-limit responses: rate-limit errors (see FR-16) abort the GraphQL-dependent portion of the run and are not re-attempted per-item within the same run. Sync acquires `scripts/lifecycle/lock-manager.sh` for its duration; concurrent `orchestrator:github sync` invocations serialize via that lock (or fail fast per existing lock semantics).
- **FR-8**: The sync script reports at exit: counts of `upserts`, `skipped`, `errors`, with a per-error summary naming the orchestrator-id, the GitHub resource it targeted, and the underlying error. Exit non-zero if any errors occurred.
- **FR-9**: A UAT Bug Issue template (`.github/ISSUE_TEMPLATE/uat-bug.yml` or equivalent) ships as part of init; the template requires a "Spec Chunk ID" field. Autocomplete is sourced from a generated list derived from `.orchestrator/KNOWLEDGE-INDEX.md` at init time (or on explicit `orchestrator:github refresh-index`). The widening of `scripts/knowledge/rebuild-index.sh` is scoped to **additive emit-pass only**: a flat list of `{chunk_id, title, phase_id}` records where `chunk_id` is pinned to existing `SPEC-*` IDs from `knowledge/spec/**/SPEC-*.md` frontmatter (no composite addressing, no new ID format authored here). FR-9 explicitly does **not** ship: (a) a review/unreviewed state model on knowledge entries, (b) a dispatch-callable query/search surface, or (c) clustering / graph-traversal affordances — all three are M020 scope per D013. See the Knowledge-Layer Boundary subsection under Constraints.
- **FR-10**: An ingestion path (command or post-verify hook) reads UAT bug Issues, creates `spec/defect` knowledge entries graph-linked to the referenced chunk, the owning phase, and the tests that covered that chunk's acceptance criteria. Unknown chunk IDs are flagged but not silently dropped.
- **FR-11**: Reversibility: deleting `.orchestrator/integrations/github.json` returns orchestrator commands to pre-integration behavior. No command path errors because the config is missing; no command path silently re-inits; `orchestrator:github status` reports "not configured."
- **FR-12**: Sync modes `manual` / `on-transition` / `cron` are supported. In `on-transition`, a post-verify hook invokes sync as a follow-up step after verify completes. In `cron`, a documented cron line performs the same invocation at a user-chosen interval (orchestrator does not manage cron registration). Hook and cron failures surface as warnings; they do not regress verify. **Engine-level POST_VERIFY framework**: the orchestrator engine already ships a POST_VERIFY phase at `scripts/engine/run.sh` L353–356, with templated hook descriptors under `packaging/bundle/hooks/` (`after-implement.json`, `after-tasks.json`, `before-commit.json`, `before-implement.json`, `before-tasks.json`) consumed by the three-runtime installer tree (`packaging/install/install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`). M013 does **not** author a new hook framework; it adds a new hook **descriptor** (`packaging/bundle/hooks/post-verify.json`) registered as a Claude Code handler — this is handler registration, not primitive authoring. **v1 scope (per arbiter ruling)**: handler installation is Claude-Code-only for v1, wired by a one-line addition to `packaging/install/install-claude-code.sh`. Codex CLI and Cursor installer registration is deferred to a future runtime-adapter milestone; on those runtimes, US-5's `on-transition` mode falls back to `manual` sync at init with a clear diagnostic. Hook-failure-is-warning semantics apply uniformly across runtimes.
- **FR-13**: Conversus integration: M013 does not re-implement deliberation. It invokes the M011/P07 conversus adapter (`scripts/dispatch/adapters/tool/conversus.sh`) at the single D007-named UAT PR gate invocation site (US-6) with `--strict` enabled (so a missing adapter exits non-zero with a diagnostic rather than the adapter's default graceful-SKIPPED behavior). The `--strict` flag is M011/P07 authored — see `scripts/dispatch/adapters/tool/conversus.sh` L239–244 and the adapter header documentation; the adapter comment explicitly cites "M013 pre-merge gate, US-6 AS-4" as the anticipated consumer. M013 is the invoking caller; the adapter is the authoring owner. No amendment to the adapter is needed. Enablement is configured per phase type via `github.json` (explicit opt-in; there is no runtime coupling to the intensity engine in v1 — an intensity-engine policy surface for gate enablement is deferred to a later milestone that cites a concrete engine hook). Adapter invocation is bounded to a 30-second default timeout (operator-configurable up to a planning-set ceiling per Constitution XII Hook Isolation); timeout is treated as a `--strict` failure and exits non-zero. The adapter's verdict is posted as an Issue / PR comment and gates or allows the transition per its return code.
- **FR-14**: Init is repeatable — running it again after an initial run either reconciles against the existing config (reporting what is already set up) or prints a clear message on what would change, without creating duplicate Milestones/Projects/Labels. **Re-init adoption via marker search**: when the sidecar config is absent but the target repo contains Issues bearing orchestrator-id markers (prior sync's artifacts), re-init adopts them by marker-search before creating — it does not delete remote resources, and it does not create duplicates. Re-init repairs a missing sidecar from remote state; the `pending`-sentinel path (FR-6) handles the inverse (sidecar present, remote not yet populated). Closes Open Question #3. **Label-collision preflight**: init enumerates pre-existing labels matching names it would create (`phase`, `task`, `uat-bug`, `spec-gap`) and either adopts them without modifying color/description, or — if `--strict-labels` is passed — refuses with a diagnostic. Adoption is the default (dogfood + greenfield adopters); refuse-mode is for external adopters with existing label conventions.
- **FR-15**: Both `init` and `sync` support a `--dry-run` that prints the upsert manifest (Issues that would be created, Project items that would be attached, labels that would be added, per-item status transitions that would be applied) without calling any write endpoint. The manifest format is identical across `init --dry-run` and `sync --dry-run`.
- **FR-16** (Rate-limit + auth-expiry detection): Sync detects GitHub rate-limit responses (HTTP 403 with `X-RateLimit-Remaining: 0`, or GraphQL `RATE_LIMITED` verbatim) and does not auto-retry within the rate-limit window; the `retry-after` header value surfaces in the exit diagnostic. Sync detects auth expiry (HTTP 401 + `gh auth status` reporting stale) and surfaces a pointer to `gh auth refresh`. Resume semantics: partial sync resumes from the last committed per-item cache entry (FR-6 `items.<orchestrator-id>` schema). Before runs with projected GraphQL volume > 50 mutations, sync issues one `gh api rate_limit` pre-flight probe and exits non-zero with a budget diagnostic if remaining budget is insufficient. On rate-limit hit, GraphQL-dependent upserts abort; REST items already succeeded remain committed in the cache. Sync reports `rate_limit_remaining` in its exit summary (per FR-8).
- **FR-17** (Observability emission): Every `orchestrator:github sync` run emits a `unit_close` JSONL record to `.orchestrator/execution-log.jsonl` in the M019 Tier 1 shape, including `{upserts, skipped, errors, elapsed_ms, rest_calls, graphql_calls, rate_limit_remaining, source: "runtime"}`. Every conversus-gate invocation fired under FR-13 emits a `conversus_gate_invocation` record with `{gate_id, adapter_version, verdict, llm_calls, elapsed_ms, estimated_cost_usd}`. M019 owns schema evolution; M013 is a producer. This closes the auditability contract D009 named (cost metrics paired with quality metrics from day one to avoid Goodhart).
- **FR-18** (Cache reconciliation): `orchestrator:github status --verify-cache` probes remote state (Issue existence, Project v2 attachment, status field values) and flags cache/remote divergence (missing remote Issue for a cached item, missing cache entry for a marker-bearing remote Issue, status-field mismatch). Divergence is reported; repair is not automatic — the operator invokes `orchestrator:github sync` to reconcile or `init` to re-adopt via marker search (FR-14). Composes with FR-7's lock acquisition and FR-17's emission so divergence is observable.

## Success Criteria

- **SC-1**: From a test orchestrator project with one milestone containing ≥2 phases and ≥3 tasks, `orchestrator:github init --dry-run` prints a manifest matching the expected resources; the same command without `--dry-run` completes in <60 seconds and the resulting GitHub state contains all expected resources with correct labels, markers, and Project attachments.
- **SC-2**: Re-running `orchestrator:github sync` with zero orchestrator state change reports `upserts=0 errors=0 skipped=N` (where N is the total item count). No duplicate Issues exist (marker search before create verified).
- **SC-3**: After a partial-failure scenario (GraphQL leg fails, or one Issue's label edit fails), REST-created Issues still exist and the next sync successfully reattaches them — no manual remediation required.
- **SC-4**: A UAT bug filed via the installed template with a valid spec chunk ID is ingested into `.orchestrator/knowledge/spec/defect/` with graph edges to chunk → phase → tests, and its knowledge entry survives a full `orchestrator:consolidate` run.
- **SC-5**: Deleting `.orchestrator/integrations/github.json` and then running `orchestrator:auto` on a small phase completes without any `gh` subprocess, any config-missing warning blocking execution, or any unexpected failure — verified by a subprocess trace or equivalent.
- **SC-6**: Every `orchestrator:github` command runs under Bash 3.2 (Constitution IX) and passes `scripts/verify/anti-pattern-lint.sh` (Constitution XV + M016/M021 hardening).
- **SC-7**: A fresh `orchestrator:auto` run on a phase that exercises the on-transition hook produces zero Claude Code approval prompts (inheriting the M016/M021 zero-prompt baseline).
- **SC-8**: No silent degradation at runtime (sync, verify, hook invocation). `init` and `sync` fail loudly — non-zero exit, clear diagnostic — when `gh` is not authenticated, when GitHub rate limits are hit (per FR-16), or when required scopes are missing. Auto-mode authoring produces an operator-visible `pending` sentinel (per FR-6); this is an explicit operator-handoff artifact, not a silent-success branch.
- **SC-9**: *If US-6 is in-scope for this milestone cut*, the conversus gate hook point is exercised in at least one end-to-end test at the UAT PR gate (per FR-13): adapter invoked, verdict posted as a comment, transition blocked or allowed per return code. If the adapter is absent, sync errors with a pointer rather than silently proceeding. If planning defers US-6, SC-9 is marked N/A for the cut; the gate wiring remains dormant until enabled.
- **SC-10**: Integration does not regress any existing test suite — `tests/test-*.sh` remain green with and without `.orchestrator/integrations/github.json` present.
- **SC-11**: `references/` contains a new doc (`references/github-integration.md` or similar) documenting the mapping table, marker format, sidecar schema, sync modes, auth modes and required scopes (per FR-2), and failure semantics — sufficient for a future maintainer to extend the integration without reading the source.
- **SC-12**: Total new shell-script count outside `scripts/integrations/` and hook-contract LOC do not exceed ceilings set at Phase 1 planning. The spec pins the shape of the cap (scope-cap, not scope-count) per Constitution XII (hook isolation) + XIV (no speculative complexity); planning pins the specific ceilings.
- **SC-13**: Per-operator recurring overhead after adoption — time spent on auth rotation, rate-limit diagnostics, and cache reconciliation — is bounded by a ceiling set at Phase 1 planning (measured in hours/quarter/operator). Exceeding the ceiling during dogfooding is signal for M009 launch docs to recommend GitHub App over PAT (see new Open Question on PAT-vs-App default).

## Non-Goals

- **Bi-directional synchronization beyond the two narrow read-backs.** The read-backs are (1) UAT issue ingestion and (2) comment routing (M014). Anything beyond that — reading back Issue edits, reopening closed issues back into orchestrator state, treating GitHub labels as orchestrator scope tags — is out of scope.
- **Comment classification, triage, or auto-apply.** That is M014's scope. M013 ships the Issues and the UAT template; M014 ships the classifier that routes their comments.
- **GitHub UI as a planning surface.** Orchestrator state is authored on disk via the orchestrator's commands. Users who edit an Issue body on GitHub and expect the orchestrator to pick it up will not see that behavior in M013. (That path, if ever added, is a separate milestone.)
- **Webhooks, daemons, or long-running sync processes.** Sync is triggered by explicit invocation: manual command, post-verify hook, or operator-owned cron. No webhook receiver, no sidecar service.
- **Multi-repo or organization-wide rollup.** One orchestrator project syncs to one GitHub repo's Issues/Milestones/Projects. Cross-repo roadmaps or org-wide Project v2 rollups are out of scope.
- **Non-GitHub hosts** (GitLab, Bitbucket, Forgejo, etc.). M013 is a GitHub-specific adapter. Future host adapters, if warranted, live in parallel namespaces.
- **View configuration beyond initial creation.** Board column order, saved views, filter presets — orchestrator writes them at init time (if at all) and never touches them after. Operators own view ergonomics.
- **Custom-field auto-population beyond explicit mappings.** Orchestrator writes to a custom field only if the operator has mapped it in the sidecar config. No guessing.
- **A native CLI dashboard or TUI for Issue browsing.** Stakeholders use GitHub's web UI or `gh` CLI. The orchestrator does not ship its own Issues viewer.
- **Migration from pre-existing hand-maintained Issues/Projects.** Init assumes a clean slate for the resources it creates. Operators who have manually created overlapping issues are responsible for reconciling first; the marker-based idempotency handles only orchestrator-originated resources.
- **Launch/ecosystem docs framing.** M009 (Launch) consumes this integration as a feature; M013 itself does not ship stakeholder-facing marketing or public onboarding artifacts.

## Constraints

- **GitHub is a projection.** Orchestrator never reads GitHub state to decide what to plan, dispatch, or verify. The two exceptions (UAT ingestion, M014 comment routing) are narrow, explicit read-backs with clearly documented boundaries.
- **REST-first.** ≥90% of writes go through `gh` subcommands. ≤2 GraphQL calls per run, limited to `createProjectV2` (once, at init) and `addProjectV2ItemById` (per attach/update).
- **Idempotency via marker.** Every Issue body carries `<!-- orchestrator-id: <id> -->`. Sync must search-by-marker before creating. A duplicate marker is a bug.
- **Per-item retry boundaries.** One failed upsert does not abort the remaining items. Each item's success/failure is recorded in the cache.
- **Opt-in and reversible.** No behavior change until `init` runs; deleting the sidecar config cleanly restores pre-integration behavior.
- **One runtime dependency added.** `gh` CLI. Nothing else (no Node, no Python, no extra libraries).
- **Bash 3.2 compatibility** (Constitution IX) and anti-pattern lint clean (Constitution XV + M016/M021) for all shipped shell scripts, hooks, and command payloads.
- **Zero approval prompts in auto mode.** The on-transition hook must not introduce Claude Code prompt triggers (inherits M016/M021 baseline).
- **Invokes M011/P07 conversus adapter.** Does not duplicate deliberation logic. If the adapter is required and absent, error loudly; do not silently proceed.
- **Disk state stays authoritative.** All orchestrator state mutations continue to happen via existing orchestrator commands writing to `.orchestrator/`. The integration's writes to GitHub and its sidecar cache are a side effect of those existing state transitions.
- **No mid-milestone scope insertion** (Constitution XV — Surgical Precision). Features not in this spec are either non-goals, future work, or out-of-scope — they do not accrete during planning or execution.

### Sub-Issue Representation Constraint

Where GitHub's sub-issue REST link is unavailable on the target repo's plan, the task-to-phase relationship is materialized via **labeled parent/child**: `parent:<phase-id>` label on the phase Issue, `child:<task-id>` label on each task Issue, plus reciprocal Issue-body links naming the counterpart Issue number. The sub-issue REST link is preferred when available. Checklist-items-only representation is explicitly rejected as a fallback — it demotes task-level Issues to non-first-class artifacts and breaks US-3's task-level UAT ingestion contract (US-3 AC-2). Init preflights sub-issue REST availability alongside `gh auth status` and commits the chosen mode to the sidecar config; the mode is reported to the operator in the init summary. This Constraint settles the former Open Question #7.

### Knowledge-Layer Boundary (M013 vs. M020)

M013 writes to the knowledge tree at exactly two points:

1. **FR-9**: widens `scripts/knowledge/rebuild-index.sh` to emit a flat list of `{chunk_id, title, phase_id}` records into `KNOWLEDGE-INDEX.md` (additive-emit only; no query surface; no review-state; no clustering). `chunk_id` is pinned to existing `SPEC-*` IDs from `knowledge/spec/**/SPEC-*.md` frontmatter — no new ID format is authored here.
2. **FR-10**: writes `spec/defect` entries at `knowledge/spec/defect/SPEC-DEFECT-NNN.md` with entity-reference edges `{chunk, phase, tests}` and `status: open` frontmatter.

Knowledge-substrate maturation — review-state lifecycle, dispatch-callable query surface, entry clustering — is M020 territory (per `.orchestrator/DECISIONS.md` D013). M013's `spec/defect` schema is forward-compatible with M020's additive extensions; SC-4 verifies `consolidate` survival. M020's planning will verify M013-entry extension compatibility.

This is a sequencing bet: M013 widens the index pragmatically and accepts that M020 may redesign the query surface built on top of the flat list; if M020 ships first, this widening is unnecessary. The flat-list format is deliberately minimal to avoid authoring the chunk-metadata schema M020 will inherit.

## Assumptions

- **`gh` CLI is installed and authenticated** on the operator's machine at init time and remains so during syncs. If not, commands fail loudly per FR-2.
- **The target repo has Issues, Milestones, and Projects v2 enabled** and the authenticated user has permissions sufficient to create labels, Milestones, and Projects v2, and to create and edit Issues. These are deploy-time prerequisites, not features this milestone provides.
- **The target repo has Discussions enabled** (inherited from M012's Giscus prerequisite). This is a shared operational prerequisite between M012 and M013.
- **The orchestrator-id format** (`M###-P##-T##`) is stable. Renumbering milestones or phases after init is an edge case treated as out-of-scope for v1; if it happens, operators re-init (FR-14 re-adopts via marker search).
- **The M011/P07 conversus adapter is installed** when the pre-merge gate is enabled. If absent, the gate errors; it does not silently skip.
- **The repo-root `KNOWLEDGE-INDEX.md`** is a trustworthy source of chunk IDs for the UAT template autocomplete once widened per FR-9's additive-emit pass (flat `{chunk_id, title, phase_id}` list; `chunk_id` pinned to existing `SPEC-*` frontmatter). Autocomplete is refreshed at init and on explicit re-run; it is not live.
- **Operators are responsible for cron registration** when sync mode is `cron`. The orchestrator documents the line; it does not install cron itself.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` (v2.1.0) for each principle M013 materially touches. Planning verifies these at plan-phase time; implementation verifies again before milestone close.

- **Principle I (Context Minimization)**: scope is anchored on the Minimal Slice (full US-3 + minimal US-1 scaffolding + US-2 idempotency for UAT entries). Full US-1/US-2 projection is deferred to Phases 2–3 with named downstream-consumer justification (M009 handoff, M014 consumption). Context budget is bounded per Phase by the Minimal Slice boundary; each user story ships independently with its own dispatch payload.

- **Principle V (Fresh Context Per Unit)**: each user story plans independently within M013. FR-7 sync acquires a single lock-manager lock so concurrent invocations serialize rather than interleave; per-item cache entries (FR-6) give resumable units so partial-failure recovery does not require session continuity. Planning units inherit the spec's scope decisions — the Minimal Slice boundary prevents silent scope expansion across phase boundaries.

- **Principle VI (State On Disk Is Truth)**: `.orchestrator/` remains the authoritative substrate. The sidecar config at `.orchestrator/integrations/github.json` (FR-6) and the cache within it are on-disk state; recovery semantics (FR-11 reversibility-by-delete; FR-14 re-init adoption via marker search) derive entirely from disk state. GitHub state is a projection — the only read-backs are UAT ingestion (FR-10) and M014 comment routing, both narrow and documented. The prior draft incorrectly cited VI as the architectural grounding for projection-not-peer; that citation is retracted — projection-not-peer is grounded on Principle XIV (no speculative complexity), M007 no-graceful-degradation, and `.orchestrator/DECISIONS.md` D007 (adapter-consumer pattern). VI is honored by on-disk cache recoverability, not by read-source exclusivity.

- **Principle VII (Knowledge Compounds)**: `spec/defect` entries (FR-10) are the structured, discoverable artifact M013 produces — graph-linked to chunk → phase → tests so the defect trail compounds across milestones. FR-9's index widening is bounded by the Knowledge-Layer Boundary subsection — additive emit only, forward-compatible with M020's review-state and query-surface work. M020's planning verifies M013-entry extension compatibility (accepted risk A-2).

- **Principle X (Templating Over Inference)**: FR-12's post-verify hook is declared as a templated descriptor under `packaging/bundle/hooks/` (existing surface, 5 descriptors shipped), consumed by the three-runtime installer tree. M013 adds one new descriptor (`post-verify.json`) — it does not author a new hook framework. The conversus gate's enablement is declared in `github.json` per phase type (FR-13); there is no runtime inference of gate points.

- **Principle XII (Hook Isolation)**: FR-13 adapter invocation is bounded to a 30-second default timeout (operator-configurable up to a planning-set ceiling); timeout is treated as a `--strict` failure. US-5.4 pins hook-failure-is-warning semantics — the post-verify hook cannot regress verify. Together FR-12 and FR-13 express the full XII envelope: isolated snapshot input, bounded timeout, no engine-state mutation.

- **Principle XIV (No Speculative Complexity)**: US-4 (reversibility) is defended on SC-10 (existing test suites remain green) — the surface is verifiable without new machinery. US-5's `on-transition` mode is narrowed to Claude-Code-only for v1 per the arbiter ruling on FR-12 scope; Codex CLI and Cursor registration is deferred to a runtime-adapter milestone with a current, demonstrable consumer. US-6 is narrowed to a single D007-named invocation site (the UAT PR gate); additional sites are out of scope for v1. FR-9 widening is narrowed to additive-emit only, explicitly forbidding M020-scoped affordances.

- **Principle XV (Surgical Precision)**: FR-11 reversibility (delete-the-sidecar = clean opt-out) is the XV boundary — opting in does not write orchestrator behavior that can't be undone locally. FR-6 `pending` sentinel is an operator-gated outcome, not a dual-code-path graceful-degradation (M007 discipline preserved). The Minimal Slice subsection pins the Phase 1 scope mechanically so planning cannot silently expand.

## Open Questions (defer to planning)

These are **not** decisions the spec makes. They are captured so planning starts with the list. Questions closed by this spec revision (eager-vs-lazy #1, out-of-band deletion #3, conversus gate hook points #6, sub-issue fallback #7) have been moved into the relevant FRs / Constraints and are no longer open.

- **Project v2 status field values.** Exact names and ordering (Planning / Ready / Executing / Verifying / Blocked / Done vs. some variant). Affects board readability. A planning decision with small stakes.
- **Post-verify hook install descriptor shape for Claude Code.** Exact descriptor file location under `packaging/bundle/hooks/` and the shape of the one-line installer wiring in `packaging/install/install-claude-code.sh`. (Codex CLI and Cursor registration is out of scope per FR-12 v1.)
- **`--dry-run` manifest format.** Plain text vs. JSON. Affects whether downstream tools can parse the manifest for diffing.
- **UAT ingestion trigger.** Manual command vs. cron pull. This milestone constrains to "no webhooks" (see Constraints). Planning chooses which is the default.
- **Custom-field mapping ergonomics.** How operators declare the mapping in `github.json` — by field name, by field ID, or both. Affects first-run UX.
- **Cross-milestone re-init.** When a new milestone begins, does init need to be re-run, or does sync auto-detect the new milestone and create its Milestone + Project? Recommend the latter; planning confirms.
- **PAT-vs-App default for M009 external-adopter onboarding.** Whether launch docs (M009) recommend personal PAT, GitHub App, or let the operator choose. Informed by SC-13 per-operator overhead measured during M013 dogfooding. Planning picks; M013 supports all three modes (FR-2).

## Dependencies

- **M011 (Spec Management)** — complete. Provides chunk IDs (`SPEC-*`) and repo-root `KNOWLEDGE-INDEX.md` (the UAT autocomplete source, extended by FR-9's additive-emit pass), plus the scope-tag infrastructure used to graph-link defect entries.
- **M012 (Spec Wiki)** — complete. Provides per-chunk wiki URLs used in the Issue custom-field link; Discussions enabled is a shared prerequisite.
- **M011/P07 Conversus Adapter** (`scripts/dispatch/adapters/tool/conversus.sh`) — shipped as part of M011/P07. Invoked at configured gate hook points.
- **`gh` CLI** — external dependency; operator-installed.
- **GitHub REST + Projects v2 APIs** — external; subject to GitHub's rate limits and plan-dependent features.
- **No runtime dependency on M014 or later milestones.** M013 ships standalone; M014 consumes its artifacts (Issues, comments) downstream.

## Downstream Consumers (informational, not binding)

- **M014 (Comment→Workflow Automation)** will ingest comments from the Issues and sub-issues this milestone creates, alongside wiki Giscus threads from M012, feeding them into its classifier. M014 also consumes the UAT intake path this milestone ships.
- **M020 (Knowledge Layer Maturation)** will consume `spec/defect` entries created by M013's UAT ingestion as input to its review-state and query-surface work.
- **M009 (Launch & Ecosystem)** will reference this integration as the primary "work visible to stakeholders" path in launch docs. **Handoff contract to M009**: M013 ships `references/github-integration.md` (SC-11), a populated sidecar-config schema, the `orchestrator:github init|sync|status` command surface, the UAT Bug issue template, and the first-init pending-sentinel convention — these are the artifacts M009's adoption docs build on top of, so any rough edges surfaced during M013 dogfooding get fixed in M013 rather than papered over in launch docs.
- **M019 Tier 2/3 (Observability)** surfaces sync-duration, upsert-count, error-count, and conversus-gate cost metrics via the execution-log emitter. M013 emits these events in the M019 Tier 1 shape per FR-17 so the rollup is free when M019 Tier 2/3 ships.
