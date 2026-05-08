# Arbitration Resolution: Speckit-Orchestrator Disputes

**Date**: 2026-03-19
**Arbiter**: speckit-orchestrator (the system being built)
**Process**: Post-conversus arbitration — see [process note](#process-note) below
**Input**: Unresolved disputes from spec-level conversus (5 disputes) and plan-level conversus (4 disputes)

---

## Process Note

The spec-level and plan-level conversus processes both used **cooperative mode** with 3 tool-perspective agents (APM, spec-kit, gh-aw). Cooperative mode's Phase 5 synthesis produces a neutral summary of convergence and remaining disputes — it does not issue binding rulings.

Several disputes survived both full conversus cycles (30 total artifacts across 2 processes). The three tool perspectives represent external concerns (packaging, extension system, CI) but none represents the orchestrator's own operational needs.

**Innovation**: We introduced a 4th agent — the speckit-orchestrator itself — as a post-conversus arbiter. This agent evaluates disputes from the perspective of what makes orchestration most reliable, grounded in the project's 7 constitution principles. Its decisions are binding.

**Conversus framework support**: The framework's Prisoner's Dilemma and Red-Blue modes include built-in arbiter roles in Phase 5. The cooperative mode does not. This arbitration is an ad-hoc extension of the cooperative process — a "Phase 6" that the framework could formalize as an optional arbitration phase for cooperative mode when disputes remain after synthesis.

**Recommendation for conversus framework**: Add optional `arbiter` field to `conversus.yml` schema:
```yaml
arbiter:
  name: speckit-orchestrator
  prompt: |
    You ARE the system being built. Evaluate disputes from the perspective
    of operational reliability, grounded in the constitution.
  trigger: disputes_remain  # only runs if Phase 4 has unresolved disputes
```

---

## Binding Decisions

### PD1: Config File Placement

**DECISION**: Configuration files live at the project root.

**Rationale** (Principle 6 — State On Disk Is Truth):
Config must be at a predictable, stable location for crash recovery and CI runners. Coupling config lifecycle to APM's deployment directory (`.specify/extensions/orchestrator/`) is fragile — even though APM currently tracks per-file via `deployed_files`, this is an implementation detail that could change. Config is user-authored with a different lifecycle than extension code. Project root makes config discoverable by CI runners without path assumptions about the extension system, and satisfies FR-070 ("user-mutable configuration MUST NOT reside in APM-managed directories").

**Three-bucket model** (extends AD-7):

| Bucket | Location | Write Owner | Lifecycle |
|--------|----------|-------------|-----------|
| Deployment | `.specify/extensions/orchestrator/` | Package manager (APM / specify) | Replaced on install/upgrade |
| Runtime state | `.specify/orchestrator/` | Orchestrator | Written during execution |
| Configuration | Project root | Developer | Created once, evolved over time |

**Concrete files**:
- `{root}/orchestrator-config.yml` — committed, team-shared
- `{root}/orchestrator-config.local.yml` — gitignored, per-developer
- `extension.yml` `defaults` section — factory defaults (shipped with extension)
- `SPECKIT_ORCHESTRATOR_*` env vars — CI/per-run overrides

**Rejected**: gh-aw's position (config at `.specify/extensions/orchestrator/`). Even though APM currently tracks per-file, placing config inside the deployment directory creates fragile coupling. If APM ever adds "clean install" mode, user config is destroyed.

---

### PD2: `deterministic` Script Annotation

**DECISION**: Annotation in `extension.yml` `provides.scripts` section, not command frontmatter, not adapter config.

**Rationale** (Principle 6 + Principle 1):
`derive-phase.sh` runs as precomputation before any adapter code is available — the annotation must be discoverable from disk alone. Placing it in command frontmatter pollutes the format seen by all agents (violates Principle 1). Placing it in adapter config makes it invisible to the orchestrator's own test suite.

The annotation describes a property of the script, not the runtime. The orchestrator extension knows which of its scripts are deterministic — this is intrinsic metadata.

**Deterministic script contract**:
- Reads only from filesystem (no network, no agent session, no user interaction)
- Writes only to stdout/stderr and files
- Produces identical output given identical file state

**Enforcement**: Integration test in the orchestrator's own test suite validates all `deterministic: true` scripts by running them in a restricted environment and verifying idempotent output.

**Concrete change**:
```yaml
# extension.yml
provides:
  scripts:
    - file: scripts/state/derive-phase.sh
      executable: true
      deterministic: true   # <-- new field
```

The gh-aw adapter reads `extension.yml` at compile time to decide what can run as precomputation. Any adapter can use this metadata — it's not gh-aw-specific.

**Rejected**: spec-kit (adapter config only — can't enforce in orchestrator tests) and gh-aw (command frontmatter — pollutes command format for all agents).

---

### SC1: Install-time Overwrite vs Runtime Config Persistence

**DECISION**: Three-bucket separation is the complete resolution. No further action beyond PD1.

**Rationale** (Principle 6):
The tension existed because config was being forced into one of two buckets (deployment or runtime) when it belongs in neither. The three-bucket model gives each concern its own location with non-overlapping write ownership:

- `apm install --upgrade`: replaces deployment bucket only
- Orchestrator execution: writes runtime state bucket only
- Developer edits: modifies config bucket only
- CI checkout: finds config at project root, state at `.specify/orchestrator/`

No bucket's owner can corrupt another bucket's contents. Crash recovery reads state from disk (Principle 6). Config is immutable during execution (AD-4). The tension is structurally eliminated.

---

### SC5: Single-Source Metadata vs Multi-Surface Discoverability

**DECISION**: One manually-maintained root-level `SKILL.md`. No derivation system.

**Rationale** (Principle 1 + Principle 3):
Agents need to find what the orchestrator does in one place (Principle 1 — don't make them scan 10 command files). APM's derivation capability doesn't exist today. Building it violates Principle 3 (Design Before Code — we'd be building tooling infrastructure instead of the orchestrator).

Drift risk is manageable: `SKILL.md` updates happen at milestone boundaries (command additions/removals), not per-commit. With 10 commands that will stabilize after initial implementation, this is a few edits per release.

**Concrete approach**:
- Root `SKILL.md` with trigger-phrased package description + command inventory table
- `extension.yml` `description` fields remain authoritative for per-command behavior
- `SKILL.md` references commands by name, doesn't duplicate behavior specs
- Updated as part of release checklist

**Rejected**: AD-6 derivation approach (the tool doesn't exist; building it is out of scope). When APM ships derivation, adopt it then.

---

### D3-EXT: Adapter Interface Richness

**DECISION**: Five core operations. No capability negotiation. No batch dispatch in the interface.

**Rationale** (Principle 1 + Principle 5):
The orchestrator always dispatches tasks sequentially from its perspective. This is the simplest possible core (Principle 1). Each task is an atomic unit with its own context (Principle 5). The dispatch loop is: `pick next → dispatch → await → collect → verify → advance`. This loop never needs to know about parallelism.

Parallel fan-out is the adapter's internal optimization, invisible to the core. The gh-aw adapter can internally batch independent tasks by reading the roadmap's dependency graph — but the orchestrator's 5-operation interface stays the same. No `if adapter.supports('batch')` branches, no `AdapterCapabilities` type, no negotiation handshake.

**Five operations (complete interface)**:
```
dispatch-task(payload) → task_handle
await-completion(task_handle) → completion_status
collect-result(task_handle) → result_artifacts
signal-failure(task_handle, diagnostic) → void
inject-context(task_handle, context) → void
```

**FR-069 rewrite**: "Adapters MAY implement internal optimizations (e.g., parallel fan-out, concurrency control) that are invisible to the orchestrator's core dispatch loop. The interface contract is the five core operations; adapter-internal behavior is unconstrained."

**Rejected**:
- APM (3 operations) — too thin. `inject-context` needed for FR-052 decision injection; `signal-failure` needed for escalation ladder.
- gh-aw (batch dispatch in interface) — forces two code paths in core. The adapter can batch internally without the core knowing.
- Capability negotiation (spec-kit + plan) — inevitably leads to conditional branches, violating FR-068. Eliminating negotiation eliminates the temptation.

---

## Summary of Changes Required

| Artifact | Change | Priority |
|----------|--------|----------|
| `plan.md` AD-7 | Extend from 2-bucket to 3-bucket separation | P1 |
| `plan.md` adapter interface | Remove capability negotiation; 5 ops are the complete interface | P1 |
| `extension.yml` | Add `deterministic: true` to script entries in `provides.scripts` | P1 |
| `contracts/runtime-adapter.md` | Remove Capability Negotiation section; rewrite FR-069 | P1 |
| `SKILL.md` | Author root-level skill summary (new file) | P2 |
| `research.md` | Update R-003 to reflect no capability negotiation | P2 |
| `data-model.md` | No changes needed | — |
| `quickstart.md` | No changes needed | — |

---

*This arbitration was conducted as a post-conversus process innovation. The speckit-orchestrator acted as its own arbiter, grounding all decisions in its 7 constitution principles. The conversus framework's cooperative mode does not natively include binding arbitration — this is a recommended extension.*