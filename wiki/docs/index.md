---
title: "spec-kit-orchestrator dogfood wiki"
---

# spec-kit-orchestrator dogfood wiki

A browseable projection of the orchestrator's `.orchestrator/` state —
Constitution, Decisions, Knowledge, every milestone's plans and
summaries — rendered from canonical paths with no body-copy (AD-3).

## What this site is

The dogfood wiki is an internal MkDocs Material site generated from
the orchestrator's own state tree. Every rendered page is a thin
include stub pointing at a canonical `.orchestrator/**.md` artifact
(or a granular `knowledge/**/MEM*.md` entry). No artifact body is
copied into this site — the scanner enumerates paths, the stub
generator writes include-markdown shells, and MkDocs renders them at
build time.

This is **not** a public-facing site. External launch lives in M009.

## How to navigate

Five entry points live in the left navigation:

- **Constitution** — the seven governing principles.
  See [Constitution](constitution.md).
- **Decisions** — the architectural decisions register (AD-1..AD-19+).
  See [Decisions](decisions.md).
- **Knowledge** — consolidated narrative plus 25 granular MEM entries
  grouped by category. See [Knowledge](knowledge/index.md).
- **Milestone Summary** — the cross-milestone rollup + extension
  guide. See [Milestone Summary](milestone-summary.md).
- **Milestones** — per-milestone plans, phases, tasks, and summaries
  (M001..current). See [Milestones](milestones/index.md).

The top-right search box indexes every rendered page.

## Where to comment

Every page carries a Giscus thread at the bottom, anchored to that
page's URL path. Sign in with GitHub to post; threads persist across
redeploys. If an artifact is renamed or consolidated, the
`scripts/diagnostics/wiki-giscus-remap.sh` script migrates the
thread. See the `Remapping threads after consolidation` section of
the operator guide.

## Audience scope

This site is for the dogfood team — contributors who need to
navigate the orchestrator's decision history, knowledge, and
milestone progress without opening raw markdown. It is not a public
documentation site, not a user guide, and not a marketing page.
External documentation lives under `docs/` in the repo and ships via
M009 launch.

## Deploy & preview

Preview locally with `bash scripts/wiki/wiki-serve.sh` from the repo
root. Deploy via `bash scripts/wiki/wiki-deploy.sh` (the wrapper
chains link-check + Giscus config-check + smoke-test before invoking
`mkdocs gh-deploy --force` against the `gh-pages` branch). Both
commands plus the first-deploy checklist are documented in the
operator guide — see the repo-root `wiki/README.md`.
