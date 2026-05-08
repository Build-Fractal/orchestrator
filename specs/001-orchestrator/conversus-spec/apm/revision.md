# APM Utilization Review: Iteration 1

**Reviewer perspective**: APM (Agent Package Manager)
**Spec under review**: `specs/001-orchestrator/spec.md`
**Date**: 2026-03-18
**Iteration**: 1 (post cross-review revision)

**Cross-reviews received from**: spec-kit, gh-aw
**Cross-reviews issued to**: spec-kit, gh-aw

---

## 1. Recommendation Dispositions

### Recommendation 1: Define the orchestrator's `apm.yml` manifest as a spec deliverable — **Surviving**

**Original**: Add a new functional requirement specifying the exact `apm.yml` contents: name, version, type, dependencies, and scripts.

**Criticism received**:
- spec-kit (Tension 2.1): Argues the community catalog should be the primary distribution channel, with APM packaging as secondary. Warns that front-loading APM packaging diverts effort from the core extension infrastructure.
- gh-aw (Tension 2.1): Argues APM wants to "ship everything at install time" while gh-aw needs runtime resolution, creating a packaging-completeness vs. runtime-adaptability tension.

**Rebuttal**: Neither cross-review argues against the existence of `apm.yml` — their objection is about priority and primacy. That is a scheduling concern, not a specification concern. A spec deliverable defines what the artifact looks like; the implementation plan decides when it gets built. The `apm.yml` manifest is the contract that enables every downstream APM integration (lockfile tracking, version pinning, `apm pack`, multi-agent deployment). Without it defined in the spec, US-8 is an acceptance scenario with no concrete deliverable. spec-kit's own recommendation 10 (catalog submission) requires a well-defined package — the `apm.yml` manifest is what makes the package well-defined. gh-aw's tension is resolved by the manifest itself: `apm.yml` declares static contents; runtime state resolution is orthogonal.

---

### Recommendation 2: Map each skill folder to APM's skill integration contract — **Modified**

**Original**: For each of the six skill categories, specify that the root `SKILL.md` has required frontmatter, names conform to agentskills.io validation, and folder structure matches APM's expectations for bundled resources.

**Criticism received**:
- spec-kit (Contradiction 1.1): The skill folder concept is "fundamentally orthogonal to the extension system." Spec-kit extensions package commands as individual markdown files in `commands/`, scripts in `scripts/`, templates in `templates/`. There is no "skill folder" primitive in spec-kit. Recommendation 7 from spec-kit asks the spec to eliminate the parallel skill folder abstraction entirely.
- gh-aw (Safe Agreement 3.2): Endorses the skill folder structure as architecturally sound, noting skills are content and gh-aw workflows are execution infrastructure that consumes that content.

**Concession**: spec-kit is correct that the extension model is the authoring-time and runtime-time canonical structure. The orchestrator is first a spec-kit extension, and its commands, scripts, and templates must conform to spec-kit's extension primitives. I was wrong to treat the skill folder as a pre-existing settled structure that APM packaging simply wraps. The spec's skill folder design was written before either review, and it needs reconciliation with spec-kit's extension model, not just APM validation layered on top.

**Revised recommendation**: The spec should define a **single directory structure that satisfies both systems**. Each orchestrator command exists as a spec-kit command markdown in `commands/` AND has a corresponding `SKILL.md` in the same logical grouping for APM discovery. The `SKILL.md` is the APM entry point; the command markdown is the spec-kit entry point. Both coexist. Concretely: the extension directory contains `commands/orchestrate-auto.md` (spec-kit reads this) and a sibling or embedded `SKILL.md` (APM reads this). The spec should define this dual-entry-point layout as a deliverable and specify the mapping rules. APM's skill naming validation (1-64 chars, lowercase-hyphenated) applies to the APM-facing names, not to spec-kit's command naming convention. The reconciliation is coexistence, not one system eliminating the other.

---

### Recommendation 3: Separate user configuration from skill-folder configuration — **Modified**

**Original**: Revise FR-040 to clarify that the active user configuration lives at `.specify/orchestrator/config.json` (outside the APM-managed skill folder), while each skill's `config.json` is a defaults/schema template.

**Criticism received**:
- spec-kit (Contradiction 1.2): spec-kit already has a multi-layer configuration system (extension defaults in `extension.yml`, project config, local overrides, env vars). APM's recommendation creates a third configuration path that is neither APM-managed nor spec-kit-managed.
- gh-aw (Contradiction 1.4): `.specify/orchestrator/config.json` solves the overwrite problem locally but is ephemeral in CI — the path is in the working directory and is not persisted between workflow runs. For CI, config that evolves during orchestration must persist in repo-memory.

**Concession**: I accept both criticisms partially. spec-kit is right that the live configuration should flow through spec-kit's extension config system, which already provides layered precedence, local overrides, and env var support. I should not have proposed a freestanding JSON file that duplicates what spec-kit already provides. gh-aw is right that CI persistence requires additional consideration beyond the working tree.

**Revised recommendation**: The spec should use spec-kit's multi-layer configuration system as the canonical config infrastructure (extension defaults, project config, local overrides, env vars). The critical constraint from APM's side remains: **user-mutable configuration MUST NOT reside in APM-managed directories** — any file APM deploys is subject to overwrite on reinstall. spec-kit's extension defaults in `extension.yml` can serve as the APM-deployed defaults layer (overwritten is fine for defaults). The mutable project config (`orchestrator-config.yml`) and local overrides (`.local.yml`) must live outside APM's deployment radius. For CI persistence, gh-aw's repo-memory can mirror the active configuration, but the working-tree config file remains the runtime source of truth per the spec's Principle 6 (State On Disk Is Truth) — repo-memory is a persistence mechanism, not a replacement for disk state.

---

### Recommendation 4: Add `apm pack` as the CI distribution mechanism for User Story 7 — **Withdrawn**

**Original**: Extend the GitHub Agentic Workflows acceptance scenarios to include `apm install && apm pack` in the activation job, with the agent job unpacking the bundle with zero network access.

**Criticism received**:
- gh-aw (Contradiction 1.3): gh-aw workflows declare dependencies in frontmatter, and the activation job handles dependency installation before the agent job starts. The activation job runs `apm install` with network access — only the agent job is sandboxed. There is no need for pre-packed archives because the activation job resolves dependencies natively. A packed bundle is a frozen snapshot that cannot pick up hotfixes without re-packing.
- spec-kit (Tension 2.4): If the extension is committed to the repository (most spec-kit extensions are), `apm pack` is unnecessary — the files are already present in the CI checkout.

**What I concede**: My recommendation was based on an incorrect assumption about gh-aw's sandboxing model. I assumed the entire CI execution environment lacked network access, requiring pre-packed bundles. gh-aw's architecture splits execution into an activation job (with network, runs `apm install`) and an agent job (sandboxed). Since `apm install` runs in the activation job with full network access, `apm pack --archive` adds a build step, storage step, and extraction step that are redundant with gh-aw's native frontmatter-based dependency resolution. Additionally, spec-kit extensions are typically committed to the repository, making even `apm install` unnecessary in many CI scenarios. I withdraw this recommendation.

---

### Recommendation 5: Leverage APM's hook integration for cross-agent hook deployment — **Modified**

**Original**: Package the orchestrator's four hooks (before_tasks, after_tasks, before_implement, after_implement) as APM hook JSON files under `.apm/hooks/` for automatic deployment to `.github/hooks/`, `.claude/settings.json`, and `.cursor/hooks.json`.

**Criticism received**:
- spec-kit (Contradiction 1.3): The spec's hooks are spec-kit extension hooks, registered via `extension.yml` and executed by spec-kit's hook system at defined lifecycle points. They are markdown command invocations within spec-kit's lifecycle, not IDE-level event handlers. Deploying them through APM's hook system would bypass spec-kit's extension registration and create a parallel hook execution path.
- gh-aw (Contradiction 1.1): In CI, hooks deployed to `.github/hooks/` are irrelevant — the execution environment is a GitHub Actions runner, not an IDE. Verification gates must be workflow-native. If verification is implemented exclusively as IDE-deployed hooks, those gates silently disappear in CI.
- spec-kit (Tension 2.4 in gh-aw's review): APM hooks fire on IDE events (file save, pre-commit); spec-kit hooks fire on SDD lifecycle events (command execution). These are fundamentally different hook surfaces.

**Concession**: Both cross-reviews are correct that I conflated two different hook systems. The orchestrator's four SDD lifecycle hooks (before_tasks, after_tasks, before_implement, after_implement) are spec-kit extension hooks that fire during spec-kit command execution. They belong in `extension.yml` and are managed by spec-kit's hook registration system. APM's hook JSON system serves a different purpose — IDE-level event handlers that fire on file patterns, pre-commit, etc. I was wrong to propose repackaging spec-kit lifecycle hooks as APM hooks.

**Revised recommendation**: APM hooks should be used **only for IDE-level concerns that are genuinely outside spec-kit's lifecycle**. Concrete examples: (a) a warning hook that fires when a user manually edits files in `.specify/orchestrator/` without going through orchestrator commands, (b) a pre-commit hook that validates orchestrator state consistency before allowing a commit. These are legitimate APM hook use cases because they operate at the IDE/git layer, not the SDD workflow layer. The four SDD lifecycle hooks remain exclusively in spec-kit's extension system. The spec should explicitly distinguish between "SDD lifecycle hooks" (spec-kit) and "IDE guard hooks" (APM, optional).

---

### Recommendation 6: Package knowledge artifacts as APM context primitives — **Modified**

**Original**: Author KNOWLEDGE.md, DECISIONS.md, and phase summary templates as `.context.md` files that participate in APM's context linking and compilation graph.

**Criticism received**:
- gh-aw (Tension 2.3): Knowledge artifacts are dynamic — they grow during execution. An APM-compiled KNOWLEDGE.md would be empty at install time (no knowledge has been generated yet), making context linking pointless. In CI, these artifacts live in repo-memory branches, read at workflow start and committed at workflow end.
- spec-kit (Tension 2.2): Both APM and spec-kit want to own how templates and artifacts are discovered and loaded. spec-kit's template resolution stack resolves templates at command execution time with precedence (presets > extensions > core). APM's context linking resolves at install/compile time.

**Concession**: gh-aw is correct that the knowledge artifacts themselves are runtime-generated and empty at install time. It makes no sense to context-link an empty KNOWLEDGE.md. I was conflating the template (schema, headers, format guidance) with the runtime content.

**Revised recommendation**: Separate the concern by artifact lifecycle. **Templates** (the schema and format definition for KNOWLEDGE.md, DECISIONS.md, phase summaries) are APM context primitives deployed at install time — they provide format guidance to agents editing these files. **Runtime instances** (the actual populated KNOWLEDGE.md with accumulated knowledge) are runtime state managed by the orchestrator and, in CI, persisted via gh-aw's repo-memory. APM's context links point to the templates for format guidance; the orchestrator reads/writes the runtime instances at `.specify/orchestrator/`. The two are separate files: `templates/knowledge-schema.context.md` (APM-deployed) vs. `.specify/orchestrator/KNOWLEDGE.md` (runtime-generated).

---

### Recommendation 7: Ship `.instructions.md` files for orchestrator state file editing — **Surviving**

**Original**: Create instructions with `applyTo: ".specify/orchestrator/**"` that guide agents on state file format requirements (YAML frontmatter schemas, JSONL log format, lock file structure).

**Criticism received**:
- spec-kit (Tension 2.2): Proposes that output templates be registered in spec-kit's template resolution stack, not as APM instruction primitives.
- gh-aw (Contradiction 1.2): Frames `apm compile` instruction injection as producing stale point-in-time snapshots.

**Rebuttal**: Neither cross-review addresses the specific use case here. `.instructions.md` files with `applyTo` patterns solve a problem that spec-kit's template system does not address and that gh-aw's staleness concern does not apply to. The use case is: when an agent opens or edits a file matching `.specify/orchestrator/**/*.md`, it should automatically receive guidance on the expected YAML frontmatter schema, state transition rules, and format constraints. This is not a template that spec-kit commands consume at runtime — it is agent guidance that loads contextually based on file patterns. It is not a runtime-state document that goes stale — it is a static format specification that changes only when the orchestrator's state file format changes (i.e., at version boundaries, when `apm install` would refresh it anyway). This is APM's most distinctive capability: targeted context injection based on file patterns. spec-kit has no equivalent mechanism, and gh-aw's staleness concern applies to runtime state, not schema documentation. The recommendation stands.

---

### Recommendation 8: Define the orchestrator's compilation target strategy — **Modified**

**Original**: The spec should state whether `apm compile` produces AGENTS.md, CLAUDE.md, or both. Recommended target: `all`.

**Criticism received**:
- gh-aw (Tension 2.2): `target: all` deploys to directories gh-aw cannot use (`.cursor/`, `.opencode/`), wasting disk space in CI and potentially confusing agent runtimes. Recommends conditional compilation: `target: detect` or a CI-specific flag.
- spec-kit (Tension 2.3): The install/compile distinction is APM-specific and should not contaminate the core extension architecture.

**Concession**: gh-aw is right that `target: all` is wasteful in CI and potentially confusing. spec-kit is right that the install/compile distinction should be confined to the APM packaging layer.

**Revised recommendation**: Define the compilation target in the `apm.yml` manifest as `target: detect` (compile for detected agent runtimes only), not `target: all`. Document that in CI environments (`GITHUB_ACTIONS=true`), only `.github/` targets are relevant. The install/compile distinction remains an APM packaging concern defined exclusively under US-8, not as a core functional requirement. The extension's FRs (FR-028 through FR-032) describe what the extension provides; the APM packaging section under US-8 describes how those artifacts map to APM's install-time vs. compile-time pipelines.

---

### Recommendation 9: Add version pinning acceptance scenarios to User Story 8 — **Modified**

**Original**: Extend US-8 to verify `apm install speckit-orchestrator#v0.1.0` pinning, `apm.lock.yaml` SHA tracking, and clean `apm uninstall` artifact removal.

**Criticism received**:
- gh-aw (Tension 2.5): Strict version pinning during active development creates friction — every workflow update requires a version bump, a new tag, and consumers must update their pinned version. Recommends branch-based dependency syntax during development, switching to tag-based pinning at stable release.

**Concession**: gh-aw is right that tag-based pinning is premature for a spec in draft status. During active development, branch-based tracking (`@main`) is more practical.

**Revised recommendation**: The version pinning acceptance scenarios should cover both modes: (a) branch-based tracking (`apm install speckit-orchestrator@main`) for pre-1.0 development, verifying that `apm.lock.yaml` records the branch name and commit SHA, and (b) tag-based pinning (`apm install speckit-orchestrator#v1.0.0`) for stable releases, verifying exact version resolution. The spec should recommend branch-based tracking as the default during the orchestrator's development phase and tag-based pinning for production consumers. Clean `apm uninstall` verification remains in both modes.

---

## 2. New Recommendations

### New Recommendation A: Define a dual-entry-point directory layout as a spec deliverable

**Source**: The skill folder contradiction between spec-kit (Contradiction 1.1) and APM (Cross-review 1.1) reveals that neither review fully solved the structural question. Both identified the problem; neither proposed a concrete layout.

**Recommendation**: The spec should include a deliverable that defines the extension's directory structure with explicit annotations showing which files each system reads. Example:

```
orchestrator/
  extension.yml              # spec-kit reads: extension manifest
  apm.yml                    # APM reads: package manifest
  commands/
    orchestrate-auto.md      # spec-kit reads: command definition
    orchestrate-verify.md    # spec-kit reads: command definition
    ...
  skills/
    orchestrator-auto/
      SKILL.md               # APM reads: skill entry point (refs commands/orchestrate-auto.md)
      scripts/               # Both: shell scripts for the command
      templates/             # spec-kit reads via resolution stack; APM deploys as bundled resources
      references/            # APM deploys as bundled resources
    ...
  scripts/                   # spec-kit reads: extension-level scripts
  templates/                 # spec-kit reads: extension-level templates
```

The `SKILL.md` in each skill folder references the corresponding command markdown, serving as APM's discovery entry point without duplicating content. The `commands/` directory serves spec-kit's extension model. Both systems read from the same source tree with no file duplication.

### New Recommendation B: Explicitly define the boundary between APM-deployed and runtime-generated directories

**Source**: Both cross-reviews (spec-kit Contradiction 1.2, gh-aw Contradiction 1.4) and my own cross-review of spec-kit (Tension 2.4) converge on the need for a clear ownership boundary.

**Recommendation**: The spec should add a non-functional requirement or architecture constraint stating:
- `.specify/extensions/orchestrator/` is APM's deployment target (extension code, defaults, templates — overwritten on `apm install`)
- `.specify/orchestrator/` is the runtime state directory (phase files, lock files, JSONL logs, KNOWLEDGE.md, DECISIONS.md — never touched by APM)
- No APM primitive may target any path under `.specify/orchestrator/`
- No runtime operation may modify files under `.specify/extensions/orchestrator/`

This makes the ownership boundary explicit and prevents the overwrite/persistence conflicts both cross-reviews identified.

### New Recommendation C: Define a dispatch interface abstraction, not a dispatch implementation

**Source**: gh-aw's recommendation to use `dispatch-workflow` and `create-agent-session` as the dispatch primitives (gh-aw Recommendations 2, 5) conflicts with the spec's agent-agnostic requirement (FR-032). My cross-review of gh-aw (Tension 2.4) identified this but only proposed a resolution path, not a concrete spec change.

**Recommendation**: The spec should define a dispatch interface as a functional requirement: a payload format (what context a dispatched task receives), a completion signaling mechanism (how the orchestrator knows a task finished), and a result collection format (how task outputs are returned). The spec should then specify that dispatch implementations are pluggable adapters: gh-aw's `dispatch-workflow` is one adapter, local subprocess spawning is another, Copilot agent sessions via `create-agent-session` is a third. The orchestrator's core logic programs against the interface, not any specific adapter. This prevents vendor lock-in to any single dispatch mechanism while still enabling gh-aw's CI capabilities.

---

## 3. Position Summary

### What I got wrong

My original review over-extended APM's packaging concerns into runtime territory. Three patterns recur in the valid criticisms:

1. **Conflating install-time and runtime artifacts**: I recommended packaging runtime-generated knowledge artifacts as APM context primitives (Rec 6), repackaging SDD lifecycle hooks as APM hook JSON (Rec 5), and compiling constitutions into static instruction files (implicit in Rec 8). These all attempt to solve runtime problems with install-time mechanisms — exactly the pattern gh-aw's summary identifies as my systematic blind spot.

2. **Assuming APM's distribution model is the only distribution model**: I treated `apm pack` as necessary for CI (Rec 4, withdrawn) based on an incorrect understanding of gh-aw's sandboxing architecture. I also positioned APM packaging as structurally prior to spec-kit's extension model (Rec 2, modified), when the correct ordering is: spec-kit extension first, APM packaging wraps whatever the extension produces.

3. **Proposing parallel infrastructure instead of integrating with existing systems**: My config recommendation (Rec 3) created a third configuration path instead of leveraging spec-kit's existing multi-layer system. My hook recommendation (Rec 5) proposed a parallel hook deployment path instead of recognizing spec-kit's hook system as canonical for SDD lifecycle events.

### What I got right

Three recommendations survive substantively intact:

1. **The `apm.yml` manifest must be defined** (Rec 1): No cross-review argues against this. It is the foundational contract for APM distribution.

2. **`.instructions.md` files for state file editing** (Rec 7): This addresses a genuine gap that neither spec-kit's template system nor gh-aw's runtime model covers — contextual agent guidance based on file patterns. It is APM's most distinctive capability applied to a real problem.

3. **Version pinning and lockfile tracking** (Rec 9, modified): The mechanism is right; only the default mode (branch vs. tag) needed adjustment for the project's maturity stage.

### Revised overall stance

APM's role in the speckit-orchestrator is **distribution and agent-contextual guidance for static artifacts**. Specifically:

- **APM owns**: Package manifest (`apm.yml`), skill entry points (`SKILL.md` files), multi-agent deployment (copying to `.github/skills/`, `.claude/skills/`, etc.), targeted instructions (`.instructions.md` with `applyTo` patterns for state file format guidance), version tracking (`apm.lock.yaml`), and IDE-level guard hooks (pre-commit validation, manual-edit warnings).

- **APM does not own**: SDD lifecycle hooks (spec-kit's extension system), runtime configuration (spec-kit's multi-layer config), knowledge artifact content (runtime-generated, persisted by orchestrator or gh-aw repo-memory), CI distribution strategy (gh-aw's activation job handles this natively), constitution management (spec-kit's `.specify/memory/` is the source of truth), or the dispatch mechanism (must be an abstract interface with pluggable adapters).

- **APM shares**: The directory structure (dual-entry-point layout serving both spec-kit and APM), template artifacts (format schemas deployed by APM, consumed by spec-kit's resolution stack at runtime), and the extension's functional boundary (defined by spec-kit's extension model, packaged by APM's distribution model).

The orchestrator is a spec-kit extension that APM distributes. Not an APM package that happens to run in spec-kit.
