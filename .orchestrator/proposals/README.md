# Future-Milestone Proposals

Captured 2026-04-27. Source: session reviewing `~/Sites/conversus-oss` for adoptable patterns and a fresh sweep of `orchestrator:auto` interruption screenshots.

These docs are inputs for `orchestrator:specify` (and downstream `orchestrator:evaluate` / `orchestrator:roadmap`) when each milestone enters the planning queue. They are *not* themselves specs — they are briefs intended to give specify enough context to produce a tight spec without re-doing the analysis.

## Proposals

| ID | Title | Shape | Standalone? |
|---|---|---|---|
| `constitution-amendment-inclusion-criteria.md` | Inclusion-criteria gate + governance log + distribution-surface integrity | Constitution PR (~50 LOC + 1 new doc) | Yes — no milestone needed |
| `M026-autonomous-hardening-v3.md` | Hook portability + 4 new shape classes + investigation-pattern wrappers | Milestone (5 phases) or 2 quick PRs | Some phases standalone |
| `M027-roadmap-visibility-and-cli-ux.md` | `orchestrator:where` tree renderer + invocation-context resolver + headline status + M013 GitHub coupling | Milestone (3 phases) | No — coherent feature |

## Sequencing recommendation

Current forward queue (per `CLAUDE.md`, revised 2026-04-22 per D016):

> M014 (extended) → M020 → M024 → M019 Tier 2+3 → M018 → M023 → M009 (extended) → M010 (adjusted)

Proposed insertion points:

```
[constitution-amendment]   ← any time, single PR, no dependencies
M014 (extended)
M026 (autonomous hardening v3)   ← INSERT HERE — see rationale below
M020
M024
M019 Tier 2+3
M018  ← currently active
M023
M027 (roadmap visibility + CLI UX)   ← INSERT HERE
M009 (extended)
M010 (adjusted)
```

### Why M026 before M024

M024 (universal intake & routing) will run under `orchestrator:auto` against arbitrary input and is intended to be exercised in *downstream consumer projects*. The screenshots that motivated M026 reveal the M021 shape guard fails-open in projects outside the orchestrator repo (script path resolution via `$CLAUDE_PROJECT_DIR`). Without M026's hook-portability fix, M024's autonomous runs will be interrupted by the same shapes M021 already classified — wasting the M021 investment. Hook portability is the load-bearing item; it's worth doing before any further autonomous-run-heavy milestone.

If empirical replay (P01 of M026) shows only 1-2 screenshots actually leak past the existing classifier when the hook *is* portable, M026 can collapse into 2 quick PRs (hook portability + corpus extension) and not block M024 at all.

### Why M027 after M023

M027 is launch-polish — it makes the orchestrator's autonomous execution legible to humans (and to the M013 GitHub board). It's not blocking; it's the kind of feature that materially improves first-impression adoption *at launch*. M023 (design layer) is currently the last pre-launch gate before M009. M027 fits naturally between them: M023 produces design contracts, M027 makes the runtime visible. Both feed into M009's runtime-parity audit.

### Why constitution amendment any time

The amendment is doc-only and self-contained. It introduces a *gate* for future principle additions — landing it before any large milestone reduces the chance that future milestones accrete weak principles. Cheapest, earliest land.

## Active-milestone safety note

M018 (Context Compression Layer) is currently executing under `orchestrator:auto` on branch `feat/m018-context-compression` (lock held). These proposal docs are isolated under `.orchestrator/proposals/` and do not touch:
- `.orchestrator/milestones/M018/**`
- `.orchestrator/orchestrator.lock`
- `.orchestrator/execution-log.jsonl`
- `knowledge/**` (M018 consolidation pass is rewriting these)
- Any file currently `M` in `git status`

The proposals can be committed at any time without affecting M018's autonomous run.

## Source material

- Session transcript: 2026-04-27 (no archive — content captured in proposal docs)
- Conversus reference: `~/Sites/conversus-oss` (CONSTITUTION.md, engine/cli/, docs/user-guide/)
- Auto-interruption screenshots: 7 screenshots dated 2026-04-25 to 2026-04-26 — patterns extracted into `M026-autonomous-hardening-v3.md` §3
- Existing infrastructure to extend: M021 corpus (`tests/fixtures/m021-prompt-corpus.txt`), classifier (`scripts/verify/lib/shape-classifier.sh`), hook (`scripts/hooks/pre-bash-shape-guard.sh`), antipattern register (`ANTIPATTERNS.md` AP-001 through AP-009)
