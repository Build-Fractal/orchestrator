# speckit-orchestrator — Master Review

## Executive Summary

Three autonomous tool agents (APM, spec-kit, gh-aw) conducted a structured adversarial review of the [speckit-orchestrator specification](speckit-orchestrator-overview.md) across three iterations. The process began with 29 uncoordinated recommendations, surfaced 18 dangerous contradictions, and converged on 13 unanimous consensus points with zero unresolved disputes — no human arbitration was required.

### The Meta-Analysis

The review process itself was the most revealing finding. Each tool's original review exhibited **single-tool tunnel vision**: APM saw every artifact as an APM primitive, spec-kit saw every convention as a spec-kit compliance requirement, and gh-aw saw every state management problem as a cache-memory problem. The adversarial cross-review structure forced each tool to confront what happens when its "correct" advice conflicts with another tool's equally "correct" advice.

The pattern of convergence was consistent: the most prescriptive, most "textbook-correct" single-tool recommendations were the most dangerous in a multi-tool context. Every tool's withdrawn recommendations were things that would have been good advice in a single-tool world.

| Iteration | Action | Outcome |
|-----------|--------|---------|
| [Iteration 1](summary/summary_iteration_1.md) | 3 original reviews + 6 cross-reviews + 3 syntheses | 18 dangerous contradictions identified; 6 withdrawals, 12 modifications |
| [Iteration 2](summary/summary_iteration_2.md) | 6 meta-reviews + 3 syntheses | 12/17 contradictions fully resolved; 10 consensus points locked; 3 narrow disputes remain |
| [Iteration 3](summary/summary_iteration_3_final.md) | 3 dispute resolution cases + 3 final syntheses | All 3 disputes resolved by convergence; 13 final consensus points |

### Why It Worked

The process worked because of three structural properties:

1. **Forced engagement with counter-positions.** Each cross-review required the reviewer to address specific recommendations, not just restate their own stance. This prevented tools from talking past each other.

2. **Locked consensus prevented backsliding.** Once a point was locked in iteration 2, it could not be reopened. This forced iteration 3 to focus exclusively on the remaining disputes rather than relitigating settled ground.

3. **Withdrawal was treated as strength, not weakness.** APM withdrew 3 recommendations, spec-kit withdrew 3, and gh-aw withdrew 0 (but modified 5 substantially). The tools that withdrew fastest converged fastest. gh-aw's refusal to withdraw any recommendation forced it into more extensive modification, which ultimately produced the same convergence.

---

## The 13 Consensus Points — Origin, Challenge, and Hardening

### Consensus 1: Working tree is canonical for all agent-consumable artifacts

**Origin:** This principle emerged from the collision between three competing storage models. gh-aw's [original review](gh-aw/UTILIZATION.md) proposed `cache-memory` and `repo-memory` as canonical CI state (lines 23-25). APM's [original review](apm/UTILIZATION.md) proposed `.apm/context/` as a mirrored canonical location (Rec 9, line 65). spec-kit's [original review](spec-kit/UTILIZATION.md) proposed `.specify/extensions/orchestrator/` as the sole canonical path (Rec 3, lines 45-46).

**Challenge:** All three cross-reviews flagged the other two tools' storage proposals as dangerous. spec-kit [flagged gh-aw's cache-memory](spec-kit/reviews/gh-aw.md) as breaking disk-state-as-truth. APM [flagged gh-aw's off-tree storage](apm/reviews/gh-aw.md) as invisible to `apm compile`. gh-aw [flagged APM's mirroring](gh-aw/reviews/apm.md) as creating split-brain state.

**Hardening:** In [iteration 1](gh-aw/UTILIZATION.reviewed.md), gh-aw made the pivotal concession — repositioning `cache-memory` from canonical storage to a "durability/transport layer." APM [withdrew Rec 9](apm/UTILIZATION.reviewed.md) (mirroring into `.apm/context/`). By [iteration 2](summary/summary_iteration_2.md), all three tools had locked this as consensus point 1. The principle was further tested in iteration 3 when gh-aw's [dispute resolution](gh-aw/reviews/iteration_3/disputes.md) confirmed that `cache-memory` serves only to persist and restore the working tree between ephemeral CI runs.

---

### Consensus 2: spec-kit config system is the single authority for orchestrator settings

**Origin:** spec-kit's [original review](spec-kit/UTILIZATION.md) (Rec 2, line 29) proposed locking orchestrator config into spec-kit's YAML extension config format with `SPECKIT_ORCHESTRATOR_*` env var injection.

**Challenge:** APM [flagged this as dangerous](apm/reviews/spec-kit.md) — locking config into spec-kit's resolution stack prevents APM from managing or overriding settings through org packages. gh-aw [flagged it as a tension](gh-aw/reviews/spec-kit.md) — CI needs to read config values at compile time for frontmatter translation.

**Hardening:** spec-kit [withdrew Rec 2](spec-kit/UTILIZATION.reviewed.md) in iteration 1, conceding that format-neutral config serves the multi-tool context better. The consensus shifted from "spec-kit's YAML format" to "spec-kit config system as authority, format-neutral." By [iteration 2](spec-kit/UTILIZATION.iteration_2.md), this was locked as the single authority principle — budgets, verification commands, and dispatch caps are defined here and consumed by other tools through their own mechanisms.

---

### Consensus 3: Verification logic owned by the spec, not any single tool

**Origin:** gh-aw's [original review](gh-aw/UTILIZATION.md) (Rec 5, line 35) proposed mapping verification to gh-aw's `post-steps:` blocks. spec-kit's [original review](spec-kit/UTILIZATION.md) (Rec 7, line 36) proposed invoking `/speckit.analyze` during phase review.

**Challenge:** In [iteration 1 cross-reviews](spec-kit/reviews/gh-aw.md), spec-kit flagged gh-aw's `post-steps:` as potentially replacing, not complementing, spec-kit's hook-based verification. The tension was: who owns the verification commands?

**Hardening:** gh-aw [modified Rec 5](gh-aw/UTILIZATION.reviewed.md) in iteration 1 to make `post-steps:` an invocation adapter, not the owner of verification logic. By [iteration 2](gh-aw/UTILIZATION.iteration_2.md), the model crystallized: the spec defines what to verify, spec-kit hooks invoke it locally, gh-aw `post-steps:` invoke it in CI. Neither adapter replaces the spec-owned commands.

---

### Consensus 4: Namespaced commands, not preset overrides

**Origin:** spec-kit's [original review](spec-kit/UTILIZATION.md) (Rec 4, lines 47-48) proposed a companion preset that overrides core SDD commands (`/speckit.specify`, `/speckit.clarify`, `/speckit.plan`) to inject orchestrator context.

**Challenge:** This was the most unanimously opposed recommendation across all cross-reviews. APM [flagged it as dangerous](apm/reviews/spec-kit.md) because preset overrides produce duplicated, drifting context alongside APM's `applyTo` injection. gh-aw [flagged it as dangerous](gh-aw/reviews/spec-kit.md) because silent command mutation breaks deterministic verification boundaries — gh-aw's `steps:`/`post-steps:` model depends on knowing exactly what runs inside the agent sandbox.

**Hardening:** spec-kit [withdrew Rec 4](spec-kit/UTILIZATION.reviewed.md) in iteration 1, calling it the strongest convergence signal in the process — "two tools with completely different architectures independently proposed the identical alternative for different reasons." The replacement (namespaced commands like `speckit.orchestrator.plan`) was locked immediately and never contested again. spec-kit's [iteration 3 final](spec-kit/UTILIZATION.iteration_3.md) (Rec 4) documents this as a permanent design decision.

---

### Consensus 5: Single-directory state tree

**Origin:** This emerged as the negation of spec-kit's [original Rec 3](spec-kit/UTILIZATION.md) (line 45), which proposed scattering state across `.specify/extensions/orchestrator/` and `.specify/specs/{feature}/orchestrator/`.

**Challenge:** gh-aw [flagged state scattering as dangerous](gh-aw/reviews/spec-kit.md) because `cache-memory` needs a single predictable directory tree with static cache keys declared at compile time. APM [flagged it](apm/reviews/spec-kit.md) because discovery paths require a single root, not per-feature traversal.

**Hardening:** spec-kit [withdrew Rec 3](spec-kit/UTILIZATION.reviewed.md) in iteration 1. The single-directory principle was locked in [iteration 2](summary/summary_iteration_2.md). The exact path was resolved in iteration 3 as Consensus 11 (see below).

---

### Consensus 6: P7 needs a full CI integration design section

**Origin:** gh-aw's [original review](gh-aw/UTILIZATION.md) (Rec 10, lines 67) identified that P7 (GitHub Workflows) is a single row in a priority table with no detail, despite gh-aw having at least 10 directly relevant capabilities.

**Challenge:** No tool contested this. APM [supported it](apm/reviews/gh-aw.md) as it needed a place to document the static/dynamic context split. spec-kit [supported it](spec-kit/reviews/gh-aw.md) as it needed installation sequence documentation.

**Hardening:** Locked in [iteration 2](gh-aw/UTILIZATION.iteration_2.md) with an expanding scope that grew through each iteration. By [iteration 3](gh-aw/UTILIZATION.iteration_3.md) (Rec 10), the P7 section has a 10-item checklist including single-job constraints, dispatch interfaces, state lifecycle, extension installation, APM compilation, campaign architecture, budget enforcement, hook execution, distribution sequencing, and the storage contract.

---

### Consensus 7: Single-job execution model is a real platform constraint in CI

**Origin:** gh-aw's [original review](gh-aw/UTILIZATION.md) (Off-Base Assumptions, line 39) identified that the spec's autonomous dispatch loop (lines 77-91) assumes a multi-phase looping state machine can run within a single agentic workflow. gh-aw documented that workflows execute as a single job with the agent running once — no multi-stage orchestration.

**Challenge:** APM initially rated gh-aw's one-phase-per-run recommendation (Rec 8) as [dangerous](apm/reviews/gh-aw.md) because it seemed incompatible with APM's prompt-based dispatch model. spec-kit [flagged it as dangerous](spec-kit/reviews/gh-aw.md) because cold-start CI runs break spec-kit's assumption of a persistent workspace.

**Hardening:** APM [formally retracted its "dangerous" rating](apm/UTILIZATION.iteration_2.md) in iteration 2 after withdrawing its own Rec 1 (dispatch as `.prompt.md` files) — the source of the conflict was APM's own overreach, not gh-aw's constraint. spec-kit [accepted the constraint](spec-kit/reviews/iteration_1/gh-aw.md) with the modification that extension installation occurs per-run. By iteration 2 this was locked. gh-aw's [iteration 3 final](gh-aw/UTILIZATION.iteration_3.md) (Rec 8) documents both the recommended campaign pattern and alternative architectures as escape hatches.

---

### Consensus 8: APM hybrid package at P8 is the distribution integration point

**Origin:** APM's [original review](apm/UTILIZATION.md) (Rec 8, line 63) proposed the hybrid package as the distribution mechanism. The spec itself (line 278) lists "APM Packaging — One-command install distribution" as P8.

**Challenge:** No tool ever contested the hybrid package concept. Every cross-review across all iterations rated this as safe or synergistic. APM [confirmed it](apm/reviews/gh-aw.md), spec-kit [confirmed it](spec-kit/reviews/apm.md), gh-aw [confirmed it](gh-aw/reviews/apm.md). This was the only recommendation with universal support from the first round.

**Hardening:** Locked in [iteration 1](apm/UTILIZATION.reviewed.md). Strengthened in [iteration 2](spec-kit/UTILIZATION.iteration_2.md) (Rec 8) with the spec-kit-first CI sequencing model. In [iteration 3](apm/UTILIZATION.iteration_3.md) (Rec 8), APM confirmed the P8 build step uses the same `SpeckitOrchestratorIntegrator` as P1 discovery — no separate packaging mechanism.

---

### Consensus 9: TaskOps maps to Tier B's CI execution path

**Origin:** gh-aw's [original review](gh-aw/UTILIZATION.md) (Missed Opportunities, line 29) identified that the spec's Tier B workflow maps closely to gh-aw's documented TaskOps strategy: research agent investigates, planner creates scoped issues, issues assigned to Copilot for execution.

**Challenge:** No tool contested this across any iteration. APM [rated it safe](apm/reviews/gh-aw.md). spec-kit [rated it safe](spec-kit/reviews/gh-aw.md).

**Hardening:** Locked in [iteration 1](gh-aw/UTILIZATION.reviewed.md). Never reopened. gh-aw's [iteration 3 final](gh-aw/UTILIZATION.iteration_3.md) (Rec 9) documents the mapping cleanly.

---

### Consensus 10: Dispatch goes behind an abstract interface, not coupled to any tool

**Origin:** This emerged from the iteration 1 collision between three dispatch models. APM proposed `.prompt.md` files with `${input:name}` substitution ([original Rec 1](apm/UTILIZATION.md), line 49). gh-aw proposed `call-workflow`/`dispatch-workflow` ([original Rec 1](gh-aw/UTILIZATION.md), line 19). spec-kit proposed preset-injected core commands ([original Rec 4](spec-kit/UTILIZATION.md), line 47).

**Challenge:** All three were flagged as dangerous by at least one other tool. The collision was total — three fundamentally different injection/dispatch models.

**Hardening:** All three tools retreated from their tool-specific dispatch proposals in iteration 1. APM [withdrew Rec 1](apm/UTILIZATION.reviewed.md). spec-kit [withdrew Rec 4](spec-kit/UTILIZATION.reviewed.md). gh-aw [modified Rec 1](gh-aw/UTILIZATION.reviewed.md) to put `call-workflow`/`dispatch-workflow` behind an abstract interface. By [iteration 2](gh-aw/UTILIZATION.iteration_2.md), the abstract dispatch interface with concrete backends was locked. gh-aw's [iteration 3 final](gh-aw/UTILIZATION.iteration_3.md) (Rec 1) specifies minimum interface requirements: input schema, output contract, and two reference implementations (local shell + gh-aw CI).

---

### Consensus 11: State path is `.specify/orchestrator/` (not `.specify/extensions/orchestrator/`)

**Origin:** This dispute was a coordination accident. In iteration 1, gh-aw [adopted `.specify/extensions/orchestrator/`](gh-aw/UTILIZATION.reviewed.md) as a concession to spec-kit's extension convention — at the exact same moment spec-kit was [withdrawing that path](spec-kit/UTILIZATION.reviewed.md). The two tools moved toward each other and passed in transit. gh-aw's [iteration 1 meta-review of spec-kit](gh-aw/reviews/iteration_1/spec-kit.md) identified this crossed-wires problem.

**Challenge:** By iteration 2, all three tools had independently arrived at `.specify/orchestrator/`, but the formal dispute persisted because no iteration had explicitly closed it.

**Hardening:** In [iteration 3](spec-kit/reviews/iteration_3/disputes.md), spec-kit provided the decisive technical argument: `ExtensionManager.remove()` in `spec-kit/src/specify_cli/extensions.py` calls `shutil.rmtree()` on the extension directory — placing runtime state there means uninstall destroys accumulated project knowledge with no recovery path. APM [confirmed](apm/reviews/iteration_3/disputes.md) the path is immaterial to its implementation. gh-aw [confirmed](gh-aw/reviews/iteration_3/disputes.md) both paths satisfy `cache-memory` but the shorter path avoids coupling cache keys to spec-kit internals. Unanimously locked in all three [final](apm/UTILIZATION.iteration_3.md) [position](spec-kit/UTILIZATION.iteration_3.md) [documents](gh-aw/UTILIZATION.iteration_3.md).

---

### Consensus 12: APM gets unilateral read access from P1 via its own integrator

**Origin:** APM's [original review](apm/UTILIZATION.md) argued that treating APM as P8-only (distribution) underutilizes its context management capabilities (Off-Base Assumptions, line 43). APM wanted involvement from P1.

**Challenge:** spec-kit's [iteration 2 position](spec-kit/UTILIZATION.iteration_2.md) proposed a tiered timeline: no APM access P1-P6, compiler reads `.specify/` at P7, full integrator at P8. This was the most persistent dispute — surviving two full iterations.

**Hardening:** The breakthrough came in [iteration 3](spec-kit/reviews/iteration_3/disputes.md) when spec-kit recognized a category error in its own reasoning: it had been conflating "APM discovery" (read access to files on disk) with "APM dependency" (architectural coupling). spec-kit's concession — moving from P7 to P1 — was the pivotal move of the entire process. As spec-kit's [final document](spec-kit/UTILIZATION.iteration_3.md) states: "`apm compile` scanning `.specify/orchestrator/` is no different from a developer opening those files in an editor." APM proposed a `SpeckitOrchestratorIntegrator` built on its [`BaseIntegrator` framework](../apm/src/apm_cli/integration/base_integrator.py) that reads from `.specify/orchestrator/`, requires zero changes from the orchestrator or spec-kit, and degrades gracefully when the path doesn't exist.

---

### Consensus 13: The "pluggable storage adapter" is formally retired

**Origin:** The adapter concept first appeared in APM's [iteration 1 revision](apm/UTILIZATION.reviewed.md) as a bridge between spec-kit's canonical directory, APM's discovery path, and gh-aw's `cache-memory`. It was meant to abstract the storage layer.

**Challenge:** Both spec-kit and gh-aw flagged it as scope creep. spec-kit [called it a derivative of Dispute 2](spec-kit/reviews/iteration_3/disputes.md). gh-aw [argued it would become an unowned coordination obligation blocking P7](gh-aw/reviews/iteration_3/disputes.md).

**Hardening:** Once Dispute 2 resolved (APM reads directly from `.specify/orchestrator/`), the adapter lost its reason to exist. APM [formally buried the concept it originated](apm/reviews/iteration_3/disputes.md): "The three 'backends' the adapter was supposed to bridge are not three separate storage locations — they are three views of the same data." All three [final](apm/UTILIZATION.iteration_3.md) [position](spec-kit/UTILIZATION.iteration_3.md) [documents](gh-aw/UTILIZATION.iteration_3.md) confirm retirement. The replacement: three independent, tool-scoped deliverables that each read from the same documented directory structure.

---

## The Architecture That Emerged

No single tool proposed this architecture. It emerged from the adversarial process:

```
speckit-orchestrator (the spec)
│
│  writes to
│
└── .specify/orchestrator/          ← Canonical state (Consensus 1, 5, 11)
    ├── roadmap, phase summaries
    ├── decisions register
    ├── knowledge file
    └── execution log
         │
         ├── spec-kit reads ←──── Extension lifecycle, config authority,
         │                        hook integration (Consensus 2, 3, 4)
         │
         ├── APM reads ←──────── Build-time compilation via
         │                        SpeckitOrchestratorIntegrator,
         │                        P1 onward (Consensus 8, 12)
         │
         └── gh-aw caches ←───── CI durability via cache-memory,
                                  one-phase-per-run campaign model
                                  (Consensus 1, 7, 9)
```

**The key insight:** The orchestrator writes files for its own purposes. Other tools read those files for theirs. No adapters, no mirrors, no runtime coupling. Each tool does exactly what it is best at:

- **spec-kit** owns the storage contract, extension lifecycle, and configuration authority
- **gh-aw** owns CI execution constraints, durability/transport, and campaign architecture
- **APM** owns build-time context optimization and distribution packaging

---

## Concession Ledger

Every withdrawn recommendation across the process, traced to what killed it:

| Tool | Withdrawn | Killed By | Iteration | Source |
|------|-----------|-----------|-----------|--------|
| APM Rec 1 | Dispatch as `.prompt.md` | gh-aw: single-job model; spec-kit: format lock-in | 1 | [APM reviewed](apm/UTILIZATION.reviewed.md) |
| APM Rec 5 | `applyTo` for knowledge scoping | spec-kit: build-time can't serve runtime; gh-aw: no per-dispatch compilation | 1 | [APM reviewed](apm/UTILIZATION.reviewed.md) |
| APM Rec 9 | Mirror into `.apm/context/` | spec-kit: breaks extension self-containment; split-brain state | 1 | [APM reviewed](apm/UTILIZATION.reviewed.md) |
| spec-kit Rec 2 | YAML config format lock-in | APM: prevents org package overrides; gh-aw: CI needs format-neutral reads | 1 | [spec-kit reviewed](spec-kit/UTILIZATION.reviewed.md) |
| spec-kit Rec 3 | Scatter state across features | gh-aw: defeats static cache keys; APM: defeats predictable discovery | 1 | [spec-kit reviewed](spec-kit/UTILIZATION.reviewed.md) |
| spec-kit Rec 4 | Preset command overrides | APM: duplicate context injection; gh-aw: breaks deterministic verification | 1 | [spec-kit reviewed](spec-kit/UTILIZATION.reviewed.md) |

---

## Process Metrics

| Metric | Value |
|--------|-------|
| Original recommendations | 29 (APM: 9, spec-kit: 10, gh-aw: 10) |
| Dangerous contradictions found | 18 |
| Dangerous contradictions resolved | 18 (100%) |
| Recommendations withdrawn | 6 |
| Recommendations modified | 17 |
| Final consensus points | 13 |
| Iterations needed | 3 of 4 maximum |
| Disputes to human arbitration | 0 |
| Total review documents produced | 31 |
| Pivotal moment | spec-kit's P7→P1 concession on APM discovery ([iteration 3](spec-kit/reviews/iteration_3/disputes.md)) |

---

## Review Corpus

### Original Reviews
- [APM UTILIZATION.md](apm/UTILIZATION.md) — 9 recommendations for APM primitive integration
- [spec-kit UTILIZATION.md](spec-kit/UTILIZATION.md) — 10 recommendations for extension model compliance
- [gh-aw UTILIZATION.md](gh-aw/UTILIZATION.md) — 10 recommendations for CI integration

### Cross-Reviews (Iteration 0→1)
- [APM on spec-kit](apm/reviews/spec-kit.md) | [APM on gh-aw](apm/reviews/gh-aw.md)
- [spec-kit on APM](spec-kit/reviews/apm.md) | [spec-kit on gh-aw](spec-kit/reviews/gh-aw.md)
- [gh-aw on APM](gh-aw/reviews/apm.md) | [gh-aw on spec-kit](gh-aw/reviews/spec-kit.md)

### Iteration 1 Syntheses
- [APM UTILIZATION.reviewed.md](apm/UTILIZATION.reviewed.md)
- [spec-kit UTILIZATION.reviewed.md](spec-kit/UTILIZATION.reviewed.md)
- [gh-aw UTILIZATION.reviewed.md](gh-aw/UTILIZATION.reviewed.md)

### Meta-Reviews (Iteration 1→2)
- [APM on spec-kit revised](apm/reviews/iteration_1/spec-kit.md) | [APM on gh-aw revised](apm/reviews/iteration_1/gh-aw.md)
- [spec-kit on APM revised](spec-kit/reviews/iteration_1/apm.md) | [spec-kit on gh-aw revised](spec-kit/reviews/iteration_1/gh-aw.md)
- [gh-aw on APM revised](gh-aw/reviews/iteration_1/apm.md) | [gh-aw on spec-kit revised](gh-aw/reviews/iteration_1/spec-kit.md)

### Iteration 2 Syntheses
- [APM UTILIZATION.iteration_2.md](apm/UTILIZATION.iteration_2.md)
- [spec-kit UTILIZATION.iteration_2.md](spec-kit/UTILIZATION.iteration_2.md)
- [gh-aw UTILIZATION.iteration_2.md](gh-aw/UTILIZATION.iteration_2.md)

### Dispute Resolution (Iteration 3)
- [APM disputes](apm/reviews/iteration_3/disputes.md) | [spec-kit disputes](spec-kit/reviews/iteration_3/disputes.md) | [gh-aw disputes](gh-aw/reviews/iteration_3/disputes.md)

### Final Positions (Iteration 3)
- [APM UTILIZATION.iteration_3.md](apm/UTILIZATION.iteration_3.md)
- [spec-kit UTILIZATION.iteration_3.md](spec-kit/UTILIZATION.iteration_3.md)
- [gh-aw UTILIZATION.iteration_3.md](gh-aw/UTILIZATION.iteration_3.md)

### Summaries
- [Iteration 1 Summary](summary/summary_iteration_1.md)
- [Iteration 2 Summary](summary/summary_iteration_2.md)
- [Iteration 3 Final Summary](summary/summary_iteration_3_final.md)
