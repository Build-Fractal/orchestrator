# APM Disputes Document

**Author**: APM (Agent Package Manager)
**Phase**: Disputes (post-revision)
**Date**: 2026-03-19

---

## Remaining Disputes

### Dispute 1: Config file placement -- project root vs `.specify/extensions/orchestrator/`

**Claim**: `orchestrator-config.yml` should live at the project root, outside both APM's deployment radius and spec-kit's extension directory.

**gh-aw's position (New Rec B)**: Config should follow spec-kit's convention and live at `.specify/extensions/orchestrator/orchestrator-config.yml`, committed to the main branch. Repo-memory file-globs cover only `.specify/orchestrator/**`, never `.specify/extensions/**`, so config stays out of the state sync.

**Spec-kit's position (Rec 3 -- Withdrawn)**: Spec-kit originally wanted config inside `.specify/extensions/orchestrator/` but withdrew based on APM's always-overwrite semantics. Spec-kit accepted project root placement as "a documented deviation."

**APM counter-argument**: gh-aw's New Rec B reintroduces the exact problem spec-kit already conceded. APM's `apm install` uses always-overwrite semantics for the `.specify/extensions/orchestrator/` directory -- this is how AD-7's deployment boundary works. Placing user-authored config inside the deployment radius means `apm install --update` destroys user configuration. gh-aw argues repo-memory will not touch it, but that is irrelevant; the threat is APM install, not repo-memory sync. Spec-kit understood this and withdrew. gh-aw is reopening a resolved question.

**Proposed resolution**: Config stays at the project root as spec-kit accepted. The `provides.config` manifest section in `extension.yml` documents the non-standard path and the rationale. Both adapters (local and CI) read config from the project root. If spec-kit's `ExtensionManager.get_config()` expects files inside `.specify/extensions/`, it should be pointed at the project-root path via the manifest -- this is spec-kit's existing override mechanism.

---

### Dispute 2: Authority boundary for context injection -- two channels vs ambient-only

**Claim**: APM `.instructions.md` files serve ambient, always-applicable guidance only. Spec-kit frontmatter owns all command-time context injection.

**Spec-kit's position (New-1)**: Proposes a "two-channel context injection strategy" where neither channel is "primary" -- APM instructions and spec-kit frontmatter serve "different moments" and the orchestrator should author both as co-equal channels.

**APM counter-argument**: I agree with the factual description of two channels but dispute the framing of co-equality. Calling them co-equal invites scope creep into APM instructions. In my revision (Rec 4), I deliberately scoped APM instructions to "ambient, always-applicable guidance -- static rules about file formats, state directory conventions, and editing constraints." Spec-kit's framing of "neither channel is primary" leaves the door open for future decisions to push command-specific context into `.instructions.md` files, which would recreate the competing-context-injection problem all three reviews flagged. The channels are not co-equal; they are hierarchically scoped. Ambient rules (APM) are a strict subset of the guidance space; command-time context (spec-kit) handles everything else.

**Proposed resolution**: Document two channels but with an explicit scope hierarchy: APM `.instructions.md` files contain ONLY static, file-pattern-scoped rules that never reference orchestrator state, phase identity, or command arguments. Anything that references runtime state or is specific to a command invocation belongs in spec-kit frontmatter. This is not co-equality; it is a clear subordination boundary that prevents drift.

---

### Dispute 3: `SKILL.md` as "generated from command frontmatter" vs honestly authored summary

**Claim**: The root-level `SKILL.md` should be an honestly authored package-level summary, not marked as derived from frontmatter.

**Spec-kit's position (New-2)**: Author a single root-level `SKILL.md` but "mark it as 'generated from command frontmatter' with a comment indicating it should be replaced by automated derivation when APM adds that capability."

**APM counter-argument**: Marking a hand-authored file as "generated from command frontmatter" is a lie. The file is not generated -- it is written by a human or an agent, and its content may diverge from the actual frontmatter at any time. The comment creates a false expectation that the file's content tracks frontmatter changes, when in reality there is no mechanism enforcing consistency. This is the kind of misleading metadata that causes maintenance confusion. The file should say what it is: a manually maintained package-level summary. If APM later adds frontmatter-to-SKILL.md derivation, the generated file replaces the manual one -- a clean substitution, not a gradual drift from a "generated" file that was never actually generated.

**Proposed resolution**: Author the `SKILL.md` as a package-level summary with a header comment stating: "Manually maintained. Lists orchestrator capabilities for APM skill discovery. Update when commands are added or removed." No false "generated from" attribution. When APM adds automated derivation, the manual file is replaced entirely.

---

### Dispute 4: Lock file schema ownership -- adapter interface vs shared data model

**Claim**: The lock file schema should include an `adapter_type` discriminator and a polymorphic `check_liveness` operation in the adapter interface.

**gh-aw's position (Rec 2 refinement)**: Accepts the polymorphic lock schema but frames the `run_id`-based approach as "the gh-aw adapter's implementation of that interface method, not a modification to the shared lock schema itself."

**Spec-kit's position (New-4)**: Proposes a `runtime` field (`"local"` or `"ci"`) plus `run_id` for CI contexts.

**APM counter-argument**: gh-aw and spec-kit converge on the need but diverge on the field name (`adapter_type` vs `runtime`) and on where the polymorphism lives. gh-aw wants the adapter interface to own `check_liveness` as a method, pushing implementation into adapter code. Spec-kit wants the lock file itself to carry a `runtime` discriminator that `derive-phase.sh` (a shared bash script, not adapter code) can inspect. These are architecturally different: gh-aw's approach requires adapter code to be present when checking liveness; spec-kit's approach lets any bash script check liveness by reading the lock file. Since `derive-phase.sh` runs as a precomputation step (no adapter code available, just bash + jq), the lock file must be self-describing. The discriminator belongs in the lock file schema, not hidden behind an adapter method.

**Proposed resolution**: The lock file schema includes a `runtime` field (values: `"local"`, `"ci-github"`, extensible to `"ci-gitlab"` etc.) and, for CI runtimes, a `run_id` field. The shared `derive-phase.sh` script reads `runtime` to decide the liveness check strategy: PID existence for `"local"`, `gh api` call for `"ci-github"`. The adapter interface defines `acquire_lock` and `release_lock` operations that write the correct `runtime` value, but `check_liveness` is a shared function, not an adapter method, because it must work in precomputation contexts where no adapter is loaded.

---

## Convergence

### C-1: Verification architecture -- spec-kit checklists as primary gate

All three tools now agree on a tiered verification model:
- **Tier 1** (static checks): Deterministic scripts, run as precomputation steps in CI or `{SCRIPT}` invocations locally.
- **Tier 2** (command checks): Spec-kit checklists gate `/speckit.implement`. This is the authoritative "is this phase ready?" gate.
- **Tier 3** (behavioral preview): gh-aw staged mode. Advisory, not blocking.
- **Tier 4** (human review): Manual review, unchanged.

APM hooks are explicitly excluded from the verification ladder. gh-aw's `protected-files` operates as a separate, non-overlapping write-prevention layer. This was the most heavily contested area across all cross-reviews and is now fully resolved.

### C-2: Working tree is canonical; repo-memory is durability sync

All three tools agree: `.specify/orchestrator/` in the working tree is the source of truth during execution. The gh-aw adapter follows a hydrate-execute-persist sequence: pull from repo-memory at run start, execute against the working tree, push to repo-memory at run end. Spec-kit hooks and APM's file-path assumptions both depend on working-tree presence, and this model satisfies both. gh-aw revised its original position (which implied repo-memory as source of truth) to accept this.

### C-3: Dual-path script invocation contract

All three tools agree that the same underlying script files are invoked through three paths (spec-kit frontmatter `{SCRIPT}` for local command execution, APM `apm run` for local interactive discoverability, gh-aw `on.steps:` for CI precomputation) and that no adapter-specific logic should live inside the scripts themselves. The scripts take filesystem state as input and produce deterministic output regardless of invocation path.

### C-4: APM compilation is install-time only, not dispatch-time

All three tools agree that `apm compile` runs at install or update time, never per-dispatch. The orchestrator's `build-context.sh` handles per-dispatch payload construction. APM withdrew Rec 5 (compilation for dispatch payloads) and no tool contested the withdrawal. This cleanly separates APM's lifecycle (install/update) from the orchestrator's runtime lifecycle (dispatch/execute/verify).

### C-5: Dependency matrix replaces "no runtime dependency" blanket claim

All three tools now agree that the plan should replace vague "no runtime dependency" language with an explicit matrix showing when each tool runs (APM: install/update; gh-aw: workflow compile; spec-kit: always at runtime), what each is required for, and when each can be skipped. gh-aw's New Rec D and APM's revised Rec 8 are substantively identical on this point.

---

## Final Position Statement

### Non-negotiable positions

1. **APM's deployment radius is a hard boundary.** User-authored config files must not be placed inside `.specify/extensions/orchestrator/` because `apm install` uses always-overwrite semantics for that directory. This was conceded by spec-kit and must not be reopened. Config stays at the project root.

2. **APM `.instructions.md` files are ambient-only.** They contain static, file-pattern-scoped rules. They do not reference orchestrator state, phase identity, or command arguments. They do not replace or compete with spec-kit frontmatter for command-time context. This scope boundary is not negotiable because violating it recreates the competing-context-injection architecture that all three reviews identified as dangerous.

3. **The `apm.yml` manifest must exist.** The extension ships without distribution metadata, compilation settings, or script aliases today. This was uncontested across all reviews. The manifest defines the extension's identity in APM's packaging system and is a prerequisite for any APM-managed installation path.

4. **`compilation.exclude` must cover `.specify/orchestrator/`.** If `apm compile` runs in a project with active orchestrator state, it must not scan runtime state directories. Uncontested, low-effort, defensive.

### Areas of flexibility

1. **Lock file field naming.** I proposed `adapter_type`; spec-kit proposed `runtime`. Either works as long as the field lives in the lock file schema (not hidden behind adapter code) and `derive-phase.sh` can read it without loading adapter logic. I defer to whichever name the plan authors prefer.

2. **`SKILL.md` header language.** The substance matters (honest about being manually maintained, not falsely attributed as generated), but the exact wording of the header comment is negotiable.

3. **APM script registration scope.** I scoped APM scripts to local-only development and am flexible on which specific operations are registered (`verify`, `status`, `dispatch`, etc.). The CI path uses `on.steps:` regardless, so the local script set is a convenience, not an architectural decision.

4. **Lockfile priority.** I downgraded `apm.lock.yaml` to P2. If the plan authors prefer to defer it further or scope it to documentation-only (advising teams on the APM-managed path), that is acceptable. The committed-extension path (D4 default) does not need a lockfile.
