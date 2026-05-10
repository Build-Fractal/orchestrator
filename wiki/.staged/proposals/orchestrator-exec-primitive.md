# Proposal: `orchestrator:exec` — Subprocess-Output Context Discipline (Context Mode equivalent)

**Captured**: 2026-05-04 from the GSD-2 adoption scan (`gsd-2-adoption-scan-2026-05-04.md` §1 — the headline new primitive).
**Shape**: Milestone-shaped (4–5 phases). Foundation primitive that touches dispatch, observability ([M019](../milestones/M019/index.md)), efficiency surfaces ([M027](../milestones/M027/index.md)), and the manifest format (M030/[M031](../milestones/M031/index.md)).
**Slot**: **Post-launch milestone candidate** (provisional ID — pick from the post-launch fast-follow band: [M037](../milestones/M037/index.md) / M038 / etc. depending on what's already taken when this enters the queue). NOT pre-launch — see Sequencing.
**Source**: GSD v2.80 PR #5256 (`feat(context-mode): fully wire auto-run context mode`). Companion items elsewhere in this scan: see "Why this needs its own milestone" below for what makes this distinct from the other 13 GSD-2 adoption items.
**Predecessors**: [M018](../milestones/M018/index.md) (compression-tier — input-side discipline; this is the output-side sibling), M019 (Tier 1 JSONL emitter — exec runs are first-class observability events), M027 (cost+quality observability — efficiency footer surfaces exec-output savings), [M030](../milestones/M030/index.md) (adaptive model selection — exec lanes integrate with manifest-driven routing), M031 (right-sized entry — Quick/Standard/Full profiles already declare per-task lanes).

## Goal

Add a new primitive `orchestrator:exec` that runs a subprocess command and **persists full stdout/stderr to disk**, returning to the model only metadata (exit code, byte counts, summary line, search-key). Plus two siblings — `orchestrator:exec-search` (rediscover prior runs) and `orchestrator:exec-resume` (post-compaction recovery).

This is a **new axis of context discipline** that Principle I (Context Minimization) does not currently cover. Our existing efficiency stack (M027 efficiency-footer + M031 build-context profiles + M018 compression-tier) acts on *input assembly* — what enters the agent's context. Context Mode acts on *subprocess output* — test logs, build output, lint reports, search results that bloat conversations during long autonomous runs. We have **no analog primitive today**.

## Why this needs its own milestone (not folded into anything else)

**Not a paper-cut**: touches dispatch + manifest + observability + efficiency surfaces. A proper goal-backward pass on the manifest-lane integration is needed.

**Not a brief amendment**: the subprocess-output discipline is a *new contract*, not a refinement of an existing one. M027 surfaces *report* it; M030 routes *informed by* it; M031 declares *lanes consuming* it. None of those existing milestones carry the contract itself.

**Not a feature flag on an existing command**: every dispatchable command and every plan-frontmatter manifest entry needs the option to declare an exec lane (`exec_mode: capture | stream`). That's a manifest-format extension, not a flag.

The closest existing surface is `scripts/dispatch/dispatch-interface.sh`. The exec primitive lives next to dispatch but operates at a finer grain — every subprocess call inside a dispatched unit is a candidate for capture-mode.

## Strict scope

This is **the exec primitive + its two siblings + manifest-lane integration**. It is **not**:

- A replacement for `dispatch-interface.sh` — exec runs **inside** a dispatched unit
- A new observability framework — extends M019 JSONL emitter with `exec_run` event type
- A compression layer — output is captured raw on disk; M018-style compression is orthogonal and applies if at all when a *future* unit reads the captured output
- A cache (separate from M030's prompt-cache machinery) — exec runs are persistent records, not memoization
- A sandboxing layer — exec runs commands in the same security context as the orchestrator runs in
- An MCP server — pure shell + filesystem primitive

The goal: when a unit runs `bash tests/run-suite.sh` (5MB of output), the model sees only `{exit: 0, lines: 12847, summary: "All 437 tests passed", search_key: "exec/2026-05-15T10:23:11Z-tests-run-suite"}`. The 5MB stays on disk. Future agent invocations searching prior runs find it via `orchestrator:exec-search`.

## Surfaces this ships

### `scripts/dispatch/exec.sh`

```
orchestrator:exec [--lane <capture|stream>] [--summary-lines <N>] -- <command> [args...]
```

- Runs `<command>` capturing stdout + stderr to `.orchestrator/exec/<unit>/<timestamp>/{stdout,stderr,meta.json}`
- `meta.json` records: command, args, cwd, env-snapshot (allowlisted vars only), exit code, duration, stdout/stderr byte counts, head/tail samples, summary line (last non-empty stderr line OR first matching pattern)
- Default lane is `capture` (full output to disk, metadata-only to model)
- `stream` lane: short commands where capture-overhead exceeds output cost; passes output through to caller. Determined by allowlist, not by command output size (which we don't know in advance).
- Returns to caller: meta.json contents (small, deterministic)

### `scripts/dispatch/exec-search.sh`

```
orchestrator:exec-search [--unit <id>] [--command-pattern <regex>] [--exit <status>] [--since <time>]
```

- Filters prior runs in `.orchestrator/exec/`
- Returns matching `meta.json` entries (caller reads stdout/stderr on demand)

### `scripts/dispatch/exec-resume.sh`

```
orchestrator:exec-resume [--last-snapshot] [--unit <id>]
```

- Reads `.orchestrator/exec/<unit>/_last-snapshot.md` (compaction-resilient pointer to the last completed exec run)
- Returns the snapshot content for post-compaction recovery
- Snapshot writer integrated into M021/[M028](../milestones/M028/index.md) autonomous-pause path so the snapshot is written *before* compaction-cancellation cascades (this is the GSD lesson exactly)

### Manifest-format extension

Plan-frontmatter and task-frontmatter gain an optional `exec_lane: capture | stream` field:

```yaml
---
schema_version: "1.0"
type: task-plan
exec_lane: capture  # default — long-running verifiers, test suites, builds
---
```

Per-task lanes can override the milestone default. The `dispatch-interface.sh` reads the lane and threads `--lane` through to `exec.sh` invocations.

### M019 observability integration

New event type `exec_run` in the JSONL emitter:

```json
{"event": "exec_run", "unit": "...", "command": "bash tests/run-suite.sh", "exit": 0, "lines": 12847, "duration_ms": 8492, "captured_bytes": 5242880, "search_key": "..."}
```

`orchestrator:cost` rollups can surface "bytes captured to exec/ vs. bytes that would have entered conversation context" as a new efficiency metric.

### M027 efficiency-footer integration

Footer gains a new line: `EXEC: <N> runs captured (<bytes-captured> off-context)`. Single sentence, optional.

## Phase shape (preliminary — refined by `orchestrator:specify`)

- **P00 baseline**: empirical measurement of subprocess-output cost in current autonomous runs (3-5 representative milestone autoloops; what's the bytes-into-context distribution?). Determines whether opt-in or opt-out is the right default.
- **P01 exec primitive**: `exec.sh` + `meta.json` schema + `.orchestrator/exec/` directory convention + acceptance tests against 3 fixture commands (long stdout, long stderr, exit-non-zero).
- **P02 exec-search + exec-resume**: search filters + snapshot file + acceptance tests.
- **P03 manifest integration**: lane field in plan/task frontmatter + dispatch-interface.sh threading + acceptance tests for both `capture` and `stream` lanes.
- **P04 observability + efficiency-footer integration**: M019 event type + M027 footer line + cost rollup integration. Cross-milestone-regression tests against M027.
- **P05 milestone close**: phase-suite + cross-phase regression + scope-guard + VALIDATED marker + SUMMARY.md.

## Sequencing (post-launch slot)

This is **post-launch** because:
- Pre-launch queue ([M032](../milestones/M032/index.md) + [M033](../milestones/M033/index.md) → [M029](../milestones/M029/index.md) → [M035](../milestones/M035/index.md)) is already load-bearing for first-impression UX and packaging. Inserting a 5-phase milestone before launch slips the launch.
- Cost-of-delay is not acute: M027 efficiency-footer will catch obvious context-bloat in autonomous runs; users will surface concrete pain points that inform the manifest-lane allowlist post-launch.
- Mis-shaping the manifest contract pre-launch has real blast radius (every plan/task frontmatter consumer reads it). Post-launch slotting means real autonomous-run signal informs the contract.

**When demand surfaces** (a real autonomous run's context budget is dominated by subprocess output that can't be turned off): this is the next hardening milestone after lease-based-lock work and any other M028-v4 follow-ups land. Pair with M027 v2 if observability extensions are also needed.

## Dependencies

- **Hard**: M018 (compression-tier — for any future capture-then-compress flow), M019 (Tier 1 emitter), M027 (efficiency-footer surface), M031 (manifest-lane format precedent)
- **Soft**: M030 (adaptive model selection — model routing benefits from knowing exec_lane)
- **No conflict**: Principle VI (State On Disk Is Truth) — exec captures *strengthen* this principle by making subprocess output first-class on-disk state

## Open questions for `orchestrator:specify`

1. **Default lane**: `capture` or `stream`? Recommendation `capture` (default-conservative) once P00 baseline measures bloat magnitude.
2. **`.orchestrator/exec/` retention policy**: keep forever, GC after milestone-close, or operator-explicit cleanup? Recommend forever-during-milestone, archived at `consolidate` time alongside other milestone artifacts.
3. **Cross-runtime parity**: CC works straightforwardly; Codex CLI / Cursor parity is M009 territory. Does this milestone include the parity check or defer it?
4. **Stream-lane allowlist**: who maintains it? Recommend a small declarative table at `references/EXEC-LANES.md`, similar to (or merged with) the delegation-policy table.
5. **Snapshot frequency**: write snapshot per exec run, per unit, or per dispatch? Recommend per-unit (one snapshot per dispatched unit, updated as exec runs complete).

## Cross-references

- Parent scan: `gsd-2-adoption-scan-2026-05-04.md` §1
- Sibling adoption items (different lanes): `delegation-policy-table.md` (per-tool background safety), `papercut-gsd2-scan-2026-05-04.md` (item E1 `$HOME` write guard composes with exec capture sandbox)
- M018 compression-tier: input-side counterpart to this output-side primitive
- M019 JSONL emitter: where new `exec_run` event type lands
- M027 efficiency-footer: surfaces exec savings
- M031 right-sized entry: manifest-lane format precedent
- GSD source: PR #5256 / commit `4b1f3178` in `gsd-build/gsd-2`

## Provenance

- Discovered: 2026-05-04 GSD-2 adoption scan
- Originally captured: parent scan §1
- Promoted to standalone proposal: 2026-05-04 (this file) — see scan §"Where each item lands" Q1 recommendation that the headline primitive deserves its own front door so the roadmap process picks it up cleanly when post-launch slotting is decided.
