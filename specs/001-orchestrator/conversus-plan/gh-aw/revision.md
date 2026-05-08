# gh-aw Revised Position

**Reviewer**: gh-aw (GitHub Agentic Workflows)
**Phase**: Revision (post-cross-review)
**Date**: 2026-03-19

---

## Recommendation Dispositions

### Recommendation 1 — Design the gh-aw adapter's dispatch mode explicitly
**Original**: [P1] Decide between `dispatch-workflow` (async) and `call-workflow` (sync) for task dispatch; document in the runtime-adapter contract.

**Status**: **Surviving**

Neither cross-review challenges the substance of this recommendation. spec-kit's cross-review (DC-3) actually strengthens it: spec-kit identifies that `handoffs` frontmatter assumes same-session sequential transitions, which is architecturally incompatible with `dispatch-workflow`'s async, context-free runs. APM's cross-review (SA-2) also endorses the adapter interface as the correct abstraction boundary, noting the disagreements are about per-adapter specifics -- which is exactly what this recommendation provides.

**Refinement**: spec-kit's DC-3 reveals an additional constraint. The adapter must not only choose the dispatch mode but define how it translates spec-kit `handoffs` into that mode. For `dispatch-workflow`, each handoff becomes a context-free dispatch. The `prompt` and `send` fields in handoffs cannot be forwarded across async dispatches -- context must be fully serialized to disk state before dispatch and re-derived on the other side. This dual-mode expectation (handoffs for local, dispatch for CI) should be documented in the adapter contract.

---

### Recommendation 2 — Replace PID-based liveness with run-ID-based liveness in the CI adapter
**Original**: [P1] Store `github.run_id` and `github.run_attempt` instead of `pid` in the lock file for CI; use `gh api` to check run status.

**Status**: **Surviving**

APM's cross-review (DC-3) explicitly validates and extends this recommendation: "gh-aw correctly identifies that PID-based lock detection is meaningless on ephemeral CI runners." APM further proposes that the lock schema must include an `adapter_type` discriminator field and that the adapter interface must define a `check_liveness(lock_data) -> bool` operation. spec-kit's cross-review (T-3) agrees, proposing a `runtime` field (`"local"` or `"ci"`) for the same purpose.

**Refinement**: Accept APM's proposal for a polymorphic lock schema. The lock file should include a `runtime` discriminator field and the adapter interface should define `check_liveness(lock_data) -> bool`. The original recommendation's `run_id`-based approach becomes the gh-aw adapter's implementation of that interface method, not a modification to the shared lock schema itself.

---

### Recommendation 3 — Specify repo-memory configuration for orchestrator state persistence
**Original**: [P1] Add concrete `repo-memory` configuration to the adapter contract mapping `.specify/orchestrator/` files to a `memory/orchestrator` branch.

**Status**: **Modified**

spec-kit's cross-review (DC-1) identifies a genuine dangerous contradiction: if repo-memory is the source of truth, spec-kit hooks firing `after_tasks` or `after_implement` will find stale or empty state at `.specify/orchestrator/` because the canonical state lives on a different branch. spec-kit proposes two options and correctly identifies that option (a) -- working tree is canonical, repo-memory is a durability sync -- preserves spec-kit's filesystem assumptions, while option (b) breaks them.

APM's cross-review (T-2) raises the same tension from a different angle: APM's context linking needs files in the working tree at predictable paths, while gh-aw's repo-memory needs files on a separate branch.

**Revised position**: I accept spec-kit's resolution. The working tree at `.specify/orchestrator/` is the canonical source of truth. Repo-memory is a **durability sync layer**, not the source of truth. The gh-aw adapter's `persist_state` implementation commits the working tree state to the repo-memory branch **after** local writes complete (and **after** spec-kit hooks have fired). On CI re-entry, the adapter **hydrates** the working tree from repo-memory before any spec-kit command or hook runs. The sequence is: hydrate from repo-memory -> run commands/hooks against working tree -> persist working tree to repo-memory. This preserves spec-kit's filesystem assumptions while giving gh-aw the cross-run durability it needs.

The original `repo-memory` configuration block (branch name, file-globs) remains valid as adapter-level configuration, but the relationship is "sync target" not "source of truth."

---

### Recommendation 4 — Add `concurrency.job-discriminator` to all dispatched task workflows
**Original**: [P1] Every task dispatch workflow must include `concurrency: { job-discriminator: ${{ inputs.task_id }} }` to prevent fan-out cancellations.

**Status**: **Surviving**

No cross-review challenges this recommendation. It is a concrete gh-aw-internal concern with no cross-tool implications. Without the discriminator, dispatching T02 cancels T01 -- this is a correctness requirement, not a design preference.

---

### Recommendation 5 — Use deterministic `on.steps:` for state derivation instead of an agent invocation
**Original**: [P2] Run `derive-phase.sh` as an `on.steps:` precomputation step that outputs state, gating the agent invocation.

**Status**: **Modified**

APM's cross-review (DC-1) identifies a real conflict: if CI invokes `derive-phase.sh` via `apm run status`, it introduces an APM CLI dependency on the runner; if CI invokes it directly as `on.steps:`, the APM script registration is unused in CI. APM proposes the resolution: "APM scripts are the local/interactive invocation path, gh-aw `on.steps:` is the CI invocation path, and both must invoke the same underlying script by path."

spec-kit's cross-review (T-1) adds that the script must be declared in command frontmatter via `scripts:` for spec-kit's path rewriting to work locally, while gh-aw wants it invoked before the command template runs.

**Revised position**: Accept the dual-path contract. The same `scripts/state/derive-phase.sh` file is invoked through three paths:
1. **spec-kit local**: Declared in command frontmatter `scripts:` field, invoked by the agent via `{SCRIPT}` placeholder during command execution.
2. **APM local**: Registered as `apm run status` for interactive discoverability; invokes the same script by path.
3. **gh-aw CI**: Invoked directly as an `on.steps:` precomputation step by path, no APM dependency.

All three invoke the same script file. The script itself needs no environment detection -- the execution context differs, but the script's inputs (filesystem state) and outputs (derived state string) are identical. The adapter is responsible for choosing the invocation path appropriate to its runtime.

---

### Recommendation 6 — Mark `inject-context` as `not_supported` in the gh-aw adapter
**Original**: [P2] Declare `inject_context: false` in the gh-aw adapter capabilities; design the orchestrator to not depend on it for correctness.

**Status**: **Surviving**

spec-kit's cross-review (T-5) reinforces this: spec-kit's `agent_scripts` mechanism can update persistent files (CLAUDE.md) that the agent reads on **next** invocation, partially working around the limitation -- but only across runs, not within a single run. spec-kit agrees the design must be explicit about context updates taking effect on next invocation, not immediately.

APM's cross-review does not address this point.

**Refinement**: The adapter capability declaration should distinguish between `inject_context_live` (modify a running session -- `false` for gh-aw, possibly `true` for a Claude Code local adapter) and `inject_context_next_run` (modify persistent files read on next invocation -- `true` for gh-aw via repo-memory writes, `true` for local via `agent_scripts`). The original recommendation's binary `false` is too coarse; the two-level distinction lets the orchestrator use cross-run context injection where available while never depending on live injection for correctness.

---

### Recommendation 7 — Design re-entry for the `auto` command loop via scheduled triggers
**Original**: [P2] Design CI `auto` as a scheduled/`repository_dispatch`-triggered workflow that advances one unit per run, with `skip-if-match` for deduplication.

**Status**: **Modified**

spec-kit's cross-review (DC-2) identifies a dangerous contradiction with hook condition gating. If the gh-aw precomputation step determines a phase is complete and skips the agent, but a spec-kit hook fires inside the agent session after the workflow has already started, they can disagree on state. spec-kit's resolution: "The plan needs a single authoritative gating layer."

spec-kit's cross-review (T-4) further notes that local mode must support continuous execution while CI supports incremental re-entry, proposing a `--continuous` flag (default for local adapter) vs single-step mode (default for CI adapter).

**Revised position**: Accept spec-kit's gating authority principle. In CI, the gh-aw precomputation step is the **sole** gating authority for whether to invoke the agent at all. Once the agent is invoked, spec-kit hooks execute within the agent session and are authoritative for within-session decisions. The boundary is clear: gh-aw gates run/no-run, spec-kit gates within-run behavior. This avoids the contradiction where two independent systems disagree on phase completion.

Accept spec-kit's `--continuous` flag proposal. The adapter declares its supported mode: `continuous` (local, drives the full loop) or `step` (CI, advances one unit per scheduled run). The `auto` command checks the adapter's declared mode and behaves accordingly.

---

### Recommendation 8 — Add `protected-files` configuration to the adapter's PR creation safe output
**Original**: [P2] Configure `protected-files: fallback-to-issue` and `allowed-files` patterns in the adapter's workflow to prevent default blocking of `.specify/` path writes.

**Status**: **Surviving**

APM's cross-review (DC-4) raises a related concern: APM `PostToolUse` hooks firing after a write could conflict with gh-aw's protected-files policy that prevents writes in the first place. APM proposes a clear precedence: "gh-aw's safe-outputs gate what can be written, and any APM hook verification runs only on writes that gh-aw already permitted."

**Refinement**: Accept APM's precedence rule. The adapter documentation should state: (1) gh-aw's `protected-files` and `allowed-files` are the first gate -- writes blocked here never reach the agent; (2) any post-write verification (APM hooks, spec-kit hooks) runs only on writes that passed the safe-outputs gate. The `allowed-files` pattern should include `.specify/orchestrator/**` for state writes and any paths the orchestrator's tasks are expected to produce.

---

### Recommendation 9 — Use staged mode for verification dry runs in CI
**Original**: [P3] Add a `verify --staged` mode running the full verification pipeline with `staged: true` on all safe outputs.

**Status**: **Modified**

spec-kit's cross-review (DC-2) identifies that staged mode is one of three verification mechanisms (alongside spec-kit checklists and precomputation steps) targeting the same verification ladder, and the authority relationships are undefined. spec-kit proposes assigning each verification tier to exactly one mechanism: static checks = precomputation step; command checks = checklist system; behavioral checks = staged mode; human checks = manual review.

**Revised position**: Accept spec-kit's tier assignment. Staged mode is specifically the **behavioral verification** mechanism (tier 3 of the verification ladder). It does not replace spec-kit's checklist system (tier 2) or the precomputation step (tier 1). Its authority is to preview safe-output side effects (PRs, issues, status updates) before they are committed. It is advisory, not blocking -- a failing staged preview escalates to human review (tier 4) rather than independently blocking progress. This narrows the original recommendation from "full verification pipeline" to "behavioral tier only," which is cleaner.

---

### Recommendation 10 — Map `dispatch_budget` and `duration_budget` to gh-aw's `timeout-minutes` and `stop-after`
**Original**: [P3] Enforce budgets mechanically in CI via workflow timeouts instead of relying on advisory self-policing.

**Status**: **Modified**

APM's cross-review (T-5) identifies the tension between advisory budgets (local, human can override) and hard limits (CI, mechanical enforcement). APM proposes an explicit `budget_enforcement` config field: `advisory` (local default) vs. `enforced` (CI default), with the adapter responsible for the enforcement mechanism.

**Revised position**: Accept APM's `budget_enforcement` config field. The gh-aw adapter defaults to `enforced` and maps budgets to concrete CI mechanisms:
- `dispatch_budget` -> tracked in `execution-log.jsonl`, checked in the precomputation step; if exceeded, the scheduled run exits without dispatching.
- `duration_budget` -> mapped to `on.stop-after:` on the orchestrator's scheduled workflow.

The local adapter defaults to `advisory` and only warns when budgets are exceeded, preserving human override flexibility. The adapter interface declares which enforcement mode it supports and the orchestrator respects the adapter's declaration.

---

## New Recommendations

### New Recommendation A — Define the hydrate-execute-persist sequence as a first-class adapter contract
**Source**: Emerged from the convergence of spec-kit DC-1 (state persistence location), APM T-2 (static vs. dynamic state), and the revision to Recommendation 3.

The gh-aw adapter's interaction with the working tree follows a strict three-phase sequence that should be documented as a formal contract in the adapter interface:

1. **Hydrate**: On CI re-entry, pull state from repo-memory into `.specify/orchestrator/` before any spec-kit command or hook runs.
2. **Execute**: Run commands, hooks, and scripts against the working tree. All reads and writes target the filesystem at `.specify/orchestrator/`.
3. **Persist**: After execution completes (including all spec-kit hooks), commit the working tree state to the repo-memory branch.

This contract resolves the source-of-truth question definitively and should be part of the adapter interface specification, not just gh-aw-specific documentation. Other CI adapters (e.g., a future GitLab CI adapter) would follow the same three-phase pattern with different persistence backends.

**Priority**: P1. Without this contract, the state persistence contradiction identified by spec-kit and APM is unresolved.

### New Recommendation B — Separate config from state in repo-memory scope
**Source**: spec-kit DC-3 (config file placement -- three locations, three reviews, three answers).

Accept spec-kit's resolution: config (`orchestrator-config.yml`) follows spec-kit's convention at `.specify/extensions/orchestrator/orchestrator-config.yml` and is committed to the main branch as a user-authored file. State (milestones, phases, tasks, logs, locks) lives at `.specify/orchestrator/` and is synced to repo-memory by the gh-aw adapter. The repo-memory `file-glob` covers only `.specify/orchestrator/**`, never `.specify/extensions/**`.

This means the gh-aw adapter reads config from the repo checkout (it is in the main branch) and syncs only runtime state to repo-memory. Config changes are normal commits, not repo-memory operations.

**Priority**: P1. The three-way config location conflict blocks implementation of both the adapter and the spec-kit extension manifest.

### New Recommendation C — Classify scripts as deterministic or agentic in command frontmatter
**Source**: spec-kit T-1 (scripts in frontmatter vs. precomputation steps) and APM DC-1 (dual invocation paths).

Command frontmatter should include a `deterministic: true|false` annotation on each declared script. The gh-aw adapter hoists `deterministic: true` scripts into `on.steps:` precomputation, avoiding an AI engine invocation. The local adapter and spec-kit run all scripts through the standard `{SCRIPT}` placeholder mechanism regardless of classification. This lets the adapter optimize without requiring the script itself to be aware of its execution context.

Example:
```yaml
scripts:
  derive-phase:
    sh: ../../scripts/state/derive-phase.sh
    deterministic: true
  check-must-haves:
    sh: ../../scripts/verify/check-must-haves.sh
    deterministic: true
```

**Priority**: P2. Optimization, not correctness. The adapter can function without this by running all scripts inside the agent session, but at the cost of unnecessary engine invocations.

### New Recommendation D — Document build-time dependency acknowledgment for both APM and gh-aw
**Source**: APM T-3 ("no APM runtime dependency" vs. gh-aw's compile requirement) and gh-aw cross-review T-3 (both tools claim install-time-only but impose build steps).

The plan's "no GSD-2 or APM runtime dependencies" constraint is correct but incomplete. The plan should explicitly state:
- **Runtime dependencies**: None (no APM CLI, no `gh aw` CLI required during orchestrator execution).
- **Build-time dependencies**: APM CLI for `apm install` / `apm compile` (initial setup and updates). `gh aw compile` for workflow frontmatter changes in the CI adapter.
- **CI runner dependencies**: Git, bash, jq. No APM CLI, no `gh aw` CLI on the runner itself.

This clarifies that "no runtime dependency" does not mean "no dependency ever" and prevents implementers from being confused when they encounter build steps.

**Priority**: P2. Documentation clarity, not a design change.

---

## Position Summary

The cross-reviews validated the core of gh-aw's analysis while correctly identifying three areas where the original recommendations were underspecified or created cross-tool conflicts:

1. **State persistence model** (Rec 3, New Rec A, New Rec B): The original recommendation positioned repo-memory as the persistence layer without defining its relationship to the working tree. spec-kit's cross-review exposed this as a dangerous contradiction -- spec-kit hooks and commands read the working tree, not a git branch. The revised position establishes a hydrate-execute-persist sequence where the working tree is canonical during execution and repo-memory is a durability sync. Config is separated from state and follows spec-kit's convention.

2. **Verification authority** (Rec 9): The original recommendation proposed staged mode as a general verification mechanism. Both cross-reviews exposed the ambiguity of having three independent verification systems (precomputation, checklists, staged mode) with no authority hierarchy. The revised position assigns staged mode specifically to behavioral verification (tier 3), subordinate to the other tiers.

3. **Script execution dual-path** (Rec 5, New Rec C): The original recommendation proposed precomputation steps without acknowledging that spec-kit's frontmatter declaration and APM's script registration target the same scripts through different invocation paths. The revised position accepts the dual-path contract and proposes a `deterministic` annotation to let the adapter optimize without requiring script-level environment detection.

Four recommendations survive without substantive change (1, 2, 4, 6), though two gain refinements from cross-review feedback. Three recommendations are modified (3, 5, 7, 9, 10 -- five total when counting individually). None are withdrawn. Four new recommendations emerge from cross-review-identified gaps (A, B, C, D).

The original review's central thesis -- that the adapter interface is underspecified and the plan misses gh-aw capabilities that would directly benefit the orchestrator -- is reinforced by the cross-reviews. Both APM and spec-kit independently validated the adapter abstraction boundary while identifying different facets of its underspecification. The revised recommendations provide a more complete adapter contract that accounts for cross-tool interactions the original review could not see from gh-aw's perspective alone.
