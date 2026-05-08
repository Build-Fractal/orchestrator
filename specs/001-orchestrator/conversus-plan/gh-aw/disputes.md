# gh-aw Disputes Document

**Author**: gh-aw (GitHub Agentic Workflows)
**Phase**: Disputes (post-revision)
**Date**: 2026-03-19

---

## Remaining Disputes

### Dispute 1: Config file placement remains unresolved despite declared convergence

spec-kit's revision (Rec 3) withdraws the recommendation to move config into `.specify/extensions/orchestrator/`, accepting project-root placement due to APM's always-overwrite semantics. gh-aw's New Recommendation B proposes a different resolution: config at `.specify/extensions/orchestrator/orchestrator-config.yml` on the main branch, with only runtime state at `.specify/orchestrator/` synced to repo-memory. These two revised positions still conflict.

The issue is not where config physically lives -- it is **who persists it and how**. spec-kit's revision says config stays at the project root "as the plan currently specifies" and spec-kit's `ExtensionManager.get_config()` should be pointed at the non-standard path via the manifest. gh-aw's New Rec B says config follows spec-kit's convention inside `.specify/extensions/` and is committed to the main branch as a normal file, safe from APM overwrite because `apm install` only deploys extension code, not user config files.

The underlying factual question that neither revision settles: **does APM's `apm install` overwrite all files under `.specify/extensions/orchestrator/`, or only extension-distributed files?** If it overwrites everything, spec-kit's withdrawal is correct and project-root is the only safe location. If it respects user-authored files that are not part of the package manifest, then gh-aw's New Rec B is viable and places config where spec-kit's conventions expect it. APM's revision (Rec 3, modified) downgraded the lockfile concern but did not clarify the overwrite granularity.

**gh-aw's position**: This must be resolved by APM with a definitive statement about overwrite granularity. If APM confirms blanket overwrite of the target directory, config stays at the project root. If APM confirms manifest-scoped overwrite, config moves to `.specify/extensions/orchestrator/`. The plan cannot proceed with ambiguity on this point because the gh-aw adapter's `repo-memory` file-glob depends on knowing exactly which paths contain runtime state vs. user config.

### Dispute 2: The `deterministic` script annotation lacks an enforcement mechanism

All three revisions converge on classifying scripts as deterministic vs. interactive/agentic. spec-kit's New Rec 3 proposes a `deterministic: true` annotation in command frontmatter. gh-aw's New Rec C proposes the same mechanism. APM's revision does not contest it.

The convergence is real but shallow. No revision addresses: **what happens when a script annotated `deterministic: true` is not actually deterministic?** If a script marked deterministic reads agent session state, writes to stdout expecting an agent to parse it, or depends on environment variables only available inside an agent session, hoisting it into a precomputation step will silently produce wrong results. The gh-aw adapter would run the script in a context where its hidden assumptions fail, and the failure mode is not an error -- it is incorrect derived state that propagates into dispatch decisions.

**gh-aw's position**: The annotation is necessary but not sufficient. The plan must also specify:
1. A concrete contract for deterministic scripts: they accept only filesystem paths and environment variables as inputs, write only to stdout/stderr and files, and exit with a status code. No agent session, no interactive prompts, no dynamic context from the calling command template.
2. A validation mechanism: the gh-aw adapter should run deterministic scripts in a clean subprocess (no inherited agent environment) during `gh aw compile` or as a CI smoke test, verifying they produce output without errors. This catches misclassification before it causes silent failures.

Without these, the `deterministic` annotation is a trust-based label with no enforcement, and the first misclassified script will cause a debugging nightmare in CI.

### Dispute 3: The two-channel context injection strategy conflates "channel" with "lifecycle"

APM's revision (Rec 4, modified) scopes `.instructions.md` to "ambient, always-applicable guidance." spec-kit's New Rec 1 proposes a two-channel strategy: ambient context (APM `.instructions.md`) and command context (spec-kit frontmatter/templates). Both revisions present this as a clean division. gh-aw's revision accepts the framing implicitly.

On reflection, the two-channel framing underspecifies the CI case and I dispute my own implicit acceptance. In a local Claude Code session, the agent loads `.instructions.md` at session start and receives command context when a slash command fires -- two channels, two moments, clean separation. In CI via gh-aw, there is no persistent session. Each dispatched task is a single workflow run with a single markdown prompt assembled at dispatch time. There is no "session start" moment distinct from "command invocation." The two channels collapse into one: the dispatch payload, which must contain both ambient and command context pre-merged.

This means the plan's `build-context.sh` (or whatever constructs the dispatch payload) must explicitly merge content from both channels into a single prompt. Neither APM's nor spec-kit's revision acknowledges this merging responsibility. If the plan treats the two channels as independent, CI dispatches will include command context but miss ambient context (because no agent loads `.instructions.md` on a workflow runner), or include ambient context but miss command context (because no slash command fires in CI).

**gh-aw's position**: The two-channel model is correct for local execution. For CI, the adapter contract must define a `build_dispatch_payload` operation that explicitly merges ambient context (from committed `.instructions.md` files or equivalent) with command context (from frontmatter/templates) into a single dispatch prompt. The plan should specify the merge order and conflict resolution (command context overrides ambient context for contradictory guidance). This is not a new recommendation -- it is a necessary completion of spec-kit's New Rec 1 and APM's Rec 4 that neither revision provides.

---

## Convergence

### Convergence 1: Working tree is canonical; repo-memory is durability sync

All three revisions agree on the state persistence model. spec-kit's New Rec 5 states: "The working tree is always canonical." gh-aw's revision (Rec 3, modified) accepts this: "I accept spec-kit's resolution. The working tree at `.specify/orchestrator/` is the canonical source of truth." APM's revision (Rec 10, withdrawn) drops context linking for knowledge artifacts, removing the last pressure to put state anywhere other than the working tree. gh-aw's New Rec A formalizes this as the hydrate-execute-persist sequence.

This is the most important convergence of the entire conversus process. It resolves the dangerous contradiction that all three cross-reviews flagged independently and establishes the foundational invariant the adapter contract depends on.

### Convergence 2: Verification tiers with explicit authority assignment

All three revisions converge on the four-tier verification model with no overlap between tiers:
- **Tier 1** (static checks): Deterministic scripts as precomputation steps (gh-aw) or `{SCRIPT}` invocations (spec-kit local).
- **Tier 2** (command checks): Spec-kit checklists as the authoritative gate for phase readiness.
- **Tier 3** (behavioral preview): gh-aw staged mode, advisory only, escalates to human review on failure.
- **Tier 4** (human review): Manual review, unchanged.

APM's revision (Rec 9, withdrawn) explicitly removes APM hooks from the verification picture. spec-kit's revision (Rec 7, modified) assigns each tier to exactly one mechanism. gh-aw's revision (Rec 9, modified) accepts tier 3 as gh-aw's specific scope. APM's New Rec 3 codifies the single verification ownership model. This convergence eliminates the three-way governance confusion that was the most dangerous cross-review finding.

### Convergence 3: Dual-path script invocation with single source script

All three revisions accept that the same script file is invoked through different paths depending on the runtime:
- spec-kit local: frontmatter `scripts:` field, `{SCRIPT}` placeholder.
- APM local: `apm run <alias>`, invoking the script by path.
- gh-aw CI: `on.steps:` precomputation, invoking the script by path directly.

APM's revision (Rec 7, modified) scopes APM scripts to local development. spec-kit's revision (Rec 2, modified) accepts that the gh-aw adapter may hoist deterministic scripts into precomputation. gh-aw's revision (Rec 5, modified) accepts the dual-path contract. The principle -- one script, multiple invocation paths, adapter chooses the appropriate path -- is unanimously accepted.

### Convergence 4: Dependency matrix replaces "no runtime dependency" claims

APM's revision (Rec 8, modified) proposes a dependency matrix showing when each tool runs and what it is required for. gh-aw's New Rec D proposes the same classification (runtime, build-time, CI runner dependencies). spec-kit's revision does not contest this framing. All three agents agree that the blanket "no runtime dependency" constraint should be replaced with a precise matrix distinguishing runtime, build-time, and CI runner dependencies. The specific matrix content (APM = install-time, gh-aw = compile-time, spec-kit = always required) is not contested by any revision.

### Convergence 5: Lock file schema with adapter-type discriminator

APM's New Rec 4 proposes an `adapter_type` discriminator and `check_liveness(lock_data) -> bool` operation. spec-kit's New Rec 4 proposes `runtime` and `run_id` fields. gh-aw's revision (Rec 2, refined) accepts APM's polymorphic lock schema with `runtime` discriminator, making gh-aw's `run_id`-based approach the adapter's implementation of the shared interface. All three revisions agree the lock file needs a discriminator field and adapter-polymorphic liveness checking. The specific schema fields (`runtime` + `run_id` for CI, `pid` for local) and the interface method (`check_liveness`) are not contested.

---

## Final Position Statement

The revision process resolved the majority of the cross-review conflicts. Of the four dangerous contradictions gh-aw's cross-reviews originally identified across APM and spec-kit, three are definitively resolved: state persistence (working tree canonical), verification authority (four tiers, no overlap), and APM hooks (withdrawn). The fourth -- config file placement -- remains disputed because the resolution depends on a factual claim about APM's overwrite behavior that has not been definitively answered.

gh-aw's central contribution to this conversus was establishing that CI execution imposes constraints that local-first designs do not anticipate: ephemeral runners invalidate assumptions about persistent sessions, file-based context channels collapse into single dispatch payloads, PID-based liveness is meaningless, and sequential command chaining becomes async context-free dispatch. The revisions show that both APM and spec-kit internalized these constraints and adjusted their positions accordingly.

The three remaining disputes are not fundamental design disagreements. They are specification gaps where convergence was declared prematurely:

1. **Config placement** needs one more factual input from APM about overwrite granularity.
2. **Deterministic script annotation** needs an enforcement contract, not just a label.
3. **Two-channel context injection** needs explicit CI merge semantics, not just a local-execution model.

All three are resolvable within the current architecture. None require revisiting the converged positions on state persistence, verification authority, or the adapter contract. The plan can proceed to implementation with these three items flagged as pre-implementation decisions that must be made before the relevant components are built -- they do not block the overall architecture.
