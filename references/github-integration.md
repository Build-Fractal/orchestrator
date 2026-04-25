# GitHub Native Integration — Reference

**Milestone**: M013 (see `.orchestrator/milestones/M013/`)
**Spec**: `specs/023-github-native-integration/spec.md`
**Status**: P01 skeleton — P02 and P03 extend.

## Overview

M013 projects orchestrator state (milestones, phases, tasks, spec chunks, verification status) onto GitHub Issues, Milestones, and Projects v2 as an **opt-in** side surface. Orchestrator state on disk at `.orchestrator/` remains authoritative. GitHub is a projection, not a peer — this boundary is governed by Constitution XIV (No Speculative Complexity), XV (Surgical Precision), and `.orchestrator/DECISIONS.md` D007 (projection-not-peer, single direction of truth flow). The integration is **reversible**: deleting `.orchestrator/integrations/github.json` returns the orchestrator to pre-integration behavior (FR-11).

This reference is scoped to what M013 ships. P01 (this milestone phase) ships the scaffolding:

- Sidecar config schema at `.orchestrator/integrations/github.json` with a pending-sentinel bootstrap.
- `orchestrator:github status` subcommand (read-only, zero `gh` subprocess calls at P01).
- UAT Bug Issue Form template at `.github/ISSUE_TEMPLATE/uat-bug.yml`.
- Additive `## Spec Chunks` emit pass in `scripts/knowledge/rebuild-index.sh`.
- `knowledge/spec/defect/SPEC-DEFECT-NNN.md` schema contract and a fixture-driven ingester.

P02 adds `init` workflow, marker-based REST search idempotency, auth modes, and the full orchestrator→GitHub mapping table. P03 adds `sync` workflow, `sync_mode` runtime wiring, conversus pre-merge gate, and FR-17 cost emission. Sections below labeled "TODO P02" or "TODO P03" are reserved stubs — deliberately empty at P01 per Constitution XV (Surgical Precision). Overreach beyond this boundary will be rejected by the phase-suite gate.

## Sidecar Config Schema

The sidecar lives at `.orchestrator/integrations/github.json`. It is operator-owned and gitignored — the committed repository never carries a populated sidecar. The canonical template lives at `templates/github-integration-sidecar.json` (schema documented inline under the template's `_schema_docs` block). The bootstrap helper `scripts/integrations/sidecar-init-pending.sh` writes a fresh pending-valued sidecar and refuses to clobber an existing file (exit 2).

### Top-Level Fields (FR-6, v1)

| Field | Type | P01 Default | Semantics |
|-------|------|-------------|-----------|
| `schema_version` | integer | `1` | Current cache schema version. Increment on any breaking per-item shape change. |
| `repo_slug` | string | `"pending"` | `owner/repo` for the target GitHub repo. Literal `"pending"` until operator completes init (P02). |
| `project_v2_id` | string | `"pending"` | GitHub Projects v2 node ID. Literal `"pending"` until P02 init creates or attaches. |
| `sync_mode` | string (enum) | `"manual"` | One of `manual` / `on-transition` / `cron`. See § `sync_mode` Enum. |
| `recommended_cron` | string | `"*/15 * * * *"` | Cron expression surfaced to the operator when `sync_mode=cron`. Advisory only — orchestrator does not install cron. |
| `custom_field_mappings` | array | `[]` | Operator-declared Project v2 custom-field name → orchestrator-source mappings. Populated in P02. |
| `items` | object | `{}` | Per-item cache keyed by orchestrator-id (e.g. `"M013-P01"`, `"M013-P01-T01"`). Empty at P01 scaffold; populated by P02 on first init. |

### Per-Item Cache Shape (populated P02+)

Each key in `items` is an orchestrator-id (see § Marker Format) and its value is an object:

| Field | Type | Semantics |
|-------|------|-----------|
| `issue_number` | integer | GitHub Issue number this orchestrator-id is projected to. |
| `project_v2_attached` | boolean | Whether the issue is attached to the target Project v2. |
| `status_field_synced` | boolean | Whether the Project v2 Status field tracks orchestrator-derived state. |
| `last_attempt_at` | ISO-8601 string | When the last sync attempt against this item ran. |
| `last_error` | string \| null | Last sync error, or `null` if the last attempt succeeded. |
| `schema_version` | integer | Per-item shape version (pinned to top-level `schema_version` at time of write). |

P01 writes none of these — `items` stays `{}`. The shape is documented here so P02 can populate it against a fixed contract.

## Pending-Sentinel Semantics

The literal string `"pending"` in any FR-6 top-level field marks a scaffolded-but-not-yet-configured sidecar. This pattern is inherited from the M012/P04 `DEPLOY-RECORD.md` first-deploy contract — a pending-sentinel path signals operator-gated outcome rather than failure.

`scripts/integrations/github-status.sh` reads the sidecar and emits one of exactly three tri-state lines to stdout:

- `STATUS: absent` — `.orchestrator/integrations/github.json` does not exist.
- `STATUS: pending-operator-complete` — sidecar exists and at least one FR-6 field (`repo_slug`, `project_v2_id`, or `sync_mode`) holds the literal `"pending"`. A `PENDING_FIELDS:` CSV enumerates which fields. Per FR-6, this is an **operator-handoff state**, not graceful degradation — the operator must complete init before sync can proceed.
- `STATUS: configured` — all FR-6 fields are populated. The status line is followed by `REPO_SLUG`, `SYNC_MODE`, `LAST_SYNC`, and `CACHE_ITEMS` report lines.

Schema-mismatch (missing required FR-6 field) writes to stderr and exits 1. Unknown flags exit 2. Help exits 0. Configured and absent both exit 0 — `absent` is a valid steady state for projects that have opted out of the integration.

**Reversibility-by-delete (FR-11)**: removing `.orchestrator/integrations/github.json` returns the orchestrator to `STATUS: absent` and to pre-integration behavior across all surfaces. No dual-code-path branching exists (M007 no-graceful-degradation discipline) — the absence of the sidecar is the opt-out.

## `sync_mode` Enum

The `sync_mode` field takes exactly one of three values. P01 describes the enum; runtime wiring (actually invoking sync on transitions or via cron) is P03.

- **`manual`** (default) — sync runs only when the operator explicitly invokes it (planned `orchestrator:github sync` subcommand in P02/P03). No hook, no scheduler, no drift. Safe for exploratory use and the implicit default for operators who have not yet decided on an automation posture.
- **`on-transition`** — sync fires as a post-transition hook on orchestrator state advancement (task completion, phase advancement, milestone close). Runtime wiring is Claude-Code-only for v1 per D014 / spec FR-12; Codex CLI and Cursor fall back to `manual`. Wiring lands in P03.
- **`cron`** — operator installs an external cron line (advisory expression surfaced via `recommended_cron`). Orchestrator does not own the cron installation — the operator edits their own crontab. P03 emits the advisory line at init time.

## `<!-- orchestrator-id: ... -->` Marker Format

GitHub Issues projected by M013 carry an HTML-comment marker in the body used for idempotent re-sync. The literal marker shape is:

```
<!-- orchestrator-id: M###-P##[-T##] -->
```

### ID Format

The ID inside the marker is a three-segment orchestrator path:

- **Milestone**: `M###` (zero-padded three-digit milestone number, e.g. `M013`).
- **Phase**: `-P##` (zero-padded two-digit phase number, e.g. `-P01`).
- **Task** (optional): `-T##` (zero-padded two-digit task number, e.g. `-T06`).

Valid examples: `M013-P01`, `M013-P01-T06`, `M001-P04`. Any deviation from this format is non-matching and will cause P02's REST search-by-marker to fall through to "no projection yet" (which is the correct fail-closed behavior).

### Idempotency Contract

The marker is the primary key M013 uses to reconcile orchestrator-id → GitHub Issue number. Re-syncing the same orchestrator-id must:

1. Find the existing Issue by marker search, not by title or label match.
2. Update in place (body, labels, project-v2 attachment) rather than creating a duplicate.
3. If marker search returns zero matches, create a new Issue with the marker embedded; if it returns more than one, surface a label-collision diagnostic and refuse to sync that ID until the operator reconciles.

P01 documents the format. Implementation (REST search, body-embedding on create, duplicate-collision preflight) is **TODO P02**.

## UAT Ingestion Contract

UAT-filed defects flow from GitHub Issues (created via the UAT Bug Issue Form at `.github/ISSUE_TEMPLATE/uat-bug.yml`) into `knowledge/spec/defect/SPEC-DEFECT-NNN.md` entries. P01 ships the offline fixture-driven flow. P03 MAY add a live `gh issue list` pull.

### Input Fixture Shape

The ingester at `scripts/integrations/uat-ingest.sh` consumes a JSON fixture representing one UAT-bug Issue. Required fields on the fixture:

| Field | Type | Source | Semantics |
|-------|------|--------|-----------|
| `number` | integer | GitHub Issue number | Drives the `SPEC-DEFECT-NNN` filename — zero-padded to ≥3 digits. |
| `title` | string | Issue title | Carried to the entry body. |
| `created_at` | ISO-8601 string | Issue creation timestamp | Written to frontmatter verbatim. |
| `spec_chunk_id` | string | `.github/ISSUE_TEMPLATE/uat-bug.yml` `id: spec_chunk_id` required input | The `SPEC-*` chunk ID the reporter cited. Looked up against `KNOWLEDGE-INDEX.md`'s `## Spec Chunks` section. |

The `.github/ISSUE_TEMPLATE/uat-bug.yml` form enforces `spec_chunk_id` as `type: input` + `validations.required: true` and surfaces a "How to find your Spec Chunk ID" markdown block pointing to the repo-root `KNOWLEDGE-INDEX.md` Spec Chunks section — which is emitted by `scripts/knowledge/rebuild-index.sh`'s additive pass (T04).

### Output File Shape

Each fixture produces one `knowledge/spec/defect/SPEC-DEFECT-NNN.md` file whose frontmatter contract is documented (not duplicated) at `knowledge/spec/defect/README.md`. This reference intentionally does not restate that field table — `knowledge/spec/defect/README.md` is the authoritative schema source (M020 forward-compatibility noted there).

### Status Enum

The `status` frontmatter field takes exactly one of four values. Full transition semantics live in `knowledge/spec/defect/README.md`; the enum set itself:

- `open` — freshly ingested with a valid chunk lookup.
- `chunk-lookup-failed` — ingested but the cited chunk ID did not match any `SPEC-*` in `KNOWLEDGE-INDEX.md`. Entry is preserved with `chunk: ""` (never silently dropped).
- `triaged` — a maintainer has assigned a triage bucket (execution-error / spec-gap / spec-error).
- `closed` — defect resolved.

### Unknown Chunk Flagging

Per FR-10 and the D014 Knowledge-Layer Boundary ruling, UAT bugs referencing unknown chunk IDs MUST be ingested as sentinel entries (`status: chunk-lookup-failed`, `chunk: ""`) — never silently dropped. The ingester surfaces this at run time via a `SKIP:` prefix line and the summary line. Manual reconciliation (operator edits the `chunk:` field and flips `status:` to `open`) is the exit path — this is an operator-handoff state, symmetric to the pending-sentinel pattern above.

## Knowledge-Layer Boundary (M013 vs. M020)

Per `.orchestrator/DECISIONS.md` D013 (M020 promotion) and D014 (M013 conversus pressure-test rulings), M013 deliberately does **not** author new knowledge-layer primitives. Specifically:

- **`chunk_id` is pinned to existing `SPEC-*` frontmatter.** Both `scripts/knowledge/rebuild-index.sh`'s additive `## Spec Chunks` emit pass and `scripts/integrations/uat-ingest.sh` source `chunk_id` verbatim from the `id:` frontmatter field of files under `knowledge/spec/`. M013 introduces no new ID format, no composite addressing, no namespace extension.
- **Review-state lifecycle, query-surface, and clustering stay out of M013.** These live in M020 (Knowledge Layer Maturation) — see D013 for the promote-or-dissolve decision rule based on M012/P02 delivery, and `.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md` for the 1-of-3 outcome that promoted M020.
- **`knowledge/spec/defect/SPEC-DEFECT-NNN.md` is a new *category*, not a new format.** It conforms to the existing `knowledge/{category}/{entry-id}.md` warm-layer convention (MEM019). Optional fields M020 may add (`review_state:`, `cluster_id:`, `similarity_hash:`) are reserved as forward-compatible additions — M013-era entries will validate against M020's extended schema.

Full rationale: `.orchestrator/DECISIONS.md` D013 (M020 scope and sequencing) and D014 (13 spec edits + 3 arbitrated rulings applied pre-discuss).

## Scope Boundary (P01 vs. P02 vs. P03 vs. P04)

This table pins what each phase writes into this document. P01 populates only the P01 column; later phases fill their columns in place.

| Section | P01 | P02 | P03 | P04 |
|---------|-----|-----|-----|-----|
| Sidecar schema | shipped (this doc) | `items.<id>` population + `sub_issue_mode` field added | — (per-item status tracking is P04) | per-item `last_attempt_at` / `last_error` / `status_field_synced` / `project_v2_attached` write paths shipped |
| Pending sentinel | shipped | reversed on successful init | — | `--verify-cache` no-ops on pending (FR-18) |
| `sync_mode` enum | shipped (enum described) | operator-set at init (still `manual` default) | — (runtime wiring is P04) | runtime wiring: `manual` / `on-transition` (Claude Code post-verify hook) / `cron` (advisory) shipped |
| Marker format | shipped (format described) | REST search-by-marker + emit + shasum byte-identity verify shipped | `gh_marker_search_remote` helper + byte-identity-on-adopt ship | `--verify-cache` uses marker-search to detect `missing-remote` divergences |
| UAT ingestion | shipped (offline fixture flow) | — | — (live `gh issue list` pull not taken in P03) | — |
| Auth modes | — | shipped (this doc) | — | FR-16 auth-expiry rc=4 wired in sync + init |
| Full mapping table | — | partial (phase/task/milestone rows; chunk/AC/status deferred) | **shipped** (deferred rows filled in place) | sync rows added (close / status-sync / skip-nochange) |
| `init` workflow | — | shipped (this doc + script T02/T03) | **shipped** re-init adoption (FR-14 full) | — |
| `sync` workflow | — | — | — (TODO P04) | **shipped** (reconcile pass + `--dry-run` + FR-5 third-shape mutation) |
| Conversus pre-merge gate | — | — | — (TODO P04) | **shipped** (strict mode + 30s timeout + verdict-as-comment + D007 adapter invocation) |
| FR-17 cost emission | — | — | — (TODO P04) | **shipped** (`unit_close` + `conversus_gate_invocation` Tier 1 records with `source: "runtime"`) |
| FR-5 GraphQL call-shape lint | — | — | **shipped** (`scripts/verify/graphql-call-shape.sh`) | `updateProjectV2ItemFieldValue` third-shape used by sync; lint pre-whitelisted in P03 |
| FR-16 rate-limit | — | — | — | rc=3 exit + `RATE-LIMIT: retry-after=<ISO>` diagnostic + pre-flight `gh api rate_limit` on >50 mutations |
| FR-18 `--verify-cache` | — | — | — | `orchestrator:github status --verify-cache` flag + `DIVERGENCE:` classes + rc=0/5 contract |

### Auth Modes

`orchestrator:github init` supports four auth modes (FR-2). The mode is inferred from `gh auth status` — orchestrator does not own token creation, storage, or rotation.

| Mode | How to authenticate | Required scopes | Token storage | Rotation |
|------|---------------------|-----------------|---------------|----------|
| PAT classic | `gh auth login --with-token` | `repo`, `project`, `read:org` | `~/.config/gh/hosts.yml` | Operator-owned; no expiry by default but GitHub may force rotation |
| PAT fine-grained | `gh auth login --with-token` (fine-grained) | Repository: `Issues: Read/Write`, `Metadata: Read`; Organization: `Projects: Read/Write` | `~/.config/gh/hosts.yml` | Fixed expiry (max 1 year) — operator must rotate |
| GitHub App installation | `gh auth login` → App flow | Same as fine-grained PAT at app-install time | App-managed | App-managed |
| `gh` CLI OAuth | `gh auth login` → browser OAuth | `repo`, `project` (granted via device flow) | Encrypted keychain (macOS) / libsecret (Linux) | 1-year sliding refresh |

`github-init.sh --dry-run` invokes `gh_auth_preflight` which calls `gh auth status` and inspects `X-Oauth-Scopes` from `gh api user -i`. Missing scopes fail fast with `integration-auth-failed: missing scope <name>` — operator runs `gh auth refresh -s <name>` before retrying.

`orchestrator:github status` reports the last time `gh auth status` was verified and warns if that timestamp is older than 60 days (FR-2). Token rotation is operator-owned — M013 does not refresh tokens.

#### Rate-Limit Budget by Mode

| Mode | Primary limit | Secondary limit (search, graphql) |
|------|---------------|-----------------------------------|
| PAT classic / fine-grained | 5000 req/hour per token | 30 graphql points/min; abuse-detection on burst |
| GitHub App installation | 5000 req/hour per installation (higher on paid plans) | Same as PAT |
| `gh` OAuth | 5000 req/hour per user | Same as PAT |

FR-16 rate-limit detection (P04) pre-flights `gh api rate_limit` on runs with projected GraphQL volume > 50 mutations; this is a P04 scope item, noted here so the doc is discoverable when operators hit the 50-mutation boundary.

### Sub-Issue Representation Modes

GitHub's sub-issue REST endpoint (`POST /repos/:owner/:repo/issues/:issue_number/sub_issues`) became available in limited rollout in late 2024 and may return HTTP 404 or 501 on repos where the feature is not enabled. `orchestrator:github init` preflights this endpoint and records the selected mode in the sidecar as `sub_issue_mode: native | labeled-fallback` (sidecar schema field added in P02/T06).

**`native` mode** — preferred when the preflight probe returns HTTP 200:
- Task Issues are linked under their parent phase Issue via the sub-issue REST endpoint.
- GitHub UI renders them as a first-class sub-issue tree.
- Sidecar records `sub_issue_mode: native`.

**`labeled-fallback` mode** — used when the preflight probe returns 404/501:
- Task Issues carry a `child:<task-id>` label; the parent phase Issue carries a `parent:<phase-id>` label (one per child).
- Each Issue body includes a reciprocal Markdown link: phase body contains `- [ ] <task-id> #<issue-number>` for each child; task body contains `Parent: #<phase-issue-number>`.
- Sidecar records `sub_issue_mode: labeled-fallback`.
- UI representation is plain labels + body links — no tree view. US-3 first-class-Issue contract is preserved because each task is still its own Issue.

The mode does not change without explicit operator re-init. `orchestrator:github status` reports the current mode in the `SUBISSUE_MODE:` line on `configured` state.

### Full Mapping Table (P02 + P03)

Orchestrator state → GitHub resource projection. P02 populates phase/task/milestone/label/project-v2 rows; P03 fills chunk/AC/verification-status rows in place. P04 owns the live transitions on the verification-status row (`updateProjectV2ItemFieldValue`) and the AC checklist-toggling on `sync`.

| Orchestrator concept | GitHub resource | Creator | Marker / Key | Lifecycle |
|----------------------|-----------------|---------|--------------|-----------|
| Milestone | Milestone | `init` | title = `M###-<slug>` | close on consolidate (P04) |
| Phase | Issue with `label:phase` | `init` | body marker `<!-- orchestrator-id: M###-P## -->` | close on P##-SUMMARY.md landing (P04) |
| Task | Sub-issue (native) or `label:task` Issue (labeled-fallback) linked under parent phase Issue | `init` | body marker `<!-- orchestrator-id: M###-P##-T## -->` | close on T##-SUMMARY.md landing (P04) |
| Project (per milestone) | Project v2 | `init` | single Project per orchestrator milestone | - |
| Project item | Project v2 item (Issue attached) | `init` via `addProjectV2ItemById` | `orchestrator-id` custom field | status transitions (P04 via `updateProjectV2ItemFieldValue`) |
| Required label set | `phase`, `task`, `uat-bug`, `spec-gap` | `init` (adopted or created per FR-14 label preflight) | name | - |
| **Spec chunk** | **Issue custom field (`chunk-URL`)** | `init` — populates from walker pass | `chunk-url` field value = stable per-chunk wiki URL (see M012 `wiki/URL-SCHEME.md`) | Read-only at P04 sync (no transitions) |
| **Acceptance criterion** | **Checklist item in Issue body** | `init` — one `- [ ] AC: <text>` line per AC parsed from the task-plan `## Must-Haves` block | AC text (content is the key; no dedicated marker) | `sync` ticks the box when the AC's verification artifact lands (P04) |
| **Verification status** | **Project v2 Status field** | `init` sets initial value `Todo` via `addProjectV2ItemById` then `updateProjectV2ItemFieldValue` (P04) | Project v2 item node id (from sidecar) | `sync` transitions Todo → In Progress → Done via `updateProjectV2ItemFieldValue` (P04) |

The table is now complete. Lifecycle columns referencing P04 capture sync-time transitions not shipped in P03 (status transitions, AC checkbox toggling); P03 only wires the `init`-time creator cells.

#### Sync Action Mapping (P04)

`orchestrator:github sync` emits one UPSERT row per cached `items.<oid>` entry. The `reason` column takes one of three values mapped to an orchestrator state transition:

| Sync action | GitHub effect | Orchestrator trigger | Cache side-effect |
|-------------|---------------|----------------------|-------------------|
| `close` (phase) | `gh issue close <num>` on the phase Issue | `P##-SUMMARY.md` lands (phase-done state) | `items.<M###-P##>.last_attempt_at` updated |
| `close` (task) | `gh issue close <num>` on the task sub-Issue | `T##-SUMMARY.md` lands (task-done state) | `items.<M###-P##-T##>.last_attempt_at` updated |
| `status-sync` | `updateProjectV2ItemFieldValue` flips Project v2 Status field (Todo → In Progress → Done) | Phase enters `ready` / `executing` / `done` | `items.<oid>.status_field_synced` set true |
| `skip-nochange` | no-op | desired state already matches remote projection | `items.<oid>.last_attempt_at` updated |

Under a stable-state fixture (no orchestrator-side changes since the last sync), every row resolves to `skip-nochange` and the footer reports `upserts=0 errors=0` — the steady-state idempotency contract for sync.

#### FR-14 Label Collision

`init` enumerates pre-existing labels matching names it would create (`phase`, `task`, `uat-bug`, `spec-gap`). Default: **adopt-without-modification** — the existing label's color/description is preserved. With `--strict-labels`: **refuse** with `integration-labels-collision: <label-name>` diagnostic and exit 3. Re-init from sidecar-absent + marker-bearing remote state (FR-14 full re-adoption) is deferred to P03; P02 handles only the create path's label-collision case.

### `init` Workflow

Step-by-step flow of `orchestrator:github init` (see `commands/github-init.md` for the command-level view):

1. **Flag parse** — `--dry-run`, `--i-am-operator`, `--strict-labels`, `--root <project-root>`, `--repo-slug <owner/name>`.
2. **Auto-mode guard (SC-7)** — if no TTY and no `--i-am-operator`, invoke `scripts/integrations/sidecar-init-pending.sh` and exit 0 with `STATUS: pending-operator-complete`. Zero `gh` calls.
3. **Preflight: auth** — `gh_auth_preflight` (from `github-common.sh`). Checks `gh auth status` and enumerates scopes via `gh api user -i`. Fail fast on missing `project` / `repo`.
4. **Preflight: sub-issue REST** — `gh_subissue_rest_preflight <repo-slug>`. Probes `/repos/.../issues/1/sub_issues`; sets `SUBISSUE_MODE` per response code.
5. **Preflight: labels** — `gh_label_collision_preflight <repo-slug> <strict-flag>`. Enumerates pre-existing `phase`, `task`, `uat-bug`, `spec-gap` labels. Adopt by default; refuse with `--strict-labels`.
6. **State walker (lazy projection, US-1 AS-4a)** — walks `.orchestrator/milestones/M###/M###-ROADMAP.md` + `phases/P##/P##-PLAN.md` / `tasks/T##-PLAN.md`. Projects only Ready/Executing/Verifying-state phases and their Ready-or-later tasks. Planning-state phases / tasks skipped until transition.
7. **Manifest emit (FR-15)** — buffer UPSERT lines via `manifest_upsert_line` helper (from `github-common.sh`). On `--dry-run`, emit the full manifest (header + body + footer) and exit 0. On live run, manifest is emitted after creates complete.
8. **Marker search-before-create** — for each `<orchestrator-id>`, query `gh issue list --search "\"<!-- orchestrator-id: <id> -->\""`. Zero matches → create; one match → adopt (skip-existing-marker); ≥2 matches → `integration-marker-duplicate` exit 3.
9. **Create phase** — REST for Issues/Milestones/Labels (`gh milestone create`, `gh issue create`, `gh label create`, sub-issue REST). GraphQL for Project v2 setup: `createProjectV2` (once) and `addProjectV2ItemById` (per Issue attached). FR-5 three-shape whitelist: only these two GraphQL shapes fire in P02; `updateProjectV2ItemFieldValue` is P04.
10. **Marker byte-identity verification (FR-4)** — after each Issue create, fetch body via `gh issue view --json body --jq .body`, feed to `shasum_marker_byte_identity`, exit non-zero on mismatch.
11. **Sidecar populate** — `sidecar_set_top_field repo_slug ...`; `sidecar_set_top_field project_v2_id ...`; `sidecar_set_top_field sub_issue_mode ...`; `sidecar_upsert_item <id> <issue-number> ...` per created Issue.
12. **Exit summary** — `upserts=N skipped=M errors=E` on final stdout line. Exit 1 if `$E > 0`.

### Dry-Run Manifest Format (FR-15)

The manifest printed by `init --dry-run` (and later `sync --dry-run` in P04) uses this pinned shape:

```
MANIFEST: <upserts> <skipped> <errors>
UPSERT: <resource-kind> <orchestrator-id> <target> <reason>
UPSERT: <resource-kind> <orchestrator-id> <target> <reason>
...
upserts=<N> skipped=<M> errors=<E>
```

Where:
- `resource-kind` ∈ `{milestone, project-v2, label, phase-issue, task-subissue, project-v2-item}`
- `orchestrator-id` is `M###-P##[-T##]` or `-` for repo-level resources (labels, project-v2 root)
- `target` is a GitHub URL, Issue number, Project v2 node id, or `-` for labels
- `reason` ∈ `{create, adopt, skip-existing-marker}`

This format is load-bearing: P03 re-init adoption and P04 sync `--dry-run` consume it verbatim. Changing it is a breaking change requiring a spec amendment.

### Re-init Adoption Contract (FR-14)

`orchestrator:github init` is repeatable. Running it again after an initial run adopts existing remote resources rather than creating duplicates. Two trigger paths:

1. **Explicit `--re-init` flag** — operator intent to re-adopt. Fires the adoption pre-pass regardless of sidecar state.
2. **Implicit detection (sidecar-absent + marker-bearing remote)** — when the sidecar is absent AND the first projected orchestrator-id has a marker-bearing remote Issue (detected via a cheap marker-search probe on the first phase id), the adoption pre-pass engages automatically. This handles FR-11 reversibility-by-delete — the operator deleted the sidecar and re-ran init to rebuild it from remote state.

**Adoption algorithm** (per orchestrator-id):

1. `gh_marker_search_remote <repo-slug> <orchestrator-id>` queries the remote via `gh issue list --search "\"<!-- orchestrator-id: <id> -->\""`.
2. **Unique hit** → emit `UPSERT: <kind> <oid> <issue-number> adopt` manifest row; fetch the remote Issue body; verify FR-4 marker byte-identity via `shasum_marker_byte_identity`; write `items.<oid>` sidecar entry with the adopted `issue_number`; register the id in the `adopted_ids` array so the create fan-out short-circuits.
3. **Zero hits** → the id falls through to the normal create path (handles partial-prior-init cases where the sidecar was deleted after only some Issues were created).
4. **Duplicate hits** → emit `integration-marker-duplicate: <oid>` to stderr; increment error count; do NOT adopt either. FR-4's one-marker-per-id invariant is load-bearing — a duplicate marker is a bug requiring operator intervention.

**Milestone and Project v2 adoption**: Milestone adoption discovers the existing Milestone by title match (`gh milestone list`). Project v2 adoption queries by title match (`projectsV2(first: 20)` query — this is a GraphQL **query**, not a mutation, and is therefore outside the FR-5 three-shape whitelist enforced by `scripts/verify/graphql-call-shape.sh`).

**Auto-mode safety (SC-7)**: the re-init branch runs AFTER the existing auto-mode short-circuit. Without TTY + without `--i-am-operator`, `--re-init` is a no-op — the script falls through to the pending-sentinel path. Re-init is operator-initiated only.

**Manifest footer extension**: when re-init adoption ran, the footer is `upserts=<N> skipped=<M> errors=<E> adopted=<A>`. When re-init did NOT run (pure P02 create path), the footer stays the P02 3-field shape `upserts=<N> skipped=<M> errors=<E>` byte-identical — the 4th field is additive-optional.

**FR-4 marker invariant on adoption**: every adopted Issue's remote body is fetched via `gh issue view <num> --json body --jq .body` and fed to `shasum_marker_byte_identity`. On mismatch, adoption fails with `integration-marker-mismatch on adopt: <oid>`. This closes the FR-4 invariant across the full projection → read-back round trip.

### Sync Workflow (FR-15)

`orchestrator:github sync` is a reconcile pass — it diffs cached sidecar state against desired orchestrator state and pushes deltas. It never creates new Milestones/Project v2/Issues; that is exclusively the `init` path. Sync closes sub-Issues when their associated task `T##-SUMMARY.md` lands, closes phase Issues when `P##-SUMMARY.md` lands, and flips Project v2 Status fields (Todo → In Progress → Done) via the single whitelisted `updateProjectV2ItemFieldValue` GraphQL mutation (FR-5 third-shape).

1. **Flag parse** — `--dry-run`, `--i-am-operator`, `--conversus-gate`, `--timeout <sec>`, `--root <project-root>`.
2. **Lock acquisition (FR-7)** — `scripts/lifecycle/lock-manager.sh acquire sync` at entry. Exit rc=6 on lock-held.
3. **Preflight: auth** — `gh_auth_preflight` (same helper as `init`). Exit rc=4 on auth-expired with `AUTH-EXPIRED:` diagnostic.
4. **Preflight: rate-limit (FR-16)** — `gh api rate_limit` probe when projected GraphQL volume > 50 mutations (see Rate-Limit & Auth-Expiry Semantics). Exit rc=3 on window-exceeded with `RATE-LIMIT: retry-after=<ISO>` diagnostic.
5. **Cache walk** — parse `.orchestrator/integrations/github.json` `items.<oid>`; for each, derive desired state by consulting on-disk summary files; emit UPSERT rows with reason ∈ `{close, status-sync, skip-nochange}`.
6. **Dry-run contract** — with `--dry-run`, emit the full manifest (header + body + footer `upserts=<N> skipped=<M> errors=<E>`) and exit 0. Manifest shape is byte-identical to `init --dry-run` (FR-15 generalization).
7. **Live-mode dispatch** — execute `gh issue close <num>` for close rows and the FR-5 whitelisted `updateProjectV2ItemFieldValue` GraphQL mutation for status-sync rows. Per-item sidecar cache is updated under the `items.<oid>` object (fields: `last_attempt_at`, `last_error`, `status_field_synced`, `project_v2_attached`).
8. **Conversus pre-merge gate (opt-in)** — with `--conversus-gate` flag, UAT-defect-closing sub-Issues route through `scripts/integrations/github-conversus-gate.sh` (see § Conversus Pre-Merge Gate).
9. **Observability (FR-17)** — one `unit_close` JSONL record per phase-close / task-close / sub-Issue close; one `conversus_gate_invocation` record per gate invocation (see § Observability Record Schema).
10. **Lock release** — on every exit path.
11. **Exit summary** — `upserts=<N> skipped=<M> errors=<E>` on final stdout line.

### Conversus Pre-Merge Gate (FR-13)

When `--conversus-gate` is passed, sync interposes a conversus deliberation at the UAT-defect close point per D007 (projection-not-peer) and D014 adapter-reuse: the M011/P07 conversus adapter (`scripts/dispatch/adapters/tool/conversus.sh`) is invoked as a tool adapter, not re-implemented.

**Invocation contract**:

- **Strict mode** — the gate runs conversus in `strict` presets; a blocking verdict halts the sync and exits rc=1. Operator must rerun without the gate or resolve the verdict (comment on the defect Issue) before retry.
- **30-second timeout** — the gate enforces a hard 30s wall-clock timeout on the conversus call. On timeout, the gate emits `CONVERSUS-TIMEOUT: oid=<id> wall-clock=30s` to stderr and exits rc=1.
- **Verdict-as-comment** — the conversus verdict is posted as a GitHub Issue comment on the UAT defect Issue before the close fires. On block, no close; on pass, close proceeds.
- **Exit-code-gates-merge** — a non-zero rc from the conversus adapter blocks the close. This is the spec's merge-gate contract (FR-13).
- **Adapter-absence semantics** — when `scripts/dispatch/adapters/tool/conversus.sh` is not installed (fresh install without the M011/P07 adapter), the gate emits `CONVERSUS-UNAVAILABLE:` warning on stderr and treats the UAT-defect close as operator-deferred (no close fires; rc=1). This preserves D014's "conversus integration stays at the M011/P07 reusable adapter" boundary — M013 invokes but does not reimplement.
- **Edition resolution (M026)** — the adapter resolves to the OSS conversus build (`~/Sites/conversus-oss`) by default; operators set `CONVERSUS_EDITION=paid` to flip to the paid build for paid-only presets. The resolved edition is reported on every `conversus_gate_invocation` JSONL record. See `commands/conversus-gate.md` for the full resolver order.

Full adapter semantics (mode selection, preset wiring, timing) are in `scripts/dispatch/adapters/tool/conversus.sh` and `references/routing.md`.

### FR-17 Cost Emission

Sync emits observability records to `.orchestrator/execution-log.jsonl` in the M019 Tier 1 shape. M019 is the schema-evolution authority for this JSONL stream; M013 writes records that conform to M019 Tier 1 but does not extend the schema.

Two record types fire from the sync path:

- **`unit_close`** — one per Done-phase closure, task-close, or sub-Issue close. Mirrors the orchestrator-native `unit_close` record emitted at phase-transition time, with `source: "runtime"` to distinguish the sync-path emission from orchestrator-native emissions.
- **`conversus_gate_invocation`** — one per gate call (whether verdict is pass, block, or timeout). Captures `verdict`, `wall_clock_ms`, `oid`, and adapter-invocation identifiers so the gate's effect on sync latency is visible downstream.

See § Observability Record Schema for field-by-field details. Both record types follow the M019 Tier 1 contract: JSONL append-only, UTF-8, one record per line, no newlines inside field values.

### Sync Modes

The `sync_mode` field in the sidecar (see § `sync_mode` Enum for the P01 enum definition) governs when sync fires. P04 wires the three modes:

- **`manual`** (default) — sync runs only when the operator explicitly invokes `orchestrator:github sync`. No hook, no scheduler. This is the safest posture and the only mode where the operator retains full control of GitHub API spend.
- **`on-transition`** — sync fires as a post-verify hook after every task verification pass. The Claude Code runtime adapter (`scripts/dispatch/adapters/runtime/claude-code.sh`) registers a `post_verify` hook at install time (see `packaging/bundle/hooks/post-verify.json`) that invokes `scripts/lifecycle/after-verify-sync.sh`, which in turn invokes `scripts/integrations/github-sync.sh` when `sync_mode == "on-transition"`. Per FR-12, on-transition wiring is Claude-Code-only for v1 — Codex CLI and Cursor fall back to `manual` silently (no dual code-path; absence of the hook is the fallback).
- **`cron`** — operator installs an external cron line. The advisory cron expression surfaced at init time (`recommended_cron` field, default `*/15 * * * *`) is a hint only — orchestrator never writes to the operator's crontab. Registration guidance: operator adds `*/15 * * * * cd /path/to/repo && bash scripts/integrations/github-sync.sh >> /var/log/orchestrator-sync.log 2>&1` (or equivalent) to their own crontab.

The mode does not change silently — it is operator-set at init time (or via a re-init) and persists in the sidecar.

### Rate-Limit & Auth-Expiry Semantics

FR-16 defines two exit-code boundaries that both `init` and `sync` share:

- **`rc=3` — rate-limit**. Before any run with projected GraphQL volume > 50 mutations, `gh api rate_limit` is pre-flighted. When the remaining quota is below the projected volume, the script exits 3 with a `RATE-LIMIT: retry-after=<ISO-8601>` diagnostic on stderr. No auto-retry inside the rate-limit window — operator waits, then retries. The `<ISO-8601>` timestamp is the GitHub-reported reset time.
- **`rc=4` — auth-expired**. `gh_auth_preflight` calls `gh auth status` and inspects `X-Oauth-Scopes` from `gh api user -i`. On missing scope or expired token, exit 4 with `AUTH-EXPIRED: run gh auth refresh` (or `gh auth refresh -s <scope>` when a specific scope is missing). No auto-refresh.

Both rates are operator-owned remediation paths. The orchestrator does not mutate the operator's `~/.config/gh/hosts.yml` or token state.

### Observability Record Schema

Both record types emit to `.orchestrator/execution-log.jsonl` in M019 Tier 1 shape. Field schemas:

**`unit_close`**:

| Field | Type | Semantics |
|-------|------|-----------|
| `schema_version` | integer | M019 Tier 1 schema version pinned at time of emit. |
| `record_type` | string | Literal `"unit_close"`. |
| `source` | string | `"runtime"` when emitted from the sync path; `"orchestrator"` when emitted from the phase-transition path. |
| `emitted_at` | ISO-8601 | UTC timestamp of record emission. |
| `milestone` | string | `M###` id. |
| `phase` | string \| null | `P##` id (null for milestone-close records). |
| `task` | string \| null | `T##` id (null for phase-close records). |
| `oid` | string | `M###-P##[-T##]` orchestrator-id. |
| `github_issue_number` | integer \| null | Cached issue number if a projection existed; null if no projection. |
| `action` | string | `"close"` (sub-Issue close) or `"status-sync"` (Project v2 Status flip). |
| `cost_usd` | number | Cost in USD; zero for non-LLM-gated actions. |
| `cost_source` | string | M019 cost-source closed enum (MEM016). |

**`conversus_gate_invocation`**:

| Field | Type | Semantics |
|-------|------|-----------|
| `schema_version` | integer | M019 Tier 1 schema version. |
| `record_type` | string | Literal `"conversus_gate_invocation"`. |
| `source` | string | `"runtime"`. |
| `emitted_at` | ISO-8601 | UTC emission timestamp. |
| `oid` | string | Orchestrator-id of the UAT defect that triggered the gate. |
| `verdict` | string | `"pass"` \| `"block"` \| `"timeout"` \| `"adapter-unavailable"`. |
| `wall_clock_ms` | integer | Total wall-clock duration of the conversus call in milliseconds. |
| `cost_usd` | number | Cost in USD (aggregated across adapter agent invocations). |
| `cost_source` | string | M019 cost-source closed enum. |

Byte-level JSONL discipline: UTF-8, one record per line, no newlines inside field values, append-only. Schema evolution is M019's authority — M013 writes records that validate against M019 Tier 1 but does not extend the schema.

### `--verify-cache` Semantics

`orchestrator:github status --verify-cache` (FR-18) walks each cached `items.<oid>` and probes the remote via `gh_marker_search_remote`, emitting one `DIVERGENCE:` line per class. Three classes are defined:

- **`missing-remote`** — cache has the entry; remote Issue has no marker-matching result (or `gh` returns empty). Cached issue number listed for operator context. Most common after a manual issue deletion on GitHub.
- **`missing-cache`** — remote has a marker-bearing Issue for an orchestrator-id; cache has no entry. Requires a repo-wide marker-grep sweep; P04 ships the per-item probe path only, with the repo-wide scope flagged as operator-owned (commentary in the script). Detection of this class is operator-driven pending a future extension.
- **`status-mismatch`** — cache carries `status_field_synced: true` but the remote Project v2 Status field value does not match the orchestrator's derived state. Detection requires a GraphQL read; not wired in P04's probe body — reserved for future extension.

**Exit-code contract**:

- `rc=0` — zero divergences. `SUMMARY: --verify-cache divergences=0` on final stdout line.
- `rc=5` — ≥1 divergence. `SUMMARY: --verify-cache divergences=<N>`.
- `rc=0` with `STATUS: pending-operator-complete` on absent / pending sidecar (FR-11 reversibility — not an error, just a no-op).

**Non-repair contract**: `--verify-cache` **never writes** — not to the sidecar, not to GitHub. It is a read-only divergence reporter. Byte-identity of the sidecar file is preserved across every invocation. Operator decides the remediation path (re-init, manual issue create on GitHub, etc.) after inspecting the divergence report.

### Conversus Gate Invocation Contract

The contract below supplements § Conversus Pre-Merge Gate with the precise invocation shape:

| Property | Value |
|----------|-------|
| Mode | `strict` (block-on-disagreement) |
| Timeout | 30s hard wall-clock |
| Verdict surface | GitHub Issue comment on the UAT defect Issue, posted before close |
| Exit-code on block | `rc=1` from sync; close does NOT fire |
| Exit-code on timeout | `rc=1` from sync; close does NOT fire; `CONVERSUS-TIMEOUT:` on stderr |
| Exit-code on adapter-unavailable | `rc=1` from sync; close does NOT fire; `CONVERSUS-UNAVAILABLE:` on stderr |
| Adapter path | `scripts/dispatch/adapters/tool/conversus.sh` (M011/P07 surface) |
| D007 boundary | conversus is a tool adapter invoked by M013; not reimplemented inside M013. |

The adapter is the single source of truth for conversus mode semantics. M013 is a caller, not an owner of the conversus surface.

## Referenced Artifacts (P01 + P02)

### P01 artifacts

- `.orchestrator/integrations/github.json` — sidecar config (operator-owned, gitignored).
- `templates/github-integration-sidecar.json` — canonical schema template.
- `scripts/integrations/sidecar-init-pending.sh` — bootstrap helper (clobber-refuses with exit 2).
- `scripts/integrations/github-status.sh` — read-only reporter (zero `gh` subprocess calls at P01).
- `commands/github-status.md` — `orchestrator:github status` subcommand definition.
- `.github/ISSUE_TEMPLATE/uat-bug.yml` — UAT Bug Issue Form with required `spec_chunk_id` input.
- `scripts/knowledge/rebuild-index.sh` — widened with the additive `## Spec Chunks` section emit.
- `scripts/knowledge/lib/index-utils.sh` — hosts the `emit_spec_chunks_section` helper (pure-lib extraction per MEM004).
- `knowledge/spec/defect/README.md` — authoritative `SPEC-DEFECT-NNN` frontmatter schema contract.
- `scripts/integrations/uat-ingest.sh` — fixture-driven ingester (python3-preferred JSON reader with grep/sed fallback, zero `gh` at P01).

### P02 additions

- `scripts/integrations/github-common.sh` — shared helpers (orchestrator-id derivation, marker emit/search, sidecar upsert, FR-15 manifest format).
- `scripts/integrations/github-init.sh` — create-path implementation.
- `commands/github-init.md` — `orchestrator:github init` subcommand definition (MEM012 structure).
- Sidecar schema extension: `sub_issue_mode` field documented in § Sub-Issue Representation Modes.

## Further Reading

- `specs/023-github-native-integration/spec.md` — feature specification (Ready-for-discuss post-D014).
- `.orchestrator/DECISIONS.md` — D007 (projection-not-peer), D013 (M020 promotion), D014 (conversus pressure-test rulings).
- `.orchestrator/memory/constitution.md` — Principles XIV (No Speculative Complexity) and XV (Surgical Precision) pinning the scope discipline.
- `references/state-machine.md` and `references/file-formats.md` — shape references for orchestrator state docs.
- `.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md` — the 1-of-3 evaluation that promoted M020 per D013.
