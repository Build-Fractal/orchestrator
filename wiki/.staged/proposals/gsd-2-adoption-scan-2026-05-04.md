# GSD 2 Adoption Scan — 2026-05-04

**Captured**: 2026-05-04 from a scan of `gsd-build/gsd-2` v2.79 + v2.80 releases (tweet-headlined: Context Mode, `--deep` planning, GsdWorkspace, DB-Authoritative Runtime).
**Shape**: Mixed — one new-milestone candidate (Context Mode → `orchestrator:exec`), three M033/post-[M033](../milestones/M033/index.md) amendments, four paper-cut sweeps, one constitution-adjacent governance item.
**Source**: GSD v2.79 release (2026-05-03) + v2.80 release (2026-05-04) + spike-wrap-up skill discovered in-tree. Compared against CLAUDE.md forward roadmap, M033 brief, M028/M034 briefs, and our existing dispatch / observability surfaces.
**Author note**: This proposal is the document of record for adoption decisions. Each item has a verdict (`adopt-now` / `adopt-deferred` / `defer-until-signal` / `do-not-adopt`) and a target landing location.

## Headline finding

GSD v2.79+v2.80 ship **one substantive primitive we lack** (Context Mode — keeping subprocess output off-context), **two UX patterns worth folding into our roadmap** (`--auto-chain` single-command flow + project-shape classifier feeding discuss-cadence), and **a cluster of hardening lessons** (lease-based locks, realpath canonicalization, retry boundaries) that translate cleanly to file-based equivalents.

The big one is **Context Mode**. Everything else is small-to-medium follow-on.

## Where each item lands (summary table)

| # | Item | Verdict | Target landing |
|---|------|---------|---------------|
| 1 | `orchestrator:exec` (Context Mode primitive) | adopt-now | **New milestone candidate** — see Q1 |
| 2 | `--auto-chain` flag on `orchestrator:start` | adopt-deferred | **Post-M033 fast-follow** (not P05 — scope risk) |
| 3 | Project-shape classifier in `discuss` | adopt-deferred | **`orchestrator:discuss` amendment** — independent of M033 |
| 4 | Description-as-trigger audit | adopt-now | Paper-cut sweep |
| 5 | `realpath` audit on state resolvers | adopt-now | Paper-cut sweep |
| 6 | Lease-based locks for `orchestrator:auto` | adopt-deferred | **[M028](../milestones/M028/index.md) follow-up** or new autonomous-hardening milestone |
| 7 | Soft-warning verdict tier in verifier ladder | adopt-deferred | **M034 brief amendment** |
| 8 | Doctor enrichment (orphan dirs, retry counters) | adopt-now | Paper-cut sweep |
| 9 | Anthropic prompt-cache regression test | adopt-now | Paper-cut sweep |
| 10 | Auto rate-limiting + reactive-parallelism heuristic | defer-until-signal | Post-launch fast-follow |
| 11 | Safety bundle (`$HOME` guard, git-index lock, commit subject sanitize) | adopt-now | Paper-cut sweep |
| 12 | [M013](../milestones/M013/index.md) GitHub-sync retry-boundary audit | adopt-now | Paper-cut sweep audit pass |
| 13 | Spike → durable skill bridge | defer-until-signal | Post-launch knowledge-layer fast-follow |
| 14 | Delegation-policy table (per-tool background-safety) | adopt-deferred | **Standalone amendment** alongside constitution-amendment-inclusion-criteria |
| — | DB-authoritative state migration | **do-not-adopt** | Conflicts with Principle VI |
| — | Phase 11 "deep" as a third intensity tier | **do-not-adopt** | Axis-creep on top of Quick/Standard/Full + Tier A/B/C |

## Item details

### 1. `orchestrator:exec` — Context Mode primitive (the headline adoption)

**What GSD shipped** (v2.80, PR #5256): Context Mode default-on, with three new tools wired through a `UnitContextManifest`:
- `gsd_exec` — runs a command, persists full stdout/stderr to `.gsd/exec/`, returns only metadata + summary
- `gsd_exec_search` — rediscovers prior runs by command/regex/exit-status
- `gsd_resume` — reads `.gsd/last-snapshot.md` after compaction
- Compaction snapshots written *before* active-auto cancellation
- Per-unit-type lanes declared in manifest, central composer renders guidance into prompts

**Why it matters for us**: This is a *new axis of context discipline*. Our existing surfaces ([M027](../milestones/M027/index.md) efficiency-footer, [M031](../milestones/M031/index.md) build-context profiles, [M018](../milestones/M018/index.md) compression-tier) act on **input assembly**. Context Mode acts on **subprocess output** — test logs, build output, lint reports, search results that bloat conversations during long autonomous runs. **We have no analog primitive.** It's a Principle I refinement.

**What we'd ship**:
- `scripts/dispatch/exec.sh` — runs a command, writes full output to `.orchestrator/exec/<unit>/<timestamp>/{stdout,stderr,meta.json}`, returns to model: exit code, byte counts, summary line, search-key
- `scripts/dispatch/exec-search.sh` — grep/filter prior runs by command pattern, exit status, time range
- `scripts/dispatch/exec-resume.sh` — reads last snapshot for post-compaction recovery
- Manifest hook: per-task-type "exec lanes" declared in plan frontmatter (e.g., `exec_mode: capture` for verifier runs, `exec_mode: stream` for short commands)
- [M019](../milestones/M019/index.md) JSONL emitter integration: every exec run is a first-class observability event with `unit_close`-shaped record
- `commands/dispatch.md` documents the new mode + when to use it

**Effort estimate**: Milestone-shaped (4–5 phases). Foundation primitive that touches dispatch, observability (M019), efficiency surfaces (M027), and the manifest format (M030/M031). Not a paper-cut.

**Risk**: Medium. The exec contract is straightforward but the manifest-lane integration touches enough surfaces that it deserves its own goal-backward pass.

**Q1 (open question for user)**: Slot as **[M037](../milestones/M037/index.md) (context-output discipline)** as a new pre-launch milestone, or **fold into a future autonomous-hardening v4** post-launch? Pre-launch slotting means amending the launch sequencing (currently [M032](../milestones/M032/index.md)+M033 → [M029](../milestones/M029/index.md) → [M035](../milestones/M035/index.md)). Post-launch means real users miss it on day one but launch isn't blocked. Recommendation: **defer to post-launch** — the cost-of-delay isn't acute (M027 efficiency surfaces will catch obvious bloat) and the blast-radius of mis-shaping the manifest contract pre-launch is real. But this is a judgment call worth your input.

### 2. `--auto-chain` flag on `orchestrator:start`

**What GSD shipped** (v2.79, commit `4eb53e9`): `/gsd new-project --deep` runs project-level discovery (PROJECT.md + REQUIREMENTS.md) before milestone-level work, with explicit user gates between stages. Single command, multi-stage chain.

**Why it matters for us**: Our Tier C path is `evaluate → discuss → roadmap → plan-phase` invoked separately. M033's `orchestrator:start` covers branch detection but doesn't auto-chain through to roadmap+plan-phase. A first-time user with an idea has to learn four command names. The grilling-protocol gates between stages (CON-5) are exactly the gating model GSD uses, so the discipline is preserved.

**What we'd ship**:
- New flag `orchestrator:start --auto-chain` (or `--deep`) — after detecting a Tier C greenfield project, runs `evaluate → discuss → roadmap → plan-phase` end-to-end with explicit user gates between stages (one keystroke to advance, configurable to require explicit confirmation)
- Marker-file convention reused from M033/P02 (`.orchestrator/start-state/<stage>.complete`) so interruption resumes from the last completed stage

**Effort estimate**: Small — a wrapper script that orchestrates existing commands with gate prompts. ~1 day of work behind a P05-shaped task.

**Where it lands**: **NOT in M033/P05** — adding scope to the closing phase risks the 2026-05-15 PBJ pilot. Slot as a **post-M033 fast-follow paper-cut** or fold into **M029 (roadmap visibility & CLI UX)** since it's a UX-on-top-of-existing-commands shape. Recommendation: M029 fold-in, since M029 is touching the start-time UX surface anyway.

### 3. Project-shape classifier in `discuss`

**What GSD shipped** (v2.79, commit `91deb109`): A `simple | complex` complexity verdict emitted during `discuss-project` and persisted to a `## Project Shape` section in PROJECT.md. Downstream `discuss-milestone / -requirements / -slice` stages read it and adapt cadence — `simple` favors 1–2 plain-text rounds + skips deep investigation; `complex` runs the full treatment. Structured questions in complex mode require 3–4 *researched* options + an "Other — let me discuss" escape hatch.

**Why it matters for us**: We have intensity per-task (M031 Quick/Standard/Full) and project tier (Tier A/B/C from `evaluate`). Neither persists a *project-shape verdict* that downstream `discuss`-stages consume to scale questioning depth. Our Tier classification is binary-ish; this is a finer-grained discuss-cadence axis that composes with Tier.

**What we'd ship**:
- `orchestrator:discuss` writes a `## Project Shape: simple | complex` section into the active context-draft (or `.orchestrator/PROJECT.md`)
- Downstream invocations of `orchestrator:discuss` read the verdict and adjust round count + question style
- Structured-question rubric: complex mode requires N researched options + escape hatch (mirroring GSD's contract)

**Effort estimate**: Small — `discuss.md` amendment + 1–2 helper scripts + acceptance test. ~0.5–1 day.

**Where it lands**: **`orchestrator:discuss` amendment**, *independent* of M033. Fits as a paper-cut after M033 closes, or as a sibling PR if there's appetite. Does NOT belong in M033/P05.

### 4. Description-as-trigger audit (uniqueness insight from GSD's `spike-wrap-up`)

**What GSD codified** (skill at `src/resources/skills/spike-wrap-up/SKILL.md`):
> **DESCRIPTION IS THE DISCOVERABILITY SIGNAL.** The `description` field is the primary signal the agent uses to judge relevance and decide whether to load the skill — write it as keywords the future agent will plausibly encounter, not a summary.

**Why it matters for us**: We have ~60 skills + commands. Our descriptions are mixed quality — some are summaries ("Use when X"), some are triggers (keyword-rich). A future-agent-plausibility audit on every `commands/*.md` and `templates/skills/*.md` description would tighten discoverability across the surface. Particularly relevant for M031's `orchestrator:do` universal-entry classifier.

**What we'd ship**:
- One-day audit pass on all `commands/*.md` frontmatter `description` fields
- Audit checklist + lint script: minimum length (120 chars), trigger keywords present, no summary-prose, examples of when to load
- Captured as a paper-cut PR titled `description-as-trigger sweep`

**Effort estimate**: 1 day. Mechanical pass + handful of rewrites.

**Where it lands**: Paper-cut sweep. Pre-launch — improves M033's first-impression UX since the start command lists discoverable commands.

### 5. `realpath` audit on state resolvers

**What GSD shipped** (v2.79 `GsdWorkspace` work + canonicalize commits): A workspace-identity handle type with `realpath` normalization at every state-resolving boundary. The 9 tests cover symlinked-worktree double-locking, canonical-base resolution after chdir, path-cache invalidation on resolve.

**Why it matters for us**: Our `scripts/state/resolve-root.sh` returns a path string. Multiple consumers cache resolved paths. We probably have at least one place where two scripts compute different paths for the same project root because one followed a symlink and one didn't — silent bug class.

**What we'd ship**:
- 30-minute audit on `scripts/state/` consumers: every cached resolved-root must go through `readlink -f` (Linux) / `realpath` (BSD/macOS) before caching
- Lock-file paths in `.orchestrator/locks/` resolved canonically before lock acquisition
- Acceptance test: symlinked-worktree fixture that fails before the fix and passes after

**Effort estimate**: 0.5–1 day. Targeted hardening pass.

**Where it lands**: Paper-cut sweep. Pre-launch — eliminates a failure mode that hits exactly when users start using worktrees in earnest.

### 6. Lease-based locks for `orchestrator:auto`

**What GSD shipped** (v2.79+v2.80 DB migration): Replaced `auto.lock + paused-session.json` with DB tables — workers, leases, dispatches, command queue. Time-bounded leases with worker identity + heartbeat replace stick locks.

**Why it matters for us**: Our `orchestrator:auto` lock is file-based. If the process crashes hard, the lock can stick until manual cleanup. **We do NOT adopt the DB migration** — Principle VI conflict. But the lease pattern is implementable file-side.

**What we'd ship**:
- `.orchestrator/locks/auto.lease` containing `{owner_pid, owner_started_at, heartbeat_ts, ttl_seconds}`
- `auto` heartbeat updates `heartbeat_ts` every N seconds
- Lock acquisition checks: lease file present → read TTL → if `now - heartbeat_ts > ttl + grace`, claim is stale → break-and-claim (with recovery briefing per `orchestrator:resume`)
- M021/M028 hardening territory; replaces the existing stale-lock detection in `orchestrator:resume`

**Effort estimate**: 1–2 days. Bash + flock-aware. Affects `orchestrator:auto` + `orchestrator:resume` + doctor.

**Where it lands**: **M028 follow-up** (autonomous hardening v3 has a precedent for this kind of work) or a new `M037-autonomous-hardening-v4`. Recommendation: M028 follow-up sized appropriately.

### 7. Soft-warning verdict tier in verifier ladder (M034 amendment)

**What GSD shipped** (v2.79, PR #5118): `/gsd eval-review` is an AI-evaluation auditing command with a YAML output contract, named scoring constants (60/40 weighting), three states, and a **pre-ship soft warning** emitted on `EVAL-REVIEW` status — non-blocking, just flagged.

**Why it matters for us**: The deferred M034 milestone (interactive review gates) is aiming at this exact shape. The "soft-warning" pattern (don't block, surface) is also a primitive our `verify` ladder doesn't have — we have PASS/FAIL/BLOCK but no `WARN-NON-BLOCKING`.

**What we'd ship**:
- M034 brief amendment: cite GSD's eval-review as prior art for soft-warning + named-constant scoring SSOT
- Add a `WARN-NON-BLOCKING` verdict tier to the M034 verifier ladder spec
- Decision-packet schema (P01) gains a `severity: warn | block` field

**Effort estimate**: Brief amendment is 30 minutes. Implementation lives in M034 itself when it's planned.

**Where it lands**: **M034 brief amendment** in [`.orchestrator/proposals/M034-interactive-review-gates.md`](../proposals/M034-interactive-review-gates.md).

### 8. Doctor enrichment

**What GSD shipped** (v2.79): Doctor checks for orphan milestone directories, exhausted run-uat retry counters, DB-backed stale locks, missing `workflow_prefs_captured` self-heal.

**What we'd ship**:
- `orchestrator:doctor` adds checks for: orphan phase dirs (no manifest), exhausted retry counters from M019 JSONL, stale `.orchestrator/locks/*.lease` files (composes with item 6), drifted `KNOWLEDGE-INDEX.md` vs filesystem
- Doctor emits structured findings; existing `--fix` mode applies safe remediations

**Effort estimate**: 1 day. Each check is small.

**Where it lands**: Paper-cut sweep. Pre-launch — doctor surfaces grow incrementally.

### 9. Anthropic prompt-cache regression test

**What GSD shipped** (v2.79, fix `pi-coding-agent,gsd: preserve Anthropic prompt cache (#5019)`): Explicit fix because something broke the cache breakpoint position.

**Why it matters for us**: Our M030/M031 efficiency stack depends on prompt-cache assumptions (Principle I + `efficiency-footer` cache-budget surface). One careless dispatch-payload restructure away from silently breaking cache without a regression signal.

**What we'd ship**:
- `tests/regression/prompt-cache-breakpoint.sh` — pins the dispatch-payload prefix structure (cache breakpoint position) for Quick / Standard / Full profiles
- Fires `QUICK_BUDGET_DRIFT` (existing M031 surface) if breakpoint position shifts
- Runs as part of pre-merge CI

**Effort estimate**: 0.5 day.

**Where it lands**: Paper-cut sweep. Pre-launch — cheap insurance on the efficiency story we already shipped.

### 10. Auto rate-limiting + reactive-parallelism heuristic

**What GSD shipped** (v2.79): `min_request_interval_ms` proactive rate limiting (#2996); default to reactive-execute on ≥3 ready tasks.

**What we'd ship**:
- `auto.min_request_interval_ms` config knob on `orchestrator:auto`
- Heuristic: ≥N parallel-ready tasks switches dispatch mode (requires the queue primitive — see item 6)

**Where it lands**: **defer-until-signal**. Post-launch fast-follow. We don't have current cost-pressure that demands rate-limiting, and reactive-parallelism is overengineering before real users exercise the autonomous loop.

### 11. Safety bundle ($HOME guard, git-index lock, commit subject sanitize)

**What GSD shipped** (v2.79):
- `refuse project writes when run from $HOME`
- `block startup on git index lock`
- `sanitize generated commit subjects`
- `honor skip git during init` flag

**What we'd ship**:
- `scripts/util/refuse-home-writes.sh` invoked at the top of every state-mutating command — refuses to run if `pwd` is `$HOME` or no `.orchestrator/` ancestor exists
- Dispatch precondition: check for `.git/index.lock`; abort with diagnostic if present
- `scripts/verify/commit-subject-sanitize.sh` — mechanical lint on generated commit subjects (no markdown syntax, no leaked tokens, length cap)
- `orchestrator:init --no-git` flag verified to work end-to-end (M033 greenfield-empty branch likely already covers this — verify before lock)

**Effort estimate**: 1 day. Each item is small and independent.

**Where it lands**: Paper-cut sweep. Pre-launch — these are exactly the safety nets that catch operator mistakes during cold-start.

### 12. M013 GitHub-sync retry-boundary audit

**What GSD shipped** (v2.79): A flurry of `github-sync` retry-boundary fixes — defer slice PRs until completion, keep failed task closures retryable, avoid closing issues before delivery, scope config cache by project, use safe git environment.

**Why it matters for us**: M013 is closed but these are exactly the live-fire incidents another team hit at scale. Worth a 30-minute review pass against our shipped retry boundaries.

**What we'd ship**:
- 30-minute audit comparing each GSD fix against our M013 implementation; any miss becomes a paper-cut hotfix
- Specifically check: failed-closure retryability, slice-PR sequencing vs delivery, config-cache scoping, git env safety

**Effort estimate**: 30-min audit + variable follow-up depending on findings.

**Where it lands**: Paper-cut sweep — audit pass first, hotfixes as they surface.

### 13. Spike → durable skill bridge

**What GSD shipped** (`spike-wrap-up` skill): Research spikes produce `SCOPE.md / research/*.md / RECOMMENDATION.md`; the skill packages reusable findings as a project-local `.claude/skills/<name>/SKILL.md` that auto-loads on future similar work. **Not every spike deserves a skill** — explicit gate via "is the conclusion reusable?" question.

**Why it matters for us**: This is Principle VII (Knowledge Compounds) with a different mechanism than ours — probabilistic discoverability vs deterministic graph traversal. The two compose; they're not competing.

**What we'd ship** (post-launch):
- `orchestrator:investigate` (or fold into `orchestrator:do`) runs a research spike with the same artifact shape
- On completion, offers to crystallize reusable findings into a project-local skill OR a knowledge-graph MEM entry
- Reuses `orchestrator:consolidate` infrastructure

**Effort estimate**: 1–2 phase milestone, post-launch.

**Where it lands**: **defer-until-signal**. Post-launch knowledge-layer fast-follow. Demand-driven — ships when real users exhaust the [M020](../milestones/M020/index.md) graph-injection path and reach for "I want this skill on every relevant future invocation" UX.

### 14. Delegation-policy table (per-tool background-safety)

**What GSD shipped** (v2.79, commit `92509758`): `delegation-policy.ts` — default-deny table marking each MCP tool GOOD / RISKY / NO for background sub-agent execution, with explicit constraint lists. Tests pin the GOOD set so any change requires explicit re-evaluation.

**Why it matters for us**: We dispatch many things via `scripts/dispatch/` but don't have a declared, test-pinned policy of *which orchestrator commands/scripts are safe in a fresh-context subagent vs. must run inline*. Implicit knowledge in script structure rather than codified contract. Pairs naturally with **Principle V (Fresh Context Per Unit)** — making the safety contract explicit rather than implicit.

**What we'd ship**:
- `references/DELEGATION-POLICY.md` — declarative table of per-command background-safety verdicts (GOOD / RISKY / NO) with constraint lists
- Enforced data file (YAML or JSONL) under `scripts/dispatch/policy/` consumed by `dispatch-interface.sh`
- Acceptance test: every dispatchable command has an explicit verdict; default-deny on unknowns

**Effort estimate**: 1 day for the table + script integration. Doctrine work.

**Where it lands**: **Standalone amendment** alongside the already-queued `constitution-amendment-inclusion-criteria.md`. Both are constitution-adjacent governance work; could ship as a single PR cycle. Recommendation: bundle into the same standalone PR window.

## Things explicitly NOT to adopt

- **DB-as-authoritative state** (v2.79+v2.80): Conflicts with Principle VI ("State On Disk Is Truth" in the *plain-text greppable* sense) and Principle I (markdown beats opaque DB for context delivery). The hardening lessons (atomic writes, advisory locks, leases) translate without abandoning files.
- **`/gsd new-project --deep` as a third intensity tier**: Adds a fourth axis on top of Quick/Standard/Full + Tier A/B/C. The naming overlap is misleading — what's substantive in their `--deep` is the *single-command auto-chain*, captured separately as item 2.
- **MCP-server-count welcome banner**: UX surface that fits IDE-extension UX, not our CLI-first launch posture. M029's `orchestrator:where` should care about *roadmap headline*, not MCP inventory.

## Open questions for user before brief amendments

- **Q1**: Is `orchestrator:exec` (item 1) a pre-launch milestone (M037) or a post-launch fast-follow? Recommendation: post-launch — see §1.
- **Q2**: For item 2 (`--auto-chain`), does it fold into M029 or live as a standalone post-M033 paper-cut? Recommendation: M029 fold-in.
- **Q3**: For items 4/5/8/9/11/12 (paper-cut sweeps), bundle as a single `papercut-gsd2-adoption-pass` PR or distribute across existing sweep PRs? Recommendation: single bundled PR named `papercut-gsd2-scan-2026-05-04`.
- **Q4**: For item 14 (delegation-policy table), bundle into the constitution-amendment-inclusion-criteria PR or ship separately? Recommendation: bundle — same governance window.

## Sequencing recommendation

Pre-launch (before M035 P02–P06 publishing event):
1. **Single bundled paper-cut sweep** covering items 4, 5, 8, 9, 11, 12 — `papercut-gsd2-scan-2026-05-04`
2. **Constitution amendment + delegation-policy bundle** (item 14) — folds into existing constitution-amendment-inclusion-criteria PR window
3. **M034 brief amendment** for item 7 — 30-min text edit, no code

Post-launch fast-follow queue (in priority order):
4. **`orchestrator:exec` / Context Mode primitive** (item 1) — new milestone, pre- or post-launch slot pending Q1
5. **Lease-based locks** (item 6) — M028 follow-up
6. **Project-shape classifier in `discuss`** (item 3) — independent amendment
7. **`--auto-chain` flag** (item 2) — folds into M029 if M029 is post-launch by then
8. **Auto rate-limiting + reactive-parallelism** (item 10) — demand-driven
9. **Spike → durable skill bridge** (item 13) — demand-driven

## Provenance

All commit SHAs verified against `gsd-build/gsd-2` HEAD as of 2026-05-04:
- Context Mode: PR #5256 / commit `4b1f3178`
- Discuss complexity classifier: commit `91deb109`
- `/gsd new-project --deep`: commit `4eb53e9910`
- Delegation policy: commit `92509758`
- `GsdWorkspace` + `MilestoneScope`: commit `d1bffc60`
- DB-authoritative: commit `1557e1d0`
- `eval-review`: PR #5118 / commit `e111ed88`
- `spike-wrap-up`: `src/resources/skills/spike-wrap-up/SKILL.md` (HEAD)
