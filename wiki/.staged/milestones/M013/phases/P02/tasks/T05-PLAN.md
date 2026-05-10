---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M013"
name: "references/github-integration.md P02 extensions — Auth Modes + Sub-Issue Modes + Partial Mapping Table"
depends_on: ["T01"]
---

## Prerequisites

- P01 has landed `references/github-integration.md` with three `TODO P02` reserved stubs:
  - `### TODO P02: Auth Modes`
  - `### TODO P02: Full Mapping Table`
  - `### TODO P02: init Workflow`
- Additionally, the Scope Boundary table in that doc has `TODO P02` cells that need their `P02` column populated now.
- T01 landed `scripts/integrations/github-common.sh` including the FR-15 manifest format helpers.
- T02/T03 landed `scripts/integrations/github-init.sh` with auth/sub-issue/label preflights and manifest emission.
- The P01 doc at `references/github-integration.md` is the SSOT. P02 extends it **in place**, strictly filling reserved stubs — it does NOT rewrite P01-authored sections. Byte-identity on P01-authored sections is gated by T07.

## Description

Fill the three `TODO P02` stubs in `references/github-integration.md` + update the Scope Boundary table's P02 column. Author:

1. **Auth Modes** — replace the `### TODO P02: Auth Modes` stub with a full subsection: PAT classic, PAT fine-grained, GitHub App installation, `gh` OAuth. For each: required scopes table, token storage location, rotation notes, rate-limit budget profile.
2. **Sub-Issue Representation Modes** — new subsection documenting `native` vs `labeled-fallback` modes, preflight semantics, sidecar-recorded choice, failure modes.
3. **Partial Mapping Table (P02 rows filled; P03 rows deferred in place)** — replace the `### TODO P02: Full Mapping Table` stub with a table of orchestrator-concept ↔ GitHub-resource mappings. Milestone, phase, task rows fully populated; spec chunk, acceptance criterion, verification status rows present with cells marked `_deferred to P03_`.
4. **`init` Workflow** — replace the `### TODO P02: init Workflow` stub with a walk-through: preflight → manifest → live run → post-verify.
5. **Dry-Run Manifest Format** — NEW subsection (not a stub replacement) documenting the FR-15 format pinned by T03.
6. **Scope Boundary table update** — P02 cells replaced with actual content (e.g., "shipped", "extends items population").

## Steps

### Step 1: Read the existing `references/github-integration.md`

Identify the three `TODO P02` stub markers and the Scope Boundary table. These are the only locations P02 modifies. All P01-authored content (Overview, Sidecar Config Schema, Pending-Sentinel Semantics, `sync_mode` Enum, Marker Format, UAT Ingestion Contract, Knowledge-Layer Boundary, Scope Boundary (P01 column only), Referenced Artifacts, Further Reading) stays byte-identical.

### Step 2: Replace `### TODO P02: Auth Modes` with:

```markdown
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
```

### Step 3: Insert NEW subsection "Sub-Issue Representation Modes" (between Marker Format and UAT Ingestion Contract, or wherever the P01 doc's flow suggests — do NOT modify surrounding P01 prose):

```markdown
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
```

### Step 4: Replace `### TODO P02: Full Mapping Table` with:

```markdown
### Partial Mapping Table (P02)

Orchestrator state → GitHub resource projection. P02 populates phase/task/milestone/label/project-v2 rows; chunk/AC/verification-status rows are scaffolded for P03 completion.

| Orchestrator concept | GitHub resource | Creator | Marker / Key | Lifecycle |
|----------------------|-----------------|---------|--------------|-----------|
| Milestone | Milestone | `init` | title = `M###-<slug>` | close on consolidate (P04) |
| Phase | Issue with `label:phase` | `init` | body marker `<!-- orchestrator-id: M###-P## -->` | close on P##-SUMMARY.md landing (P04) |
| Task | Sub-issue (native) or `label:task` Issue (labeled-fallback) linked under parent phase Issue | `init` | body marker `<!-- orchestrator-id: M###-P##-T## -->` | close on T##-SUMMARY.md landing (P04) |
| Project (per milestone) | Project v2 | `init` | single Project per orchestrator milestone | - |
| Project item | Project v2 item (Issue attached) | `init` via `addProjectV2ItemById` | `orchestrator-id` custom field | status transitions (P04 via `updateProjectV2ItemFieldValue`) |
| Required label set | `phase`, `task`, `uat-bug`, `spec-gap` | `init` (adopted or created per FR-14 label preflight) | name | - |
| **Spec chunk** | **Issue custom field (chunk-URL)** | **_deferred to P03_** | **_deferred to P03_** | **_deferred to P03_** |
| **Acceptance criterion** | **Checklist item in Issue body** | **_deferred to P03_** | **_deferred to P03_** | **_deferred to P03_** |
| **Verification status** | **Project v2 Status field** | **_deferred to P03_** | **_deferred to P03_** | **P04 sync owns transitions** |

P03 fills the bold rows in place. P02 must not populate them — the deferral is load-bearing (D015 scope split).

#### FR-14 Label Collision

`init` enumerates pre-existing labels matching names it would create (`phase`, `task`, `uat-bug`, `spec-gap`). Default: **adopt-without-modification** — the existing label's color/description is preserved. With `--strict-labels`: **refuse** with `integration-labels-collision: <label-name>` diagnostic and exit 3. Re-init from sidecar-absent + marker-bearing remote state (FR-14 full re-adoption) is deferred to P03; P02 handles only the create path's label-collision case.
```

### Step 5: Replace `### TODO P02: init Workflow` with:

```markdown
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
```

### Step 6: Update the Scope Boundary table's P02 column

Find the table in P01 doc ("## Scope Boundary (P01 vs. P02 vs. P03)") and replace the `TODO P02` cells with concise verbs. Example:

| Section | P01 | P02 | P03 |
|---------|-----|-----|-----|
| Sidecar schema | shipped | `items.<id>` population + `sub_issue_mode` field added | per-item status tracking (P04) |
| Pending sentinel | shipped | reversed on successful init | — |
| `sync_mode` enum | shipped | operator-set at init (still `manual` default) | runtime wiring (P04) |
| Marker format | shipped | REST search-by-marker + emit + shasum byte-identity verify shipped | — |
| UAT ingestion | shipped | — | optional live `gh issue list` pull (P03) |
| Auth modes | — | **shipped** (this doc) | — |
| Full mapping table | — | **partial** (phase/task/milestone rows; chunk/AC/status deferred) | **completed in place** |
| `init` workflow | — | **shipped** (this doc + script T02/T03) | re-init adoption (FR-14 full) |
| `sync` workflow | — | — | TODO P04 |
| Conversus pre-merge gate | — | — | TODO P04 |
| FR-17 cost emission | — | — | TODO P04 |

### Step 7: Update the Referenced Artifacts list

Add new P02 entries without removing P01 entries:

```markdown
## Referenced Artifacts (P01 + P02)

<existing P01 artifacts stay byte-identical>

### P02 additions
- `scripts/integrations/github-common.sh` — shared helpers (orchestrator-id derivation, marker emit/search, sidecar upsert, FR-15 manifest format).
- `scripts/integrations/github-init.sh` — create-path implementation.
- `commands/github-init.md` — `orchestrator:github init` subcommand definition (MEM012 structure).
- Sidecar schema extension: `sub_issue_mode` field documented in § Sub-Issue Representation Modes.
```

## Must-Haves

- `references/github-integration.md` ≥240 lines (from 207 baseline), contains `Auth Modes`.
- Contains `Sub-Issue Representation Modes` section.
- Contains `Partial Mapping Table (P02)` with three `_deferred to P03_` rows.
- Contains `init Workflow` section.
- Contains `Dry-Run Manifest Format` section.
- The three `TODO P02:` headings are REMOVED (replaced with their final content).
- All P01-authored sections remain byte-identical (Overview, Sidecar Config Schema, Pending-Sentinel Semantics, `sync_mode` Enum, Marker Format body, UAT Ingestion Contract, Knowledge-Layer Boundary, Further Reading).

## Verification

```bash
bash scripts/verify/m013-p02-reference-extensions.sh
```

Expected:
```
PASS: references/github-integration.md present, ≥240 lines, contains 'Auth Modes'
PASS: 'Sub-Issue Representation Modes' subsection present
PASS: 'Partial Mapping Table' present with 3 '_deferred to P03_' cells
PASS: 'init Workflow' subsection present
PASS: 'Dry-Run Manifest Format' subsection present
PASS: No 'TODO P02' markers remain
PASS: P01-authored sections byte-identical (Overview / Sidecar Config Schema / Pending-Sentinel / sync_mode Enum / Marker Format / UAT Ingestion Contract / Knowledge-Layer Boundary preserved)
```

Exit 0.

## Inputs

### From Previous Tasks

- `scripts/integrations/github-common.sh` (from T01; T03 extended)
  - Key API references: `orchestrator_id_for`, `emit_marker`, `manifest_header`, `manifest_upsert_line`, `manifest_footer`, `sidecar_upsert_item`.
- `scripts/integrations/github-init.sh` (from T02/T03)
  - Key API: `--dry-run`, `--i-am-operator`, `--strict-labels`, `--repo-slug`.

### From Disk (Pre-existing)

- `references/github-integration.md` (from P01/T06) — the target file; extended in place.
- `commands/github-init.md` (from T04) — cross-linked.
- `templates/github-integration-sidecar.json` (from P01/T01; T06 extends) — cross-linked.
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — D014 (Knowledge-Layer Boundary), D015 (P02 scope split).

## Constraints

- **Byte-identity on P01-authored sections**: the T07 gate diffs specific line ranges against a P01 snapshot. Only the three `TODO P02:` stubs + the Scope Boundary table P02 column + the Referenced Artifacts list may change.
- **`_deferred to P03_` cells are load-bearing**: P03 fills them in place — this task must NOT populate them.
- **Knowledge-Layer Boundary**: no new knowledge-tree primitives described. Cross-link to P01's existing § Knowledge-Layer Boundary subsection for the authoritative framing.
- **No FR-5 lint authored here**: the three-shape GraphQL lint ships in P03. Document the three shapes by name in the Mapping Table, but do not claim lint exists.
- **No re-init adoption content**: FR-14 full re-adoption is P03 — state this deferral explicitly in the mapping table and Scope Boundary table.
- **No `sync` content beyond the FR-15 format cross-link**: `orchestrator:github sync` is P04. P02 only pins the dry-run format contract.
- **Bash 3.2 irrelevant** (this is a markdown file), BUT any shell command example must be single-script-file shape.

## Expected Output

T07 phase-suite reports the reference-extensions gate PASS on green. Operator reading the doc at the P02 close boundary should find: four auth modes with scope tables, a clear sub-issue mode decision flow, a partial mapping table that signals what P03 will add, a complete `init` workflow walkthrough, and the FR-15 manifest format pinned. No `TODO P02:` markers remain; three `TODO P03:` markers still present for P03 to fill.
