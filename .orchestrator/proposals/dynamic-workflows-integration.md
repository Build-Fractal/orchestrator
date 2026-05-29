# Proposal: Dynamic-Workflows Integration — capability-gated inner-loop fan-out

**Captured**: 2026-05-29
**Shape**: Mixed — one standalone capability-gating PR (the conditionality contract, fires now) + one demand-driven post-launch pilot (extraction fan-out) + three deferred opportunities behind the same gate. Not a single coherent milestone; the gating contract is the load-bearing piece and ships independent of any workflow use.
**Predecessors**: dispatch layer (`scripts/dispatch/dispatch-interface.sh`, `detect-runtime.sh`, `detect-capabilities.sh`), `references/RUNTIME-ASSUMPTIONS.md` (M018/P07 seed), conversus adapter (M011/P07), M030 (model routing — workflow stages must respect it), `concurrent-agent-commit-isolation.md` (Layer-3 git isolation the worktree primitive would satisfy), M009 (multi-runtime parity audit — consumes the capability registry this proposal seeds)
**Source**: 2026-05-29 audit session. User asked whether Claude Code's dynamic-workflows research-preview feature should be leveraged in orchestrator, aligned to the constitution; follow-up asked how to include Claude-only features conditionally given the eventual Codex/Cursor multi-runtime goal. The audit ran as a 14-agent dynamic workflow (dogfood): 6 subsystem readers → 7 independent per-principle verdicts → synthesis. This brief is the durable artifact of that run.

## Status

**§4 SHIPPED 2026-05-29** (`feat(dispatch): capability-gating contract` — `parallel_subagent_fanout` probe + Capability Registry in `RUNTIME-ASSUMPTIONS.md` + `tests/test-capability-gating.sh` forced-fallback lane, 9/9 green). The conditionality contract is live and standalone; no call sites yet (those arrive with §5).

**§5 + §6 remain RFC capture only** — demand-driven post-launch by design. §5 (extraction pilot) waits on M036 having a live multi-file corpus to run against; §6 waits on §5 reporting its token + crash-survival evidence. When the §5 arc enters the queue this becomes the input to `orchestrator:specify`.

## TL;DR

Dynamic workflows are a **strong fit for three constitution principles (V fresh-context, II evidence, I context-minimization payload mechanic) and a hard conflict with the load-bearing one (VI state-on-disk-is-truth)** — because workflow intermediate state lives in JavaScript script variables and is lost on a Claude Code session exit (fresh restart next session, no cross-session durable resume). The orchestrator's whole value proposition is the durable, cross-session, disk-derived outer loop (`auto-loop.sh` + `derive-phase.sh` + continue files + `execution-log.jsonl`), and a workflow runtime cannot and must not own that.

The recommendation is **adopt-narrowly via a strict inner/outer split**: the disk-durable `orchestrator:auto` loop stays the milestone authority; a workflow is invoked **only** as a bounded, within-session-completable fan-out unit inside one phase, and it checkpoints every stage to disk before returning. Because workflows are **Claude-Code-only**, the integration must be **capability-gated, not runtime-gated** — and that gating contract is the durable, ship-now deliverable here, independent of whether any workflow is ever wired.

## Alignment scorecard (vs the 7 principles)

| Principle | Verdict | Driver |
|---|---|---|
| V — Fresh Context Per Unit | **strong-fit** | Subagents never inherit conversational context; `isolation:'worktree'` ships the Layer-3 git isolation only *proposed* in `concurrent-agent-commit-isolation.md`, never built into `dispatch-interface.sh`. |
| II — Evidence Before Claims | **fit** | Per-agent `schema` ≈ `emit_result`; native adversarial-review/vote patterns add evidence passes. *Caveat: schema enforces structure, not truth — the script has no shell access, so it must trust an agent's self-reported `{passed:true}`. Deterministic gates stay outside.* |
| I — Context Minimization | tension | Intermediate results stay in script vars (good) — but each hand-authored agent prompt bypasses `build-context.sh`/`compress-payload.sh`/`scope-filter.sh` unless routed there; a crash re-incurs the run's exploration tokens. |
| III — Design Before Code | tension | Claude authors-and-runs the script in one turn; `/effort ultracode` does it automatically with no design gate. |
| IV — Plans Assume Zero Context | tension | A saved `.claude/workflows/` command is *run-not-read* — opaque to cold hand-execution if treated as plan-of-record. |
| VII — Knowledge Compounds | tension | `phase()` boundaries are ephemeral control-flow; knowledge persists only if an indexing agent is wired per phase. |
| VI — State On Disk Is Truth | **conflict** | VI states verbatim "no in-memory state across sessions." Workflows lose all in-flight results on CC exit and restart fresh — the exact failure VI exists to prevent. No analog to continue-files / stuck-detector replay. |

Every tension closes with the **same two guardrails**: route agent prompts through the existing compression pipeline, and checkpoint every stage to disk before the run ends. Only VI is structural — it **disqualifies any use that cannot finish inside a single session.**

## Hard boundaries (what workflows must NOT do)

1. **Never a dispatch backend adapter** (`scripts/dispatch/adapters/backend/`). The dispatch layer is deliberately backend-agnostic (`local-agent.sh` / `local-codex.sh` / `stub.sh`) with the M009 multi-runtime aspiration. Workflows are CC-only and the script has no filesystem access to run `build-context.sh`. Wiring them as a backend would couple the core dispatch contract to a vendor-exclusive feature. Workflows sit **above** dispatch as an optional accelerator, never inside it.
2. **Never the outer milestone/phase loop** (`orchestrator:auto` / `auto-loop.sh` / `start.md --auto-chain`). Tier C multi-phase work spans sessions and day boundaries; it stays on disk-derived state, full stop.
3. **Never replaces conversus.** Conversus's durable version-controlled presets, provider/OAuth abstraction, and constitution-grounded PASS|BLOCK verdict contract are not reproduced by ad-hoc vote primitives. At most a workflow *invokes* a conversus gate at a checkpoint.
4. **Never owns the deterministic verify gate** (`check-must-haves.sh` / verify ladder). Verification runs deterministically outside the non-deterministic agent layer, consuming captured evidence.
5. **Never mid-flow human sign-off.** The hard "no mid-run user input" constraint means review gates (M034) cannot live inside one workflow run; they stay as separate orchestrator stages.
6. **`/effort ultracode` disabled for substantive orchestrator development** — it fuses design and execution with no Principle III gate.

---

## §4 — The conditionality contract (ship-now, standalone, the load-bearing piece)

**This section is the durable deliverable.** It generalizes beyond workflows to *every* Claude-only feature the orchestrator may adopt while the Codex/Cursor multi-runtime goal is still open.

### Principle: gate on *capability*, never on *runtime identity*

The trap is `if runtime == "claude-code"` at call sites — it hard-codes a vendor into control flow, so the day Codex ships an equivalent, every call site needs editing. Instead, name the **capability** the feature provides and gate on that. Workflows is merely *the CC implementation behind a capability*.

```sh
# WRONG — couples logic to a vendor
if [ "$runtime" = "claude-code" ]; then run_workflow; fi

# RIGHT — couples logic to a capability the runtime may or may not provide
if [ "$parallel_subagent_fanout" = "true" ]; then run_workflow_fanout; else run_serial; fi
```

Name the capability by **what it does for the orchestrator**, not by Claude's brand: `parallel_subagent_fanout` (durable-checkpointed parallel agent orchestration). The fallback name must encode the *durable-checkpoint* part of the contract, so a future runtime can't claim the capability with a non-durable implementation.

### This is already the orchestrator's pattern — extend, don't invent

- `detect-runtime.sh` already distinguishes `claude-code | codex | cursor | unknown` with confidence levels and a `--force` override.
- `detect-capabilities.sh` already emits per-capability flags (`subagent_dispatch`, `agent_tool_available`, `git_worktree`, …) for graceful degradation (R008).
- `agent_tool_available` already documents the exact detection problem workflows have: *"cannot be reliably detected from a shell script… The orchestrating agent should self-check its own toolkit instead. Set `SPECKIT_AGENT_TOOL=1` to override."*

Workflows slot into this. **Mirror the `agent_tool_available` pattern precisely** — do not invent a new detection philosophy.

### Three layers

**1. Probe** — add one flag to `detect-capabilities.sh`:

```
parallel_subagent_fanout = (runtime == claude-code)
                        AND (claude version ≥ 2.1.154)
                        AND (workflows not disabled: CLAUDE_CODE_DISABLE_WORKFLOWS / disableWorkflows)
                        AND (paid plan / API access)
```

The last three are **not reliably shell-detectable** (a CC user can toggle workflows off in `/config`, or be on a plan without them). So: the probe returns a conservative default (CC + version → "likely available"), the **orchestrating agent self-confirms** it actually has workflows before invoking, and an env override `ORCHESTRATOR_PARALLEL_FANOUT=0/1` is the escape hatch — identical to `SPECKIT_AGENT_TOOL=1`.

**2. Capability registry** — promote the implicit list in `detect-capabilities.sh`'s header to a declarative table in `references/RUNTIME-ASSUMPTIONS.md`, one row per capability:

| capability | claude-code | codex | cursor | fallback |
|---|---|---|---|---|
| `parallel_subagent_fanout` | dynamic workflows (≥2.1.154) | — | — | serial dispatch loop + disk checkpoint |
| `git_worktree_isolation` | `isolation:'worktree'` | git CLI | git CLI | shared index + lock |

**This table IS the M009 parity audit** — it turns "audit multi-runtime parity" from open-ended into "walk the registry, check each cell." That is the durable payoff of doing the gating right.

**3. Call sites** — every capability-gated branch has a **baseline arm that is the default**; the accelerator is opt-in. Already the dispatch philosophy (`stub.sh`, escalation fallback).

### The thing that will actually bite: fallback rot (Principle VIII)

If 100% of real users are on CC, the accelerator path is the *only* one ever exercised, and the serial fallback silently bit-rots until the first Codex user hits a broken code path — a "No Dead Infrastructure" violation waiting to happen.

**Mitigation: a forced-fallback CI lane.** The seam already exists (`detect-runtime.sh --force`). Add the capability analog — force `parallel_subagent_fanout=false` — and run **both arms in CI**. The baseline path stays green continuously even while every actual user is on Claude Code. Per `feedback_fixtures_byte_equality_default`, assert the forced-fallback run produces *equivalent results* (byte-equality where applicable), just slower.

### Constitution mapping

- **XVI / runtime-agnosticism** — capability-gating is the mechanism that keeps `local-codex.sh` honest; a vendor-named `if` breaks the backend-agnostic contract.
- **VIII (No Dead Infra)** — the forced-fallback CI lane stops the deferred multi-runtime promise from rotting.
- **VI** — the fallback for a durable-checkpointed fan-out is serial-*with-disk-state*, not bare serial.

### §4 deliverable (standalone PR, ~1–2 days) — ✅ SHIPPED 2026-05-29

1. ✅ Added `parallel_subagent_fanout` to `detect-capabilities.sh` with the `agent_tool_available`-style self-check + `ORCHESTRATOR_PARALLEL_FANOUT` override (hard-disable `CLAUDE_CODE_DISABLE_WORKFLOWS=1` wins; conservative default false).
2. ✅ Promoted the capability list to a declarative registry in `RUNTIME-ASSUMPTIONS.md` `## Capability Registry` (seeds M009; rows: `parallel_subagent_fanout`, `git_worktree_isolation`).
3. ✅ Added the gating rule (default path is the fallback; no vendor names in control flow; conservative defaults) as a subsection of the registry. Natural sibling to `delegation-policy-table.md` + `constitution-amendment-inclusion-criteria.md`.
4. ✅ Added the forced-fallback lane as `tests/test-capability-gating.sh` (9 assertions) — forces the capability off and asserts the baseline path stays correct (Principle-VIII anti-rot).

**Deferred (noted, not built):** a generic no-vendor-gating lint — too brittle (the `m008-p05` adapter layer legitimately switches on runtime). The rule is documented and the test proves the mechanism; a scoped lint can follow if call-site drift ever appears.

---

## §5 — Pilot: parallel reference-corpus extraction fan-out (demand-driven, post-launch)

The canonical inner-fan-out shape and the recommended first (and only initial) workflow use.

**Where**: `commands/extract.md` + `commands/ingest-reference.md` (M036 reference-corpus pipeline).

**Why it fits**: extraction is embarrassingly parallel — N source files (PDF/DOCX/XLSX/MD), each an independent Tier-1 deterministic pass + Tier-2 LLM structured-Markdown pass, no cross-file dependency, bounded item count, completes well within one session. `parallel()` at 16 concurrent agents collapses today's serial per-file loop. The existing per-file conversus fidelity gate maps onto a per-agent schema-forced verdict. Exercises II well — each agent emits captured evidence (source hash + tier verdict), not a self-asserted boolean.

**Guardrails** (all required):
- **VI/VII**: each agent writes its `REF-*.md` output + manifest entry to `.orchestrator/knowledge/reference/<category>/` immediately on completion — *not* held in script variables. A CC exit mid-run leaves completed files persisted; re-run only reprocesses unfinished items via `content_hash` idempotency.
- **I/V**: each agent's prompt assembled minimally per-file (not the whole corpus interpolated into every agent).
- **II**: per-agent schema carries source-hash + tier verdict as captured evidence; the conversus fidelity gate / deterministic check runs after the workflow, consuming evidence.
- **CC-only**: the existing serial `extract` path stays the **default**; the workflow fan-out is opt-in behind the `parallel_subagent_fanout` probe (§4). Never a hard dependency of M036.

**Acceptance instrumentation** (gates broader adoption):
1. Capture **total tokens vs the current serial loop** — Principle I's explicit clause requires showing total task tokens *decrease*, with data, before any bypass of the compression pipeline is justified.
2. **Force-kill the CC session mid-run** and confirm the disk-checkpoint pattern survives (completed files persisted, re-run resumes from `content_hash`).

Hold the other three opportunities (§6) until this pilot reports.

---

## §6 — Deferred opportunities (behind the same §4 gate, after the §5 pilot reports)

| Opportunity | Where | Effort | Key guardrail |
|---|---|---|---|
| **Detective audit / triage sweep** | `commands/detective.md` (M041) + `commands/diagnose.md` | medium | Fan-out hypotheses → adversarial cross-check → ranked list, behind the existing FR-9 confirmation gate. Per-hypothesis findings to `.orchestrator/runs/<id>/` before synthesis. Degrade to single-agent triage when capability absent. |
| **Design-layer parallel personalities** | new `commands/design.md` (M023, deferred) | large | M023 *is literally* `parallel()` + `isolation:'worktree'`. Could ship M023's parallel core as a workflow inner-loop while orchestrator owns the present-and-pick outer step (user-pick happens *after* the run returns — the "no mid-run input" constraint is fine here). Workflow must be the OUTPUT of a design step, not ultracode-generated. CC-only acceptable since M009 is also post-launch — document the CC dependency in the M023 brief. |
| **Knowledge re-consolidation fan-out** | `commands/consolidate.md` + `scripts/knowledge/consolidate-artifacts.sh` | small | Parallel slice-readers → structured summary chunks → synthesis. Each agent WRITES its output to the on-disk knowledge hierarchy per-slice before synthesis — otherwise parallel reading just multiplies peak tokens with zero reuse and a crash discards everything. Serial path stays default. |

---

## Risks & open questions

- **Cost blast radius** — a single run can use meaningfully more tokens than conversational work; every agent uses the session model unless the script routes per-stage. Combined with M030 adaptive routing, an un-routed workflow could run 16 smart-tier agents where the orchestrator would have routed most to fast/balanced. Workflow stages must respect M030's tier guidance.
- **Research-preview volatility** — workflows are a research preview (CC v2.1.154+). API/primitives may change. The §4 gate insulates the orchestrator: if the feature shifts or is pulled, only the probe and the one pilot call site are affected; the fallback is always present.
- **`.orchestrator/` carve-out** — saved workflow scripts live in `.claude/workflows/` or `~/.claude/workflows/`, outside `.orchestrator/`. Per Principle XVI (all first-party content in `.orchestrator/`), decide at queue-entry whether orchestrator-authored workflow scripts need an `.orchestrator/workflows/` home with a symlink/copy to the CC-discoverable location. (Cross-references `scripts_wiki_carve_out_queued` precedent.)
- **Open**: does the pilot's token instrumentation show a net decrease, or does the per-file prompt assembly bypass eat the fan-out savings? This is the empirical gate on everything downstream.

## Sequencing

§4 (gating contract) is standalone and fires now — bundle it into the `constitution-amendment` / `delegation-policy-table` standalone PR window. §5 (pilot) is demand-driven post-launch, naturally slotting when M036 reference-corpus work has a multi-file corpus to exercise. §6 follows only after §5 reports its token + crash-survival evidence.
