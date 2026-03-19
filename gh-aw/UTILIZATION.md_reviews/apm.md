# gh-aw Review of APM's Recommendations

## Dangerous Contradictions

### DC-1: APM Recommendation 1 ("Model dispatch payloads as APM prompt files") undermines gh-aw's compile-time context assembly

APM Rec 1 says each task dispatch should generate a `.prompt.md` file with YAML frontmatter and `${input:name}` parameter substitution, claiming APM's prompt system "would automatically integrate with all APM-supported runtimes."

**The conflict**: gh-aw is not an "APM-supported runtime" -- it is its own compilation and execution system. In gh-aw, the agent's prompt is the workflow's markdown body, compiled into a GitHub Actions job at build time. The agent receives its context through the workflow markdown, `steps:` pre-computed data, `cache-memory`, `repo-memory`, and imported files. There is no mechanism for gh-aw to discover and resolve APM `.prompt.md` files with `${input:name}` substitution at runtime.

If the orchestrator models dispatch payloads as APM prompt files, it would need to: (a) run `apm compile` to resolve parameters before each dispatch, and (b) somehow inject the compiled output into either a gh-aw workflow's markdown body or a `steps:` pre-computation. This adds a runtime dependency on the APM CLI for every dispatch, directly contradicting the spec's own constraint (line 283): "Must not import or wrap GSD-2 or APM at runtime."

**gh-aw's model**: Dispatch payloads in CI should be JSON passed via `dispatch-workflow` inputs or `call-workflow` reusable workflow inputs, or pre-computed data written to `/tmp/gh-aw/agent/` in `steps:` blocks. These are native gh-aw mechanisms that require no external tooling at dispatch time.

**Evidence**: gh-aw orchestration pattern (`docs/src/content/docs/patterns/orchestration.md`, lines 14-46) shows workers receiving JSON payloads and running with scoped permissions/tools. The `dispatch-workflow` safe output (`.github/aw/github-agentic-workflows.md`, lines 875-882) passes JSON payloads directly. Neither mechanism involves APM prompt resolution.

### DC-2: APM Recommendation 5 ("Use APM's instruction `applyTo` patterns for knowledge scope filtering") assumes a compilation step that does not exist in gh-aw's runtime model

APM Rec 5 proposes writing knowledge entries as `.instructions.md` files with `applyTo` patterns scoped to phase directories (e.g., `applyTo: ".specify/orchestrator/M001/P002/**"`), with APM's compilation engine handling scope filtering "automatically."

**The conflict**: gh-aw workflows execute as single GitHub Actions jobs. The agent sees the workspace as checked out by `actions/checkout`. For APM's `applyTo` patterns to work, `apm compile` must run before the agent job to assemble the right instructions into the right agent configuration files. But gh-aw's own `dependencies:` frontmatter field already handles this -- it runs APM resolution in the activation job, before the agent job starts.

The problem is that `applyTo` patterns are designed for static, repository-level instruction scoping (e.g., "apply these instructions to all Python files"). They are not designed for dynamic, per-dispatch scope filtering where the relevant knowledge changes with each phase transition. Each gh-aw workflow run is a single-job, single-agent execution. You cannot dynamically change which `applyTo` patterns are active between dispatches within the same workflow run -- because there are no multiple dispatches within one run. Each dispatch is a separate workflow run.

If the orchestrator followed this advice, it would need to either: (a) dynamically rewrite `.instructions.md` files between workflow runs, which turns build-time artifacts into mutable runtime state, or (b) generate a different APM package per phase, which is impractical.

**gh-aw's model**: Per-dispatch scope filtering is achieved by writing phase-relevant context to `cache-memory` or to files in `/tmp/gh-aw/agent/` via `steps:` blocks. The workflow's markdown prompt tells the agent which cache entries or files to read. This is explicit, requires no external tooling, and works within the single-job model.

**Evidence**: `cache-memory` with multiple named caches (`.github/aw/github-agentic-workflows.md`, lines 1284-1293) provides separate persistence for different concern areas. The one-phase-per-run model (described in gh-aw's own UTILIZATION review, Recommendation 8) means each run reads only the state relevant to the current phase.

### DC-3: APM Recommendation 6 ("Reference APM's gh-aw integration") inverts the dependency direction for the orchestrator's CI execution

APM Rec 6 says the P7 story should "build on APM's existing gh-aw integration" and "leverage gh-aw's frontmatter `dependencies:` field to declare the orchestrator's APM package and use `isolated: true` mode for clean dispatch contexts."

**The conflict**: The `dependencies:` + `isolated: true` pattern is designed for a specific use case: giving a workflow agent a clean set of APM-managed instructions/skills, free from the host repo's developer instructions. It runs once during workflow activation -- it installs a fixed set of APM primitives before the agent starts.

The orchestrator's dispatch model is fundamentally different. The orchestrator needs to vary context per dispatch: task N gets upstream summaries from phases 1-3, while task N+1 gets summaries from phases 1-4. The `dependencies:` field declares static packages that are resolved once. It cannot express "for this particular dispatch, include these specific phase summaries."

If the orchestrator follows APM's advice and puts its context management into APM packages consumed via `dependencies:`, it locks the context to whatever APM resolves at activation time. There is no mechanism to change which APM primitives are active for different worker dispatches within a campaign.

**What actually works**: gh-aw's `cache-memory` and `repo-memory` are the correct persistence layers for dynamic, per-dispatch context. The orchestrator writes phase summaries and decisions to `cache-memory` (or `repo-memory` for durable state). Each worker workflow reads what it needs from cache. This is dynamic, requires no APM resolution, and works naturally with the one-phase-per-run campaign model.

**Evidence**: APM's own gh-aw integration doc (`apm/docs/src/content/docs/integrations/gh-aw.md`, lines 142-155) describes `isolated` mode as clearing "existing `.github/` primitive directories" -- a one-time operation. gh-aw's `cache-memory` (`.github/aw/github-agentic-workflows.md`, lines 1296-1297) provides run-to-run persistence that varies with each execution.

## Tensions

### T-1: APM Recommendation 2 ("Write phase summaries as `.context.md` files") versus gh-aw's cache-memory persistence

APM wants phase summaries written as `.apm/context/phases/` files with frontmatter so `apm compile` can discover and inject them. gh-aw's review recommends storing phase summaries in `cache-memory` (structured JSON persisted across runs) or `repo-memory` (git-backed orphan branch).

**The tradeoff**: APM's approach makes summaries available to all APM-supported runtimes (IDE agents, local CLI agents). gh-aw's approach makes summaries available to CI workflows without requiring APM resolution. For local-first development (the spec's primary mode), APM's `.context.md` files on disk are immediately useful. For CI execution, gh-aw's `cache-memory` is the natural storage layer.

**Resolution path**: The orchestrator could write phase summaries as `.context.md` files locally (APM-compatible) and mirror them to `cache-memory` when running in CI. This dual-write approach adds complexity but respects both tools' discovery mechanisms. The spec should make the storage adapter pluggable rather than hardcoding either approach.

### T-2: APM Recommendation 3 ("Write boundary maps as SKILL.md files") versus gh-aw's single-job constraint

APM wants each phase's boundary map authored as a `SKILL.md` in `.apm/skills/{phase-name}/`, making phase outputs discoverable through APM's skill discovery path.

**The tradeoff**: SKILL.md files are useful for agents that have access to the full workspace filesystem (local development, Copilot coding agents). But in gh-aw's single-job execution model, the agent has workspace access only for the duration of its run. If boundary maps are SKILL.md files, a worker agent can read them -- but only if those files exist in the checked-out workspace. For dynamic orchestration where boundary maps evolve as phases complete, the files would need to be committed to the repo or stored in an artifact that the worker checkout includes.

**Resolution path**: Boundary maps could be SKILL.md files committed to the repo (updated after each phase completes via a PR or direct commit). This works for both APM discovery and gh-aw workspace access. But it means the orchestrator must commit intermediate state to the repo, which may not be desirable for all teams.

### T-3: APM Recommendation 4 ("Narrow the 'no APM at runtime' constraint") versus gh-aw's ephemeral runner model

APM wants to rewrite the constraint to allow `apm install` and `apm compile` at "setup/configuration time." In local execution, this is fine -- the orchestrator can run APM once during initialization.

**The tradeoff**: In gh-aw CI, "setup time" means `steps:` blocks that run before the agent. These blocks execute on ephemeral runners. Running `apm install && apm compile` in a `steps:` block for every workflow run adds: (a) network calls to resolve APM packages, (b) CLI execution time, and (c) a dependency on APM being installable on the runner. gh-aw's `dependencies:` frontmatter field already handles this more efficiently by running APM resolution in the activation job -- but only for static dependency sets, not dynamic per-dispatch context.

**Resolution path**: The narrowed constraint is reasonable for local execution. For CI, the orchestrator should rely on gh-aw's native `dependencies:` field for static context (orchestrator instructions, constitution) and `cache-memory`/`repo-memory` for dynamic context (phase summaries, decisions). This avoids running APM CLI on every dispatch while still benefiting from APM's static context management.

### T-4: APM Recommendation 9 ("Mirror `.specify/orchestrator/` context into `.apm/context/`") versus gh-aw's cache-based state model

APM wants orchestrator artifacts mirrored to `.apm/context/orchestrator/` for APM primitive discovery. gh-aw's review recommends persisting the same artifacts in `cache-memory` (CI) or `repo-memory` (durable).

**The tradeoff**: Mirroring to `.apm/context/` helps local agents discover orchestrator state through APM's standard paths. Persisting to `cache-memory` helps CI workflows access state without filesystem assumptions. Both are legitimate needs for different execution environments.

**Resolution path**: Same as T-1 -- dual-write with a pluggable storage adapter. The orchestrator writes to `.specify/orchestrator/` as its canonical location, with adapters that mirror to `.apm/context/` (for APM discovery) and `cache-memory`/`repo-memory` (for gh-aw CI).

## Synergies

### S-1: APM Recommendation 8 ("Publish as a hybrid APM package at P8") strengthens gh-aw's `dependencies:` integration

If the orchestrator is packaged as an APM hybrid package, gh-aw workflows can declare it as a frontmatter dependency:

```yaml
dependencies:
  packages:
    - your-org/speckit-orchestrator
  isolated: true
```

This gives worker workflows clean access to the orchestrator's instructions and constitution without manual setup. The `isolated: true` flag ensures worker agents see only orchestrator-declared context. This is exactly the pattern gh-aw's `dependencies:` field was designed for: static, pre-resolved context packages.

**Where it helps gh-aw**: Worker workflows authored as gh-aw agentic workflows get orchestrator context (coding standards, phase instructions, constitution principles) injected automatically at activation time. No `steps:` setup required for static context.

### S-2: APM Recommendation 7 ("Consider `apm pack` for milestone snapshots") complements gh-aw's `repo-memory`

APM's `apm pack --archive` produces self-contained bundles that snapshot resolved state. This is complementary to gh-aw's `repo-memory`, which stores files on an orphan branch. A milestone snapshot could be packed as an APM bundle and stored via `repo-memory`'s `upload-asset` pattern, providing both APM-compatible unpacking and git-backed durability.

**Where it helps gh-aw**: Milestone snapshots stored in `repo-memory` can be consumed by future orchestrator runs without needing network access to APM registries. The bundle format (`tar xzf`) is self-contained and works on ephemeral CI runners.

### S-3: APM's `.context.md` format is a good local-execution complement to gh-aw's CI persistence

For local (non-CI) execution, the orchestrator needs to persist phase summaries, decisions, and knowledge to the filesystem. APM's `.context.md` format with YAML frontmatter provides a structured, well-defined format for these files. When the orchestrator later runs in CI via gh-aw, the same content can be serialized to `cache-memory` JSON. The local format and the CI format can differ as long as the content model is shared.

### S-4: APM's extension manifest model aligns with gh-aw's `imports:` system

APM correctly notes that the orchestrator should be a valid spec-kit extension with `extension.yml`. Separately, gh-aw supports importing shared workflow fragments via `imports:`. If the orchestrator ships shared workflow fragments (e.g., common worker configurations, verification post-steps), those fragments can live alongside the APM package and be referenced via gh-aw's `imports:` field. The two distribution mechanisms serve different purposes (APM: agent context, gh-aw: workflow configuration) and do not conflict.

## Verdict

**Of APM's 9 recommendations:**

| # | Recommendation | Assessment | Risk Level |
|---|---------------|------------|------------|
| 1 | Model dispatch payloads as APM prompt files | **Dangerous** -- adds runtime APM dependency to every dispatch, incompatible with gh-aw's JSON payload and `steps:` data model | HIGH |
| 2 | Write phase summaries as `.context.md` files | **Tension** -- good for local, insufficient for CI; needs dual-write adapter | MEDIUM |
| 3 | Write boundary maps as SKILL.md files | **Tension** -- requires repo commits for CI visibility; adds friction to dynamic orchestration | MEDIUM |
| 4 | Narrow the "no APM at runtime" constraint | **Tension** -- safe for local, adds overhead in CI; gh-aw's `dependencies:` already handles static context | LOW |
| 5 | Use APM `applyTo` patterns for knowledge scope | **Dangerous** -- assumes compilation-time scope filtering that cannot vary per-dispatch in gh-aw's single-job model | HIGH |
| 6 | Reference APM's gh-aw integration for P7 | **Dangerous** -- inverts dependency direction; static APM packages cannot express dynamic per-dispatch context | HIGH |
| 7 | Consider `apm pack` for milestone snapshots | **Synergy** -- complements gh-aw's `repo-memory` | SAFE |
| 8 | Publish as hybrid APM package at P8 | **Synergy** -- enables gh-aw `dependencies:` integration for static context | SAFE |
| 9 | Mirror `.specify/` into `.apm/context/` | **Tension** -- good for APM discovery, orthogonal to gh-aw's `cache-memory` | LOW |

**Summary**: 3 dangerous, 4 tensions (2 medium, 2 low risk), 2 safe synergies.

The three dangerous contradictions share a common root cause: APM's recommendations assume the orchestrator's dispatch context can be assembled through APM's build-time compilation model (`apm compile` resolving `applyTo` patterns, parameter substitution, and dependency trees). gh-aw's CI execution model is fundamentally different -- each dispatch is a separate workflow run with a single agent job, and dynamic context must be injected through `cache-memory`, `repo-memory`, `steps:` pre-computation, or workflow inputs. The orchestrator spec should use APM for static, pre-resolved context (instructions, constitution, coding standards) and gh-aw's native persistence for dynamic, per-dispatch context (phase summaries, decisions, knowledge).

The two synergies are significant: APM packaging (Rec 8) directly enables gh-aw's `dependencies:` field for clean worker context, and APM bundles (Rec 7) complement `repo-memory` for durable snapshots. These should be adopted.
