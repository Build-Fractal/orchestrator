# Why this exists

The orchestrator did not start as its own project. It started as an extension to GitHub's [spec-kit](https://github.com/github/spec-kit), grew through two earlier homegrown predecessors, hit a wall every coding agent eventually hits, and only became a separate thing once the wall was unmistakable. This is the story of how it got here and why it looks the way it does.

## Spec-kit was the right starting point

Spec-driven development — the discipline of writing the spec first, then the plan, then the implementation, in three distinct passes against the same source of truth — predates orchestrator by years. GitHub's spec-kit packaged the discipline into a usable tool: a `/specify` flow that produced `spec.md`, a `/plan` flow that produced `plan.md`, a `/tasks` flow that produced `tasks.md`, and a shared constitution at `.specify/memory/constitution.md` that all three respected.

For single-task work — write a spec, plan it, implement it, ship — spec-kit was excellent. The discipline forced clarity. The artifacts created a paper trail. The constitution gave the assistant a stable point of view to argue against.

But spec-kit stopped at the single-task boundary. A spec was one feature. A plan was one feature's plan. The tooling assumed someone would hold the multi-feature context in their head and orchestrate the sequence by hand.

For features that fit in a single afternoon and a single context window, that was fine. For features that did not, it was not.

## GSD-1 and GSD-2 — the homegrown predecessors

Before the orchestrator-as-spec-kit-extension existed, two earlier internal tools tried to solve the multi-task problem. They were called GSD ("Get Stuff Done"), versions 1 and 2. They are now of interest only as predecessors — their adapters live on as migration sources (`scripts/migrate/adapters/gsd1.sh`, the SQLite-backed GSD-2 path) — but the lessons they encoded are still here.

GSD-1 was flat-markdown: a `.planning/` directory with `KNOWLEDGE.md`, `DECISIONS.md`, and per-milestone subdirectories. It worked. It also drifted. Without a strict on-disk shape, every project's `.planning/` tree slowly became its own bespoke layout, and the assistant had to re-learn the layout each time. The lesson: structure that an agent has to re-derive every session is structure that does not exist.

GSD-2 was the over-correction. It moved state into SQLite with a JSON schema layer, on the theory that a real database would enforce structure better than markdown. It did — and the cost was that humans could no longer read the project state without tooling. Crashes left state in a half-written transactional middle. The database file had to be packaged, migrated, and version-locked with the project itself. The lesson: state that humans cannot read on a Sunday afternoon is state that erodes trust.

The orchestrator's seventh constitutional principle — *State On Disk Is Truth* — is the direct codification of both lessons. Every piece of state is a markdown file or a JSONL line at a known path. A human with `cat` and `grep` can fully audit any project. An agent reading the same files reaches the same conclusions. The data layer has no privileged accessor.

## The wall every multi-context-window coding agent hits

The problem that finally forced orchestrator into its own shape is the one any coding agent hits the moment work outgrows a single session: **each context window is finite, and multi-week features do not fit in one**.

It is easy to underestimate this. Modern context windows are large. A single window can hold the spec, the plan, the tasks, and the relevant source files for most features people actually build. Until it cannot. Until the feature is six weeks of work, the plan branches into twelve interdependent phases, the conversation log has a million tokens of decisions, and the next session that picks up the work starts cold — without any of the context the previous sessions built up.

The intuitive response is to write better hand-off documents. Summarize what was decided. Append the running log. Re-load the assistant with everything important. This works on the third session. It collapses by the tenth. The hand-off document becomes a parallel codebase to maintain. The summary becomes longer than the code. The "everything important" payload grows past the context window it was supposed to fit into.

Orchestrator's first principle — *Context Minimization* — is the response to this collapse. The optimization target is explicit:

```
Context_Efficiency = Relevant_Instructions / Total_Instructions_Inherited
```

Every architectural decision is judged against this ratio. Distribute knowledge hierarchically (closest context wins, broad context lives at the root). Use fresh sessions per task (no accumulated transcript garbage). Produce structured summaries as the hand-off shape (not raw conversation logs). The agent dispatched to fix a typo in the auth flow receives the three knowledge entries relevant to the auth flow — not the project's entire history.

This is what *orchestration* means in this project's name. Not "orchestrating agents" in the multi-agent-system sense — orchestrating *context*. Deciding what the dispatched agent sees, when it sees it, and what it should ignore, so that the work it produces is sharp instead of generic.

## The M015 standalone cutover

For most of its life, the orchestrator lived inside spec-kit as an extension. Commands were registered as `speckit.orchestrator.*`. State lived at `.specify/orchestrator/`. The constitution lived at `.specify/memory/constitution.md`. Removing spec-kit removed the orchestrator.

This was friction. Every time spec-kit released a new version with a different extension manifest shape, the orchestrator had to chase the change. Every user who wanted the orchestrator had to install spec-kit first, then layer the extension on top, then learn which commands were spec-kit's and which were the extension's. The orchestrator's identity was tied to a project it did not own.

In April 2026, with v0.9.0, the M015 milestone cut the dependency. Four phases, nineteen functional requirements, all PASS:

- **P01** hard-deleted the spec-kit host: `extension.yml`, the nine `.claude/commands/speckit.*.md` files, the `.specify/scripts/` and `.specify/templates/` trees. No compatibility shim. Either spec-kit was a runtime dependency or it was not; half-removal was the worst of both.
- **P02** migrated state from `.specify/orchestrator/` to `.orchestrator/` at the repo root. The constitution moved to `.orchestrator/memory/constitution.md`. The state-root resolver dropped from five rules to four — the bridge rule between the old and new layout was deleted outright.
- **P03** reframed the five primary docs (`README.md`, `CLAUDE.md`, `references/architecture.md`, `references/installation.md`, `docs/getting-started.md`) as standalone, with thirteen wider doc surfaces swept. The new `docs/migrating-from-speckit.md` reframed spec-kit from "the host" to "a migration source."
- **P04** captured four evidence streams: all eight test suites PASS, the doctor clean, the spec-kit migration adapter producing a valid `.orchestrator/` from a fixture, a clean-clone shape probe finding zero extension-host artifacts.

The orchestrator became its own project. Spec-kit became one of three migration sources the orchestrator can read on first contact, alongside GSD-1 and GSD-2.

## The constitution as opinionated codification of prior failure

The constitution at `.orchestrator/memory/constitution.md` is seven principles long. None of them are aspirational. Each one is the codified reaction to a specific past failure mode:

1. **Context Minimization** — every architectural decision MUST optimize for minimizing the context each individual task consumes. *The lesson from the multi-context-window wall.*
2. **Evidence Before Claims** — no task is marked complete without fresh verification evidence. "Should work" is NOT evidence. *The lesson from every silent failure where the assistant reported success and the human discovered the regression a week later.*
3. **Design Before Code** — every piece of work goes through an explicit design step, no matter how "simple." *The lesson from the bug fixes that turned into architectural rewrites three commits in.*
4. **Plans Assume Zero Context** — task plans must be readable by an agent with zero prior knowledge of the project. *The lesson from hand-off documents that only made sense to the person who wrote them.*
5. **Fresh Context Per Unit** — each dispatch starts in a clean session. *The lesson from sessions that polluted each other and produced decisions nobody could trace.*
6. **State On Disk Is Truth** — all state recoverable from files, no in-memory cache, no database. *The lesson from GSD-1's drift and GSD-2's opacity.*
7. **Knowledge Compounds** — every phase emits structured summaries; the next phase is genuinely cheaper than the last. *The lesson from projects that ran twenty milestones and ended up no smarter than they started.*

Constitutions are easy to write and hard to enforce. The orchestrator's enforcement is mechanical, not advisory: command definitions reference the principles by number; verification scripts check them; every dispatched task receives the constitution in its context bundle so the agent doing the work can be argued back against the principle when it drifts.

## Where this leaves you

If you are reading this, you probably have a project that is either too large for a single context window today or about to be. You have probably tried hand-off documents. You have probably watched them collapse.

The orchestrator is one opinionated response. It encodes the assumption that context is scarce, that state belongs on disk where humans and agents can both read it, that verification is mechanical rather than vibes-based, and that knowledge worth keeping is knowledge worth structuring. It is not the only response. It is the one this project found durable enough to ship.

When you reach for `/orchestrator-start`, you are not picking up a tool that was designed in the abstract. You are picking up the residue of two homegrown predecessors, a spec-kit extension that outgrew its host, and a wall that every team building anything substantial with a coding agent will eventually hit.
