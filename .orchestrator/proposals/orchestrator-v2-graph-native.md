# Orchestrator v2 — Graph-Native Reinvention

**Status**: proposal (living doc) — authored 2026-08-17 from operator strategy session
**Inputs**: operator interview (2026-08-17); Karpathy "Graph Engineering" synthesis paper (loop→chain→swarm→DAG→knowledge-graph progression); loop-engineering roadmap (Osmani/Anthropic); agent-graph topology guide (CC dynamic workflows); graph-memory economics (caching/batch/temporal/validation); Cerebras knowledge-base architecture (hybrid retrieval, narrow MCP primitives); M044 knowledge-activation findings; M046 unattended envelope (landed 2026-08-17).

---

## 1. The problem this proposal answers

The operator — Orchestrator's author and only active user — has drifted to using Claude Code directly on every consumer project. This is rational, not a failure of discipline: **the harness absorbed Orchestrator's workflow layer.** Native subagents, dynamic workflows/ultracode, `/loop`, `/goal`, schedules, skills, hooks, and worktree isolation now cover what `dispatch`/`auto`'s ceremony provided, with less friction. The milestone→phase→task ritual was Orchestrator's front door, and the front door lost.

What the harness did NOT absorb — and what the entire 2026 literature says is the actual bottleneck — is the layer Orchestrator was always secretly about:

> "The bottleneck is often not the next model call. It is the placement of memory and evaluation." — Karpathy synthesis
> "The agent forgets, the graph does not."

Orchestrator's differentiated assets are the knowledge layer, budgeted context construction, the verification ladder + adversarial gates, execution-log lineage, and the M046 walkaway-safety envelope (budget SIGKILL, default-DENY hooks, thrash detection). Today all of it is **gated behind the ceremony** — a plain CC session gets none of it, and M044 proved the injection path silently degrades even when the ceremony IS used.

## 2. Thesis

**Invert the architecture. Orchestrator stops being a workflow engine the user enters and becomes the memory + evaluation substrate the harness plugs into.**

Pitch: *Claude Code gives your agent hands. Orchestrator gives it memory it can trust and gates it can't cheat.*

Five planes (per the Karpathy reference architecture): the harness owns the **control** and **execution** planes; Orchestrator v2 owns the **graph plane** (typed knowledge + lineage + provenance), the **evaluation plane** (objective gates + adversarial verify + grounding checks), and the **artifact plane** it already has (markdown on disk).

### Operator priorities (2026-08-17 interview)

1. **Walkaway loops** — highest priority; current mode requires babysitting. Wants graph-based auto mode per the Karpathy loop/ratchet model, not the old linear state machine.
2. **Never lose a decision** — critical for SME trust; decisions must carry provenance, supersede chains, and contradiction detection.
3. **Context for fresh agents / token optimization** — "pretty good today," but recall must become *guaranteed and cheap*: all knowledge always considered, quick to look up, inside a token budget.
4. **Greenfield AND brownfield parity** — v2 must be equally good at starting a new project and ramping onto a large existing codebase.
5. **Constitution dependency posture is released** — bash-3.2/no-runtime-deps is no longer binding; choose the best tool.
6. **Update in place** — no separate v2 repo; current repo evolves.

## 3. Architecture

### 3.1 Graph core (the graph plane)

- **One typed graph** unifying what today are parallel families: MEMs (patterns/conventions/lessons), spec chunks, decisions, reference corpus, living docs, AND work lineage (execution log, attempts, evaluations).
- Node types (per Karpathy appendix, adapted): `Entity, Claim, Decision, Source, Artifact, AgentRun, Evaluation, Task, Commit, Metric`. Edge types: `MENTIONS, SUPPORTS, CONTRADICTS, SUPERSEDES, DERIVED_FROM, PRODUCED, EVALUATES, DEPENDS_ON, PARENT_OF, RESOLVED_TO, APPLIES_TO`.
- **Four write invariants**: every claim has a source or is marked inference; every artifact has an authoring run + version; every evaluation names a rubric; every superseded object stays addressable.
- **Temporal validity on facts** (`valid_from`/`valid_until`) — supersede, never delete (M036 supersede-chain mechanism generalizes).
- **Storage: SQLite** (+FTS5; vectors deferred — see 3.3). Zero-server, single file under `.orchestrator/graph.db`, **rebuildable from markdown**. Markdown stays the human-readable source of truth (Principle VI preserved: state on disk is truth; the DB is a derived index + query engine).
- **Validation before write**: schema validation → entity normalization → duplicate detection → contradiction check → graph write. Bad edges compound; ingestion is a data pipeline, not an LLM call.

### 3.2 Ambient capture (the return path — absorbs M040)

- **Hooks, not ceremony.** Session-end / compaction-boundary distillation: a cheap model with a *cached, stable extraction prompt* (schema first, variable episode last) extracts claims/decisions/lessons from the session; the validation pipeline gates the write.
- **Decision contradiction gate** on every decision write: PASS / FLAG / BLOCK; BLOCKs route through the human-gated apply queue (`commands/comments.md` convention). This is the SME-trust surface.
- Extraction economics per the graph-memory literature: cheap model + prompt caching for high-volume mechanical extraction; frontier reasoning only at query/synthesis time; Batch API for historical backfills.

### 3.3 Retrieval surface (context for fresh agents)

- **Narrow MCP primitives**, Cerebras-style — dumb, fast, LLM-free tools; the coding agent is the orchestration engine: `kb_search` (hybrid), `kb_why` (decision + provenance chain), `kb_lineage` (what produced this / what descends), `kb_changed_since`, `kb_contradictions`, `kb_frontier` (open tasks/leaves), `kb_subgraph` (bounded expansion for context builders).
- **Hybrid ranking, lexical-first**: FTS5 + IDF weighting + recency decay, fused with reciprocal rank fusion. Embeddings are a later additive scorer, not a prerequisite — the Cerebras evidence says lexical carries most of the load for engineering corpora.
- **Context builder v2** (successor to `build-context.sh`): resolve task entities → expand 1–2 hops over allowed edge types → prioritize recent verified claims → include conflicts + uncertainty → serialize within token budget → stable edge IDs for citation. Payloads cite edges; gates can check citations.
- **One server, every runtime**: the MCP server IS the Codex/Cursor story (supersedes M009 Tier-B's per-runtime porting). CC-specific hooks remain thin adapters.

### 3.4 Graph-native auto mode (walkaway loops — operator priority #1)

The old auto mode walked a linear milestone state machine. v2's loop is the Karpathy ratchet over a task graph:

```
LOOP until goal-gate passes | budget exhausted | frontier empty:
  1. Query frontier (kb_frontier): ready units = unblocked leaves of the task DAG
  2. For each ready unit (parallel when independent, worktree-isolated):
       build bounded subgraph context → dispatch fresh agent
  3. Gate the result: objective verifiers first (tests/build/lint/fixtures),
       adversarial refuter second, grounding check third
       (claims must cite graph edges; missing-edge ⇒ structured "revise" feedback)
  4. Write back: artifact + AgentRun + Evaluation + lineage edges; failures append
       to attempts ledger (alternative lineages stay addressable — DAG, not branch-reset)
  5. Ratchet: keep on green, revert on red, record either way, continue without asking
```

- **Safety wrapper = M046 envelope, unchanged**: reserve-then-spend budget lease, in-segment SIGKILL on budget breach, stop-file live-kill, thrash terminal, fail-closed caps, default-DENY PreToolUse scope hook, verification-integrity protections (agent cannot edit its own success criteria/harness).
- **Stop condition is an objective gate checked by a fresh model** (`/goal` semantics), never the maker's own judgment — the anti-Ralph-Wiggum rule.
- Entry requirement drops from "planned milestone" to **goal + gate + budget**. Full milestone planning remains available as opt-in intensity for large work.
- Absorbs M046 P06 (second gate → the gate stack above), P07 (attempts ledger → lineage DAG + `kb_lineage`), P08 (integration → M049 exit criteria).

### 3.5 Gates and the conversus question

**Recommendation: two-tier gating.**

- **Built-in, per-unit (high volume, cheap, objective-first)**: deterministic verifiers → one adversarial refuter subagent with a different prompt/evidence set/role → grounding check against graph edges. No external dependency; runs on every loop unit.
- **Conversus, at decision points (low volume, high judgment)**: spec gates, contradiction-BLOCK arbitration, architecture forks, anything Tier-C-discussion-shaped. Conversus-oss stays a sibling product and an *optional* adapter (graceful degrade when absent), consistent with OSS adoption friction.

Rationale: the loop needs gates measured in seconds and cents; multi-wave deliberation is the wrong per-unit cost shape but exactly right where the Karpathy paper puts evaluator judgment — disputed, high-stakes, comparative decisions.

### 3.6 Two onboarding paths (first-class, equal)

- **Greenfield**: `orchestrator:start` flow survives; spec/discuss/ideation seed the graph with Requirement/Decision/Claim nodes from day one; a loop can start from goal + gate + budget without a roadmap.
- **Brownfield (ramp onto a large existing project)**: `ingest-codebase` v2 = deterministic structural extraction (exists) + batch cheap-model extraction over docs/transcripts/living documents (M036 reference-corpus machinery, now writing graph nodes) + **entity resolution pass** (new — cluster candidates, canonical nodes retain aliases/evidence/reversibility; false merges are the catastrophic failure mode) + **incremental re-index on commit** (only changed chunks, CocoIndex-style). Target: useful queryable graph on a large repo in under an hour, compounding thereafter.

### 3.7 What gets deprecated / demoted

- Ceremony commands become **thin views over graph queries** (`status`/`where`/`context` read the graph; wiki remains a projection view for SMEs).
- `dispatch`-only knowledge injection dies as the sole path; MCP tools + context builder v2 replace it (fixes the M044 fragility class structurally: retrieval is pull-based and observable, not buried in payload assembly).
- Bash-3.2-only constitution constraint is amended (operator authorization 2026-08-17); constitution principles I, II, V, VI, VII carry forward unchanged in spirit.

## 4. Sequencing (updates in place; each slice independently useful)

- **M047 — Graph core + migration.** SQLite schema, write invariants, validation pipeline, importers for every existing knowledge family + execution logs, hybrid retrieval (FTS5+IDF+recency+RRF), CLI query primitives, rebuild-from-markdown invariant + parity harness against the current index. *Exit: this repo's own knowledge fully queryable; regression suite green.*
- **M048 — Retrieval surface + ambient capture.** MCP server (narrow tools), context builder v2, session-end distillation hooks with cached extraction + validate-before-write, decision contradiction gate with human-gated BLOCK queue. *Exit: a plain CC session on a consumer project uses the tools; decisions captured ambiently with provenance; token-cost telemetry per query.*
- **M049 — Graph-native auto mode.** Frontier loop on the M046 envelope, lineage/attempts DAG, two-tier gate stack, parallel worktree units, goal-gated stop. *Exit: overnight walkaway run on a real consumer project under a hard budget cap; traceability invariant holds — every important output traces to an objective, a plan, an artifact, a source, a graph path, an evaluator decision, and a bounded execution record.*
- **M050 — Onboarding parity + runtime spread.** Brownfield batch ingest at scale, entity resolution, incremental re-index; greenfield seeding polish; Codex (and Cursor Tier-A follow-through) via the same MCP server. *Exit: cold-start on a large existing repo → useful graph <1hr; a Codex session queries the same tools.*

**Roadmap absorptions**: M046 P06–P08 → M049. M040 → M048. M009 Tier-B → M050. M036b P08 wiki projection → post-v2 view work. M034 decision packets → contradiction-gate BLOCK shape. M038 living docs → graph node family + bindings.

## 5. Open questions (carry to specify/discuss)

1. MCP server language/runtime (TypeScript SDK vs Python) — pick at M048 spec time; conversus-gate candidate.
2. Embedding adoption trigger — what measured retrieval miss-rate justifies adding a vector scorer + its dependency weight?
3. Graph DB in git or ignored-and-rebuilt? (Lean: ignored; markdown is truth; importers must be fast and deterministic.)
4. Session-transcript distillation consent/scope on consumer projects (what is captured, what is excluded by default).
5. How much of the M041 detective / doctor surface re-targets onto graph queries in v2 vs waits.

## 6. Evaluation discipline (so v2 doesn't ship on vibes)

Per-layer metrics from day one: extraction precision/recall on a gold set; resolution false-merge/missed-merge rates; retrieval hit-rate on a fixed question battery per consumer project; context-builder token cost per unit; loop cost-per-accepted-change (the metric that decides whether walkaway mode is winning); gate false-pass audits (spot-check that the objective gate actually catches the failure class it claims to).
