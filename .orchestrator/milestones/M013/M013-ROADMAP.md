---
schema_version: "1.0"
type: roadmap
milestone: "M013"
feature_ref: "023-github-native-integration"
feature_spec: "specs/023-github-native-integration/spec.md"
vision: "GitHub Issues/Milestones/Projects v2 as an opt-in, reversible projection of orchestrator state, with a UAT-bug intake that routes defects back to spec chunks and a conversus-gated PR review site."
tier: "C"
created_at: "2026-04-21T16:42:11Z"
updated_at: "2026-04-21T18:45:00Z"
---

## Phases

- [x] **P01**: Minimal Slice — Sidecar schema, UAT loop, knowledge-tree writes — "Opening a UAT Bug Issue against a valid `SPEC-*` chunk and running the ingestion step produces `knowledge/spec/defect/SPEC-DEFECT-NNN.md` with graph edges to chunk → phase → tests; `orchestrator:github status` accurately reports the sidecar state (absent / pending / configured)."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - `.orchestrator/integrations/github.json` initial schema (`schema_version`, pending-sentinel path, `sync_mode` enum) documented in `references/github-integration.md`
      - `.github/ISSUE_TEMPLATE/uat-bug.yml` (UAT Bug template with required Spec Chunk ID field + autocomplete source)
      - `commands/github-status.md` subcommand definition
      - `scripts/integrations/github-status.sh` (reports config presence / `pending-operator-complete` / last sync / cache summary)
      - `scripts/integrations/uat-ingest.sh` (reads UAT bug Issues → writes `knowledge/spec/defect/SPEC-DEFECT-NNN.md` with `{chunk, phase, tests}` frontmatter edges; unknown chunk IDs flagged `chunk-lookup-failed`, never silently dropped)
      - Additive emit pass in `scripts/knowledge/rebuild-index.sh`: flat `{chunk_id, title, phase_id}` list in `.orchestrator/KNOWLEDGE-INDEX.md`, with `chunk_id` pinned to existing `SPEC-*` frontmatter (no new ID format)
      - `knowledge/spec/defect/` directory + `SPEC-DEFECT-NNN.md` schema contract
      - `references/github-integration.md` (initial skeleton: sidecar schema, marker format, UAT ingestion contract, pending-sentinel semantics, `sync_mode` enum)
    - Consumes:
      - M011 `KNOWLEDGE-INDEX.md` + `knowledge/spec/**/SPEC-*.md` frontmatter (existing; external dependency)
      - M011 scope-tag graph edge infrastructure (existing; external dependency)
      - `scripts/verify/anti-pattern-lint.sh` (existing M016/M021 invariant)

- [x] **P02**: US-1 Projection create path — `orchestrator:github init` creates Milestone/Project v2/phase-Issues/task-sub-issues with marker-bearing bodies on first run — "On a clean `Build-Fractal/spec-kit-orchestrator` clone, `orchestrator:github init --dry-run` prints the upsert manifest; `orchestrator:github init` (no flag) completes in <60s and produces a GitHub Milestone, a Project v2, the required labels, one `label:phase` Issue per in-flight phase with a marker-bearing body (`<!-- orchestrator-id: <id> -->`), and task sub-issues linked under their phase Issue. Sidecar is populated with `repo_slug`, `project_v2_id`, and `items.<orchestrator-id>` entries. Second `init --dry-run` invocation with unchanged state produces a no-op manifest (zero upserts) via marker search-before-create; re-init adoption from sidecar-absent + marker-bearing remote state is deferred to P03."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `commands/github-init.md` subcommand definition
      - `scripts/integrations/github-init.sh` (orchestrator state → remote resources; lazy projection per US-1 AS #4a; `--dry-run` supported per FR-15; create + marker-search-before-create idempotency only — re-adoption is P03)
      - `scripts/integrations/github-common.sh` (shared helpers: deterministic orchestrator-id computation `M###-P##[-T##]`, marker search-by-body, sub-issue REST availability preflight, label-collision preflight with `--strict-labels` refuse mode, `gh auth status` + scope enumeration preflight per FR-2)
      - FR-4 marker invariant implementation (emit side): embed `<!-- orchestrator-id: <id> -->` in every Issue body; `shasum` byte-identity verification idiom (ported from M012 marker-bounded-atomic-writes pattern); search-before-create via marker body grep
      - Sidecar schema extensions: `repo_slug`, `project_v2_id`, `recommended_cron`, `custom_field_mappings`, populated `items.<orchestrator-id>` entries on first successful init
      - `references/github-integration.md` extensions: auth modes (PAT classic / PAT fine-grained / GitHub App / `gh` OAuth) + required scopes per mode, sub-issue representation modes + fallback semantics, partial mapping table (milestone/phase/task ↔ GitHub resources; chunk/AC/verification-status mapping deferred to P03)
    - Consumes:
      - P01: `.orchestrator/integrations/github.json` initial schema + pending-sentinel path
      - P01: `scripts/integrations/github-status.sh` (reports init-time state including `pending-operator-complete` vs. populated)
      - P01: `references/github-integration.md` (skeleton; this phase extends)
      - M011 orchestrator-id namespace (`M###-P##-T##` computed from existing milestone/phase/task file structure)
      - M012 `wiki/URL-SCHEME.md` (pinned URL scheme for per-chunk wiki URLs used in Issue custom-field values)
      - `gh` CLI (external runtime dependency)

- [x] **P03**: Re-init adoption path + GraphQL call-shape lint + mapping table completion — "Deleting `.orchestrator/integrations/github.json` and re-running `orchestrator:github init` on a repo with existing marker-bearing remote Issues adopts those Issues (repairs sidecar from remote state via marker search) and creates zero duplicates. CI lint verifies exactly three GraphQL mutation shapes are used across the codebase (`createProjectV2`, `addProjectV2ItemById`, `updateProjectV2ItemFieldValue`) and fails on any fourth shape. `references/github-integration.md` contains the full mapping table covering chunk / AC / verification-status ↔ GitHub resources."
  - Risk: medium
  - Depends: P02
  - Boundary Map:
    - Produces:
      - FR-14 re-init adoption path in `scripts/integrations/github-init.sh` (sidecar-absent + marker-bearing remote Issues → repair sidecar from remote state without creating duplicates; extends P02's init without rewriting it)
      - FR-5 GraphQL call-shape lint: `scripts/verify/graphql-call-shape.sh` (scans repo for GraphQL mutations, asserts membership in the three-shape whitelist; CI gate wired via existing verify surface)
      - `references/github-integration.md` extensions: mapping table completion (chunk / AC / verification-status ↔ GitHub resources), re-init adoption contract documentation
      - Re-init adoption test fixture at `tests/fixtures/m013-p03/re-init-adoption/` (sidecar-absent + marker-bearing remote-state mock)
    - Consumes:
      - P02: `scripts/integrations/github-init.sh` (extension point; P03 adds re-adoption branch without rewriting create path)
      - P02: `scripts/integrations/github-common.sh` (marker search-by-body helper reused by re-adoption)
      - P02: FR-4 marker invariant (emit side authored in P02; P03 consumes for read-back adoption)
      - P02: sidecar schema (P03 writes `items.<id>` entries during adoption using same shape)
      - P01: `references/github-integration.md` (extends)

- [x] **P04**: Sync cycle + post-verify hook + conversus UAT PR gate — "After init, `orchestrator:github sync --dry-run` prints the upsert manifest identically to init's dry-run format; a real `sync` reconciles orchestrator state with GitHub (closes sub-issues, updates Project v2 status via `updateProjectV2ItemFieldValue`, respects per-item retry boundaries, emits `unit_close` JSONL to `.orchestrator/execution-log.jsonl` in M019 Tier 1 shape); `sync` acquires the lock-manager lock for its duration; on Claude Code with `sync_mode: on-transition`, the post-verify hook invokes sync after verify completes without introducing approval prompts; a UAT-defect-closing PR reaching the pre-merge gate invokes `scripts/dispatch/adapters/tool/conversus.sh --strict` with a 30s timeout, posts the verdict as a comment, and gates the merge on the return code; `orchestrator:github status --verify-cache` flags cache/remote divergence without auto-repairing."
  - Risk: high
  - Depends: P03
  - Boundary Map:
    - Produces:
      - `commands/github-sync.md` subcommand definition
      - `scripts/integrations/github-sync.sh` (state walker + desired-state manifest diff + per-item upsert engine; acquires `scripts/lifecycle/lock-manager.sh` per FR-7; per-item retry boundaries except for rate-limit abort per FR-16)
      - `packaging/bundle/hooks/post-verify.json` (Claude Code hook descriptor registered via one-line addition to `packaging/install/install-claude-code.sh`; fail-as-warning semantics per US-5 AS-5)
      - One-line wiring in `packaging/install/install-claude-code.sh` (hook descriptor registration; Codex CLI and Cursor installers unchanged per FR-12 v1)
      - Conversus UAT PR gate invocation site (inside `github-sync.sh` or standalone `scripts/integrations/github-conversus-gate.sh`; invokes `scripts/dispatch/adapters/tool/conversus.sh` with `--strict` and a 30-second default timeout per FR-13 + Constitution XII; verdict posted as Issue/PR comment; exit code gates the transition)
      - FR-15 `--dry-run` manifest (format pinned during P04; identical shape across `init --dry-run` and `sync --dry-run`)
      - FR-16 rate-limit + auth-expiry detection: GitHub `HTTP 403 + X-RateLimit-Remaining: 0` / GraphQL `RATE_LIMITED` handling (no auto-retry within window; `retry-after` surfaced in exit diagnostic); `HTTP 401` + stale `gh auth status` → pointer to `gh auth refresh`; pre-flight `gh api rate_limit` probe when projected GraphQL volume > 50 mutations
      - FR-17 observability emitters: `unit_close` + `conversus_gate_invocation` JSONL records appended to `.orchestrator/execution-log.jsonl` in M019 Tier 1 shape; `source: "runtime"`
      - FR-18 `orchestrator:github status --verify-cache` cache/remote divergence probe (detects missing remote Issue for cached item, missing cache for marker-bearing remote Issue, status-field mismatch; reports without auto-repairing)
      - Sidecar schema extensions (per-item cache fields already declared at P01/P02; P04 populates `last_attempt_at`, `last_error`, `status_field_synced`, `project_v2_attached` on every sync run)
      - `references/github-integration.md` extensions: sync modes (`manual` / `on-transition` / `cron`) + cron registration guidance (operator-owned), rate-limit + auth-expiry semantics, observability record schema, `--verify-cache` semantics, conversus gate invocation contract
    - Consumes:
      - P02: `scripts/integrations/github-init.sh` + `github-common.sh` (shared helpers for marker search, orchestrator-id computation, sub-issue REST availability mode from sidecar)
      - P02: populated sidecar config (post-init state with `repo_slug`, `project_v2_id`, `items.<id>` entries)
      - P02: FR-4 marker invariant
      - P03: FR-5 three-shape GraphQL constraint (CI lint; P04 authors mutations within the whitelisted shapes)
      - M011/P07 conversus adapter at `scripts/dispatch/adapters/tool/conversus.sh` (with `--strict` flag authored at L239–244; this is the `M013 pre-merge gate, US-6 AS-4` consumption point cited in the adapter header)
      - M019 Tier 1 JSONL schema for `unit_close` records (ship shape; M019 owns evolution)
      - `scripts/engine/run.sh` POST_VERIFY framework at L353–356 (existing; P04 registers a handler, does not author primitives)
      - `scripts/lifecycle/lock-manager.sh` (existing)
      - `packaging/bundle/hooks/` template surface (existing; P04 adds one new descriptor)

## Cross-Cutting Concerns

- **Marker idempotency (FR-4)** — P01, P02, P03, P04. P01 establishes the `spec/defect` frontmatter-marker pattern (UAT-entry idempotency per US-2 applied to ingestion); P02 authors the Issue-body marker emit side (`<!-- orchestrator-id: ... -->`) with `shasum` byte-identity verification idiom and search-before-create idempotency on the create path; P03 extends to re-adoption (sidecar-absent + marker-bearing remote state → rebuild sidecar via marker search); P04 conforms by searching-before-creating on every sync upsert. A duplicate marker at any layer is a bug.

- **Pending-sentinel + reversibility (FR-6, FR-11)** — P01, P02, P03, P04. P01 establishes the pending-sentinel semantics (auto-mode first-init → `pending` values → `orchestrator:github status` reports `pending-operator-complete`; non-init commands error with "integration not configured: run `orchestrator:github init` to complete setup"). P02's `init` completes the sentinel on live run and populates the sidecar. P03's re-init adoption restores the sidecar from remote state when the file was deleted (FR-11 reversibility-by-delete round-trip). P04's `sync`, hook, and `status --verify-cache` must no-op cleanly when the sidecar is absent or holds pending sentinels. Preserves M007 no-dual-code-path discipline — "absent" and "pending" are two labels for one binary not-yet-live state.

- **Bash 3.2 + anti-pattern-lint clean (Constitution IX + XV; SC-6)** — all phases. Every shell script, hook, and command payload shipped by M013 must run under Bash 3.2 and pass `scripts/verify/anti-pattern-lint.sh`. No phase establishes this; it is a project-wide invariant inherited from M016/M021. CI enforces on every commit.

- **Zero approval prompts in auto mode (SC-7)** — P02, P03, P04. P02's `init` under auto-mode must not trigger any Claude Code approval prompts (writes pending sentinel without live `gh` calls; live calls happen on operator-initiated first run only). P03's re-init adoption path and GraphQL lint gate similarly must not introduce prompt triggers. P04 carries the heavier burden: the post-verify hook must not introduce new prompt triggers, and the conversus gate invocation must respect the existing zero-prompt baseline. Each phase's verify runs the M021 replay corpus (`tests/fixtures/m021-prompt-corpus.txt`) to attest.

- **Observability emission (FR-17)** — P04 only. `unit_close` and `conversus_gate_invocation` JSONL records are emitted from sync runs and gate invocations only. P01 (UAT ingestion), P02 (init create path), and P03 (re-init adoption + GraphQL lint) are NOT instrumented in this milestone — FR-17 is narrowly scoped per spec to avoid M013 overreaching into M019 territory. Records conform to M019 Tier 1 shape; M019 owns schema evolution.

- **`references/github-integration.md` lifecycle (SC-11)** — P01 (initial skeleton), P02 (auth modes + sub-issue modes + partial mapping table), P03 (mapping table completion + re-adoption contract), P04 (sync + hook + gate + rate-limit + observability + verify-cache). Each phase extends the same document; no phase re-authors sections owned by a prior phase. P04 owns the final audit before milestone close: verify the doc is coherent, navigable, and sufficient for a future maintainer to extend the integration without reading the source.

- **Knowledge-Layer Boundary (D014)** — P01 only. M013 writes to the knowledge tree at exactly two points: FR-9 additive-emit index widening and FR-10 `spec/defect` entries. Both ship in P01. None of P02, P03, P04 may extend knowledge-tree writes. Review-state lifecycle, dispatch-callable query surface, and entry clustering are M020 scope. SC-4 (`consolidate` survival) is verified at milestone close.

- **M011/P07 conversus adapter consumption (D007)** — P04 only. M013 is the invoking caller; the adapter is the authoring owner. `--strict` flag is M011/P07-authored; 30s default timeout is Constitution XII-bounded. No amendment to the adapter is needed. Adapter absence under a configured gate exits non-zero with a `FAIL:` diagnostic (not the adapter's default graceful `SKIPPED: ... exit 0`).

## Dependency Graph

```
P01 ──→ P02 ──→ P03 ──→ P04
 med      high    med    high
```

- P01 (Minimal Slice) — medium risk
- P02 (US-1 Projection create path) — high risk
- P03 (Re-init adoption + GraphQL lint + mapping table completion) — medium risk
- P04 (Sync + Hook + Conversus Gate) — high risk

Linear chain. No phase-level parallelism is possible — each phase consumes concrete artifacts from the prior phase (sidecar schema, shared helpers, post-init state, marker invariant, re-adoption read-back).

## Execution Order

1. **P01 — Minimal Slice** (medium risk; no dependencies). Foundation phase: sidecar schema skeleton, UAT Bug template, `orchestrator:github status`, FR-9 additive-emit index widening, FR-10 `spec/defect` ingestion path. Closes the US-3 dogfood loop end-to-end (the "pays for the whole feature" user story per spec).
2. **P02 — US-1 Projection create path** (high risk; depends on P01). Adds `orchestrator:github init` create path with lazy projection, FR-4 marker invariant emit side + search-before-create, label-collision preflight, sub-issue REST availability preflight, auth-mode preflight matrix (FR-2), sidecar population. Ordered after P01 because init writes to the sidecar schema P01 establishes and reports its results via P01's `status` command. **Scope deliberately narrowed** (per D015): re-init adoption (FR-14) and GraphQL call-shape lint (FR-5) are deferred to P03 to cut the dispatch risk concentration of what was originally a single-phase "full projection."
3. **P03 — Re-init adoption + GraphQL lint + mapping table completion** (medium risk; depends on P02). Adds FR-14 re-init adoption path extending P02's init, FR-5 GraphQL three-shape call-shape CI lint, and `references/github-integration.md` mapping table completion. Lower risk than P02 because each sub-scope reuses P02's primitives (marker search helper, `github-init.sh` extension point) and has narrow failure modes. Ordered after P02 because adoption consumes the marker invariant P02 authors; the GraphQL lint gates P02's mutation vocabulary retroactively as well.
4. **P04 — Sync cycle + hook + conversus gate** (high risk; depends on P03). Adds `orchestrator:github sync` (per-item upsert engine with lock acquisition, rate-limit detection, observability emission), FR-12 post-verify hook descriptor + installer wiring, FR-13 conversus UAT PR gate invocation, FR-15 `--dry-run` manifest, FR-18 `status --verify-cache`. Ordered after P03 because sync must author its GraphQL mutations within the three-shape whitelist that P03 lints and must handle the re-adopted sidecar state P03 may have rebuilt.

No phases execute concurrently. FR-043 ("high-risk first when dependencies allow") is satisfied within the linear chain: once P01's dependencies are satisfied (immediately, since it has `depends: none`), it runs; P02 follows at high risk; P03 follows at medium risk on top of P02's primitives; P04 closes the milestone at high risk. No parallel path is available because each phase consumes the prior's interface surface.

**Potential P04 split signal for re-planning**: if FR-13 conversus gate wiring proves heavier than a single task's worth of work during P04 planning (e.g., the adapter's strict-mode ergonomics require an adapter amendment despite the spec saying none is needed), planning may split P04 into P04a (sync + hook + rate-limit + observability) and P04b (conversus gate + `--verify-cache`). The trigger is recorded here so any split surfaces as a decision rather than silent scope drift.

## Validation

- **No conflicting producers**: PASS. Each artifact listed under a phase's `Produces` is owned by that phase. Shared artifacts that span phases (`.orchestrator/integrations/github.json` schema, `references/github-integration.md`) are extended by downstream phases, not re-produced — P01 produces the initial schema/skeleton, and P02/P03 add enumerated extensions to distinct fields/sections. No two phases claim authorship of the same field or section.
- **All consumed items have producers**: PASS. Every `Consumes` entry maps to either an upstream phase's `Produces` entry (P02 ← P01; P03 ← P02) or to a named external dependency (M011 `KNOWLEDGE-INDEX.md`, M011 scope-tag graph, M011/P07 conversus adapter, M012 wiki URL scheme, M019 Tier 1 JSONL schema, `scripts/engine/run.sh` POST_VERIFY framework, `scripts/lifecycle/lock-manager.sh`, `scripts/verify/anti-pattern-lint.sh`, `gh` CLI). External dependencies are all present in the repo today or are operator-installed runtime prerequisites explicitly named in the spec's Dependencies + Assumptions sections.
- **DAG is acyclic**: PASS. The dependency graph is a three-node linear chain P01 → P02 → P03 with no back-edges. No cycle possible.
- **Demo sentence coverage**: PASS. Each phase has a concrete, testable demo sentence naming observable GitHub/disk state (e.g., "produces `knowledge/spec/defect/SPEC-DEFECT-NNN.md` with graph edges…", "creates Milestone + Project v2 + `label:phase` Issues with marker-bearing bodies in <60s", "emits `unit_close` JSONL… conversus adapter invoked with `--strict`… verdict posted as comment"). Each demo sentence maps to at least one US-level Independent Test in the spec.
