# Conversus Final Summary: Speckit-Orchestrator Plan Review

**Date**: 2026-03-19
**Synthesizer**: Neutral (cross-agent)
**Spec**: 001-speckit-orchestrator

---

## Process

| Metric | Count |
|--------|-------|
| Agents | 3 (APM, spec-kit, gh-aw) |
| Phase 1 reviews | 3 |
| Phase 2 cross-reviews | 6 |
| Phase 3 revisions | 3 |
| Phase 4 disputes | 3 |
| Total artifacts | 15 |
| Mode | Written adversarial review with structured convergence |

Each agent reviewed the plan from its domain perspective (Phase 1), cross-reviewed both other agents' reviews (Phase 2), revised its own positions incorporating cross-review feedback (Phase 3), and filed remaining disputes and convergence declarations (Phase 4).

---

## Recommendation Scorecard

| Tool | Original Recs | Withdrawn | Modified | Surviving | New |
|------|:---:|:---:|:---:|:---:|:---:|
| APM | 10 | 3 (5, 9, 10) | 4 (2, 3, 4, 7) | 3 (1, 6, 8) | 4 (New-1 through New-4) |
| spec-kit | 10 | 1 (3) | 5 (2, 5, 6, 7, 9, 10) | 4 (1, 4, 8; OB-3) | 5 (New-1 through New-5) |
| gh-aw | 10 | 0 | 5 (3, 5, 7, 9, 10) | 5 (1, 2, 4, 6, 8) | 4 (A, B, C, D) |
| **Totals** | **30** | **4** | **14** | **12** | **13** |

---

## Dangerous Contradictions Found

Categorized count across the 6 cross-reviews (Phase 2):

| Cross-Review | Dangerous Contradictions | Productive Tensions | Safe Agreements |
|---|:---:|:---:|:---:|
| APM reviewing spec-kit | 4 | 5 | 3 |
| APM reviewing gh-aw | 3 | 5 | 3 |
| spec-kit reviewing APM | 3 | 5 | 3 |
| spec-kit reviewing gh-aw | 3 | 5 | 4 |
| gh-aw reviewing APM | 4 | 5 | 4 |
| gh-aw reviewing spec-kit | 3 | 5 | 4 |
| **Totals** | **20** | **30** | **21** |

The 20 dangerous contradictions cluster into 5 recurring themes: config file placement (appeared in 5 of 6 cross-reviews), verification architecture ownership (5 of 6), context injection channel conflict (4 of 6), lock file liveness model (3 of 6), and APM compilation lifecycle mismatch (3 of 6).

---

## Systemic Contradictions

These are the deepest architectural tensions that cut across all three tools. They are not individual recommendation conflicts but structural forces that will recur whenever the three tools interact.

### 1. Install-time overwrite vs. runtime config persistence

APM's deployment model is always-overwrite: `apm install` replaces the target directory. Spec-kit's extension model assumes the extension directory is a safe home for user-authored config. gh-aw's CI model needs config accessible on ephemeral runners without special syncing. These three assumptions cannot simultaneously be true for a single directory path. The plan attempted to resolve this with AD-7 (deployment boundary separation), but the specific location of `orchestrator-config.yml` remains the most-contested question in the entire conversus -- appearing as a dangerous contradiction in 5 of 6 cross-reviews and still unresolved after Phase 4.

### 2. Static channels vs. ephemeral dispatch prompts

APM and spec-kit both model context injection as channel-based: agents load `.instructions.md` at session start, receive frontmatter at command invocation. gh-aw's CI model has no persistent session -- each dispatch is a standalone prompt assembled once. The two-channel model that APM and spec-kit converged on (ambient + command-time) collapses into a single pre-merged payload in CI. This means any context architecture designed for local execution must have an explicit CI merge strategy, and no revision fully specified one.

### 3. Sequential command chaining vs. async context-free dispatch

Spec-kit's `handoffs` frontmatter assumes same-session transitions where context transfers between commands. gh-aw's `dispatch-workflow` creates independent, context-free runs. The `auto` command must work in both modes, but the handoff mechanism "becomes a lie in CI" (gh-aw's phrase) -- it promises context transfer but delivers context-free dispatch. This tension is structural: any feature that relies on session continuity will require a separate design for CI.

### 4. Verification as enforcement vs. verification as information

Spec-kit's checklists block `/speckit.implement` -- they are hard gates. gh-aw's staged mode previews side effects without executing -- it is informational. APM's hooks (now withdrawn) would have fired per-write as defense-in-depth. The converged four-tier model assigns each mechanism to a tier, but the fundamental tension between "verification that stops you" and "verification that informs you" will resurface whenever a new verification need is identified.

### 5. Single-source metadata vs. multi-surface discoverability

APM discovers capabilities via `SKILL.md`. Spec-kit discovers them via command frontmatter. gh-aw discovers them via workflow frontmatter. The plan's AD-6 attempted to declare command frontmatter as the single source with derivation to other surfaces, but APM's derivation capability does not exist. Every capability must currently be declared in multiple places (command frontmatter + SKILL.md + workflow frontmatter), creating a drift risk that scales with the number of commands.

---

## Convergence Achieved

These positions are agreed by all three tools after the full four-phase process. They are safe to implement without further deliberation.

### 1. Working tree is canonical; repo-memory is durability sync

`.specify/orchestrator/` in the working tree is the single source of truth during execution. The gh-aw adapter follows a hydrate-execute-persist sequence (pull from repo-memory at run start, execute against filesystem, push to repo-memory at run end). Spec-kit hooks and APM path assumptions both depend on working-tree presence. This was the most important convergence -- flagged as a dangerous contradiction in all cross-reviews and resolved unanimously in revisions.

### 2. Spec-kit checklists are the primary verification gate

Phase must-haves are expressed as spec-kit checklists that gate `/speckit.implement`. The orchestrator's R-006 verification ladder implements checklist verification (it is not a parallel system). gh-aw staged mode is advisory (tier 3). APM hooks are excluded entirely (APM withdrew Rec 9). The four tiers are: static scripts (tier 1), spec-kit checklists (tier 2), staged mode (tier 3), human review (tier 4).

### 3. Dual-path script invocation with adapter-chosen execution context

The same script file is invoked through three paths: spec-kit frontmatter `{SCRIPT}` for local command execution, `apm run` for local interactive discoverability, and gh-aw `on.steps:` for CI precomputation. The script is context-agnostic. The adapter chooses the invocation path. No adapter-specific logic lives inside scripts.

### 4. APM compilation is install-time only, not dispatch-time

`apm compile` runs at install or update time, never per-dispatch. The orchestrator's `build-context.sh` handles per-dispatch payload construction. APM withdrew Rec 5 (compilation for dispatch payloads). This cleanly separates APM's lifecycle from the orchestrator's runtime lifecycle.

### 5. Dependency matrix replaces "no runtime dependency" blanket claim

All three tools agreed to replace the vague constraint with an explicit matrix: APM runs at install/update time, gh-aw runs at workflow compile time, spec-kit runs always at runtime. CI runners require only git, bash, and jq -- no APM CLI or gh-aw CLI. The matrix makes lifecycle dependencies explicit rather than hiding behind slogans.

### 6. Lock file schema with adapter-type discriminator

The lock file includes a `runtime` discriminator field (`"local"`, `"ci-github"`, extensible) and adapter-specific liveness data (`pid` for local, `run_id` for CI). The shared `derive-phase.sh` reads `runtime` to determine the liveness check strategy. All three tools agree on the polymorphic schema; minor naming preferences (`adapter_type` vs `runtime`) are deferred to plan authors.

### 7. SKILL.md as a single package-level summary

One root-level `SKILL.md` describing the orchestrator's overall capability, not per-command skill files. Avoids the parallel hierarchy problem while providing APM skill discoverability. Automated frontmatter-to-SKILL.md derivation is tracked as APM roadmap work, not a blocker.

### 8. Deployment boundary separation is non-negotiable

`.specify/extensions/orchestrator/` (APM-managed, overwritten on install) is strictly separated from `.specify/orchestrator/` (runtime state, never touched by install). Validated independently by all three tools as the foundational architectural invariant.

---

## Remaining Disputes

Four disputes survived the full four-phase process. None are fundamental architectural disagreements -- they are specification gaps where convergence was declared prematurely or where a factual question remains unanswered.

### Dispute 1: Config file placement

| Tool | Final Position |
|------|---------------|
| APM | Project root. Non-negotiable. APM's `apm install` uses always-overwrite for `.specify/extensions/orchestrator/`. Config inside that directory is destroyed on update. |
| spec-kit | Project root (withdrew original recommendation). Accepted as a documented deviation from spec-kit's convention. But notes gh-aw's New Rec B reopened the question without justification. |
| gh-aw | `.specify/extensions/orchestrator/`. Asks APM for a definitive statement on overwrite granularity: does `apm install` overwrite ALL files in the target directory, or only extension-distributed files? If the latter, the spec-kit convention is safe. |

**Blocking question**: Does APM's integrator overwrite the entire target directory or only files listed in the package manifest? This is a factual question about APM's code, not a design preference.

### Dispute 2: `deterministic` script annotation location

| Tool | Final Position |
|------|---------------|
| APM | No position stated (implicit acceptance of frontmatter annotation). |
| spec-kit | The annotation belongs in the gh-aw adapter's configuration, not in spec-kit's command frontmatter schema. It is gh-aw-specific optimization metadata that pollutes the command format for all extensions. |
| gh-aw | The annotation is necessary but needs an enforcement contract: a concrete definition of what "deterministic" means (filesystem-only I/O, no agent session) and a CI smoke test to catch misclassification. |

**Resolution path**: Place the classification in the adapter's config file (per spec-kit), with gh-aw's enforcement contract specifying the rules. The adapter maintains the list of scripts to hoist. If spec-kit later adds native precomputation support, the annotation can be standardized with proper schema evolution.

### Dispute 3: Two-channel context injection needs a priority rule and CI merge semantics

| Tool | Final Position |
|------|---------------|
| APM | The channels are NOT co-equal. APM `.instructions.md` is a strict subset (ambient, static, never references runtime state). Command-time context (spec-kit) handles everything else. Scope hierarchy, not co-equality. |
| spec-kit | Agrees with two channels but demands an explicit priority rule: command-time context overrides ambient context when they conflict. The specificity principle. |
| gh-aw | The two-channel model is correct for local execution but collapses into a single dispatch payload in CI. The adapter contract must define `build_dispatch_payload` that merges both channels, with command context overriding ambient context. |

**Resolution path**: All three positions are compatible. Document: (1) APM instructions are ambient-only (static, file-pattern-scoped, never references state); (2) spec-kit frontmatter overrides ambient instructions on conflict; (3) the CI adapter's `build_dispatch_payload` explicitly merges both channels into a single prompt, with command context taking precedence.

### Dispute 4: Verification tier interface specification

| Tool | Final Position |
|------|---------------|
| APM | Tiers are conceptually agreed. Spec-kit checklists are the primary gate. `before_commit` hook runs R-006 scripts. |
| spec-kit | The four-tier model is correct but needs operational specification: sequence diagram (which tier runs when), failure disposition per tier (block/warn/escalate), and result schema for verification entries in the execution log. |
| gh-aw | Agrees with the tier assignment. Staged mode is tier 3 (advisory). Needs clarity on whether "advisory" means "logged but ignored" or "escalated and paused." |

**Resolution path**: Add to the plan: (1) ordered sequence relative to command lifecycle, (2) failure dispositions (tier 1: block, tier 2: block, tier 3: escalate to human, tier 4: human decides), (3) verification result schema in `execution-log.jsonl`.

---

## Actionable Plan Changes

Changes to make to the plan artifacts, ordered by priority and grouped by target file.

### P1 -- Must resolve before implementation begins

**P1-1. Add dependency matrix to plan.md** (replaces "no GSD-2 or APM runtime dependencies" constraint)
- File: `plan.md`
- What: Replace the blanket constraint at line 19 with a three-row dependency matrix (APM: install/update; gh-aw: workflow compile; spec-kit: always at runtime). Include "CI runner dependencies: git, bash, jq -- no APM CLI, no gh-aw CLI."
- Why: All three tools converged on this (APM Rec 8 modified, gh-aw New Rec D). The blanket claim caused confusion throughout the cross-review process.

**P1-2. Add `apm.yml` manifest skeleton to plan.md**
- File: `plan.md` (project structure section, line 62)
- What: Define concrete `apm.yml` with `name: speckit-orchestrator`, `version: 0.1.0`, `type: hybrid`, `target: all`, `compilation.exclude: [".specify/orchestrator/**"]`, and `scripts` entries for `status`, `verify`, `scaffold`. Add note on authority boundary: `extension.yml` is authoritative for command registration, hook declarations, config schema; `apm.yml` is authoritative for distribution metadata, compilation settings, multi-agent targets. Overlapping fields (name, version): `extension.yml` is source of truth.
- Why: All three tools flagged this as a gap (APM Rec 1, gh-aw SA-3, spec-kit T-3). Without it, the APM install path advertised in quickstart is non-functional.

**P1-3. Add `requires.commands` to extension.yml manifest**
- File: `plan.md` (extension.yml deliverable)
- What: Add `requires: commands: ["speckit.plan", "speckit.tasks", "speckit.implement", "speckit.clarify", "speckit.specify"]` to the extension manifest.
- Why: Uncontested across all reviews (spec-kit Rec 1, gh-aw SA-4). Enables install-time validation of core command dependencies.

**P1-4. Define hydrate-execute-persist adapter contract**
- File: `plan.md` (AD-3 Runtime Adapter Interface section)
- What: Formalize the three-phase sequence as a first-class adapter contract: (1) Hydrate -- CI adapter pulls state from durable storage into `.specify/orchestrator/` before any command or hook runs; (2) Execute -- all reads/writes target the working tree; (3) Persist -- adapter commits working tree state to durable storage after execution, including after all spec-kit hooks fire. State at `.specify/orchestrator/` is the canonical source of truth during execution.
- Why: Most important convergence of the process, resolving the dangerous contradiction all six cross-reviews flagged.

**P1-5. Specify dispatch mode in adapter contract**
- File: `plan.md` or new `contracts/runtime-adapter.md`
- What: For the gh-aw adapter, specify `dispatch-workflow` (async) as the dispatch mode for Tier C autonomous execution. Document that `handoffs` frontmatter is a presentation-layer mechanism for local execution; the CI adapter extracts the target command name and ignores prompt/send context. Each receiving command must be self-sufficient, reading state from disk (AD-2).
- Why: gh-aw Rec 1 (surviving, P1). Without this, the 5-operation adapter interface has no concrete mapping to gh-aw primitives.

**P1-6. Add concurrency discriminator requirement**
- File: `plan.md` or adapter contract
- What: All gh-aw task dispatch workflows must include `concurrency: { job-discriminator: ${{ inputs.task_id }} }` to prevent fan-out cancellations.
- Why: gh-aw Rec 4 (surviving, P1). Without it, dispatching task T02 cancels T01. Correctness requirement.

**P1-7. Establish single verification ownership model**
- File: `plan.md` (R-006 verification ladder section)
- What: Replace the standalone verification ladder with a tiered model integrated into spec-kit's mechanisms: Tier 1 (static) = deterministic scripts; Tier 2 (command) = spec-kit checklists gating `/speckit.implement`; Tier 3 (behavioral) = gh-aw staged mode (advisory); Tier 4 (human) = manual review. R-006 scripts are the implementation of spec-kit's checklist verification, not a parallel system. APM hooks are explicitly excluded.
- Why: The verification architecture was the most contested area across all cross-reviews. All three tools converged on this model (APM New-3, spec-kit Rec 7 modified, gh-aw Rec 9 modified).

**P1-8. Resolve config file placement**
- File: `plan.md`, `data-model.md` (line 28), `research.md` (R-004)
- What: Determine APM's overwrite granularity (blanket directory overwrite vs. manifest-scoped overwrite). If blanket: config stays at project root, document as accepted deviation from spec-kit convention, point spec-kit's `ExtensionManager.get_config()` at the project-root path via the manifest's `provides.config` section. If manifest-scoped: config moves to `.specify/extensions/orchestrator/orchestrator-config.yml` per spec-kit convention.
- Why: This is the only remaining dispute that requires a factual determination rather than a design decision. It blocks both the adapter's repo-memory file-glob configuration and the spec-kit extension manifest.

### P2 -- Should resolve before component implementation

**P2-1. Add `$ARGUMENTS` handling to all command definitions**
- File: `plan.md` (command design section)
- What: Every orchestrator command must include a `## User Input` section with `$ARGUMENTS` per spec-kit convention. Commands accepting inline arguments (evaluate, discuss, dispatch, auto) must document expected argument formats.
- Why: Spec-kit Rec 4 (surviving). Fundamental to how spec-kit commands receive user input.

**P2-2. Add `scripts` frontmatter to command markdown files**
- File: `plan.md` (command design section)
- What: Each command that invokes helper scripts must declare them in frontmatter (`scripts: { sh: ../../scripts/state/derive-phase.sh }`). Enables spec-kit's path rewriting and `{SCRIPT}` placeholder substitution.
- Why: Spec-kit Rec 2 (modified). Without this, commands need hardcoded paths to the installed extension directory.

**P2-3. Add lock file `runtime` discriminator to data model**
- File: `data-model.md` (lock file schema, lines 237-249)
- What: Add `runtime` field (`"local"`, `"ci-github"`, extensible) and `run_id` field for CI contexts. Document that `derive-phase.sh` reads `runtime` to dispatch to the correct liveness check (PID for local, `gh api` for CI). Define `acquire_lock` and `release_lock` as adapter operations that write the correct `runtime` value.
- Why: All three tools converged (APM New-4, spec-kit New-4, gh-aw Rec 2 refined). PID-based liveness is meaningless on ephemeral CI runners.

**P2-4. Add `config_schema` to extension.yml**
- File: `plan.md` (extension.yml deliverable)
- What: Define JSON Schema for the 6 config fields (default_tier, verification_commands, context_verbosity, git_isolation, dispatch_budget, duration_budget) with types and enum constraints.
- Why: Spec-kit Rec 8 (surviving). Enables config validation at load time.

**P2-5. Document two-channel context injection with priority rule**
- File: `plan.md` or `research.md` (new section or addendum to R-005)
- What: Document: (1) APM `.instructions.md` provides ambient, file-pattern-scoped rules (static, never references state); (2) spec-kit frontmatter provides command-time context (dynamic, command-specific); (3) command-time context overrides ambient context on conflict; (4) for CI, the adapter's `build_dispatch_payload` merges both channels into a single prompt with command context taking precedence. Instructions must be committed to the repo for CI runners.
- Why: Converged across all three tools but missing operational specification. All three disputes documents flagged the gap.

**P2-6. Add `budget_enforcement` config field**
- File: `data-model.md` (config schema), `plan.md`
- What: New config field `budget_enforcement: advisory | enforced`. Local adapter defaults to `advisory` (warn only). gh-aw adapter defaults to `enforced` (maps dispatch_budget to precomputation check, duration_budget to `on.stop-after:`).
- Why: gh-aw Rec 10 (modified). Without it, CI runs can exhaust GitHub Actions minutes without guardrails.

**P2-7. Create `.extensionignore`**
- File: New file `.extensionignore` in extension root
- What: Exclude `specs/`, `docs/`, `.planning/`, `tests/unit/`. Do NOT exclude `scripts/` (needed by both local and CI) or `tests/fixtures/` (may be needed by verification scripts). The gh-aw adapter references scripts from the source checkout, not the installed extension directory.
- Why: Spec-kit Rec 6 (modified). Without it, `specify extension add --dev` copies test artifacts into the installed extension.

**P2-8. Add `handoffs` to command frontmatter for local execution**
- File: `plan.md` (command design section)
- What: Declare command transitions as `handoffs` in frontmatter (e.g., auto -> plan-phase -> dispatch -> verify). Document that handoffs are presentation-layer only -- the CI adapter extracts target command names and ignores prompt/send context. Receiving commands must be self-sufficient via disk state (AD-2).
- Why: Spec-kit Rec 5 (modified). Improves local agent UX without creating CI dependency on context transfer.

**P2-9. Update quickstart installation instructions**
- File: `quickstart.md` (lines 12-20)
- What: Lead with `specify extension add --dev /path/to/orchestrator` for initial development. Move `specify extension add speckit-orchestrator` (catalog) and `apm install speckit-orchestrator` (APM) to a "Future distribution" section. Note that catalog installation requires publishing and APM installation requires a concrete `apm.yml`.
- Why: Both spec-kit (OB-3) and APM (Rec 1) flagged that the current quickstart advertises install paths that do not work today.

**P2-10. Add `before_commit` hook to hook integration**
- File: `plan.md` (hook integration), `research.md` (R-010)
- What: Expand from 4 hooks to 5: `before_tasks`, `after_tasks`, `before_implement`, `after_implement`, `before_commit`. The `before_commit` hook runs tier-1 static verification scripts to block commits when must-haves are unmet.
- Why: Spec-kit Rec 9 (modified), APM New-3. Natural commit-time enforcement point for verification.

**P2-11. Author root-level SKILL.md**
- File: New file `SKILL.md` in extension root
- What: Package-level summary describing the orchestrator's overall capability, listing all 10 commands with one-line descriptions. Header: "Manually maintained. Lists orchestrator capabilities for APM skill discovery. Update when commands are added or removed." No false "generated from frontmatter" attribution.
- Why: APM Rec 2 (modified), spec-kit New-2. APM cannot derive SKILL.md from frontmatter today. A single summary avoids the parallel-hierarchy problem.

**P2-12. Define manifest authority boundaries**
- File: `plan.md` (new section or addendum)
- What: `extension.yml` is authoritative for: command registration, hook declarations, spec-kit compatibility, config schema. `apm.yml` is authoritative for: distribution metadata, compilation settings, script aliases, multi-agent targets. Overlapping fields (name, version, description): `extension.yml` is source of truth; `apm.yml` must match. A CI check should validate consistency.
- Why: APM New-1, spec-kit T-3. Two manifests with overlapping concerns create drift risk.

### P3 -- Can be deferred to post-initial implementation

**P3-1. Add `compilation.exclude` to `apm.yml`**
- File: `apm.yml`
- What: `compilation.exclude: [".specify/orchestrator/**"]`
- Why: APM Rec 6 (surviving). Prevents `apm compile` from scanning runtime state. Low-effort defensive measure.

**P3-2. Use staged mode for behavioral verification in CI**
- File: Adapter documentation
- What: Add a `verify --staged` mode that runs the full safe-output pipeline with `staged: true`. Scope to tier-3 behavioral verification only. Advisory, not blocking.
- Why: gh-aw Rec 9 (modified to P3 scope).

**P3-3. Map budgets to CI enforcement mechanisms**
- File: Adapter documentation
- What: Document mapping: `dispatch_budget` tracked in `execution-log.jsonl` + checked in precomputation step; `duration_budget` mapped to `on.stop-after:`.
- Why: gh-aw Rec 10 (modified). Follows from P2-6 `budget_enforcement` field.

**P3-4. Add `protected-files` configuration to gh-aw adapter**
- File: Adapter workflow configuration
- What: `protected-files: fallback-to-issue`, `allowed-files: [".specify/orchestrator/**", "src/**", "scripts/**"]`.
- Why: gh-aw Rec 8 (surviving). Prevents default blocking of orchestrator state writes in PRs.

**P3-5. Split templates into overridable vs internal categories**
- File: `plan.md` (template design section)
- What: Overridable (participate in spec-kit resolution stack): phase-summary, milestone-summary, dispatch-brief. Internal (not overridable): roadmap, phase-plan, task-plan, dispatch payloads, verification templates. Document which and why.
- Why: Spec-kit Rec 10 (modified). Overriding internal templates could break CI workflow compilation.

**P3-6. Register APM scripts for local development**
- File: `apm.yml` scripts section
- What: `scripts: { status: "bash scripts/state/derive-phase.sh", verify: "bash scripts/verify/check-must-haves.sh" }`. Explicitly local-only; CI uses `on.steps:` with the same underlying scripts.
- Why: APM Rec 7 (modified). Convenience for local development ergonomics.

**P3-7. Design `auto` command dual-mode execution**
- File: `plan.md` (auto command specification)
- What: Local adapter runs in `continuous` mode (drives the full state machine loop). CI adapter runs in `step` mode (advances one unit per scheduled run, re-enters via `schedule` or `repository_dispatch`). The adapter declares its supported mode. Include `skip-if-match` for CI deduplication.
- Why: gh-aw Rec 7 (modified), spec-kit T-4. A single CI run cannot drive a full milestone due to timeout caps.

---

## Key Concessions

### APM conceded:

1. **Dispatch-time compilation** (Rec 5, withdrawn). APM's compilation engine runs at install time, not per-dispatch. Running `apm compile` 70+ times per milestone is impractical. The orchestrator's `build-context.sh` is the right tool for dispatch payloads. APM stated: "I was wrong to suggest it could replace the dispatch pipeline."
2. **APM hooks for verification** (Rec 9, withdrawn). Three verification systems is a governance disaster. Spec-kit checklists are the right primary mechanism. APM stated: "Adding APM hooks as a third layer creates governance confusion with no demonstrated gap in coverage."
3. **Context linking for knowledge artifacts** (Rec 10, withdrawn). Runtime-generated artifacts on repo-memory branches do not fit APM's link resolution model. The plan's `drill_down_paths` approach is sufficient.
4. **`.instructions.md` as primary context injection** (Rec 4, scoped down). Conceded from "primary mechanism replacing scope-filter.sh" to "ambient-only guidance." Spec-kit frontmatter owns command-time context.
5. **Lockfile urgency** (Rec 3, downgraded P1 to P2). The committed-extension path (D4 default) does not need a lockfile. Relevant only for the secondary APM-managed path.

### Spec-kit conceded:

1. **Config file placement inside extension directory** (Rec 3, withdrawn). APM's always-overwrite semantics for `.specify/extensions/orchestrator/` make it unsafe for user-authored config. Accepted project-root placement as a documented deviation from spec-kit convention. Spec-kit stated: "I was wrong to prioritize convention conformance over install-path safety."
2. **Hook count rigidity** (OB-1, modified from 6 to 5). Originally flagged 6 potential hooks; revised to recommend adopting only `before_commit` as the 5th, not the full set of 6.
3. **Checklist-only verification** (Rec 7, expanded scope). Original recommendation was narrowly about connecting must-haves to checklists. Revised to accept a four-tier model where checklists are authoritative but not the only verification mechanism.

### gh-aw conceded:

1. **Repo-memory as source of truth** (Rec 3, modified). Originally implied repo-memory IS the persistence layer. Revised to accept that the working tree is canonical and repo-memory is a durability sync. Stated: "I accept spec-kit's resolution."
2. **Staged mode as general verification** (Rec 9, scoped down). Originally proposed staged mode for the "full verification pipeline." Revised to scope it specifically to tier-3 behavioral verification only, advisory not blocking.
3. **Unilateral dispatch mode decision** (Rec 7, modified). Originally proposed scheduled re-entry as the CI design. Revised to accept spec-kit's gating authority principle: gh-aw gates run/no-run, spec-kit gates within-run behavior. Also accepted the `--continuous` vs `--step` mode distinction.
