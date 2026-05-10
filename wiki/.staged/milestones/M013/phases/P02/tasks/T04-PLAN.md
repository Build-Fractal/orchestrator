---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M013"
name: "commands/github-init.md subcommand definition"
depends_on: ["T02", "T03"]
---

## Prerequisites

- T02 has landed `scripts/integrations/github-init.sh` with full flag surface (`--dry-run`, `--i-am-operator`, `--strict-labels`, `--root`, `--repo-slug`).
- T03 has pinned the FR-15 `--dry-run` manifest format.
- MEM012 (Command File Structure) — all command `.md` files follow: YAML frontmatter (`description` field) → Title → Prerequisites / State Check → Core Workflow (numbered sections) → Output → Idempotency → Error Handling → Referenced Scripts/Templates. Integration tests verify all cross-references resolve to existing, executable files.
- Existing precedent: `commands/github-status.md` (from P01/T02) is the sibling doc — study its structure before authoring this one. Do NOT deviate from MEM012 structure.

## Description

Author `commands/github-init.md` — the `orchestrator:github init` subcommand definition following MEM012 structure. The doc is the agent-facing instruction surface; it tells the agent (and the human operator reading in the CLI runtime's doc viewer) when to invoke the script, what flags to pass, how to interpret the output, and how to handle errors.

## Steps

### Step 1: Author `commands/github-init.md`

Create the file with this exact structure (adapt the example contents as needed but preserve section headers and order):

```markdown
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
```

### Step 2: Validate against MEM012

- YAML frontmatter present with `description` field ✓
- Title follows (`# speckit.orchestrator.github-init`) ✓
- `## Prerequisites / State Check` section exists ✓
- `## Core Workflow` with numbered sub-items exists ✓
- `## Output` exists with concrete examples ✓
- `## Idempotency` section exists ✓
- `## Error Handling` section exists with exit codes ✓
- `## Referenced Scripts` lists every script invoked (by relative path) ✓
- `## Referenced Templates` lists every template invoked ✓

### Step 3: Spot-check cross-references

Every path mentioned in `Referenced Scripts` must exist on disk:

```bash
test -f scripts/integrations/github-init.sh
test -f scripts/integrations/github-common.sh
test -f scripts/integrations/sidecar-init-pending.sh
test -f scripts/integrations/github-status.sh
test -f templates/github-integration-sidecar.json
```

(The first two are produced by T01/T02; the latter two predate P02.)

## Must-Haves

- `commands/github-init.md` ≥50 lines, contains the literal string `github-init.sh`, follows MEM012 structure.
- All scripts/templates named in `Referenced Scripts` / `Referenced Templates` exist on disk (integration test catches missing references).
- The `description` field in frontmatter is single-line and starts with `Use when`.
- Auto-mode safety paragraph is present under Prerequisites / State Check (SC-7 contract).

## Verification

```bash
bash scripts/verify/m013-p02-github-init-command.sh
```

Expected:
```
PASS: commands/github-init.md present, ≥50 lines, contains 'github-init.sh'
PASS: MEM012 structure — frontmatter, Title, Prerequisites, Core Workflow, Output, Idempotency, Error Handling, Referenced Scripts
PASS: all 4 Referenced Scripts paths resolve to existing files
PASS: 1 Referenced Template path resolves
PASS: description field starts with 'Use when'
PASS: auto-mode pending-sentinel contract documented
```

Exit 0.

## Inputs

### From Previous Tasks

- `scripts/integrations/github-init.sh` (from T02 + T03)
  - Key API: `--dry-run`, `--i-am-operator`, `--strict-labels`, `--root`, `--repo-slug`. Exit codes 0/1/2/3. Output format: `MANIFEST:` + `UPSERT:` lines + footer.
  - T04 documents this API; does not call it.
- `scripts/integrations/github-common.sh` (from T01)
  - Named in Referenced Scripts.

### From Disk (Pre-existing)

- `commands/github-status.md` (from P01/T02) — sibling command doc to mirror for structure.
- `knowledge/patterns/MEM012.md` — authoritative MEM012 definition.
- `references/github-integration.md` — cross-linked (P02/T05 extends auth-modes content this command refers to).

## Constraints

- **MEM012 structure mandatory**: deviation fails the integration test that scans all `commands/*.md` for structural compliance.
- **No runtime-specific content**: FR-12 Claude-Code-only v1 applies to HOOK INSTALLATION (P04), not to this command doc. The doc is runtime-agnostic; the auto-mode paragraph is the only runtime-sensitive content and it applies uniformly.
- **Single-line `description` starting with `Use when`**: existing convention across all `commands/*.md`.
- **Cross-reference integrity**: every `Referenced Scripts` / `Referenced Templates` entry must resolve on disk.
- **Knowledge-Layer Boundary**: do not mention `KNOWLEDGE-INDEX.md` extensions beyond P01's existing `## Spec Chunks` section. Do not author new knowledge-tree writes.
- **No AD-19 violations in examples**: any inline command example shown in the Output section must be a single-script-file shape.

## Expected Output

T07 phase-suite reports the github-init-command gate PASS on green. The command is discoverable via the standard `commands/README.md` index (which P02/T05 does NOT update — that index is auto-generated or hand-maintained per the M011/P04 discipline; check with repo lead before adding an entry manually).
