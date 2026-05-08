# APM Revised Position: Speckit-Orchestrator Extension

**Reviewer**: APM (Agent Package Manager)
**Date**: 2026-03-19
**Revision basis**: APM Phase 1 review, cross-reviews from spec-kit and gh-aw, APM's own cross-reviews of both

---

## Recommendation Dispositions

### Recommendation 1 (P1): Create a concrete `apm.yml` manifest
**Status: Surviving**

No cross-reviewer challenged this. Both spec-kit (T-3) and gh-aw (SA-3) independently confirmed that the plan underspecifies its distribution and configuration metadata. gh-aw's cross-review (SA-3) explicitly noted that adapter configuration (dispatch mode, concurrency, repo-memory, protected-files) also needs a manifest-level home. The recommendation stands as originally stated: define `name`, `version`, `type: hybrid`, `target: all`, with `scripts` and `compilation` settings.

One refinement from gh-aw's input (T-3): the `apm.yml` should also document the relationship to `extension.yml` -- which fields are authoritative in which manifest -- to prevent the drift risk spec-kit's cross-review identified (T-3: "two manifest files with partially overlapping concerns").

### Recommendation 2 (P1): Include a root-level `SKILL.md`
**Status: Modified**

Both cross-reviews surfaced a real tension here. Spec-kit's cross-review (T-2) correctly identified that a manually authored `SKILL.md` creates a second source of truth that drifts from command frontmatter -- exactly the parallel hierarchy the conversus process rejected. gh-aw's cross-review (T-3) confirmed the problem exists across two discoverability surfaces (SKILL.md for IDE agents, workflow frontmatter for CI agents).

My original recommendation demanded a root-level `SKILL.md` because APM cannot derive one from command frontmatter today. That factual claim stands. But the cross-reviews convince me the right path is option (b) from my own cross-review of spec-kit: **author a single summary-level `SKILL.md` at the package root** that describes the orchestrator's overall capability (not per-command skill files), with an explicit note that individual command discovery happens through spec-kit's command frontmatter. This avoids the parallel hierarchy problem while giving APM's skill detection system something to find. The `SKILL.md` is a package-level summary, not a duplication of command metadata.

Separately, APM should track frontmatter-to-SKILL.md derivation as a future feature request. That work belongs in APM's roadmap, not in this extension's implementation plan.

### Recommendation 3 (P1): Commit `apm.lock.yaml` for reproducible installations
**Status: Modified — downgraded to P2**

gh-aw's cross-review (DC-3) exposed a real problem: on ephemeral CI runners, `apm.lock.yaml` is relevant only if someone runs `apm install` on the runner, which would make APM a CI runtime dependency -- contradicting my own assertion that APM never enters the execution path. Spec-kit's cross-review (T-5) correctly noted that the plan already resolved this in D4: committed extension is the default path, APM-managed is secondary. For the primary (committed) path, the lockfile provides no value since the extension files are already version-controlled by git.

The lockfile remains important for teams using the APM-managed installation path, but it is not a P1 blocker for the initial implementation. Modified to P2: document that `apm.lock.yaml` should be committed when using the `apm install` path, but do not make it a structural requirement of the extension's project layout.

### Recommendation 4 (P2): Use APM `.instructions.md` for file-pattern-scoped guidance
**Status: Modified — scoped to ambient guidance only**

This was the most heavily contested recommendation. Spec-kit's cross-review (DC-2) identified a genuine dangerous contradiction: APM instructions and spec-kit frontmatter are two competing context injection architectures operating at different lifecycle points (agent startup vs. command invocation). gh-aw's cross-review (DC-2) added a second dimension: on ephemeral CI runners, APM instructions deployed to `.github/instructions/` do not exist unless committed to the repo.

I concede the core point. My original framing -- `.instructions.md` as "primary mechanism" replacing `scope-filter.sh` -- was overreaching. Spec-kit frontmatter mechanisms (`scripts`, `handoffs`, `$ARGUMENTS`) are the correct primary channel for command-time context because they operate within spec-kit's execution model and are visible to the spec-kit command runner.

Revised position: APM `.instructions.md` files serve **ambient, always-applicable guidance** -- static rules about file formats, state directory conventions, and editing constraints for files under `.specify/orchestrator/`. They do not replace scope filtering or command-time context injection. This aligns with spec-kit's cross-review resolution (DC-2): "spec-kit frontmatter for command-time guidance, APM `.instructions.md` for ambient guidance." The instructions must be committed to the repo (not just locally deployed) to work on CI runners.

### Recommendation 5 (P2): Leverage APM compilation for constitution injection
**Status: Withdrawn**

gh-aw's cross-review (DC-1, T-1) delivered the decisive argument. APM compilation is designed as an install-time or pre-commit operation. Running `apm compile` per-dispatch (potentially 70+ times per milestone) introduces unacceptable latency and forces APM CLI as a dispatch-time dependency. My own cross-review of gh-aw (DC-2) acknowledged this: "APM compilation must run *before* dispatch, producing a complete, self-contained prompt... Running `apm compile` on every task dispatch introduces latency and requires the APM CLI on the dispatch host."

The orchestrator's custom `build-context.sh` is the right tool for dispatch payload construction. It operates at the right lifecycle point (per-dispatch), has minimal dependencies (bash), and produces self-contained output. APM compilation should remain limited to install-time CLAUDE.md generation and one-time context assembly. I was wrong to suggest it could replace the dispatch pipeline.

### Recommendation 6 (P2): Declare `compilation.exclude` for runtime state
**Status: Surviving**

Neither cross-review challenged this. It is a defensive configuration detail: if anyone runs `apm compile` in a project with active orchestrator state, the compilation engine should not scan `.specify/orchestrator/` and produce noise. Low-effort, no controversy. Stands as stated.

### Recommendation 7 (P2): Register key operations as APM scripts
**Status: Modified — local-only scope**

gh-aw's cross-review (T-4) and my own cross-review of gh-aw (DC-1) clarified the split: in CI, gh-aw `on.steps:` precomputation is the right invocation path (no APM CLI dependency, fewer moving parts, faster). APM scripts (`apm run verify`, `apm run status`) add value only for local/interactive development where APM is already installed.

Revised position: register the scripts in `apm.yml` for local developer ergonomics, but the plan must explicitly document that CI invocations use the underlying script paths directly, not `apm run`. The gh-aw adapter's `on.steps:` and the APM scripts must invoke the same underlying bash scripts by path -- the dual-path contract my cross-review of gh-aw identified.

### Recommendation 8 (P3): Correct the "no APM runtime dependency" framing
**Status: Modified — expanded scope**

Both cross-reviews revealed this is a bigger issue than I initially framed. gh-aw's cross-review (T-3) noted that both APM and gh-aw claim "no runtime dependency" while both impose build-time steps (APM compile, gh-aw compile). My framing was correct that APM is install-time only, but incomplete: the distinction that matters is not "runtime vs. non-runtime" but "when does each tool's build step run, and is that step required for the extension to function."

Revised position: the plan should replace the blanket "no APM runtime dependencies" constraint with a precise dependency matrix:

| Tool | When it runs | Required for | Can be skipped if |
|------|-------------|-------------|-------------------|
| APM | Install/update | Package distribution, CLAUDE.md compilation | Extension is committed directly |
| gh-aw | Workflow compile | CI dispatch | Running locally only |
| spec-kit | Runtime | Command execution | Never (always required) |

This makes the actual dependency relationships explicit rather than hiding behind "no runtime dependency" as a shibboleth.

### Recommendation 9 (P3): APM hooks as supplementary verification
**Status: Withdrawn**

All three cross-reviews converged against this. Spec-kit's cross-review (DC-3) identified three competing verification architectures as a maintenance disaster. gh-aw's cross-review (DC-4) showed that APM `PostToolUse` hooks conflict with gh-aw's `protected-files` policy. My own cross-review of spec-kit (DC-4) already acknowledged that spec-kit's `before_commit` hook is the natural fit for commit-time verification.

The orchestrator already has two verification systems to coordinate (its own R-006 verification ladder and spec-kit's checklist/hook system). Adding APM hooks as a third layer creates governance confusion with no demonstrated gap in coverage. Spec-kit's checklist system is the primary verification mechanism; the orchestrator's R-006 verification ladder should implement spec-kit's checklist verification, not run alongside it. APM hooks should not be part of this picture.

### Recommendation 10 (P3): Use APM context linking for cross-artifact references
**Status: Withdrawn**

My own cross-review of spec-kit (Productive Tension #5) identified the fundamental problem: a template that participates in spec-kit's resolution stack cannot simultaneously be a `.context.md` that APM's link resolver traverses. gh-aw's cross-review (T-2) added that knowledge artifacts on repo-memory branches are not in the working tree at predictable paths, breaking APM's link resolution model.

The orchestrator's knowledge artifacts (KNOWLEDGE.md, DECISIONS.md, summaries) serve a different lifecycle than APM context files. They are runtime-generated, append-only, and may live on repo-memory branches in CI. Forcing them into `.context.md` format would constrain their storage model without meaningful benefit. The plan's existing `drill_down_paths` and `key_files` approach is sufficient.

---

## New Recommendations

### New-1 (P2): Define manifest authority boundaries between `apm.yml` and `extension.yml`

**Source**: Spec-kit cross-review T-3, my own cross-review of spec-kit Productive Tension #2.

Both manifests declare package name, version, and dependencies. Without explicit rules about which is authoritative for what, they will drift. The plan should document:

- `extension.yml` is authoritative for: command registration, hook declarations, spec-kit compatibility requirements (`requires.speckit`), config schema, template declarations.
- `apm.yml` is authoritative for: distribution metadata (source repo, version resolution), compilation settings, APM script aliases, multi-agent target configuration.
- Overlapping fields (name, version, description): `extension.yml` is source of truth; `apm.yml` must match. A CI check or pre-publish script should validate consistency.

### New-2 (P2): Ensure APM-deployed instructions are committed, not just locally installed

**Source**: gh-aw cross-review DC-2.

gh-aw correctly identified that APM instructions deployed to `.github/instructions/` via `apm install` do not exist on ephemeral CI runners unless committed to the repo. For the instructions described in my revised Recommendation 4 (ambient guidance for `.specify/orchestrator/` files) to work across all execution contexts, they must be committed to version control after `apm install`. The quickstart should include a post-install step: `apm install && git add .github/instructions/ && git commit`. Alternatively, if the extension is committed directly (the default path per D4), the instructions should be checked in as part of the extension's committed files.

### New-3 (P1): Establish a single verification ownership model

**Source**: Spec-kit cross-review DC-3, gh-aw cross-review DC-4, my own cross-review of spec-kit DC-4.

All three cross-reviews independently flagged the verification architecture as the most dangerous multi-tool concern. The plan has three potential verification systems: the orchestrator's R-006 verification ladder, spec-kit's checklist/hook system, and (now withdrawn) APM hooks. Even with APM hooks withdrawn, the relationship between R-006 and spec-kit checklists needs explicit resolution.

The plan should state:
- **Spec-kit's checklist system** is the enforcement mechanism. Phase must-haves are expressed as spec-kit checklists that gate `/speckit.implement`.
- **R-006 verification ladder** is the implementation of spec-kit's checklist verification -- the bash scripts that evaluate whether checklist items are satisfied. It is not a parallel system; it feeds into spec-kit's gating.
- **`before_commit`** (spec-kit hook) is the commit-time enforcement point. The R-006 scripts run within this hook to block commits when must-haves are unmet.
- The gh-aw adapter uses `protected-files` as a separate, non-overlapping enforcement layer (write prevention, not verification).

### New-4 (P2): Define the lock file schema with adapter-type discriminator

**Source**: My own cross-review of gh-aw DC-3.

The lock file schema (data-model.md lines 237-249) uses PID-based liveness detection, which is meaningless on ephemeral CI runners. The adapter interface should define a `check_liveness(lock_data) -> bool` operation, and the lock schema should include an `adapter_type` field so that `derive-phase.sh` can dispatch to the correct liveness check. Without this, local runs misinterpret CI lock data and vice versa. This is not an APM-specific concern, but it surfaced through the cross-review process and affects the adapter interface that all three tools depend on.

---

## Position Summary

Of my 10 original recommendations, **3 survive as stated**, **4 are modified**, and **3 are withdrawn**.

**Withdrawn** (3):
- Rec 5 (APM compilation for dispatch payloads) -- gh-aw's fixed-prompt-at-dispatch constraint and per-dispatch latency make this impractical.
- Rec 9 (APM hooks for verification) -- three verification systems is a governance disaster; spec-kit checklists are the right primary mechanism.
- Rec 10 (APM context linking for knowledge artifacts) -- runtime-generated artifacts on repo-memory branches do not fit APM's link resolution model.

**Modified** (4):
- Rec 2 (SKILL.md) -- downscoped from per-command to a single package-level summary to avoid parallel hierarchy.
- Rec 3 (lockfile) -- downgraded from P1 to P2; relevant only for the secondary APM-managed path.
- Rec 4 (instructions) -- scoped to ambient guidance only; spec-kit frontmatter owns command-time context.
- Rec 7 (APM scripts) -- scoped to local development; CI uses `on.steps:` with the same underlying scripts.
- Rec 8 (runtime dependency framing) -- expanded to a full dependency matrix covering APM, gh-aw, and spec-kit.

**Surviving** (3):
- Rec 1 (concrete `apm.yml` manifest) -- universally confirmed as a gap.
- Rec 6 (`compilation.exclude` for runtime state) -- uncontested defensive measure.
- Rec 8 (dependency framing) -- surviving in modified/expanded form.

**New** (4):
- New-1 (P2): Manifest authority boundaries between `apm.yml` and `extension.yml`.
- New-2 (P2): Commit APM-deployed instructions to version control for CI compatibility.
- New-3 (P1): Single verification ownership model with spec-kit checklists as enforcement.
- New-4 (P2): Lock file schema with adapter-type discriminator for cross-environment liveness checks.

**Overall shift**: The cross-reviews corrected my overreach in three areas. First, I treated APM compilation as a general-purpose context assembly tool, but it operates at the wrong lifecycle point for per-dispatch payloads. Second, I proposed APM instructions as a replacement for scope filtering, when they are complementary at best -- ambient guidance, not command-time context. Third, I suggested layering APM hooks on top of an already-complex verification architecture, adding governance burden without demonstrated coverage gaps. My surviving and new recommendations focus APM's contribution on what it does best: distribution, manifest management, install-time configuration, and multi-agent compilation -- not runtime behavior that belongs to spec-kit and not CI orchestration that belongs to gh-aw.
