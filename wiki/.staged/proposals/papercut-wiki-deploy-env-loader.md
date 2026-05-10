---
schema_version: "1.0"
type: proposal
status: pending
priority: high (PBJ this week)
captured_at: "2026-05-06"
captured_by: "operator-secrets-and-adaptive-init §5 pre-launch slice"
folds_into: |
  Standalone paper-cut shipped same day as the parent thinking-document.
  Layers 1+2 of the proposal at
  .orchestrator/proposals/operator-secrets-and-adaptive-init.md §3.
  Layer 3 (generalized secrets-recipe primitive) defers to post-launch
  demand-driven, gated by a second consumer.
---

# Paper-Cut: `wiki-deploy.sh` and `wiki-init.sh --with-giscus` are not
# connected by any persistence layer

## Finding

`scripts/wiki/wiki-deploy.sh` gate 1 hard-fails when any of the four
`GISCUS_*` env vars is unset
(`scripts/diagnostics/wiki-giscus-config-check.sh:84`). Operators who
opt into wiki+giscus today learn this by failing the gate, then read
`wiki/README.md` § "First-deploy checklist" (an 8-step recovery), then
hand-run `scripts/diagnostics/giscus-ids-from-gh.sh` to fetch the four
IDs and paste the four `export` lines into their shell.

`scripts/lifecycle/wiki-init.sh --with-giscus` (lines 449–538) already
fetches the four IDs via the helper, parses them, and sed-substitutes
them into `wiki/overrides/partials/comments.html` — but it persists
those values **nowhere the operator's deploy shell can read them**. The
fetch and the gate are not connected by any persistence layer.

The PBJ-central wiki ship this week will hit gate 1 on the operator's
first deploy attempt unless the persistence gap closes first.

## Practical impact

PBJ-central operator runs:

```
bash scripts/lifecycle/wiki-init.sh \
  --project-dir <pbj-central> --with-giscus \
  --repo <pbj-org>/<pbj-repo> --category "Wiki Comments"
```

…then `bash scripts/wiki/wiki-deploy.sh --dry-run` and gets
`GATE: giscus-config FAIL`. They have to read the wiki/README
recovery, run the fetcher script themselves, paste four lines into
their shell, and re-run deploy. Every team member who later wants to
re-deploy hits the same friction (env vars don't survive shell
restarts unless they were persisted into a profile file or
project-local `.env`).

The orchestrator owns the gate, owns the fetcher, and owns the
mkdocs.yml templating. It should own the persistence layer between
fetch and deploy.

## Deliverables

Four small changes shipped as one paper-cut PR. Layers 1+2 close the
fetch-vs-deploy gap; the .gitignore + docs work makes it operator-safe
and reduces the documentation surface that has to evolve in lockstep.

### 1. `scripts/wiki/wiki-deploy.sh` — Layer 1: source `<root>/.env`

Source `<ROOT>/.env` if present, BEFORE gate 1. ~3 lines of bash
guarded by `[ -f "$ROOT/.env" ]`. No flag, no behavior change for
operators who already export in their shell or for CI environments
where vars come from the runner.

Update gate 1's FAIL message to name `.env` and the fetcher script
(`scripts/diagnostics/giscus-ids-from-gh.sh`) so a fresh operator who
fails the gate gets a one-line recovery instead of a doc-pointer.

### 2. `scripts/lifecycle/wiki-init.sh --with-giscus` — Layer 2: write `.env`

After the FR-8 substitution loop completes (line ~517), append the
four `export GISCUS_*` lines to `<PROJECT_DIR>/.env` under a managed
marker block (mirrors the CLAUDE.md `# >>> orchestrator:recent-changes >>>`
pattern):

```
# >>> orchestrator-managed: giscus >>>
export GISCUS_REPO="..."
export GISCUS_REPO_ID="..."
export GISCUS_CATEGORY="..."
export GISCUS_CATEGORY_ID="..."
# <<< orchestrator-managed: giscus <<<
```

Idempotent: replace existing marker block on re-run rather than
appending duplicates.

### 3. `.gitignore` hygiene

The orchestrator repo's root `.gitignore:62-63` already ignores `.env`
+ `.env.*`. For operator projects that don't ignore `.env` yet, the
Layer 2 step warns-don't-blocks: prints `WARN: <project>/.env contains
operator secrets but is not gitignored — add '.env' to <project>/.gitignore
before committing` and proceeds. Block-on-warn would be safer but is
out of scope for a paper-cut.

### 4. `wiki/README.md` § "First-deploy checklist"

Collapse the 8-step recovery to:

1. Install giscus App + enable Discussions (steps 1+2 of today's
   checklist — operator UI, not scriptable).
2. Run `bash scripts/lifecycle/wiki-init.sh --project-dir <path>
   --with-giscus --repo <org>/<repo> --category "Wiki Comments"`.
3. Run `bash scripts/wiki/wiki-deploy.sh`.

Keep the original long-form under a `<details>` block titled "Manual
recovery (if `wiki-init --with-giscus` is unavailable)" so operators
who want to understand the underlying flow have it.

## Acceptance

- `bash scripts/lifecycle/wiki-init.sh --project-dir <fixture>
  --with-giscus --repo test-org/test-repo --category Test` with
  `M032_GISCUS_IDS_FROM_GH_STUB=1` writes `<fixture>/.env` containing
  the four `export GISCUS_*` lines under the managed marker block.
- `bash scripts/wiki/wiki-deploy.sh --dry-run` against the same
  fixture passes gate 1 without any pre-exported env vars in the
  invoking shell.
- Re-running `wiki-init --with-giscus` twice leaves `<fixture>/.env`
  with exactly one managed marker block (no duplication).
- `tests/m032-acceptance/run-acceptance-battery.sh` continues to pass
  with no regression in wiki-init's existing FR-8 contract.

## What this paper-cut is NOT

- NOT [M037](../milestones/M037/index.md) P02 scope. P02 stays narrow (round-3.5 polish bundle —
  F1.2 + F2 + F5 + 3 plugins) per the parent proposal §5.
- NOT a generalized secrets-recipe primitive (Layer 3 in the parent
  thinking-document). That defers post-launch until a second feature
  wants operator-managed secrets.
- NOT an analytics / Notion-sync / external-tool-token expansion. One
  feature, one persistence layer, today.
- NOT a `--deploy` workflow change. The Layer 2 hook fires inside the
  `--with-giscus` block only; the `--deploy` block at line 540+ is
  not touched.

## Cross-references

- [`.orchestrator/proposals/operator-secrets-and-adaptive-init.md`](../proposals/operator-secrets-and-adaptive-init.md) —
  parent thinking-document; [§3](../proposals/operator-secrets-and-adaptive-init.md#3-proposed-shape-layered-pre-deploy-secrets-pattern) and [§5](../proposals/operator-secrets-and-adaptive-init.md#5-pre-launch-slice-pbj-this-week-vs-post-launch) are the load-bearing sections.
- `scripts/wiki/wiki-deploy.sh:139-145` — gate 1 FAIL surface.
- `scripts/lifecycle/wiki-init.sh:449-538` — `--with-giscus` block to
  extend with `.env` write.
- `scripts/diagnostics/wiki-giscus-config-check.sh` — the gate
  implementation; consumes env vars from the invocation environment.
- `scripts/diagnostics/giscus-ids-from-gh.sh` — the fetcher Layer 2
  invokes (already idempotent and `gh`-driven).
- `wiki/README.md` § "First-deploy checklist" (lines 280-363) — the
  docs surface that collapses post-fix.
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` — existing FR-8
  contract; new acceptance test sits alongside it.
