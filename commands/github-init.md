---
description: "Use when initializing the M013 GitHub integration for a project — projects the current orchestrator state (milestone / phases / tasks) onto GitHub Issues / Milestones / Projects v2 with marker-bearing bodies. Opt-in and reversible (FR-11): deleting `.orchestrator/integrations/github.json` returns the orchestrator to pre-integration behavior."
---

# speckit.orchestrator.github-init

Project the current orchestrator milestone onto GitHub — creating a Milestone, a Project v2, the required labels (`phase`, `task`, `uat-bug`, `spec-gap`), one Issue per in-flight phase with a `label:phase`, and one sub-issue per task under its parent phase Issue. Every Issue body carries an `<!-- orchestrator-id: <id> -->` marker for idempotent re-sync. Writes back into the sidecar at `.orchestrator/integrations/github.json` so subsequent `status` and `sync` (P04) invocations can skip-before-create via marker search.

## Prerequisites / State Check

- `gh` CLI installed and authenticated (`gh auth status` green). Required scopes: `repo`, `project`, `read:org`. Auth mode details: see `references/github-integration.md` § Auth Modes.
- An orchestrator project with at least one in-flight milestone (ROADMAP committed, at least one phase in Ready/Executing/Verifying state).
- Sidecar schema bootstrapped — run `bash scripts/integrations/github-status.sh --init-pending` first if the sidecar is absent, OR pass `--i-am-operator` to this command to bootstrap + populate in one step.

**Auto-mode safety (SC-7)**: under `orchestrator:auto` (no TTY), this command writes the pending-sentinel sidecar and exits 0 with `STATUS: pending-operator-complete` without ever calling `gh` for writes. Live Issue/Project creation fires only when invoked interactively (TTY attached) or with the explicit `--i-am-operator` flag.

## Core Workflow

1. **Preflight**: invoke `bash scripts/integrations/github-init.sh --dry-run` first. This runs auth preflight (FR-2), sub-issue REST availability probe, and label-collision preflight. Confirm the manifest output matches your expectations:
   - `MANIFEST: <upserts> <skipped> <errors>` header
   - one `UPSERT:` line per projected resource
   - `upserts=N skipped=M errors=E` footer
   The manifest format is identical across `init --dry-run` and (later) `sync --dry-run` — FR-15.
2. **Authenticate**: if preflight reports `integration-auth-failed`, run `gh auth refresh -s project` (or the scope named in the diagnostic) before proceeding.
3. **Sub-issue mode**: preflight reports `SUBISSUE_MODE: native` or `SUBISSUE_MODE: labeled-fallback`. Native mode uses GitHub's sub-issue REST endpoint; labeled-fallback uses `parent:<phase-id>` + `child:<task-id>` labels plus reciprocal body links. The choice is recorded in the sidecar as `sub_issue_mode` and does not change without explicit re-init.
4. **Label collisions**: default is adopt-existing (color/description preserved). Pass `--strict-labels` to refuse with a diagnostic instead of adopting. See `references/github-integration.md` § FR-14 Label Collision.
5. **Live run**: once preflight is green, run `bash scripts/integrations/github-init.sh --i-am-operator`. The script creates all missing resources in walker order (milestone → project-v2 → labels → phase-issues → task-subissues → project-v2-items) and populates the sidecar with `repo_slug`, `project_v2_id`, `sub_issue_mode`, and one `items.<orchestrator-id>` entry per created Issue.
6. **Post-verify**: run `bash scripts/integrations/github-status.sh` — expected `STATUS: configured` with `CACHE_ITEMS: N` matching the create-path count.
7. **Re-run** (idempotency): a second invocation with unchanged orchestrator state produces `upserts=0 skipped=N errors=0` via marker search-before-create. No duplicate Issues are created (FR-4).
8. **FR-14 re-init adoption** — if `--re-init` is passed, or if the sidecar is absent and a marker-search probe finds a pre-existing remote Issue, the adoption pre-pass runs before create fan-out. Each marker-bearing remote Issue is adopted (sidecar row written, manifest row carries `reason=adopt`); remaining ids fall through to the create path. The footer gains an extra `adopted=<A>` field on any run where adoption fired (additive-optional; pure-create runs retain the byte-identical 3-field P02 footer). See `references/github-integration.md` § Re-init Adoption Contract for the full adoption algorithm. Available flags: `--dry-run`, `--i-am-operator`, `--strict-labels`, `--re-init`, `--root <project-root>`, `--repo-slug <owner/name>`.

## Output

First invocation (live, operator, TTY):

```
MANIFEST: 12 0 0
UPSERT: milestone M013 https://github.com/owner/repo/milestone/1 create
UPSERT: project-v2 - PVT_kwXXXXXX create
UPSERT: label - phase create
...
UPSERT: task-subissue M013-P02-T02 https://github.com/owner/repo/issues/24 create
UPSERT: project-v2-item M013-P02-T02 PVTI_xxxxx create
upserts=12 skipped=0 errors=0
STATUS: configured
REPO_SLUG: owner/repo
SYNC_MODE: manual
LAST_SYNC: never
CACHE_ITEMS: 12
```

Auto-mode (no TTY, no `--i-am-operator`):

```
STATUS: pending-operator-complete
HINT: run 'orchestrator:github init' interactively (or with --i-am-operator) to populate the sidecar.
```

Second invocation (live, unchanged state):

```
MANIFEST: 0 12 0
UPSERT: milestone M013 https://github.com/owner/repo/milestone/1 skip-existing-marker
...
upserts=0 skipped=12 errors=0
```

## Idempotency

Fully idempotent after first successful live run. A second invocation with unchanged orchestrator state:

- finds every Issue by marker search (FR-4),
- reports `UPSERT: ... skip-existing-marker` for every resource,
- writes `upserts=0 skipped=N errors=0`,
- leaves the sidecar byte-identical.

If the sidecar is deleted but the remote Issues still carry markers, `init` refuses to create duplicates but does NOT repair the sidecar from remote state — that re-adoption path lives in `orchestrator:github sync` (P03 wiring, P04 full support). For v1, the operator deletes the remote Issues before re-running `init` if a fresh start is needed.

## Error Handling

- `exit 0` — success (including the auto-mode pending-sentinel path and all idempotent skip paths).
- `exit 1` — one or more upsert errors during a live run. The footer line `upserts=N skipped=M errors=E` reports the count. Per-error diagnostic lines precede the footer.
- `exit 2` — invalid CLI flag. Run `bash scripts/integrations/github-init.sh --help`.
- `exit 3` — preflight refused to proceed: `integration-auth-failed` (FR-2), `integration-labels-collision` (`--strict-labels` + pre-existing non-matching label), or `integration-marker-duplicate` (two remote Issues carry the same `<!-- orchestrator-id: <id> -->` marker — operator must reconcile in GitHub before re-running).

## Referenced Scripts

- `scripts/integrations/github-init.sh` — the create-path implementation (this command's workhorse).
- `scripts/integrations/github-common.sh` — shared helpers (orchestrator-id derivation, marker emit/search, sidecar upsert, FR-15 manifest format).
- `scripts/integrations/sidecar-init-pending.sh` — invoked under auto-mode to bootstrap the pending-sentinel sidecar (P01).
- `scripts/integrations/github-status.sh` — read-only post-init verification (P01).

## Referenced Templates

- `templates/github-integration-sidecar.json` — canonical sidecar schema (P01, extended in P02/T06 with `sub_issue_mode`).
