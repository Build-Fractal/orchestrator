# Feature Specification: M013 GitHub Native Integration — Opt-In Projection Of Orchestrator State Onto Issues, Milestones, And Projects

**Feature Branch**: `023-github-native-integration`
**Created**: 2026-04-21
**Status**: Draft
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

### User Story 1 — Maintainer Opts In And Pushes Current Roadmap To GitHub In One Command (Priority: P1)

A maintainer on a repo that already runs the orchestrator wants stakeholders to see the current milestone's plan in GitHub. They run `orchestrator:github init` once. The command verifies `gh` CLI auth, asks whether to create a new Project v2 or attach to an existing one, creates the required labels and milestone, pushes every in-flight phase as an Issue with a `phase` label, every task as a sub-issue of its phase, and attaches each Issue to the Project v2 board with a status reflecting its orchestrator state. The command writes a sidecar config and prints a summary of what was created.

**Why this priority**: This is the entry-point experience and the whole milestone's user-visible "it works" moment. Without a working init, nothing downstream matters.

**Independent Test**: On a clean orchestrator project with at least one in-flight milestone containing ≥2 phases and ≥3 tasks across those phases, run `orchestrator:github init` against a test repo. Confirm the command completes in under 60 seconds and that the resulting GitHub state contains: one Milestone (named after the orchestrator milestone), one Project v2, the required labels (`phase`, `task`, `uat-bug`, `spec-gap` at minimum), one Issue per phase with the `phase` label, one sub-issue per task linked from its phase Issue, and each Issue attached to the Project v2 with a status value.

**Acceptance Scenarios**:

1. **Given** a project with a committed orchestrator roadmap, **When** the maintainer runs `orchestrator:github init`, **Then** the command preflights `gh auth status` and refuses (exit non-zero, clear error) if auth is missing or expired.
2. **Given** `gh` is authenticated and the repo is accessible, **When** init runs, **Then** the maintainer is prompted to create a new Project v2 or supply the ID of an existing one.
3. **Given** init completes, **When** the maintainer opens the GitHub Milestones tab, **Then** the current orchestrator milestone is listed with a completion percentage derived from closed/total sub-issues.
4. **Given** init completes, **When** the maintainer opens the Issues tab and filters by `label:phase`, **Then** every in-flight phase appears as an Issue whose body includes a hidden `<!-- orchestrator-id: <milestone>-<phase> -->` marker.
5. **Given** init completes, **When** the maintainer opens a phase Issue, **Then** its task sub-issues are listed under GitHub's native sub-issue tree.
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
5. **Given** the GraphQL leg fails mid-sync (network error, rate limit, permission), **When** sync completes, **Then** REST-created Issues still exist, the cache records which items succeeded in REST and which failed in GraphQL, and the next sync re-attempts only the GraphQL-side reattachment.
6. **Given** one upsert fails (e.g., a labels permission error on one Issue), **When** sync continues, **Then** the remaining upserts still run (each item is its own retry boundary); the failed item is reported at exit with a non-zero status and a specific diagnostic.

---

### User Story 3 — UAT Bug Filed Against A Spec Chunk Routes Into Orchestrator Triage (Priority: P1)

A stakeholder exercises a feature shipped by a recent phase, finds a defect, and opens the repo's **UAT Bug** Issue template on GitHub. The template requires a spec chunk ID (with autocomplete sourced from the orchestrator's `KNOWLEDGE-INDEX.md`). They submit the issue. A local ingestion step (manual command or hook) reads the Issue, creates a `spec/defect` knowledge entry linked in the graph to the referenced chunk, its owning phase, and the tests that covered the failing acceptance criterion. The orchestrator can then route the defect into one of three triage buckets: execution error (re-dispatch the task), spec gap (insert a clarification phase), or spec error (supersede the chunk and replan).

**Why this priority**: This is the "pays for the whole feature" user story. Without this loop, M013 is just a one-way projection; with it, the integration becomes part of how the team closes quality gaps.

**Independent Test**: Seed a test repo with a small orchestrator project, a shipped phase whose acceptance criterion references spec chunk `SPEC-US-001`, and an M013-generated issue template for UAT bugs. Open a UAT bug referencing `SPEC-US-001`. Run the ingestion step. Confirm a `spec/defect` knowledge entry is created at `.orchestrator/knowledge/spec/defect/SPEC-DEFECT-NNN.md` with a populated graph edge set: `{chunk: SPEC-US-001, phase: M013-P02, tests: [...]}` and a status of `open`.

**Acceptance Scenarios**:

1. **Given** the UAT Bug template is installed in `.github/ISSUE_TEMPLATE/`, **When** a stakeholder opens it, **Then** a "Spec Chunk ID" field appears with an autocomplete source (populated from `.orchestrator/KNOWLEDGE-INDEX.md` at init time and refreshable).
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

1. **Given** init writes `sync_mode: on-transition` to the config, **When** a phase's verify step completes, **Then** the post-verify hook invokes sync as its final step before returning.
2. **Given** sync mode is `manual`, **When** verify completes, **Then** no sync is triggered automatically (manual only).
3. **Given** sync mode is `cron`, **When** a maintainer runs the documented cron entry on schedule, **Then** sync runs with the same semantics as manual invocation. (Cron scheduling itself is operator-side configuration, not an orchestrator-managed daemon.)
4. **Given** the hook fails (network, auth), **When** verify would otherwise have succeeded, **Then** verify still succeeds — the hook failure is reported as a warning, not as a verify regression.

---

### User Story 6 — Conversus Pre-Merge Review Gate Is Invoked At A Specific Hook Point (Priority: P2)

A maintainer configures M013 to run the M011/P07 conversus adapter at a specific gate — for example, before transitioning a phase Issue from Verifying to Done, or before closing a milestone. At the gate, the conversus adapter runs its source-advocate vs target-advocate deliberation against the phase's context; its verdict is attached to the phase Issue as a comment. The gate is opt-in per phase type and respects the intensity engine's default recommendation.

**Why this priority**: The roadmap explicitly calls for M013 to invoke the M011/P07 conversus adapter at opt-in gate points. P2 because the adapter itself is a dependency shipped elsewhere; this milestone wires invocation points and respects intensity defaults, without reimplementing deliberation.

**Independent Test**: With the conversus adapter available, enable the pre-merge gate for one phase type. Run that phase through sync-on-transition to the Verifying → Done edge. Confirm the adapter is invoked exactly once at the gate, its verdict is posted as a comment on the phase Issue, and the transition is blocked or allowed per the adapter's return code.

**Acceptance Scenarios**:

1. **Given** the config enables the gate for a phase type, **When** the phase reaches the configured hook point, **Then** the M011/P07 conversus adapter is invoked with a payload containing the phase's spec chunks and verification results.
2. **Given** the adapter returns a block verdict, **When** sync would otherwise mark the phase Done, **Then** the phase Issue remains in Verifying and the adapter's verdict is posted as a comment.
3. **Given** the intensity engine recommends skipping the gate for this phase, **When** no per-phase override is set, **Then** the gate is skipped and sync proceeds normally.
4. **Given** the adapter is not available (not installed / disabled), **When** the gate is configured, **Then** sync errors with a clear diagnostic pointing at the adapter — it does not silently proceed.

---

## Functional Requirements

- **FR-1**: `orchestrator:github` command surface provides at minimum three subcommands: `init` (one-time setup), `sync` (walk state + upsert), `status` (report config + last sync + cache summary). Commands live as markdown definitions in `commands/` following the existing pattern.
- **FR-2**: `init` preflights `gh auth status` and refuses with a clear, actionable error if auth is missing, expired, or scopeless.
- **FR-3**: The mapping from orchestrator state to GitHub resources is exactly: orchestrator milestone ↔ GitHub Milestone + one Project v2; orchestrator phase ↔ Issue with `phase` label; orchestrator task ↔ sub-issue (via the sub-issue REST link) of its phase Issue; spec chunk ↔ custom field on the Issue whose value is the chunk's wiki URL (when wiki deployment is known); acceptance criterion ↔ checklist item in the Issue body linking back to the chunk; verification status ↔ Project v2 status field.
- **FR-4**: Every orchestrator-generated Issue body includes a hidden HTML comment of the form `<!-- orchestrator-id: <orchestrator-id> -->` where the id is deterministic and stable across re-syncs (format: `M###-P##` for phases, `M###-P##-T##` for tasks). Sync searches-by-marker before creating; finding a match means upsert, not duplicate.
- **FR-5**: REST calls (via `gh issue`, `gh issue edit`, `gh issue comment`, `gh api` for sub-issue linkage, `gh label`, `gh milestone`) perform ≥90% of writes. GraphQL is limited to ≤2 distinct calls per run: `createProjectV2` (once, during `init`) and `addProjectV2ItemById` (per Issue that needs to be attached or status-updated).
- **FR-6**: A single sidecar config file at `.orchestrator/integrations/github.json` stores: repo slug, Project v2 ID (if attached / created), orchestrator-id → issue-number cache, sync mode (`manual` / `on-transition` / `cron`), optional custom-field mappings. The file is human-readable JSON with a schema documented in `references/`.
- **FR-7**: A single sync script (`scripts/integrations/github-sync.sh` or equivalent; exact path is a planning decision) walks orchestrator state, computes a desired-state manifest, diffs against the sidecar cache, and emits per-item upserts. Each item is its own retry boundary — one failure does not abort the remaining items.
- **FR-8**: The sync script reports at exit: counts of `upserts`, `skipped`, `errors`, with a per-error summary naming the orchestrator-id, the GitHub resource it targeted, and the underlying error. Exit non-zero if any errors occurred.
- **FR-9**: A UAT Bug Issue template (`.github/ISSUE_TEMPLATE/uat-bug.yml` or equivalent) ships as part of init; the template requires a "Spec Chunk ID" field. Autocomplete is sourced from a generated list derived from `.orchestrator/KNOWLEDGE-INDEX.md` at init time.
- **FR-10**: An ingestion path (command or post-verify hook) reads UAT bug Issues, creates `spec/defect` knowledge entries graph-linked to the referenced chunk, the owning phase, and the tests that covered that chunk's acceptance criteria. Unknown chunk IDs are flagged but not silently dropped.
- **FR-11**: Reversibility: deleting `.orchestrator/integrations/github.json` returns orchestrator commands to pre-integration behavior. No command path errors because the config is missing; no command path silently re-inits; `orchestrator:github status` reports "not configured."
- **FR-12**: Sync modes `manual` / `on-transition` / `cron` are supported. In `on-transition`, a post-verify hook invokes sync as a follow-up step after verify completes. In `cron`, a documented cron line performs the same invocation at a user-chosen interval (orchestrator does not manage cron registration). Hook and cron failures surface as warnings; they do not regress verify.
- **FR-13**: Conversus integration: M013 does not re-implement deliberation. It invokes the M011/P07 conversus adapter (`scripts/dispatch/adapters/tool/conversus.sh`) at configured gate hook points, respecting the intensity engine's default enablement. The adapter's verdict is posted as an Issue comment and gates or allows transitions per its return code.
- **FR-14**: Init is repeatable — running it again after an initial run either reconciles against the existing config (reporting what is already set up) or prints a clear message on what would change, without creating duplicate Milestones/Projects/Labels.
- **FR-15**: Init supports a `--dry-run` that prints the upsert manifest (Issues that would be created, Project items that would be attached, labels that would be added) without calling any write endpoint.

## Success Criteria

- **SC-1**: From a test orchestrator project with one milestone containing ≥2 phases and ≥3 tasks, `orchestrator:github init --dry-run` prints a manifest matching the expected resources; the same command without `--dry-run` completes in <60 seconds and the resulting GitHub state contains all expected resources with correct labels, markers, and Project attachments.
- **SC-2**: Re-running `orchestrator:github sync` with zero orchestrator state change reports `upserts=0 errors=0 skipped=N` (where N is the total item count). No duplicate Issues exist (marker search before create verified).
- **SC-3**: After a partial-failure scenario (GraphQL leg fails, or one Issue's label edit fails), REST-created Issues still exist and the next sync successfully reattaches them — no manual remediation required.
- **SC-4**: A UAT bug filed via the installed template with a valid spec chunk ID is ingested into `.orchestrator/knowledge/spec/defect/` with graph edges to chunk → phase → tests, and its knowledge entry survives a full `orchestrator:consolidate` run.
- **SC-5**: Deleting `.orchestrator/integrations/github.json` and then running `orchestrator:auto` on a small phase completes without any `gh` subprocess, any config-missing warning blocking execution, or any unexpected failure — verified by a subprocess trace or equivalent.
- **SC-6**: Every `orchestrator:github` command runs under Bash 3.2 (Constitution IX) and passes `scripts/verify/anti-pattern-lint.sh` (Constitution XV + M016/M021 hardening).
- **SC-7**: A fresh `orchestrator:auto` run on a phase that exercises the on-transition hook produces zero Claude Code approval prompts (inheriting the M016/M021 zero-prompt baseline).
- **SC-8**: `init` and `sync` fail loudly — non-zero exit, clear diagnostic — when `gh` is not authenticated, when GitHub rate limits are hit, or when required scopes are missing. No silent degradation.
- **SC-9**: The conversus gate hook point is exercised in at least one end-to-end test: adapter invoked, verdict posted as a comment, transition blocked or allowed per return code. If the adapter is absent, sync errors with a pointer rather than silently proceeding.
- **SC-10**: Integration does not regress any existing test suite — `tests/test-*.sh` remain green with and without `.orchestrator/integrations/github.json` present.
- **SC-11**: `references/` contains a new doc (`references/github-integration.md` or similar) documenting the mapping table, marker format, sidecar schema, sync modes, and failure semantics — sufficient for a future maintainer to extend the integration without reading the source.

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

## Assumptions

- **`gh` CLI is installed and authenticated** on the operator's machine at init time and remains so during syncs. If not, commands fail loudly per FR-2.
- **The target repo has Issues, Milestones, and Projects v2 enabled** and the authenticated user has permissions sufficient to create labels, Milestones, and Projects v2, and to create and edit Issues. These are deploy-time prerequisites, not features this milestone provides.
- **The target repo has Discussions enabled** (inherited from M012's Giscus prerequisite). This is not strictly needed for M013 itself but is assumed because M013 is a dogfooding partner to M012.
- **The orchestrator-id format** (`M###-P##-T##`) is stable. Renumbering milestones or phases after init is an edge case treated as out-of-scope for v1; if it happens, operators re-init.
- **GitHub sub-issue REST link** is available on the target repo's plan. If the account tier or repo lacks sub-issue support, planning will fall back to checklist-item representation with a documented trade-off. The fallback is a planning decision, not a spec commitment.
- **The M011/P07 conversus adapter is installed** when the pre-merge gate is enabled. If absent, the gate errors; it does not silently skip.
- **`KNOWLEDGE-INDEX.md` is a trustworthy source of chunk IDs** for the UAT template autocomplete. Autocomplete is refreshed at init and on explicit re-run; it is not live.
- **Operators are responsible for cron registration** when sync mode is `cron`. The orchestrator documents the line; it does not install cron itself.

## Open Questions (defer to planning)

These are **not** decisions the spec makes. They are captured so planning starts with the list.

- **Eager vs. lazy task issue creation.** Does init create a sub-issue for every task in the roadmap up front, or only for tasks that are ready/in-progress, with the rest created on demand? Affects Issues-tab noise and sync performance.
- **Project v2 status field values.** Exact names and ordering (Planning / Ready / Executing / Verifying / Blocked / Done vs. some variant). Affects board readability. A planning decision with small stakes.
- **Out-of-band deletion handling.** If an operator manually deletes a GitHub Milestone or Project that the sidecar cache still references, what does the next sync do — re-init, warn, or error? Recommend error with a pointer to `init --repair`, but planning decides.
- **Post-verify hook install location.** `.claude/settings.json` vs. `.orchestrator/hooks/` vs. a separate install script. Affects cross-runtime (Codex CLI, Cursor) portability.
- **`--dry-run` manifest format.** Plain text vs. JSON. Affects whether downstream tools can parse the manifest for diffing.
- **Conversus gate hook points.** Where exactly the adapter is invoked — phase verify success, milestone close, or both. Affects M011/P07 invocation surface and the intensity engine's recommendation logic.
- **Sub-issue fallback strategy.** If sub-issue REST link is unavailable on the target repo's plan, do we fall back to checklist items, to labeled parent/child relationships, or refuse to init until the feature is available?
- **UAT ingestion trigger.** Manual command vs. GitHub webhook vs. cron pull. This milestone constrains to "no webhooks" (see Constraints), so manual or cron. Planning chooses which is the default.
- **Custom-field mapping ergonomics.** How operators declare the mapping in `github.json` — by field name, by field ID, or both. Affects first-run UX.
- **Cross-milestone re-init.** When a new milestone begins, does init need to be re-run, or does sync auto-detect the new milestone and create its Milestone + Project? Recommend the latter; planning confirms.

## Dependencies

- **M011 (Spec Management)** — complete. Provides chunk IDs (`SPEC-*`), `KNOWLEDGE-INDEX.md` (UAT autocomplete source), scope tag infrastructure (graph links for defect entries).
- **M012 (Spec Wiki)** — complete. Provides per-chunk wiki URLs used in the Issue custom-field link; Discussions enabled is a shared prerequisite.
- **M011/P07 Conversus Adapter** (`scripts/dispatch/adapters/tool/conversus.sh`) — shipped as part of M011/P07. Invoked at configured gate hook points.
- **`gh` CLI** — external dependency; operator-installed.
- **GitHub REST + Projects v2 APIs** — external; subject to GitHub's rate limits and plan-dependent features.
- **No runtime dependency on M014 or later milestones.** M013 ships standalone; M014 consumes its artifacts (Issues, comments) downstream.

## Downstream Consumers (informational, not binding)

- **M014 (Comment→Workflow Automation)** will ingest comments from the Issues and sub-issues this milestone creates, alongside wiki Giscus threads from M012, feeding them into its classifier. M014 also consumes the UAT intake path this milestone ships.
- **M020 (Knowledge Layer Maturation)** will consume `spec/defect` entries created by M013's UAT ingestion as input to its review-state and query-surface work.
- **M009 (Launch & Ecosystem)** will reference this integration as the primary "work visible to stakeholders" path in launch docs. M013's dogfooding surfaces the rough edges M009 must document.
- **M019 Tier 2/3 (Observability)** may surface sync-duration, upsert-count, and error-count metrics via the execution-log emitter; M013 should emit events in the standard shape so this is free when M019 Tier 2 ships.
